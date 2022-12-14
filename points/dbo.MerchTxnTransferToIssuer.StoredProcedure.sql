USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchTxnTransferToIssuer]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Acquiring Module

Objective	: This stored procedure process transaction in batch 
		  and call MerchTxnProcessing and to finish the rest of the processing.

SP Level	: Primary

-------------------------------------------------------------------------------
When	   Who		CRN		Desc
-------------------------------------------------------------------------------
2002/12/02 Jacky			Initial development
2002/12/19 Sam				Cater for redemption extraction from merchant source.
2003/06/30 Sam				To move InputSrc into atx_Txn.
2003/07/07 Jacky			Transfer WithheldUnsettleId to Issuer.
2003/07/08 Jacky			Use MTIBatchId as BatchId and extract txn from atx_Txn. Only create
							single batch for all the transaction.
2003/07/11 Jacky			Change transaction description to use DBAName, DBACity and DBAState
2003/12/03 Sam				Blocking those IssTxnCd = 0 of atx_TxnCode.
2006/01/16 Chew Pei			Change transaction description to use DBAName + DBACity (eg BSB)
2009/03/10 Darren			Transfer atx_Txn Stan & DealerCd to itx_Txn Stan & DealerCd
2009/03/17 Chew Pei			Commented redemption and reload portion.
							Also, update RefNo in Reflib
							Update iss_Reflib set RefNo = 0 where RefType = 'TxnInd' and RefCd = 'M' (Redemption)
2009/05/15 Chew Pei			Commented left outer join iss_Reflib in line 133 and added (nolock)
2009/08/14 Darren			Added CashAmt, VoucherAmt, PaymtCardPrefix into transaction table
2014/04/08 Humairah			Change DriverCd to Arn
2015/02/10 Sam				Cater for GST.
2019/05/21 Azan				Add IAuthSourceTransactionId and IAuthReferenceTransactionId
							For Points Transfer Txn : Update Descp in its_SourceTxn accordingly 
2020/06/24 Chui             Add SourceId
******************************************************************************************************************/

CREATE	procedure [dbo].[MerchTxnTransferToIssuer] 
	@AcqNo uAcqNo,
	@PrcsId uPrcsId = null
--with encryption 
as
begin
	declare	@rc int,
		@Cnt int,
		@PrcsDate datetime,
		@PrcsName varchar(50),
		@BatchId uBatchId,
		@SrcBatchId uBatchId,
		@ActiveSts uRefCd,
		@RecCnt int,
		@PtsTransferToDescp varchar(100),
		@PtsTransferFromDescp varchar(100)

	set nocount on;
	EXEC @rc = InitProcess
	if @@ERROR <> 0 or @rc <> 0 return 99999

	select @PrcsName = 'MerchTxnTransferToIssuer'
	EXEC TraceProcess @AcqNo, @PrcsName, 'Start'

	select @ActiveSts = RefCd from iss_RefLib (nolock) where IssNo = @AcqNo and RefType = 'MerchBatchSts' and RefNo = 0
	select @PtsTransferToDescp = Descp from itx_TxnCode (nolock) where ShortDescp = 'CRPTS'
	select @PtsTransferFromDescp = Descp from itx_TxnCode (nolock) where ShortDescp = 'DRPTS'

	if @@rowcount = 0 or @@ERROR <> 0 return 95049 --Status Code is invalid

	if @PrcsId is null
	begin
		select @PrcsId = CtrlNo, @PrcsDate = CtrlDate
		from iss_Control (nolock) where IssNo = @AcqNo and CtrlId = 'PrcsId'
	end
	else
	begin
		select @PrcsDate = PrcsDate
		from cmnv_ProcessLog (nolock) where IssNo = @AcqNo and PrcsId = @PrcsId
	end

	-- 2003/07/08 Jacky [B]
	-- To extract online sales, offline sales transaction
--	select a.BatchId, identity (int,1,1) 'Seq' into #SettlementBatch
--	from atx_Settlement a
--	where PrcsId = @PrcsId and Sts = @ActiveSts
--	and not exists (select 1 from udi_Batch b where IssNo = @AcqNo
--	and b.BatchId = a.BatchId)
	-- 2003/07/08 Jacky [E]

	--To extract redemption/reload transactions from source settlement 
	-- 2003/07/08 Jacky - Single batch only
