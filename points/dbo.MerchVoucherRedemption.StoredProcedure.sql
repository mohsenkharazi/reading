USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchVoucherRedemption]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Maintain Promotion details.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/04/09 Jac			   Initial development
2003/02/18 Chew Pei			Added TxnInd (Per Txn (P), Cumulative Txn (C))

*******************************************************************************/

CREATE procedure [dbo].[MerchVoucherRedemption]
	@AcqNo uIssNo,
	@VoucherId uVoucherId,
	@BusnLocation uMerchNo,
	@RdmpDate datetime
  as
begin
	declare @PrcsId uPrcsId,
		@PrcsDate datetime,
		@PrcsName varchar(50)

	select @PrcsName = 'MerchVoucherAllocation'

	exec TraceProcess @AcqNo, @PrcsName, 'Start'

	select @PrcsId = CtrlNo, @PrcsDate = CtrlDate
	from iss_Control where IssNo = @AcqNo and CtrlId = 'PrcsId'

	if @VoucherId is null return 55252	-- VoucherId is a compulsory field

	if @BusnLocation is null return 55253	-- Business Location is a compulsory field

	if @RdmpDate is null return 55254	-- Redemption date is a compulsory field

	if not exists (select 1 from ard_Vouchers where VoucherId = @VoucherId)
		return 60084	-- Voucher not found

	if not exists (select 1 from aac_BusnLocation where BusnLocation = @BusnLocation)
		return 60085	-- Business Location not found

	if @RdmpDate > @PrcsDate return 95387	-- Future date is not allowed

	if exists (select 1 from ard_Vouchers where AcqNo = @AcqNo and VoucherId = @VoucherId and Sts = 'R')
		return 95388	-- Voucher has been redeemed

	if exists (select 1 from ard_Vouchers where AcqNo = @AcqNo and VoucherId = @VoucherId and Sts <> 'A')
		return 95396	-- Merchant Voucher has not allocate

	if exists (select 1 from ard_Vouchers where AcqNo = @AcqNo and VoucherId = @VoucherId and CreationDate > @RdmpDate)
		return 95390	-- Invalid redemption date

	if exists (select 1 from ard_Vouchers where AcqNo = @AcqNo and VoucherId = @VoucherId and ExpiryDate < @RdmpDate)
		return 95391	-- Voucher has been expired

	update ard_Vouchers set RdmpDate = @RdmpDate, Redeemed = 'Y',
		RdmpBusnLocation = @BusnLocation, PrcsId = @PrcsId, Sts = 'R'
	where AcqNo = @AcqNo and VoucherId = @VoucherId and Sts = 'A'

	if @@error <> 0 return 70979	-- Failed to update ard_Vouchers table

	return 54100	-- Voucher updated successfully
end
GO
