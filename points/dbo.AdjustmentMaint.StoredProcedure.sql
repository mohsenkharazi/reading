USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AdjustmentMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Merchant adjustment maintenance.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/07/12 Sam			   Initial development.
2002/11/17 Sam			   Reconciliation.
*******************************************************************************/
CREATE procedure [dbo].[AdjustmentMaint]
	@Func varchar(6), 
	@AcqNo uAcqNo, 
	@vBusnLocation varchar(19), 
	@TxnId uTxnId output, 
	@TxnDate datetime, 
	@TxnCd uTxnCd, 
	@TxnAmt money, 
	@Descp uDescp50
  as
begin
	declare @eDescp varchar(50), 
		@SysDate datetime, 
		@InputSrc uRefCd, 
		@CtryCd uRefCd, 
		@CrryCd uRefCd, 
		@ActiveSts uRefCd,
		@Rrn char(12),
		@BatchId uBatchId,
		@AcctNo uAcctNo,
		@Mcc smallint,
		@Ids int, 
		@TxnIds uTxnId,
		@Adjs uRefCd,
		@PrcsId uPrcsId,
		@BusnDate datetime,
		@Error int,
		@BusnLocation uMerch
	
	select @SysDate = getdate()
	if @TxnCd is null return 55069
	if @TxnDate is null return 55122
	if @TxnAmt is null return 55123

	set nocount on

	select @CrryCd = @CrryCd, @CtryCd = CtryCd from acq_Acquirer where AcqNo = @AcqNo
	select @ActiveSts = RefCd from iss_RefLib where IssNo = @AcqNo and RefType = 'MerchBatchSts' and RefNo = 0
	select @Adjs = RefCd from iss_RefLib where IssNo = @AcqNo and RefType = 'TxnInd' and RefCd = 'F'
	select @InputSrc = RefCd from iss_RefLib where IssNo = @AcqNo and RefType = 'MerchInputSrc' and RefNo = 1
	select @BusnLocation = convert(bigint, @vBusnLocation)

	select @PrcsId = CtrlNo, @BusnDate = CtrlDate
	from iss_Control
	where IssNo = @AcqNo and CtrlId = 'PrcsId'

	if @@rowcount = 0 or @@error <> 0 return 95098

	select @AcctNo = AcctNo, @Mcc = Mcc
	from aac_BusnLocation where BusnLocation = @BusnLocation

	if @@rowcount = 0 or @@error <> 0
		return 55094 --Business Location is a compulsory field

	select @Descp = isnull(@Descp, Descp)
	from atx_TxnCode
	where AcqNo = @AcqNo and TxnCd = @TxnCd

	if @@rowcount = 0 or @@error <> 0 return 55069

	if convert(char(8), @TxnDate,112) > convert(char(8), @BusnDate,112) 
		return 95208 --Transaction Date is greater than business date

	if @func = 'Add'
	begin
		exec GetRrn @Rrn output
	
		exec @BatchId = NextRunNo @AcqNo, 'MNLBatchID'

		if @@rowcount = 0 or @@error <> 0 return 95174

		----------
		BEGIN TRAN
		----------

		insert atx_SourceSettlement
		( TxnCd, BusnLocation, TermId, SettleDate, Stan, Rrn, InputSrc, LinkIds, 
		InvoiceNo, OrigBatchNo, Cnt, Amt, Pts, BillingAmt, BillingPts, Sts, BatchId,
		AcqNo, AcctNo, Mcc, UserId, LastUpdDate, PrcsId, TxnInd, PosCondCd, ChequeNo, Descp )
		values ( @TxnCd, @BusnLocation, null, @TxnDate, null, @Rrn, @InputSrc, null,
		0, -1, 1, @TxnAmt, 0, 0, 0, @ActiveSts, @BatchId,
		@AcqNo, @AcctNo, @Mcc, system_user, @SysDate, @PrcsId, @Adjs, null, null, @Descp )

		select @Error = @@error, @TxnIds = @@identity

		if isnull(@TxnIds, 0) = 0 or @Error <> 0
		begin
			rollback tran
			return 70253 --Failed to insert Adjustment
		end

		insert atx_SourceTxn
		( SrcIds, TxnCd, CardNo, TxnDate, Rrn, BatchId, TxnInd, LastUpdDate, AcqNo, UserId, Amt, Qty, PrcsId, BusnLocation )
		values ( @TxnIds, @TxnCd, 0, @TxnDate, @Rrn, @BatchId, @Adjs, @SysDate, @AcqNo, system_user, @TxnAmt, 1, @PrcsId, @BusnLocation )

		select @Error = @@error, @Ids = @@identity

		if isnull(@Ids, 0) = 0 or @Error <> 0
		begin
			rollback tran
			return 70253
		end

		select @TxnId = @BatchId

		commit tran
		return 50211
	end

	----------
	BEGIN TRAN
	----------
	update atx_SourceSettlement
	set SettleDate = @TxnDate,
		Amt = @TxnAmt,
		Descp = @Descp,
		LastUpdDate = @SysDate,
		UserId = system_user,
		TxnInd = @Adjs,
		InputSrc = @InputSrc,
		PrcsId = @PrcsId
	where BatchId = @TxnId
	if @@rowcount = 0 or @@error <> 0
	begin
		rollback tran
		return 70254 --Failed to update Adjustment
	end

	update atx_SourceTxn
	set TxnDate = @TxnDate,
		Amt = @TxnAmt, 
		Descp = @Descp,
		LastUpdDate = @SysDate,
		UserId = system_user,
		TxnInd = @Adjs,
		PrcsId = @PrcsId
	where BatchId = @TxnId

	if @@error <> 0
	begin
		rollback tran
		return 70254
	end
	commit tran
	return 50212
end
GO
