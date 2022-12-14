USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchTxnProcessing]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/*****************************************************************************************************************        
        
Copyright : CardTrend Systems Sdn. Bhd.        
Modular  : CardTrend Card Management System (CCMS)- Acquiring Module        
        
Objective : This stored procedure will post transactions (batch and instant) into cardholder's account.        
        
Required tables : #SourceTxn (Temporary table holds the transaction)        
    #SourceTxnDetail (Temporary table holds the transaction detail)        
    acq_MTDTxnCd (Month-To-Date for transaction cd)        
    acq_MTDProdCd (Month-To-Date for Product cd)        
    acq_MTDSettlement (Month-To-Date for Batch Settlement)        
        
Calling Sp : BatchMerchTxnProcessing, OnlineMerchTxnProcessing        
        
Leveling : Second level        
------------------------------------------------------------------------------------------------------------------        
When  Who  CRN  Desc        
------------------------------------------------------------------------------------------------------------------        
2001/10/02 Jacky   Initial development        
2002/11/25 Sam    Reconciliation        
2003/03/09 Sam    Fixes.        
2003/07/14 Sam    To incl. subsidized amount.        
2005/11/13 Chew Pei  Added criteria a.RefTo = 'P' when select from #SourceTxnDetail        
2008/06/11 Peggy   Add matching         
2009/03/17 Darren   Only calculate srv fee if source billing amount > 0        
2009/05/21 Chew Pei  Added Stan into atx_Txn        
2009/06/12 Chew Pei        
2009/08/14 Darren   Added CashAmt, VoucherAmt, PaymtCardPrefix into transaction table        
2009/08/26 Darren   Changes on creating #SourceTxn & #SourceTxnDetail table        
2015/02/10 SAM    Cater for GST.       
2019/05/21 Azan    Insert IAuthSourceTransactionId and IAuthReferenceTransactionId    
2020/06/24 Chui      Add SourceId
******************************************************************************************************************/        
        
CREATE	procedure [dbo].[MerchTxnProcessing]
	@AcqNo uAcqNo, 
	@PrcsId uPrcsId
