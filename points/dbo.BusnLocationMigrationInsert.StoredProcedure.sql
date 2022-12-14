USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BusnLocationMigrationInsert]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [dbo].[BusnLocationMigrationInsert]	
	@AcqNo uAcqNo,	
	@BusnLocation uMerch,
	@AcctNo uAcctNo output,
	@BusnName uBusnName,
	@AgreeNo varchar(10),
	@AgreeDate datetime,
	@BankName uRefCd,
	@ReasonCd uRefCd,
	@PersonInChrg nvarchar(50),
	@Ownership uRefCd,
	@Sic uRefCd,
	@Mcc uRefCd,
	@CreatedBy uUserId,
	@CreateDate char(10), 
	@CoRegNo nvarchar(15), 
	@BankAcctNo varchar(15),
	@PayeeName uPayeeName,
	@AutoDebit uYesNo,
	@StmtPrint char(1),
	@SiteId nvarchar(15),
	@EntityId uEntityId output,
	@BranchCd varchar(10),
	@DBAName nvarchar(50),
	@DBACity uRefCd,
	@DBAState uRefCd,
	@DBARegion uRefCd,
	@CoRegName nvarchar(50),
	@TaxId nvarchar(20),
	@AcctType uRefCd,
	@DealerAcctNo uAcctNo,

	@ContactNo varchar(15),	
	@MobileNo varchar(25),
	@EmailAddr varchar(100),

	@Street1 varchar(150), 
	@State uRefCd,
	@Sts uRefCd

   as
begin
	declare @CancelDate datetime, @eMcc uRefCd, @ActiveSts uRefCd, @Inactive uRefCd, @eOwnership uRefCd, 
			@AcctSts uRefCd, @LatestUpdDate datetime

	set nocount on

	if @BusnLocation is null return 60075	--Invalid Merchant No

	if @BusnName is null return 55118 --Merchant Name is a compulsory field
--	if (@BankName is null and @BankAcctNo is not null) or (@BankName is not null and @BankAcctNo is null) return 95122
	if (@BankAcctNo is null and @AutoDebit = 'Y') or (@BankAcctNo is not null and @AutoDebit = 'N') return 95117
	if (@BankName is null and @BankAcctNo is not null) or
		(@BankName is not null and @BankAcctNo is null) return 95122
--	if (@BankName is null and @AutoDebit = 'Y') or (@BankAcctNo is not null and @AutoDebit = 'N') return 95117
	if (@AgreeNo is not null and @AgreeDate is null) or (@AgreeNo is null and @AgreeDate is not null) return 95116
	if @Sic is null return 55188 --Merchant Type is a compulsory field
	if @DBAName is null or @DBACity is null return 95272 --Check DBA details
	if @CoRegName is null return 55186 --Company Registration Name is a compulsory field
	if @TaxId is null return 55162 --Tax Id is a compulsory field
	if @BankAcctNo is null return 55066	--Bank Account Number is a compulsory field
--	if @BranchCd is null return 55165	--Branch Code is a compulsory field
--	if @AcctType is null return 55153	--Bank Account Type  is a compulsory field
--	if @BankAcctNo is not null and len(@BankAcctNo) <> 10 return 95122	--Check the Bank Account and Bank Name
	if @BankAcctNo is not null and isnumeric(cast(@BankAcctNo as varchar(6))) = 0 return 95122	--Check the Bank Account and Bank Name

	select @PersonInChrg = isnull(@PersonInChrg, @PayeeName)
	select @PayeeName = isnull(@PayeeName, @PersonInChrg)

	select @Inactive = RefCd from iss_RefLib where IssNo = @AcqNo and RefType = 'MerchAcctSts' and RefNo = 1
	select @ActiveSts = RefCd from iss_RefLib where IssNo = @AcqNo and RefType = 'MerchAcctSts' and RefInd = 0
	
	select @eMcc = Mcc,
		@eOwnership = Ownership,
		@AcctSts = Sts
	from aac_Account a
	join iss_RefLib b on a.AcqNo = b.IssNo and a.Sts = b.RefCd and b.RefType = 'MerchAcctSts' and RefInd <> 9
	where a.AcqNo = @AcqNo and a.AcctNo = @AcctNo

	if @@rowcount = 0 or @@error <> 0 return 95267	--Check account status
		
