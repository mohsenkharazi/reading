USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MiscTxnFeeBilling]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure will calculates the actual bonus points should be
		  bill to the cardholder's account

Required files  : #SourceTxn (Temporary table holds the transaction)
		  #SourceTxnDetail (Temporary table holds the transaction detail)

Leveling	: Second Level

------------------------------------------------------------------------------------------------------------------
When	   Who		CRN		Desc
------------------------------------------------------------------------------------------------------------------
2007/04/17 Darren			Initial development
******************************************************************************************************************/

CREATE procedure [dbo].[MiscTxnFeeBilling]
	@IssNo uIssNo,
	@AmtInd tinyint = 3,
	@PtsInd tinyint = 2
  as
begin
	declare	@PrcsName varchar(50),
			@ProdRebateTxnCategory  int,
			@rc int,
			@VATRate money,
			@TxnMerchFeeType nvarchar(50), 
			@GSTFeeType nvarchar(50)

	select @PrcsName = 'MiscTxnFeeBilling'

	exec TraceProcess @IssNo, @PrcsName, 'Start'

	---------------------------------------------
	-- Retrieve default value from iss_Default --
	---------------------------------------------

	select @TxnMerchFeeType = RefCd
	from iss_RefLib
	where IssNo = @IssNo and RefType = 'MiscTxnFeeType' and (RefNo & 1) > 0

	select @GSTFeeType = RefCd
	from iss_RefLib
	where IssNo = @IssNo and RefType = 'MiscTxnFeeType' and (RefNo & 2) > 0

	-- Make sure the Original Transaction Amount is a positive value
	update #SourceTxn
	set SettleTxnAmt = abs(SettleTxnAmt)

	if @@error <> 0 return 70268	-- Failed to update #SourceTxn

	-- Populate required fields into the holding table
	update a set AcctNo = b.AcctNo
	from #SourceTxn a, iac_Card b
	where a.CardNo is not null and a.CardNo = b.CardNo

	if @@error <> 0 return 70268	-- Failed to update #SourceTxn
	
	-- Standard Merchant Promotion by Transaction
	update a set PlanId = b.PlanId, BillMethod = 'M'
	from #SourceTxn a, ipr_StandardPromotion b, aac_BusnLocation c
	where c.BusnLocation = a.BusnLocation and b.IssNo = @IssNo and b.PromoType = 'M'
	and b.TxnCd = a.TxnCd and b.BusnLocation = cast(c.AcctNo as varchar(15))
	and a.BillMethod is null and b.BillMethod = 'T'
	and a.TxnDate between b.EffDateFrom and b.EffDateTo

	if @@error <> 0 return 70268	-- Failed to update #SourceTxn

	-- Standard Merchant Promotion by Product
	update a set PlanId = 0, BillMethod = 'D'
	from #SourceTxn a
	where a.BillMethod is null
	and exists (select 1 from ipr_StandardPromotion b, aac_BusnLocation c
			where c.BusnLocation = a.BusnLocation and b.IssNo = @IssNo
			and b.PromoType = 'M' and b.TxnCd = a.TxnCd
			and b.BusnLocation = cast(c.AcctNo as varchar(15)) and b.BillMethod = 'P'
			and a.TxnDate between b.EffDateFrom and b.EffDateTo)

	if @@error <> 0 return 70268	-- Failed to update #SourceTxn

	-- Standard Merchant Promotion by Product for each detail transaction
	update a set PlanId = c.PlanId
	from #SourceTxnDetail a, #SourceTxn b, ipr_StandardPromotionProduct c, aac_BusnLocation d
	where b.BillMethod = 'D' and a.RefTo = 'P' and a.ParentSeq = b.TxnSeq and a.PlanId is null
	and d.BusnLocation = b.BusnLocation and c.IssNo = @IssNo and c.PromoType = 'M'
	and c.TxnCd = b.TxnCd and c.BusnLocation = cast(d.AcctNo as varchar(15))
	and c.ProdCd = a.RefKey

	if @@error <> 0 return 70269	-- Failed to update #SourceTxnDetail

	-------------------------------------
	-- Standard BusnLocation Promotion --
	-------------------------------------

	exec TraceProcess @IssNo, @PrcsName, 'Standard BusnLocation Promotion'

	-- Standard BusnLocation Promotion by Transaction
	update a set PlanId = b.PlanId, BillMethod = 'M'
	from #SourceTxn a, ipr_StandardPromotion b
	where b.IssNo = @IssNo and b.PromoType = 'B' and b.TxnCd = a.TxnCd and
	b.BusnLocation = a.BusnLocation and a.BillMethod is null and b.BillMethod = 'T'
	and a.TxnDate between b.EffDateFrom and b.EffDateTo


	if @@error <> 0 return 70268	-- Failed to update #SourceTxn

	-- Standard BusnLocation Promotion by Product
	update a set PlanId = 0, BillMethod = 'D'
	from #SourceTxn a
	where a.BillMethod is null
	and exists (select 1 from ipr_StandardPromotion b
			where b.IssNo = @IssNo and b.PromoType = 'B' and b.TxnCd = a.TxnCd
			and b.BusnLocation = a.BusnLocation and b.BillMethod = 'P' and
			a.TxnDate between b.EffDateFrom and b.EffDateTo)

	if @@error <> 0 return 70268	-- Failed to update #SourceTxn

	-- Standard BusnLocation Promotion by Product for each detail transaction
	update a set PlanId = c.PlanId
	from #SourceTxnDetail a, #SourceTxn b, ipr_StandardPromotionProduct c
	where b.BillMethod = 'D' and a.RefTo = 'P' and a.ParentSeq = b.TxnSeq and a.PlanId is null
	and c.IssNo = @IssNo and c.PromoType = 'B' and c.TxnCd = b.TxnCd
	and c.BusnLocation = b.BusnLocation
	and c.ProdCd = a.RefKey

	if @@error <> 0 return 70269	-- Failed to update #SourceTxnDetail


	-------------------
	-- Standard Plan --
	-------------------

	exec TraceProcess @IssNo, @PrcsName, 'Plan Selection'

	-- Billing Plan by Transaction
	update a set PlanId = b.PlanId, BillMethod = 'T'
	from #SourceTxn a, itx_TxnCode b
	where b.IssNo = @IssNo and b.TxnCd = a.TxnCd
	and a.BillMethod is null and b.BillMethod = 'T'

	if @@error <> 0 return 70268	-- Failed to update #SourceTxn

	-- Billing Plan by Product
	update a set PlanId = b.PlanId, BillMethod = 'P'
	from #SourceTxn a, itx_TxnCode b
	where b.IssNo = @IssNo and b.TxnCd = a.TxnCd
	and (a.BillMethod is null or a.BillMethod = 'D') and b.BillMethod = 'P'

	if @@error <> 0 return 70268	-- Failed to update #SourceTxn

	-- Billing Plan by Product for each detail transaction other than Product Rebate transaction
	update a set PlanId = c.PlanId	
	from #SourceTxnDetail a, #SourceTxn b, iss_Product c, itx_TxnCode d
	where b.BillMethod = 'P' and a.RefTo = 'P' and a.ParentSeq = b.TxnSeq and a.PlanId is null
	and c.IssNo = @IssNo and c.ProdCd = a.RefKey
	and d.IssNo = @IssNo and d.TxnCd = b.TxnCd and d.Category <> @ProdRebateTxnCategory

	-- Billing Plan by Product for each detail transaction for Product Rebate transaction
	update a set PlanId = d.PlanId
	from #SourceTxnDetail a
	join #SourceTxn b on
		b.BillMethod = 'P' and b.TxnSeq = a.ParentSeq
	join iac_Account c on
		c.AcctNo = b.AcctNo
	join iss_ProductRebate d on
		d.IssNo = @IssNo and d.PlasticType = c.PlasticType and d.ProdCd = a.RefKey
	join itx_TxnCode e on
		e.IssNo = @IssNo and e.TxnCd = b.TxnCd and e.Category = @ProdRebateTxnCategory
	where a.RefTo = 'P' and a.PlanId is null
	-- 2003/07/04 Jacky [E]

	if @@error <> 0 return 70269	-- Failed to update #SourceTxnDetail

	
	----------------------------------------------------------------
	-- Calculate Merchant Transaction Fee
	----------------------------------------------------------------

	update a set Pts = round(
		case
		when a.SettleTxnAmt < c.FirstPurchAmt then
			dbo.GetMoneyMin(dbo.GetMoneyMax(c.MinBillingPts,
			case
			when c.ProportionBillingPts = 0 then
				0
			else
				round((a.SettleTxnAmt/c.FirstPurchAmt*c.FirstBillingPts),
				c.ProportionBillingPts, 1)
			end ), c.MaxBillingPts)
		else dbo.GetMoneyMin(dbo.GetMoneyMax((c.FirstBillingPts +
			case
			when c.ProportionBillingPts = 0 then
				round(((a.SettleTxnAmt-c.FirstPurchAmt)/c.SubseqPurchAmt), 0, 1)*
				c.SubseqBillingPts
			else
				round(((a.SettleTxnAmt-c.FirstPurchAmt)/c.SubseqPurchAmt*
				c.SubseqBillingPts), c.ProportionBillingPts, 0)
			end )
			,c.MinBillingPts), c.MaxBillingPts)
		end, c.PtsRoundLen, c.PtsRoundFunc)
	from #SourceTxn a, itx_TxnCode b, cmn_MiscTxnFeePlan c
	where b.IssNo = @IssNo and b.TxnCd = a.TxnCd and b.PtsInd = @PtsInd
	and c.MiscTxnFeePlanId = a.PlanId and c.MiscTxnFeeType = @TxnMerchFeeType
	and c.MinPurchAmt = (	select min(d.MinPurchAmt)
				from itx_BillingPlan d
				where d.IssNo = @IssNo and d.PlanId = a.PlanId
				and ((d.EffDateFrom is null and d.EffDateTo is null)
				or (d.EffDateTo is null and d.EffDateFrom is not null and a.TxnDate >= d.EffDateFrom)
				or (d.EffDateFrom is null and d.EffDateTo is not null and a.TxnDate <= d.EffDateTo)
				or (a.TxnDate between d.EffDateFrom and d.EffDateTo))
				and d.MinPurchAmt >= a.SettleTxnAmt)

	if @@error <> 0 return 70268	-- Failed to update #SourceTxn

	----------------------------------------------------------------
	-- Calculate and Deduct GST
	----------------------------------------------------------------

	update a set Pts = Pts - round(
		case
		when a.Pts < c.FirstPurchAmt then
			dbo.GetMoneyMin(dbo.GetMoneyMax(c.MinBillingPts,
			case
			when c.ProportionBillingPts = 0 then
				0
			else
				round((a.Pts/c.FirstPurchAmt*c.FirstBillingPts),
				c.ProportionBillingPts, 1)
			end ), c.MaxBillingPts)
		else dbo.GetMoneyMin(dbo.GetMoneyMax((c.FirstBillingPts +
			case
			when c.ProportionBillingPts = 0 then
				round(((a.Pts-c.FirstPurchAmt)/c.SubseqPurchAmt), 0, 1)*
				c.SubseqBillingPts
			else
				round(((a.Pts-c.FirstPurchAmt)/c.SubseqPurchAmt*
				c.SubseqBillingPts), c.ProportionBillingPts, 0)
			end )
			,c.MinBillingPts), c.MaxBillingPts)
		end, c.PtsRoundLen, c.PtsRoundFunc)
	from #SourceTxn a, itx_TxnCode b, cmn_MiscTxnFeePlan c
	where b.IssNo = @IssNo and b.TxnCd = a.TxnCd and b.PtsInd = @PtsInd
	and c.MiscTxnFeePlanId = a.PlanId and c.MiscTxnFeeType = @GSTFeeType
	and c.MinPurchAmt = (	select min(d.MinPurchAmt)
				from itx_BillingPlan d
				where d.IssNo = @IssNo and d.PlanId = a.PlanId
				and ((d.EffDateFrom is null and d.EffDateTo is null)
				or (d.EffDateTo is null and d.EffDateFrom is not null and a.TxnDate >= d.EffDateFrom)
				or (d.EffDateFrom is null and d.EffDateTo is not null and a.TxnDate <= d.EffDateTo)
				or (a.TxnDate between d.EffDateFrom and d.EffDateTo))
				and d.MinPurchAmt >= a.SettleTxnAmt)	

	if @@error <> 0 return 70268	-- Failed to update #SourceTxn

	
	----------------------------------------------------------------
	-- Calculate the actual card holder points
	----------------------------------------------------------------

	update a set Pts = round(
		case
		when a.Pts < c.FirstPurchAmt then
			dbo.GetMoneyMin(dbo.GetMoneyMax(c.MinBillingPts,
			case
			when c.ProportionBillingPts = 0 then
				0
			else
				round((a.Pts/c.FirstPurchAmt*c.FirstBillingPts),
				c.ProportionBillingPts, 1)
			end ), c.MaxBillingPts)
		else dbo.GetMoneyMin(dbo.GetMoneyMax((c.FirstBillingPts +
			case
			when c.ProportionBillingPts = 0 then
				round(((a.Pts-c.FirstPurchAmt)/c.SubseqPurchAmt), 0, 1)*
				c.SubseqBillingPts
			else
				round(((a.Pts-c.FirstPurchAmt)/c.SubseqPurchAmt*
				c.SubseqBillingPts), c.ProportionBillingPts, 0)
			end )
			,c.MinBillingPts), c.MaxBillingPts)
		end, c.PtsRoundLen, c.PtsRoundFunc)
	from #SourceTxn a, itx_TxnCode b, itx_BillingPlan c
	where b.IssNo = @IssNo and b.TxnCd = a.TxnCd and b.PtsInd = @PtsInd
	and c.IssNo = @IssNo and c.PlanId = a.PlanId
	and c.MinPurchAmt = (	select min(d.MinPurchAmt)
				from itx_BillingPlan d
				where d.IssNo = @IssNo and d.PlanId = a.PlanId
				and ((d.EffDateFrom is null and d.EffDateTo is null)
				or (d.EffDateTo is null and d.EffDateFrom is not null and a.TxnDate >= d.EffDateFrom)
				or (d.EffDateFrom is null and d.EffDateTo is not null and a.TxnDate <= d.EffDateTo)
				or (a.TxnDate between d.EffDateFrom and d.EffDateTo))
				and d.MinPurchAmt >= a.SettleTxnAmt)
	
	if @@error <> 0 return 70268	-- Failed to update #SourceTxn

	exec TraceProcess @IssNo, @PrcsName, 'End'

	return 0
end
GO
