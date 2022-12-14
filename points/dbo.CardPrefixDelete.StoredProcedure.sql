USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardPrefixDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To delete existing card prefix
		 for a particular plastic type.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2001/12/28 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[CardPrefixDelete]
	@IssNo uIssNo,
	@CardLogo uCardLogo,
	@PlasticType uPlasticType,
	@StartPrefix uCardNo,
	@EndPrefix uCardNo,
	@CurrentPrefix uCardNo,
	@CardPrefix uCardNo
   as
begin
	select @StartPrefix = StartNo,
		@EndPrefix = EndNo
	from iss_CardPrefix
	where IssNo = @IssNo and CardLogo = @CardLogo and @PlasticType = @PlasticType and CardPrefix = @CardPrefix
	if @@rowcount = 0 return 60009

	if exists (select 1 from iac_Card where IssNo = @IssNo and convert(bigint, (substring ((convert(varchar(19), CardNo)), 1, (len(CardNo) - 1)))) between @StartPrefix and @EndPrefix)
		return 95000

	delete iss_CardPrefix
	where IssNo = @IssNo and CardLogo = @CardLogo and @PlasticType = @PlasticType and CardPrefix = @CardPrefix
	if @@rowcount = 0
	begin
		return 70080
	end
	return 50040
end
GO
