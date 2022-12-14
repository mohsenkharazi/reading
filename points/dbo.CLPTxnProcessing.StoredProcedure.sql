USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CLPTxnProcessing]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Objective	:Load CLP Txn Record and process
		
SP Level	:Primary

-----------------------------------------------------------------------------
When	   Who			   Description
-------------------------------------------------------------------------------
2014/02/21 Adi			Initial development
2014/04/30 Humairah		TxnAmt length change to 15	&& accept card with sts = 'A' or 'P'
2014/06/19 Humairah		Select ACTIVE && ISSUED Primary Card No only.
2014/07/16 Humairah		bug fixed at 'F'  checking
2015/05/08 Humairah		change /1000 to 10000
2015/07/28 Humairah		restrict poits issuance to 53 accounts (temp_CLP53AccountList) provided by BTD
2015/08/21 Humairah		add sts H and remove: restrict poits issuance to 53 accounts (temp_CLP53AccountList) provided by BTD
2015/08/24 Humairah		allow points issued to a block card(special request)
2015/08/24 Humairah		remove : allow points issued to a block card(special request)
*******************************************************************************/
CREATE procedure [dbo].[CLPTxnProcessing]
	@IssNo uIssNo,
	@PrcsId	uPrcsId = null
	
  as
begin

	declare @PrcsDate datetime, @BatchId uBatchId, @FileSeq int, @Rc int, @TxnInd uRefCd
	declare @BillMethod char(1), @BatchSalesTxnCd int, @BusnName varchar(50), @BusnLocation varchar(15), @TermId int
	declare @ActiveSts char(1), @BaseFareChargeCd varchar(50)
	declare @AcqBatchId uBatchId, @ID int, @TxnCd nvarchar(4)
	
	select 'Start CLP Txn Process : ', getdate()

	if @PrcsId is null
	begin
		select @PrcsId = CtrlNo, @PrcsDate = CtrlDate
		from iss_Control (nolock)
		where CtrlId = 'PrcsId'
	end
	else
	begin 
		select @PrcsId = PrcsId, @PrcsDate = PrcsDate
		from cmnv_ProcessLog 
		where PrcsId = @PrcsId
	end


	select @FileSeq = max(FileSeq)	-- Get the last file sequence
	from udi_Batch (nolock)
	where IssNo = @IssNo and SrcName = 'CLP' and FileName = 'TRANSACTION'


	create table #Txn
	(
		IssNo smallint NULL ,
		BatchId int NOT NULL,
		TxnId int IDENTITY(1,1) NOT NULL,
		AcctNo nvarchar(20),
		CardNo varchar(30) COLLATE DATABASE_DEFAULT NULL,
		TxnAmt money NULL,
		TxnDescp varchar(500) null,
		BusnLocation varchar(15) COLLATE DATABASE_DEFAULT NULL,
		TxnCd int,
		PrcsId int NULL,
		UdiTxnId bigint NULL
	)

	create unique index IX_Txn_TxnId on #Txn (
		TxnId )

	create index IX_Txn_IssNoBatchId on #Txn (
		IssNo,
		BatchId )
	
	select @BusnLocation = VarcharVal 
	from iss_default where IssNo = @IssNo and Deft = 'PetronasBusnLocation'
	
	select @TermId = IntVal 
	from iss_default where IssNo = @IssNo and  Deft = 'PetronasTermId'

	-----------------
	BEGIN TRANSACTION
	-----------------

		exec @BatchId = NextRunNo @IssNo, 'UDIBatchId'

		insert into udii_CLPTxn (IssNo, BatchId, TxnSeq, AcctNo, TxnAmt, 
			TxnCd, PlanId, BusnLocation, PrcsId, Sts)
		select @IssNo, @BatchId, SUBSTRING(Str,2,10)'TxnSeq', RTRIM(SUBSTRING(Str,12,30))'AcctNo', CONVERT(money,SUBSTRING(Str,42,15))/10000'TxnAmt', 
			SUBSTRING(Str,57,3)'TxnCd', SUBSTRING(Str,60,4)'PlanId', @BusnLocation, @PrcsId, null
		from ld_CLPTxn 
		where Str like 'D%' and Str <> ''

		if @@error <> 0
		begin
			rollback transaction
			return 70271 -- Failed to insert into temporary table
		end