--with encryption 
as
begin
	declare @PaymtTxnCategory uTxnCd,
		@PrcsDate datetime,
		@ActiveSts char(1),
		@Date varchar(6),
		@SysDate datetime,
		@PrcsName varchar(50),
		@Rc int

	set nocount on;

	select @PrcsName = 'MerchTxnProcessing'
	EXEC TraceProcess @AcqNo, @PrcsName, 'Start'

	EXEC @Rc = dbo.InitProcess

	if @@ERROR <> 0 or @Rc <> 0 return 99999

	if @PrcsId is null
	begin
		select @PrcsDate = CtrlDate,
			@Date = convert(varchar(6), CtrlDate, 112)
		from iss_Control (nolock)
		where IssNo = @AcqNo and CtrlId = 'PrcsId'

		if @@ROWCOUNT = 0 or @@ERROR <> 0 return 60056 --Process Id in CCMSTools not found
	end
	else
	begin
		select @PrcsDate = PrcsDate,
			@Date = convert(varchar(6), PrcsDate, 112)
		from cmnv_ProcessLog (nolock)
		where IssNo = @AcqNo

		if @@ROWCOUNT = 0 or @@ERROR <> 0 return 60056 --Process Id in CCMSTools not found
	end

	select @ActiveSts = RefCd			from iss_RefLib (nolock) where IssNo = @AcqNo and RefType = 'MerchBatchSts' and RefNo = 0

	if @@ROWCOUNT = 0 or @@ERROR <> 0 return 95049 --Status Code is invalid
        
	--------------------------------------------------------------------------------
	SAVE TRANSACTION MerchTxnProcessing
	--------------------------------------------------------------------------------

	insert atx_Settlement 
		(TxnCd, BusnLocation, TermId, SettleDate, InputSrc, LinkIds,
		OrigBatchNo, InvoiceNo, Qty, Amt, Pts, SrvcFee, BillingAmt, BillingPts,
		Stan, Sts, PrcsId, BatchId, AcqNo, AcctNo, Mcc, TxnInd, UserId,
		LastUpdDate, Descp, ChequeNo, ChequeDate, CycId, CrryCd, CtryCd,
		IssChequeNo, IssChequeDate, IssChequeSettleDate, DealerCd)
	select TxnCd, BusnLocation, isnull(TermId, ''), SettleDate, InputSrc, LinkIds,
		--2003/03/09B
		--OrigBatchNo, InvoiceNo, Cnt, Amt, a.Pts, b.SettleTxnAmt-b.BillingTxnAmt, b.BillingTxnAmt, b.Pts,
		OrigBatchNo, InvoiceNo, Cnt, b.SettleTxnAmt, a.Pts, 
			case 
				when isnull(b.BillingTxnAmt,0) = 0 then 0
				else b.SettleTxnAmt-b.BillingTxnAmt end,
			b.BillingTxnAmt, b.Pts,
		--2003/03/09E
		Stan, Sts, PrcsId, BatchId, AcqNo, AcctNo, Mcc, TxnInd, UserId,
		getdate(), Descp, ChequeNo, null, null, null, null,
		null, null, null, a.DealerCd
	from atx_SourceSettlement a (nolock)
	join (select RefTxnId, sum(SettleTxnAmt) 'SettleTxnAmt', 
				sum(BillingTxnAmt) 'BillingTxnAmt', sum(Pts) 'Pts' 
				from #SourceTxn b where PrcsId = @PrcsId group by RefTxnId) as b on a.Ids = b.RefTxnId
	where a.Sts = @ActiveSts and a.PrcsId = @PrcsId

	if @@ERROR <> 0
	begin
		rollback transaction MerchTxnProcessing
		return 70394	-- Failed to add Settlement
	end
                  
	 -- Create Transaction        
	 insert atx_Txn         
		  (SrcIds, BatchId, TxnCd, CardNo, CardExpiry, AuthCardNo, AuthCardExpiry,        
		  LocalDate, LocalTime, TxnDate, Qty, Amt, Pts, BillingAmt, BillingPts, Descp,        
		  BusnLocation, TermId, CrryCd, CtryCd, InvoiceNo, DriverCd, Odometer, Rrn,        
		  Arn, AuthNo, ExceptionCd, BillMethod, PlanId, PrcsId, LinkIds, WithheldUnsettleId,        
	--2003/07/14B        
	  --TxnInd, IssLinkIds, IssTxnCd, IssBillingAmt, IssBillingPts, UserId, LastUpdDate, Sts)        
		  TxnInd, IssLinkIds, IssTxnCd, IssBillingAmt, IssBillingPts, UserId, LastUpdDate, Sts, SubsidizedAmt, Stan, DealerCd,        
		  CashAmt, VoucherAmt, PaymtCardPrefix,        
	--2015/02/10B        
		  VATNo, VATAmt, ExternalTransactionId, IAuthSourceTransactionId, IAuthReferenceTransactionId, SourceId)     
	--2015/02/10E        
	--2003/07/14E        
	 select c.Ids, a.BatchId, a.TxnCd, a.CardNo, a.CardExpiry, a.AuthCardNo, a.AuthCardExpiry,        
		  a.LocalDate, a.LocalTime, a.TxnDate, a.Qty, b.SettleTxnAmt, a.Pts, b.BillingTxnAmt, b.Pts, a.Descp,        
		  a.BusnLocation, a.TermId, a.CrryCd, a.CtryCd, a.InvoiceNo, a.DriverCd, a.Odometer, a.Rrn,        
		  a.Arn, a.AuthNo, a.ExceptionCd, b.BillMethod, b.PlanId, a.PrcsId, a.Ids, a.WithheldUnsettleId,        
	--2003/07/14B        
	  --a.TxnInd, null, null, a.IssBillingAmt, a.IssBillingPts, system_user, getdate(), a.Sts        
		  a.TxnInd, null, null, a.IssBillingAmt, a.IssBillingPts, system_user, getdate(), a.Sts, b.SubsidizedAmt, a.Stan, a.DealerCd,        
		  a.CashAmt, a.VoucherAmt, a.PaymtCardPrefix,        
	--2015/02/10B        
		  a.VATNo, isnull(a.VATAmt,0), a.ExternalTransactionId, a.IAuthSourceTransactionId, a.IAuthReferenceTransactionId , a.SourceId              
	--2015/02/10E          
	--2003/07/14B        
	 from atx_SourceTxn a (nolock)        
	 join #SourceTxn b on a.Ids = b.TxnSeq and a.PrcsId = b.PrcsId        
	 join atx_Settlement c (nolock) on b.BatchId = c.BatchId and b.PrcsId = c.PrcsId and c.BusnLocation = a.BusnLocation and c.TermId = a.TermId --2008/06/11        
	 where a.PrcsId = @PrcsId        
        
	 if @@ERROR <> 0        
	 begin        
		 rollback transaction MerchTxnProcessing        
		 return 70272 -- Failed to insert transaction        
	 end        
        
