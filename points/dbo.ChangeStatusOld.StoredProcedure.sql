USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ChangeStatusOld]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	:To change the Account or Card status. 
-------------------------------------------------------------------------------
When	   Who		CRN	    Description
-------------------------------------------------------------------------------
2002/01/28 Wendy		    Initial development
2002/02/07 Wendy		    Adding SysInd and changing event type	
2002/02/22 Wendy 		    Adding narrative into iac_EventDetail
2005/09/26 Chew Pei			Delete all status severity validation
2009/08/20 Chew Pei			Make use of WriteOffDate to put the Closed Date when account is closed.
*******************************************************************************/

CREATE procedure [dbo].[ChangeStatusOld]
	@IssNo uIssNo,
	@AcctNo uAcctNo,
	@CardNo varchar(19),
	@EventDescp nvarchar(80),
	@Sts uRefCd, 
	@ReasonCd uRefCd,
	@Narrative nvarchar(400)
   as
begin
	declare	@EventId int,
		@EventType nvarchar(50),
		@Priority char(1),
		@SysInd char(1),
		@CurrSts char(1),
		@NewCardSts char(1),
		@StsInd tinyint,
		@ActivationDate datetime

	select @EventType=VarcharVal from iss_default where Deft='EventTypeChangeSts'
	select @SysInd = 'Y'
	select @Priority = 'L'

 	if @Sts is null return 55092
	if @ReasonCd is null return 55055

	-----------------
	BEGIN TRANSACTION
	-----------------

	if @AcctNo is not null
	begin
		if not exists (select 1 from iac_Account where IssNo = @IssNo and AcctNo = @AcctNo)
		begin
			rollback transaction
			return 60000	-- Account not found
		end

		-- [B]CP 20090820 -- if account status is closed, put the closed date in writeoffdate field

--		update iac_Account set Sts = @Sts where IssNo = @IssNo and AcctNo = @AcctNo
		update a
		set Sts = @Sts, WriteOffDate = case when b.RefInd = 3 then getdate() end
		from iac_Account a
		join iss_Reflib b on b.RefType = 'AcctSts' and b.RefCd = @Sts and b.IssNo = @IssNo
		where a.AcctNo = @AcctNo

		-- [E]20090820 

		if @@error <> 0
		begin
			rollback transaction
			return 70124	-- Failed to update account
		end
	end

	if @CardNo is not null
	begin
		select @NewCardSts = VarcharVal from iss_Default where IssNo = @IssNo and Deft = 'NewCardSts'

		select @AcctNo = a.AcctNo, @CurrSts = a.Sts
		from iac_Card a
		where a.IssNo = @IssNo and a.CardNo = @CardNo

		if @@rowcount = 0 or @@error <> 0
		begin
			rollback transaction
			return 60003	-- Card not found
		end

		select * from iss_reflib where reftype ='CardSts'

		select @StsInd = RefInd from iss_RefLib
		where IssNo = @IssNo and RefType = 'CardSts' and RefCd = @Sts

		-- Only when Status P change to Status A, set the ActivationDate
		if isnull(@NewCardSts, 'P') = @CurrSts and @StsInd = 0
		begin
				select @ActivationDate = getdate()
		end
		
		update iac_Card set ActivationDate = isnull(@ActivationDate,ActivationDate) , Sts = @Sts
		where IssNo = @IssNo and CardNo=convert(bigint,@CardNo)

		if @@rowcount = 0
		begin	
			rollback transaction
			return 70132	-- Failed to update card
		end
	end

	insert into iac_Event (IssNo, EventType, AcctNo, CardNo, ReasonCd, Descp, 
		Priority, CreatedBy, AssignTo, XRefDoc, CreationDate, SysInd, Sts)
	values (@IssNo, isnull(@EventType,'ChgSts'), @AcctNo, convert(bigint,@CardNo), @ReasonCd, @EventDescp,
		@Priority, system_user, null, null, getdate(), @SysInd, 'C')

	if @@error <> 0
	begin
		rollback transaction
		return 70194	-- Failed to create event
	end

	select @EventId = @@identity

	if (@Narrative is not null)
	begin
		insert into iac_EventDetail (EventId, Seq, Descp, CreationDate, CreatedBy)
		values (@EventId, 1, @Narrative, getdate(), system_user)

		if @@error <> 0
		begin
			rollback transaction
			return 70194	-- Failed to create event
		end
	end

	------------------
	COMMIT TRANSACTION
	------------------

	if @CardNo is not null return 50101	-- Changed successfully

	return 50099	-- Changed successfully
end
GO
