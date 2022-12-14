USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CostCentreDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Cost Centre deletion.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/11/19 Jac			   Initial development
2005/03/29 Alex			   Add checking when delete costcentre
*******************************************************************************/
	
CREATE procedure [dbo].[CostCentreDelete]
	@IssNo smallint,	
	@ApplId uApplId,
	@AcctNo uAcctNo,
	@CostCentre uCostCentre
   as
begin
	declare @CostCentreId varchar(19)

	select @CostCentreId = CostCentreId from iaa_CostCentre where IssNo=IssNo
	       and CostCentre = @CostCentre and (AcctNo = @AcctNo or ApplId=@ApplId )

	if @AcctNo is null and @ApplId is null return 95252 -- Incomplete information for retrieving recordset 
	if @CostCentre is null return 55142	-- Cost Centre is a compulsory field

	--Alex 2005/03/29. 
	if exists (select 1 from iac_Event where CostCentreId =@CostCentreId and Sts ='A') return  95000 -- Unable to delete record because data is being used
	--Alex End


	if @AcctNo is not null
	begin
		if not exists (select 1 from iaa_CostCentre where IssNo = @IssNo
			and AcctNo = @AcctNo and CostCentre = @CostCentre)
			return 60060	-- Cost Centre not found
		
		BEGIN TRANSACTION

		delete iaa_CostCentre
		where IssNo = @IssNo and AcctNo = @AcctNo and CostCentre = @CostCentre
		if @@error <> 0
		begin
			ROLLBACK TRANSACTION
			return 70383	-- Failed to delete Cost Centre
		end
		
		
		delete iaa_CostCentreVelocityLimit
		where IssNo = @IssNo and AcctNo = @AcctNo and CostCentre = @CostCentre
		if @@error <> 0
		begin
			ROLLBACK TRANSACTION
			return 70383	-- Failed to delete Cost Centre
		end

		
		delete iss_Address
		where IssNo = @IssNo and RefKey = @CostCentreId and RefTo='ACCTCOSTC'
		if @@error <> 0
		begin
			ROLLBACK TRANSACTION
			return 70383	-- Failed to delete Cost Centre
		end

		delete iss_Contact
		where IssNo = @IssNo and RefKey = @CostCentreId and RefTo='ACCTCOSTC'
		if @@error <> 0
		begin
			ROLLBACK TRANSACTION
			return 70383	-- Failed to delete Cost Centre
		end
		
		COMMIT TRANSACTION
		return 50253	-- Cost Centre has been deleted successfully
	end
	else
	begin
		if not exists (select 1 from iaa_CostCentre where IssNo = @IssNo
			and ApplId = @ApplId and CostCentre = @CostCentre)
			return 60060	-- Cost Centre not found

		BEGIN TRANSACTION

		delete iaa_CostCentre
		where IssNo = @IssNo and ApplId = @ApplId and CostCentre = @CostCentre

		if @@error <> 0
		begin
			ROLLBACK TRANSACTION
			return 70383	-- Failed to delete Cost Centre
		end

		delete iaa_CostCentreVelocityLimit
		where IssNo = @IssNo and ApplId = @ApplId and CostCentre = @CostCentre
		if @@error <> 0
		begin
			ROLLBACK TRANSACTION
			return 70383	-- Failed to delete Cost Centre
		end

		delete iss_Contact
		where IssNo = @IssNo and RefKey = @CostCentreId and RefTo='APPLCOSTC'
		if @@error <> 0
		begin
			ROLLBACK TRANSACTION
			return 70383	-- Failed to delete Cost Centre
		end
		
		delete iss_Address
		where IssNo = @IssNo and RefKey = @CostCentreId and RefTo='APPLCOSTC'

		if @@error <> 0
		begin
			ROLLBACK TRANSACTION
			return 70383	-- Failed to delete Cost Centre
		end
		
		COMMIT TRANSACTION
		return 50253	-- Cost Centre has been deleted successfully
	end

	

end
GO
