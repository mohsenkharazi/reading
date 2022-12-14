USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GetControl]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Call this stored procedure to log a record in the job audit table.

-------------------------------------------------------------------------------
When	   Who		CRN	   Desc
-------------------------------------------------------------------------------
2001/10/24 Jacky		   Initial development

******************************************************************************************************************/

CREATE procedure [dbo].[GetControl]
	@IssNo uIssNo
  as
begin
--	select Descp, 'CtrlId - '+isnull(CtrlId,'')
--	from iss_Control
--	where IssNo = @IssNo
--	union
	select Descp, 'CtrlNo - '+isnull(convert(varchar(10),CtrlNo),'')
	from iss_Control
	where IssNo = @IssNo
	union
	select Descp, 'CtrlDate - '+isnull(convert(varchar(20), CtrlDate, 107),'')
	from iss_Control
	where IssNo = @IssNo
end
GO
