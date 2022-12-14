USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AlertTypeSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	:Select available Alert Type from the iss_User Table
SP Level	:Primary
-------------------------------------------------------------------------------
When	   Who		CRN		Description
-------------------------------------------------------------------------------
2005/04/20 Alex				Initial Develop

*******************************************************************************/

CREATE procedure [dbo].[AlertTypeSelect]
	@IssNo uIssNo,
	@UserId uUserId
	
  as 
begin

	set nocount on

	if (select AlertType from iss_User where UserId =@UserId and IssNo = @IssNo)is null
	begin
		
		select b.RefCd as 'AlertType', b.Descp as 'Descp'
		from Iss_Reflib b 
		where b.RefType ='AlertType' and IssNo = @IssNo 
	
	end
	else
	begin
		
		select b.RefCd as 'AlertType' , b.Descp as 'Descp'
		from iss_User a, Iss_Reflib b 
		where a.IssNo=b.IssNo and a.IssNo =@IssNo and a.UserId =@UserId  and b.RefType ='AlertType' and a.AlertType & b.RefInd = 0
	end
	
end
GO
