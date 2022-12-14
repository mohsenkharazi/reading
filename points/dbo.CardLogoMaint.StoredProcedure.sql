USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardLogoMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	: CarDtrend Systems Sdn. Bhd.
Modular		: CarDtrend Card Management System (CCMS)- Issuing Module

Objective	: To insert new or update existing card logo.

SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2001/12/19 Sam			   Initial development
2204/07/19 Alex            adding new statement (Last Update)

*******************************************************************************/
	
CREATE procedure [dbo].[CardLogoMaint]
	@Func varchar(5),
	@IssNo uIssNo,
	@CardLogo uCardLogo,
	@Descp uDescp50,
	@Program char(1),
	@LaunchDate datetime,
	@LastUpdDate varchar(30)
   as
begin
	declare @LatestUpdDate datetime
	if @IssNo = 0
	begin
		return 55015
	end

	if @CardLogo is null
	begin
		return 55002
	end

	if isdate(@LaunchDate) = 0
	begin
		return 55016
	end

	if @Func = 'Add'
	begin
		if exists (select 1 from iss_CardLogo where IssNo = @IssNo and CardLogo = @CardLogo)
			return 65002

		insert iss_CardLogo (IssNo, CardLogo, Descp, Program, LaunchDate, LastUpdDate)
		select @IssNo, @CardLogo, isnull(@Descp, 'X'), @Program, @LaunchDate, getdate()
		if @@rowcount = 0
		begin
			return 70006
		end
		return 50007
	end

	if @Func = 'Save'
	begin
		if @LastUpdDate is null
			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

		select @LatestUpdDate = LastUpdDate from iss_CardLogo where IssNo = @IssNo and CardLogo = @CardLogo
		if @LatestUpdDate is null
			select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

		-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
		-- it means that record has been updated by someone else, and screen need to be refreshed
		-- before the next update.
		-----------------
		begin transaction
		-----------------
		if @LatestUpdDate = convert(datetime, @LastUpdDate)
		
		begin
			update iss_CardLogo
			set Descp = @Descp, 
				Program = @Program, 
				LaunchDate = @LaunchDate,
				LastUpdDate = getdate()
			where IssNo = @IssNo and CardLogo = @CardLogo
			if @@rowcount = 0
			begin
				rollback transaction
				return 70007
			end	
		end
		else
		begin
			rollback transaction
			return 95307
		end
		------------------
		commit transaction
		------------------
	
		return 50008	    
	end

/*	if not exists (select 1 from iss_CardLogo where IssNo = @IssNo and CardLogo = @CardLogo)
	begin
		if @Func = 'Save'
			return 70007
		else
		begin
			insert iss_CardLogo (IssNo, CardLogo, Descp, Program, LaunchDate)
			select @IssNo, @CardLogo, isnull(@Descp, 'X'), @Program, @LaunchDate
			if @@rowcount = 0
			begin
				return 70006
			end
			return 50007
		end
	end
	else
		if @Func = 'Add'
			return 65002
		else
		begin
			update iss_CardLogo
			set Descp = @Descp, Program = @Program, LaunchDate = @LaunchDate
			where IssNo = @IssNo and CardLogo = @CardLogo
			if @@rowcount = 0
			begin
				return 70007
			end
			return 50008
		end
*/
end
GO
