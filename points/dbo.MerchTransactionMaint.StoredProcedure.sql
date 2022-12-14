USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchTransactionMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:Cardtrend Systems Sdn. Bhd.
Modular		:Cardtrend Card Management System (CCMS)- Acquiring Module

Objective	:Merchant payment/ adjustment/ fees/ charges/ misc txn capturing.
-------------------------------------------------------------------------------
When	   Who		CRN	    Description
-------------------------------------------------------------------------------
2007/08/16 Sam			    Initial development
*******************************************************************************/

CREATE	procedure [dbo].[MerchTransactionMaint]
	@Func varchar(10),
	@AcqNo uAcqNo,
	@BusnLocation uMerchNo,
	@TxnCd uTxnCd,
	@Descp uDescp50,
	@TxnAmt money,
	@AppvCd varchar(6),
	@Ids uTxnId,
	@TxnDate datetime

  as
begin
	declare	@Err int, @AcctNo uAcctNo, @CrryCd varchar(4), @CtryCd varchar(4), @SrcIds uTxnId, @Rrn varchar(12), @PrcsDate datetime, @PrcsId int,
			@SysDate datetime, @BatchId uBatchId, @Sts varchar(5), @tAmt money, @Mcc varchar(4), @TxnInd varchar(5), @tDescp nvarchar(50)

	set nocount on
	select @SysDate = getdate()

	if @BusnLocation is null return 60010
	if @TxnCd is null return 55069
	if isnull(@TxnAmt,0) = 0 return 55069

	select @AcctNo = AcctNo,
		@Mcc = Mcc
	from aac_BusnLocation 
	where AcqNo = @AcqNo and BusnLocation = @BusnLocation

	if @@error <> 0 return 60010

	select @CrryCd = CrryCd,
		@CtryCd = CtryCd
	from acq_Acquirer where AcqNo = @AcqNo

	if @BatchId is null
	begin
		exec @BatchId = NextRunNo @AcqNo, 'MNLBatchId'

		if @@error <> 0 return 60028
	end

	select @Sts = VarcharVal from acq_Default where AcqNo = @AcqNo and Deft = 'ActiveSts'

	select @TxnInd = TxnInd,
		@tDescp = Descp
	from atx_TxnCode 
	where AcqNo = @AcqNo and TxnCd = @TxnCd

	if @@rowcount = 0 return 60006

	if @Descp is null select @Descp = @tDescp

	select @SrcIds = Ids,
		@BatchId = BatchId
	from atx_SourceSettlement 
	where BusnLocation = @BusnLocation and TxnCd = @TxnCd and PrcsId = 0 and convert(varchar(8),SettleDate,112) = convert(varchar(8),@SysDate,112)

	if @@error <> 0 return 95210

	-- To capture a future date adjustment
	select @PrcsId = PrcsId,
		@PrcsDate = PrcsDate
	from cmnv_ProcessLog
	where PrcsId = (select max(PrcsId) from cmnv_ProcessLog)

	if @@error <> 0 return 95273 --Unable to retrieve ProcessLog info

	select @PrcsId = isnull(@PrcsId,0) + datediff(dd,@PrcsDate,@SysDate)

	----------
	begin tran
	----------

	if @Func = 'Add'
	begin
		if exists (select 1 from atx_SourceTxn where BusnLocation = @BusnLocation and TxnCd = @TxnCd and BatchId = @BatchId and Amt = @TxnAmt and AuthNo = @AppvCd)
		begin
			rollback tran
			return 65064
		end

		exec GetApprovalCd @AppvCd output

		if @@error <> 0
		begin
			rollback tran
			return 70394
		end

		exec GetRrn @Rrn output

		if @@error <> 0
		begin
			rollback tran
			return 70394
		end

		if isnull(@SrcIds,0) = 0
		begin
			insert atx_SourceSettlement
				(AcqNo, BatchId, TxnCd, SettleDate, Cnt, Amt, Pts, BillingAmt, BillingPts, Descp, 
				BusnLocation, TermId, Stan, Rrn, InvoiceNo, OrigBatchNo, AcctNo, Mcc, PrcsId, TxnInd, 
				POSCondCd, ChequeNo, InputSrc, LinkIds, UserId, LastUpdDate, Sts)
			select @AcqNo, @BatchId, @TxnCd, @SysDate, 1, @TxnAmt, 0, @TxnAmt, 0, @Descp, 
				@BusnLocation, '', 0, '0', 0, 0, @AcctNo, @Mcc, @PrcsId, @TxnInd, 
				0, null, 'USER', 0, 'sa', @SysDate, @Sts

			select @Err = @@error, @SrcIds = @@identity

			if @Err <> 0 or isnull(@SrcIds,0) = 0
			begin
				rollback tran
				return 70394
			end

			insert atx_SourceTxn
				(SrcIds, AcqNo, BatchId, TxnCd, CardNo, CardExpiry, AuthCardNo, AuthCardExpiry, LocalDate, 
				LocalTime, TxnDate, ArrayCnt, Qty, Amt, Pts, BillingAmt, BillingPts, SrvcFee, VATAmt, 
				SubsidizedAmt, Descp, BusnLocation, TermId, CrryCd, CtryCd, InvoiceNo, DriverCd, Odometer, Rrn, 
				Arn, AuthNo, ExceptionCd, PrcsId, LinkIds, TxnInd, WithheldUnsettleId, IssBillingAmt, IssBillingPts, IssBatchId, 
				UserId, LastUpdDate, Sts)
			select @SrcIds, @AcqNo, @BatchId, @TxnCd, 0, null, null, null, substring(convert(varchar(8),@SysDate,112),3,4), 
				replace(convert(varchar(10),@SysDate,108),':',''), @SysDate, 1, null, @TxnAmt, 0, @TxnAmt, 0, 0, null, 
				0, upper(isnull(@Descp,@tDescp)), @BusnLocation, '', @CrryCd, @CtryCd, 0, null, 0, @Rrn, 
				null, @AppvCd, null, @PrcsId, 0, @TxnInd, 0, 0, 0, 0, 
				system_user, getdate(), @Sts

			if @@error <> 0
			begin
				rollback tran
				return 95202
			end

			commit tran
			return 50187
		end

		insert atx_SourceTxn
			(SrcIds, AcqNo, BatchId, TxnCd, CardNo, CardExpiry, AuthCardNo, AuthCardExpiry, LocalDate, 
			LocalTime, TxnDate, ArrayCnt, Qty, Amt, Pts, BillingAmt, BillingPts, SrvcFee, VATAmt, 
			SubsidizedAmt, Descp, BusnLocation, TermId, CrryCd, CtryCd, InvoiceNo, DriverCd, Odometer, Rrn, 
			Arn, AuthNo, ExceptionCd, PrcsId, LinkIds, TxnInd, WithheldUnsettleId, IssBillingAmt, IssBillingPts, IssBatchId, 
			UserId, LastUpdDate, Sts)
		select @SrcIds, @AcqNo, @BatchId, @TxnCd, 0, null, null, null, substring(convert(varchar(8),@SysDate,112),3,4), 
			replace(convert(varchar(10),@SysDate,108),':',''), @SysDate, 1, null, @TxnAmt, 0, @TxnAmt, 0, 0, null, 
			0, upper(isnull(@Descp,@tDescp)), @BusnLocation, '', @CrryCd, @CtryCd, 0, null, 0, @Rrn, 
			null, @AppvCd, null, @PrcsId, 0, @TxnInd, 0, 0, 0, 0, 
			system_user, getdate(), @Sts

		if @@error <> 0
		begin
			rollback tran
			return 95202
		end

		update atx_SourceSettlement
		set Cnt = isnull(Cnt,0) + 1,
			Amt = isnull(Amt,0) + @TxnAmt,
			BillingAmt = isnull(BillingAmt,0) + @TxnAmt,
			PrcsId = @PrcsId
		where Ids = @SrcIds

		if @@error <> 0
		begin
			rollback tran
			return 70486
		end

		commit tran
		return 50187
	end

	if @Func = 'Save'
	begin
		select @SrcIds = SrcIds,
			@tAmt = Amt
		from atx_SourceTxn
		where AcqNo = @AcqNo and Ids = @Ids

		if isnull(@SrcIds,0) = 0
		begin
			rollback tran
			return 60061
		end

		update atx_SourceTxn
		set Amt = @TxnAmt,
			BillingAmt = @TxnAmt,
			Descp = isnull(@Descp,@tDescp),
