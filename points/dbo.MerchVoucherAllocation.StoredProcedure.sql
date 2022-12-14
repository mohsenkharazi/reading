USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchVoucherAllocation]    Script Date: 9/6/2021 10:33:55 AM ******/
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

CREATE procedure [dbo].[MerchVoucherAllocation]
	@AcqNo uIssNo,
	@VoucherPrefix varchar(4),
	@BusnLocation uMerchNo,
	@NoOfVoucher int
  as
begin
	declare @PrcsId uPrcsId,
		@PrcsDate datetime,
		@PrcsName varchar(50),
		@StartVoucher uVoucherId,
		@Cnt int

	select @PrcsName = 'MerchVoucherAllocation'

	exec TraceProcess @AcqNo, @PrcsName, 'Start'

	if @VoucherPrefix is null return 55147	-- Voucher Prefix is a compulsory field

	if @BusnLocation is null return 55253	-- Business Location is a compulsory field

	if @NoOfVoucher is null or @NoOfVoucher = 0 return 55255	-- No Of Voucher is a compulsory field

	if not exists (select 1 from ard_MerchantVoucher where AcqNo = @AcqNo and VoucherPrefix = @VoucherPrefix)
		return 55147	-- Voucher Prefix is a compulsory field

	if not exists (select 1 from aac_BusnLocation where BusnLocation = @BusnLocation)
		return 60085	-- Business Location not found

	select @StartVoucher = @VoucherPrefix + '%'

	select identity(int, 1,1) 'Seq', a.VoucherId
	into #Vouchers
	from ard_Vouchers a
	where a.AcqNo = @AcqNo and a.VoucherId like @StartVoucher and a.Sts = 'P'
	order by a.VoucherId

	if (select count(*) from #Vouchers) < @NoOfVoucher return 95276	-- Number of Voucher to be assign greater than available

	update a set BusnLocation = @BusnLocation, Sts = 'A'
	from ard_Vouchers a
	join #Vouchers b on b.VoucherId = a.VoucherId and b.Seq <= @NoOfVoucher

	if @@error <> 0 return 70979	-- Failed to update ard_Vouchers table

	return 54102	-- Merchant Voucher has been allocated successfully
end
GO
