USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CostCentreDetailMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
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
2004/08/09	Alex		Add Company Name and Trading Name
*******************************************************************************/
	
CREATE procedure [dbo].[CostCentreDetailMaint]
	@IssNo uIssNo,	
	@CmpyName uCmpyName,
	@TradingName uCmpyName,
	@CostCentreId uTxnId,
	@AcctNo uAcctNo,
	@ApplId uApplId

   as
begin

	if @ApplId is null
	begin

		update iaa_CostCentre
		set 	CmpyName = @CmpyName,
			TradingName = @TradingName
		where CostCentreId = @CostCentreId and IssNo = @IssNo and AcctNo = @AcctNo

		if @@error <> 0
		begin
			return 70382	-- Failed to update
		end
			return 50252	-- Update has been created successfully

	end
	else
	begin
		update iaa_CostCentre
		set 	CmpyName = @CmpyName,
			TradingName = @TradingName
		where CostCentreId = @CostCentreId and IssNo = @IssNo and ApplId = @ApplId
		
		if @@error <> 0
		begin
			return 70382	-- Failed to Update
		end
		return 50252	-- Update has been created successfully
	end


end
GO
