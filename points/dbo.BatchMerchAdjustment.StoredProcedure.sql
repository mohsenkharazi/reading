USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BatchMerchAdjustment]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*************************************************************************************************************************              
              
Copyright : CardTrend Systems Sdn. Bhd.              
Modular  : CardTrend Card Management System (CCMS)- Issuing Module              
              
Objective : This stored procedure is to process the data from Adjustment batch file            
              
SP Level : Primary              
              
Calling By : none              
              
--------------------------------------------------------------------------------------------------------------------------              
When    Who  CRN  Desc              
--------------------------------------------------------------------------------------------------------------------------              
2019/03/07 Azan  Initial development             
**************************************************************************************************************************/   
/*
DECLARE @rc int 
EXEC @rc = BatchMerchAdjustment 1
SELECT @rc 
*/
CREATE PROCEDURE [dbo].[BatchMerchAdjustment]
	@AcqNo uAcqNo 
AS
begin 
   declare              
		@PrcsId uPrcsId,
		@PrcsDate datetime,
		@PrcsName varchar(50),
		@BatchId uBatchId,
		@BusnLocation uMerch,
		@SysDate datetime, 
		@InputSrc uRefCd, 
		@Adjs uRefCd,
		@CtryCd uRefCd, 
		@CrryCd uRefCd, 
		@ActiveSts uRefCd,
		@Error int,
		@Rrn char(12),
		@RecSeq int,
		@RecSeqMax int,
		@TxnIds uTxnId,
		@Ids uTxnId,
		@MNLBatchID uBatchId,
		@ResponseCode uMsgCd 

		SET NOCOUNT ON  

		select @SysDate = getdate()
		select @ResponseCode = 0

		select @CrryCd = @CrryCd, @CtryCd = CtryCd from acq_Acquirer where AcqNo = @AcqNo
		select @ActiveSts = RefCd from iss_RefLib where IssNo = @AcqNo and RefType = 'MerchBatchSts' and RefNo = 0
		select @Adjs = RefCd from iss_RefLib where IssNo = @AcqNo and RefType = 'TxnInd' and RefCd = 'F'
		select @InputSrc = RefCd from iss_RefLib where IssNo = @AcqNo and RefType = 'MerchInputSrc' and RefNo = 1

		select @PrcsId = CtrlNo, @PrcsDate = CtrlDate
		from iss_Control
		where IssNo = @AcqNo and CtrlId = 'PrcsId'

		create table #MerchAdjustment 
		(
			BatchId int,
			RecSeq int,
			AcctNo bigint,
			Mcc int,
			MID varchar(100),
			TxnAmt varchar(100),
			TxnCd varchar(50),
			TxnDescp varchar(100), 
			TxnDate varchar(100),
			Sts char(1),
			Remarks varchar(50)
		)
		 
		if not exists (select 1 from cbf_Batch (nolock) where FileId = 'MERCHADJ' and Prcsid = @PrcsId and Sts = 'L') 
		begin 
			set @ResponseCode = 60086
			GOTO ResponseExit;
		end

		select @BatchId = min(a.BatchId)              
		from cbf_Batch a (nolock)  
		where FileId = 'MERCHADJ' and Prcsid = @PrcsId and Sts = 'L'

		update 
			cbf_Record 
		set BatchId = @BatchId 
			where 
		FileId = 'MERCHADJ' and BatchId is null and Sts is null

		if @@error <> 0 or @@ROWCOUNT = 0 

		begin 
			set @ResponseCode = 54022
			GOTO ResponseExit;
		end

		-- Retrieve data--------------------------------------------------------------------------------------    

		insert into #MerchAdjustment (BatchId,RecSeq,MID,TxnAmt,TxnCd,TxnDate)
		select
			b.BatchId, 
			b.RecSeq,
			dbo.StringSpliter(b.RecStr,'|',0), 
			dbo.StringSpliter(b.RecStr,'|',1), 
			dbo.StringSpliter(b.RecStr,'|',2), 
			dbo.StringSpliter(b.RecStr,'|',3)
		from
			cbf_Batch a (nolock)  
			join cbf_Record b (nolock) on a.FileId = b.FileId  and a.BatchId = b.BatchId
		where 
		a.Prcsid = @PrcsId 
		and a.BatchId = @BatchId
		and a.FileId = 'MERCHADJ' 
		and b.RecSeq > 1

		--Validate-------------------------------------------------------------------------------------------
		
		update a 
		set a.Sts = 'F',
			a.Remarks = 'Invalid merchant ID'
		from #MerchAdjustment a 
		where not exists (select 1 from aac_busnlocation b (nolock) where a.MID = b.Busnlocation)

		update a
		set a.Sts = 'F',
			a.Remarks = 'Invalid transaction code'
		from #MerchAdjustment a where a.TxnCd not in (400,402)

		update a
		set a.Sts = 'F',
			a.Remarks = 'Transaction amount should be in numeric'
		from #MerchAdjustment a where isnumeric(a.TxnAmt) <> 1 

		update a
		set a.Sts = 'F',
			a.Remarks = 'Transaction amount should be in numeric'
		from #MerchAdjustment a where isnumeric(a.TxnAmt) <> 1 

		update a
		set a.Sts = 'F',
			a.Remarks = 'Transaction amount should be more than 0'
		from #MerchAdjustment a where cast(a.TxnAmt as money) <= 0  

		update a 
		set a.Sts = 'F',
			a.Remarks = 'Invalid transaction date format'
		from #MerchAdjustment a  where isdate(a.TxnDate) <> 1

		update a 
		set a.Sts = 'F',
			a.Remarks = 'Transaction date more than process date'
		from #MerchAdjustment a  where convert(datetime,a.TxnDate,103) > @PrcsDate

		----------------------------------------------------------------------------------------------------------

		update a 
			set a.AcctNo = b.AcctNo,
				a.Mcc = b.Mcc,
				a.TxnDescp = c.Descp 
		from  
			#MerchAdjustment a 
			join aac_Busnlocation b (nolock) on a.MID = b.Busnlocation 
			join atx_TxnCode c (nolock) on a.TxnCd = c.TxnCd 
		where 
			a.Sts is null

		update a
			set 
				a.Sts = b.Sts, 
				a.Remarks = b.Remarks,  
				a.LastUpdDate = getdate() 
		from
			cbf_Record a (nolock) 
			join #MerchAdjustment b on a.BatchId = b.BatchId and a.RecSeq = b.RecSeq 
		where 
			a.BatchId = @BatchId
			and a.FileId = 'MERCHADJ' 
			and a.RecSeq > 1


		delete from #MerchAdjustment where Sts = 'F'

		---------------------------------------------------------------------------------------------------------
		BEGIN TRANSACTION
		---------------------------------------------------------------------------------------------------------
		exec @MNLBatchID = NextRunNo @AcqNo, 'MNLBatchID'
		select @RecSeq = min(RecSeq) from #MerchAdjustment where RecSeq > 1 and Sts is null

		while (@RecSeq is not null)
		begin 
			exec GetRrn @Rrn output
			
			insert atx_SourceSettlement
			( TxnCd, BusnLocation, TermId, SettleDate, Stan, Rrn, InputSrc, LinkIds, 
			InvoiceNo, OrigBatchNo, Cnt, Amt, Pts, BillingAmt, BillingPts, Sts, BatchId,
			AcqNo, AcctNo, Mcc, UserId, LastUpdDate, PrcsId, TxnInd, PosCondCd, ChequeNo, Descp )
			
			select TxnCd, MID,'',convert(datetime,TxnDate,103), null, @Rrn, @InputSrc, null,
			0, -1, 1, TxnAmt, 0, 0, 0, @ActiveSts, @MNLBatchID,
			@AcqNo, AcctNo, Mcc, system_user, @SysDate, @PrcsId, @Adjs, null, null, TxnDescp 
			from #MerchAdjustment where RecSeq = @RecSeq

			select @Error = @@error, @TxnIds = @@identity

			if isnull(@TxnIds, 0) = 0 or @Error <> 0
			begin
				rollback transaction
				set @ResponseCode = 70253 --Failed to insert Adjustment
				GOTO ResponseExit;
			end

			insert atx_SourceTxn
			( SrcIds, TxnCd, CardNo, TxnDate, Rrn, BatchId, TxnInd, LastUpdDate, AcqNo, UserId, Amt, Qty, PrcsId, BusnLocation,TermId)
			select @TxnIds, TxnCd, 0,convert(datetime,TxnDate,103), @Rrn, @MNLBatchID, @Adjs, @SysDate, @AcqNo, system_user, TxnAmt, 1, @PrcsId, MID,'' 
			from #MerchAdjustment where RecSeq = @RecSeq

			select @Error = @@error, @Ids = @@identity

			if isnull(@Ids, 0) = 0 or @Error <> 0
			begin
				rollback transaction
				set @ResponseCode = 70253 --Failed to insert Adjustment
				GOTO ResponseExit;
			end

			update #MerchAdjustment set Sts = 'P' where RecSeq =  @RecSeq
			select @RecSeq = min(RecSeq) from #MerchAdjustment where RecSeq > 1 and Sts is null
		end

		update cbf_Batch set Sts = 'P' where BatchId = @BatchId 
		update cbf_Record set Sts = 'S' where BatchId = @BatchId and RecSeq > 1 and sts is null  

		---------------------------------------------------------------------------------------------------------
		COMMIT TRANSACTION
		---------------------------------------------------------------------------------------------------------
		ResponseExit:

		if @ResponseCode = 0
		begin 
			exec SendMail 1,@PrcsId,2 
		end 

		return @ResponseCode
end
GO
