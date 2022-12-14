USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[IssuerMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2001/11/27 Sam			   Initial development
2003/06/25 Aeris		   Add VAT rate field
2004/07/21 Alex			   Add LastUpdDate
2005/09/27 Chew Pei			Comment LastUpdDate changed by Alex
*******************************************************************************/
	
CREATE procedure [dbo].[IssuerMaint]
	@IssNo uIssNo,
	@Name nvarchar(50),
	@ShortName nvarchar(10),
	@CoRegsNo nvarchar(10),
	@ContactPerson nvarchar(50),
	@ContactNo varchar(12),
	@LangId uRefCd,
	@CrryCd uRefCd,
	@CtryCd uRefCd,
	@VATRate money, -- 2003/06/25
	@LastUpdDate varchar(30)

  as
begin
	declare @LatestUpdDate datetime
/*	if not exists (select 1 from iss_User where UserId = 'Jac' and PrivilegeCd = 1)
	begin
		return '90000'
	end */

	if @IssNo = 0
	begin
		return 20017
	end

	if @CoRegsNo is null
	begin
		return 55078	-- VAT Rate is a compulsory field
	end

	if @VATRate is null return 55169

	if @LangId = ''	select @LangId = 'EN' 

	if not exists (select 1 from iss_Issuer where IssNo = @IssNo)
	begin
		insert iss_Issuer (Name, ShortName, CoRegsNo, ContactPerson, ContactNo, LangId, CtryCd, CrryCd, VATRate, LastUpdDate)
		select isnull(@Name,'X'),
			@ShortName,
			upper(@CoRegsNo),
			isnull(@ContactPerson,'X'),
			@ContactNo,
			isnull(@LangId, 'EN'),
			@CtryCd, 
			@CrryCd,
			@VATRate, --2003/06/25
			getdate()
		if @@rowcount = 0
		begin
			return 70003
		end
		return 50004
	end
	else
	begin
--		if @LastUpdDate is null
--			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

--		select @LatestUpdDate = LastUpdDate from iss_Issuer where IssNo = @IssNo and ShortName = @ShortName
--		if @LatestUpdDate is null
--			select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

		-----------------
		begin transaction
		-----------------
	
		-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
		-- it means that record has been updated by someone else, and screen need to be refreshed
		-- before the next update.
--		if @LatestUpdDate = convert(datetime, @LastUpdDate)
--		begin
			update a
			set a.Name = isnull(@Name, 'X'),
				ShortName = @ShortName,
				CoRegsNo = upper(@CoRegsNo),
				ContactPerson = @ContactPerson,
				ContactNo = @ContactNo,
				LangId = isnull(@LangId, 'EN'),
				CrryCd = @CrryCd,
				CtryCd = @CtryCd,
				VATRate = @VATRate, --2003/06/25
				LastUpdDate = getdate()
			from iss_Issuer a
			where a.IssNo = @IssNo
			if @@rowcount = 0
			begin
				return 70004
			end
--		end
--		else
--		begin
--			rollback transaction
--			return 95307
--		end

		------------------
		commit transaction
		------------------
		return 50005
	end
end
GO