/*	select a.BatchId, identity (int,1,1) 'Seq' into #RedemptionSettlementBatch
	from atx_SourceSettlement a
	join iss_RefLib c on a.AcqNo = c.IssNo and a.TxnInd = c.RefCd and c.RefType = 'TxnInd' and c.RefNo > 0
	where a.PrcsId = @PrcsId and a.Sts = @ActiveSts
	and not exists (select 1 from udi_Batch b where b.IssNo = @AcqNo and b.BatchId = a.BatchId) */

	-----------------
	BEGIN TRANSACTION
	-----------------

	---------------------------------------------
	--Update Descp for points transfer transactions
	---------------------------------------------
	select a.* into #PtsTransferToTxn from atx_Txn a (nolock)
	join atx_TxnCode b (nolock) on b.TxnCd = a.TxnCd 
	join itx_TxnCode c (nolock) on c.TxnCd = b.IssTxnCd and c.ShortDescp = 'CRPTS'
	where a.PrcsId = @PrcsId

	select a.* into #PtsTransferFromTxn from atx_Txn a (nolock)
	join atx_TxnCode b (nolock) on b.TxnCd = a.TxnCd 
	join itx_TxnCode c (nolock) on c.TxnCd = b.IssTxnCd and c.ShortDescp = 'DRPTS'
	where a.PrcsId = @PrcsId

	select a.IAuthSourceTransactionId,count(*)'NoOfTxn' into #Count 
	from #PtsTransferToTxn a 
	join #PtsTransferFromTxn b on a.IAuthSourceTransactionId = b.IAuthReferenceTransactionId 
	group by a.IAuthSourceTransactionId 

	-- Update credit transaction description
	update a 
	set a.Descp = substring(@PtsTransferToDescp+' '+cast(b.CardNo as varchar)+' '+e.FamilyName,1,50)              ---pts transfer one to one
	from #PtsTransferToTxn a 
	join #PtsTransferFromTxn b on b.IAuthReferenceTransactionId = a.IAuthSourceTransactionId 
	join #Count c on c.IAuthSourceTransactionId = a.IAuthSourceTransactionId and c.NoOfTxn = 1 
	join iac_Card d (nolock) on d.CardNo = b.CardNo 
	join iac_Entity e (nolock) on e.EntityId = d.EntityId 

	update a 
	set a.Descp = substring(@PtsTransferToDescp+' '+'Batch'+' '+cast(a.IAuthSourceTransactionId as varchar),1,50)  ---pts transfer one to many 
	from #PtsTransferToTxn a 
	join #Count b on a.IAuthSourceTransactionId = b.IAuthSourceTransactionId and b.NoOfTxn > 1

	-- Update debit transaction description
	update a 
	set a.Descp = substring(@PtsTransferFromDescp+' '+cast(b.CardNo as varchar)+' '+d.FamilyName,1,50)
	from #PtsTransferFromTxn a 
	join #PtsTransferToTxn b on b.IAuthSourceTransactionId = a.IAuthReferenceTransactionId 
	join iac_Card c (nolock) on c.CardNo = b.CardNo 
	join iac_Entity d (nolock) on d.EntityId = c.EntityId 
  

	------------------------------------
	-- Online and Offline Transaction --
	------------------------------------

	EXEC @BatchId = dbo.NextRunNo @AcqNo, 'MTIBatchId'

	insert itx_SourceTxn 
		(IssNo, BatchId, TxnSeq, TxnCd, AcctNo, CardNo, AuthCardNo,
		LocalTxnDate, TxnDate, LocalTxnAmt, SettleTxnAmt, BillingTxnAmt,
		Pts, PromoPts, Descp, BusnLocation, Mcc, TermId, Rrn, Stan, AppvCd,
		CrryCd, Arn, Odometer, ExceptionCd, BillMethod, PlanId, PrcsId, InputSrc, SrcTxnId,
		-- 2003/07/07 Jacky - Transfer WithheldUnsettle to issuer
		RefTxnId, AuthTxnId, OnlineTxnId, WithheldUnsettleId, OnlineInd, UserId, DealerCd, CashAmt, VoucherAmt, PaymtCardPrefix,
--2015/02/10B
		VATNo, VATAmt, ExternalTransactionId, IAuthSourceTransactionId, IAuthReferenceTransactionId, SourceId)  
