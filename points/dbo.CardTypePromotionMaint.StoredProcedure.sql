USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardTypePromotionMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Maintain Card Type Promotion details.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2009/08/11 Peggy		   Initial development
2010/01/13 Peggy		   Added checking of @EffDateFrom and @EffDateTo cannot 
					       be null value.
*******************************************************************************/
CREATE procedure [dbo].[CardTypePromotionMaint]
	@func varchar(5),
	@IssNo uIssNo,
	@PromoType char(1),
	@BusnLocation uMerchNo,	
	@CardType uCardType,
	@TxnCd uTxnCd,
	@BillMethod char(1),
	@PlanId uPlanId,
	@EffDateFrom datetime,
	@EffDateTo datetime

   as
begin
	if @CardType is null return 55048 -- Card Type is a compulsory field
	if @BusnLocation is null return 55094	-- BusnLocation is a compulsory field
	if @TxnCd is null return 55069	-- Transaction code is a compulsory field
	if @BillMethod is null return 55020	-- Bill method is a compulsory field
	if @BillMethod = 'T' and @PlanId is null return 55019	-- Plan Id is a compulsory field
	if @EffDateFrom is null return 55208 --Effective From Date is a compulsory field
	if @EffDateTo is null return 55209 --Effective To Date is a compulsory field

	if @Func = 'Add'
	begin
		if exists (select 1 from ipr_CardTypePromotion where IssNo = @IssNo
		and BusnLocation = @BusnLocation and TxnCd = @TxnCd and CardType = @CardType)
			return 65095	-- Card Type promotion already exists

		insert ipr_CardTypePromotion
			(IssNo, PromoType, CardType, BusnLocation, TxnCd, BillMethod, PlanId, EffDateFrom, EffDateTo)
		values (@IssNo, @PromoType, @CardType, @BusnLocation, @TxnCd, @BillMethod, @PlanId, @EffDateFrom, @EffDateTo)

		if @@error <> 0 return 70492	-- Failed to create Card Type Promotion

		return 50361   -- Card Type Promotion has been added successfully	
	end
	if @Func = 'Save'
	begin
		if not exists (select 1 from ipr_CardTypePromotion where IssNo = @IssNo
		and BusnLocation = @BusnLocation and TxnCd = @TxnCd and CardType = @CardType)
			return 60103	-- Card Type promotion not found

		update ipr_CardTypePromotion set BillMethod = @BillMethod , PlanId = @PlanId,
			EffDateFrom = @EffDateFrom, EffDateTo = @EffDateTo
		where IssNo = @IssNo and TxnCd = @TxnCd and BusnLocation = @BusnLocation and CardType = @CardType

		if @@error <> 0 return 70493	-- Failed to update Card Type Promotion

		return 50362 -- Card Type Promotion has been update successfully
	end
end
GO
