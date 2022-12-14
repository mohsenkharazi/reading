USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[DirectCreditExtraction]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*****************************************************************************************************
Copyright	:Cardtrend Systems Sdn. Bhd.

Modular		:Cardtrend Card Management System (CCMS)- Acquiring Module.

Objective	:To extract merchant direct credit

------------------------------------------------------------------------------------------------------
When	   	Who		CRN		Description
------------------------------------------------------------------------------------------------------
2005/09/20	KY				Initial development.
2005/09/29	Chew Pei		Change NextRunNo param from 'BatchId' to 'INSBatchId'
2009/03/11	Peggy			Customized for PDB (same logic with IDBB version)
								--udi_Batch table field changed
								--udiE_DirectCredit table filed changed
2009/04/25	Chew Pei		Added RecCnt, RefNo1
2009/04/28	Peggy			Changed Credit/Debit Entry, and added BankName in udie_DirectCredit
2009/04/29	Chew Pei		Added TxnCd grouping
							- Every transaction done on Merchant side (eg adjustment), it will be a separate line of SPO entry
2012/01/13	Barnett			Change the get RefNo1 logic.
********************************************************************************************************/
-- exec DirectCreditExtraction 1,null,null,null,null
CREATE	procedure [dbo].[DirectCreditExtraction]
	@AcqNo uAcqNo,
	@PrcsId uPrcsId = null,
	@FromDate char(8) = null,
	@ToDate char(8) = null,
	@Rerun tinyint = null
  as
