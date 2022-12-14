USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BusnLocationMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:Cardtrend Systems Sdn. Bhd.
Modular		:Cardtrend Card Management System (CCMS)- Acquiring Module

Objective	:Business Location creation or maintenance.
-------------------------------------------------------------------------------
When	   Who		CRN		Description
-------------------------------------------------------------------------------
2002/06/10 Sam				Initial development.
2003/09/25 Sam				Merchant no creation.
2003/11/25 Sam				To populates account contact detail for new merchant.
2004/05/19 Chew Pei			Added Dealer Acct No
2004/05/21 Aeris			Added Region
2004/06/17 Chew Pei			Insert aac_BusnLocation with LastUpdDate
2004/07/08 Chew Pei			Added LastUpdDate
2005/09/16 KY				Take out the BusnLocation Prefix
2005/09/21 Alex				Add Caution Code, Annual/Month Sale, Bank Ind, Remark.
2005/09/27 Chew Pei			Comment Tax Id validation
							Add Co RegNo validation\
							Comment LastUpdDate validation done on 2004/07/08
2008/03/07 Peggy			Disable the Merch No length validation
							Add WebLogonId, WebPw
2008/03/11 Peggy			Add gen password function
2009/03/16 Barnett			Change Dealer AcctNo to  Dealer Code
2009/04/03 Barnett			Limit BusnLocation must 15 Digits.
2019/03/04 Humairah			Limit Site Id t0 16 characters.
*******************************************************************************/
CREATE procedure [dbo].[BusnLocationMaint]
	@Func varchar(5),
	@AcqNo uAcqNo,
	@BusnLocation uMerch output,
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
	@BankAcctNo uBankAcctNo,
	@PayeeName uPayeeName,
	@AutoDebit uYesNo,
	@StmtPrint char(1),
	@SiteId nvarchar(max),
	@EntityId uEntityId output,
	@BranchCd uBranchCd,
	@DBAName nvarchar(50),
	@DBACity uRefCd,
	@DBAState uRefCd,
	@DBARegion uRefCd, --2004/05/21
	@CoRegName nvarchar(50),
	@TaxId nvarchar(20),
	@AcctType uRefCd,
	@DealerCd varchar(20),
	@LastUpdDate varchar(30),
	@CautionCd char(1),
	@OthBankInd char(1),
	@AnnualSales money,
	@MonthlySales money,
	@Remarks varchar(50),     
	@WebLogonId uWebLogonId,
	@WebPw uPw
   as
