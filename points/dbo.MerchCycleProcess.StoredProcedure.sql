USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchCycleProcess]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/*****************************************************************************************************************

Copyright	: Cardtrend Systems Sdn. Bhd.
Modular		: Cardtrend Card Management System (CCMS)- Acquiring Module

Objective	: This stored procedure will track the merchant outstanding balance to carry forward 
			Period: Cycle-cut (Cycle no.)

SP Level	: Primary

-------------------------------------------------------------------------------
When	   Who		CRN		Desc
-------------------------------------------------------------------------------
2007/07/26 Sam				Initial development

******************************************************************************************************************/
--exec MerchCycleProcess 1,1,28,1
CREATE procedure [dbo].[MerchCycleProcess] 
	@AcqNo uAcqNo,
	@CycNo uCycNo,
	@PrcsId uPrcsId = null

  as
begin

	declare	@rc int,
		@Cnt int,
		@PrcsDate datetime,
		@StartPrcsDate datetime,
		@StartPrcsId int,
		@PrcsName varchar(50),
		@StmtDueDate datetime,
		@StmtDueDay smallint,
		@GracePeriod tinyint,
		@StmtCycId int,
		@StmtFreqInd char(1),
		@CycInterval smallint,
		@MaxCycSeq smallint,
		@MaxCycDate datetime,
		@MaxCycInd char(1),
		@CurrCycSeq smallint,
		@DeftPayMerchTxnCd int,
		@DeftPayerBusnName nvarchar(50),
		@DeftPayerBusnLocation varchar(15),
		@DeftPayerAcctNo bigint,
		@MNLBatchId bigint,
		@AutoPay varchar(15)

	SET nocount on
	SET DATEFORMAT ymd
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	select @GracePeriod = 0, @MaxCycSeq = 0, @MaxCycInd = 'N'

	exec @rc = InitProcess
	 
	if @@error <> 0 or @rc <> 0 return 99999

	select @PrcsName = 'MerchCycleProcess'
	exec TraceProcess @AcqNo, @PrcsName, 'Start'

--Ind, 0= Fully/ Without o/s contra
--	   1= Partial contra
--	   9= Untouched

	delete tmp_Contra
	delete tmp_MerchStmtPrcs
