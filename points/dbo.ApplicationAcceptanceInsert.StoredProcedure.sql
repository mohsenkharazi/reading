USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ApplicationAcceptanceInsert]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	:Add new Business Location Acceptance to a application.

-------------------------------------------------------------------------------
When		Who		CRN	Description
-------------------------------------------------------------------------------
2003/06/20 	KY			Initial development

*******************************************************************************/

CREATE procedure [dbo].[ApplicationAcceptanceInsert]
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

	if @@rowcount = 0
		return 60022	-- Application not found

	select @PrcsName = 'ApplicationAcceptanceInsert'

	exec TraceProcess @IssNo, @PrcsName, 'Start'

	-----------------
	BEGIN TRANSACTION
	-----------------

	insert iap_ApplicationAcceptance (IssNo, ApplId, BusnLocation, Sts)
	select @IssNo, @ApplId, @BusnLocation, 'A'

	if @@rowcount = 0
	begin
		rollback transaction
		return 70143	-- Failed to insert Business Location Acceptance
	end

	------------------
	COMMIT TRANSACTION
	------------------

	return 50115	-- Business Location Acceptance has been created successfully
end
GO
