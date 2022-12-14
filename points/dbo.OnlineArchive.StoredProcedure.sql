USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[OnlineArchive]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--if exists (select * from dbo.sysobjects where id = object_id(N'[OnlineArchive]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
--drop procedure [OnlineArchive]
--GO

/******************************************************************************
Copyright	: Cardtrend Systems Sdn. Bhd.
Modular		: Cardtrend Card Management System (CCMS)- Acquiring Module

Objective	: (acq) Log, Online Txn archiving.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------

*******************************************************************************/
--exec OnlineArchive 1,26, null
CREATE	procedure [dbo].[OnlineArchive]
	@IssNo uIssNo = 1,
	@PrcsId uPrcsId = null,
	@Ind tinyint = null

  
as
begin
	declare @SpId int, @CPUms money, @PrcsDate datetime, @Sts tinyint, @Date datetime, @RenDay int

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	set nocount on

	truncate table arc_DeleteOnlineSettlement
	truncate table arc_DeleteOnlineTxn
	truncate table arc_DeleteOnlineLog

	select @Sts = 1, @SpId = @@spid, @CPUms = @@cpu_busy, @Date = getdate()

	select @RenDay = IntVal
	from iss_Default (nolock)
	where Deft = 'ArcRenDay'

	if isnull(@PrcsId,0) = 0
	begin
		select @PrcsId = max(PrcsId)
		from Demo_lms_tools..cmn_ProcessLog (nolock)
		where IssNo = @IssNo

		if @@error <> 0
		begin
			print 'sel 0 prcs id'
			return -99
		end

		select @PrcsId = @PrcsId - @RenDay
	end

	select @PrcsDate = PrcsDate + 1
	from Demo_lms_tools..cmn_ProcessLog (nolock)
	where IssNo = @IssNo and PrcsId = @PrcsId

	if @@error <> 0 or isdate(@PrcsDate) <> 1
	begin
		print 'sel cmn_processLog err...'
		return -98
	end

	----------------------------------------
	--extract onlinesettlement to be deleted
	----------------------------------------
	insert arc_DeleteOnlineSettlement
		(Ids, BusnLocation, TermId, PrevLogIds, LogIds, InvoiceNo, PrcsCd, TxnInd)
	select Ids, BusnLocation, TermId, PrevLogIds, LogIds, InvoiceNo, PrcsCd, TxnInd
	from atx_OnlineSettlement (nolock)
	where (Sts in ('A','B') and PrcsId > 0 and PrcsId <= @PrcsId) or (Sts = '0') or (Sts = 'A' and Cnt = 0)

	if @@error <> 0 return -99

	insert arc_DeleteOnlineSettlement
		(Ids, BusnLocation, TermId, PrevLogIds, LogIds, InvoiceNo, PrcsCd, TxnInd)
	select Ids, BusnLocation, TermId, PrevLogIds, LogIds, InvoiceNo, PrcsCd, TxnInd
	from atx_OnlineSettlement (nolock)
	where Sts = 'U' and PrcsCd = 920000

	if @@error <> 0 return -99

	---------------------------------
	--extract onlinetxn to be deleted
	---------------------------------
	insert arc_DeleteOnlineTxn
		(Ids)
	select b.Ids
	from arc_DeleteOnlineSettlement a (nolock) 
	join atx_OnlineTxn b (nolock) on a.Ids = b.SrcIds and a.InvoiceNo = b.InvoiceNo and a.TxnInd = b.TxnInd and
		((a.PrcsCd = 920000 and b.MsgType < 320) or (a.PrcsCd = 960000 and b.MsgType in (320,321)))

	if @@error <> 0 return -98

	insert arc_DeleteOnlineTxn
		(Ids)
	select Ids
	from atx_OnlineTxn (nolock) 
	where MsgType = 100 and LastUpdDate < @PrcsDate

	if @@error <> 0 return -98

	insert arc_DeleteOnlineTxn
		(Ids)
	select a.Ids
	from (select Ids from atx_OnlineTxn a (nolock) 
			where datediff(dd, a.LastUpdDate, @PrcsDate) > 4) a
	where not exists (select 1 from arc_DeleteOnlineTxn b (nolock) where a.Ids = b.Ids)

	if @@error <> 0 return -98

	---------------------------------
	--extract onlinelog to be deleted
	---------------------------------
	insert arc_DeleteOnlineLog
		(Ids)
	select Ids
	from atx_OnlineLog (nolock)
	where CreationDate < @PrcsDate

	if @@error <> 0 return -97

	----------------
	--archive online
	----------------

	----------
	begin tran
	----------

		insert into Demo_lms_arc..atx_OnlineSettlement
			(Ids, MsgType, PrcsCd, BatchId, LastUpdDate, BusnLocation, TermId, Sts, PrcsId, LogIds, Stan, LocalTime, LocalDate, SettleDate,
			Nii, POSCondCd, Rrn, InputSrc, RespCd, InvoiceNo, TxnCd, Cnt, Amt, TxnDate, UserId, TxnInd, AcqNo, PrevLogIds)
		select a.Ids, MsgType, b.PrcsCd, BatchId, LastUpdDate, b.BusnLocation, b.TermId, Sts, PrcsId, b.LogIds, Stan, LocalTime, LocalDate, SettleDate,
			Nii, POSCondCd, Rrn, InputSrc, RespCd, b.InvoiceNo, TxnCd, Cnt, Amt, TxnDate, UserId, b.TxnInd, AcqNo, b.PrevLogIds
		from arc_DeleteOnlineSettlement a
		join atx_OnlineSettlement b (nolock) on a.Ids = b.Ids

		if @@error <> 0 
		begin
			rollback tran
			return -1
		end

		insert into Demo_lms_arc..atx_OnlineTxn
			(Ids, SrcIds, MsgType, PrcsCd, CardNo, Amt, Stan, TxnDate, InvoiceNo, Track2, BusnLocation, TermId, Rrn, AuthNo, RespCd, BatchId,
			TxnCd, WithheldUnsettleId, IssTxnCd, PINData, LocalDate, LocalTime, SrvcRestrictCd, POSCondCd, CardExpiry, POSEntry, VATAmt,
			CashAmt, VoucherAmt, Nii, AuthCardNo, AuthCardExpiry, DriverCd, Odometer, PtsIssued, PtsAccum, ArrayCnt, Descp, LastUpdDate,
			Sts, TagIds, PrcsId, TxnInd, LogIds, AcqNo, UserId, InputSrc, Mcc, CtryCd, CrryCd, OrigStan, OrigRrn, OrigInvoiceNo, OrigAmt,
			PaymtCardPrefix, VehRegsNo, PumpIslandNo, IssBillingAmt, IssBillingPts, AvailBal, ForcePrcsId, ForceBatchId, ForceSts, VoidReversalSts,
			VoidReversalDate, OrigBonusPts, PrevPtsBal, CurrPtsBal, OrigPts)
		select a.Ids, SrcIds, MsgType, PrcsCd, CardNo, Amt, Stan, TxnDate, InvoiceNo, Track2, BusnLocation, TermId, Rrn, AuthNo, RespCd, BatchId,
			TxnCd, WithheldUnsettleId, IssTxnCd, PINData, LocalDate, LocalTime, SrvcRestrictCd, POSCondCd, CardExpiry, POSEntry, VATAmt,
			CashAmt, VoucherAmt, Nii, AuthCardNo, AuthCardExpiry, DriverCd, Odometer, PtsIssued, PtsAccum, ArrayCnt, Descp, LastUpdDate,
			Sts, TagIds, PrcsId, TxnInd, LogIds, AcqNo, UserId, InputSrc, Mcc, CtryCd, CrryCd, OrigStan, OrigRrn, OrigInvoiceNo, OrigAmt,
			PaymtCardPrefix, VehRegsNo, PumpIslandNo, IssBillingAmt, IssBillingPts, AvailBal, ForcePrcsId, ForceBatchId, ForceSts, VoidReversalSts,
			VoidReversalDate, OrigBonusPts, PrevPtsBal, CurrPtsBal, OrigPts
		from arc_DeleteOnlineTxn a
		join atx_OnlineTxn b (nolock) on a.Ids = b.Ids

		if @@error <> 0
		begin
			rollback tran
			return -2
		end

		insert into Demo_lms_arc..atx_OnlineTxnDetail
			(Ids, SrcIds, Seq, ProdCd, Qty, AmtPts, Pts, FastTrack, UnitPrice, BatchId, AcqNo, BusnLocation, PlanId, Descp, ProdType, LastUpdDate)
		select b.Ids, a.Ids, Seq, ProdCd, Qty, AmtPts, Pts, FastTrack, UnitPrice, BatchId, AcqNo, BusnLocation, PlanId, Descp, ProdType, LastUpdDate
		from arc_DeleteOnlineTxn a
		join atx_OnlineTxnDetail b (nolock) on a.Ids = b.SrcIds

		if @@error <> 0
		begin
			rollback tran
			return -3
		end

--deleting...
		delete a
		from atx_OnlineSettlement a
		join arc_DeleteOnlineSettlement b on a.Ids = b.Ids

		if @@error <> 0
		begin
			rollback tran
			return -4
		end

		delete a
		from atx_OnlineTxn a
		join arc_DeleteOnlineTxn b on a.Ids = b.Ids

		if @@error <> 0
		begin
			rollback tran
			return -5
		end

		delete a
		from atx_OnlineTxnDetail a
		join arc_DeleteOnlineTxn b on a.SrcIds = b.Ids

		if @@error <> 0
		begin
			rollback tran
			return -6
		end

	-----------
	commit tran
	-----------

	if @@TRANCOUNT > 0
	begin
		rollback tran
		return -7
	end

	-------------
	--archive log
	-------------

	----------
	begin tran
	----------
/*
		insert into Demo_lms_arc..atx_OnlineLog
			(Ids, CreationDate, MsgType, PrcsCd, CardNo, SysTraceAudit, Rrn, InvoiceNo, WithheldUnsettleId, BusnLocation, TermId, RespCd, 
			HostErrCd, Amt, AuthResp, LastUpdDate, Msg, LocalTime, LocalDate, CardExpiry, Track2, PINData, NewPIN, POSEntry, 
			POSCondCd, VAT, Mcc, Nii, SrvcRestrictionCd, AuthCardNo, AuthCardExpiry, DriverCd, OdometerReading, PumpIslandNo, PtsIssued, 
			PtsAccum, ArrayCnt, FleetSalesCnt, FleetSalesAmt, PreSalesCnt, PreSalesAmt, RedemptionCnt, RedemptionAmt, PreReloadCnt, 
			PreReloadAmt, OtherSalesCnt, OtherSalesAmt, ProdCd1, Qty1, AmtPts1, FastTrack1, UnitPrice1, ProdCd2, Qty2, AmtPts2, 
			FastTrack2, UnitPrice2, ProdCd3, Qty3, AmtPts3, FastTrack3, UnitPrice3, ProdCd4, Qty4, AmtPts4, FastTrack4, UnitPrice4, 
			ProdCd5, Qty5, AmtPts5, FastTrack5, UnitPrice5, ProdCd6, Qty6, AmtPts6, FastTrack6, UnitPrice6, ProdCd7, Qty7, AmtPts7, 
			FastTrack7, UnitPrice7, ProdCd8, Qty8, AmtPts8, FastTrack8, UnitPrice8, ProdCd9, Qty9, AmtPts9, FastTrack9, UnitPrice9, 
			ProdCd10, Qty10, AmtPts10, FastTrack10, UnitPrice10, ProdCd11, Qty11, AmtPts11, FastTrack11, UnitPrice11, ProdCd12, Qty12, 
			AmtPts12, FastTrack12, UnitPrice12, ProdCd13, Qty13, AmtPts13, FastTrack13, UnitPrice13, ProdCd14, Qty14, AmtPts14, 
			FastTrack14, UnitPrice14, ProdCd15, Qty15, AmtPts15, FastTrack15, UnitPrice15, Milestone, VAEPrcsDate, VehRegsNo, 
			OrigRrn, OrigStan, OrigInvoiceNo, OrigMti)
		select a.Ids, CreationDate, MsgType, PrcsCd, CardNo, SysTraceAudit, Rrn, InvoiceNo, WithheldUnsettleId, BusnLocation, TermId, RespCd, 
			HostErrCd, Amt, AuthResp, LastUpdDate, Msg, LocalTime, LocalDate, CardExpiry, Track2, PINData, NewPIN, POSEntry, 
			POSCondCd, VAT, Mcc, Nii, SrvcRestrictionCd, AuthCardNo, AuthCardExpiry, DriverCd, OdometerReading, PumpIslandNo, PtsIssued, 
			PtsAccum, ArrayCnt, FleetSalesCnt, FleetSalesAmt, PreSalesCnt, PreSalesAmt, RedemptionCnt, RedemptionAmt, PreReloadCnt, 
			PreReloadAmt, OtherSalesCnt, OtherSalesAmt, ProdCd1, Qty1, AmtPts1, FastTrack1, UnitPrice1, ProdCd2, Qty2, AmtPts2, 
			FastTrack2, UnitPrice2, ProdCd3, Qty3, AmtPts3, FastTrack3, UnitPrice3, ProdCd4, Qty4, AmtPts4, FastTrack4, UnitPrice4, 
			ProdCd5, Qty5, AmtPts5, FastTrack5, UnitPrice5, ProdCd6, Qty6, AmtPts6, FastTrack6, UnitPrice6, ProdCd7, Qty7, AmtPts7, 
			FastTrack7, UnitPrice7, ProdCd8, Qty8, AmtPts8, FastTrack8, UnitPrice8, ProdCd9, Qty9, AmtPts9, FastTrack9, UnitPrice9, 
			ProdCd10, Qty10, AmtPts10, FastTrack10, UnitPrice10, ProdCd11, Qty11, AmtPts11, FastTrack11, UnitPrice11, ProdCd12, Qty12, 
			AmtPts12, FastTrack12, UnitPrice12, ProdCd13, Qty13, AmtPts13, FastTrack13, UnitPrice13, ProdCd14, Qty14, AmtPts14, 
			FastTrack14, UnitPrice14, ProdCd15, Qty15, AmtPts15, FastTrack15, UnitPrice15, Milestone, VAEPrcsDate, VehRegsNo, 
			OrigRrn, OrigStan, OrigInvoiceNo, OrigMti
		from arc_DeleteOnlineLog a
		join atx_OnlineLog b (nolock) on a.Ids = b.Ids
*/
		insert into Demo_lms_arc..atx_OnlineLog
			(Ids, CreationDate, MsgType, PrcsCd, CardNo, SysTraceAudit, Rrn, InvoiceNo, WithheldUnsettleId, BusnLocation, TermId, RespCd, 
			HostErrCd, Amt, AuthResp, LastUpdDate, Msg, LocalTime, LocalDate, CardExpiry, Track2, PINData, NewPIN, POSEntry, 
			POSCondCd, VAT, Mcc, Nii, SrvcRestrictionCd, AuthCardNo, AuthCardExpiry, DriverCd, OdometerReading, PumpIslandNo, PtsIssued, 
			PtsAccum, ArrayCnt, FleetSalesCnt, FleetSalesAmt, PreSalesCnt, PreSalesAmt, RedemptionCnt, RedemptionAmt, PreReloadCnt, 
			PreReloadAmt, OtherSalesCnt, OtherSalesAmt, Milestone, VAEPrcsDate, VehRegsNo, 
			OrigRrn, OrigStan, OrigInvoiceNo, OrigMti)
		select a.Ids, CreationDate, MsgType, PrcsCd, CardNo, SysTraceAudit, Rrn, InvoiceNo, WithheldUnsettleId, BusnLocation, TermId, RespCd, 
			HostErrCd, Amt, AuthResp, LastUpdDate, Msg, LocalTime, LocalDate, CardExpiry, Track2, PINData, NewPIN, POSEntry, 
			POSCondCd, VAT, Mcc, Nii, SrvcRestrictionCd, AuthCardNo, AuthCardExpiry, DriverCd, OdometerReading, PumpIslandNo, PtsIssued, 
			PtsAccum, ArrayCnt, FleetSalesCnt, FleetSalesAmt, PreSalesCnt, PreSalesAmt, RedemptionCnt, RedemptionAmt, PreReloadCnt, 
			PreReloadAmt, OtherSalesCnt, OtherSalesAmt, Milestone, VAEPrcsDate, VehRegsNo, 
			OrigRrn, OrigStan, OrigInvoiceNo, OrigMti
		from arc_DeleteOnlineLog a
		join atx_OnlineLog b (nolock) on a.Ids = b.Ids

		if @@error <> 0
		begin
			rollback tran
			return -8
		end

		insert into Demo_lms_arc..atx_OnlineSubLog
			(Ids, Stan, Rrn, RespCd, HostErrCd, InvNo, WUId, CreationDate, LastUpdDate)
		select a.Ids, Stan, Rrn, RespCd, HostErrCd, InvNo, WUId, CreationDate, LastUpdDate
		from arc_DeleteOnlineLog a
		join atx_OnlineSubLog b (nolock) on a.Ids = b.Ids

		if @@error <> 0
		begin
			rollback tran
			return -9
		end

		insert into Demo_lms_arc..atx_OnlineTxnDetailLog
			(Ids, Seq, ProdCd, Qty, AmtPts, UnitPrice, CreationDate)
		select a.Ids, Seq, ProdCd, Qty, AmtPts, UnitPrice, CreationDate
		from arc_DeleteOnlineLog a
		join atx_OnlineTxnDetailLog b (nolock) on a.Ids = b.Ids

		if @@error <> 0
		begin
			rollback tran
			return -10
		end

--deleting...
		
		delete a
		from atx_OnlineLog a
		join arc_DeleteOnlineLog b on a.Ids = b.Ids
		
		if @@error <> 0
		begin
			rollback tran
			return -11
		end		

		delete a
		from atx_OnlineSubLog a
		join arc_DeleteOnlineLog b on a.Ids = b.Ids
		
		if @@error <> 0
		begin
			rollback tran
			return -12
		end		

		delete a
		from atx_OnlineTxnDetailLog a
		join arc_DeleteOnlineLog b on a.Ids = b.Ids
		
		if @@error <> 0
		begin
			rollback tran
			return -13
		end		

	-----------
	commit tran
	-----------

	if @@TRANCOUNT > 0
	begin
		rollback tran
		return -14
	end

	insert arc_ArchiveLog
		(PrcsType, PrcsId, BeginDate, EndDate, SpId)
	select 'OnlArc', @PrcsId, @Date, getdate(), @SpId

	return 0
end
GO
