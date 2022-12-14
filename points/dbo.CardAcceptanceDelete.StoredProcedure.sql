USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardAcceptanceDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	:Remove Business Location from the Card Acceptant List
-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2002/02/21	Jacky			Initial development

2003/06/20	KY				Add arguement -- IssNo
*******************************************************************************/
	
CREATE procedure [dbo].[CardAcceptanceDelete]
	@IssNo uIssNo,
	@CardNo varchar(19),
	@BusnLocation uMerch
   as
begin
	declare @PrcsName varchar(50),		
			@AcctNo uAcctNo,
			@Msg nvarchar(80),
			@EventType uRefCd

	select @EventType = VarcharVal
	from iss_Default
	where Deft = 'EventTypeAcctAccptance'

	select @AcctNo = b.AcctNo
	from iac_Card a, iac_Account b
	where a.IssNo = @IssNo and b.IssNo = a.IssNo and a.CardNo = @CardNo and b.AcctNo = a.AcctNo

	if @@rowcount = 0 return 60003	-- Account not found

	select @PrcsName = 'CardAcceptanceDelete'

	exec TraceProcess @IssNo, @PrcsName, 'Start'

	begin transaction

	delete iac_CardAcceptance
	where IssNo = @IssNo and CardNo = @CardNo and BusnLocation = @BusnLocation

	if @@rowcount = 0
	begin
		rollback transaction
		return 70151	-- Failed to delete
	end

	select @Msg = 'Business Location Acceptance has been removed - '+cast(@BusnLocation as varchar(19))
	insert iac_Event (EventType, AcctNo, CardNo, Descp, Priority, IssNo, CreationDate, CreatedBy, ClsDate, SysInd, Sts)
	select	@EventType, @AcctNo, @CardNo, @Msg, 'L', @IssNo, getdate(), system_user, null, 'Y', 'C'

	if @@error != 0 or @@rowcount = 0
	begin
		rollback transaction
		return 70151	-- Failed to delete
	end

	commit transaction

	return 50117	-- Deleted successful
end
GO
