USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CycleControlDetailMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Insert or update Cycle control detail.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/27 Aeris		   Initial development
2004/07/08 Chew Pei			Change to standard coding
2004/07/21 Alex			   Add LastUpdDate
*******************************************************************************/
CREATE procedure [dbo].[CycleControlDetailMaint]
	@Func varchar(5),
	@IssNo uIssNo,
	@CycNo uCycNo,
	@CycMth smallint,
	@CycDate Datetime,
	@DueDate Datetime,
	@DueDay smallint,
	@GracePeriod smallint,
	@LastUpdDate varchar(30)
   as
begin
	declare @LatestUpdDate datetime

	Set nocount on
	
	if @CycMth is null return 55172
	if @CycDate is null return 95002
	if @CycDate < GETDATE() return 95259
	if @DueDate  <  @CycDate return 95260

	if @Func = 'Add'
	begin
		if exists(select 1 from iss_CycleDate where IssNo=@IssNo and CycNo= @CycNo and CycMth = @CycMth)
			return 65051 --Cycle control detail already exists 
	
		Insert into iss_CycleDate (IssNo, CycNo, CycMth, CycDate, DueDate, DueDay, GracePeriod, LastUpdDate)
		select @IssNo, @CycNo, @CycMth, @CYcDate, @DueDate, @DueDay, @GracePeriod, getdate()

		if @@rowcount = 0
		begin
			return 70440
		end

		return 50305
	end

	if @Func = 'Save'
	begin
		if @LastUpdDate is null
			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

		select @LatestUpdDate = LastUpdDate from iss_CycleDate where CycNo= @CycNo and IssNo = @IssNo and CycMth = @CycMth
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
					
			update iss_CycleDate
			set CycDate = @CycDate,	
			    DueDate = @DueDate,
			    DueDay = @DueDay,
			    GracePeriod = @GracePeriod,
			    LastUpdDate = getdate()
 
			where CycNo= @CycNo and IssNo = @IssNo and CycMth = @CycMth

			if @@rowcount = 0
			begin
				return 70439
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

		return 50304
	end

	Set nocount off
	
/*	if @Func = 'Save'
	begin
				
		update iss_CycleDate
		set StmtDate = @StmtDate,	
		    DueDate = @DueDate,
		    DueDay = @DueDay,
		    GracePeriod = @GracePeriod
		where CycNo= @CycNo and IssNo = @IssNo and CycMth = @CycMth

		if @@rowcount = 0
		begin
			return 70439
		end

		return 50304
	end
	else
	begin
		if exists(select 1 from iss_CycleDate where IssNo=@IssNo and
			CycNo= @CycNo and CycMth = @CycMth)
			return 65051 --Cycle control detail already exists 
		
		Insert into iss_CycleDate (IssNo, CycNo, CycMth, StmtDate, DueDate, DueDay, GracePeriod)
		select @IssNo, @CycNo, @CycMth, @StmtDate, @DueDate, @DueDay, @GracePeriod

		if @@rowcount = 0
		begin
			return 70440
		end

		return 50305
	end

	Set nocount off
*/
end
GO