--2003/07/14B --removed. merchant does not support redemption portion.        
/*        
	-- Create Redemption Transaction
	insert atx_Txn 
	(SrcIds, BatchId, TxnCd, CardNo, CardExpiry, AuthCardNo, AuthCardExpiry,
		LocalDate, LocalTime, TxnDate, Qty, Amt, Pts, BillingAmt, BillingPts, Descp,
		BusnLocation, TermId, CrryCd, CtryCd, InvoiceNo, DriverCd, Odometer, Rrn,
		Arn, AuthNo, ExceptionCd, BillMethod, PlanId, PrcsId, LinkIds, WithheldUnsettleId,
		TxnInd, IssLinkIds, IssTxnCd, IssBillingAmt, IssBillingPts, UserId, LastUpdDate, Sts)
	select b.Ids, a.BatchId, a.TxnCd, a.CardNo, a.CardExpiry, a.AuthCardNo, a.AuthCardExpiry,
		a.LocalDate, a.LocalTime, a.TxnDate, a.Qty, a.Amt, a.Pts, 0, 0, a.Descp,
		a.BusnLocation, a.TermId, a.CrryCd, a.CtryCd, a.InvoiceNo, a.DriverCd, a.Odometer, a.Rrn,
		a.Arn, a.AuthNo, a.ExceptionCd, null, null, a.PrcsId, a.Ids, a.WithheldUnsettleId,
		a.TxnInd, null, null, a.IssBillingAmt, a.IssBillingPts, system_user, getdate(), a.Sts
	from atx_SourceTxn a, atx_Settlement b
	where a.AcqNo = @AcqNo and a.PrcsId = b.PrcsId and a.Sts = b.Sts and a.TxnInd in ('M','P')
	and b.BatchId = a.BatchId and b.Sts = @ActiveSts

	if @@ERROR <> 0
	begin
		rollback transaction MerchTxnProcessing
		return 70272	-- Failed to insert transaction
	end      
*/        
--2003/07/14E        
        
	-- Create Transaction Detail
	insert atx_TxnDetail 
		(SrcIds, ParentIds, AcqNo, BatchId, Seq, ProdCd, Qty,
		AmtPts, FastTrack, BillingAmt, BillingPts, Descp, BusnLocation, UnitPrice,
		PlanId, ProdType, LinkIds, LastUpdDate,
--2015/02/10B
		BaseAmt, VATAmt, VATCd, VATRate)
--2015/02/10E		
	select c.Ids, c.SrcIds, @AcqNo, a.BatchId, a.Seq, a.ProdCd, a.Qty,
		a.AmtPts, a.FastTrack, b.BillingTxnAmt, b.Pts, a.Descp, a.BusnLocation, a.UnitPrice,
		b.PlanId, a.ProdType, a.LinkIds, getdate(),
--2015/02/10B
		isnull(a.BaseAmt,0), isnull(a.VATAmt,0), ltrim(rtrim(a.VATCd)), isnull(a.VATRate,0)
--2015/02/10E		
	from atx_SourceTxnDetail a (nolock), #SourceTxnDetail b, atx_Txn c (nolock)
	where a.SrcIds = b.ParentSeq and a.Seq = b.TxnSeq and c.LinkIds = a.SrcIds and c.PrcsId = @PrcsId

	if @@ERROR <> 0
	begin
		rollback transaction MerchTxnProcessing
		return 70273	-- Failed to insert transaction detail
	end    
        
