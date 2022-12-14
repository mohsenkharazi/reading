USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CostCentreMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Insert or update Cost Centre.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/11/19 Jac			   Initial development
2003/09/23 Chew Pei			Change 55017 to 55133
2004/07/21 Alex				Add The LastUpdDate
*******************************************************************************/
	
CREATE procedure [dbo].[CostCentreMaint]
	@Func varchar(5),
	@IssNo smallint,
	@ApplId uApplId,
	@AcctNo uAcctNo,
	@CostCentre uCostCentre,
	@Descp uDescp50,
	@PersonInCharge nvarchar(50),
	@LastUpdDate varchar(30)
   as
begin
	declare @LatestUpdDate datetime

	if @AcctNo is null and @ApplId is null return 95252 -- Incomplete information for retrieving recordset 

	if @Descp is null return 55062	--Department is a compulsory field
	if @CostCentre is null return 55142	-- Cost Centre is a compulsory field

	if @Func = 'Add'
	begin
		if @AcctNo is not null
		begin
			if exists (select 1 from iaa_CostCentre where IssNo = @IssNo
				and AcctNo = @AcctNo and CostCentre = @CostCentre)
			return 65040	-- Cost Centre already exists
		end
		else
		begin
			if exists (select 1 from iaa_CostCentre where IssNo = @IssNo
				and ApplId = @ApplId and CostCentre = @CostCentre)
			return 65040	-- Cost Centre already exists
		end

		insert iaa_CostCentre (IssNo, ApplId, AcctNo, CostCentre, Descp, PersonInCharge, LastUpdDate )
		select @IssNo, @ApplId, @AcctNo, @CostCentre, @Descp, @PersonInCharge, getdate()

		if @@error <> 0 return 70381	-- Failed to add Cost Centre

		return 50251	-- Cost Centre has been added successfully
	end

	if @Func = 'Save'
	begin
		if @AcctNo is not null
		begin
			if @LastUpdDate is null
				select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))
	
			select @LatestUpdDate = LastUpdDate from iaa_CostCentre where IssNo = @IssNo and AcctNo = @AcctNo and CostCentre = @CostCentre
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
				if not exists (select 1 from iaa_CostCentre where IssNo = @IssNo
					and AcctNo = @AcctNo and CostCentre = @CostCentre)
				return 60060	-- Cost Centre not found

				update iaa_CostCentre
				set Descp = @Descp, 
					PersonInCharge = @PersonInCharge,
					LastUpdDate = getdate()
				where IssNo = @IssNo and AcctNo = @AcctNo and CostCentre = @CostCentre
	
				if @@error <> 0 return 70382	-- Failed to update Cost Centre
			end
			else
			begin
					
				rollback transaction
				return 95307
			end
			------------------
			commit transaction
			------------------
		end
		else
		begin
			if @LastUpdDate is null
				select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))
	
			select @LatestUpdDate = LastUpdDate from iaa_CostCentre where IssNo = @IssNo and ApplId = @ApplId and CostCentre = @CostCentre
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
				if not exists (select 1 from iaa_CostCentre where IssNo = @IssNo
					and ApplId = @ApplId and CostCentre = @CostCentre)
				return 60060	-- Cost Centre not found

				update iaa_CostCentre
				set Descp = @Descp, 
					PersonInCharge = @PersonInCharge,
					LastUpdDate = getdate()
				where IssNo = @IssNo and ApplId = @ApplId and CostCentre = @CostCentre

				if @@error <> 0 return 70382	-- Failed to update Cost Centre
			end
		
		else
		begin
			
			rollback transaction
			return 95307
		end
		------------------
		commit transaction
		------------------
		end
	return 50252	-- Cost Centre has been updated successfully
	end	
end
GO
