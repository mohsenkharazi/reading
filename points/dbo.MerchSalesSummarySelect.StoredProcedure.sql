USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchSalesSummarySelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Merchant sales summary info.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/08/24 Sam			   Initial development
2009/12/18 Barnett			Add Nolock
*******************************************************************************/

CREATE	procedure [dbo].[MerchSalesSummarySelect]
	@AcqNo uAcqNo,
	@Ind char(1),
	@AcctNo uMerch,
	@BusnLocation uMerch,
	@vSettleDay nvarchar(20),
	@SettleYear int,
	@SettleMth int,
	@SubsidizedPlanId varchar(10) output,
	@PlanId varchar(10) output,
	@VATRate varchar(10) output,
	@WithholdingTaxRate varchar(10) output,
	@SubsidizedAmt varchar(13) output,
	@MDRAmt varchar(13) output, 
	@VATAmt varchar(13) output, 
	@WithholdingTaxAmt varchar(13) output,
	@SettleAmt varchar(13) output, 
	@BillingAmt varchar(13) output, 
	@Cnt varchar(10) output
  as
begin
	declare @SysDate datetime, @PrcsDate datetime, @Year int, @Mth int, @StartPrcsId int, @EndPrcsId int,
			@YearMth varchar(6), @SettleDay datetime, @PrcsId uPrcsId

	set nocount on

	select @SettleDay = cast(@vSettleDay as datetime)
	select @SysDate = getdate()
	select @Year = datepart(yy, @SysDate)
	select @Mth = datepart(mm, @SysDate)

	select @PrcsDate = CtrlDate
	from iss_Control where IssNo = @AcqNo and CtrlId = 'PrcsId'

	if @Ind = 'M'
	begin
		if isnull(@SettleYear, 0) > @Year or len(convert(varchar(10), isnull(@SettleYear, 0))) <> 4
			return 95127	--Invalid Settle Date

		if isnull(@SettleMth, 0) < 0 or isnull(@SettleMth, 0) > 12
			return 95127	--Invalid Settle Date

		select @YearMth = convert(varchar(4), @SettleYear) + replicate('0', 2 - len(convert(varchar(2), @SettleMth))) + convert(varchar(2), @SettleMth)
		if isnull(@YearMth, 0) > convert(varchar(6), @PrcsDate, 112)
			return 95127	--Invalid Settle Date
	end
	else
	begin
		if @SettleDay > @SysDate or @SettleDay > @PrcsDate return 95127	--Invalid Settle Date

		if @SettleDay <> @PrcsDate
		begin
			select @PrcsId = PrcsId
			from cmnv_ProcessLog 
			where PrcsDate = @SettleDay
			if not exists (select 1 from cmnv_ProcessLog where IssNo = @AcqNo and convert(varchar(8),PrcsDate,112) = convert(varchar(8),@SettleDay,112))
				return 95127	--Invalid Settle Date
		end
	end

	create table #MerchSummary
	(
		SubsidizedPlanId money null,
		PlanId money null,
		VATRate money null,
		WithholdingTaxRate money null,
		SubsidizedAmt money null,
		MDRAmt money null,
		VATAmt money null,
		WithholdingTaxAmt money null,
		SettleAmt money null,
		BillingAmt money null,
		Cnt int null
	)

	if isnull(@BusnLocation, '') <> ''
	begin
		if @Ind = 'M'
		begin
			insert #MerchSummary
			( SubsidizedPlanId, PlanId, VATRate, WithholdingTaxRate, SubsidizedAmt, MDRAmt, VATAmt, WithholdingTaxAmt, SettleAmt, BillingAmt, Cnt )
