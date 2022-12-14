USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardTypeDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To delete existing Card Type.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2003/06/13 Aeris		   Initial development.
2009/02/15 Sam				Minor changes.
*******************************************************************************/

CREATE procedure [dbo].[CardTypeDelete]
	@CardLogo uCardLogo,
	@CardType uCardType
	
   as
begin
	Set nocount on

	if exists (select 1 from iac_Card where CardLogo = @CardLogo and CardType = @CardType)
		return 95000

	delete iss_CardType
	where CardLogo = @CardLogo and CardType = @CardType

	if @@error <> 0 
		return 70429

	return 50294
end
GO
