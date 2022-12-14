USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CycleControlDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To delete existing Cycle Control Number.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2001/12/21 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[CycleControlDelete]
	@IssNo uIssNo,
	@CycNo uCycNo
   as
begin
	declare @PrcsName varchar(50)

	if not exists (select 1 from iss_CycleControl where IssNo = @IssNo and CycNo = @CycNo)
		return 60055	-- Cycle Control Number not found

	BEGIN TRANSACTION

	delete iss_PlasticTypeCycle
	where IssNo = @IssNo and CycNo = @CycNo

	if @@error <> 0
	begin
		rollback transaction
		return 70350	-- Failed to delete Cycle Control Number
	end

	delete iss_CycleControl
	where IssNo = @IssNo and CycNo = @CycNo

	if @@error <> 0
	begin
		rollback transaction
		return 70350	-- Failed to delete Cycle Control Number
	end

	COMMIT TRANSACTION

	return 50232	-- Cycle Control Number deleted successfully
end
GO
