USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AlertTypeMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	:Capture Alert Type from the CCMS and store to the iss_User Table
SP Level	:Primary
-------------------------------------------------------------------------------
When	   Who		CRN		Description
-------------------------------------------------------------------------------
2005/04/20 Alex				Initial Develop

*******************************************************************************/

CREATE procedure [dbo].[AlertTypeMaint]
	@IssNo uIssNo,
	@UserId uUserId,
	@RefCd uRefcd
	
  as
begin
	declare @RefInd smallint
		
	if((select RefInd & 1 from iss_RefLib where RefType='AlertType' and RefCd = @RefCd) = 1)
	begin
		if (select EmailAddr from iss_User where UserId = @UserId) is null
		return 55214-- Email Address is a compulsory field
	end	

	set nocount on

	select @RefInd = RefInd from iss_RefLib where RefCd = @RefCd and RefType = 'AlertType' 	

	-----------------
	Begin Transaction
	-----------------

	update iss_User
	set AlertType =(select isnull(AlertType,0) + @RefInd from iss_User where IssNo = @IssNo and UserId = @UserId)
	where IssNo = @IssNo and UserId = @UserId
	
	if @@error <> 0
	begin
		Rollback Transaction
		return 70888--Failed To Adding Alert Type
	end

	
	------------------
	Commit transaction
	------------------
		
	return 50328 --Alert Type Adding Succesfully

	

end
GO
