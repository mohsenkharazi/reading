USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchCardRangeDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:Cardtrend Systems Sdn. Bhd.
Modular		:Cardtrend Card Management System (CCMS)- Acquiring Module

Objective	:To delete card range acceptance for business location.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/07/31 Sam			   Initial development
*******************************************************************************/

CREATE procedure [dbo].[MerchCardRangeDelete]
	@AcqNo uAcqNo,
	@BusnLocation uMerch,
	@CardRangeId nvarchar(10)
  as
begin
	set nocount on

	if not exists (select 1 from aac_BusnLocation a join iss_RefLib b on a.AcqNo = b.IssNo and a.Sts = b.RefCd and b.RefType = 'MerchAcctSts' and b.RefInd = 0 where a.AcqNo = @AcqNo and a.BusnLocation = @BusnLocation)
		return 95132 --Check Business Location status

	if isnull(@CardRangeId,'') <> ''
	begin
		if not exists (select 1 from acq_CardRangeAcceptance where AcqNo = @AcqNo and BusnLocation = @BusnLocation and CardRangeId = @CardRangeId)
			return 70258 --Failed to delete Merchant Card Acceptance
	
		----------
		begin tran
		----------
	
		delete acq_CardRangeAcceptance
		where AcqNo = @AcqNo and BusnLocation = @BusnLocation and CardRangeId = @CardRangeId
		 
		if @@error <> 0 
		begin
			rollback tran
			return 70258 --Failed to delete Merchant Card Acceptance
		end
	
		delete acq_TxnCodeMapping
		where AcqNo = @AcqNo and BusnLocation = @BusnLocation and CardRangeId = @CardRangeId
	
		if @@error <> 0
		begin
			rollback tran
			return 70387	--Failed to delete Txn Code Mapping
		end
	
		-----------
		commit tran
		-----------
	end
	else
	begin
		----------
		begin tran
		----------
	
		delete acq_CardRangeAcceptance
		where AcqNo = @AcqNo and BusnLocation = @BusnLocation
		 
		if @@error <> 0 
		begin
			rollback tran
			return 70258 --Failed to delete Merchant Card Acceptance
		end
	
		delete acq_TxnCodeMapping
		where AcqNo = @AcqNo and BusnLocation = @BusnLocation
	
		if @@error <> 0
		begin
			rollback tran
			return 70387	--Failed to delete Txn Code Mapping
		end
	
		-----------
		commit tran
		-----------
	end
	return 50216 --Merchant Card Acceptance has been deleted successfully
end
GO
