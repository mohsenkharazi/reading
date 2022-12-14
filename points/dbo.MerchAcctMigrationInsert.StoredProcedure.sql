USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchAcctMigrationInsert]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [dbo].[MerchAcctMigrationInsert]	
	@AcqNo int,
	@AcctNo uAcctNo output,	
	@BusnName uBusnName,
	@AgreeNo varchar(10),
	@AgreeDate datetime,
	@BankName uRefCd,
	@CorpCd uRefCd, 
	@ReasonCd uRefCd,
	@PersonInChrg nvarchar(50),
	@Ownership uRefCd,
	@Establishment uRefCd,
	@Sic uRefCd,
	@Mcc uRefCd,
	@CreatedBy uUserId,
	@CreateDate varchar(10), 
	@CoRegNo nvarchar(15),
	@BankAcctNo uBankAcctNo,
	@PayeeName uPayeeName,
	@AutoDebit uYesNo,
	@Sts uRefCd output,
	@EntityId uEntityId output,
	@CoRegName nvarchar(50),
	@TaxId nvarchar(20),
	@BranchCd varchar(25), --uBranchCd
	@WithholdInd uYesNo,
	@WithholdRate money,
	@AcctType uRefCd,
	
	@ContactNo varchar(15),	
	@MobileNo varchar(25),
	@EmailAddr varchar(100),

	@Street1 varchar(150), 
	@State uRefCd

  as
begin
	declare @eMcc smallint, @ActiveSts uRefCd, @Inactive uRefCd, @eSts uRefCd, @Rc int, @Ind tinyint
	declare @LatestUpdDate datetime

	set nocount on

	select @ActiveSts = RefCd
	from iss_RefLib where IssNo = @AcqNo and RefType = 'MerchAcctSts' and RefInd = 0

	if @CorpCd is null return 55009	--Corporate Code is a compulsory field
	if @BusnName is null return 55118
	if (@BankName is null and @BankAcctNo is not null) or (@BankName is not null and @BankAcctNo is null) return 95122
	if (@BankAcctNo is null and @AutoDebit = 'Y') or (@BankAcctNo is not null and @AutoDebit = 'N')return 95117
	if @AgreeNo is not null and @AgreeDate is null return 95116
--	if @PersonInChrg is null and @PayeeName is null return 55124
	if @CoRegName is null return 55186 --Company Registration Name is a compulsory field
--	if @TaxId is null return 55162 --Tax Id is a compulsory field
	if (@BranchCd is null and @BankAcctNo is not null) or (@BranchCd is not null and @BankAcctNo is null) return 55165	--Branch Code is a compulsory field
	if @BankAcctNo is null return 55066	--Bank Account Number is a compulsory field
	if @BranchCd is null return 55165	--Branch Code is a compulsory field
--	if @AcctType is null return 55153	--Bank Account Type  is a compulsory field
--	if @BankAcctNo is not null and len(@BankAcctNo) <> 10 return 95122	--Check the Bank Account and Bank Name
	if @BankAcctNo is not null and isnumeric(cast(@BankAcctNo as varchar(6))) = 0 return 95122	--Check the Bank Account and Bank Name

	----------
	begin tran
	----------


		select @Inactive = RefCd from iss_RefLib where IssNo = @AcqNo and RefType = 'MerchAcctSts' and RefNo = 1

		if @ReasonCd is not null select @Sts = @Inactive

		select @Sts = isnull(@Sts, @Inactive)

		if @Sts = @Inactive
		begin
			select @ReasonCd = isnull(@ReasonCd, 'INSD')
		end

		if @AcctNo is null
		begin
			exec GetMerchAccountNo @AcqNo, @AcctNo output
			if @AcctNo is null 
			begin
				rollback tran
				return 95123
			end
		end

		if (select isnull(len(convert(varchar(10),@AcctNo)), 0)) <> 10 
		begin
			rollback tran
			return 95123 --Failed to generate Merchant
		end

		exec EntityMigrationInsert @AcqNo, @PersonInChrg, @EntityId output

		if @EntityId is null
		begin
			rollback tran
			return 95120 --Failed to generate Entity
		end

		--------------------------------------
		-- Create Account
		--------------------------------------

		insert aac_Account
		( AcqNo, AcctNo, CorpCd, BusnName, CoRegNo, AgreementNo, AgreementDate,
		CreationDate, CreatedBy, ReasonCd, AutoDebitInd, BankName, BankAcctNo, PayeeName,
		PersonInCharge, EntityId, Ownership, Mcc, Sic, BusnSize, Sts, CoRegName, TaxId, BranchCd,
		WithholdingTaxInd, WithholdingTaxRate, BankAcctType, LastUpdDate )
		values	
		( @AcqNo, @AcctNo, @CorpCd, @BusnName, @CoRegNo, @AgreeNo, @AgreeDate,
		getdate(), system_user, @ReasonCd, @AutoDebit, @BankName, @BranchCd + @BankAcctNo, @PayeeName,
		@PersonInChrg, @EntityId, @Ownership, @Mcc, @Sic, @Establishment, @Sts, @CoRegName, @TaxId, null,
		@WithholdInd, isnull(@WithholdRate,0), @AcctType, getdate() )

		if @@error <> 0
		begin
			rollback tran
			return 70223
		end


		---------------------------
		-- Create Address
		---------------------------
-- select * From iss_Address
-- select * from iss_reflib where reftype like '%add%'

		insert into iss_Address(IssNo, RefTo, RefKey, RefType, RefCd, Street1, Street2, Street3, 
			State, ZipCd, Ctry, EntityInd, MailingInd, LastUpdDate)
		select @AcqNo, 'MERCH', @AcctNo, 'ADDRESS', '20', @Street1, null, null, 
			@State, null, '458', null, 'Y', getdate()	

		if @@error <> 0
		begin
			rollback tran
			return 70224
		end

		---------------------------
		-- Create Contact
		---------------------------
-- select * from iss_Contact
-- select * from iss_reflib where reftype like '%contact%'

		insert into iss_Contact(IssNo, RefTo, RefKey, RefType, RefCd, ContactName, Occupation, ContactNo, 
			Sts, EntityInd, EmailAddr, PromoteInd, LastUpdDate)
		select @AcqNo, 'MERCH', @AcctNo, 'CONTACT', '42', @PersonInChrg, null, @ContactNo,
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
			select @AcqNo, 'MERCH', @AcctNo, 'CONTACT', '42', @PersonInChrg, null, @MobileNo,
				'A', null, @EmailAddr, null, getdate()
			
			if @@error <> 0
			begin
				rollback tran
				return 70226
			end

		end

		commit tran

		return 50180
	
end
GO
