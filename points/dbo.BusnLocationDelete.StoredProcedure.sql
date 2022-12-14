USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BusnLocationDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Deletion of Business Location.
		Enable to delete the new business location.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/10/30 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[BusnLocationDelete]
	@AcqNo uAcqNo,
	@BusnLocation uMerch
   as
begin
	declare @EntityId uEntityId, @PrcsName varchar(50), @Descp varchar(100)
	set nocount on

	select @EntityId = EntityId from aac_BusnLocation where BusnLocation = @BusnLocation
	if isnull(@EntityId, 0) > 0
	begin
		----------
		BEGIN TRAN
		----------
		delete aac_BusnLocation where AcqNo = @AcqNo and BusnLocation = @BusnLocation
		if @@error <> 0
		begin
			rollback tran
			return 70357
		end
		delete aac_Entity where EntityId = @EntityId
		delete iss_Contact where IssNo = @AcqNo and RefTo = 'BUSN' and RefType = 'CONTACT' and RefKey = @EntityId
		delete iss_Address where IssNo = @AcqNo and RefTo = 'BUSN' and RefType = 'ADDRESS' and RefKey = @EntityId
		-----------
		COMMIT TRAN
		-----------
		return 50235
	end
	return 60010
end
GO
