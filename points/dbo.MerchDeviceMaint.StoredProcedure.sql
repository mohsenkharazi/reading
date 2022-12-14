USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchDeviceMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:Cardtrend Systems Sdn. Bhd.
Modular		:Cardtrend Card Management System (CCMS)- Acquiring Module

Objective	:Terminal/ PinPad/ Printer devices maintenance.
		1. New terminal stated as 'N'
		2. Enable to delete terminal as long as deploydate is null

Called By	:
SP Level	:Primary
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/08/22 Sam			   Initial development
2004/07/08 Chew Pei			Change to standard coding
2004/07/21 Alex				Add LastUpdDate
2005/11/27 Khar Yeong		Validation Terminal Length
*******************************************************************************/

CREATE procedure [dbo].[MerchDeviceMaint]
	@Func varchar(8),
	@AcqNo uAcqNo,
	@TermId uTermId,
	@SerialNo int,
	@DevType uRefCd,
	@ProdType uRefCd,
	@SrcCd uRefCd,
	@ReasonCd uRefCd,
	@Sts uRefCd,
	@Descp uDescp50,
	@LastUpdDate varchar(50)
  as
begin
	declare @NewSts uRefCd, @LatestUpdDate datetime

	set nocount on

	if @TermId is null return 60032
	if @DevType is null return 55120
	if @SrcCd is null return 55006
	if datalength(@TermId) <> 8 return 95336

	if @Func = 'Add'
	begin
		select @NewSts = RefCd from iss_RefLib where IssNo = @AcqNo and RefType = 'TermSts' and RefInd = 0

		if @@rowcount = 0 or @@error <> 0 return 50198

		insert atm_TerminalInventory
			(AcqNo, TermId, ProdType, DeviceType, DeployDate, Sts, BusnLocation, ReasonCd, Descp, SrcCd, UserId, LastUpdDate )
		values ( @AcqNo, @TermId,@ProdType, @DevType, null, @NewSts, 0, null, @Descp, @SrcCd, system_user, getdate())
		
		if @@rowcount = 0 or @@error <> 0 return 70242
		
		return 50198
	end

	if @Func = 'Save'
	begin
		if @LastUpdDate is null
			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 120))
	
		select @LatestUpdDate = convert(datetime, convert(varchar(30), LastUpdDate, 120)) from atm_TerminalInventory where AcqNo = @AcqNo and TermId = @TermId and SerialNo = @SerialNo
		if @LatestUpdDate is null
			select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

	--select  convert(datetime, convert(varchar(30),LastUpdDate, 120)), LastUpdDate from atm_TerminalInventory
	
	--select convert(datetime, convert(varchar(30), LastUpdDate, 120)) from atm_TerminalInventory where AcqNo = @AcqNo and TermId = @TermId
		-----------------
		begin transaction
		-----------------
	
		-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
		-- it means that record has been updated by someone else, and screen need to be refreshed
		-- before the next update.
		if @LatestUpdDate = convert(datetime, @LastUpdDate)
		begin
			update a
			set DeviceType = @DevType,
				ProdType = @ProdType,
				SrcCd = @SrcCd,
				ReasonCd = @ReasonCd,
				Sts = @Sts,
				Descp = @Descp,
				LastUpdDate = getdate()
			from atm_TerminalInventory a
			join iss_RefLib b on a.AcqNo = b.IssNo and a.Sts = b.RefCd and b.RefType = 'TermSts' and RefInd <> 1
			where AcqNo = @AcqNo and TermId = @TermId and SerialNo = @SerialNo

			if @@rowcount = 0 or @@error <> 0 
			begin
				rollback transaction
				return 70243
			end
				
		end
		else
		begin
			rollback transaction
			return 95307
		end
		------------------
		commit transaction
		------------------
		return 50199
	end

/*	if @Func = 'Save'
	begin
		update a
		set SerialNo = @SerialNo,
			DeviceType = @DevType,
			ProdType = @ProdType,
			SrcCd = @SrcCd,
			ReasonCd = @ReasonCd,
			Sts = @Sts,
			Descp = @Descp
		from atm_TerminalInventory a
		join iss_RefLib b on a.AcqNo = b.IssNo and a.Sts = b.RefCd and b.RefType = 'TermSts' and RefInd <> 1
		where AcqNo = @AcqNo and TermId = @TermId

		if @@rowcount = 0 or @@error <> 0 return 70243
		return 50199
	end
	else
		if @Func = 'Add'
		begin
			select @NewSts = RefCd from iss_RefLib where IssNo = @AcqNo and RefType = 'TermSts' and RefInd = 0

			if @@rowcount = 0 or @@error <> 0 return 50198

			insert atm_TerminalInventory
				(AcqNo, TermId, SerialNo, ProdType, DeviceType, DeployDate, Sts, BusnLocation, ReasonCd, Descp, SrcCd, UserId, LastUpdDate)
			values ( @AcqNo, @TermId, @SerialNo, @ProdType, @DevType, null, @NewSts, null, null, @Descp, @SrcCd, system_user, getdate() )
			if @@rowcount = 0 or @@error <> 0 return 70242
			return 50198
		end
*/
	if exists (select 1 from atm_TerminalInventory a join iss_RefLib b on a.AcqNo = b.IssNo and a.Sts = b.RefCd and b.RefType = 'TermSts' and b.RefInd > 0 where TermId = @TermId)
		return 95000

	delete a
	from atm_TerminalInventory a
	join iss_RefLib b on a.AcqNo = b.IssNo and a.Sts = b.RefCd and b.RefType = 'TermSts' and RefInd = 0
	where AcqNo = @AcqNo and TermId = @TermId

	if @@rowcount = 0 or @@error <> 0 return 70244
	return 50200
end
GO
