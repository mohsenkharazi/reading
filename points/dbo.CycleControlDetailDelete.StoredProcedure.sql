USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CycleControlDetailDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Delete cycle control detail.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/27 Aeris		   Initial development
*******************************************************************************/
CREATE procedure [dbo].[CycleControlDetailDelete]
	@IssNo uIssNo,
	@CycNo uCycNo,
	@CycMth smallint,
	@CycDate Datetime,
	@DueDate Datetime,
	@DueDay smallint,
	@GracePeriod smallint
   as
begin
	Set nocount on
					
		delete iss_CycleDate
		where CycNo= @CycNo and IssNo = @IssNo and CycMth = @CycMth

		if @@rowcount = 0
		begin
			return 70443
		end

		return 50306

	Set nocount off
end
GO
