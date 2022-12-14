USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchEventMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Business Location event maintenance.
-------------------------------------------------------------------------------
When	   Who		CRN	    Description
-------------------------------------------------------------------------------
2002/07/15 Sam			    Initial development
2003/08/21 Sam				To enable event capturing for merchant account.
*******************************************************************************/

CREATE procedure [dbo].[MerchEventMaint]
	@Func varchar(5),
	@AcqNo uAcqNo,
	@EventId int,
	@EventType uRefCd,
	@AcctNo uAcctNo,
	@BusnLocation uMerch,
	@ReasonCd uRefCd,
	@Descp nvarchar(150),
	@Priority uRefCd,
	@AssignTo uUserId,
	@XRefDoc nvarchar(30),
	@SysInd char(1), 
	@Sts uRefCd 
  as
begin
	declare	@CreationDate datetime,	@ClsDate datetime,
		@EventInd tinyint, @OrigEventInd tinyint, @SysDate datetime

	if @EventType is null return 55080
	if @Descp is null return 55017
	if @Priority is null return 55081
	if @AssignTo is null return 55082
	if @ReasonCd is null return 55055	--Reason Code is a compulsory field

	select @SysDate = getdate()

	if @Func = 'Add'
	begin
		select @Sts = VarcharVal from acq_Default where AcqNo = @AcqNo and Deft = 'ActiveSts'

		insert into aac_Event (AcqNo, EventType, AcctNo, BusnLocation, ReasonCd, Descp, 
			Priority, CreatedBy, AssignTo, XRefDoc, CreationDate, Sts)
		values (@AcqNo, @EventType, @AcctNo, @BusnLocation, @ReasonCd, @Descp,
			@Priority, system_user, isnull(@AssignTo, system_user), @XRefDoc, @SysDate, @Sts)

		if @@rowcount = 0 or @@error <> 0 return 70238
		return 50068
	end

	select @ClsDate = @SysDate from acq_Default where AcqNo = @AcqNo and Deft = 'CloseSts' and VarcharVal = @Sts

	if not exists (select 1 from aac_EventDetail where EventId = @EventId and convert(char(8), CreationDate, 112) = convert(char(8), @SysDate, 112) and isdate(@ClsDate) = 1) return 95153

	update aac_Event
	set --ReasonCd = @ReasonCd,
		--Descp = @Descp,
		--Priority = @Priority,
		--AssignTo = isnull(@AssignTo, system_user),
		--XRefDoc = @XRefDoc,
		Sts = @Sts,
		LastUpdDate = @SysDate,
		ClsDate = @ClsDate
	where EventId = @EventId and Sts = (select VarcharVal from acq_Default where AcqNo = @AcqNo and Deft = 'ActiveSts')

	if @@rowcount = 0 or @@error <> 0 return 70239
	return 50069
end
GO