--			Arn = @CheqNo,
			PrcsId = @PrcsId
		where AcqNo = @AcqNo and Ids = @Ids and SrcIds = @SrcIds

		if @@error <> 0
		begin
			rollback tran
			return 95202
		end

		update atx_SourceSettlement
		set Amt = Amt - isnull(@tAmt,0) + @TxnAmt,
			BillingAmt = BillingAmt - isnull(@tAmt,0) + @TxnAmt,
			PrcsId = @PrcsId
		where Ids = @SrcIds

		if @@error <> 0
		begin
			rollback tran
			return 70486
		end

		commit tran
		return 50188
	end
	else
	begin
		select @SrcIds = SrcIds,
			@TxnAmt = Amt
		from atx_SourceTxn
		where AcqNo = @AcqNo and Ids = @Ids

		if isnull(@SrcIds,0) = 0
		begin
			rollback tran
			return 60044
		end

		delete atx_SourceTxn where AcqNo = @AcqNo and Ids = @Ids

		if @@error <> 0
		begin
			rollback tran
			return 70320
		end

		update atx_SourceSettlement
		set Cnt = isnull(Cnt,1) - 1,
			Amt = isnull(Amt,0) - isnull(@TxnAmt,0),
			BillingAmt = isnull(BillingAmt,0) - isnull(@TxnAmt,0)
		where Ids = @SrcIds

		if @@error <> 0
		begin
			rollback tran
			return 70486
		end

		delete atx_SourceSettlement
		where AcqNo = @AcqNo and Ids = @SrcIds and Cnt = 0

		if @@error <> 0
		begin
			rollback tran
			return 70392
		end

		commit tran
		return 50189		
	end
end
GO
