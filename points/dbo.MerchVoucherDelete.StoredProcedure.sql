USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchVoucherDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Delete Promotion Voucher for Merchant.

-------------------------------------------------------------------------------
When	   Who		CRN	Description
-------------------------------------------------------------------------------
2003/08/26 CK			Initial development
2006/07/13 Chew Pei		Delete @MerchNo
*******************************************************************************/
	
CREATE procedure [dbo].[MerchVoucherDelete]
	@AcqNo smallint,
	@BusnLocation uMerchNo,
	@VoucherPrefix varchar(4)
  as
begin
	if exists (select 1 from ard_Vouchers where AcqNo = @AcqNo and BusnLocation = @BusnLocation and VoucherPrefix = @VoucherPrefix)
	begin
		return 95392	-- Promotion Voucher is in used
	end

	delete ard_MerchantVoucher
	where AcqNo = @AcqNo and BusnLocation = @BusnLocation and VoucherPrefix = @VoucherPrefix 

	if @@error <> 0 return 70480	-- Failed to delete VoucherPrefix

	return 50322  -- Promotion Voucher has been deleted successfully

end
GO