--2003/07/14B --remove. merchant does not support redemption portion.
/*
	-- Create Redemption Transaction Detail
	insert atx_TxnDetail 
	(SrcIds, ParentIds, AcqNo, BatchId, Seq, ProdCd, Qty,
		AmtPts, FastTrack, BillingAmt, BillingPts, Descp, BusnLocation, UnitPrice,
		PlanId, ProdType, LinkIds, LastUpdDate)
	select a.SrcIds, a.ParentIds, a.AcqNo, a.BatchId, a.Seq, a.ProdCd, a.Qty,
		a.AmtPts, a.FastTrack, 0, 0, a.Descp, a.BusnLocation, a.UnitPrice,
		null, a.ProdType, a.LinkIds, getdate()
	from atx_SourceTxnDetail a, atx_SourceTxn b, atx_Txn c
	where b.AcqNo = @AcqNo and b.PrcsId = @PrcsId and b.Sts = @ActiveSts and b.TxnInd in ('M','P')
	and b.Ids = a.SrcIds and c.LinkIds = a.SrcIds

	if @@ERROR <> 0
	begin
		rollback transaction MerchTxnProcessing
		return 70273	-- Failed to insert transaction detail
	end
*/
--2003/07/14B --Removal begining from     
        
	---------------------        
	-- Update MTD Info --        
	---------------------        
        
	--By TxnCd
	update a
	set a.Cnt = a.Cnt + b.Cnt,
		a.Amt = a.Amt + b.Amt,
		a.BillingAmt = a.BillingAmt + b.BillingAmt,
		a.BillingPts = a.BillingPts + b.Pts,
		a.LastUpdDate = @SysDate
	from acq_MTDTxnCd a
	join ( select a.BusnLocation, isnull(a.TermId, '') 'TermId', b.TxnInd, a.TxnCd, 
		isnull(count(*), 0) 'Cnt', isnull(sum(a.SettleTxnAmt), 0) 'Amt',
		isnull(sum(a.BillingTxnAmt), 0) 'BillingAmt', isnull(sum(a.Pts), 0) 'Pts'
		from #SourceTxn a
		join atx_TxnCode b (nolock) on a.TxnCd = b.TxnCd
		where a.PrcsId = @PrcsId
		group by BusnLocation, TermId, b.TxnInd, a.TxnCd ) as b on a.BusnLocation = b.BusnLocation and a.TermId = b.TermId and a.TxnInd = b.TxnInd and a.TxnCd = b.TxnCd
	where a.PrcsDate = @Date

	if @@ERROR <> 0
	begin
		rollback transaction MerchTxnProcessing
		return 70394	-- Failed to update acq_MTDTxnCd
	end

	insert acq_MTDTxnCd 
		(AcqNo, PrcsDate, BusnLocation, TermId, TxnInd, TxnCd, Cnt, Amt, BillingAmt, BillingPts)
	select	@AcqNo, @Date, a.BusnLocation, isnull(a.TermId, ''), b.TxnInd, a.TxnCd, isnull(count(*), 0), isnull(sum(a.SettleTxnAmt),0), isnull(sum(a.BillingTxnAmt), 0), isnull(sum(a.Pts), 0)
	from #SourceTxn a 
	join atx_TxnCode b (nolock) on a.TxnCd = b.TxnCd
	where not exists ( select 1 from acq_MTDTxnCd c (nolock) where c.BusnLocation = a.BusnLocation
			and c.TermId = isnull(a.TermId, '') 
			and c.TxnInd = b.TxnInd 
			and c.TxnCd = a.TxnCd
			and c.PrcsDate = @Date )
	group by a.BusnLocation, a.TermId, b.TxnInd, a.TxnCd

	if @@ERROR <> 0
	begin
		rollback transaction MerchTxnProcessing
		return 70393	-- Failed to add acq_MTDTxnCd
	end     
        
	--By TxnCd
	update a
	set a.Cnt = a.Cnt + b.Cnt,
		a.Amt = a.Amt + b.Amt,
		a.BillingAmt = a.BillingAmt + b.BillingAmt,
		a.BillingPts = a.BillingPts + b.Pts,
		a.LastUpdDate = @SysDate
	from acq_MTDProdCd a
	join ( select b.BusnLocation, isnull(b.TermId, '') 'TermId', a.RefKey, 
		isnull(count(*), 0) 'Cnt', isnull(sum(a.SettleTxnAmt), 0) 'Amt',
		isnull(sum(a.BillingTxnAmt), 0) 'BillingAmt', isnull(sum(a.Pts), 0) 'Pts'
		from #SourceTxnDetail a
		join #SourceTxn b on a.ParentSeq = b.TxnSeq and b.PrcsId = @PrcsId
		where a.RefTo = 'P'
		group by b.BusnLocation, b.TermId, a.RefKey
		 ) as b on a.BusnLocation = b.BusnLocation and a.TermId = b.TermId and a.ProdCd = b.RefKey
	where a.PrcsDate = @Date

	if @@ERROR <> 0
	begin
		rollback transaction
		return 70384	-- Failed to update acq_MTDProdCd
	end

	insert acq_MTDProdCd 
		(AcqNo, PrcsDate, BusnLocation, TermId, ProdCd, Cnt, Amt, BillingAmt, BillingPts)
	select	@AcqNo, @Date, b.BusnLocation, isnull(b.TermId, ''), a.RefKey, isnull(count(*), 0), isnull(sum(a.SettleTxnAmt), 0), isnull(sum(a.BillingTxnAmt), 0), isnull(sum(a.Pts), 0)
	from #SourceTxnDetail a
	join #SourceTxn b on a.ParentSeq = b.TxnSeq and b.PrcsId = @PrcsId
	where not exists ( select 1 from acq_MTDProdCd c where c.BusnLocation = b.BusnLocation 
			and c.TermId = isnull(b.TermId, '') 
			and c.ProdCd = a.RefKey 
			and c.PrcsDate = @Date )
			and a.RefTo = 'P'
	group by b.BusnLocation, b.TermId, a.RefKey

	if @@ERROR <> 0
	begin
		rollback transaction
		return 70384	-- Failed to update acq_MTDProdCd
	end       
        
