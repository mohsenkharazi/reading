USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CopyPermission]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Change User Password

Required files  : 

------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2003/09/24 Kenny		   Initial development
2003/12/08 Kenny		   Add columns(ResrcName, CtrlName) into tables
******************************************************************************************************************/

CREATE procedure [dbo].[CopyPermission]
	@IssNo uIssNo,
 	@CopyFrom uUserId,
	@CopyTo uUserId,
	@Appl varchar(50)
   as
begin

	if @CopyFrom = @CopyTo return 95282	-- Cannot copy screen permission to the same user

	if not exists( select * from iss_User where UserId = @CopyFrom) return 60004	-- User Account not found
	if not exists( select * from iss_User where UserId = @CopyTo )  return 60004	-- User Account not found

	if exists (select * from iss_PermissionControl where UserId = @CopyTo) return 70484	-- Failed to copy permission. This operation is only allowed for new user
	if exists (select * from iss_Permission where UserId = @CopyTo) return 70484		-- Failed to copy permission. This operation is only allowed for new user

	-----------------
	BEGIN TRANSACTION
	-----------------
	insert into iss_PermissionControl
	(Appl, ResrcName, ResrcId, CtrlName, CtrlId, UserId)
	select @Appl, ResrcName, ResrcId, CtrlName, CtrlId, @CopyTo
	from iss_PermissionControl where UserId = @CopyFrom and @IssNo = @IssNo

	if @@error <> 0
	begin
		rollback transaction
		return 1
	end

	insert into iss_Permission
	(UserId, Appl, Resrcname, ResrcId, Permission)
	select @CopyTo, @Appl, ResrcName, ResrcId, Permission
	from iss_Permission where UserId = @CopyFrom and @IssNo = @IssNo
	
	if @@error <> 0
	begin
		rollback transaction
		return 1
	end

	------------------
	COMMIT TRANSACTION
	------------------
	return 54042	-- User screen permission has been copied successfully
end
GO
