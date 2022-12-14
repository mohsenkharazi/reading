USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[EventMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To insert new or update existing events.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/01/14 Wendy		   Initial development
2004/12/17 Alex				Added Cost Centre Id
2004/12/24 Chew Pei			Added parameter : Recall Date
2004/12/26 Alex				Added Recall Date.
*******************************************************************************/
	
CREATE procedure [dbo].[EventMaint]
	@Func varchar(5),
	@IssNo uIssNo,
	@EventId uEventId,
	@EventType uRefCd,
	@AcctNo uAcctNo,
	@CardNo varchar(19),
	@CostCentreId uTxnId,
	@ReasonCd uRefCd,
	@Descp nvarchar(120),
	@Priority uRefCd,
	@AssignTo uUserId,
	@RecallDate datetime,
	@XRefDoc nvarchar(15),
	@SysInd char(1), 
	@Sts char(1)
	
  as
begin
	declare	@CreationDate datetime,
		@ClsDate datetime,
		@EventInd tinyint,
		@OrigEventInd tinyint

	if @EventType is null return 55080
	if @Descp is null return 55017

	if @AcctNo is null /*for application create event use, by Alex 200503/21 */
	begin
		select @AcctNo=0
	end
--	if @Priority is null return 55081
--	if @AssignTo is null return 55082


	if @Func = 'Add'	
	begin
		select @Sts = 'A'

		insert into iac_Event (IssNo, EventType, AcctNo, CardNo, CostCentreId, ReasonCd, Descp, 
			Priority, CreatedBy, AssignTo, XRefDoc, CreationDate, RecallDate, SysInd, Sts )
		values (@IssNo, @EventType, @AcctNo, convert(bigint, @CardNo), @CostCentreId, @ReasonCd, @Descp,
			@Priority, system_user, @AssignTo, @XRefDoc, getdate(), @Recalldate, @SysInd, @Sts )

		if @@error <> 0 return 70194	-- Failed to create event

		return 50068	-- Successfully added
	end

	if @Func = 'Save'	
	begin
		select @EventInd = RefInd
		from iss_RefLib
		where IssNo = @IssNo and RefType = 'EventSts' and RefCd = @Sts

		select @OrigEventInd = b.RefInd
		from iac_Event a, iss_RefLib b
		where a.EventId = @EventId and b.IssNo = @IssNo
		and b.RefType = 'EventSts' and b.RefCd = a.Sts

		if @@rowcount = 0 return 60030	-- Event not found

		update iac_Event
		set	EventType=@EventType, ReasonCd = @ReasonCd,
			Descp= @Descp, Priority=@Priority,RecallDate = @RecallDate,
			AssignTo=@AssignTo, XRefDoc=@XRefDoc,
			ClsDate=case when @EventInd = 2 and @OrigEventInd <> 2 then getdate() 
						 when @EventInd <> 2 then null else ClsDate 
					end, 
			Sts=@Sts
		where EventId=@EventId 

		if @@error <> 0 return 70195	-- Failed to update event

		return 50069	-- Successfully updated
	end
end
GO
