USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AlertTypeDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	:Delete the Alert Type from user
SP Level	:Primary
-------------------------------------------------------------------------------
When	   Who		CRN		Description
-------------------------------------------------------------------------------
2005/04/20 Alex				Initial Develop

*******************************************************************************/

CREATE procedure [dbo].[AlertTypeDelete]
	@IssNo uIssNo,
	@UserId uUserId,
	@RefCd uRefCd
	
  as
begin
	declare @RefInd smallint
	

	select @RefInd = RefInd from iss_RefLib where RefCd = @RefCd and RefType = 'AlertType' 	

	-----------------
	Begin Transaction
	-----------------

	update iss_User
	set AlertType =(select isnull(AlertType,0) - @RefInd from iss_User where IssNo = @IssNo and UserId = @UserId)
	where IssNo = @IssNo and UserId = @UserId
	
	if @@error <> 0
	begin
		Rollback Transaction
		return 70889 --Failed To Deleted Alert Type
	end

	
	------------------
	Commit transaction
	------------------

	return 50329 --Alert Type Deleted Succesfully
		
	

	

end
GO