begin
	declare @BatchId uBatchId, @Cnt int, @PrcsDate datetime, @PrcsName varchar(50), 
		@ReadySts uRefCd, @SysDate datetime, @EndPrcsId uPrcsId,
		@RefNo1 int, @RecCnt int

	--set nocount on

	select @Rerun = isnull(@Rerun, 0)

	select @PrcsName = 'DirectCreditExtraction'
	select @SysDate = getdate()

	select @ReadySts = VarcharVal
	from acq_Default where AcqNo = @AcqNo and Deft = 'ReadySts'

	if @FromDate is not null
	begin
		if @FromDate > @ToDate return 50257 --Bank auto debit extracted 0 records

		select @PrcsId = PrcsId
		from cmnv_ProcessLog where IssNo = @AcqNo and convert(char(8),PrcsDate,112) = @FromDate
		if @@rowcount = 0 or @@error <> 0 return 50257  --Bank auto debit extracted 0 records
		exec TraceProcess @AcqNo, @PrcsName, @PrcsId

		select @EndPrcsId = PrcsId
		from cmnv_ProcessLog where IssNo = @AcqNo and convert(char(8),PrcsDate,112) = @ToDate
		if @@rowcount = 0 or @@error <> 0 return 50257  --Bank auto debit extracted 0 records
		exec TraceProcess @AcqNo, @PrcsName, @EndPrcsId
	end
	else
	begin
		if @PrcsId is null
		begin
			select @PrcsDate = CtrlDate, @PrcsId = CtrlNo, @EndPrcsId = CtrlNo
			from iss_Control where IssNo = @AcqNo and CtrlId = 'PrcsId'
			if @@rowcount = 0 or @@error <> 0 return 50257  --Bank auto debit extracted 0 records
			exec TraceProcess @AcqNo, @PrcsName, @PrcsId
		end
		else
		begin
			select @Rerun = 1
			select @PrcsDate = PrcsDate, @EndPrcsId = PrcsId
			from cmnv_ProcessLog where IssNo = @AcqNo and PrcsId = @PrcsId
			exec TraceProcess @AcqNo, @PrcsName, @PrcsId
		end
	end

	if exists (select 1 from udi_Batch where IssNo = @AcqNo and PrcsId = @EndPrcsId and SrcName = 'HOST' and FileName = 'DRCD')
	begin
		exec TraceProcess @AcqNo, @PrcsName, 'End-udi batch already exists'
		return 0
	end


	if @Rerun = 0
	begin
		----------
		begin tran
		----------

		update a 
		set BankPrcsId = @EndPrcsId
		from atx_Settlement a
		join aac_BusnLocation c on c.BusnLocation = a.BusnLocation and c.AutoDebitInd = 'Y'
		where a.Sts = 'A' and a.PrcsId between @PrcsId and @EndPrcsId


		if @@error <> 0
		begin
			rollback tran
			return 70395	-- Failed to create new batch
		end
		-----------
		commit tran
		-----------
	end
	

	-- Extract Settlement
	select identity(int, 1, 1) 'SeqNo', BatchId, TxnCd, BusnLocation, AcctNo, SettleDate, Amt, BillingAmt
	into #Settlements
	from atx_Settlement a
	where (BankPrcsId between @PrcsId and @EndPrcsId) and a.BillingAmt <> 0

	--Generate transactions group by process id as well. if customer wanna to 
	--group few days settlement transactions in one, then remove a.PrcsId.
	select TxnCd, BusnLocation, AcctNo, isnull(sum(Amt), 0) 'Amt', isnull(sum(BillingAmt), 0) 'BillingAmt'
	into #Payment 
	from #Settlements
	group by TxnCd, BusnLocation, AcctNo

	if @@rowcount = 0 return 50257 --Bank auto debit extracted 0 records

	select  identity (int,1,1) 'Seq',10 'TxnId',a.BusnLocation,a.AcctNo, a.Amt, a.BillingAmt, b.BankAcctNo, a.TxnCd
	into #CreditMerch
	from #Payment a
	join aac_BusnLocation b on b.BusnLocation = a.BusnLocation 
	where a.BillingAmt < 0 -- changed 20090428 by Peggy

	select  identity (int,1,1) 'Seq',50 'TxnId',a.BusnLocation,a.AcctNo, a.Amt, a.BillingAmt, (select VarcharVal from acq_Default where Deft = 'PDBDCBankAcctNo')'BankAcctNo', a.TxnCd
	into #DebitPDB 
	from #Payment a
	where a.BillingAmt < 0 -- changed 20090428 by Peggy

	select  identity (int,1,1) 'Seq',50 'TxnId',a.BusnLocation,a.AcctNo, a.Amt, a.BillingAmt, b.BankAcctNo, a.TxnCd
	into #DebitMerch
	from #Payment a
	join aac_BusnLocation b on b.BusnLocation = a.BusnLocation 
	where a.BillingAmt > 0 -- changed 20090428 by Peggy

	select  identity (int,1,1) 'Seq',10 'TxnId',a.BusnLocation,a.AcctNo, a.Amt, a.BillingAmt, (select VarcharVal from acq_Default where Deft = 'PDBDCBankAcctNo')'BankAcctNo', a.TxnCd
	into #CreditPDB
	from #Payment a
	where a.BillingAmt > 0 -- changed 20090428 by Peggy

	create table #udi(
	seq INT identity ,
	TxnId varchar(10),
	BusnLocation varchar(20),
	AcctNo varchar(20),
	Amt money,
	BillingAmt money,
	BankAcctNo varchar(20),
	TxnCd int
	)

	insert into #udi(TxnId,BusnLocation,AcctNo,Amt,BillingAmt,BankAcctNo, TxnCd)
	select TxnId,BusnLocation,AcctNo,Amt,BillingAmt,BankAcctNo, TxnCd from #CreditMerch
	order by Busnlocation, TxnCd

	if @@error <> 0	return 70395	-- Failed to create new batch

	insert into #udi(TxnId,BusnLocation,AcctNo,Amt,BillingAmt,BankAcctNo, TxnCd)
	select TxnId,BusnLocation,AcctNo,Amt,BillingAmt,BankAcctNo, TxnCd from #DebitPDB
	order by Busnlocation, TxnCd

	if @@error <> 0	return 70395	-- Failed to create new batch

	insert into #udi(TxnId,BusnLocation,AcctNo,Amt,BillingAmt,BankAcctNo, TxnCd)
	select TxnId,BusnLocation,AcctNo,Amt,BillingAmt,BankAcctNo, TxnCd from #CreditPDB
	order by Busnlocation, TxnCd

	if @@error <> 0	return 70395	-- Failed to create new batch

	insert into #udi(TxnId,BusnLocation,AcctNo,Amt,BillingAmt,BankAcctNo, TxnCd)
	select TxnId,BusnLocation,AcctNo,Amt,BillingAmt,BankAcctNo, TxnCd from #DebitMerch
	order by Busnlocation, TxnCd

	if @@error <> 0	return 70395	-- Failed to create new batch

	select * 
	into #MerchAutoDebit 
	from  #udi 
	order by TxnCd asc, BusnLocation asc, TxnID desc

	select @RecCnt = count(*) from #MerchAutoDebit
	
	exec @BatchId = NextRunNo @AcqNo, 'INSBatchId'

		
	select @RefNo1 = isnull(max(cast(RefNo1 as int)), 0) + 1
	from udi_Batch 
	where SrcName = 'HOST' and FileName = 'DRCD' and BatchId = (select Max(BatchId) from udi_Batch where SrcName = 'HOST' and FileName = 'DRCD')

	
	if @RefNo1 > 999 -- if more than 999 then reset to 1
		select @RefNo1 = 1

	-----------------
	BEGIN TRANSACTION
	-----------------

	insert into udi_Batch  
		(IssNo, BatchId, PhyFileName, SrcName, FileName, 
			FileSeq, 
			DestName, FileDate, OrigBatchId, LoadedRec, RecCnt, PrcsRec, Direction, PrcsId, PrcsDate, RefNo1, RefNo2, RefNo3, RefNo4, 
			Sts, PlasticType, OperationMode, RefNo5)
	select @AcqNo, @BatchId, null, 'HOST', 'DRCD', 
		(select isnull(max(FileSeq), 0) + 1 from udi_Batch where IssNo = @AcqNo and SrcName = 'HOST' and FileName = 'DRCD'),
		'PDB', getdate(), null, 0, @RecCnt, null, 'E', @EndPrcsId, @PrcsDate, @RefNo1, null, null, null, 
			'L', null, null, (select VarcharVal from acq_Default where Deft = 'PDBDCBankAcctNo')

	if @@error <> 0
	begin
		rollback transaction
		return 70395	-- Failed to create new batch
	end

	select @BatchId = max(BatchId) from udi_Batch where IssNo = @AcqNo and SrcName = 'HOST' and FileName = 'DRCD'

	if isnull(@BatchId, 0) = 0 
	begin
		rollback tran
		return 70395	-- Failed to create new batch
	end

	insert into udiE_DirectCredit
		(IssNo, BatchId, SeqNo, TxnId, AcctNo, BusnLocation, Amt, BillingAmt, BusnName, PostDate, TxnDate, BankAcctNo, BankName, PrcsId, RespCd)
	select @AcqNo, @BatchId, a.Seq, a.TxnId, a.AcctNo, a.BusnLocation, a.Amt, abs(a.BillingAmt), b.BusnName, @PrcsDate, @PrcsDate, 
			a.BankAcctNo, b.BankName, @EndPrcsId, null
	from #MerchAutoDebit a
	join aac_BusnLocation b on b.BusnLocation = a.BusnLocation  ---- changed 20090428 by Peggy
	order by a.Seq
	
	if @@error <> 0
	begin
		rollback transaction
		return 70395	-- Failed to create new batch
	end

	exec TraceProcess @AcqNo, @PrcsName, 'End'

	------------------
	COMMIT TRANSACTION
	------------------

	return 50104	--Transaction has been processed successfully
end
GO
