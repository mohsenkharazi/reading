USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchVoucherMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Insert or update Voucher Prefix for Merchant.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2003/08/26 CK				Initial Development
2006/07/13 Chew Pei			Added MerchAcctNo and MerchNo as pass in parameter
*******************************************************************************/
	
CREATE procedure [dbo].[MerchVoucherMaint]
	@Func varchar(5),
	@AcqNo smallint,
	@BusnLocation uMerch,
	@VoucherPrefix varchar(4),
	@Descp uDescp50,
	@EffFrom datetime,
	@EffTo datetime,
	@ValidDays int,
	@Sts char(1)
	
  as
begin

	if @Descp is null
	begin
		return 55017
	end

	if @VoucherPrefix is null
	begin
		return 55147
	end


	if @Func = 'Add'
	begin
		if exists (select 1 from ard_MerchantVoucher where AcqNo = @AcqNo and BusnLocation = @BusnLocation and VoucherPrefix = @VoucherPrefix)
			return 65052	-- VoucherPrefix already exists

		insert ard_MerchantVoucher 
		(AcqNo, BusnLocation, VoucherPrefix, VoucherSeq, Descp, EffFrom, EffTo, ValidDays, Sts)
		select @AcqNo, @BusnLocation, @VoucherPrefix, 0, @Descp, @EffFrom, @EffTo, @ValidDays, @Sts

		if @@error <> 70478	-- Failed to add VoucherPrefix

		return 50320	-- VoucherPrefix has been added successfully
	end

	if @Func = 'Save'
	begin
		if not exists (select 1 from ard_MerchantVoucher where AcqNo = @AcqNo and BusnLocation = @BusnLocation and VoucherPrefix = @VoucherPrefix)
			return 60075	-- Voucher not found

		update ard_MerchantVoucher
		set Descp = @Descp, EffFrom = @EffFrom, EffTo = @EffTo, ValidDays = @ValidDays, Sts = @Sts
		where AcqNo = @AcqNo and BusnLocation = @BusnLocation and VoucherPrefix = @VoucherPrefix

		if @@error <> 0 return 70479	-- Failed to update VoucherPrefix

		return 50321	-- VoucherPrefix has been updated successfully
	end
	
end
GO