begin
	declare @CancelDate datetime, @eMcc uRefCd, @ActiveSts uRefCd, @Inactive uRefCd, @eOwnership uRefCd, @Sts uRefCd,
			@AcctSts uRefCd, @LatestUpdDate datetime

	set nocount on


	if len(@BusnLocation) <> 15 return 95206	--Invalid length of Merchant No

	
	if @BusnLocation is null return 60075	--Invalid Merchant No

	if @BusnName is null return 55118 --Merchant Name is a compulsory field
	if (@AgreeNo is not null and @AgreeDate is null) or (@AgreeNo is null and @AgreeDate is not null) return 95116
	if @Sic is null return 55188 --Merchant Type is a compulsory field
	if @DBAName is null or @DBACity is null return 95272 --Check DBA details
	if @CoRegName is null return 55186 --Company Registration Name is a compulsory field
	if @SiteId is null 	return 55276  -- Site Id is a compulsory field
	if len(@SiteId)>16 	return 95809  -- 'Length of Site Id must be in 16 characters or less' 


	select @PersonInChrg = isnull(@PersonInChrg, @PayeeName)
	select @PayeeName = isnull(@PayeeName, @PersonInChrg)

	select @Inactive = RefCd from iss_RefLib (nolock) where IssNo = @AcqNo and RefType = 'MerchAcctSts' and RefNo = 1
	select @ActiveSts = RefCd from iss_RefLib (nolock) where IssNo = @AcqNo and RefType = 'MerchAcctSts' and RefInd = 0

	if @Func = 'Add'
	begin
		select @eMcc = Mcc,
			@eOwnership = Ownership,
			@AcctSts = Sts
		from aac_Account a (nolock)
		join iss_RefLib b (nolock) on a.AcqNo = b.IssNo and a.Sts = b.RefCd and b.RefType = 'MerchAcctSts' and RefInd <> 9
		where a.AcqNo = @AcqNo and a.AcctNo = @AcctNo

		if @@rowcount = 0 or @@error <> 0 return 95267	--Check account status
	end
	else
	begin
		select @eMcc = Mcc,
			@eOwnership = Ownership
		from aac_Account a (nolock)
		join iss_RefLib b (nolock) on a.AcqNo = b.IssNo and a.Sts = b.RefCd and b.RefType = 'MerchAcctSts' and RefInd = 0
		where a.AcqNo = @AcqNo and a.AcctNo = @AcctNo

		if @@rowcount = 0 or @@error <> 0 return 95267	--Check account status
	end

	if @Func = 'Add' 
	begin
		if @BusnLocation is not null
		begin
			if exists (select 1 from aac_BusnLocation (nolock) where BusnLocation = @BusnLocation)
				return 65041 --Business Location already exists
		end
	end
	else
		if not exists (select 1 from aac_BusnLocation (nolock) where BusnLocation = @BusnLocation)
			return 60010 --Merchant not found

	select @Ownership = isnull(@Ownership, @eOwnership)
	select @Mcc = isnull(@Mcc, @eMcc)

	if @PayeeName is null and @PersonInChrg is null return 95118
	if @PayeeName is null and @PersonInChrg is not null select @PayeeName = @PersonInChrg
	if @PayeeName is not null and @PersonInChrg is null select @PersonInChrg = @PayeeName
	
	----------
	BEGIN TRAN
	----------
	if @Func = 'Add'
	begin
		if @BusnLocation is null
		begin
			exec GetBusnLocation @AcqNo, @BusnLocation output

			if @BusnLocation is null 
			begin
				rollback tran
				return 95119 --Failed to generate Business Location
			end
		end

		exec GetEntity @AcqNo, @PayeeName, @EntityId output

		if @EntityId is null
		begin
			rollback tran
			return 95120 --Failed to generate Entity
		end
		
		select @WebLogonId = isnull(@WebLogonId, @BusnLocation)
		if @WebLogonId is not null
			select @WebPw = dbo.GenPassword(rand())
		
		insert aac_BusnLocation
		( BusnLocation, AcqNo, AcctNo, BusnName, CoRegNo, AgreementNo, 
		AgreementDate, PartnerRefNo, CreationDate, CreatedBy, CancelDate,
		AutoDebitInd, BankName, BankAcctNo, DealerCd, PayeeName, PersonInCharge, EntityId,
		StmtPrintInd, Ownership, Mcc, Sic, BranchCd, DBAName, DBARegion, DBACity, DBAState, 
		Sts, CoRegName, TaxId, BankAcctType, LastUpdDate, CautionCd, OthBankInd, AnnualSales, 
		MonthlySales, Remarks, WebLogonId, WebPw )
		values
		( @BusnLocation, @AcqNo, @AcctNo, @BusnName, @CoRegNo, @AgreeNo, 
		@AgreeDate, @SiteId, getdate(), system_user, @CancelDate,
		@AutoDebit, @BankName, @BankAcctNo, @DealerCd, @PayeeName, @PersonInChrg, @EntityId,
		@StmtPrint, @Ownership, @Mcc, @Sic, @BranchCd, @DBAName, @DBARegion, @DBACity, @DBAState, 
		@Inactive, @CoRegName, @TaxId, @AcctType, getdate(), @CautionCd, @OthBankInd, @AnnualSales, 
		@MonthlySales, @Remarks, @WebLogonId, @WebPw )

		if @@error <> 0
		begin
			rollback tran
			return 70221 --Failed to create Business Location
		end

		insert aac_BusnLocationFinInfo
		(BusnLocation, LastUpdDate, FloorLimit, SettlementEnd)
		values (@BusnLocation, getdate(), 999999.99, null)

		if @@error <> 0
		begin
			rollback tran
			return 70221 --Failed to create Business Location
		end

		if exists (select 1 from iss_Address (nolock) where RefTo = 'MERCH' and RefKey = @AcctNo)
		begin
			select * into #Addr from iss_Address (nolock) where RefTo = 'MERCH' and RefKey = @AcctNo

			if @@rowcount > 0 and @@error = 0
			begin
				insert iss_Address
				( IssNo, RefTo, RefKey, RefType, RefCd, Street1, Street2, Street3, State, ZipCd, Ctry, EntityInd, MailingInd )
				select IssNo, 'BUSN', @BusnLocation, RefType, RefCd, Street1, Street2, Street3, State, ZipCd, Ctry, null, MailingInd
				from #Addr

				if @@error <> 0
				begin
					rollback tran
					return 70221 --Failed to create Business Location
				end
			end
		end

		--2003/11/25B
		if exists (select 1 from iss_Contact (nolock) where RefTo = 'MERCH' and RefKey = @AcctNo)
		begin
			select * into #Cont from iss_Contact (nolock) where RefTo = 'MERCH' and RefKey = @AcctNo

			if @@rowcount > 0 and @@error = 0
			begin
				insert iss_Contact
				( IssNo, RefTo, RefKey, RefType, RefCd, ContactName, Occupation, ContactNo, Sts, EntityInd, EmailAddr )
				select IssNo, 'BUSN', @BusnLocation, RefType, RefCd, ContactName, Occupation, ContactNo, Sts, EntityInd, EmailAddr
				from #Cont

				if @@error <> 0
				begin
					rollback tran
					return 70221 --Failed to create Business Location
				end
			end
		end
		--2003/11/25E
		-----------
		commit tran
		-----------
		return 50178 --Business Location has been created successfully
	end

	select @Sts = Sts from aac_BusnLocation (nolock) where BusnLocation = @BusnLocation

	if (@ReasonCd is not null and @Sts is null) or @Sts is null
		select @Sts = @inactive

	if (@Sts <> @ActiveSts and @Sts <> @Inactive) 
	begin
		rollback tran
		return 95132 --Check Merchant status
	end


	select @WebPw = WebPw from aac_BusnLocation (nolock) where BusnLocation = @BusnLocation
	if @WebPw is null
		select @WebPw = dbo.GenPassword(rand())

		update aac_BusnLocation
		set BusnName = @BusnName,
			PartnerRefNo = @SiteId,
			CoRegNo = @CoRegNo,
			AgreementNo = @AgreeNo,
			AgreementDate = @AgreeDate,
			AutoDebitInd = @AutoDebit,
			BankName = @BankName,
			BankAcctNo = @BankAcctNo,
			DealerCd = @DealerCd, -- CP 20040519
			PayeeName = @PayeeName,
			PersonInCharge = @PersonInChrg,
			Ownership = @Ownership,
			Mcc = @Mcc,
			Sic = @Sic,
			StmtPrintInd = @StmtPrint,
			BranchCd = @BranchCd,
			ReasonCd = @ReasonCd,
			DBAName = @DBAName,
			DBARegion = @DBARegion, --2004/05/21
			DBACity = @DBACity,
			DBAState = @DBAState,
			Sts = @Sts,
			UserId = system_user,
			LastUpdDate = getdate(),
			CoRegName = @CoRegName,
			TaxId = @TaxId,
			BankAcctType = @AcctType,
			CautionCd = @CautionCd,
			OthBankInd = @OthBankInd, 
			AnnualSales = @AnnualSales, 
			MonthlySales = @MonthlySales, 
			Remarks = @Remarks,
			WebLogonId = @WebLogonId,
			WebPw = @WebPw
		where BusnLocation = @BusnLocation

		if @@rowcount = 0 or @@error <> 0
		begin
			rollback tran
			return 70222 --Failed to update Business Location
		end
		-----------
		COMMIT TRAN
		-----------
		return 50179 --Business Location has been updated successfully

end
GO
