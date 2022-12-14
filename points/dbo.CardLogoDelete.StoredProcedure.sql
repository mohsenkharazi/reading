USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardLogoDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To delete existing card logo.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2001/12/19 Sam			   Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[CardLogoDelete]
	@IssNo uIssNo,
	@CardLogo uCardLogo,
	@Descp uDescp50,
	@LaunchDate datetime
   as
begin
	if exists (select 1 from iss_PlasticType where IssNo = @IssNo and CardLogo = @CardLogo)
	begin
		return 95000
	end

	delete iss_CardLogo
	where IssNo = @IssNo and CardLogo = @CardLogo
	if @@rowcount = 0
	begin
		return 70008
	end
	return 50009
end
GO
