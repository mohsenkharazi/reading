USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ComputerInfoMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: User Logon

Required files  : 

------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2001/09/10 Kenny		   Initial development
******************************************************************************************************************/

CREATE procedure [dbo].[ComputerInfoMaint]
	@UserId uUserId,
	@IssNo uIssNo,
	@ComputerName nvarchar(50),
	@IPAddr varchar(15)
   as
begin	

	if not exists (select 1 from iss_User where UserId = @UserId)
		return 95007	-- Invalid User ID

	update iss_User set WorkStationId = @ComputerName, IPAddr = @IPAddr 
	where UserId = @UserId and IssNo = @IssNo

	return 0
end
GO