/*
--Creating temporary table
	create table tmp_Contra
	(
		BusnLocation varchar(15),
		PrcsId int,
		PrevBfwd money,
		AccumBal money,
		RecvPaymt money,
		ActualCt money,
		Ind tinyint,
		AfterCt money
	)		
	create	unique index IX_Contra on tmp_Contra (
		BusnLocation,
		PrcsId)

	create table tmp_MerchStmtPrcs
		(BusnLocation varchar(15),
		TxnCd varchar(10) null,
		Amt money null)
	create index IX_Key on tmp_MerchStmtPrcs 
		(BusnLocation,
		TxnCd)
*/
	if not exists (select 1 from iss_Control where IssNo = @AcqNo and CtrlId = 'MerchStmtCycId')
	begin
		insert iss_Control
		(IssNo, CtrlId, Descp, CtrlNo, CtrlDate, LastUpdDate)
		values 
		(@AcqNo, 'MerchStmtCycId', 'Merchant Statement Cycle', 1, null, getdate())

		if @@error <> 0 return 70330 --Failed to create new Control
	end

	if @PrcsId is null
	begin
		select @PrcsId = CtrlNo, 
			@PrcsDate = CtrlDate
		from iss_Control 
		where IssNo = @AcqNo and CtrlId = 'PrcsId'

		if @@error <> 0 or @PrcsDate is null return 95098	--Unable to retrieve information from iss_Control table
	end
	else
	begin
		select @PrcsDate = PrcsDate
		from cmn_ProcessLog 
		where IssNo = @AcqNo and PrcsId = @PrcsId

		if @@error <> 0 or @PrcsDate is null return 95273	--Unable to retrieve ProcessLog info
	end

	if exists (select 1 from aac_AccountStatement where PrcsId = @PrcsId) return 0	--Cycle control detail already exists

	select @StmtDueDate = b.DueDate, 
		@StmtDueDay = b.DueDay, 
		@GracePeriod = b.GracePeriod,
		@StmtFreqInd = a.StmtFreqInd,
		@CycInterval = a.CycInterval,
		@CurrCycSeq = b.CycSeq
	from acq_CycleControl a
	inner join acq_CycleDate b on a.AcqNo = b.AcqNo and a.CycNo = b.CycNo and b.StmtDate = @PrcsDate
	where a.CycNo = @CycNo

	if @@error <> 0
	begin
		return 95166	--Cycle day does not match process date
	end

	if isnull(@CurrCycSeq,0) = 0 return 0

	select @MaxCycDate = max(b.StmtDate)
	from acq_CycleControl a
	join acq_CycleDate b on a.AcqNo = b.AcqNo and a.CycNo = b.CycNo
	where a.CycNo = @CycNo

	if @@error <> 0
	begin
		return 95166	--Cycle day does not match process date
	end

	if @MaxCycDate = @PrcsDate
	begin
		select @MaxCycInd = 'Y'

		select @MaxCycSeq = max(CycSeq)
		from acq_CycDate
		where AcqNo = @AcqNo and CycNo = @CycNo
	end

	if @StmtDueDate is null and @StmtDueDay is null and @GracePeriod is null
	begin
		return 95167	--Cycle day not match
	end

	select @StartPrcsDate =
	case @StmtFreqInd
		when "W" then dateadd(dd, -6, @PrcsDate)
		when "M" then dateadd(mm, -1, @PrcsDate) 
	end

	if @StartPrcsDate is null
	begin
		return 95166	--Cycle day does not match process date
	end

	if (select 1 from cmn_ProcessLog (nolock) where PrcsDate = @StartPrcsDate) = 0
	begin
		select @StartPrcsDate = min(PrcsDate)
		from cmn_ProcessLog
	end

	if @StmtDueDate is null
	begin
		select @StmtDueDate =
		case @StmtFreqInd
			when "W" then dateadd(dd, isnull(@StmtDueDay,0), @PrcsDate)
			when "M" then dateadd(mm, 1, @PrcsDate)
		end
	end

	if (select 1 from aac_AccountStatement where PrcsId = @PrcsId) > 0
		return 70347	--Failed to create Account Statement

	select @StartPrcsId =
		case @StmtFreqInd
			when "W" then @PrcsId - 6
			else (select PrcsId from cmn_ProcessLog where PrcsDate = dateadd(mm, -1, @PrcsDate))
		end

	if (select 1 from cmn_ProcessLog where PrcsId = @StartPrcsId) = 0
	begin
		select @StartPrcsId = min(PrcsId) 
		from cmn_ProcessLog		
	end

	select @StmtCycId = CtrlNo
	from iss_Control
	where IssNo = @AcqNo and CtrlId = 'MerchStmtCycId'

	if @StmtCycId is null
	begin
		return 60055	--Cycle Control Number not found
	end

	select @DeftPayMerchTxnCd = IntVal
	from acq_Default
	where AcqNo = @AcqNo and Deft = 'PaymtToMerchTxnCd' 

	select @DeftPayerAcctNo = VarcharVal
	from acq_Default
	where AcqNo = @AcqNo and Deft = 'GUAcctDept'

	select @DeftPayerBusnLocation = BusnLocation
	from aac_BusnLocation 
	where AcqNo = @AcqNo and BusnLocation = '599999999999999'

	exec @MNLBatchId = NextRunNo @AcqNo, 'MNLBatchId'

	if @@error <> 0
	begin
		return 95098 --Unable to retrieve information from iss_Control table
	end

	select @AutoPay = RefCd
	from iss_RefLib
	where IssNo = @AcqNo and RefType = 'PaymtMode' and RefNo = 0

	-----------------
	BEGIN TRANSACTION
	-----------------

	--------------------------------------------------------------------------------------------------------
	--Extracting business location into account statement table */
	--------------------------------------------------------------------------------------------------------
	insert aac_AccountStatement
		(AcqNo, StmtCycId, AgeingId, AcctNo, BusnLocation, PrcsId, Sts, StmtMsgId, PrevBfwd, ContraInd, 
		ContraPaymt, OpnBal, ClsBal, MinRepaymt, TotalPaymt, DrTxnBal, CrTxnBal, DrAdjBal, CrAdjBal, FeeBal, 
		PaymtTo, PaymtRecv, ChargeBal, MiscBal, AccumBal, OffsetAmt, UblcInd)
	select @AcqNo, @StmtCycId, 0, a.AcctNo, a.BusnLocation, @PrcsId, a.Sts, 0, 0, 9, 
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 'N'
	from aac_BusnLocation a (nolock)
	inner join acq_CycleControl b on a.CycNo = b.CycNo
	where a.AcqNo = @AcqNo and a.CycNo = @CycNo

	if @@error <> 0
	begin
		rollback transaction
		return 70347	--Failed to create Account Statement
	end

	--------------------------------------------------------------------------------------------------------
	--Extracting total sum by txncd
	--------------------------------------------------------------------------------------------------------

	insert tmp_MerchStmtPrcs
		(BusnLocation, TxnCd, Amt)
	select a.BusnLocation, a.TxnCd, sum(isnull(b.TxnMerchFee,0))
	from atx_Txn a
	join atx_MiscTxnFee b (nolock) on a.Ids = b.Ids
	where a.PrcsId between @StartPrcsId and @PrcsId
	group by a.BusnLocation, a.TxnCd

	if @@error <> 0
	begin
		rollback transaction
		return 70270	--Failed to create temporary table
	end

	insert tmp_MerchStmtPrcs
		(BusnLocation, TxnCd, Amt)
	select a.BusnLocation, a.TxnCd, sum(case when a.BillingAmt <> 0 then a.BillingAmt else a.BillingPts end)
	from atx_Txn a
	join atx_TxnCode b (nolock) on a.TxnCd = b.TxnCd and b.Category in (2,3,4,5,6,20,21)
	where a.PrcsId between @StartPrcsId and @PrcsId
	group by a.BusnLocation, a.TxnCd

	if @@error <> 0
	begin
		rollback transaction
		return 70270	--Failed to create temporary table
	end

	update a
	set OpnBal = isnull(b.ClsBal,0),
		ClsBal = isnull(b.ClsBal,0) + 
					isnull(c.TxnAmt,0) + 
					isnull(d.TxnAmt,0) + 
					isnull(e.TxnAmt,0) + 
					isnull(f.TxnAmt,0) + 
					isnull(g.TxnAmt,0) + 
					isnull(h.TxnAmt,0) + 
					isnull(i.TxnAmt,0) + 
					isnull(j.TxnAmt,0) +
					isnull(k.TxnAmt,0),
		DrAdjBal = isnull(c.TxnAmt,0),
		CrAdjBal = isnull(d.TxnAmt,0),
		DrTxnBal = isnull(e.TxnAmt,0),
		CrTxnBal = isnull(h.TxnAmt,0),
		TotalPaymt = isnull(f.TxnAmt,0),
		PaymtTo = isnull(m.TxnAmt,0),
		PaymtRecv = isnull(l.TxnAmt,0),
		FeeBal = isnull(g.TxnAmt,0),
		ChargeBal = isnull(i.TxnAmt,0),
		MiscBal = isnull(j.TxnAmt,0) + isnull(k.TxnAmt,0)
	from aac_AccountStatement a
	left outer join (select b1.BusnLocation, b1.ClsBal
					from aac_AccountStatement b1 (nolock)
					where PrcsId = (select max(PrcsId) from aac_AccountStatement b2 where b1.BusnLocation = b2.BusnLocation and b2.PrcsId < @PrcsId)) b on a.BusnLocation = b.BusnLocation
	left outer join (select c1.BusnLocation, sum(c1.Amt) 'TxnAmt' --* c4.RefNo) 'TxnAmt'
						from tmp_MerchStmtPrcs c1
						inner join atx_TxnCode c2 (nolock) on c2.AcqNo = @AcqNo and c1.TxnCd = c2.TxnCd
						inner join acq_Default c3 (nolock) on c2.AcqNo = c3.AcqNo and c2.Category = c3.IntVal and c3.Deft = 'AdjustTxnCategory'
						inner join iss_RefLib c4 (nolock) on c2.AcqNo = c4.IssNo and c2.Multiplier = c4.RefCd and c4.RefType = 'TxnType' and c4.RefNo = 1
						group by c1.BusnLocation) c on a.BusnLocation = c.BusnLocation
	left outer join (select d1.BusnLocation, sum(d1.Amt) 'TxnAmt' --* d4.RefNo) 'TxnAmt'
						from tmp_MerchStmtPrcs d1
						inner join atx_TxnCode d2 (nolock) on d2.AcqNo = @AcqNo and d1.TxnCd = d2.TxnCd
						inner join acq_Default d3 (nolock) on d2.AcqNo = d3.AcqNo and d2.Category = d3.IntVal and d3.Deft = 'AdjustTxnCategory'
						inner join iss_RefLib d4 (nolock) on d2.AcqNo = d4.IssNo and d2.Multiplier = d4.RefCd and d4.RefType = 'TxnType' and d4.RefNo = -1
						group by d1.BusnLocation) d on a.BusnLocation = d.BusnLocation
	left outer join (select e1.BusnLocation, sum(e1.Amt) 'TxnAmt' 
						from tmp_MerchStmtPrcs e1
						inner join atx_TxnCode e2 (nolock) on e2.AcqNo = @AcqNo and e1.TxnCd = e2.TxnCd
						inner join acq_Default e3 (nolock) on e2.AcqNo = e3.AcqNo and e2.Category = e3.IntVal and e3.Deft = 'PtsTxnCategory'
						group by e1.BusnLocation) e on a.BusnLocation = e.BusnLocation
	left outer join (select f1.BusnLocation, sum(f1.Amt) 'TxnAmt' --* f4.RefNo) 'TxnAmt'
						from tmp_MerchStmtPrcs f1
						inner join atx_TxnCode f2 (nolock) on f2.AcqNo = @AcqNo and f1.TxnCd = f2.TxnCd
						inner join acq_Default f3 (nolock) on f2.AcqNo = f3.AcqNo and f2.Category = f3.IntVal and f3.Deft = 'PaymtTxnCategory'
						inner join iss_RefLib f4 (nolock) on f2.AcqNo = f4.IssNo and f2.Multiplier = f4.RefCd and f4.RefType = 'TxnType'
						group by f1.BusnLocation) f on a.BusnLocation = f.BusnLocation
	left outer join (select g1.BusnLocation, sum(g1.Amt) 'TxnAmt' --* g4.RefNo) 'TxnAmt'
						from tmp_MerchStmtPrcs g1
						inner join atx_TxnCode g2 (nolock) on g2.AcqNo = @AcqNo and g1.TxnCd = g2.TxnCd
						inner join acq_Default g3 (nolock) on g2.AcqNo = g3.AcqNo and g2.Category = g3.IntVal and g3.Deft = 'FeeTxnCategory'
						inner join iss_RefLib g4 (nolock) on g2.AcqNo = g4.IssNo and g2.Multiplier = g4.RefCd and g4.RefType = 'TxnType'
						group by g1.BusnLocation) g on a.BusnLocation = g.BusnLocation
	left outer join (select h1.BusnLocation, sum(h1.Amt) 'TxnAmt' 
						from tmp_MerchStmtPrcs h1
						inner join atx_TxnCode h2 (nolock) on h2.AcqNo = @AcqNo and h1.TxnCd = h2.TxnCd
						inner join acq_Default h3 (nolock) on h2.AcqNo = h3.AcqNo and h2.Category = h3.IntVal and h3.Deft = 'RdmpTxnCategory'
						group by h1.BusnLocation) h on a.BusnLocation = h.BusnLocation
	left outer join (select i1.BusnLocation, sum(i1.Amt) 'TxnAmt' --* i4.RefNo) 'TxnAmt'
						from tmp_MerchStmtPrcs i1
						inner join atx_TxnCode i2 (nolock) on i2.AcqNo = @AcqNo and i1.TxnCd = i2.TxnCd
						inner join acq_Default i3 (nolock) on i2.AcqNo = i3.AcqNo and i2.Category = i3.IntVal and i3.Deft = 'ChargeTxnCategory'
						inner join iss_RefLib i4 (nolock) on i2.AcqNo = i4.IssNo and i2.Multiplier = i4.RefCd and i4.RefType = 'TxnType'
						group by i1.BusnLocation) i on a.BusnLocation = i.BusnLocation
	left outer join (select j1.BusnLocation, sum(j1.Amt) 'TxnAmt' --* j4.RefNo) 'TxnAmt'
						from tmp_MerchStmtPrcs j1
						inner join atx_TxnCode j2 (nolock) on j2.AcqNo = @AcqNo and j1.TxnCd = j2.TxnCd
						inner join acq_Default j3 (nolock) on j2.AcqNo = j3.AcqNo and j2.Category = j3.IntVal and j3.Deft = 'MiscTxnCategory'
						inner join iss_RefLib j4 (nolock) on j2.AcqNo = j4.IssNo and j2.Multiplier = j4.RefCd and j4.RefType = 'TxnType'
						group by j1.BusnLocation) j on a.BusnLocation = j.BusnLocation
	left outer join (select k1.BusnLocation, sum(k1.Amt) 'TxnAmt' --* k4.RefNo) 'TxnAmt'
						from tmp_MerchStmtPrcs k1
						inner join atx_TxnCode k2 (nolock) on k2.AcqNo = @AcqNo and k1.TxnCd = k2.TxnCd
						inner join acq_Default k3 (nolock) on k2.AcqNo = k3.AcqNo and k2.Category = k3.IntVal and k3.Deft = 'PayMerchTxnCategory'
						inner join iss_RefLib k4 (nolock) on k2.AcqNo = k4.IssNo and k2.Multiplier = k4.RefCd and k4.RefType = 'TxnType'
						group by k1.BusnLocation) k on a.BusnLocation = k.BusnLocation
	left outer join (select l1.BusnLocation, sum(l1.Amt) 'TxnAmt'
						from tmp_MerchStmtPrcs l1
						inner join atx_TxnCode l2 (nolock) on l2.AcqNo = @AcqNo and l1.TxnCd = l2.TxnCd
						inner join acq_Default l3 (nolock) on l2.AcqNo = l3.AcqNo and l2.Category = l3.IntVal and l3.Deft = 'PaymtTxnCategory'
						inner join iss_RefLib l4 (nolock) on l2.AcqNo = l4.IssNo and l2.Multiplier = l4.RefCd and l4.RefType = 'TxnType' and l4.RefNo = -1
						group by l1.BusnLocation) l on a.BusnLocation = l.BusnLocation
	left outer join (select m1.BusnLocation, sum(m1.Amt) 'TxnAmt'
						from tmp_MerchStmtPrcs m1
						inner join atx_TxnCode m2 (nolock) on m2.AcqNo = @AcqNo and m1.TxnCd = m2.TxnCd
						inner join acq_Default m3 (nolock) on m2.AcqNo = m3.AcqNo and m2.Category = m3.IntVal and m3.Deft = 'PaymtTxnCategory'
						inner join iss_RefLib m4 (nolock) on m2.AcqNo = m4.IssNo and m2.Multiplier = m4.RefCd and m4.RefType = 'TxnType' and m4.RefNo = 1
						group by m1.BusnLocation) m on a.BusnLocation = m.BusnLocation
	where a.AcqNo = @AcqNo and a.PrcsId = @PrcsId

	if @@error <> 0
	begin
		rollback transaction
		return 70461	--Failed to update Statement No
	end

	--------------------------------------------------------------------------------------------------------
	--insert into table tmp_Contra
	--------------------------------------------------------------------------------------------------------
	insert tmp_Contra
		(BusnLocation, PrcsId, PrevBfwd, AccumBal, RecvPaymt, AfterCt, ActualCt, Ind)
	select a.BusnLocation, a.PrcsId, isnull(a.PrevBfwd,0), isnull(a.ClsBal,0), isnull(b.RecvPaymt,0), 0, 0, b.ContraInd
	from aac_AccountStatement a
	left outer join (select BusnLocation, TotalPaymt + CrAdjBal + CrTxnBal 'RecvPaymt', ContraInd
						from aac_AccountStatement
						where AcqNo = @AcqNo and PrcsId = @PrcsId) b on a.BusnLocation = b.BusnLocation
	where a.AcqNo = @AcqNo and a.ContraInd > 0

	if @@error <> 0
	begin
		rollback transaction
		return 95095 --Unable to update temporary table
	end

	--------------------------------------------------------------------------------------------------------
	--accumulate prev o/s & closing bal as AccumBal for tmp_Contra
	--------------------------------------------------------------------------------------------------------
	update a
	set AccumBal = AccumBal + isnull(b.PrevBfwd,0)
	from tmp_Contra a
	left outer join (select b1.BusnLocation, avg(b1.PrcsId + 1) 'PrcsId', sum(isnull(b2.PrevBfwd,0)) 'PrevBfwd'
						from tmp_Contra b1
						join (select BusnLocation, avg(PrcsId - 1) 'PrcsId', sum(isnull(PrevBfwd,0)) 'PrevBfwd'
								from tmp_Contra
								where PrcsId < @PrcsId and Ind > 0
								group by BusnLocation) b2 on b1.BusnLocation = b2.BusnLocation and b1.PrcsId = b2.PrcsId
						group by b1.BusnLocation) b on a.BusnLocation = b.BusnLocation and a.PrcsId = b.PrcsId

	if @@error <> 0
	begin
		rollback transaction
		return 95095 --Unable to update temporary table
	end

	--------------------------------------------------------------------------------------------------------
	--AfterCt (after contra) = 
	--------------------------------------------------------------------------------------------------------
