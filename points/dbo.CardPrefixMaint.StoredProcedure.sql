USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardPrefixMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To insert new or update existing card prefix
		 for a particular plastic type.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2001/12/28 Sam		   Initial development

2002/02/04 Wendy		   Allowing card prefix status change (active/suspend) 	

*******************************************************************************/

CREATE procedure [dbo].[CardPrefixMaint]
	@Func varchar(9),
	@IssNo uIssNo,
	@CardLogo uCardLogo,
	@PlasticType uPlasticType,
	@StartPrefix varchar(19),
	@EndPrefix varchar(19),
	@CurrentPrefix uCardNo,
	@CardPrefix uCardNo, 
	@Sts char(1)
   as
begin
	if @StartPrefix is null or @EndPrefix is null return 95012
	if @StartPrefix > @EndPrefix return 95013
	if substring((convert(char(19),@StartPrefix)), 1, 1) <>  
		substring((convert(char(19),@CardPrefix)), 1, 1)
		return 95014

	if @Func = 'Add'
	begin
		if exists (select 1 from iss_CardPrefix where @CardPrefix = CardPrefix)
			return 95046
		if exists (select 1 from iss_CardPrefix where @StartPrefix between StartNo and EndNo)
			return 95048
		if exists (select 1 from iss_CardPrefix where @EndPrefix between StartNo and EndNo)
			return 95048
		if exists (select 1 from iss_CardPrefix where StartNo between @StartPrefix and @EndPrefix)
			return 95048
		if exists (select 1 from iss_CardPrefix where EndNo between @StartPrefix and @EndPrefix)
			return 95048

		insert into iss_CardPrefix
			(IssNo, CardLogo, PlasticType, CardPrefix, StartNo,
			CurrNo, EndNo, Sts, Priority)
		select	@IssNo, @CardLogo, @PlasticType, @CardPrefix, convert(bigint, @StartPrefix),
			0, convert(bigint, @EndPrefix), 'A', 1

		if @@rowcount = 0
		begin
			return 70078
		end
		return 50038
	end

	if @Func = 'Save'
	begin
		if not exists (select 1 from iss_CardPrefix where CardPrefix = @CardPrefix)
			return 60009
		if @EndPrefix < @CurrentPrefix
			return 95047
		if exists (select 1 from iss_CardPrefix where CardPrefix <> @CardPrefix and @StartPrefix between StartNo and EndNo)
			return 95048
		if exists (select 1 from iss_CardPrefix where CardPrefix <> @CardPrefix and @EndPrefix between StartNo and EndNo)
			return 95048
		if exists (select 1 from iss_CardPrefix where CardPrefix <> @CardPrefix and StartNo between @StartPrefix and @EndPrefix)
			return 95048
		if exists (select 1 from iss_CardPrefix where CardPrefix <> @CardPrefix and EndNo between @StartPrefix and @EndPrefix)
			return 95048

		update iss_CardPrefix
		set StartNo = @StartPrefix,
			EndNo = convert(bigint, @EndPrefix),
			Sts = @Sts
		where IssNo = @IssNo and CardLogo = @CardLogo and @PlasticType = @PlasticType and CardPrefix = @CardPrefix

		if @@rowcount = 0
		begin
			return 70079
		end
		return 50039
	end

/*	if (@Func = 'Activate' or @Func = 'Suspend')
	begin
		update iss_CardPrefix
		set Sts = @Sts
		where IssNo = @IssNo and CardLogo = @CardLogo and @PlasticType = @PlasticType and CardPrefix = @CardPrefix
	end
*/
end
GO
