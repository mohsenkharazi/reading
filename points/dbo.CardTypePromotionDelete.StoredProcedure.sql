USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardTypePromotionDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	: Delete existing Card Type Promotion and all related records
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2009/08/13 Peggy		   Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[CardTypePromotionDelete]
	@IssNo uIssNo,
	@PromoType char(1),
	@CardType uCardType,
	@BusnLocation uMerchNo,
	@TxnCd uTxnCd

   as
begin
	if @CardType is null return 55048	-- Card Type is a compulsory field
	if @BusnLocation is null return 55094	-- BusnLocation is a compulsory field
	if @TxnCd is null return 55069	-- Transaction code is a compulsory field

	begin transaction

	delete from ipr_CardTypePromotion
	where IssNo = @IssNo and PromoType = @PromoType and BusnLocation = @BusnLocation
	and TxnCd = @TxnCd and CardType = @CardType

	if @@error <> 0
	begin
		rollback transaction
		return 71071	-- Failed to delete Card Type Promotion
	end

	delete from ipr_CardTypePromotionProduct
	where IssNo = @IssNo and PromoType = @PromoType and BusnLocation = @BusnLocation
	and TxnCd = @TxnCd and CardType = @CardType

	if @@error <> 0
	begin
		rollback transaction
		return 71103	-- Failed to delete Card Type Promotion Product
	end

	commit transaction

	return 50546	-- Card Type Promotion Product has been deleted successfully

end
GO
