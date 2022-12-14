USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AccountTaxReceiptMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: To insert new or update existing tax receipt.

-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2003/07/03	KY			Initial development
2003/08/21	Chew Pei	Changed RcptTaxId to RcptFax
						Commented Province and ZipCd
2004/07/13	Chew Pei	Add LastUpdDate
2004/07/28	Chew Pei	Comment off LastUpdDate
*******************************************************************************/
	
CREATE procedure [dbo].[AccountTaxReceiptMaint]
	@Func varchar(5),
	@IssNo uIssNo,
	@AcctNo uAcctNo,
	@RcptName uCmpyName,
	@Street1 uStreet,
	@Street2 uStreet,
	@Street3 uStreet,
--	@Province uRefCd,
--	@ZipCd uZipCd,
	@RcptTel uContactNo,
	@RcptFax uContactNo--,
--	@RcptTaxId uTaxId
--	@LastUpdDate varchar(30), -- iap_Application..LastUpdDate
--	@LastUpdDate1 varchar(30) -- iss_Address..LastUpdDate
  as
begin
	declare @RefCd uRefCd,
			@Ctry uRefCd,
			@Province uRefCd,
			@ZipCd uZipCd,
			@LatestUpdDate datetime	

	select @RefCd = RefCd from iss_RefLib 
	where IssNo = @IssNo and RefType = 'Address' and (RefNo & 8) > 0

--	select @Ctry = RefCd from iss_RefLib
--	where IssNo = @IssNo and RefType = 'Country' and Descp = 'Thailand'

	if isnull(@IssNo,0) = 0
	return 0	-- Mandatory Field IssNo

	if isnull(@AcctNo,'') = ''
	return 0	-- Mandatory Field AcctNo

	if isnull(@RcptName,'') = ''
	return 55141	-- Name is a compulsory field 

	if isnull(@Street1,'') = ''
	return 55083	-- Address 1 is a compulsory field

--	if isnull(@Province,'') = ''
--	return 55160	-- Province is a compulsory field

--	if isnull(@ZipCd,'') = ''
--	return 55161	-- Postal Code is a compulsory field

	if isnull(@RcptTel,'') = ''
	return 55177	--Telephone Number is a compulsory field

--	if isnull(@RcptTaxId,'') = ''
--	return 55162	-- Tax Id is a compulsory field
	
--	if isnull(@RcptFax,'') = ''
--	return 55178	-- Fax Number is a compulsory field

	if @Func = 'Save'
	begin
		if not exists (select 1 from iap_Application where IssNo = @IssNo and AcctNo = @AcctNo)
		return 60000	-- Account not found

		-----------------
		begin transaction
		-----------------
/*		if @LastUpdDate is null
			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

		select @LatestUpdDate = LastUpdDate from iac_Account 
		where IssNo = @IssNo and AcctNo = @AcctNo 

		if @LatestUpdDate is null
			select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

		-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
		-- it means that record has been updated by someone else, and screen need to be refreshed
		-- before the next update.
		if @LatestUpdDate = convert(datetime, @LastUpdDate)
		begin
*/
			update iac_Account
			set 	RcptName = @RcptName,
					RcptTel = @RcptTel,
					RcptFax = @RcptFax,
					--RcptTaxId = @RcptTaxId
					LastUpdDate = getdate()
			where IssNo = @IssNo and AcctNo = @AcctNo

			if @@error <> 0	
			begin
				rollback transaction
				return 70438	-- Failed to update Application Tax Receipt
			end
/*		end
		else
		begin
			rollback transaction
			return 95307 -- Session Expired
		end
*/
		if not exists (select 1 from iss_Address where IssNo = @IssNo and RefTo = 'ACCT' and RefKey = @AcctNo and RefType = 'ADDRESS' and RefCd = @RefCd)
		begin			
			insert into iss_Address 
			(IssNo, RefTo, RefKey, RefType, RefCd, Street1, Street2, Street3, State, ZipCd, Ctry, LastUpdDate)
			values 
			(@IssNo, 'ACCT', @AcctNo, 'ADDRESS', @RefCd, @Street1, @Street2, @Street3, @Province, @ZipCd, @Ctry, getdate())

			if @@error <> 0	
			begin
				rollback transaction
				return 70438	-- Failed to update Application Tax Receipt
			end
		end 
		else
		begin
/*			if @LastUpdDate1 is null
				select @LastUpdDate1 = isnull(@LastUpdDate1, convert(varchar(30), getdate(), 13))

			select @LatestUpdDate = LastUpdDate from iss_Address
			where IssNo = @IssNo and RefTo = 'ACCT' and RefKey = @AcctNo and RefType = 'ADDRESS' and RefCd = @RefCd

			if @LatestUpdDate is null
				select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

			-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
			-- it means that record has been updated by someone else, and screen need to be refreshed
			-- before the next update.
			if @LatestUpdDate = convert(datetime, @LastUpdDate1)
			begin
*/
				update iss_Address
				set 	Street1 = @Street1,
						Street2 = @Street2,
						Street3 = @Street3,
						State = @Province,
						ZipCd = @ZipCd,
						LastUpdDate = getdate()
				where IssNo = @IssNo and RefTo = 'ACCT' and RefKey = @AcctNo and RefType = 'ADDRESS' and RefCd = @RefCd

				if @@error <> 0	
				begin
					rollback transaction
					return 70438	-- Failed to update Application Tax Receipt
				end
/*			end
			else
			begin
				rollback transaction
				return 95307 -- Session Expired
			end
*/
		end

		------------------
		commit transaction
		------------------

		return 50091	-- Account has been updated successfully
	end

end
GO
