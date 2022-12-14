USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchUnsettleBatchMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	: Cardtrend Systems Sdn. Bhd.
Modular		: Cardtrend Card Management System (CCMS)- Acquiring Module

Objective	: 
SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2007/08/16 Sam		           Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[MerchUnsettleBatchMaint]
	@Func varchar(10),
	@AcqNo uAcqNo,
	@Ids uTxnId,
	@BusnLocation uMerchNo,
	@BatchId uBatchId,
	@TermId uTermId,
	@Cnt smallint,
	@Amt money,
	@Pts money,
	@BillingAmt money,
	@BillingPts money,
	@SettleDate varchar(30),
	@TxnCd uTxnCd,
	@Descp uDescp50

  as
begin
	declare @PrcsId uPrcsId, @PrcsDate datetime, @Mcc varchar(5), @SysDate datetime, @tDescp nvarchar(50),
			@Ublc varchar(5), @ActiveSts varchar(5), @AcctNo bigint, @TxnInd varchar(5)

	set nocount on

	select @SysDate = getdate(),
		@Cnt = isnull(@Cnt,0),
		@Amt = isnull(@Amt,0),
		@Pts = isnull(@Pts,0),
		@BillingAmt = isnull(@BillingAmt,0),
		@BillingPts = isnull(@BillingPts,0)

	if isnull(@Amt,0) = 0 and isnull(@BillingPts,0) = 0 return 95125 --Check counter/ litre or amount

	select @PrcsId = CtrlNo,
		@PrcsDate = CtrlDate
	from iss_Control where IssNo = @AcqNo and CtrlId = 'PrcsId'

	if @@error <> 0 return 95098 --Unable to retrieve information from iss_Control table

	if (datediff(dd,@PrcsDate,@SysDate)) = 0
		select @PrcsId = @PrcsId
	else
		select @PrcsId = @PrcsId + datediff(dd,@PrcsDate,@SysDate)	

	select @AcctNo = AcctNo,
		@Mcc = Mcc
	from aac_BusnLocation (nolock)
	where AcqNo = @AcqNo and BusnLocation = @BusnLocation

	if @AcctNo is null return 60048	--Merchant Account not found

	if @TermId is not null
	begin
		if not exists (select 1 from atm_TerminalInventory where AcqNo = @AcqNo and BusnLocation = @BusnLocation and TermId = @TermId)
			return 60039 --Terminal Id for this Merchant not found
	end

	select @TxnInd = TxnInd,
		@tDescp = Descp
	from atx_TxnCode (nolock)
	where AcqNo = @AcqNo and TxnCd = @TxnCd

	if @TxnInd is null return 60014 --Transaction Code not found

	select @Ublc = RefCd
	from iss_RefLib (nolock)
	where IssNo = @AcqNo and RefType = 'MerchBatchSts' and RefNo = 1

	select @ActiveSts = RefCd
	from iss_RefLib (nolock)
	where IssNo = @AcqNo and RefType = 'MerchBatchSts' and RefNo = 0

	----------
	begin tran
	----------
	if @Func = 'Add'
	begin
		insert atx_SourceSettlement
			(BatchId, TxnCd, SettleDate, Cnt, Amt, Pts, BillingAmt, BillingPts, Descp, BusnLocation, TermId, Stan, 
			Rrn, InvoiceNo, OrigBatchNo, AcctNo, Mcc, PrcsId, TxnInd, POSCondCd, ChequeNo, InputSrc, LinkIds, UserId, LastUpdDate, Sts)
		select @BatchId, @TxnCd, @SysDate, @Cnt, @Amt, @Pts, @BillingAmt, @BillingPts, isnull(@Descp,@tDescp), @BusnLocation, @TermId, 0, 
			null, 0, 0, @AcctNo, @Mcc, @PrcsId, @TxnInd, 0, null, 'EDC', 0, system_user, @SysDate, @Ublc

		if @@error <> 0
		begin
			rollback tran
			return 70394 --Failed to add Settlement
		end
		-----------
		commit tran
		-----------
	end
	else
	begin
		update a
		set Cnt = @Cnt,
			Amt = @Amt,
			Pts = @Pts,
			BillingAmt = @BillingAmt,
			BillingPts = @BillingPts,
			AcctNo = @AcctNo,
			Mcc = @Mcc,
			TxnInd = @TxnInd,
			LastUpdDate = @SysDate,
			TxnCd = @TxnCd,
			Descp = isnull(@Descp,@tDescp)
		from atx_SourceSettlement a
		where a.Ids = @Ids and a.BatchId = @BatchId

		if @@error <> 0
		begin
			rollback tran
			return 70278 --Failed to update settled balance
		end

		if exists (select 1 from atx_SourceTxn where SrcIds = @Ids and BatchId = @BatchId)
		begin
			update a
			set PrcsId = 0,
				Sts = @Ublc,
				TxnInd = @TxnInd,
				LastUpdDate = @SysDate,
				TxnCd = @TxnCd,
				Descp = isnull(Descp,@tDescp)
			from atx_SourceTxn a
			join (select SrcIds, BatchId, sum(AmtPts) 'AmtPts', sum(BillingPts) 'BillingPts', sum(BillingAmt) 'BillingAmt'
					from atx_SourceTxnDetail
					where ParentIds = @Ids and BatchId = @BatchId
					group by SrcIds, BatchId) b on a.Ids = b.SrcIds and a.BatchId = b.BatchId and (a.Amt <> b.AmtPts or a.BillingPts <> b.BillingPts or a.BillingAmt <> b.BillingAmt)
			where a.SrcIds = @Ids and a.BatchId = @BatchId

			if @@error <> 0
			begin
				rollback tran
				return 70278 --Failed to update settled balance
			end

			update a
			set PrcsId = @PrcsId,
				Sts = @ActiveSts,
				TxnInd = @TxnInd,
				LastUpdDate = @SysDate,
				TxnCd = @TxnCd,
				Descp = isnull(Descp,@tDescp)
			from atx_SourceTxn a
			join (select SrcIds, BatchId, count(*) 'Cnt', sum(AmtPts) 'AmtPts', sum(BillingPts) 'BillingPts', sum(BillingAmt) 'BillingAmt'
					from atx_SourceTxnDetail
					where ParentIds = @Ids and BatchId = @BatchId
					group by SrcIds, BatchId) b on a.Ids = b.SrcIds and a.BatchId = b.BatchId and (a.Amt = b.AmtPts and a.BillingPts = b.BillingPts and a.BillingAmt = b.BillingAmt)
			where a.SrcIds = @Ids and a.BatchId = @BatchId and a.Sts = @ActiveSts

			if @@error <> 0
			begin
				rollback tran
				return 70278 --Failed to update settled balance
			end

			update a
			set PrcsId = 0,
				Sts = @Ublc,
				LastUpdDate = @SysDate
			from atx_SourceSettlement a
			join (select SrcIds, BatchId, count(*) 'Cnt', sum(Amt) 'Amt', sum(Pts) 'Pts', sum(BillingAmt) 'BillingAmt', sum(BillingPts) 'BillingPts'
					from atx_SourceTxn
					where SrcIds = @Ids and BatchId = @BatchId and Sts = @ActiveSts
					group by SrcIds, BatchId) b on a.Ids = b.SrcIds and a.BatchId = b.BatchId and (a.Cnt <> b.Cnt or a.Amt <> b.Amt or a.BillingAmt <> b.BillingAmt or a.BillingPts <> b.BillingPts)
			where a.Ids = @Ids and a.BatchId = @BatchId

			if @@error <> 0 
			begin
				rollback tran
				return 70278 --Failed to update settled balance
			end

			update a
			set PrcsId = @PrcsId,
				Sts = @ActiveSts,
				LastUpdDate = @SysDate
			from atx_SourceSettlement a
			join (select SrcIds, BatchId, count(*) 'Cnt', sum(Amt) 'Amt', sum(Pts) 'Pts', sum(BillingAmt) 'BillingAmt', sum(BillingPts) 'BillingPts'
					from atx_SourceTxn
					where SrcIds = @Ids and BatchId = @BatchId and Sts = @ActiveSts
					group by SrcIds, BatchId) b on a.Ids = b.SrcIds and a.BatchId = b.BatchId and (a.Cnt = b.Cnt and a.Amt = b.Amt and a.BillingAmt = b.BillingAmt and a.BillingPts = b.BillingPts)
			where a.Ids = @Ids and a.BatchId = @BatchId

			if @@error <> 0 
			begin
				rollback tran
				return 70278 --Failed to update settled balance
			end

			-----------
			commit tran
			-----------
			return 50262 --Settlement transaction has been updated successfully
		end

		update a
		set PrcsId = 0,
			Sts = @Ublc,
			Cnt = @Cnt,
			Amt = @Amt,
			Pts = @Pts,
			BillingAmt = @BillingAmt,
			BillingPts = @BillingPts,
			AcctNo = @AcctNo,
			Mcc = @Mcc,
			TxnInd = @TxnInd,
			LastUpdDate = @SysDate,
			TxnCd = @TxnCd,
			Descp = isnull(@Descp,@tDescp)
		from atx_SourceSettlement a
		where Ids = @Ids and BatchId = @BatchId

		if @@error <> 0 
		begin
			rollback tran
			return 70278 --Failed to update settled balance
		end

		-----------
		commit tran
		-----------
		return 50262 --Settlement transaction has been updated successfully
	end
end
GO