--2015/02/10E
	-- 2003/07/08 Jacky - Change a.BatchId to @BatchId
	select	@AcqNo, @BatchId, a.Ids, c.IssTxnCd, d.AcctNo, a.CardNo, a.AuthCardNo,
		null, a.TxnDate, a.Amt, a.Amt, a.IssBillingAmt,	-- Changes from a.BillingAmt to a.IssBillingAmt
		abs(a.IssBillingPts), 0,	-- Changes from a.BillingPts to a.IssBillingPts
		-- 2003/07/11 Jacky
		CASE when isnull(g.Descp,'') <> '' then g.Descp when isnull(h.Descp,'') <> '' then h.Descp else 
		substring(isnull(e.DBAName,space(1)), 1, 25)+replicate(' ', 25-len(substring(isnull(e.DBAName,space(1)), 1, 25)))+isnull(e.DBACity, space(1)) END, 
		--substring(isnull(g.Descp,space(1)), 1, 13)+replicate(' ', 13-len(substring(isnull(g.Descp,space(1)), 1, 13)))+isnull(e.DBAState,space(1)),
		a.BusnLocation, b.Mcc, a.TermId, a.Rrn, a.Stan, a.AuthNo,	-- 2009/03/10 Darren - used atx_Txn stan instead of atx_Settlement stan
		--2003/06/30B
		--b.CrryCd, b.DriverCd, b.Odometer, b.ExceptionCd, null, null, b.PrcsId, 'ACQ', null,
		--2014/04/08H
		--a.CrryCd, a.DriverCd, a.Odometer, a.ExceptionCd, null, null, @PrcsId, b.InputSrc, null,
		a.CrryCd, a.Arn, a.Odometer, a.ExceptionCd, null, null, @PrcsId, b.InputSrc, null,
		--2003/06/30E
		-- 2003/07/07 Jacky - Transfer WithheldUnsettle to issuer
		null, a.Ids, null, a.WithheldUnsettleId, null, a.UserId, a.DealerCd, a.CashAmt, a.VoucherAmt, a.PaymtCardPrefix,
--2015/02/10B
		a.VATNo, isnull(a.VATAmt,0), a.ExternalTransactionId, a.IAuthSourceTransactionId, a.IAuthReferenceTransactionId, a.SourceId
--2015/02/10E		
	-- 2003/07/08 Jacky [B]
	from atx_Txn a (nolock)
	join atx_Settlement b (nolock) on b.BatchId = a.BatchId
	--2003/12/03B
	--join atx_TxnCode c on c.AcqNo = @AcqNo and c.TxnCd = b.TxnCd
	join atx_TxnCode c (nolock) on c.AcqNo = @AcqNo and a.TxnCd = c.TxnCd and isnull(c.IssTxnCd,0) > 0
	--2003/12/03E 
	join iac_Card d (nolock) on d.CardNo = a.CardNo
	join aac_BusnLocation e (nolock) on e.AcqNo = @AcqNo and e.BusnLocation = b.BusnLocation
	join iss_RefLib f (nolock) on f.IssNo = @AcqNo and f.RefType = 'TxnInd' and f.RefCd = a.TxnInd and f.RefNo = 0
	left join #PtsTransferToTxn g (nolock) on g.Ids = a.Ids 
	left join #PtsTransferFromTxn h (nolock) on h.Ids = a.Ids
	-- left outer join iss_RefLib g on g.IssNo = @AcqNo and g.RefType = 'City' and g.RefCd = e.DBACity -- CP Commented as it is not used
	where a.PrcsId = @PrcsId and a.IssBatchId is null

	if @@ERROR <> 0
	begin
		rollback transaction
		return 70320	-- Failed to delete SourceTxn
	end

	insert itxv_SourceTxnProductDetail 
		(IssNo, BatchId, ParentSeq, TxnSeq, RefTo, ProdCd, LocalTxnAmt,
		SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Qty, SrcTxnId, PricePerUnit, PlanId, Sts,
--2015/02/10B
		BaseAmt, VATAmt, VATCd, VATRate)
--2015/02/10E
	select @AcqNo, @BatchId, b.SrcIds, b.Seq, 'P', b.ProdCd, b.AmtPts,
		b.AmtPts, 0, abs(b.BillingPts), 0, b.Qty, b.Ids, b.UnitPrice, null, @ActiveSts,
--2015/02/10B
		isnull(b.BaseAmt,0), isnull(b.VATAmt,0), b.VATCd, isnull(b.VATRate,0)
