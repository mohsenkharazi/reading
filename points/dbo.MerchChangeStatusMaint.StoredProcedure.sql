USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchChangeStatusMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Change an account or business location status.
-------------------------------------------------------------------------------
When	   Who		CRN	    Description
-------------------------------------------------------------------------------
2002/07/08 Sam			    Initial development
2003/08/12 Sam				Disable condition.
*******************************************************************************/

CREATE procedure [dbo].[MerchChangeStatusMaint]
	@AcqNo uAcqNo,
	@AcctNo uAcctNo,
	@BusnLocation uMerch,
	@ChgSts uRefCd,
	@ReasonCd uRefCd,
	@Narrative nvarchar(150)
  as
begin
	declare @CancelDate datetime, @ActiveSts uRefCd, @EventTypeChangeSts uRefCd

	if @ChgSts is null return 55092

	select @CancelDate = getdate() from acq_Default where AcqNo = @AcqNo and Deft = 'CancelSts' and VarcharVal = @ChgSts

	select @ActiveSts = RefCd from iss_RefLib where IssNo = @AcqNo and RefType = 'MerchAcctSts' and RefInd = 0
	
	select @EventTypeChangeSts = VarcharVal from iss_default where Deft = 'EventTypeChangeSts'

	if @ChgSts <> @ActiveSts and @ReasonCd is null return 55055 --Reason Code is a compulsory field

	--if business location is null means changes on account status.
	if @BusnLocation is null
	begin
		update aac_Account
		set Sts = @ChgSts,
			ReasonCd = @ReasonCd,
			CancelDate = @CancelDate
		where AcctNo = @AcctNo and Sts <> @ChgSts

		if @@rowcount = 0 or @@error <> 0 return 70235
		return 50218	--Merchant Status has been updated successfully

		--2003/08/12B
/*		update aac_BusnLocation
		set Sts = @ChgSts
		where AcctNo = @AcctNo
		return 50217 */
		--2003/08/12E
	end

	if @ChgSts <> @ActiveSts
	begin
		if exists (select 1 from aac_BusnLocation a join iss_RefLib b on a.AcqNo = b.IssNo and a.Sts = b.RefCd and b.RefType = 'MerchAcctSts' and RefInd <> 0 where BusnLocation = @BusnLocation)
			return 95132 --Check Business Location status
	end

	update aac_BusnLocation
	set Sts = @ChgSts,
		ReasonCd = @ReasonCd,
		CancelDate = @CancelDate
	where BusnLocation = @BusnLocation and Sts <> @ChgSts

	if @@rowcount = 0 or @@error <> 0 return 70234
	
	--Create Event Narrative
	insert aac_Event(AcqNo, EventType, Dept, AcctNo, BusnLocation, ReasonCd, Priority, Descp, 
		CreationDate, CreatedBy, AssignTo, ClsDate, XrefDoc, ActiveSts, Sts, LastUpdDate)
	select @AcqNo, @EventTypeChangeSts, null, @AcctNo, @BusnLocation, @ReasonCd, 'L', @Narrative,
		getdate(), system_user, null, null, null, null, 'C', getdate() 
	
	return 50218
end
GO