--		--Remove from udii_CLPTxn
--		update a
--		set a.Prcsid = a.PrcsId *-1,
--			a.Sts = 'X'
--		from udii_CLPTxn a
--		where a.BatchId = @BatchId and a.PrcsId = @PrcsId and a.Sts is null and AcctNo not in (select AcctNo from temp_CLP53AccountList )

		-- Invalid TxnAmt
		update a
		set a.Sts = 'R' 
		from udii_CLPTxn a
		where a.BatchId = @BatchId and a.PrcsId = @PrcsId and a.Sts is null and a.TxnAmt <= 0 

		if @@error <> 0
		begin
			rollback transaction
			return 70281 -- Failed to update temporary table
		end

		-- Check AcctNo
		update a
		set a.Sts = 'I' 
		from udii_CLPTxn a
		where not exists (select 1 from iac_Account b (nolock) where b.AcctNo = a.AcctNo) and a.Sts is null
				and a.BatchId = @BatchId and a.PrcsId = @PrcsId

		if @@error <> 0
		begin
			rollback transaction
			return 70281 -- Failed to update temporary table
		end

		-- Check the Merchant ID
		update a
		set a.Sts = 'M' 
		from udii_CLPTxn a
		where a.BatchId = @BatchId and a.PrcsId = @PrcsId and a.Sts is null 
				and not exists (select 1 from aac_BusnLocation b (nolock) where b.BusnLocation = a.BusnLocation)

		if @@error <> 0
		begin
			rollback transaction
			return 70281 -- Failed to update temporary table
		end

		-- Check TxnCd (only allow CLP TxnCd)
		update a
		set a.Sts = 'T'
		from udii_CLPTxn a
		where a.BatchId = @BatchId and a.PrcsId = @PrcsId and a.Sts is null 
			and a.TxnCd not in ('207','211')
		
		if @@error <> 0
		begin
			rollback transaction
			return 70281 -- Failed to update temporary table
		end

		update a
		set a.CardNo = b.CardNo
		from udii_CLPTxn a
		join iac_Card b (nolock) on b.AcctNo=CONVERT(bigint,a.AcctNo) and b.PriSec = 'P' and b.Sts in('A','P','B')			-- 2014/06/19 - Primary Card with Active/Issued Status ; 20150824 - include block card(for reporting purpose) but it will be filtered out later
		where a.BatchId = @BatchId and a.PrcsId = @PrcsId and a.Sts is null
		
		if @@error <> 0
		begin
			rollback transaction
			return 70281 -- Failed to update temporary table
		end	

		
		/*		-- Card/Account does not active or issued(Card only)
		update a
		set a.Sts = 'F' 
		from udii_CLPTxn a		
		join iac_Account b on b.AcctNo = a.AcctNo
		join iac_Card c on c.AcctNo = b.AcctNo and c.CardNo = a.CardNo and c.PriSec = 'P'								--2014/07/16 : link iac_card & udii_CLPTxn
		join iss_Reflib d on d.RefType = 'CardSts' and d.RefCd = c.Sts and d.IssNo = @IssNo  
		join iss_Reflib e on e.RefType = 'AcctSts' and e.RefCd = b.Sts and e.IssNo = @IssNo
		where a.Sts is null and a.BatchId = @BatchId and a.PrcsId = @PrcsId and (d.RefCd not in ('A','P')  or e.RefInd <> 0)
		*/
	
		-- No Card NO
		update a
		set a.Sts = 'H' 
		from udii_CLPTxn a		
		where a.Sts is null and a.BatchId = @BatchId and a.PrcsId = @PrcsId  and a.CardNo is NULL
		
		if @@error <> 0
		begin
			rollback transaction
			return 70281 -- Failed to update temporary table
		end

		-- Card is not active or issued
		update a
		set a.Sts = 'F' 
		from udii_CLPTxn a		
		join iac_Account b on b.AcctNo = a.AcctNo
		join iac_Card c on c.AcctNo = b.AcctNo and c.CardNo = a.CardNo and c.PriSec = 'P'								--2014/07/16 : link iac_card & udii_CLPTxn
		join iss_Reflib d on d.RefType = 'CardSts' and d.RefCd = c.Sts and d.IssNo = @IssNo  
		where a.Sts is null and a.BatchId = @BatchId and a.PrcsId = @PrcsId and d.RefCd not in ('A','P')


		if @@error <> 0
		begin
			rollback transaction
			return 70281 -- Failed to update temporary table
		end


		-- Account is not active 
		update a
		set a.Sts = 'G' 
		from udii_CLPTxn a		
		join iac_Account b on b.AcctNo = a.AcctNo							  
		join iss_Reflib c on c.RefType = 'AcctSts' and c.RefCd = b.Sts and c.IssNo = @IssNo
		where a.Sts is null and a.BatchId = @BatchId and a.PrcsId = @PrcsId  and c.RefInd <> 0
		
		if @@error <> 0
		begin
			rollback transaction
			return 70281 -- Failed to update temporary table
		end
	
		-- 'P' - Txn Ready to be processed
		update a
		set a.Sts = 'P'
		from udii_CLPTxn a
		where a.BatchId = @BatchId and a.PrcsId = @PrcsId and a.Sts is null 

		if @@error <> 0
		begin
			rollback transaction
			return 70281 -- Failed to update temporary table
		end
	
	
		insert into #Txn 
			(IssNo, BatchId, AcctNo, CardNo, TxnAmt, BusnLocation, TxnCd, TxnDescp, PrcsId, UdiTxnId)
		select a.IssNo, a.BatchId, a.AcctNo, a.CardNo, a.TxnAmt, a.BusnLocation, a.TxnCd, f.Descp, a.PrcsId, a.TxnId
		from udii_CLPTxn a
		join iac_Account b (nolock) on b.AcctNo = a.AcctNo
		join iac_Card c (nolock) on c.AcctNo = b.AcctNo and c.PriSec = 'P' and a.CardNo = c.CardNo
