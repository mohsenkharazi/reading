USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AddressDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
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
2002/01/21 	Wendy		   	Initial development

2002/02/05 	CK				Changes to accomodate insert of Corporate Contact

2003/06/20	KY		1103003	Validation checking

2003/07/24	KY				Create event

*******************************************************************************/

CREATE procedure [dbo].[AddressDelete]
	@IssNo uIssNo,
	@RefKey varchar(19),
	@RefCd uRefCd,
	@RefTo uRefCd	-- Require front-end to pass in this value
  as
begin
	declare @ValidateResult varchar(40),
		@Count int,
		@EventType nvarchar(50),
		@Priority char(1),
		@NewRefCd uRefCd,
		@OldAddressType uDescp50,
		@NewAddressType uDescp50,
		@EventDescp nvarchar(80)
	
	select @EventType=VarcharVal from iss_default where Deft='EventTypeChangeMailInd'
	select @Priority = 'L'

	-- Validation Check
	if isnull(@IssNo,0) = 0
	return 0	--Mandatory Field IssNo

	if isnull(@RefTo,'') = ''
	return 0	--Mandatory Field RefTo

	if isnull(@RefKey,'') = ''
	return 0	--Mandatory Field RefKey

	if isnull(@RefCd,'') = ''
	return 0	--Mandatory Field RefCd

	if not exists (select 1 from iss_Address where IssNo = @IssNo and RefKey = @RefKey and RefCd = @RefCd and RefTo = @RefTo)
	return 60026	-- Address not found
	
	-- validate the (deleting address) mailing indicator --
	-- if mailing indicator is 'Y', system will run through the if condition code --
	-- if mailing indicator is 'N', system will run through the else condition code --
	if exists (select 1 from iss_Address where IssNo = @IssNo and RefKey = @RefKey and RefCd = @RefCd and RefTo = @RefTo and MailingInd = 'Y')
	begin
		-- ensure at least two address is exists for the company group
		if exists (select 1 from iss_Address a, iss_RefLib b where a.IssNo = @IssNo and a.RefTo = @RefTo and a.RefKey = @RefKey and a.RefCd <> @RefCd and b.IssNo = a.IssNo and b.RefType = 'Address' and (b.RefNo & 1) > 0 and b.RefInd > 0 and a.RefCd = b.RefCd)
		begin
			-- START: Create Event
			select @NewRefCd = a.RefCd
			from iss_Address a, iss_RefLib b
			where a.IssNo = @IssNo and a.RefTo = @RefTo and a.RefKey = @RefKey and a.RefCd <> @RefCd and 
			b.IssNo = a.IssNo and b.RefType = 'Address' and (b.RefNo & 1) > 0 and b.RefInd > 0 and a.RefCd = b.RefCd
			
			if isnull(@NewRefCd,'') <> ''
			begin
				select @OldAddressType  = Descp
				from iss_RefLib
				where IssNo = @IssNo and RefType = 'Address' and RefCd = @RefCd

				select @NewAddressType = Descp
				from iss_RefLib
				where IssNo = @IssNo and RefType = 'Address' and RefCd = @NewRefCd

				select @EventDescp = 'Mailing Ind changed from ' + @OldAddressType + ' to ' + @NewAddressType

				-----------------
				begin transaction
				-----------------
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
				------------------
				commit transaction
				------------------
			end
			-- END: Create Event
			
			-----------------
			begin transaction
			-----------------
			-- delete address
			delete iss_Address
			where IssNo = @IssNo and RefKey = @RefKey and RefCd = @RefCd and RefTo = @RefTo
	
			if @@error <> 0	
			begin
				rollback transaction
				return 70149	-- Failed to delete Address
			end

			-- update other company group address mailing indicator to 'Y' 
			update a
			set a.MailingInd = 'Y'
			from iss_Address a, iss_RefLib b
			where a.IssNo = @IssNo and a.RefTo = @RefTo and a.RefKey = @RefKey and b.IssNo = a.IssNo and b.RefType = a.RefType and (b.RefNo & 1) > 0 and b.RefInd > 0 and b.RefCd = a.RefCd
			
			if @@error <> 0
			begin
				rollback transaction
				return	70148	-- Failed to update Address
			end

			------------------
			commit transaction
			------------------
			return 50074	-- Address has been deleted successfully
		end
		else 	-- to prevent delete all the company group address
		begin
			return 95256  -- At least one Mailing Indicator to be fill up
		end
	end
	else 	-- Mailing Indicator = 'N'
	begin
		-----------------
		begin transaction
		-----------------
		delete iss_Address
		where IssNo = @IssNo and RefKey = @RefKey and RefCd = @RefCd and RefTo = @RefTo
	
		if @@error <> 0	
		begin
			rollback transaction
			return 70149	-- Failed to delete Address
		end
		------------------
		commit transaction
		------------------
		return 50074	-- Address has been deleted successfully
	end

end
GO
