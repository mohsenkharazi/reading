USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CheckPermission]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure checks the user permission over a resources.

-------------------------------------------------------------------------------
When	   Who		CRN	   Desc
-------------------------------------------------------------------------------
2002/03/06 Jacky		   Initial development

******************************************************************************************************************/

CREATE procedure [dbo].[CheckPermission]
	@Appl varchar(30),
	@ResrcId int,
	@UserId uUserId
   as
begin
	declare @Access int
	select @Access = 1
	from iss_Permission
	where UserId = @UserId and Appl = @Appl and ResrcId = @ResrcId

	return isnull(@Access, 0)
end
GO
