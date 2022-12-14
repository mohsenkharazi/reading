USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardAcceptanceInsert]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Add new Business Location Acceptance to a card.
-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2002/02/21 	Jacky		   	Initial development

2003/06/20	KY				Add arguement - IssNo

*******************************************************************************/
	
CREATE procedure [dbo].[CardAcceptanceInsert]
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

	if @@rowcount = 0 return 60003	-- Card not found

	select @PrcsName = 'CardAcceptanceInsert'

	exec TraceProcess @IssNo, @PrcsName, 'Start'

	begin transaction

	insert iac_CardAcceptance (IssNo, CardNo, BusnLocation, Sts)
	select @IssNo, @CardNo, @BusnLocation, 'A'

	if @@rowcount = 0
	begin
		rollback transaction
		return 70143	-- Failed to insert
	end

	select @Msg = 'New Business Location Acceptance has been added - '+cast(@BusnLocation as varchar(19))
	insert iac_Event (EventType, AcctNo, CardNo, Descp, Priority, IssNo, CreationDate, CreatedBy, ClsDate, SysInd, Sts)
	select	@EventType, @AcctNo, @CardNo, @Msg, 'L', @IssNo, getdate(), system_user, null, 'Y', 'A'

	if @@error != 0 or @@rowcount = 0
	begin
		rollback transaction
		return 70143	-- Failed to insert
	end

	commit transaction

	return 50115	-- Added successful
end
GO
