USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardTypePromotionProductsMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	: Add new card type promotion products
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2009/08/12 Peggy		   Initial development

*******************************************************************************/
--	exec CardTypePromotionProductsMaint 'Add',1,'M','1','2000000014','200',15,1
CREATE procedure [dbo].[CardTypePromotionProductsMaint]
	@func varchar(5),
	@IssNo uIssNo,
	@PromoType char(1),
	@CardType uCardType,
	@BusnLocation uMerchNo,
	@TxnCd uTxnCd,
	@ProdCd uProdCd,
	@PlanId uPlanId

   as
begin
	if @CardType is null return 55048		-- Card Type is a compulsory field
	if @BusnLocation is null return 55094	-- Compulsory field
	if @TxnCd is null return 55069		-- Compulsory field
	if @ProdCd is null return 55023		-- Compulsory field

	if @func = 'Add'
	begin
		if @PlanId is null return 55019		-- Compulsory field

		if exists (select 1 from ipr_CardTypePromotionProduct where IssNo = @IssNo
			and PromoType = @PromoType and BusnLocation = @BusnLocation
			and TxnCd = @TxnCd and ProdCd = @ProdCd and CardType = @CardType)
			return 65094

		insert ipr_CardTypePromotionProduct (IssNo, PromoType, CardType, BusnLocation, TxnCd, ProdCd, PlanId)
		select @IssNo, @PromoType, @CardType, @BusnLocation, @TxnCd, @ProdCd, @PlanId  

		if @@error <> 0 return 71102	-- Failed to insert Card Type Promotion Product

		return 50544	-- Card Type Promotion Product has been added successfully
	end
	if @Func = 'Save'
	begin
		if not exists (select 1 from ipr_CardTypePromotionProduct where IssNo = @IssNo
			and PromoType = @PromoType and BusnLocation = @BusnLocation and TxnCd = @TxnCd and ProdCd = @ProdCd
			and CardType = @CardType)
			return 60102	-- Card Type Promotion Product not found

		update ipr_CardTypePromotionProduct set PlanId = @PlanId
		where IssNo = @IssNo and PromoType = @PromoType and BusnLocation = @BusnLocation
		and TxnCd = @TxnCd and ProdCd = @ProdCd and CardType = @CardType

		if @@error <> 0 return 71070	-- Failed to update Card Type Promotion Product

		return 50545	-- Card Type Promotion Product has been updated successfully
	end
end
GO
