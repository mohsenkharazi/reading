USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchMiscTxnFeeCalculation]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure calculate miscellaneous transaction fees

SP Level	: Primary

-------------------------------------------------------------------------------
When	   Who		CRN	   Desc
-------------------------------------------------------------------------------
2007/03/08 KY			   Initial development

******************************************************************************************************************/
-- exec MerchMiscTxnFeeCalculation 1
CREATE	procedure [dbo].[MerchMiscTxnFeeCalculation]
	@AcqNo uIssNo,
	@PrcsId uPrcsId = null
  as
begin
	declare @TxnMerchFeeType nvarchar(50), @GSTFeeType nvarchar(50), @MerchAgentFeeType nvarchar(50), @CardAgentFeeType nvarchar(50),
		@SpecialPromoTxnCd int

	--------------------------------------------
	-- retrive default value from iss_Default --
	--------------------------------------------

	select @TxnMerchFeeType = RefCd
	from iss_RefLib
	where IssNo = @AcqNo and RefType = 'MiscTxnFeeType' and (RefNo & 1) > 0

	select @GSTFeeType = RefCd
	from iss_RefLib
	where IssNo = @AcqNo and RefType = 'MiscTxnFeeType' and (RefNo & 2) > 0

	select @MerchAgentFeeType = RefCd
	from iss_RefLib
	where IssNo = @AcqNo and RefType = 'MiscTxnFeeType' and (RefNo & 4) > 0

	select @CardAgentFeeType = RefCd
	from iss_RefLib
	where IssNo = @AcqNo and RefType = 'MiscTxnFeeType' and (RefNo & 8) > 0

	/*select @SpecialPromoTxnCd = IntVal
	from iss_Default
	where IssNo = @AcqNo and Deft = 'SpecialPromoTxnCd'*/

	-------------------------------------------------------------------------------
	-- create temporary tables to store all transactions are going to be process --
	-------------------------------------------------------------------------------

	select a.Ids, a.BillMethod, a.PrcsId, a.Amt, d.MiscTxnFeePlanId, d.MiscTxnFeeType, cast(0.00 as money) 'PtsCalc', 
		cast(0.00 as money) 'AcqPtsCalc', cast(0.00 as money) 'IssPtsCalc', min(d.MinPurchAmt) 'MinPurchAmt',
		cast(0.00 as money) 'FirstPurchAmt', cast(0.00 as money) 'FirstBillingAmt', cast(0.00 as money) 'FirstBillingPts',
		cast(0.00 as money) 'SubseqPurchAmt', cast(0.00 as money) 'SubseqBillingAmt', cast(0.00 as money) 'SubseqBillingPts',
		cast(0.00 as money) 'ProportionBillingAmt', cast(0.00 as money) 'ProportionBillingPts',
		cast(0.00 as money) 'MinBillingAmt', cast(0.00 as money) 'MinBillingPts', cast(0.00 as money) 'MaxBillingAmt', cast(0.00 as money) 'MaxBillingPts',
		cast(0.00 as money) 'AmtRoundLen', cast(0.00 as money) 'AmtRoundFunc', cast(0.00 as money) 'PtsRoundLen', cast(0.00 as money) 'PtsRoundFunc'
	into #SourceMiscTxnFeePlan	
	from atx_Txn as a
	join (select b1.TxnCd, b3.PlanId
		from atx_TxnCode b1, itx_TxnCategory b2, itx_TxnCode b3
		where b1.AcqNo = @AcqNo and b1.Multiplier = 'DB' --and b1.TxnCd <> @SpecialPromoTxnCd
			and b1.IssNo = b2.IssNo and b1.Category = b2.Category and b2.Category = 1
			and b1.AcqNo = b3.IssNo and b1.IssTxnCd = b3.TxnCd
	) as b on a.TxnCd = b.TxnCd
	join cmnv_ProcessLog as c on c.IssNo = @AcqNo and a.PrcsId = c.PrcsId
	join cmn_MiscTxnFeePlan as d on b.PlanId = d.MiscTxnFeePlanId and a.Amt <= d.MinPurchAmt
		and (d.EffDateFrom is null or convert(varchar(8), d.EffDateFrom, 112) <= convert(varchar(8), c.PrcsDate, 112)) 
		and (d.EffDateTo is null or convert(varchar(8), isnull(d.EffDateTo, getdate()), 112) >= convert(varchar(8), c.PrcsDate, 112))
	where not exists (select 1 from atx_MiscTxnFee e where a.Ids = e.Ids)
	group by a.Ids, a.BillMethod, a.PrcsId, a.Amt, d.MiscTxnFeePlanId, d.MiscTxnFeeType

	select c.SrcIds, c.Seq, c.ProdCd, c.AmtPts, a.BillMethod, a.PrcsId, e.MiscTxnFeePlanId, e.MiscTxnFeeType, cast(0.00 as money) 'PtsCalc', 
		cast(0.00 as money) 'AcqPtsCalc', cast(0.00 as money) 'IssPtsCalc', min(e.MinPurchAmt) 'MinPurchAmt',
		cast(0.00 as money) 'FirstPurchAmt', cast(0.00 as money) 'FirstBillingAmt', cast(0.00 as money) 'FirstBillingPts',
		cast(0.00 as money) 'SubseqPurchAmt', cast(0.00 as money) 'SubseqBillingAmt', cast(0.00 as money) 'SubseqBillingPts',
		cast(0.00 as money) 'ProportionBillingAmt', cast(0.00 as money) 'ProportionBillingPts',
		cast(0.00 as money) 'MinBillingAmt', cast(0.00 as money) 'MinBillingPts', cast(0.00 as money) 'MaxBillingAmt', cast(0.00 as money) 'MaxBillingPts',
		cast(0.00 as money) 'AmtRoundLen', cast(0.00 as money) 'AmtRoundFunc', cast(0.00 as money) 'PtsRoundLen', cast(0.00 as money) 'PtsRoundFunc'
	into #SourceMiscTxnFeeDetailPlan
	from atx_Txn as a
	join (select b1.TxnCd, b3.PlanId
		from atx_TxnCode b1, itx_TxnCategory b2, itx_TxnCode b3
		where b1.AcqNo = @AcqNo and b1.Multiplier = 'DB' --and b1.TxnCd <> @SpecialPromoTxnCd
			and b1.IssNo = b2.IssNo and b1.Category = b2.Category and b2.Category = 1
			and b1.AcqNo = b3.IssNo and b1.IssTxnCd = b3.TxnCd
	) as b on a.TxnCd = b.TxnCd
	join atx_TxnDetail as c on a.SrcIds = c.ParentIds and not exists (select 1 from atx_MiscTxnFeeDetail c1 where c.SrcIds = c1.SrcIds and c.Seq = c1.Seq)
	join cmnv_ProcessLog as d on d.IssNo = @AcqNo and a.PrcsId = d.PrcsId
	join cmn_MiscTxnFeePlan as e on b.PlanId = e.MiscTxnFeePlanId and c.AmtPts <= e.MinPurchAmt
		and (e.EffDateFrom is null or convert(varchar(8), e.EffDateFrom, 112) <= convert(varchar(8), d.PrcsDate, 112)) 
		and (e.EffDateTo is null or convert(varchar(8), isnull(e.EffDateTo, getdate()), 112) >= convert(varchar(8), d.PrcsDate, 112))
	group by c.SrcIds, c.Seq, c.ProdCd, c.AmtPts, a.BillMethod, a.PrcsId, e.MiscTxnFeePlanId, e.MiscTxnFeeType

	select a.Ids, d.PlanId, min(d.MinPurchAmt) 'MinPurchAmt', 
		cast(0.00 as money) 'FirstPurchAmt', cast(0.00 as money) 'FirstBillingAmt', cast(0.00 as money) 'FirstBillingPts',
		cast(0.00 as money) 'SubseqPurchAmt', cast(0.00 as money) 'SubseqBillingAmt', cast(0.00 as money) 'SubseqBillingPts',
		cast(0.00 as money) 'ProportionBillingAmt', cast(0.00 as money) 'ProportionBillingPts',
		cast(0.00 as money) 'MinBillingAmt', cast(0.00 as money) 'MinBillingPts', cast(0.00 as money) 'MaxBillingAmt', cast(0.00 as money) 'MaxBillingPts',
		cast(0.00 as money) 'AmtRoundLen', cast(0.00 as money) 'AmtRoundFunc', cast(0.00 as money) 'PtsRoundLen', cast(0.00 as money) 'PtsRoundFunc'
	into #itx_BillingPlan
	from atx_Txn as a
	join (select b1.TxnCd, b1.IssTxnCd, b3.PlanId
		from atx_TxnCode b1, itx_TxnCategory b2, itx_TxnCode b3
		where b1.AcqNo = @AcqNo and b1.Multiplier = 'DB' --and b1.TxnCd <> @SpecialPromoTxnCd
			and b1.IssNo = b2.IssNo and b1.Category = b2.Category and b2.Category = 1
			and b1.AcqNo = b3.IssNo and b1.IssTxnCd = b3.TxnCd
	) as b on a.TxnCd = b.TxnCd
	join cmnv_ProcessLog as c on c.IssNo = @AcqNo and a.PrcsId = c.PrcsId
	join itx_BillingPlan as d on c.IssNo = d.IssNo and b.PlanId = d.PlanId and a.Amt <= d.MinPurchAmt
		and (d.EffDateFrom is null or convert(varchar(8), d.EffDateFrom, 112) <= convert(varchar(8), c.PrcsDate, 112)) 
		and (d.EffDateTo is null or convert(varchar(8), isnull(d.EffDateTo, getdate()), 112) >= convert(varchar(8), c.PrcsDate, 112))
	group by a.Ids, d.PlanId

	-------------------------------------------------
	-- update all the plan detail into temp tables --
	-------------------------------------------------

	update a	set a.FirstPurchAmt = b.FirstPurchAmt, a.FirstBillingAmt = b.FirstBillingAmt, a.FirstBillingPts = b.FirstBillingPts,
		a.SubseqPurchAmt = b.SubseqPurchAmt, a.SubseqBillingAmt = b.SubseqBillingAmt, a.SubseqBillingPts = b.SubseqBillingPts,
		a.ProportionBillingAmt = b.ProportionBillingAmt, a.ProportionBillingPts = b.ProportionBillingPts,
		a.MinBillingAmt = b.MinBillingAmt, a.MinBillingPts = b.MinBillingPts, a.MaxBillingAmt = b.MaxBillingAmt, a.MaxBillingPts = b.MaxBillingPts,
		a.AmtRoundLen = b.AmtRoundLen, a.AmtRoundFunc = b.AmtRoundFunc, a.PtsRoundLen = b.PtsRoundLen, a.PtsRoundFunc = b.PtsRoundFunc
	from #SourceMiscTxnFeePlan as a
	join cmn_MiscTxnFeePlan as b on a.MiscTxnFeePlanId = b.MiscTxnFeePlanId and a.MiscTxnFeeType = b.MiscTxnFeeType and a.MinPurchAmt = b.MinPurchAmt

	update a	set a.FirstPurchAmt = b.FirstPurchAmt, a.FirstBillingAmt = b.FirstBillingAmt, a.FirstBillingPts = b.FirstBillingPts,
		a.SubseqPurchAmt = b.SubseqPurchAmt, a.SubseqBillingAmt = b.SubseqBillingAmt, a.SubseqBillingPts = b.SubseqBillingPts,
		a.ProportionBillingAmt = b.ProportionBillingAmt, a.ProportionBillingPts = b.ProportionBillingPts,
		a.MinBillingAmt = b.MinBillingAmt, a.MinBillingPts = b.MinBillingPts, a.MaxBillingAmt = b.MaxBillingAmt, a.MaxBillingPts = b.MaxBillingPts,
		a.AmtRoundLen = b.AmtRoundLen, a.AmtRoundFunc = b.AmtRoundFunc, a.PtsRoundLen = b.PtsRoundLen, a.PtsRoundFunc = b.PtsRoundFunc
	from #SourceMiscTxnFeeDetailPlan as a
	join cmn_MiscTxnFeePlan as b on a.MiscTxnFeePlanId = b.MiscTxnFeePlanId and a.MiscTxnFeeType = b.MiscTxnFeeType and a.MinPurchAmt = b.MinPurchAmt

	update a	set a.FirstPurchAmt = b.FirstPurchAmt, a.FirstBillingAmt = b.FirstBillingAmt, a.FirstBillingPts = b.FirstBillingPts,
		a.SubseqPurchAmt = b.SubseqPurchAmt, a.SubseqBillingAmt = b.SubseqBillingAmt, a.SubseqBillingPts = b.SubseqBillingPts,
		a.ProportionBillingAmt = b.ProportionBillingAmt, a.ProportionBillingPts = b.ProportionBillingPts,
		a.MinBillingAmt = b.MinBillingAmt, a.MinBillingPts = b.MinBillingPts, a.MaxBillingAmt = b.MaxBillingAmt, a.MaxBillingPts = b.MaxBillingPts,
		a.AmtRoundLen = b.AmtRoundLen, a.AmtRoundFunc = b.AmtRoundFunc, a.PtsRoundLen = b.PtsRoundLen, a.PtsRoundFunc = b.PtsRoundFunc
	from #itx_BillingPlan as a
	join itx_BillingPlan as b on b.IssNo = @AcqNo and a.PlanId = b.PlanId and a.MinPurchAmt = b.MinPurchAmt

	------------------------------------
	-- calculate billing point amount --
	------------------------------------
	
	-- TxnMerchFeeType by Transaction Level Calculation 
	update #SourceMiscTxnFeePlan
	set PtsCalc = case
		when FirstPurchAmt = 0 and SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round((Amt / SubseqPurchAmt) * SubseqBillingPts, PtsRoundLen, PtsRoundFunc), MinBillingPts), MaxBillingPts)
		when Amt > FirstPurchAmt and FirstPurchAmt > 0 and SubseqPurchAmt = 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(FirstBillingPts, PtsRoundLen, PtsRoundFunc), MinBillingPts), MaxBillingPts)
		when Amt > FirstPurchAmt and FirstPurchAmt > 0 and SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(FirstBillingPts + (((Amt - FirstPurchAmt) / SubseqPurchAmt) * SubseqBillingPts), PtsRoundLen, PtsRoundFunc), MinBillingPts), MaxBillingPts)
		else 0 end 
	where MiscTxnFeeType = @TxnMerchFeeType

	-- GSTFeeType by Transaction Level Calculation 
	update a
	set a.PtsCalc = case
		when a.FirstPurchAmt = 0 and a.SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round((b.PtsCalc / a.SubseqPurchAmt) * a.SubseqBillingPts, a.PtsRoundLen, a.PtsRoundFunc), a.MinBillingPts), a.MaxBillingPts)
		when b.PtsCalc > a.FirstPurchAmt and a.FirstPurchAmt > 0 and a.SubseqPurchAmt = 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(a.FirstBillingPts, a.PtsRoundLen, a.PtsRoundFunc), a.MinBillingPts), a.MaxBillingPts)
		when b.PtsCalc > a.FirstPurchAmt and a.FirstPurchAmt > 0 and a.SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(a.FirstBillingPts + (((b.PtsCalc - a.FirstPurchAmt) / a.SubseqPurchAmt) * a.SubseqBillingPts), a.PtsRoundLen, a.PtsRoundFunc), a.MinBillingPts), a.MaxBillingPts)
		else 0 end
	from #SourceMiscTxnFeePlan as a
	join #SourceMiscTxnFeePlan as b on a.Ids = b.Ids and b.MiscTxnFeeType = @TxnMerchFeeType
	where a.MiscTxnFeeType = @GSTFeeType

	-- Issuer Points (Cardholder) by Transaction Level Calculation 
	update a
	set a.IssPtsCalc = case
		when c.FirstPurchAmt = 0 and c.SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round((b.PtsCalc / c.SubseqPurchAmt) * c.SubseqBillingPts, c.PtsRoundLen, c.PtsRoundFunc), c.MinBillingPts), c.MaxBillingPts)
		when b.PtsCalc > c.FirstPurchAmt and c.FirstPurchAmt > 0 and c.SubseqPurchAmt = 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(c.FirstBillingPts, c.PtsRoundLen, c.PtsRoundFunc), c.MinBillingPts), c.MaxBillingPts)
		when b.PtsCalc > c.FirstPurchAmt and c.FirstPurchAmt > 0 and c.SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(c.FirstBillingPts + (((b.PtsCalc - c.FirstPurchAmt) / c.SubseqPurchAmt) * c.SubseqBillingPts), c.PtsRoundLen, c.PtsRoundFunc), c.MinBillingPts), c.MaxBillingPts)
		else 0 end
	from #SourceMiscTxnFeePlan as a
	join (select b1.Ids, b1.PtsCalc - b2.PtsCalc 'PtsCalc'
		from #SourceMiscTxnFeePlan b1, #SourceMiscTxnFeePlan b2
		where b1.Ids = b2.Ids and b1.MiscTxnFeeType = @TxnMerchFeeType and b2.MiscTxnFeeType = @GSTFeeType
	) as b on a.Ids = b.Ids
	join #itx_BillingPlan as c on a.Ids = c.Ids and a.MiscTxnFeePlanId = c.PlanId

	-- Acquirer Points (Merchant) by Transaction Level Calculation 
	update a
	set a.AcqPtsCalc = b.PtsCalc - a.IssPtsCalc
	from #SourceMiscTxnFeePlan as a
	join (select b1.Ids, b1.PtsCalc - b2.PtsCalc 'PtsCalc'
		from #SourceMiscTxnFeePlan b1, #SourceMiscTxnFeePlan b2
		where b1.Ids = b2.Ids and b1.MiscTxnFeeType = @TxnMerchFeeType and b2.MiscTxnFeeType = @GSTFeeType
	) as b on a.Ids = b.Ids

	-- MerchAgentFeeType by Transaction Level Calculation 
	update #SourceMiscTxnFeePlan
	set PtsCalc = case
		when FirstPurchAmt = 0 and SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round((AcqPtsCalc / SubseqPurchAmt) * SubseqBillingPts, PtsRoundLen, PtsRoundFunc), MinBillingPts), MaxBillingPts)
		when AcqPtsCalc > FirstPurchAmt and FirstPurchAmt > 0 and SubseqPurchAmt = 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(FirstBillingPts, PtsRoundLen, PtsRoundFunc), MinBillingPts), MaxBillingPts)
		when AcqPtsCalc > FirstPurchAmt and FirstPurchAmt > 0 and SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(FirstBillingPts + (((AcqPtsCalc - FirstPurchAmt) / SubseqPurchAmt) * SubseqBillingPts), PtsRoundLen, PtsRoundFunc), MinBillingPts), MaxBillingPts)
		else 0 end
	where MiscTxnFeeType = @MerchAgentFeeType

	-- CardAgentFeeType by Transaction Level Calculation 
	update #SourceMiscTxnFeePlan
	set PtsCalc = case
		when FirstPurchAmt = 0 and SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round((AcqPtsCalc / SubseqPurchAmt) * SubseqBillingPts, PtsRoundLen, PtsRoundFunc), MinBillingPts), MaxBillingPts)
		when AcqPtsCalc > FirstPurchAmt and FirstPurchAmt > 0 and SubseqPurchAmt = 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(FirstBillingPts, PtsRoundLen, PtsRoundFunc), MinBillingPts), MaxBillingPts)
		when AcqPtsCalc > FirstPurchAmt and FirstPurchAmt > 0 and SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(FirstBillingPts + (((AcqPtsCalc - FirstPurchAmt) / SubseqPurchAmt) * SubseqBillingPts), PtsRoundLen, PtsRoundFunc), MinBillingPts), MaxBillingPts)
		else 0 end
	where MiscTxnFeeType = @CardAgentFeeType

	-- TxnMerchFeeType by Product Level Calculation 
	update #SourceMiscTxnFeeDetailPlan
	set PtsCalc = case
		when FirstPurchAmt = 0 and SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round((AmtPts / SubseqPurchAmt) * SubseqBillingPts, PtsRoundLen, PtsRoundFunc), MinBillingPts), MaxBillingPts)
		when AmtPts > FirstPurchAmt and FirstPurchAmt > 0 and SubseqPurchAmt = 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(FirstBillingPts, PtsRoundLen, PtsRoundFunc), MinBillingPts), MaxBillingPts)
		when AmtPts > FirstPurchAmt and FirstPurchAmt > 0 and SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(FirstBillingPts + (((AmtPts - FirstPurchAmt) / SubseqPurchAmt) * SubseqBillingPts), PtsRoundLen, PtsRoundFunc), MinBillingPts), MaxBillingPts)
		else 0 end 
	where MiscTxnFeeType = @TxnMerchFeeType

	-- GSTFeeType by Product Level Calculation 
	update a
	set a.PtsCalc = case
		when a.FirstPurchAmt = 0 and a.SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round((b.PtsCalc / a.SubseqPurchAmt) * a.SubseqBillingPts, a.PtsRoundLen, a.PtsRoundFunc), a.MinBillingPts), a.MaxBillingPts)
		when b.PtsCalc > a.FirstPurchAmt and a.FirstPurchAmt > 0 and a.SubseqPurchAmt = 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(a.FirstBillingPts, a.PtsRoundLen, a.PtsRoundFunc), a.MinBillingPts), a.MaxBillingPts)
		when b.PtsCalc > a.FirstPurchAmt and a.FirstPurchAmt > 0 and a.SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(a.FirstBillingPts + (((b.PtsCalc - a.FirstPurchAmt) / a.SubseqPurchAmt) * a.SubseqBillingPts), a.PtsRoundLen, a.PtsRoundFunc), a.MinBillingPts), a.MaxBillingPts)
		else 0 end
	from #SourceMiscTxnFeeDetailPlan as a
	join #SourceMiscTxnFeeDetailPlan as b on a.SrcIds = b.SrcIds and a.Seq = b.Seq and b.MiscTxnFeeType = @TxnMerchFeeType
	where a.MiscTxnFeeType = @GSTFeeType

	-- Issuer Points (Cardholder) by Product Level Calculation 
	update a
	set a.IssPtsCalc = case
		when c.FirstPurchAmt = 0 and c.SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round((b.PtsCalc / c.SubseqPurchAmt) * c.SubseqBillingPts, c.PtsRoundLen, c.PtsRoundFunc), c.MinBillingPts), c.MaxBillingPts)
		when b.PtsCalc > c.FirstPurchAmt and c.FirstPurchAmt > 0 and c.SubseqPurchAmt = 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(c.FirstBillingPts, c.PtsRoundLen, c.PtsRoundFunc), c.MinBillingPts), c.MaxBillingPts)
		when b.PtsCalc > c.FirstPurchAmt and c.FirstPurchAmt > 0 and c.SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(c.FirstBillingPts + (((b.PtsCalc - c.FirstPurchAmt) / c.SubseqPurchAmt) * c.SubseqBillingPts), c.PtsRoundLen, c.PtsRoundFunc), c.MinBillingPts), c.MaxBillingPts)
		else 0 end
	from #SourceMiscTxnFeeDetailPlan as a
	join (select b1.SrcIds, b1.Seq, b1.PtsCalc - b2.PtsCalc 'PtsCalc'
		from #SourceMiscTxnFeeDetailPlan b1, #SourceMiscTxnFeeDetailPlan b2
		where b1.SrcIds = b2.SrcIds and b1.Seq = b2.Seq and b1.MiscTxnFeeType = @TxnMerchFeeType and b2.MiscTxnFeeType = @GSTFeeType
	) as b on a.SrcIds = b.SrcIds and a.Seq = b.Seq
	join #itx_BillingPlan as c on a.SrcIds = c.Ids and a.MiscTxnFeePlanId = c.PlanId

	-- Acquirer Points (Merchant) by Product Level Calculation 
	update a
	set a.AcqPtsCalc = b.PtsCalc - a.IssPtsCalc
	from #SourceMiscTxnFeeDetailPlan as a
	join (select b1.SrcIds, b1.Seq, b1.PtsCalc - b2.PtsCalc 'PtsCalc'
		from #SourceMiscTxnFeeDetailPlan b1, #SourceMiscTxnFeeDetailPlan b2
		where b1.SrcIds = b2.SrcIds and b1.Seq = b2.Seq and b1.MiscTxnFeeType = @TxnMerchFeeType and b2.MiscTxnFeeType = @GSTFeeType
	) as b on a.SrcIds = b.SrcIds and a.Seq = b.Seq

	-- MerchAgentFeeType by Product Level Calculation 
	update #SourceMiscTxnFeeDetailPlan
	set PtsCalc = case
		when FirstPurchAmt = 0 and SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round((AcqPtsCalc / SubseqPurchAmt) * SubseqBillingPts, PtsRoundLen, PtsRoundFunc), MinBillingPts), MaxBillingPts)
		when AcqPtsCalc > FirstPurchAmt and FirstPurchAmt > 0 and SubseqPurchAmt = 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(FirstBillingPts, PtsRoundLen, PtsRoundFunc), MinBillingPts), MaxBillingPts)
		when AcqPtsCalc > FirstPurchAmt and FirstPurchAmt > 0 and SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(FirstBillingPts + (((AcqPtsCalc - FirstPurchAmt) / SubseqPurchAmt) * SubseqBillingPts), PtsRoundLen, PtsRoundFunc), MinBillingPts), MaxBillingPts)
		else 0 end
	where MiscTxnFeeType = @MerchAgentFeeType

	-- CardAgentFeeType by Product Level Calculation 
	update #SourceMiscTxnFeeDetailPlan
	set PtsCalc = case
		when FirstPurchAmt = 0 and SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round((AcqPtsCalc / SubseqPurchAmt) * SubseqBillingPts, PtsRoundLen, PtsRoundFunc), MinBillingPts), MaxBillingPts)
		when AcqPtsCalc > FirstPurchAmt and FirstPurchAmt > 0 and SubseqPurchAmt = 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(FirstBillingPts, PtsRoundLen, PtsRoundFunc), MinBillingPts), MaxBillingPts)
		when AcqPtsCalc > FirstPurchAmt and FirstPurchAmt > 0 and SubseqPurchAmt > 0 then
			dbo.GetMoneyMin(dbo.GetMoneyMax(round(FirstBillingPts + (((AcqPtsCalc - FirstPurchAmt) / SubseqPurchAmt) * SubseqBillingPts), PtsRoundLen, PtsRoundFunc), MinBillingPts), MaxBillingPts)
		else 0 end
	where MiscTxnFeeType = @CardAgentFeeType
	
	/*update a
	set a.PtsCalc = case 
	when a.FirstPurchAmt = 0 and b.FirstPurchAmt = 0 then 
		(((a.Pts * b.SubseqPurchAmt) / b.SubseqBillingPts) * a.SubseqBillingPts) / a.SubseqPurchAmt
		--round(((((a.Pts * b.SubseqPurchAmt) / b.SubseqBillingPts) * a.SubseqBillingPts) / a.SubseqPurchAmt), a.PtsRoundLen, a.PtsRoundFunc)
	when a.FirstPurchAmt > 0 and b.FirstPurchAmt = 0  and ((a.Pts * b.SubseqPurchAmt) / b.SubseqBillingPts) >= a.FirstPurchAmt then 
		a.FirstBillingPts + (((((a.Pts * b.SubseqPurchAmt) / b.SubseqBillingPts) - a.FirstPurchAmt) * a.SubseqBillingPts) / a.SubseqPurchAmt)		
	when a.FirstPurchAmt = 0 and b.FirstPurchAmt > 0 and a.Pts >= b.FirstBillingPts then 
		((b.FirstPurchAmt + (((a.Pts - b.FirstBillingPts) * b.SubseqPurchAmt) / b.SubseqBillingPts)) * a.SubseqBillingPts) / a.SubseqPurchAmt
	when a.FirstPurchAmt > 0 and b.FirstPurchAmt > 0 and a.Pts >= b.FirstBillingPts and (b.FirstPurchAmt + (((a.Pts - b.FirstBillingPts) * b.SubseqPurchAmt) / b.SubseqBillingPts)) >= a.FirstPurchAmt then 
		a.FirstBillingPts + ((((b.FirstPurchAmt + (((a.Pts - b.FirstBillingPts) * b.SubseqPurchAmt) / b.SubseqBillingPts)) - a.FirstPurchAmt) * a.SubseqBillingPts) / a.SubseqPurchAmt)
	else 0 end
	from #SourceMiscTxnFeePlan as a
	join #itx_BillingPlan as b on a.TxnId = b.TxnId and a.MiscTxnFeePlanId = b.PlanId

	update a
	set a.PtsCalc = case 
	when a.FirstPurchAmt = 0 and b.FirstPurchAmt = 0 then 
		(((a.Pts * b.SubseqPurchAmt) / b.SubseqBillingPts) * a.SubseqBillingPts) / a.SubseqPurchAmt	
	when a.FirstPurchAmt > 0 and b.FirstPurchAmt = 0  and ((a.Pts * b.SubseqPurchAmt) / b.SubseqBillingPts) >= a.FirstPurchAmt then 
		a.FirstBillingPts + (((((a.Pts * b.SubseqPurchAmt) / b.SubseqBillingPts) - a.FirstPurchAmt) * a.SubseqBillingPts) / a.SubseqPurchAmt)		
	when a.FirstPurchAmt = 0 and b.FirstPurchAmt > 0 and a.Pts >= b.FirstBillingPts then 
		((b.FirstPurchAmt + (((a.Pts - b.FirstBillingPts) * b.SubseqPurchAmt) / b.SubseqBillingPts)) * a.SubseqBillingPts) / a.SubseqPurchAmt
	when a.FirstPurchAmt > 0 and b.FirstPurchAmt > 0 and a.Pts >= b.FirstBillingPts and (b.FirstPurchAmt + (((a.Pts - b.FirstBillingPts) * b.SubseqPurchAmt) / b.SubseqBillingPts)) >= a.FirstPurchAmt then 
		a.FirstBillingPts + ((((b.FirstPurchAmt + (((a.Pts - b.FirstBillingPts) * b.SubseqPurchAmt) / b.SubseqBillingPts)) - a.FirstPurchAmt) * a.SubseqBillingPts) / a.SubseqPurchAmt)
	else 0 end
	from #SourceMiscTxnFeeDetailPlan as a
	join #itx_BillingPlan as b on a.TxnId = b.TxnId and a.MiscTxnFeePlanId = b.PlanId*/

	-----------------------------------------
	-- update fees amount by product level --
	-----------------------------------------

	update a
	set a.PtsCalc = b.PtsCalc, a.AcqPtsCalc = b.AcqPtsCalc, a.IssPtsCalc = b.IssPtsCalc
	from #SourceMiscTxnFeePlan as a
	join (select SrcIds, MiscTxnFeeType, sum(PtsCalc) 'PtsCalc', avg(AcqPtsCalc) 'AcqPtsCalc', avg(IssPtsCalc) 'IssPtsCalc'
		from #SourceMiscTxnFeeDetailPlan 
		where BillMethod = 'P'
		group by SrcIds, MiscTxnFeeType
	) as b on a.Ids = b.SrcIds and a.MiscTxnFeeType = b.MiscTxnFeeType

	---------------------------------------------
	-- update fees amount by transaction level --
	---------------------------------------------
	
	update #SourceMiscTxnFeeDetailPlan
	set PtsCalc = 0, AcqPtsCalc = 0, IssPtsCalc = 0
	where BillMethod = 'T'

	--------------------------------------------------------------
	-- insert into itx_MiscTxnFee & itx_MiscTxnFeeDetail tables --
	--------------------------------------------------------------

	-----------------	
	BEGIN TRANSACTION
	-----------------

	insert into atx_MiscTxnFee
		(Ids, Amt, AcqTxnFee, 
		 TxnMerchFeePlanId, TxnMerchFeeType, TxnMerchMinPurchAmt, TxnMerchFee,
		 GSTFeeTxnFeePlanId, GSTFeeTxnFeeType, GSTMinPurchAmt, GSTFee,
		 MerchAgentTxnFeePlanId, MerchAgentTxnFeeType, MerchAgentMinPurchAmt, MerchAgentFee,
		 CardAgentTxnFeePlanId, CardAgentTxnFeeType, CardAgentMinPurchAmt, CardAgentFee, LastUpdDate)
	select a.Ids, a.Amt, a.AcqPtsCalc,
		a.MiscTxnFeePlanId, a.MiscTxnFeeType, a.MinPurchAmt, a.PtsCalc,
		b.MiscTxnFeePlanId, b.MiscTxnFeeType, b.MinPurchAmt, b.PtsCalc,
		c.MiscTxnFeePlanId, c.MiscTxnFeeType, c.MinPurchAmt, c.PtsCalc,
		d.MiscTxnFeePlanId, d.MiscTxnFeeType, d.MinPurchAmt, d.PtsCalc, getdate()
	from #SourceMiscTxnFeePlan as a
	join #SourceMiscTxnFeePlan as b on a.Ids = b.Ids and b.MiscTxnFeeType = @GSTFeeType
	join #SourceMiscTxnFeePlan as c on a.Ids = c.Ids and c.MiscTxnFeeType = @MerchAgentFeeType
	join #SourceMiscTxnFeePlan as d on a.Ids = d.Ids and d.MiscTxnFeeType = @CardAgentFeeType
	where a.MiscTxnFeeType = @TxnMerchFeeType
		
	if @@error <> 0
	begin
		rollback transaction
		return 99999
	end

	insert into atx_MiscTxnFeeDetail
		(SrcIds, Seq, ProdCd, AmtPts, AcqTxnFee, 
		 TxnMerchFeePlanId, TxnMerchFeeType, TxnMerchMinPurchAmt, TxnMerchFee,
		 GSTFeeTxnFeePlanId, GSTFeeTxnFeeType, GSTMinPurchAmt, GSTFee,
		 MerchAgentTxnFeePlanId, MerchAgentTxnFeeType, MerchAgentMinPurchAmt, MerchAgentFee,
		 CardAgentTxnFeePlanId, CardAgentTxnFeeType, CardAgentMinPurchAmt, CardAgentFee, LastUpdDate)
	select a.SrcIds, a.Seq, a.ProdCd, a.AmtPts, a.AcqPtsCalc,
		a.MiscTxnFeePlanId, a.MiscTxnFeeType, a.MinPurchAmt, a.PtsCalc,
		b.MiscTxnFeePlanId, b.MiscTxnFeeType, b.MinPurchAmt, b.PtsCalc,
		c.MiscTxnFeePlanId, c.MiscTxnFeeType, c.MinPurchAmt, c.PtsCalc,
		d.MiscTxnFeePlanId, d.MiscTxnFeeType, d.MinPurchAmt, d.PtsCalc, getdate()
	from #SourceMiscTxnFeeDetailPlan as a
	join #SourceMiscTxnFeeDetailPlan as b on a.SrcIds = b.SrcIds and a.Seq = b.Seq and b.MiscTxnFeeType = @GSTFeeType
	join #SourceMiscTxnFeeDetailPlan as c on a.SrcIds = c.SrcIds and a.Seq = c.Seq and c.MiscTxnFeeType = @MerchAgentFeeType
	join #SourceMiscTxnFeeDetailPlan as d on a.SrcIds = d.SrcIds and a.Seq = d.Seq and d.MiscTxnFeeType = @CardAgentFeeType
	where a.MiscTxnFeeType = @TxnMerchFeeType

	if @@error <> 0
	begin
		rollback transaction
		return 99999
	end

	------------------
	COMMIT TRANSACTION
	------------------

end
GO
