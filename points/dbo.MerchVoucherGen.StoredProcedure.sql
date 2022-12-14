USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchVoucherGen]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To generate merchant voucher no
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2003/08/27 Wendy		   Initial development
*******************************************************************************/
CREATE procedure [dbo].[MerchVoucherGen] 
	@AcqNo uAcqNo,
	@VoucherPrefix varchar(4),
	@CurrVoucherSeq int,
	@NoOfVoucher int
  as
begin
	declare @VoucherId uVoucherId,
		@Count int,
		@VoucherDescp uDescp50,
		@CreationDate datetime,
		@ValidDays int,
		@ExpiryDate datetime,
		@DeftMerchVoucherSts char(1)

	if isnull(@VoucherPrefix,'') = ''
	begin
		return 55147 -- Voucher Prefix is a compulsory field
	end
	if isnull(@CurrVoucherSeq,-1) = -1
	begin
		return 95393 -- Current Voucher sequence must be > or = 0
	end
	if isnull(@NoOfVoucher,0) = 0
	begin
		return 95394 -- Number of Voucher must be > 0
	end

	select @Count = 0

	select @VoucherDescp = Descp,
		@ValidDays = ValidDays
	from ard_MerchantVoucher where @AcqNo = AcqNo and @VoucherPrefix = VoucherPrefix

	select @CreationDate = CtrlDate,
		@ExpiryDate = CtrlDate+@ValidDays
	from iss_Control
	where CtrlId = 'PrcsId'	

	select @DeftMerchVoucherSts = VarcharVal from iss_Default where Deft = 'DeftMerchVoucherSts'

	begin transaction

	while @NoOfVoucher <> @Count
	begin
		select @CurrVoucherSeq = @CurrVoucherSeq + 1
		select @VoucherId = @VoucherPrefix + ltrim(cast(@CurrVoucherSeq as varchar(10)))

		insert into ard_Vouchers
			(AcqNo, MerchNo, BusnLocation, VoucherPrefix, VoucherId, Descp, RefNo, CreationDate, 
			RdmpDate, ExpiryDate, ExtractDate, Redeemed, RdmpBusnLocation, BatchId, PrcsId, Sts)
		select @AcqNo, NULL, NULL, @VoucherPrefix, @VoucherId, @VoucherDescp, NULL, @CreationDate, 
			NULL, @ExpiryDate, NULL, NULL, NULL, NULL, NULL, @DeftMerchVoucherSts

		if @@error <> 0
		begin
			rollback transaction
			return 70979 -- Failed to update ard_Vouchers table
		end

		select @Count = @Count + 1

	end

	update ard_MerchantVoucher set VoucherSeq = @CurrVoucherSeq where VoucherPrefix = @VoucherPrefix
	if @@error <> 0
	begin
		rollback transaction
		return 70482 -- Failed to update ard_MerchantVoucher table
	end

	commit transaction

	return 54101 -- Merchant Voucher has been generated succesfully

end
GO
