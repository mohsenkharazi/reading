USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AddressMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: To insert new or update  existing address.

-------------------------------------------------------------------------------
When		Who		CRN	Description
-------------------------------------------------------------------------------
2002/01/21	Wendy		   	Initial development

2003/06/20	KY		1103003	Validation check.
							Mailing Indicator checking.
2003/07/11	Chew Pei		Added Mailing Ind Event Log
2009/03/29	Barnett			Add City
2009/04/03	Chew Pei		Added zip cd validation, check length
2015/01/08	Humairah		Change datatype for Parameter @Street1 from uStreet to varchar(100): to avoid error in CCMS
*******************************************************************************/

CREATE procedure [dbo].[AddressMaint]
	@Func varchar(5),
	@IssNo uIssNo,
	@RefTo uRefCd,
	@RefKey varchar(19),
	@RefCd uRefCd,
	@Street1 varchar(100),                                                                                                  --Humairah 8 Jan 2015
	@Street2 uStreet,
	@Street3 uStreet,
	@City nVarchar(100),
	@State uRefCd,
	@ZipCd uZipCd,
	@Ctry uRefCd,
	@MailInd char(1),
	@LastUpdDate varchar(30)
  as
begin
	declare	@RefType uRefType,
		@SPName varchar(40),
		@ValidateResult varchar(40),
		@Count int,
		@EventType nvarchar(50),
		@Priority char(1),
		@OldRefCd uRefCd,
		@OldAddressType uDescp50,
		@NewAddressType uDescp50,
		@EventDescp nvarchar(80),
		@LatestUpdDate datetime
	
	select @RefType = 'ADDRESS'

	if isnull(@Street1,'') ='' return 55083 -- Address 1 is a compulsory field