--			select avg((1 - isnull(d.SubseqBillingAmt, 0) / isnull(d.SubseqPurchAmt, 1)) * 100),
--				avg((1 - isnull(c.SubseqBillingAmt, 0) / isnull(c.SubseqPurchAmt, 1)) * 100),
			select avg((1 - isnull(d.SubseqBillingAmt, 0)) * 100),
				avg((1 - isnull(c.SubseqBillingAmt, 0)) * 100),
				avg(VATRate),
				avg(WithholdingTaxRate),
				sum(SubsidizedAmt),
				sum(MDRAmt),
				sum(VATAmt), 
				sum(WithholdingTaxAmt),
				sum(SettleAmt), 
				sum(BillingAmt), 
				sum(Cnt)
			from acq_MerchTaxInvoice a (nolock)
			join atx_TxnCode b (nolock) on a.TxnCd = b.TxnCd
			join atx_BillingPlan c (nolock) on b.PlanId = c.PlanId
			left outer join atx_BillingPlan d (nolock) on b.SubsidizedPlanId = d.PlanId
			where BusnLocation = @BusnLocation and month(PrcsDate) = @SettleMth and year(PrcsDate) = @SettleYear

			if @@error <> 0 return 95127	--Invalid Settle Date
		end
		else
		begin
			insert #MerchSummary
			( SubsidizedPlanId, PlanId, VATRate, WithholdingTaxRate, SubsidizedAmt, MDRAmt, VATAmt, WithholdingTaxAmt, SettleAmt, BillingAmt, Cnt )
			select avg((1 - isnull(d.SubseqBillingAmt, 0)) * 100),
				avg((1 - isnull(c.SubseqBillingAmt, 0)) * 100),
				avg(VATRate),
				avg(WithholdingTaxRate),
				sum(SubsidizedAmt),
				sum(MDRAmt),
				sum(VATAmt), 
				sum(WithholdingTaxAmt),
				sum(SettleAmt), 
				sum(BillingAmt), 
				sum(Cnt)
			from acq_MerchTaxInvoice a (nolock)
			join atx_TxnCode b (nolock) on a.TxnCd = b.TxnCd
			join atx_BillingPlan c (nolock) on b.PlanId = c.PlanId
			left outer join atx_BillingPlan d (nolock) on b.SubsidizedPlanId = d.PlanId
			where BusnLocation = @BusnLocation and PrcsId = @PrcsId

			if @@error <> 0 return 95127	--Invalid Settle Date
		end
	end
	else
	begin
		if @Ind = 'M'
		begin
			insert #MerchSummary
			( SubsidizedPlanId, PlanId, VATRate, WithholdingTaxRate, SubsidizedAmt, MDRAmt, VATAmt, WithholdingTaxAmt, SettleAmt, BillingAmt, Cnt )
			select avg((1 - isnull(d.SubseqBillingAmt, 0)) * 100),
				avg((1 - isnull(c.SubseqBillingAmt, 0)) * 100),
				avg(VATRate),
				avg(WithholdingTaxRate),
				sum(SubsidizedAmt),
				sum(MDRAmt),
				sum(VATAmt), 
				sum(WithholdingTaxAmt),
				sum(SettleAmt), 
				sum(BillingAmt), 
				sum(Cnt)
			from acq_MerchTaxInvoice a (nolock)
			join atx_TxnCode b (nolock) on a.TxnCd = b.TxnCd
			join atx_BillingPlan c (nolock) on b.PlanId = c.PlanId
			left outer join atx_BillingPlan d (nolock) on b.SubsidizedPlanId = d.PlanId
			join aac_BusnLocation e (nolock) on a.BusnLocation = e.BusnLocation and e.AcctNo = @AcctNo
			where month(PrcsDate) = @SettleMth and year(PrcsDate) = @SettleYear

			if @@error <> 0 return 95127	--Invalid Settle Date
		end
		else
		begin
			insert #MerchSummary
			( SubsidizedPlanId, PlanId, VATRate, WithholdingTaxRate, SubsidizedAmt, MDRAmt, VATAmt, WithholdingTaxAmt, SettleAmt, BillingAmt, Cnt )
			select avg((1 - isnull(d.SubseqBillingAmt, 0)) * 100),
				avg((1 - isnull(c.SubseqBillingAmt, 0)) * 100),
				avg(VATRate),
				avg(WithholdingTaxRate),
				sum(SubsidizedAmt),
				sum(MDRAmt),
				sum(VATAmt), 
				sum(WithholdingTaxAmt),
				sum(SettleAmt), 
				sum(BillingAmt), 
				sum(Cnt)
			from acq_MerchTaxInvoice a (nolock)
			join atx_TxnCode b (nolock) on a.TxnCd = b.TxnCd
			join atx_BillingPlan c (nolock) on b.PlanId = c.PlanId
			left outer join atx_BillingPlan d (nolock) on b.SubsidizedPlanId = d.PlanId
			join aac_BusnLocation e (nolock) on a.BusnLocation = e.BusnLocation and e.AcctNo = @AcctNo
			where PrcsId = @PrcsId

			if @@error <> 0 return 95127	--Invalid Settle Date
		end
	end

	select 	@SubsidizedPlanId = cast(SubsidizedPlanId as varchar(12)),
		@PlanId = cast(PlanId as varchar(12)),
		@VATRate = cast(VATRate as varchar(10)),
		@WithholdingTaxRate = cast(isnull(WithholdingTaxRate,0) as varchar(10)),
		@SubsidizedAmt = cast(SubsidizedAmt as varchar(13)),
		@MDRAmt = cast(MDRAmt as varchar(13)),
		@VATAmt = cast(VATAmt as varchar(13)),
		@WithholdingTaxAmt = cast(WithholdingTaxAmt as varchar(13)),
		@SettleAmt = cast (SettleAmt as varchar(13)),
		@BillingAmt = cast(BillingAmt as varchar(13)),
		@Cnt = cast(Cnt as varchar(10))
	from #MerchSummary

	return 0
end
GO