/*	update tmp_Contra
	set AfterCt = RecvPaymt - AccumBal,
		PrevBfwd = 
		case
			when RecvPaymt - AccumBal >= 0 then PrevBfwd
			when RecvPaymt - AccumBal < 0 then PrevBfwd + (RecvPaymt - AccumBal)
		end,
		Ind = 
		case
			when RecvPaymt - AccumBal <= 0 then 0
			when RecvPaymt - AccumBal > 0 then 1
			else 1
		end
	where RecvPaymt <> 0
*/
	update tmp_Contra
	set AfterCt = RecvPaymt + AccumBal,
		PrevBfwd = 
		case
			when RecvPaymt + AccumBal = 0 then 0
			when RecvPaymt + AccumBal < 0 then RecvPaymt + AccumBal
			else RecvPaymt + AccumBal
		end,
		Ind = 
		case
			when RecvPaymt + AccumBal <= 0 then 0
			else 1
		end

	if @@error <> 0
	begin
		rollback transaction
		return 95095 --Unable to update temporary table
	end
/*
	update tmp_Contra
	set ActualCt = 
		case
			when PrevBfwd > AfterCt or PrevBfwd = 0 then PrevBfwd
			else PrevBfwd + AfterCt
		end
	where RecvPaymt <> 0
*/
	update tmp_Contra
	set ActualCt = 
		case
			when RecvPaymt + AccumBal <= 0 then AccumBal
			else abs(RecvPaymt + AccumBal)
		end

	if @@error <> 0
	begin
		rollback transaction
		return 95095 --Unable to update temporary table
	end
