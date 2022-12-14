USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MissTxnBatchProcessing]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Management System (CCMS)
Objective	: 
*******************************************************************************/

/*
exec MissTxnBatchProcessing 1, 1000488
exec MissTxnBatchProcessing 1, 1000489
*/
CREATE procedure [dbo].[MissTxnBatchProcessing]
		@IssNo uIssNo,
		@BatchId uBatchId
  as
begin

		
	declare    @PrcsId int,@InsertedRec int, @ActiveSts varchar(5),
				@Ids int, @AcqBatchId int, @PrcsDate datetime, @Rrn varchar(12), @SysDate datetime


	select @ActiveSts = RefCd 
	from iss_RefLib where IssNo = @IssNo and RefType = 'MerchBatchSts' and RefNo = 0

	select @PrcsDate = CtrlDate, @PrcsId = CtrlNo
	from iss_Control (nolock) 
	where CtrlId = 'PrcsId' and IssNo = @IssNo
	
	select @SysDate = getdate()

	
	select @Rrn =	substring(convert(varchar(8), @SysDate, 112),3,6) + 
				substring(convert(varchar(8), @SysDate, 108),1,2) +
				substring(convert(varchar(8), @SysDate, 108),4,2) +
				substring(convert(varchar(8), @SysDate, 108),7,2)

	create table #Settle
	(
		IssNo smallint null,
		Ids bigint identity (1,1) not null,
		BusnLocation varchar(15) null,
		TermId varchar(10) null,
		TxnCd int null,
		TxnInd varchar(10) null,
		BatchId int null,
		OrgBatchId int null,
		Cnt int null,
		Amt money null
	)

	create table #Txn
	(
		IssNo smallint NULL,
		BatchId int NOT NULL,
		OrgBatchId int NOT NULL,
		TxnSeq bigint NOT NULL,
		TxnCd int,
		TxnInd varchar(15),
		TermId varchar(10) NULL,
		TxnDate varchar(12) NULL,
		CardNo bigint NULL,
		TxnAmt money NULL,
		Rrn varchar(12) NULL,
		AuthNo varchar(6) NULL,		
		BusnLocation varchar(15) NULL,
		PrcsId int NULL,
		Sts char(2) NULL,
		ExpiryDate varchar(4) NULL,
		TxnTime varchar(12) NULL,
		LtyPAN varchar(30) NULL,
		OfferCd varchar(5) NULL,
		UUID varchar(12) NULL,
		Stan varchar(10) NULL
	)


	-- Create index for field PrcsId and Sts
	insert into #Txn
	(IssNo, BatchId, OrgBatchId, TxnSeq, TxnCd, TxnInd, TermId, TxnDate, CardNo, TxnAmt, Rrn, AuthNo, BusnLocation, 
	PrcsId, Sts, ExpiryDate, TxnTime, OfferCd, Stan)	
	select a.IssNo, BatchId, @BatchId, TxnSeq, a.TxnCd, b.TxnInd, TermId, TxnDate, CardNo, TxnAmt, Rrn, AuthNo, BusnLocation, 
		@PrcsId, null, ExpiryDate, TxnTime, OfferCd, Stan
	from udii_DTxn a
	join atx_txncode b on b.TxnCd = a.TxnCd 
	where a.IssNo = @IssNo and a.BatchId = @BatchId and a.Sts is null

	
	-- Set the Txn to Active Status
	update a
	set a.Sts = 'A'
	from #Txn a
	where a.IssNo = @IssNo and a.BatchId = @BatchId and a.Sts is null

	--Get Count
	select @InsertedRec = @@rowcount


	-- Insert Settle
	insert  #Settle (IssNo, BusnLocation, TermId, TxnCd, TxnInd, Cnt, Amt, OrgBatchId)
	select @IssNo, BusnLocation, TermId, 500, TxnInd, count(*), sum(TxnAmt), @BatchId
	from #Txn
	where Sts = 'A'
	group by IssNo, BusnLocation, TermId, TxnCd, TxnInd

	
	-- create the EDC batchId
	select @Ids = min(Ids) from #Settle
	while @Ids > 0
	begin
		exec @AcqBatchId = NextRunNo @IssNo, 'EDCBatchId'

		update #Settle set 
			BatchId = @AcqBatchId
		where Ids = @Ids

		select @Ids = min(Ids) from #Settle where Ids > @Ids
		if @@rowcount = 0 break
	end

	
	update a
	set BatchId = b.BatchId
	from #Txn a
	join #Settle b on a.BusnLocation = b.BusnLocation and 
	a.TermId = b.TermId and a.TxnInd = b.TxnInd

	------------------
	begin transaction
	------------------

	insert into atx_SourceSettlement
		(AcqNo, BatchId, TxnCd, SettleDate, Cnt, Amt, Pts, BillingAmt, BillingPts, Descp, 
		BusnLocation, TermId, Stan, Rrn, InvoiceNo, OrigBatchNo, AcctNo, Mcc, PrcsId, TxnInd, 
		POSCondCd, ChequeNo, InputSrc, LinkIds, UserId, LastUpdDate, Sts , DealerCd)
	select a.IssNo, a.BatchId, a.TxnCd, @PrcsDate, a.Cnt, a.Amt, 0, 0, 0, b.DBAName, 
		a.BusnLocation, a.TermId, 0, @Rrn, 0, a.OrgBatchId, b.AcctNo, b.Mcc, @PrcsId, a.TxnInd, 
		0, null, 'BATCH', null, system_user, @PrcsDate, @ActiveSts, b.DealerCd
	from #Settle a
	join aac_BusnLocation b on a.IssNo = b.AcqNo and a.BusnLocation = b.BusnLocation


	if @@Error <> 0
	begin

			rollback transaction
			return 1000
	end
	
	
	insert atx_SourceTxn
		(SrcIds, AcqNo, BatchId, TxnCd, CardNo, CardExpiry, LocalDate, LocalTime, TxnDate, 
		ArrayCnt, Qty, Amt, Pts, BillingAmt, BillingPts, SrvcFee, VATAmt, SubsidizedAmt, 
		Descp, BusnLocation, TermId, CrryCd, CtryCd, InvoiceNo, Odometer, Rrn, AuthNo, 
		PrcsId, LinkIds, TxnInd, WithheldUnsettleId, IssBillingAmt,IssBillingPts, IssBatchId, 
		UserId, LastUpdDate, Sts, Stan, DealerCd)
	select c.Ids, a.IssNo, b.BatchId, a.TxnCd, a.CardNo, null /*a.CardExpiry*/, null /*a.LocalDate*/, null /*a.LocalTime*/, substring(a.TxnDate, 1, 4) + '-' + substring(a.TxnDate, 5, 2) + '-' + substring(a.TxnDate, 7, 2) + ' ' + (substring(a.TxnTime, 1, 2) + ':' + substring(a.TxnTime, 3, 2) + ':' + substring(a.TxnTime, 5, 2)), 
		1, null, a.TxnAmt, -a.TxnAmt*100, 0, -a.TxnAmt*100, 0, 0, 0, 
		c.Descp, a.BusnLocation, a.TermId, null /*a.CrryCd*/, null /*a.CtryCd*/, null /*a.InvoiceNo*/, 0 /*a.Odometer*/, a.Rrn, a.AuthNo, 
		@PrcsId, a.TxnSeq, a.TxnInd, 0, 0, 0, 0, 
		system_user, getdate(), @ActiveSts, a.Stan, c.DealerCd
	from #Txn a
	join #Settle b on a.BusnLocation = b.BusnLocation and a.TermId = b.TermId and a.TxnInd = b.TxnInd
	join atx_SourceSettlement c on b.BusnLocation = c.BusnLocation and b.TermId = c.TermId and b.TxnCd = c.TxnCd and c.PrcsId = @PrcsId and b.TxnInd = c.TxnInd and b.BatchId = c.BatchId
	where a.IssNo = @IssNo and a.Sts = @ActiveSts

	
	if @@Error <> 0
	begin

			rollback transaction
			return 1000
	end

	commit Transaction
	
	return 0
		
--	insert atx_SourceTxnDetail
--	(SrcIds, ParentIds, AcqNo, BatchId, Seq, ProdCd, Qty, AmtPts, FastTrack, BillingAmt, BillingPts, SubsidizedAmt, 
--	Descp, BusnLocation, UnitPrice, PlanId, ProdType, LinkIds, LastUpdDate, UserId, Sts)
--	select b.Ids, c.Ids, @IssNo, b.BatchId, 1, 9999, isnull(a.TxnAmt,0) / 1.8, a.TxnAmt, 0, 0, 0, 0, 
--	'General Product', c.BusnLocation, 1.8, 0, 15, a.TxnSeq, getdate(), system_user, @ActiveSts		
--	from #Txn a
--	join atx_SourceTxn b on a.TxnSeq = b.LinkIds and a.BatchId = b.BatchId and a.PrcsId = b.PrcsId
--	join atx_SourceSettlement c on a.BusnLocation = c.BusnLocation and a.TermId = c.TermId and b.PrcsId = c.PrcsId and b.SrcIds = c.Ids
--	where a.Sts = @ActiveSts and a.PrcsId = @PrcsId and a.IssNo = @IssNo

end
GO
