USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchTxnBilling]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Acquiring Module

Objective	: This stored procedure will calculates the actual transaction amount should be
		  bill to the Merchant's account

Required files  : #SourceTxn (Temporary table holds the transaction)
		  #SourceTxnDetail (Temporary table holds the transaction detail)

Leveling	: Second Level

------------------------------------------------------------------------------------------------------------------
When	   Who		CRN		Desc
------------------------------------------------------------------------------------------------------------------
2001/10/23 Jacky			Initial development
2002/10/24 Jacky			If AmtInd = 3(Without any calculation) then the BillingTxnAmt
							should be from the source input file.
2002/11/   Jacky			Reconciliation
2003/03/10 Sam				Fixes.
2003/07/14 Sam				To calc subsidized amt.
2005/04/20 Chew Pei			Change cmn_Reflib to iss_Reflib
******************************************************************************************************************/

CREATE procedure [dbo].[MerchTxnBilling] 
	@AcqNo uAcqNo
--with encryption 
as
begin
	declare @PrcsName varchar(50),
			@rc int

	set nocount on

	select @PrcsName = 'MerchTxnBilling'
	exec TraceProcess @AcqNo, @PrcsName, 'Start'

	exec @rc = InitProcess
	if @@error <> 0 or @rc <> 0 return 99999

	-- Make sure the Original Transaction Amount is a positive value
	update #SourceTxn
	set SettleTxnAmt = abs(SettleTxnAmt)

	if @@error <> 0 return 70268 --Failed to update #SourceTxn

	-- Populate required fields into the holding table
	update a set AcctNo = b.AcctNo
	from #SourceTxn a, aac_BusnLocation b (nolock)
	where a.BusnLocation is not null and a.BusnLocation = b.BusnLocation

	if @@error <> 0 return 70268 --Failed to update #SourceTxn

	-- Billing Plan by Transaction
	update a set PlanId = b.PlanId, BillMethod = 'T'
	from #SourceTxn a, atx_TxnCode b (nolock)
	where b.AcqNo = @AcqNo and b.TxnCd = a.TxnCd
	and a.BillMethod is null and b.BillMethod = 'T'

	if @@error <> 0 return 70268 --Failed to update #SourceTxn

	-- Billing Plan by Product
	update a set BillingTxnAmt = SettleTxnAmt, PlanId = b.PlanId, BillMethod = 'P'
	from #SourceTxn a, atx_TxnCode b (nolock)
	where b.AcqNo = @AcqNo and b.TxnCd = a.TxnCd
	and a.BillMethod is null and b.BillMethod = 'P'

	if @@error <> 0 return 70268 --Failed to update #SourceTxn

	-- Billing Plan by Product for each detail transaction
	-- Set Plan to parents Plan
	update a set PlanId = b.PlanId
	from #SourceTxnDetail a, #SourceTxn b
	where b.BillMethod = 'P' and a.ParentSeq = b.TxnSeq

	if @@error <> 0 return 70269 --Failed to update #SourceTxnDetail

	update a set PlanId = c.PlanId
	from #SourceTxnDetail a, #SourceTxn b, acq_ServiceFeeByProduct c, iss_RefLib d (nolock) -- CP 20050420
	where b.BillMethod = 'P' and a.ParentSeq = b.TxnSeq
	and c.Location = b.BusnLocation and c.ProdCd = a.RefKey and d.RefType = 'ProdSts'
	and d.RefCd = c.Sts and d.RefInd = 0

	if @@error <> 0 return 70269 --Failed to update #SourceTxnDetail

	-- Derive Transaction Amount for Billing Plan by Transaction
	update a set BillingTxnAmt = round(
		case
		when a.SettleTxnAmt < c.FirstPurchAmt then
			dbo.GetMoneyMin(dbo.GetMoneyMax(c.MinBillingAmt,
			case
			when c.ProportionBillingAmt = 0 then
				0
			else
				round((a.SettleTxnAmt / c.FirstPurchAmt * c.FirstBillingAmt),
				c.ProportionBillingAmt, 0)
			end ), c.MaxBillingAmt)
		else dbo.GetMoneyMin(dbo.GetMoneyMax((c.FirstBillingAmt +
			case
			when c.ProportionBillingAmt = 0 then
				round(((a.SettleTxnAmt - c.FirstPurchAmt) / c.SubseqPurchAmt), 0, 1) *
				c.SubseqBillingAmt
			else
				round(((a.SettleTxnAmt - c.FirstPurchAmt) / c.SubseqPurchAmt * 
				c.SubseqBillingAmt), c.ProportionBillingAmt, 0)
			end )
			,c.MinBillingAmt), c.MaxBillingAmt)
		end, c.AmtRoundLen, c.AmtRoundFunc)
	from #SourceTxn a, atx_BillingPlan c (nolock)
	where a.BillMethod in ('M', 'T')
	and c.AcqNo = @AcqNo and c.PlanId = a.PlanId
	and c.MinPurchAmt = ( select min(d.MinPurchAmt)
				from atx_BillingPlan d (nolock)
				where d.AcqNo = @AcqNo and d.PlanId = a.PlanId
				and ((d.EffDateFrom is null and d.EffDateTo is null)
				or (d.EffDateTo is null and d.EffDateFrom is not null and a.TxnDate >= d.EffDateFrom)
				or (d.EffDateFrom is null and d.EffDateTo is not null and a.TxnDate <= d.EffDateTo)
				or (a.TxnDate between d.EffDateFrom and d.EffDateTo))
				and d.MinPurchAmt >= a.SettleTxnAmt )

	if @@error <> 0 return 70268 -- Failed to update #SourceTxn

	-- Derive Transaction Amount for Billing Plan by Product
	update a set BillingTxnAmt = round(
		case
		when a.SettleTxnAmt < d.FirstPurchAmt then
			dbo.GetMoneyMin(dbo.GetMoneyMax(d.MinBillingAmt,
			case
			when d.ProportionBillingAmt = 0 then
				0
			else
				round((a.SettleTxnAmt / d.FirstPurchAmt * d.FirstBillingAmt),
				d.ProportionBillingAmt, 0)
			end ), d.MaxBillingAmt)
		else dbo.GetMoneyMin(dbo.GetMoneyMax((d.FirstBillingAmt +
			case
			when d.ProportionBillingAmt = 0 then
				round(((a.SettleTxnAmt - d.FirstPurchAmt) / d.SubseqPurchAmt), 0, 1) *
				d.SubseqBillingAmt
			else
				round(((a.SettleTxnAmt - d.FirstPurchAmt) / d.SubseqPurchAmt *
				d.SubseqBillingAmt), d.ProportionBillingAmt, 0)
			end )
			,d.MinBillingAmt), d.MaxBillingAmt)
		end, d.AmtRoundLen, d.AmtRoundFunc)
	from #SourceTxnDetail a, #SourceTxn b, atx_BillingPlan d (nolock)
	where a.ParentSeq = b.TxnSeq
	and b.BillMethod in ('D', 'P')
	and d.AcqNo = @AcqNo and d.PlanId = a.PlanId
	and d.MinPurchAmt = (	select min(e.MinPurchAmt)
				from atx_BillingPlan e (nolock)
				where e.AcqNo = @AcqNo and e.PlanId = a.PlanId
				and ((e.EffDateFrom is null and e.EffDateTo is null)
				or (e.EffDateTo is null and e.EffDateFrom is not null and b.TxnDate >= e.EffDateFrom)
				or (e.EffDateFrom is null and e.EffDateTo is not null and b.TxnDate <= e.EffDateTo)
				or (b.TxnDate between e.EffDateFrom and e.EffDateTo))
				and e.MinPurchAmt >= a.SettleTxnAmt)
	if @@error <> 0 return 70269	-- Failed to update #SourceTxnDetail

	-- Update Transaction Amount and Bonus Points
	update a set BillingTxnAmt = d.BillingTxnAmt, Pts = d.Pts, PromoPts = d.PromoPts
	from #SourceTxn a
	join	(select c.ParentSeq 'TxnSeq', sum(c.BillingTxnAmt) 'BillingTxnAmt', sum(c.Pts) 'Pts',
			sum(c.PromoPts) 'PromoPts'
		from #SourceTxn b, #SourceTxnDetail c
		where b.BillMethod in ('D', 'P') and c.ParentSeq = b.TxnSeq
		group by c.ParentSeq) as d
	on a.BillMethod in ('D', 'P') and d.TxnSeq = a.TxnSeq

	if @@error <> 0 return 70268	-- Failed to update #SourceTxn

	-- Debit or Credit transaction
	--2003/03/10B
	--update a set BillingTxnAmt = BillingTxnAmt * b.Multiplier, Pts = Pts * b.Multiplier
	update a set BillingTxnAmt = BillingTxnAmt * isnull(c.RefNo,1), Pts = Pts * isnull(c.RefNo,1), SettleTxnAmt = SettleTxnAmt * isnull(c.RefNo,1)
	--2003/03/10E
	from #SourceTxn a, atx_TxnCode b (nolock), iss_RefLib c (nolock)
	where b.AcqNo = @AcqNo and b.TxnCd = a.TxnCd and b.Multiplier = c.RefCd and c.RefType = 'TxnType' and b.AcqNo = c.IssNo

	if @@error <> 0 return 70268	-- Failed to update #SourceTxn

	update a 
	set a.SettleTxnAmt = a.SettleTxnAmt * isnull(d.RefNo,1),
		a.BillingTxnAmt = a.BillingTxnAmt * isnull(d.RefNo,1)
	from #SourceTxnDetail a, #SourceTxn b, atx_TxnCode c (nolock), iss_RefLib d (nolock)
	where a.ParentSeq = b.TxnSeq and b.IssNo = c.AcqNo and b.TxnCd = c.TxnCd and c.Multiplier = d.RefCd and d.RefType = 'TxnType' and c.AcqNo = d.IssNo

	if @@error <> 0 return 70268	-- Failed to update #SourceTxn

	exec TraceProcess @AcqNo, @PrcsName, 'End'
	return 0
end
GO
