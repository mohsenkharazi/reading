USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchForceSettlementExtract]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Acquiring Module

Objective	: This stored procedure is to calculates:

			-- MerchDiscRate, ValueAddedTax, WithholdingTax, SubsidizedAmt 
			-- To excludes in-house merchant.

Calling Sp	: 

Leveling	: Second level
------------------------------------------------------------------------------------------------------------------
When	   Who		CRN		Desc
------------------------------------------------------------------------------------------------------------------
2002/08/21 Sam				Initial development.
2003/09/02 Sam				To segregate card range, terminal sales values.
2003/09/03 Sam				To accum sales n compare tax id, tax reg name & addr for tax invoice no generation.
******************************************************************************************************************/

CREATE	procedure [dbo].[MerchForceSettlementExtract]
	@AcqNo uIssNo, 
	@PrcsId uPrcsId
  as
begin
	declare @PrcsDate datetime, @Date char(8), @BatchId int,
		@PrcsName varchar(50), @InputSrc uRefCd,
		@Cnt1 int, @Cnt2 int, @Cnt3 int, @Cnt4 int,
		@SysDate datetime, @CutOffDateTime datetime, @CutOffTime varchar(20),
		@ActiveSts uRefCd, @Rowcount int, @Error int,
		@Yy varchar(4), @Mn varchar(2), @Ids int, @TaxInvoice int

	set nocount on

	create table #ForceTxn
	(
		AcqNo smallint not null,
		Ids int not null,
		InputSrc varchar(10) not null,
		BatchId bigint not null,
		BusnLocation varchar(15) not null,
		TermId varchar(10) not null,
		TxnDate datetime not null,
		InvoiceNo int null,
		TxnCd bigint not null,
		CardNo bigint not null,
		CardExpiry char(4) null,
		Rrn varchar(12) null,
		Amt money not null,
		AuthNo char(6) not null,
		WithheldUnsettleId bigint null,
		Sts uRefCd not null,
		IssTxnCd int null
	)

	create table #SettleTxnByTxnCd
	(
		AcctNo bigint null,
		BusnLocation varchar(15) not null,
		TxnCd int not null,
		TaxId bigint null,
		AcctTaxId bigint null,
		CoRegName nvarchar(50) null,
		TaxRegAddr nvarchar(50) null,
		TaxInvoiceNo varchar(15) null,
		Cnt int not null,
		SettleAmt money not null,
		BillingAmt money null,
		PlanId int,
		SubsidizedPlanId int null,
		VATRate money null,
		WithholdingTaxRate money null,
		MDRAmt money null,
		VATAmt money null,
		WithholdingTaxAmt money null,
		SubsidizedAmt money null,
		BillingMethod money null,
		Sic varchar(10) null
	)

	create table #TaxAcct
	(
		Ids int identity(1,1) not null,
		BusnLocation varchar(15) null,
		AcctNo bigint null,
		TaxInvoiceNo varchar(15) null,
		BranchCd varchar(5) null	
	)

	select @SysDate = getdate()

	select @PrcsName = 'OnlineForceSettlementExtract'
	exec TraceProcess @AcqNo, @PrcsName, 'Start'

	--Retrieve Business Process ID
	if @PrcsId is null
	begin
		select @PrcsDate = CtrlDate, @PrcsId = CtrlNo, @Date = convert(char(8), CtrlDate,112)
		from iss_Control where IssNo = @AcqNo and CtrlId = 'PrcsId'
	end
	else
	begin
		select @PrcsDate = PrcsDate,
			@Date = convert(char(8), PrcsDate,112)
		from cmnv_ProcessLog where IssNo = @AcqNo and PrcsId = @PrcsId
	end

	exec @BatchId = NextRunNo @AcqNo, 'BatchId'
	select @BatchId = isnull(@BatchId, 0)

	select @CutOffTime = VarcharVal 
	from acq_Default where AcqNo = @AcqNo and IntVal = 1 and Deft = 'CutOffTime'
	if @@error <> 0 return 70368 --Failed to retrieve business date process id

	select @CutOffDateTime = cast((convert(varchar(15), @PrcsDate, 106)) + ' ' + @CutOffTime as datetime)

	select @InputSrc = RefCd from iss_RefLib where IssNo = @AcqNo and RefType = 'MerchInputSrc' and RefNo = 0

	select @ActiveSts = RefCd 
	from iss_RefLib where IssNo = @AcqNo and RefType = 'MerchBatchSts' and RefNo = 0

	if @ActiveSts is null return 95049 --Status Code is invalid

	select @Yy = substring(convert(varchar(4), dateadd(yyyy, 543, @PrcsDate)),3,2)
	select @Mn = convert(varchar(2), datepart(mm, @PrcsDate))
	----------
	begin tran
	----------

	--To compile batch settlement for txn extraction.
	insert into #ForceSettle
	(AcqNo, BusnLocation, TermId, BatchId, PrcsId)
	select a.AcqNo, a.BusnLocation, a.TermId, a.BatchId, a.PrcsId
	from atx_Settlement a
	where a.AcqNo = @AcqNo and a.PrcsId = @PrcsId

	select @Rowcount = @@rowcount, @Error = @@error

	if @Error <> 0
	begin
		rollback tran
		return 70394	--Failed to add Settlement
	end

	if @Rowcount = 0
	begin
		commit tran
		return 95210	--Extracted settlement with no transactions
	end

	--Extract manual txn to #SrcTxn
	insert #ForceTxn
	(AcqNo, Ids, InputSrc, BusnLocation, TermId, TxnDate, InvoiceNo, TxnCd, CardNo, CardExpiry, Rrn, Amt, AuthNo, WithheldUnsettleId, Sts, IssTxnCd, BatchId)
	select a.AcqNo, a.Ids, a.InputSrc, a.BusnLocation, a.TermId, a.TxnDate, a.InvoiceNo, a.TxnCd, a.CardNo, a.CardExpiry, a.Rrn, a.Amt, a.AuthNo, a.WithheldUnsettleId, @ActiveSts, a.IssTxnCd, a.BatchId
	from atx_Txn a
	join #ForceSettle b on a.AcqNo = b.AcqNo and PrcsId = @PrcsId and BatchId = @BatchId and a.TermId = b.TermId
	join iss_RefLib c on a.AcqNo = b.IssNo and a.TxnInd = b.RefCd and b.RefType = 'TxnInd' and b.RefInd = 0

	if @@error <> 0
	begin
		rollback tran
		return 70109	--Failed to insert into #SourceTxn table
	end

	--------------------
	--Store to temp file.
	--------------------

	--Segregate by card range.
	select a.BusnLocation, 
		c.CardRangeId, 
		a.TxnCd, 
		count(*) 'Cnt', 
		sum(isnull(Amt,0)) 'SettleAmt', 
		0.00 'BillingAmt',
		0 'PlanId', 
		0 'SubsidizedPlanId', 
		0.00 'VATRate', 
		0.00 'WithholdingTaxRate', 
		0.00 'MDRAmt', 
		0.00 'VATAmt', 
		0.00 'WithholdingTaxAmt', 
		0.00 'SubsidizedAmt',
		null 'BillMethod',
		null 'Sic'
	into #SettleTxnByCardRange
	from #ForceTxn a
	join iac_Card b on a.CardNo = b.CardNo
	join iss_CardType c on b.CardLogo = c.CardLogo and b.CardType = c.CardType
	where ForcePrcsId = @PrcsId
	group by a.BusnLocation, c.CardRangeId, a.TxnCd

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	--Segregate by terminal.
	select a.BusnLocation, 
		a.TermId, 
		a.TxnCd, 
		count(*) 'Cnt', 
		sum(isnull(Amt,0)) 'SettleAmt', 
		0.00 'BillingAmt',
		0 'PlanId', 
		0 'SubsidizedPlanId', 
		0.00 'VATRate', 
		0.00 'WithholdingTaxRate', 
		0.00 'MDRAmt', 
		0.00 'VATAmt', 
		0.00 'WithholdingTaxAmt', 
		0.00 'SubsidizedAmt',
		null 'BillMethod',
		null 'Sic'
	into #SettleTxnByTermId
	from #ForceTxn a
	join iac_Card b on a.CardNo = b.CardNo
	join iss_CardType c on b.CardLogo = c.CardLogo and b.CardType = c.CardType
	where ForcePrcsId = @PrcsId
	group by a.BusnLocation, a.TermId, a.TxnCd

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	--Segregate by txn code.
	insert #SettleTxnByTxnCd
	(BusnLocation, TxnCd, Cnt, SettleAmt)
	select a.BusnLocation, a.TxnCd, sum(isnull(Cnt,0)), sum(isnull(SettleAmt,0))
	from #SettleTxnByCardRange a
	group by a.BusnLocation, a.TxnCd

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	-------------
	--Update info.
	-------------
	update a
	set PlanId = b.PlanId,
		SubsidizedPlanId = b.SubsidizedPlanId,
		WithholdingTaxRate = isnull(d.WithholdingTaxRate, 0),
		VATRate = isnull(e.VATRate, 0),
		BillMethod = b.BillMethod,
		Sic = c.Sic
	from #SettleTxnByCardRange a
	join atx_TxnCode b on a.TxnCd = b.TxnCd
	join aac_BusnLocation c on a.BusnLocation = c.BusnLocation
	join aac_Account d on c.AcqNo = d.AcqNo and c.AcctNo = d.AcctNo
	join acq_Acquirer e on c.AcqNo = e.AcqNo

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	update a
	set PlanId = b.PlanId,
		SubsidizedPlanId = b.SubsidizedPlanId,
		WithholdingTaxRate = isnull(d.WithholdingTaxRate, 0),
		VATRate = isnull(e.VATRate, 0),
		BillMethod = b.BillMethod,
		Sic = c.Sic
	from #SettleTxnByTermId a
	join atx_TxnCode b on a.TxnCd = b.TxnCd
	join aac_BusnLocation c on a.BusnLocation = c.BusnLocation
	join aac_Account d on c.AcqNo = d.AcqNo and c.AcctNo = d.AcctNo
	join acq_Acquirer e on c.AcqNo = e.AcqNo

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	update a
	set PlanId = b.PlanId,
		SubsidizedPlanId = b.SubsidizedPlanId,
		WithholdingTaxRate = isnull(d.WithholdingTaxRate, 0),
		VATRate = isnull(e.VATRate, 0),
		BillMethod = b.BillMethod,
		Sic = c.Sic,
		TaxId = c.TaxId,
		CoRegName = c.CoRegName,
		AcctNo = d.AcctNo,
		TaxRegAddr = f.Street1
	from #SettleTxnByTxnCd a
	join atx_TxnCode b on a.TxnCd = b.TxnCd
	join aac_BusnLocation c on a.BusnLocation = c.BusnLocation
	join aac_Account d on c.AcqNo = d.AcqNo and c.AcctNo = d.AcctNo
	join acq_Acquirer e on c.AcqNo = e.AcqNo
	left outer join iss_Address f on c.AcqNo = f.IssNo and a.BusnLocation = f.RefKey and f.RefTo = 'BUSN' and f.RefType = 'ADDRESS' and f.RefCd = '22'

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	---------------------
	--To calculate MDRAmt. 
	---------------------

	--segregated by card range.
	update a set MDRAmt = round(
		case
		when a.SettleTxnAmt < c.FirstPurchAmt then
			dbo.GetMoneyMin(dbo.GetMoneyMax(c.MinBillingAmt,
			case
			when c.ProportionBillingAmt = 0 then
				0
			else
				round((a.SettleAmt / c.FirstPurchAmt * c.FirstBillingAmt),
				c.ProportionBillingAmt, 0)
			end ), c.MaxBillingAmt)
		else dbo.GetMoneyMin(dbo.GetMoneyMax((c.FirstBillingAmt +
			case
			when c.ProportionBillingAmt = 0 then
				round(((a.SettleAmt - c.FirstPurchAmt) / c.SubseqPurchAmt), 0, 1) *
				c.SubseqBillingAmt
			else
				round(((a.SettleAmt - c.FirstPurchAmt) / c.SubseqPurchAmt * 
				c.SubseqBillingAmt), c.ProportionBillingAmt, 0)
			end )
			,c.MinBillingAmt), c.MaxBillingAmt)
		end, c.AmtRoundLen, c.AmtRoundFunc)
	from #SettleTxnByCardRange a, atx_BillingPlan c
	where a.BillMethod in ('M', 'T') and a.Sic <> 'I'
	and c.AcqNo = @AcqNo and c.PlanId = a.PlanId
	and c.MinPurchAmt = ( select min(d.MinPurchAmt)
				from atx_BillingPlan d
				where d.AcqNo = @AcqNo and d.PlanId = a.PlanId
				and ((d.EffDateFrom is null and d.EffDateTo is null)
				or (d.EffDateTo is null and d.EffDateFrom is not null and a.PrcsDate >= d.EffDateFrom)
				or (d.EffDateFrom is null and d.EffDateTo is not null and a.PrcsDate <= d.EffDateTo)
				or (a.PrcsDate between d.EffDateFrom and d.EffDateTo))
				and d.MinPurchAmt >= a.SettleAmt )

	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	--Segregated by terminal.
	update a set MDRAmt = round(
		case
		when a.SettleTxnAmt < c.FirstPurchAmt then
			dbo.GetMoneyMin(dbo.GetMoneyMax(c.MinBillingAmt,
			case
			when c.ProportionBillingAmt = 0 then
				0
			else
				round((a.SettleAmt / c.FirstPurchAmt * c.FirstBillingAmt),
				c.ProportionBillingAmt, 0)
			end ), c.MaxBillingAmt)
		else dbo.GetMoneyMin(dbo.GetMoneyMax((c.FirstBillingAmt +
			case
			when c.ProportionBillingAmt = 0 then
				round(((a.SettleAmt - c.FirstPurchAmt) / c.SubseqPurchAmt), 0, 1) *
				c.SubseqBillingAmt
			else
				round(((a.SettleAmt - c.FirstPurchAmt) / c.SubseqPurchAmt * 
				c.SubseqBillingAmt), c.ProportionBillingAmt, 0)
			end )
			,c.MinBillingAmt), c.MaxBillingAmt)
		end, c.AmtRoundLen, c.AmtRoundFunc)
	from #SettleTxnByTermId a, atx_BillingPlan c
	where a.BillMethod in ('M', 'T') and a.Sic <> 'I'
	and c.AcqNo = @AcqNo and c.PlanId = a.PlanId
	and c.MinPurchAmt = ( select min(d.MinPurchAmt)
				from atx_BillingPlan d
				where d.AcqNo = @AcqNo and d.PlanId = a.PlanId
				and ((d.EffDateFrom is null and d.EffDateTo is null)
				or (d.EffDateTo is null and d.EffDateFrom is not null and a.PrcsDate >= d.EffDateFrom)
				or (d.EffDateFrom is null and d.EffDateTo is not null and a.PrcsDate <= d.EffDateTo)
				or (a.PrcsDate between d.EffDateFrom and d.EffDateTo))
				and d.MinPurchAmt >= a.SettleAmt )

	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	--Segregated by txn cd.
	update a set MDRAmt = round(
		case
		when a.SettleTxnAmt < c.FirstPurchAmt then
			dbo.GetMoneyMin(dbo.GetMoneyMax(c.MinBillingAmt,
			case
			when c.ProportionBillingAmt = 0 then
				0
			else
				round((a.SettleAmt / c.FirstPurchAmt * c.FirstBillingAmt),
				c.ProportionBillingAmt, 0)
			end ), c.MaxBillingAmt)
		else dbo.GetMoneyMin(dbo.GetMoneyMax((c.FirstBillingAmt +
			case
			when c.ProportionBillingAmt = 0 then
				round(((a.SettleAmt - c.FirstPurchAmt) / c.SubseqPurchAmt), 0, 1) *
				c.SubseqBillingAmt
			else
				round(((a.SettleAmt - c.FirstPurchAmt) / c.SubseqPurchAmt * 
				c.SubseqBillingAmt), c.ProportionBillingAmt, 0)
			end )
			,c.MinBillingAmt), c.MaxBillingAmt)
		end, c.AmtRoundLen, c.AmtRoundFunc)
	from #SettleTxnByTxnCd a, atx_BillingPlan c
	where a.BillMethod in ('M', 'T') and a.Sic <> 'I'
	and c.AcqNo = @AcqNo and c.PlanId = a.PlanId
	and c.MinPurchAmt = ( select min(d.MinPurchAmt)
				from atx_BillingPlan d
				where d.AcqNo = @AcqNo and d.PlanId = a.PlanId
				and ((d.EffDateFrom is null and d.EffDateTo is null)
				or (d.EffDateTo is null and d.EffDateFrom is not null and a.PrcsDate >= d.EffDateFrom)
				or (d.EffDateFrom is null and d.EffDateTo is not null and a.PrcsDate <= d.EffDateTo)
				or (a.PrcsDate between d.EffDateFrom and d.EffDateTo))
				and d.MinPurchAmt >= a.SettleAmt )

	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	-----------------------------------
	--To calculate HQ subsidized amount 
	-----------------------------------

	--Segregated by card range.
	update a set SubsidizedAmt = round(
		case
		when a.SettleTxnAmt < c.FirstPurchAmt then
			dbo.GetMoneyMin(dbo.GetMoneyMax(c.MinBillingAmt,
			case
			when c.ProportionBillingAmt = 0 then
				0
			else
				round((a.SettleAmt / c.FirstPurchAmt * c.FirstBillingAmt),
				c.ProportionBillingAmt, 0)
			end ), c.MaxBillingAmt)
		else dbo.GetMoneyMin(dbo.GetMoneyMax((c.FirstBillingAmt +
			case
			when c.ProportionBillingAmt = 0 then
				round(((a.SettleAmt - c.FirstPurchAmt) / c.SubseqPurchAmt), 0, 1) *
				c.SubseqBillingAmt
			else
				round(((a.SettleAmt - c.FirstPurchAmt) / c.SubseqPurchAmt * 
				c.SubseqBillingAmt), c.ProportionBillingAmt, 0)
			end )
			,c.MinBillingAmt), c.MaxBillingAmt)
		end, c.AmtRoundLen, c.AmtRoundFunc)
	from #SettleTxnByCardRange a, atx_BillingPlan c
	where a.BillMethod in ('M', 'T') and a.Sic <> 'I'
	and c.AcqNo = @AcqNo and c.PlanId = a.SubsidizedPlanId and isnull(a.SubsidizedPlanId, 0) > 0
	and c.MinPurchAmt = ( select min(d.MinPurchAmt)
				from atx_BillingPlan d
				where d.AcqNo = @AcqNo and d.PlanId = a.SubsidizedPlanId
				and ((d.EffDateFrom is null and d.EffDateTo is null)
				or (d.EffDateTo is null and d.EffDateFrom is not null and a.PrcsDate >= d.EffDateFrom)
				or (d.EffDateFrom is null and d.EffDateTo is not null and a.PrcsDate <= d.EffDateTo)
				or (a.PrcsDate between d.EffDateFrom and d.EffDateTo))
				and d.MinPurchAmt >= a.SettleAmt )

	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	--Segregated by terminal.
	update a set SubsidizedAmt = round(
		case
		when a.SettleTxnAmt < c.FirstPurchAmt then
			dbo.GetMoneyMin(dbo.GetMoneyMax(c.MinBillingAmt,
			case
			when c.ProportionBillingAmt = 0 then
				0
			else
				round((a.SettleAmt / c.FirstPurchAmt * c.FirstBillingAmt),
				c.ProportionBillingAmt, 0)
			end ), c.MaxBillingAmt)
		else dbo.GetMoneyMin(dbo.GetMoneyMax((c.FirstBillingAmt +
			case
			when c.ProportionBillingAmt = 0 then
				round(((a.SettleAmt - c.FirstPurchAmt) / c.SubseqPurchAmt), 0, 1) *
				c.SubseqBillingAmt
			else
				round(((a.SettleAmt - c.FirstPurchAmt) / c.SubseqPurchAmt * 
				c.SubseqBillingAmt), c.ProportionBillingAmt, 0)
			end )
			,c.MinBillingAmt), c.MaxBillingAmt)
		end, c.AmtRoundLen, c.AmtRoundFunc)
	from #SettleTxnByTermId a, atx_BillingPlan c
	where a.BillMethod in ('M', 'T') and a.Sic <> 'I'
	and c.AcqNo = @AcqNo and c.PlanId = a.SubsidizedPlanId and isnull(a.SubsidizedPlanId, 0) > 0
	and c.MinPurchAmt = ( select min(d.MinPurchAmt)
				from atx_BillingPlan d
				where d.AcqNo = @AcqNo and d.PlanId = a.SubsidizedPlanId
				and ((d.EffDateFrom is null and d.EffDateTo is null)
				or (d.EffDateTo is null and d.EffDateFrom is not null and a.PrcsDate >= d.EffDateFrom)
				or (d.EffDateFrom is null and d.EffDateTo is not null and a.PrcsDate <= d.EffDateTo)
				or (a.PrcsDate between d.EffDateFrom and d.EffDateTo))
				and d.MinPurchAmt >= a.SettleAmt )

	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	--Segregated by txn cd.
	update a set SubsidizedAmt = round(
		case
		when a.SettleTxnAmt < c.FirstPurchAmt then
			dbo.GetMoneyMin(dbo.GetMoneyMax(c.MinBillingAmt,
			case
			when c.ProportionBillingAmt = 0 then
				0
			else
				round((a.SettleAmt / c.FirstPurchAmt * c.FirstBillingAmt),
				c.ProportionBillingAmt, 0)
			end ), c.MaxBillingAmt)
		else dbo.GetMoneyMin(dbo.GetMoneyMax((c.FirstBillingAmt +
			case
			when c.ProportionBillingAmt = 0 then
				round(((a.SettleAmt - c.FirstPurchAmt) / c.SubseqPurchAmt), 0, 1) *
				c.SubseqBillingAmt
			else
				round(((a.SettleAmt - c.FirstPurchAmt) / c.SubseqPurchAmt * 
				c.SubseqBillingAmt), c.ProportionBillingAmt, 0)
			end )
			,c.MinBillingAmt), c.MaxBillingAmt)
		end, c.AmtRoundLen, c.AmtRoundFunc)
	from #SettleTxnByTxnCd a, atx_BillingPlan c
	where a.BillMethod in ('M', 'T') and a.Sic <> 'I'
	and c.AcqNo = @AcqNo and c.PlanId = a.SubsidizedPlanId and isnull(a.SubsidizedPlanId, 0) > 0
	and c.MinPurchAmt = ( select min(d.MinPurchAmt)
				from atx_BillingPlan d
				where d.AcqNo = @AcqNo and d.PlanId = a.SubsidizedPlanId
				and ((d.EffDateFrom is null and d.EffDateTo is null)
				or (d.EffDateTo is null and d.EffDateFrom is not null and a.PrcsDate >= d.EffDateFrom)
				or (d.EffDateFrom is null and d.EffDateTo is not null and a.PrcsDate <= d.EffDateTo)
				or (a.PrcsDate between d.EffDateFrom and d.EffDateTo))
				and d.MinPurchAmt >= a.SettleAmt )

	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	------------------------------
	--To calculate value added tax.
	------------------------------
	update #SettleTxnByCardRange
	set VATAmt = SettleAmt * (isnull(VATRate, 0) / 100)
	where Sic <> 'I' and SettleAmt > 0

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	update #SettleTxnByTermId
	set VATAmt = SettleAmt * (isnull(VATRate, 0) / 100)
	where Sic <> 'I' and SettleAmt > 0

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	update #SettleTxnByTxnCd
	set VATAmt = SettleAmt * (isnull(VATRate, 0) / 100)
	where Sic <> 'I' and SettleAmt > 0

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	----------------------------------
	--To calculate withholding tax amt.
	----------------------------------
	update #SettleTxnByCardRange
	set WithholdingTaxAmt = MDRAmt * (isnull(WithholdingTaxRate, 0) / 100)
	where Sic <> 'I' and SettleAmt > 0

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	update #SettleTxnByTermId
	set WithholdingTaxAmt = MDRAmt * (isnull(WithholdingTaxRate, 0) / 100)
	where Sic <> 'I' and SettleAmt > 0

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	update #SettleTxnByTxnCd
	set WithholdingTaxAmt = MDRAmt * (isnull(WithholdingTaxRate, 0) / 100)
	where Sic <> 'I' and SettleAmt > 0

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	-------------------------------------
	--To calculate the actual billing amt.
	-------------------------------------
	update #SettleTxnByCardRange
	set BillingAmt = isnull(SettleAmt, 0) - (isnull(MDRAmt, 0) + isnull(VATAmt, 0))

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	update #SettleTxnByTermId
	set BillingAmt = isnull(SettleAmt, 0) - (isnull(MDRAmt, 0) + isnull(VATAmt, 0))

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	update #SettleTxnByTxnCd
	set BillingAmt = isnull(SettleAmt, 0) - (isnull(MDRAmt, 0) + isnull(VATAmt, 0))

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	update a
	set AcctTaxId = d.TaxId
	from #SettleTxnByTxnCd a
	join (select AcctNo, TaxId, CoRegName, Street1 from aac_Account b left outer join iss_Address c on b.AcqNo = c.IssNo and b.AcctNo = c.RefKey and c.RefTo = 'MERCH' and c.RefType = 'ADDRESS' and c.RefCd = '22') as d on a.AcctNo = d.AcctNo and a.TaxId = d.TaxId and a.CoRegName = d.CoRegName and a.TaxRegAddr = d.Street1

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	insert #TaxAcct
	(BusnLocation)
	select BusnLocation
	from #SettleTxnByTxnCd where AcctTaxId is null
	group by BusnLocation

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	insert #TaxAcct
	(AcctNo)
	select AcctNo
	from #SettleTxnByTxnCd where AcctTaxId is not null
	group by AcctNo

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	update a
	set BranchCd = b.BranchCd
	from #TaxAcct a
	join aac_BusnLocation b on a.BusnLocation = b.BusnLocation 
	where a.AcctTaxId is null

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	update a
	set BranchCd = b.BranchCd
	from #TaxAcct a
	join aac_Account b on a.AcctNo = b.AcctNo
	where a.AcctTaxId is not null

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	select @Ids = min(Ids) from #TaxAcct
	while @Ids is not null
	begin
		exec @TaxInvoice = NextTaxInvoice @AcqNo, @PrcsDate, 'TaxInvoice'

		update #TaxAcct
		set TaxId = BranchCd + @Yy + @Mn + '04' + replicate('0', 6 - len(convert(varchar(6), @TaxInvoice))) + convert(varchar(6), @TaxInvoice)
		where Ids = @Ids

		if @@error <> 0
		begin
			rollback tran
			return 95278 --Check error on temp file
		end

		select @Ids = min(Ids) from #TaxAcct where Ids > @Ids
	end

	update a
	set TaxInvoiceNo = b.TaxInvoiceNo
	from #SettleTxnByTxnCd a 
	join #TaxAcct b on a.BusnLocation = b.BusnLocation
	where a.AcctTaxId is null

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	update a
	set TaxInvoiceNo = b.TaxInvoiceNo
	from #SettleTxnByTxnCd a 
	join #TaxAcct b on a.AcctNo = b.AcctNo 
	where a.AcctTaxId is not null

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	--------------
	--Update sales.
	--------------
	insert acq_MerchSalesByCardRange
	(AcqNo, BusnLocation, CardRangeId, TxnCd, PrcsId, Cnt, SettleAmt, BillingAmt, MDRAmt, VATAmt, WithholdingTaxAmt, SubsidizedAmt, PlanId, SubsidizedPlanId, VATRate, WithholdingTaxRate, LastUpdDate)
	select @AcqNo, BusnLocation, CardRangeId, TxnCd, @PrcsId, Cnt, SettleAmt, BillingAmt, isnull(MDRAmt, 0), isnull(VATAmt, 0), isnull(WithholdingTaxAmt, 0), isnull(SubsudizesAmt, 0), PlanId, SubsidizedPlanId, VATRate, WithholdingTaxRate, @SysDate
	from #SettleTxnByCardRange

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	insert acq_MerchSalesByTerminal
	(AcqNo, BusnLocation, TermId, TxnCd, PrcsId, Cnt, SettleAmt, BillingAmt, MDRAmt, VATAmt, WithholdingTaxAmt, SubsidizedAmt, PlanId, SubsidizedPlanId, VATRate, WithholdingTaxRate, LastUpdDate)
	select @AcqNo, BusnLocation, TermId, TxnCd, @PrcsId, Cnt, SettleAmt, BillingAmt, isnull(MDRAmt, 0), isnull(VATAmt, 0), isnull(WithholdingTaxAmt, 0), isnull(SubsudizesAmt, 0), PlanId, SubsidizedPlanId, VATRate, WithholdingTaxRate, @SysDate
	from #SettleTxnByTermId

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	insert acq_MerchTaxInvoice
	(AcqNo, BusnLocation, TxnCd, PrcsId, Cnt, SettleAmt, BillingAmt, MDRAmt, VATAmt, WithholdingTaxAmt, SubsidizedAmt, PlanId, SubsidizedPlanId, VATRate, WithholdingTaxRate, LastUpdDate, TaxId, AcctTaxId, AcctNo, TaxInvoiceNo, PrcsDate)
	select @AcqNo, BusnLocation, TxnCd, @PrcsId, Cnt, SettleAmt, BillingAmt, isnull(MDRAmt, 0), isnull(VATAmt, 0), isnull(WithholdingTaxAmt, 0), isnull(SubsudizesAmt, 0), PlanId, SubsidizedPlanId, VATRate, WithholdingTaxRate, @SysDate, TaxId, AcctTaxId, AcctNo, TaxInvoiceNo, @PrcsDate
	from #SettleTxnByTxnCd

	select @Rowcount = @@rowcount, @Error = @@error

	if @@error <> 0
	begin
		rollback tran
		return 1
	end

	drop table #ForceSettle
	drop table #ForceTxn
	drop table #SettleTxnByCardRange
	drop table #SettleTxnByTerminal
	drop table #SettleTxnByTxnCd
	drop table #TaxAcct

	exec TraceProcess @AcqNo, @PrcsName, 'End'

	commit tran
	return 0
end
GO