--	select @BusnLocation = '000001' + substring(@BusnLocation,1,9)
--	if @BusnLocation is not null
--	begin
--		if exists (select 1 from aac_BusnLocation where BusnLocation = @BusnLocation)
--			return 65041 --Business Location already exists
--	end
	
	select @Ownership = isnull(@Ownership, @eOwnership)
	select @Mcc = isnull(@Mcc, @eMcc)

--	if @PayeeName is null and @PersonInChrg is null return 95118
--	if @PayeeName is null and @PersonInChrg is not null select @PayeeName = @PersonInChrg
--	if @PayeeName is not null and @PersonInChrg is null select @PersonInChrg = @PayeeName

	----------
	BEGIN TRAN
	----------

	
--		if @BusnLocation is null
--		begin
--			exec GetBusnLocation @AcqNo, @BusnLocation output
--
--			if @BusnLocation is null 
--			begin
--				rollback tran
--				return 95119 --Failed to generate Business Location
--			end
--		end
--
--		exec GetEntity @AcqNo, @PayeeName, @EntityId output
--
--		if @EntityId is null
--		begin
--			rollback tran
--			return 95120 --Failed to generate Entity
--		end
-- 
		insert aac_BusnLocation
		( BusnLocation, AcqNo, AcctNo, BusnName, CoRegNo, AgreementNo, 
		AgreementDate, PartnerRefNo, CreationDate, CreatedBy, CancelDate,
		AutoDebitInd, BankName, BankAcctNo, /*DealerAcctNo,*/ PayeeName, PersonInCharge, EntityId,
		StmtPrintInd, Ownership, Mcc, Sic, BranchCd, DBAName, DBARegion, DBACity, DBAState, Sts, CoRegName, TaxId, BankAcctType, LastUpdDate )
		values
		( @BusnLocation, @AcqNo, @AcctNo, @BusnName, @CoRegNo, @AgreeNo, 
		@AgreeDate, @SiteId, getdate(), system_user, @CancelDate,
		@AutoDebit, @BankName, @BranchCd + @BankAcctNo, /*@DealerAcctNo,*/ @PayeeName, @PersonInChrg, @EntityId,
		@StmtPrint, @Ownership, @Mcc, @Sic, null, @DBAName, @DBARegion, @DBACity, @DBAState, @Sts, @CoRegName, @TaxId, @AcctType, getdate() )

		if @@error <> 0
		begin
			rollback tran
			return 70221 --Failed to create Business Location
		end

		insert aac_BusnLocationFinInfo
		(BusnLocation, LastUpdDate, FloorLimit, SettlementEnd)
		values (@BusnLocation, getdate(), 9999999.99, null)

		if @@error <> 0
		begin
			rollback tran
			return 70221 --Failed to create Business Location
		end

		----------------------------------
		-- Insert Address
		----------------------------------
-- select * from iss_RefLib where RefType like '%add%'

		insert into iss_Address (IssNo, RefTo, RefKey, RefType, RefCd, Street1, Street2, Street3, 
			State, ZipCd, Ctry, EntityInd, MailingInd, LastUpdDate )
		select @AcqNo, 'BUSN', @BusnLocation, 'ADDRESS', '20', @Street1, null, null, 
			@State, null, '458', null, 'Y', getdate()
		
		if @@error <> 0
		begin
			rollback tran
			return 70221 --Failed to create Business Location
		end
			

		----------------------------------
		-- Insert Contact
		----------------------------------
-- select * from iss_RefLib where RefType like '%contact%'

		insert into iss_Contact(IssNo, RefTo, RefKey, RefType, RefCd, ContactName, Occupation, ContactNo, 
			Sts, EntityInd, EmailAddr, PromoteInd, LastUpdDate)
		select @AcqNo, 'BUSN', @BusnLocation, 'CONTACT', '40', @PersonInChrg, null, @ContactNo,
			'A', null, @EmailAddr, null, getdate()

		if @@error <> 0
		begin
			rollback tran
			return 70225
		end

		if isnull(@MobileNo,'') <> ''
		begin
			insert into iss_Contact(IssNo, RefTo, RefKey, RefType, RefCd, ContactName, Occupation, ContactNo, 
				Sts, EntityInd, EmailAddr, PromoteInd, LastUpdDate)
			select @AcqNo, 'BUSN', @BusnLocation, 'CONTACT', '42', @PersonInChrg, null, @MobileNo,
				'A', null, @EmailAddr, null, getdate()
			
			if @@error <> 0
			begin
				rollback tran
				return 70226
			end

		end
			
		-----------
		commit tran
		-----------

		return 50178 --Business Location has been created successfully
	
end
GO
