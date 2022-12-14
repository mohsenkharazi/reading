USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BillingPlanMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To form the plan id with billing method.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2001/12/20 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[BillingPlanMaint]
	@IssNo uIssNo,
	@PlanId uPlanId,
	@MinPurchAmt money,
	@FirstPurchAmt money,
	@FirstBillingAmt money,
	@FirstBillingPts money,
	@SubseqPurchAmt money,
	@SubseqBillingAmt money,
	@SubseqBillingPts money,
	@MinBillingAmt money,
	@MinBillingPts money,
	@MaxBillingAmt money,
	@MaxBillingPts money,
	@FromDate datetime,
	@ToDate datetime
   as
begin
	if @PlanId is null return 55019
	if @MinPurchAmt is null select @MinPurchAmt = 0
	if @FirstPurchAmt is null select @FirstPurchAmt = 0
	if @FirstBillingAmt is null select @FirstBillingAmt = 0
	if @FirstBillingPts is null select @FirstBillingPts = 0
	if @SubseqPurchAmt is null select @SubseqPurchAmt = 0
	if @SubseqBillingAmt is null select @SubseqBillingAmt = 0
	if @SubseqBillingPts is null select @SubseqBillingPts = 0
	if @MinBillingAmt is null select @MinBillingAmt = 0
	if @MinBillingPts is null select @MinBillingPts = 0
	if @MaxBillingAmt is null select @MaxBillingAmt = 0
	if @MaxBillingPts is null select @MaxBillingPts = 0

	if isdate(@FromDate) = 1 and isdate(@ToDate) = 1
	begin
		if @FromDate > @ToDate
			return 95073
	end
	else
		if (isdate(@FromDate) = 0 and isdate(@ToDate) = 1) or
			(isdate(@FromDate) = 1 and isdate(@ToDate) = 0)
			return 95073

	if @FirstPurchAmt = 0 and @SubseqPurchAmt = 0
	begin
		select @SubseqPurchAmt = 1
--			@SubseqBillingAmt = 1
	end

/*	if @MaxBillingAmt = 0 and @MaxBillingPts = 0
	begin
		select @MaxBillingAmt = 100000.00,
			@MaxBillingPts = 10000000.00
	end
*/
	if not exists (select 1 from itx_BillingPlan where IssNo = @IssNo and PlanId = @PlanId and MinPurchAmt = @MinPurchAmt)
	begin
		insert itx_BillingPlan
			( IssNo,
			PlanId,
			MinPurchAmt,
			FirstPurchAmt,
			FirstBillingAmt,
			FirstBillingPts,
			SubseqPurchAmt,
			SubseqBillingAmt,
			SubseqBillingPts,
			MinBillingAmt,
			MinBillingPts,
			MaxBillingAmt,
			MaxBillingPts,
			EffDateFrom,
			EffDateTo,
			LastUpdDate )
		values (@IssNo,
			@PlanId,
			@MinPurchAmt,
			@FirstPurchAmt,
			@FirstBillingAmt,
			@FirstBillingPts,
			@SubseqPurchAmt,
			@SubseqBillingAmt,
			@SubseqBillingPts,
			@MinBillingAmt,
			@MinBillingPts,
			@MaxBillingAmt,
			@MaxBillingPts,
			@FromDate,
			@ToDate,
			getdate())
		if @@rowcount = 0
			return 70009
		else
			return 50065
	end
	else
	begin
		update itx_BillingPlan
		set FirstPurchAmt = @FirstPurchAmt,
			FirstBillingAmt = @FirstBillingAmt,
			FirstBillingPts = @FirstBillingPts,
			SubseqPurchAmt = @SubseqPurchAmt,
			SubseqBillingAmt = @SubseqBillingAmt,
			SubseqBillingPts = @SubseqBillingPts,
			MinBillingAmt = @MinBillingAmt,
			MinBillingPts = @MinBillingPts,
			MaxBillingAmt = @MaxBillingAmt,
			MaxBillingPts = @MaxBillingPts,
			EffDateFrom = @FromDate,
			EffDateTo = @ToDate
		where IssNo = @IssNo and PlanId = @PlanId and MinPurchAmt = @MinPurchAmt
		if @@rowcount = 0
		begin
			return 70010
		end
		return 50066
	end
end
GO