--		join iss_Reflib d (nolock) on d.RefType = 'CardSts' and d.RefCd = c.Sts and d.RefCd in ('A','P') and d.IssNo = @IssNo -- Only Active Card can earn points
--		join iss_Reflib e (nolock) on e.RefType = 'AcctSts' and e.RefCd = b.Sts and e.RefInd = 0 and e.IssNo = @IssNo -- Only Active Account can earn points
		join itx_TxnCode f (nolock) on f.TxnCd = a.TxnCd
		where a.PrcsId = @PrcsId and a.BatchId = @BatchId and a.Sts = 'P'
		
		if @@error <> 0
		begin
			rollback transaction
			return 70271      --     Failed to insert into temporary table
		end	
		
		select @rc = COUNT(*) from #Txn
		
	
		insert udi_Batch (IssNo, BatchId, SrcName, FileName, FileSeq, DestName, FileDate, RecCnt, Direction, PrcsId, PrcsDate, Sts)
		select @IssNo, @BatchId, 'CLP', 'TRANSACTION', isnull(@FileSeq,0)+1, 'HOST', getdate(), isnull(@Rc, 0), 'I', @PrcsId, @PrcsDate, 'L'
	
		if @@error <> 0
		begin
			rollback transaction
			return 	70395       --     Failed to create new batch
		end	
		
		-- *************************
		-- Do not continue process if there is no sts 'P' in the batch
		-- **************************
		if isnull(@Rc,0) = 0
		--if not exists (select 1 from udii_CLPTxn where BatchId = @BatchId and Sts = 'P')
		begin
			update a
			set Sts = 'P'
			from udi_Batch a
			where a.BatchId = @BatchId and SrcName = 'CLP' and FileName = 'TRANSACTION'

			if @@error <> 0
			begin
				rollback transaction
				return 70265	--	Failed to update Batch
			end

			truncate table ld_CLPTxn
			
			if @@error <> 0
			begin
				rollback transaction
				return 95481     --  Failed to truncate table
			end
			------------------
			commit transaction
			------------------
			drop table #Txn
		
			return 95159 -- Not all record has been processed
		end		

		--- *************************
		-- Create BatchId for each TxnCd
		-- **************************
				
		select identity(int,1,1)'ID', TxnCd, 0 'AcqBatchId' into #BatchId 
		from #Txn group by TxnCd
		
		select @ID = min(ID) from #BatchId
		
		while @ID > 0
		begin
			exec @AcqBatchId = NextRunNo @IssNo, 'EDCBatchId'

			update #BatchId 
			set AcqBatchId = @AcqBatchId
			where ID = @ID

			if @@error <> 0
			begin
				rollback transaction
				return 95278 --Check error on temp file
			end

			select @TxnCd = TxnCd from #BatchId where ID = @ID
			
			update #Txn set BatchId = @AcqBatchId where TxnCd = @TxnCd

			if @@error <> 0
			begin
				rollback transaction
				return 95278 --Check error on temp file
			end

			select @ID = min(ID) from #BatchId where ID > @ID
			if @@rowcount = 0 break
		end

		--- *************************
		-- Insert into atx_SourceSettlement 
		-- **************************			
		insert into atx_SourceSettlement -- For settlement TxnCd = 0
			(BusnLocation, Descp, TermId, Cnt, Amt, BillingAmt, TxnCd, SettleDate, InputSrc, InvoiceNo, BatchId, OrigBatchNo,
				LinkIds, PrcsId, TxnInd, Sts, AcqNo, UserId, LastUpdDate )
		select a.BusnLocation, b.BusnName, @TermId, a.Cnt, a.SumPts, 0, a.TxnCd, getdate(), 'BATCH', 0, c.AcqBatchId, 0,
				0, @PrcsId, @TxnInd, null, @IssNo, system_user, getdate()
		from (select a1.BusnLocation, a1.BatchId, a1.TxnCd, count(*) 'Cnt', sum(isnull(a1.TxnAmt,0)) 'SumPts'
				from #Txn a1
				group by a1.BusnLocation, a1.BatchId, a1.TxnCd) a
		join aac_BusnLocation b (nolock) on b.BusnLocation = a.BusnLocation and b.AcqNo = @IssNo		
		join #BatchId c on c.TxnCd = a.TxnCd and c.AcqBatchId = a.BatchId	 				


		if @@error <> 0 
		begin
			rollback transaction
			return 95205 -- Insert error atx_SourceTxnDetail
		end
		

		insert atx_SourceTxn
				(AcqNo, SrcIds, LinkIds, TxnCd, CardNo, LocalDate, LocalTime,
				TxnDate, Qty, Amt, BillingAmt, Descp,
				Sts, BatchId, PrcsId, TxnInd, LastUpdDate, 
				BusnLocation, TermId, Rrn, AuthNo, UserId, OrigAmt, Arn)
		select @IssNo, b.Ids, a.UdiTxnId, a.TxnCd, a.CardNo, null, null,
				@PrcsDate, 0, isnull(a.TxnAmt,0), 0, isnull(substring(a.TxnDescp,1,50),''),
				'A', a.BatchId, a.PrcsId, 'L', getdate(), 
				a.BusnLocation, @TermId, null, null, system_user, a.TxnAmt, a.UdiTxnId
		from #Txn a	
		join atx_SourceSettlement b (nolock) on b.BusnLocation = a.BusnLocation and b.PrcsId = @PrcsId and b.BatchId = a.BatchId
	
		if @@error <> 0 
		begin
			rollback transaction
			return 95205 -- Insert error atx_SourceTxnDetail
		end


		update a 
		set Sts = 'E'
		from udii_CLPTxn a
		where BatchId = @BatchId and a.Sts = 'P'
		
		if @@error <> 0
		begin
			rollback transaction
			return 70199 -- Failed to update held transaction
		end

	------------------
	COMMIT TRANSACTION
	------------------

	drop table #Txn
	drop table #BatchId

	return 54025	--	Transaction processing completed successfully
	
end
GO
