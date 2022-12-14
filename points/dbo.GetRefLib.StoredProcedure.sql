USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GetRefLib]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************

Copyright	: CardTrend Systems Sdn Bhd 
Project		: CardTrend Card Management System Acquirer
Description	: To return the month of a year
		  (User Definition Functions)

When		Who		Where
------------------------------------------------------------------
2002/06/05	Jacky		Initial development

******************************************************************/

CREATE procedure [dbo].[GetRefLib] @RefType uRefType, @IssNo uIssNo=2 as
begin
	select * from iss_RefLib where IssNo=@IssNo and RefType = @RefType
end
GO