--2015/02/10E		
	from atx_Txn a (nolock)	-- (Darren) added unit price column
	join atx_TxnDetail b (nolock) on b.SrcIds = a.Ids
	join atx_Settlement c (nolock) on c.BatchId = a.BatchId
	--2003/12/03B
	join atx_TxnCode d (nolock) on c.AcqNo = d.AcqNo and a.TxnCd = d.TxnCd and isnull(d.IssTxnCd,0) > 0
	--2003/12/03E
	where a.PrcsId = @PrcsId and a.IssBatchId is null

	if @@ERROR <> 0
	begin
		rollback transaction
		return 70321	-- Failed to delete SourceTxnDetail
	end

	update a
	set a.IssBatchId = @BatchId
	from atx_Txn a
	join itx_SourceTxn b (nolock) on b.BatchId = @BatchId and b.TxnSeq = a.Ids
	where a.PrcsId = @PrcsId

	if @@ERROR <> 0
	begin
		rollback transaction
		return 70396	-- Failed to update Transaction Detail
	end

	-- Create udi_Batch if there are records extracted
	select @RecCnt = 0
	select @RecCnt = count(*) from itx_SourceTxn (nolock) where BatchId = @BatchId

	if @RecCnt > 0
	begin
		insert udi_Batch 
			(IssNo, BatchId, SrcName, FileName, FileSeq, DestName, FileDate,
			LoadedRec, RecCnt, Direction, PrcsId, PrcsDate, Sts)
		select @AcqNo, @BatchId, 'ACQUIRER', 'TRANSACTION',
			(select isnull(max(FileSeq), 0)+1 from udi_Batch
				where IssNo = @AcqNo and SrcName = 'ACQUIRER' and FileName = 'TRANSACTION'),
			'HOST', @PrcsDate, @RecCnt, 0, 'I', @PrcsId, null, 'L'

		if @@ERROR <> 0
		begin
			rollback transaction
			return 70395	-- Failed to create new batch
		end
	end

