USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)-Acquiring Module

Objective	:Merchant deletion.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/05/29 Sam			   Initial development
2002/10/02 Jac			   Fixes
*******************************************************************************/

CREATE procedure [dbo].[MerchDelete]
	@AcqNo uAcqNo,
	@AcctNo uAcctNo
  as
begin
	declare	@eAppvInd char(1),
		@eSts uRefCd,
		@EntityId uEntityId

	set nocount on

	select @EntityId = EntityId, @AcqNo = AcqNo
	from aac_Account where AcctNo = @AcctNo
	if @@rowcount = 0 or @@error <> 0 
		return 60048	-- Merchant account not found

	----------
	BEGIN TRAN
	----------

	delete aac_Account where AcqNo = @AcqNo and AcctNo = @AcctNo
	if @@error <> 0
	begin
		rollback transaction
		return 70236	-- Failed to delete Merchant
	end

	delete aac_Entity where EntityId = @EntityId
	delete iss_Address where IssNo = @AcqNo and RefTo = 'MERCH' and RefKey = @EntityId and RefType = 'Address'
	delete iss_Contact where IssNo = @AcqNo and RefTo = 'MERCH' and RefKey = @EntityId and RefType = 'Contact'

	delete a
	from iss_Address a
	join aac_BusnLocation b on b.AcqNo = a.IssNo and b.EntityId = a.RefKey and b.AcctNo = @AcctNo
	where a.IssNo = @AcqNo and a.RefTo = 'BUSN' and a.RefType = 'Address'

	delete a
	from iss_Contact a
	join aac_BusnLocation b on b.AcqNo = a.IssNo and b.EntityId = a.RefKey and b.AcctNo = @AcctNo
	where a.IssNo = @AcqNo and a.RefTo = 'BUSN' and a.RefType = 'Contact'

	delete aac_BusnLocation where AcqNo = @AcqNo and AcctNo = @AcctNo
	if @@error <> 0
	begin
		rollback transaction
		return 70236	-- Failed to delete Merchant
	end

	-----------
	COMMIT TRAN
	-----------
	return 50193	-- Merchant has been deleted successfully
end
GO
