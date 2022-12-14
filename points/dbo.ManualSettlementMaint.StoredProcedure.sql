USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ManualSettlementMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Manual settlement maintenance.

		If the TxnCd is null or 0. It means 
-------------------------------------------------------------------------------
When	   Who		CRN		Description
-------------------------------------------------------------------------------
2002/06/22 Sam				Initial development
2003/12/04 Sam				Incl checking on terminal id.
*******************************************************************************/

CREATE procedure [dbo].[ManualSettlementMaint]
	@Func varchar(10),
	@AcqNo uAcqNo,
	@BatchId uBatchId output,
	@Ids int output,
	@BusnLocation uMerch,
	@TermId uTermId,
	@TxnCd uTxnCd output,
	@SettleDate datetime,
	@TotCnt smallint,
	@TotAmt money,
	@OrigBatchNo uBatchId,
	@Sts uRefCd output
  as
begin
	declare @PrcsId uPrcsId,
		@PrcsDate datetime,
		@Rrn char(12),
		@Mcc varchar(5),
		@CancelDate datetime,
		@AcctNo uAcctNo,
		@InputSrc uRefCd,
		@Descp uDescp50,
		@BillMethod char(1),
		@TxnInd uRefCd,
		@Error int,
		@SysDate datetime,
		@MerchAcctSts uRefCd

	set nocount on

	select @SysDate = getdate()

	select @InputSrc = RefCd from iss_RefLib where RefType = 'MerchInputSrc' and RefNo = 1

	select @PrcsId = CtrlNo, @PrcsDate = CtrlDate
	from iss_Control
	where IssNo = @AcqNo and CtrlId = 'PrcsId'

	if isnull(@TotAmt, 0) = 0 or isnull(@TotCnt, 0) = 0 return 95128
	if isdate(@SettleDate) != 1 return 95127
	if @SettleDate > getdate() return 95126
	if isnull(@TxnCd, 0) = 0 return 60014
	if isnull(@TermId,'') = '' return 55145	--Terminal Id is a compulsory field

	select @AcctNo = AcctNo,
		@Mcc = Mcc,
		@CancelDate = CancelDate,
		@Descp = substring(rtrim(DBAName),1,30) + ', ' + substring(ltrim(DBACity),1,18),
		@MerchAcctSts = Sts
	from aac_BusnLocation where BusnLocation = @BusnLocation

	if @@rowcount = 0 or @@error <> 0 return 60010

	if not exists (select 1 from iss_RefLib where IssNo = @AcqNo and RefCd = @MerchAcctSts and RefType = 'MerchAcctSts' and RefNo <> 1)
		return 95132 --Check Merchant status

	select @BillMethod = BillMethod, @TxnInd = TxnInd
	from atx_TxnCode where AcqNo = @AcqNo and TxnCd = @TxnCd

	if @@rowcount = 0 or @@error <> 0 return 60006

--	if @BillMethod = 'P'
--	begin
--		if not exists (select 1 from acq_ServiceFeeByProduct where Location = @BusnLocation and Sts = 'A')
--			return 95181
--	end

	if convert(char(8), @SettleDate, 112) > convert(char(8), isnull(@CancelDate, getdate()), 112) return 95176

	if isnull(@TermId, '') <> ''
	begin
		if not exists (select 1 from atm_TerminalInventory a 
						join iss_RefLib b on a.AcqNo = b.IssNo and a.Sts = b.RefCd and b.RefType = 'TermSts' and b.RefInd = 1 
						where TermId = @TermId and BusnLocation = @BusnLocation)
			return 60032
	end

	if isnull(@Ids, 0) > 0
	begin
		update a
		set Cnt = @TotCnt, Amt = @TotAmt, PrcsId = @PrcsId, InputSrc = @InputSrc, a.Sts = b.RefCd
		from atx_SourceSettlement a
		join iss_RefLib b on a.AcqNo = b.IssNo and b.RefType = 'MerchBatchSts' and RefNo = 1
		where Ids = @Ids

		if @@error <> 0 return 54022 --Batch contain no record

		update a 
		set a.Sts = c.RefCd, LastUpdDate = @SysDate
		from atx_SourceSettlement a
		join ( select SrcIds, count(*) 'Cnt', sum(amt) 'Amt'
			from atx_SourceTxn where SrcIds = @Ids
			group by SrcIds 
			) as b on a.Ids = b.SrcIds and (a.Cnt = b.Cnt and a.Amt = b.Amt)
		join iss_RefLib c on a.AcqNo = c.IssNo and c.RefType = 'MerchBatchSts' and RefNo = 0

		if @@error <> 0 return 54022 --Batch contain no record

		update a
		set a.Sts = b.Sts, a.BatchId = b.BatchId
		from atx_SourceTxn a
		join atx_SourceSettlement b on a.SrcIds = b.Ids

		if @@error <> 0 return 54022 --Batch contain no record

		select @Sts = Sts from atx_SourceSettlement where Ids = @Ids
		if @Sts <> 'A' return 95128 --Check on total Batch Count and Batch Amount
		return 50185 --Manual Batch has been updated successfully
	end

	exec @BatchId = NextRunNo @AcqNo, 'MNLBatchId'

	if @@rowcount = 0 or @@error <> 0 return 95174

	exec GetRrn @Rrn output
	select @Rrn = isnull(@Rrn,'123456123456')

	insert atx_SourceSettlement
	( TxnCd, BusnLocation, TermId, SettleDate, Stan, Rrn, InputSrc, InvoiceNo,
	OrigBatchNo, Cnt, Amt, Pts, BillingPts, BillingAmt, Sts, BatchId, LinkIds,
	AcqNo, AcctNo, Mcc, UserId, LastUpdDate, PrcsId, TxnInd, POSCondCd, Descp )
	values
	( @TxnCd, @BusnLocation, @TermId, @SettleDate, null, @Rrn, @InputSrc, @OrigBatchNo,
	@OrigBatchNo, @TotCnt, @TotAmt, 0, 0, 0, 'U', @BatchId, 0,
	@AcqNo, @AcctNo, @Mcc, system_user, getdate(), @PrcsId, @TxnInd, null, @Descp )

	select @Error = @@error, @Ids = @@identity

	if @Error <> 0 or isnull(@Ids, 0) = 0 return 70225 --Failed to create Manual Batch

	return 50184 --Manual Batch has been create successfully
end
GO
