USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BusnLocationApprovalIndMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:To activate the approval status of business location.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/07/13 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[BusnLocationApprovalIndMaint]
	@AcqNo uAcqNo,
	@BusnLocation uMerch,
	@ReasonCd uRefCd
   as
begin
	declare @ActiveSts uRefCd, @Rc int

	if @ReasonCd is not null return 95212 --No reason is needed for an approved Merchant

	select @ActiveSts = RefCd from iss_RefLib where IssNo = @AcqNo and RefType = 'MerchAcctSts' and RefInd = 0

	if @@rowcount = 0 or @@error <> 0 return 95124

	if not exists (select 1 from aac_Account a where a.Sts = @ActiveSts and a.AcctNo = (select b.AcctNo from aac_BusnLocation b where b.BusnLocation = @BusnLocation))
		return 95090 --Account not active

	if not exists (select 1 from aac_BusnLocation where AcqNo = @AcqNo and BusnLocation = @BusnLocation)
		return 60010 --Business Location not found

	exec @Rc = BusnLocationValidate @AcqNo, @BusnLocation

	if @@error <> 0 or @Rc ! = 0 return @Rc

	update aac_BusnLocation
	set Sts = @ActiveSts,
		AcctNo = AcctNo,	-- Add entry into iss_Object
		BusnName = BusnName,	-- Add entry into iss_Object
		PayeeName = PayeeName,	-- Add entry into iss_Object
		PartnerRefNo = PartnerRefNo	-- Add entry into iss_Object
	where BusnLocation = @BusnLocation

	if @@rowcount = 0 or @@error <> 0 return 70222 --Failed to update Business Location

--	exec MerchTxnCodeAutoInsert @AcqNo, @BusnLocation
--	exec ServiceFeeChargeByProdInsert @AcqNo, @BusnLocation

	return 50179 --Business Location has been updated successfully
end
GO