/*
	update tmp_Contra
	set Ind = 0
	where AccumBal = 0

	if @@error <> 0
	begin
		rollback transaction
		return 95095 --Unable to update temporary table
	end
*/
	update a
	set PrevBfwd = b.PrevBfwd,
		ContraPaymt = ActualCt,
		ContraInd = b.Ind
	from aac_AccountStatement a
	join tmp_Contra b on a.BusnLocation = b.BusnLocation and a.PrcsId = b.PrcsId

	if @@error <> 0
	begin
		rollback transaction
		return 70461	--Failed to update Statement No
	end

	--------------------------------------------------------------------------------------------------------
	--Auto cheque payment creation for credit merchant
	--------------------------------------------------------------------------------------------------------
	insert atx_SourceSettlement
		(AcqNo, BatchId, TxnCd, SettleDate, Cnt, Amt, Pts, BillingAmt, BillingPts, 
		Descp, BusnLocation, TermId, Stan, Rrn, InvoiceNo, OrigBatchNo, AcctNo, Mcc, 
		PrcsId, TxnInd, POSCondCd, ChequeNo, InputSrc, LinkIds, UserId, LastUpdDate, Sts)
	select 
		a.AcqNo, @MNLBatchId, @DeftPayMerchTxnCd, @PrcsDate + isnull(b.WithholdPaymtPeriod,0), 1, abs(a.ClsBal), 0, abs(a.ClsBal), 0, 
		@DeftPayerBusnName, @DeftPayerBusnLocation, null, 0, '9999999999', 0, @MNLBatchId, @DeftPayerAcctNo, null, 
		@PrcsId + isnull(b.WithholdPaymtPeriod,0), 'L', 0, null, @AutoPay, null, system_user, @PrcsDate, a.Sts
	from aac_AccountStatement a
	join aac_BusnLocation b (nolock) on a.AcqNo = b.AcqNo and a.BusnLocation = b.BusnLocation and b.WithholdInd = 'Y'
	where a.AcqNo = @AcqNo and a.PrcsId = @PrcsId and a.ClsBal < 0

	if @@error <> 0
	begin
		rollback tran
		return 70394	--Failed to add Settlement
	end

	insert atx_SourceTxn
		(SrcIds, AcqNo, BatchId, TxnCd, CardNo, CardExpiry, LocalDate, LocalTime, TxnDate, ArrayCnt, 
		Qty, Amt, Pts, BillingAmt, BillingPts, SrvcFee, VATAmt, SubsidizedAmt, Descp, BusnLocation, TermId, 
		CrryCd, CtryCd, InvoiceNo, Odometer, Rrn, AuthNo, PrcsId, LinkIds, TxnInd, WithheldUnsettleId, 
		IssBillingAmt,IssBillingPts, IssBatchId, UserId, LastUpdDate, Sts, 
		AuthCardNo, AuthCardExpiry, DriverCd, Arn, ExceptionCd)
	select
		Ids, AcqNo, BatchId, TxnCd, 0, 0, substring(convert(varchar(10),@PrcsDate,112),5,4), '0000', SettleDate, 0, 
		1, Amt, 0, BillingAmt, 0, 0, 0, 0, Descp, BusnLocation, TermId, 
		null, null, BatchId, 0, Rrn, '000000', PrcsId, null, TxnInd, 0, 
		0, 0, 0, UserId, LastUpdDate, Sts, 
		0, null, 0, null, null
	from atx_SourceSettlement
	where AcqNo = @AcqNo and BatchId = @MNLBatchId and LastUpdDate = @PrcsDate and TxnCd = @DeftPayMerchTxnCd

	if @@error <> 0
	begin
		rollback tran
		return 95202	--Failed to update atx_SourceTxn
	end

	--------------------------------------------------------------------------------------------------------
	--Auto update cycle date control
	--------------------------------------------------------------------------------------------------------
	if @MaxCycInd = 'Y'
	begin
		update acq_CycleDate
		set StmtDate = 	
			case 
				when @StmtFreqInd = "W" then dateadd(dd, @CycInterval, @PrcsDate)
				when @StmtFreqInd = "M" then dateadd(mm, @CycInterval, @PrcsDate) 
			end,
			DueDate = null,
			StmtCycId = 0,
			PrcsId = 0,
			LastUpdDate = getdate()
		where AcqNo = @AcqNo and CycNo = @CycNo and StmtFreqInd = @StmtFreqInd and CycSeq = (case when @CurrCycSeq = @MaxCycSeq then 1 else @CurrCycSeq + 1 end)

		if @@error <> 0
		begin
			rollback tran
			return 95166	--Cycle day does not match process date
		end
	end

	update acq_CycleDate
	set DueDate = @StmtDueDate,
		StmtCycId = @StmtCycId,
		PrcsId = @PrcsId,
		LastUpdDate = getdate()
	where AcqNo = @AcqNo and CycNo = @CycNo and StmtFreqInd = @StmtFreqInd and CycSeq = @CurrCycSeq

	if @@error <> 0
	begin
		rollback tran
		return 70919	--Failed to update Cycle Date
	end

	update iss_Control
	set CtrlNo = CtrlNo + 1,
		CtrlDate = @PrcsDate,
		LastUpdDate = getdate()
	where IssNo = @AcqNo and CtrlId = 'MerchStmtCycId'

	if @@error <> 0
	begin
		rollback transaction
		return 70331	--Failed to update Control
	end

	--------------------------------------------------------------------------------------------------------
	COMMIT TRANSACTION
	--------------------------------------------------------------------------------------------------------
	return 54026	--Statement processing completed successfully
end
GO
