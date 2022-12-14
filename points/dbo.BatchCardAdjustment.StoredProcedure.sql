USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BatchCardAdjustment]    Script Date: 9/6/2021 10:33:55 AM ******/
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
2019/02/27 Azan  Initial development          
**************************************************************************************************************************/   
/*
declare @rc int 
exec @rc = BatchCardAdjustment 1
select @rc 
*/
CREATE PROCEDURE [dbo].[BatchCardAdjustment] 
	@IssNo uIssNo 
AS
begin 
	declare              
		@PrcsId uPrcsId,@PrcsDate datetime,@PrcsName varchar(50),@BatchId uBatchId,@TxnDate datetime,
		@AppvCd varchar(6), @DeftBusnLocation varchar(50), @DeftTermId varchar(50), @RcptNo int, @RetCd int,
		@OnlineInd char(1),@TermId uTermId, @Mcc int, @Rrn uRrn, @Stan uStan,@InputSrc nvarchar(10), @CrryCd uRefCd, 
		@TxnSeq bigint,@Msg varchar(50), @MapInd int,@BusnLocation varchar(20),@PlanId uPlanId, @PaymentBatchId uBatchId,
		@ResponseCode uMsgCd 
	  
	SET NOCOUNT ON   

	select @Rrn = 0
	select @Stan = 0
	select @InputSrc = 'USER'
	select @ResponseCode = 0
	
	select @BusnLocation = VarCharVal
	from iss_Default where IssNo = @IssNo and Deft = 'CardCenterBusnLocation'

	select @TermId = IntVal
	from iss_Default where IssNo = @IssNo and Deft = 'CardCenterTermId'

	select @BatchId = 0	   

	--Create temp table--------------------------------------------------------------------------------------  
	  
	create table #PtsAdjustmentData
	(
		BatchId int,
		RecSeq int, 
		CardNo varchar(20), 
		Pts varchar(20), 
		Amt varchar(20),
		TxnCd varchar(5),
		Sts char(1),
		Remarks varchar(50),
		TxnDate varchar(100) 
	)

	select * into #SourceTxn
	from itx_SourceTxn
	where BatchId = -1
	delete #SourceTxn

	select * into #SourceTxnDetail
	from itx_SourceTxnDetail
	where BatchId = -1
	delete #SourceTxnDetail

	create	unique index IX_SourceTxnDetail on #SourceTxnDetail (
		BatchId,
		ParentSeq,
		TxnSeq )
              
	-- Retrieve data--------------------------------------------------------------------------------------              
              
	select @PrcsDate = CtrlDate, @PrcsId = CtrlNo          
	from iss_Control (nolock)              
	where IssNo = @IssNo and CtrlId = 'PrcsId' 
 
	if not exists (select 1 from cbf_Batch (nolock) where FileId = 'CARDADJ' and Prcsid = @PrcsId and Sts = 'L') 
	begin 
		set @ResponseCode = 60086
		GOTO ResponseExit;
	end

	select @BatchId = min(a.BatchId)              
	from cbf_Batch a (nolock)  
	where FileId = 'CARDADJ' and Prcsid = @PrcsId and Sts = 'L'

	update cbf_Record 
		set BatchId = @BatchId 
	where 
		FileId = 'CARDADJ' and BatchId is null and Sts is null 

	if @@error <> 0 or @@ROWCOUNT = 0 
	begin
		set @ResponseCode = 54022
		GOTO ResponseExit;
	end

	insert into #PtsAdjustmentData (BatchId,RecSeq,CardNo,Pts,Amt,TxnCd,TxnDate)
	select
		b.BatchId, 
		b.RecSeq,
		dbo.StringSpliter(b.RecStr,'|',0), 
		dbo.StringSpliter(b.RecStr,'|',1), 
		dbo.StringSpliter(b.RecStr,'|',2), 
		dbo.StringSpliter(b.RecStr,'|',3), 
		dbo.StringSpliter(b.RecStr,'|',4) 
	from
		cbf_Batch a (nolock)  
		join cbf_Record b (nolock) on a.FileId = b.FileId  and a.BatchId = b.BatchId
	where 
	a.Prcsid = @PrcsId 
	and a.BatchId = @BatchId
	and a.FileId = 'CARDADJ' 
	and b.RecSeq > 1

	if @@error <> 0 
	begin
		set @ResponseCode = 70271
		GOTO ResponseExit;
	end
	else if @@rowcount = 0
	begin 
		set @ResponseCode = 54022
		GOTO ResponseExit;
	end 


	--Validate--------------------------------------------------------------------------------------   
	update a 
	set a.Sts = 'F',
		a.Remarks = 'Invalid card number'
	from #PtsAdjustmentData a 
	where isnumeric(a.CardNo) <> 1

	update a 
	set a.Sts = 'F',
		a.Remarks = 'Invalid card number'
	from #PtsAdjustmentData a 
	where not exists (select 1 from iac_card b (nolock) where a.CardNo = b.CardNo)

	update a
	set a.Sts = 'F',
		a.Remarks = 'Invalid transaction code'
	from #PtsAdjustmentData a  where a.TxnCd not in (402,403)

	update a 
	set a.Sts = 'F',
		a.Remarks = 'Points is not in numeric'
	from #PtsAdjustmentData a  where isnumeric(a.Pts) <> 1 

	update a 
	set a.Sts = 'F',
		a.Remarks = 'Points should be more than 0'
	from #PtsAdjustmentData a  where a.Pts <= 0 

	update a 
	set a.Sts = 'F',
		a.Remarks = 'Points is in decimal'
	from #PtsAdjustmentData a  where ceiling(a.Pts) <> floor(a.Pts) 

	update a 
	set a.Sts = 'F',
		a.Remarks = 'Amount is not in numeric'
	from #PtsAdjustmentData a  where isnumeric(a.Amt) <> 1 

	update a 
	set a.Sts = 'F',
		a.Remarks = 'Amount should be more than 0'
	from #PtsAdjustmentData a  where cast(a.Amt as money) <= 0 

	update a 
	set a.Sts = 'F',
		a.Remarks = 'Points and amount not tally'
	from #PtsAdjustmentData a  where cast(a.Pts as int)*0.01 <> a.Amt

	update a 
	set a.Sts = 'F',
		a.Remarks = 'Invalid transaction date format'
	from #PtsAdjustmentData a  where isdate(a.txnDate) <> 1

	update a
		set 
			a.Sts = b.Sts, 
			a.Remarks = b.Remarks,  
			a.LastUpdDate = getdate() 
	from
		cbf_Record a (nolock) 
		join #PtsAdjustmentData b on a.BatchId = b.BatchId and a.RecSeq = b.RecSeq 
	where 
	a.BatchId = @BatchId
	and a.FileId = 'CARDADJ' 
	and a.RecSeq > 1


	if not exists (select 1 from #PtsAdjustmentData where RecSeq > 1 and Sts is null)
	begin 
		update cbf_Batch 
		set Sts = 'P' 
		where BatchId = @BatchId

		GOTO ResponseExit;    
	end 
	

	---------------------------------------------------------------------------------------------------------
	BEGIN TRANSACTION 
	---------------------------------------------------------------------------------------------------------

	exec @PaymentBatchId = nextRunNo 1, 'UDIBatchId'

	insert into udii_BatchPaymentCardList (BatchId,CardNo, TxnCd, TxnAmt,TxnDate, Description) 
	select @PaymentBatchId,CardNo, TxnCd, cast(Pts as int)*0.01,convert(datetime,TxnDate,103),'Points Adjustment via batch file :'+cast(@BatchId as varchar) 
	from #PtsAdjustmentData where Sts is null

	if @@ERROR <> 0
	begin 
		ROLLBACK TRANSACTION 
		set @ResponseCode = 70395 -- Failed to create new batch
		GOTO ResponseExit;    
	end 

	insert into udi_Batch (IssNo,BatchId,SrcName,Filename,FileSeq,DestName,Direction,PrcsId,Sts)
	select @IssNo,@PaymentBatchId,'PDB','ADJUSTMENT',0,'LMS','I',@PrcsId,'L'

	if @@ERROR <> 0
	begin 
		ROLLBACK TRANSACTION 
		set @ResponseCode = 70395 -- Failed to create new batch
		GOTO ResponseExit;    
	end 

	insert into #SourceTxn (
		BatchId, TxnSeq, IssNo, TxnCd, AcctNo, CardNo, LocalTxnDate, TxnDate,
		LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Descp,
		BusnLocation, Mcc, TermId, Rrn, Stan, AppvCd, CrryCd, Arn, BillMethod,
		PlanId, PrcsId, InputSrc, SrcTxnId, RefTxnId, AuthTxnId, OnlineInd,
		UserId, Sts )
	select @PaymentBatchId, 0, @IssNo, a.TxnCd, b.AcctNo, b.CardNo, TxnDate, TxnDate,
		isnull(TxnAmt,0), isnull(TxnAmt,0), 0, 0, 0, c.Descp,
		@BusnLocation, @Mcc, @TermId, null, null, @AppvCd, @CrryCd, null, null,
		c.PlanId, @PrcsId, @InputSrc,  null, null, null, c.OnlineInd,
		system_user, null
	from udii_BatchPaymentCardList a (nolock)
	join iac_card b (nolock) on b.CardNo = a.CardNo and b.IssNo = @IssNo
	join itx_TxnCode c (nolock) on c.txnCd = a.TxnCd and c.IssNo = @IssNo
	where a.BatchId = @PaymentBatchId and a.Sts is null

	if @@ERROR <> 0
	begin 
		ROLLBACK TRANSACTION 
		set @ResponseCode = 70109 -- Failed to create new batch
		GOTO ResponseExit;    
	end 

	select @TxnSeq = min(TxnId) from #SourceTxn
	
	while @TxnSeq is not null
	begin
		exec @RcptNo = NextRunNo @IssNo, 'RcptNo' 
			
		update #SourceTxn
		set STAN = @RcptNo,
			TxnSeq = TxnId
		where TxnId = @TxnSeq
			
		select @TxnSeq = min(TxnId) from #SourceTxn where TxnId > @TxnSeq	
	end

	exec @RetCd = OnlineTxnProcessing @IssNo

	if @@error <> 0 or dbo.CheckRC(@RetCd) <> 0
	begin
		rollback transaction
		set @ResponseCode = 95175	-- Failed to held the batch
		GOTO ResponseExit;    
	end

	update cbf_Batch 
		set Sts = 'P' 
	where BatchId = @BatchId

	if @@ERROR <> 0
	begin 
		ROLLBACK TRANSACTION 
		set @ResponseCode = 70265 -- Failed to update Batch
		GOTO ResponseExit;    
	end 

	update cbf_Record 
		set Sts = 'S' 
	where BatchId = @BatchId and RecSeq > 1 and Sts is null 

	if @@ERROR <> 0
	begin 
		ROLLBACK TRANSACTION 
		set @ResponseCode = 70265 -- Failed to update Batch
		GOTO ResponseExit;    
	end 
	
	update 
		udii_BatchPaymentCardList
	set Sts ='P'
	where BatchId = @PaymentBatchId 
		and Sts is null

	if @@ERROR <> 0
	begin 
		ROLLBACK TRANSACTION 
		set @ResponseCode = 70265 -- Failed to update Batch
		GOTO ResponseExit;    
	end 

	---------------------------------------------------------------------------------------------------------
	COMMIT TRANSACTION 
	---------------------------------------------------------------------------------------------------------
	ResponseExit:
	drop table #PtsAdjustmentData

	if @ResponseCode = 0
	begin 
		exec SendMail @IssNo,@PrcsId,1 
	end 

	return @ResponseCode
end
GO
