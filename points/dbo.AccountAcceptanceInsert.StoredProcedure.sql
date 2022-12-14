USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AccountAcceptanceInsert]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	:Add new Business Location Acceptance to a account.

-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2002/01/24 	Jacky			Initial development

2003/06/20	KY				Add arguement - IssNo 

*******************************************************************************/

CREATE procedure [dbo].[AccountAcceptanceInsert]
	@IssNo uIssNo,
	@AcctNo uAcctNo,
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
		return 60000	-- Account not found

	select @PrcsName = 'AccountAcceptanceInsert'

	exec TraceProcess @IssNo, @PrcsName, 'Start'

	begin transaction

	insert iac_AccountAcceptance (IssNo, AcctNo, BusnLocation, Sts)
	select @IssNo, @AcctNo, @BusnLocation, 'A'

	if @@rowcount = 0
	begin
		rollback transaction
		return 70143	-- Failed to insert
	end

	select @Msg = 'New Business Location Acceptance has been added - '+cast(@BusnLocation as varchar(19))
	insert iac_Event (EventType, AcctNo, Descp, Priority, IssNo, CreationDate, CreatedBy, ClsDate, SysInd, Sts)
	select	@EventType, @AcctNo, @Msg, 'L', @IssNo, getdate(), system_user, null, 'Y', 'A'

	if @@error != 0 or @@rowcount = 0
	begin
		rollback transaction
		return 70143	-- Failed to insert
	end

	commit transaction

	return 50115	-- Added successful
end
GO
