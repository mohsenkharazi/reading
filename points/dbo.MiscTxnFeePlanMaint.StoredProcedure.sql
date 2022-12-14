USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MiscTxnFeePlanMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To update miscellaneous txn fee plan calculation method.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2007/04/12 KY			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[MiscTxnFeePlanMaint]
	@MiscTxnFeePlanId uPlanId,
	@MiscTxnFeeType uRefcd,
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
	if @MiscTxnFeePlanId is null return 55019
	if @MiscTxnFeeType is null return 55019
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
	end

	if not exists (select 1 from cmn_MiscTxnFeePlan where MiscTxnFeePlanId = @MiscTxnFeePlanId and MiscTxnFeeType = @MiscTxnFeeType and MinPurchAmt = @MinPurchAmt)
	begin
		insert into cmn_MiscTxnFeePlan 
			(MiscTxnFeePlanId, MiscTxnFeeType, MinPurchAmt, FirstPurchAmt, FirstBillingAmt, FirstBillingPts, SubseqPurchAmt, SubseqBillingAmt, SubseqBillingPts,
			 MinBillingAmt, MinBillingPts, MaxBillingAmt, MaxBillingPts, EffDateFrom, EffDateTo, LastUpdDate)
		values (@MiscTxnFeePlanId, @MiscTxnFeeType, @MinPurchAmt, @FirstPurchAmt, @FirstBillingAmt, @FirstBillingPts, @SubseqPurchAmt, @SubseqBillingAmt, @SubseqBillingPts, 
			@MinBillingAmt, @MinBillingPts, @MaxBillingAmt, @MaxBillingPts, @FromDate, @ToDate, getdate())

		if @@rowcount = 0 return 70009
		else return 50065

	end
	else
	begin
		update cmn_MiscTxnFeePlan
		set FirstPurchAmt = @FirstPurchAmt, FirstBillingAmt = @FirstBillingAmt, FirstBillingPts = @FirstBillingPts,
			SubseqPurchAmt = @SubseqPurchAmt, SubseqBillingAmt = @SubseqBillingAmt, SubseqBillingPts = @SubseqBillingPts,
			MinBillingAmt = @MinBillingAmt,	MinBillingPts = @MinBillingPts, MaxBillingAmt = @MaxBillingAmt, MaxBillingPts = @MaxBillingPts,
			EffDateFrom = @FromDate, EffDateTo = @ToDate, LastUpdDate = getdate()
		where MiscTxnFeePlanId = @MiscTxnFeePlanId and MiscTxnFeeType = @MiscTxnFeeType and MinPurchAmt = @MinPurchAmt

		if @@rowcount = 0 return 70010
		else return 50066
	end
end
GO