/*-- <************ Commented this portion as it is not being used ********************>
	-----------------------------------
	-- Redemption/Reload Transaction --
	-----------------------------------

	EXEC @SrcBatchId = NextRunNo @AcqNo, 'MTIBatchId'

	--Direct extract transaction from source settlement,txn,txndetail is because
	--merchant settlement posting process does not pick up redemption transaction.
	--Thus, we will extract all the transaction from merchant source into issuer source file.

	insert itx_SourceTxn (IssNo, BatchId, TxnSeq, TxnCd, AcctNo, CardNo, AuthCardNo,
		LocalTxnDate, TxnDate, LocalTxnAmt, SettleTxnAmt, BillingTxnAmt,
		Pts, PromoPts, Descp, BusnLocation, Mcc, TermId, Rrn, Stan, AppvCd,
		CrryCd, Arn, Odometer, ExceptionCd, BillMethod, PlanId, PrcsId, InputSrc, SrcTxnId,
		RefTxnId, AuthTxnId, OnlineTxnId, WithheldUnsettleId, OnlineInd, UserId,
		VATNo, VATAmt)
	select	@AcqNo, @SrcBatchId, b.Ids, d.IssTxnCd, e.AcctNo, b.CardNo, b.AuthCardNo,
--		null, b.TxnDate, 0,0,0,
--		b.Amt, 0,
		null, b.TxnDate, b.Amt, b.Amt, 0,
		b.BillingPts, 0,
		substring(c.DBAName, 1, 25)+replicate(' ', 25-len(substring(c.DBAName, 1, 25)))+
		substring(c.DBACity, 1, 13)+replicate(' ', 13-len(substring(c.DBACity, 1, 13)))+c.DBAState,
		b.BusnLocation, a.Mcc, b.TermId, b.Rrn, a.Stan, b.AuthNo,
		b.CrryCd, b.DriverCd, b.Odometer, b.ExceptionCd, null, null, @PrcsId, a.InputSrc, null,
--		null, b.Ids, null, b.WithheldUnsettleId, null, b.UserId
		null, null, null, b.WithheldUnsettleId, null, b.UserId,
		b.VATNo, isnull(b.VATAmt,0)
	from atx_SourceSettlement a
	join atx_SourceTxn b on b.BatchId = a.BatchId
	join aac_BusnLocation c on c.AcqNo = @AcqNo and c.BusnLocation = b.BusnLocation
	--2003/12/03B
	--join atx_TxnCode d on d.AcqNo = @AcqNo and d.TxnCd = b.TxnCd
	join atx_TxnCode d on d.AcqNo = @AcqNo and d.TxnCd = b.TxnCd and isnull(d.IssTxnCd,0) > 0
	--2003/12/03E
	join iac_Card e on e.CardNo = b.CardNo
	join iss_RefLib f on f.IssNo = @AcqNo and f.RefType = 'TxnInd' and f.RefCd = a.TxnInd and f.RefNo > 0
--	join iss_RefLib f on f.IssNo = @AcqNo and f.RefType = 'TxnInd' and f.RefCd = a.TxnInd and f.RefNo = 0
	where a.PrcsId = @PrcsId and a.Sts = @ActiveSts

	if @@ERROR <> 0
	begin
		rollback transaction
		return 70320	-- Failed to delete SourceTxn
	end

	insert itxv_SourceTxnRewardDetail (IssNo, BatchId, ParentSeq, TxnSeq, RefTo, RewardId, LocalTxnAmt,
		SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Qty, SrcTxnId, PlanId, Sts,
		BaseAmt, VATAmt, VATCd, VATRate)
	select	@AcqNo, @SrcBatchId, c.SrcIds, c.Seq, 'R', c.ProdCd, c.AmtPts,
		c.AmtPts, 0, c.BillingPts, 0, c.Qty, c.Ids, null, @ActiveSts,
		isnull(c.BaseAmt,0), isnull(c.VATAmt,0), ltrim(rtrim(c.VATCd)), isnull(c.VATRate,0)
	from atx_SourceSettlement a
	join atx_SourceTxn b on b.BatchId = a.BatchId
	join atx_SourceTxnDetail c on c.SrcIds = b.Ids
	--2003/12/03B
	join atx_TxnCode d on a.AcqNo = d.AcqNo and b.TxnCd = d.TxnCd and isnull(d.IssTxnCd,0) > 0
	--2003/12/03E
	where a.PrcsId = @PrcsId and a.Sts = @ActiveSts

	if @@ERROR <> 0
	begin
		rollback transaction
		return 70266	-- Failed to insert into #SourceTxnDetail
	end

	-- Create udi_Batch if there are records extracted
	select @RecCnt = 0
	select @RecCnt = count(*) from itx_SourceTxn where BatchId = @SrcBatchId

	if @RecCnt > 0
	begin
		insert udi_Batch (IssNo, BatchId, SrcName, FileName, FileSeq, DestName, FileDate,
			LoadedRec, RecCnt, Direction, PrcsId, PrcsDate, Sts)
		select @AcqNo, @SrcBatchId, 'ACQUIRER', 'TRANSACTION',
			(select isnull(max(FileSeq), 0)+1 from udi_Batch
				where IssNo = @AcqNo and SrcName = 'ACQUIRER' and FileName = 'TRANSACTION'),
			'HOST', @PrcsDate, @RecCnt, 0, 'I', @PrcsId, null, 'L'

		if @@ERROR <> 0
		begin
			rollback transaction
			return 70395	-- Failed to create new batch
		end
	end

	-- Delete extracted transactions
	delete a from atx_SourceSettlement a
	join iss_RefLib b on b.IssNo = @AcqNo and b.RefType = 'TxnInd' and b.RefCd = a.TxnInd and b.RefNo > 0
	where a.PrcsId = @PrcsId and a.Sts = @ActiveSts

	if @@ERROR <> 0
	begin
		rollback transaction
		return 70392	-- Failed to delete Settlement
	end

	delete a from atx_SourceTxn a
	join itx_SourceTxn b on b.BatchId = @SrcBatchId and b.TxnSeq = a.Ids

	if @@ERROR <> 0
	begin
		rollback transaction
		return 70320	-- Failed to delete SourceTxn
	end

	delete a from atx_SourceTxnDetail a
	join itxv_SourceTxnProductDetail b on b.BatchId = @SrcBatchId and b.ParentSeq = a.SrcIds

	if @@ERROR <> 0
	begin
		rollback transaction
		return 70321	-- Failed to delete SourceTxnDetail
	end

-- <************************************ END **********************************/

	------------------
	COMMIT TRANSACTION
	------------------
end
GO
