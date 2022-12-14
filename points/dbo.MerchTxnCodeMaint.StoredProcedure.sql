USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchTxnCodeMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:Cardtrend Systems Sdn. Bhd.
Modular		:Cardtrend Card Management System (CCMS)- Acquiring Module

Objective	:Merchant transaction code maintenance.
-------------------------------------------------------------------------------
When	   Who		CRN		Description
-------------------------------------------------------------------------------
2002/07/02 Sam				Initial development
2003/06/27 Sam				Incl. service fee indicator for calc service fee.
							SrvcFee = Amt - BillingAmt.
							relate: SrvcFee of atx_SourceTxn & atx_Txn.
2003/07/28 Sam				To enable capture the subsidized plan id to calc the total amount 
							to be subsidised by their head office of merchant/retail/station.
2003/09/10 Sam				To incl. reversal txn cd n force settle ind.
2003/11/20 Sam				Dedicate general or in-house merchant type.
2004/07/22 Alex				Add LastUpdDate.
*******************************************************************************/

CREATE procedure [dbo].[MerchTxnCodeMaint]
	@Func varchar(5),
	@AcqNo uAcqNo,
	@TxnCd uTxnCd,
	@Descp uDescp50,
	@Multiplier uRefCd,
	@PlanId uPlanId,
	@Manual char(1),
	@TxnInd uRefCd,
	@IssTxnCd uTxnCd,
	@IssNo uIssNo,
	@BillMethod char(1),
	@SrvcFeeInd char(1),
	@VATInd char(1),
	@BillInd char(1),
	@SubsidizedPlanId uPlanId,
	@Category smallint,
	@ReversalTxnCd uTxnCd,
	@ForceInd uYesNo,
	@Sic uRefCd,
	@LastUpdDate varchar(30)
  as
begin
	declare @LatestUpdDate datetime

	set nocount on

	if @TxnCd is null return 60006
	if @Descp is null return 55017
	if @Multiplier is null return 55018
	if @PlanId is null return 55019
--	if @TxnInd is null return 55140
--	if @IssTxnCd is null return 55128
	if @BillMethod is null return 55020
	if @Category is null return 60054 --Transaction Category not found

	if not exists (select 1 from atx_Plan where AcqNo = @AcqNo and PlanId = @PlanId and isnull(PlanId, 0) > 0)
		return 60012

--	if not exists (select 1 from atx_Plan where AcqNo = @AcqNo and PlanId = @SubsidizedPlanId and isnull(PlanId, 0) > 0)
--		return 60012

	if isnull(@IssTxnCd, 0) > 0
	begin
		if not exists (select 1 from itx_TxnCode where IssNo = @IssNo and TxnCd = @IssTxnCd)
			return 60045
	end

	if @Func = 'Add'
	begin
		if exists (select 1 from atx_TxnCode where AcqNo = @AcqNo and TxnCd = @TxnCd)
			return 65005 --Transaction Code already exists

		insert atx_TxnCode
--		( AcqNo, TxnCd, Descp, Multiplier, PlanId, AllowManualEntry, TxnInd, IssTxnCd, IssNo, BillMethod )
--		values ( @AcqNo, @TxnCd, @Descp, @Multiplier, @PlanId, @Manual, @TxnInd, @IssTxnCd, @IssNo, @BillMethod )
--2003/09/10B
--		( AcqNo, TxnCd, Descp, Multiplier, PlanId, AllowManualEntry, TxnInd, IssTxnCd, IssNo, BillMethod, BillInd, SrvcFeeInd, VATInd, SubsidizedPlanId, Category )
--		values ( @AcqNo, @TxnCd, @Descp, @Multiplier, @PlanId, @Manual, @TxnInd, @IssTxnCd, @IssNo, @BillMethod, @BillInd, @SrvcFeeInd, @VATInd, @SubsidizedPlanId, @Category )
		( AcqNo, TxnCd, Descp, Multiplier, PlanId, AllowManualEntry, TxnInd, IssTxnCd, IssNo, BillMethod, BillInd, SrvcFeeInd, VATInd, SubsidizedPlanId, Category, ReversalTxnCd, ForceSettleInd, Sic, LastUpdDate )
		values ( @AcqNo, @TxnCd, @Descp, @Multiplier, @PlanId, @Manual, @TxnInd, @IssTxnCd, @IssNo, @BillMethod, @BillInd, @SrvcFeeInd, @VATInd, @SubsidizedPlanId, @Category, @ReversalTxnCd, @ForceInd, @Sic, getdate() )
--2003/09/10E
		if @@rowcount = 0 or @@error <> 0 return 70015 --Failed to create Transaction Code
		return 50010
	end

	if not exists (select 1 from atx_TxnCode where AcqNo = @AcqNo and TxnCd = @TxnCd)
		return 55128

	if @LastUpdDate is null
		select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

	select @LatestUpdDate = LastUpdDate from atx_TxnCode where AcqNo = @AcqNo and TxnCd = @TxnCd
	if @LatestUpdDate is null
		select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

	-----------------
	begin transaction
	-----------------
	
	-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
	-- it means that record has been updated by someone else, and screen need to be refreshed
	-- before the next update.
	if @LatestUpdDate = convert(datetime, @LastUpdDate)
	begin

		update atx_TxnCode
		set Descp = @Descp,
			Multiplier = @Multiplier,
			PlanId = @PlanId,
			AllowManualEntry = @Manual,
			TxnInd = @TxnInd,
			IssTxnCd = @IssTxnCd,
			IssNo = @IssNo,
			BillMethod = @BillMethod,
			--2003/06/27B
			SrvcFeeInd = @SrvcFeeInd,
			VATInd = @VATInd,
			BillInd = @BillInd,
			--2003/06/27E
			--2003/07/28B
			SubsidizedPlanId = @SubsidizedPlanId,
			--2003/07/28B
			Category = @Category,
			--2003/09/10B
			ReversalTxnCd = @ReversalTxnCd,
			ForceSettleInd = @ForceInd,
			Sic = @Sic,
			--2003/09/10E
			LastUpdDate = getdate()
		where AcqNo = @AcqNo and TxnCd = @TxnCd

		if @@rowcount = 0 
		begin
			rollback transaction
			return 70016 --Failed to update Transaction Code
		end
	end
	else
	begin
		rollback transaction
		return 95307 --Fail update beecause date outofdate
	end
	------------------
	commit transaction
	------------------
	
	return 50011
end
GO
