USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CycleControlMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To insert new or update existing Cycle Control Number.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2001/12/20 Sam			   Initial development
2003/06/26 Aeris		   Take off CycDay, CycInterval. Add in Descp
2004/07/08 Chew Pei			Change to standard code
2004/07/21 Alex			   Add LastUpdDate   	
*******************************************************************************/

CREATE procedure [dbo].[CycleControlMaint]
	@Func varchar(5),
	@IssNo uIssNo,
	@CycNo uCycNo,
	@Descp uDescp50,
	@Sts char(1),
	@LastUpdDate varchar(30)
   as
begin
	declare @LatestUpdDate datetime	

	Set nocount on
	declare @PrcsName varchar(50),
		@NextCycDate datetime

	if @CycNo is null return 55115	-- Cycle Number is a compulsory field
	
	if @Func = 'Add'
	begin
		if exists (select 1 from iss_CycleControl where IssNo = @IssNo and CycNo = @CycNo)
			return 65037	-- Cycle Control Number already exists

		insert iss_CycleControl
			(IssNo, CycNo, Descp, Sts, LastUpdDate)
		select @IssNo, @CycNo, @Descp, isnull(@Sts, 'A'), getdate()

		if @@error <> 0
		begin
			return 70349	-- Failed to create Cycle Control Number
		end
		return 50230	-- Cycle Control Number created successfully
	end

	if @Func = 'Save'
	begin
		if not exists (select 1 from iss_CycleControl where IssNo = @IssNo and CycNo = @CycNo)
			return 60055	-- Cycle Control Number not found
		
		if @LastUpdDate is null
			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

		select @LatestUpdDate = LastUpdDate from iss_CycleControl where IssNo = @IssNo and CycNo = @CycNo
		if @LatestUpdDate is null
			select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

		-----------------
		begin transaction
		-----------------
	
		-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
		-- it means that record has been updated by someone else, and screen need to be refreshed
		-- before the next update.
		if @LatestUpdDate = convert(datetime, @LastUpdDate)
		begin
			update iss_CycleControl
			set	Descp = @Descp,
				Sts = @Sts,
				LastUpdDate = getdate()
			where IssNo = @IssNo and CycNo = @CycNo

			if @@error <> 0
			begin
				return 70345	-- Failed to update cycle control table
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
		return 50231	-- Cycle Control Number updated successfully
	end
	Set nocount Off
end
GO