/*	--Accumulate daily txn detail value into month-to-date settlement
	insert acq_MTDSettlement
	( AcqNo, BusnLocation, BatchId, TxnInd, CycId, CycDate, Cnt, Amt, BillingAmt, BillingPts, LastUpdDate )
	select a.AcqNo, a.BusnLocation, a.BatchId, a.TxnInd, null, null, isnull(count(*), 0), isnull(sum(SettledTxnAmt), 0), isnull(sum(BillingTxnAmt), 0), isnull(sum(Pts), 0), @SysDate
	from #SourceTxn a
	group by a.AcqNo, a.BusnLocation, a.BatchId, a.TxnInd
*/
	--------------------------------
	-- Clearing un-wanted records --
	--------------------------------   
        
/*select * from #Sourcetxn        
select * from #sourcetxndetail        
select * from atx_settlement        
select * from atx_Txn where prcsid = @prcsid        
select * from atx_txndetail        
select * from acq_mtdtxncd        
select * from acq_mtdprodcd        
select * from atx_sourcetxn        
select * from atx_sourcetxndetail        
rollback transaction merchbatchtxnprocessing        
return*/        
	-- Delete Posted transactions
	delete a
	from atx_SourceSettlement a, (select RefTxnId from #SourceTxn group by RefTxnId) b
	where a.Ids = b.RefTxnId and a.PrcsId = @PrcsId

	if @@ERROR <> 0
	begin
		rollback transaction MerchTxnProcessing
		return 70392	-- Failed to delete Settlement
	end

	delete a
	from atx_SourceTxn a, #SourceTxn b
	where a.Ids = b.TxnSeq and a.PrcsId = @PrcsId

	if @@ERROR <> 0
	begin
		rollback transaction MerchTxnProcessing
		return 70320	-- Failed to delete SourceTxn
	end

	-- Delete Posted detail transaction
	delete a
	from atx_SourceTxnDetail a, #SourceTxnDetail b
	where a.SrcIds = b.ParentSeq and a.Seq = b.TxnSeq

	if @@ERROR <> 0
	begin
		rollback transaction MerchTxnProcessing
		return 70321	-- Failed to delete SourceTxnDetail
	end

	EXEC dbo.TraceProcess @AcqNo, @PrcsName, 'End'   
        
--	if exists (select 1 from itx_SourceTxn where IssNo = @IssNo and BatchId = @BatchId)
--		return 95159	-- Not all record has been processed

--	if exists (select 1 from itxv_SourceTxnProductDetail where IssNo = @IssNo and BatchId = @BatchId)
--		return 95159	-- Not all record has been processed

	return 54025	-- Transaction processing completed successfully    
end
GO