--	if isnull(@Street2,'') ='' return 55237	-- Address 2 is a compulsory field

	if len(@ZipCd) <> 5
		return 95454 -- Invalid Post Code Length

	-- CP: 2003/07/11[B]
	select @EventType=VarcharVal from iss_default where Deft='EventTypeChangeMailInd'
	select @Priority = 'L'
	-- CP: 2003/07/11[E]

	-- Address Validation --
	if isnull(@IssNo,0) = 0
	return 0	--Mandatory Field IssNo

	select @SPName = StoredProcName
	from iss_Functions
	where FuncName = 'ValidateAddress' and FuncType = 'P'

	exec @SPName @RefTo, @RefKey, @RefCd, @Street1, @ZipCd,	@Ctry, @ValidateResult output

	if @@error <> 0 or @ValidateResult <> 0
		return @ValidateResult

	if not exists (select 1 from iss_Address where IssNo = @IssNo and RefTo = @RefTo and RefKey = @RefKey and RefType = @RefType and RefCd <> @RefCd and MailingInd = 'Y')
		and exists (select 1 from iss_RefLib where IssNo = @IssNo and RefType = @RefType and RefCd = @RefCd and RefInd > 0)
		and @MailInd <> 'Y'
		return 95256  -- At least one Mailing Indicator to be fill up	

	-- Add address to table --
	if @Func = 'Add'
	begin
		if exists (select 1 from iss_Address where IssNo = @IssNo and RefKey = @RefKey and RefCd = @RefCd and RefTo = @RefTo)
			return 65049 	-- Address already exists

		-----------------
		begin transaction
		-----------------
		
		if @MailInd = 'Y'
		begin
			if exists (select 1 from iss_RefLib where IssNo = @IssNo and RefType = @RefType and RefCd = @RefCd and RefInd > 0)
			begin
				update a
				set a.MailingInd = 'N'
				from iss_Address a, iss_RefLib b
				where a.IssNo = @IssNo and a.RefKey = @RefKey and b.IssNo = a.IssNo and b.RefType = a.RefType and b.RefCd = a.RefCd and b.RefInd > 0

				if @@error <> 0
				begin
					rollback transaction
					return 70176	-- Failed to create Address
				end
			end
		end


		insert into iss_Address (IssNo, RefTo, RefKey, RefType, RefCd, Street1, Street2, Street3, State, ZipCd, Ctry, MailingInd, City, LastUpdDate)
		values	(@IssNo, @RefTo, @RefKey, @RefType, @RefCd, @Street1, @Street2, @Street3, @State, @ZipCd, @Ctry, @MailInd, @City, getdate())

		if @@error <> 0	
		begin
			rollback transaction
			return 70176	-- Failed to create Address
		end
		------------------
		commit transaction
		------------------

		return 50073	-- Address has been inserted successfully
	end

	-- update address to table --
	if @Func = 'Save'
	begin
		if not exists (select 1 from iss_Address where IssNo = @IssNo and RefKey = @RefKey and RefCd = @RefCd and RefTo = @RefTo)
		return 60026	-- Address not found

		-----------------
		begin transaction
		-----------------
	
		if @MailInd = 'Y'
		begin
			-- CP: 2003/07/11 [B] Create Event
			select @OldRefCd = RefCd
			from iss_Address 
			where IssNo = @IssNo and RefTo = @RefTo and RefKey = @RefKey and MailingInd = 'Y'

			if isnull(@OldRefCd,'') <> ''
			begin
				select @OldAddressType  = Descp
				from iss_RefLib
				where IssNo = @IssNo and RefType = 'Address' and RefCd = @OldRefCd

				select @NewAddressType = Descp
				from iss_RefLib
				where IssNo = @IssNo and RefType = 'Address' and RefCd = @RefCd

				select @EventDescp = 'MailingInd changed from ' + @OldAddressType + ' to ' + @NewAddressType

				insert into iac_Event 
				(IssNo, EventType, AcctNo, CardNo, ReasonCd, Descp, 
				Priority, CreatedBy, AssignTo, XRefDoc, CreationDate, SysInd, Sts)
				values 
				(@IssNo, isnull(@EventType,'ChgMailInd'), @RefKey, null, null, @EventDescp, 
				@Priority, system_user, null, null, getdate(), null, 'C')
		
				if @@error <> 0
				begin
					rollback transaction
					return 70194	-- Failed to create event
				end
			end
			-- CP: 2003/07/11 [E] End Create Event

			if exists (select 1 from iss_RefLib where IssNo = @IssNo and RefType = @RefType and RefCd = @RefCd and RefInd > 0)
			begin
				update a
				set a.MailingInd = 'N'
				from iss_Address a, iss_RefLib b
				where a.IssNo = @IssNo and a.RefKey = @RefKey and b.IssNo = a.IssNo and b.RefType = a.RefType and b.RefCd = a.RefCd and b.RefInd > 0

				if @@error <> 0
				begin
					rollback transaction
					return 70148	-- Failed to update Address
				end	
			end
		end

		if @LastUpdDate is null
			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

		select @LatestUpdDate = LastUpdDate from iss_Address where IssNo = @IssNo and RefTo = @RefTo and RefKey = @RefKey and RefCd = @RefCd

		if @LatestUpdDate is null
			select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

		-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
		-- it means that record has been updated by someone else, and screen need to be refreshed
		-- before the next update.
		if @LatestUpdDate = convert(datetime, @LastUpdDate)
		begin
			update iss_Address
			set	Street1 = @Street1, 
				Street2 = @Street2, 
				Street3 = @Street3, 
				City = @City,
				State = @State,
				ZipCd = @ZipCd,
				Ctry = @Ctry,
				MailingInd = @MailInd,
				LastUpdDate = getdate()
			where IssNo = @IssNo and RefTo = @RefTo and RefKey = @RefKey and RefCd = @RefCd

			if @@error <> 0
			begin
				rollback transaction
				return 70148	-- Failed to update Address
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
		return 50072	-- Address has been updated successfully
	end

end
GO
