USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardTypePromotionProductsDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	: Delete existing Card Type Promotion Products
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2009/08/12 Peggy		   Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[CardTypePromotionProductsDelete]
	@IssNo uIssNo,
	@PromoType char(1),
	@CardType uCardType,
	@BusnLocation uMerchNo,
	@TxnCd uTxnCd,
	@ProdCd uProdCd

   as
begin
	if @CardType is null return 55048	--Card Type is a compulsory field
	if @BusnLocation is null return 55094	-- Compulsory field
	if @TxnCd is null return 55069		-- Compulsory field
	if @ProdCd is null return 55023		-- Compulsory field

	delete from ipr_CardTypePromotionProduct
	where IssNo = @IssNo and PromoType = @PromoType and TxnCd = @TxnCd
	and BusnLocation = @BusnLocation and ProdCd = @ProdCd and CardType = @CardType

	if @@error <> 0 return 71103	-- Failed to delete Card Type Promotion Product

	return 50546	-- Card Type Promotion Product has been deleted successfully
end
GO
