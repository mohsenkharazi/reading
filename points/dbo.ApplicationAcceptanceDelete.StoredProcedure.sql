USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ApplicationAcceptanceDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	:Remove Business Location from the Aplication Acceptant List

-------------------------------------------------------------------------------
When		Who		CRN			Description
-------------------------------------------------------------------------------
2003/06/20 	KY		1103003		Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[ApplicationAcceptanceDelete]
	@IssNo uIssNo,
	@ApplId uApplId,
	@BusnLocation uMerch
  as
begin
	declare @PrcsName varchar(50),		
			@Msg nvarchar(80),
			@EventType uRefCd

	select @EventType = VarcharVal
	from iss_Default
	where Deft = 'EventTypeAcctAccptance'

	if @@rowcount = 0 return 60022	-- Application not found

	select @PrcsName = 'ApplicationAcceptanceDelete'

	exec TraceProcess @IssNo, @PrcsName, 'Start'

	begin transaction

	delete iap_ApplicationAcceptance
	where IssNo = @IssNo and ApplId = @ApplId and BusnLocation = @BusnLocation

	if @@rowcount = 0
	begin
		rollback transaction
		return 70143	-- Failed to insert Business Location Acceptance
	end

	commit transaction

	return 50117	-- Business Location Acceptance has been deleted successfully
end
GO
