USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ApplicationValidation]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************
Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This is the front end Application capturing procedure.

-------------------------------------------------------------------------------
When	   Who		CRN		Desc
-------------------------------------------------------------------------------
2003/06/26 KY		1103003		Initial Development
2003/08/11 Sam				Check credit limit.
2003/08/21 Chew Pei			Changed RcptTaxId to RcptFax
								Added Tax ID validation (mandatory)
2003/09/12 Chew Pei			Make Introduct by and Tax Receipt Fax to be optional
2005/03/21 Chew Pei			Commented @RcptName and @RcptTel validation
2005/09/21 Alex				Check AcctInd for validate the Corporate/Individual	
2005/09/21 Chew Pei			Change 55162 to 55078 -- Company Registration Number is a compulsory field
2005/09/23 Chew Pei			Commented Trade No Validation
2005/11/08 Chew Pei			Commented Delivery Type and company related validation
2008/07/17 Peggy			Add checking on street2 and street3
******************************************************************************************************************/

CREATE procedure [dbo].[ApplicationValidation]
	@IssNo uIssNo,
	@ApplId uApplId
  as
begin
	declare @CardLogo uCardLogo,
			@PlasticType uPlasticType,
			@CycNo uCycNo,
			@ApplSts char(1),
			@ApplRef nvarchar(35),
			@CompanyType uRefCd,
			@CmpyRegsName1 uCmpyName,
			@CmpyRegsName2 uCmpyName,
			@BusnCategory uRefCd,
			@TaxId uTaxId,
			@PymtMode char(1),
			@BankAcctNo uBankAcctNo,
			@DeliveryType char(1),
			@BranchCd uRefCd,
			@HandDelivery nvarchar(20),
			@MailDelivery nvarchar(20),
			@ApplIntroBy uRefCd,
			@RcptName uCmpyName,
			@RcptTel uContactNo,
			@RcptFax uContactNo,
--			@RcptTaxId uTaxId,
			@Street1 uStreet,
			@Street2 uStreet,
			@Street3 uStreet,
			@State uRefCd,
			@Ctry uRefCd,
			@ZipCd uZipCd,
			@MaxCreditLimit money,
			@PreInd uYesNo,
			@TradeNo nvarchar(15),
			@AcctType char(1),
			@PymtAmt money

	set nocount on

	if isnull(@IssNo,'') = ''
	return 0	-- Mandatory Field IssNo

	if isnull(@ApplId,'') = ''
	return 0	-- Mandatory Field ApplId

	select @ApplRef = ApplRef, @CardLogo = CardLogo, 
			@PlasticType = PlasticType, @CycNo = CycNo, 
			@ApplSts = ApplSts, @CompanyType = CmpyType , 
			@CmpyRegsName1 = CmpyRegsName1, @CmpyRegsName2 = CmpyRegsName2, 
			@BusnCategory = BusnCategory, @TaxId = TaxId, 
			@PymtMode = PymtMode, @BankAcctNo = BankAcctNo, 
			@DeliveryType = DeliveryType, @BranchCd = BranchCd, 
			@HandDelivery = SendingCd, @MailDelivery = SendingCd, 
			--@ApplIntroBy = ApplIntroBy, 
			@RcptName = RcptName, 
			@RcptTel = RcptTel, --@RcptFax = RcptFax, 
			@MaxCreditLimit = CreditLimit,
			@TradeNo = TradeNo,
			--@RcptTaxId = RcptTaxId
			@AcctType = AcctType, @PymtAmt = PymtAmt
	from iap_Application
	where IssNo = @IssNo and ApplId = @ApplId

	--2003/08/11B
	select @PreInd = PrePaidInd from iss_PlasticType where IssNo = @IssNo and CardLogo = @CardLogo and PlasticType = @PlasticType
	--2003/08/11E

	if isnull(@ApplRef,'') = ''
	return 55001	-- Application Reference is a compulsory field

	if isnull(@CardLogo,'') = ''	
	return 55002	-- Card Logo is a compulsory field

	if isnull(@PlasticType,'') = ''
	return 55003	-- Plastic Type is a compulsory field

	--2003/08/11B
	--if isnull(@MaxCreditLimit, 0) = 0 and @PreInd = 'N'
	--return 55014 --Credit Limit is a compulsory field
	--2003/08/11E

	if isnull(@ApplSts,'') = ''
	return 55013	-- Application Status is a compulsory field
	
	if (@PymtMode = 'D') and isnull(@BankAcctNo, '') = ''
	return 55152 	-- Bank Account Number is a compulsory field

--	if isnull(@DeliveryType,'') = ''
--	return 55164 	-- Delivery Type is a compulsory field

--	if (@DeliveryType = 'B') and isnull(@BranchCd, '') = ''
--	return 55165 	-- Branch Code is a compulsory field

--	if (@DeliveryType = 'H') and isnull(@HandDelivery, '') = ''
--	return 55166 	-- By Hand is a compulsory field

--	if (@DeliveryType = 'R') and isnull(@MailDelivery, '') = ''
--	return 55167 	-- By Mail is a compulsory field

	--2005/09/21 Alex [BEGIN]
	if not exists (select 1 from iap_Application where ApplId = @ApplId and (isnull(@BankAcctNo, '')='' and isnull(@AcctType,'')='' and isnull(@PymtMode,'')='') )
	Begin
	
		if isnull(@AcctType,'') ='' return 55153 -- Bank Account Type  is a compulsory field
		if isnull(@BankAcctNo, '')='' return 55152 -- Bank Account Number is a compulsory field
		if (select @PymtMode ) is null 	return 55163 -- Payment Method is a compulsory field


		if ((select @PymtMode) ='X')
		begin
			if (select @PymtAmt) is null return 55119 -- Amount is a compulsory field
			if ((select @PymtAmt)<=0) return 95283-- Amount must be positive
		end
	end
	--2005/09/21 Alex [END]
	


	
	if ((select b.AcctInd from iap_Application a, iss_PlasticType b where a.ApplId = @ApplId and a.PlasticType = b.PlasticType)='Y')	
	begin
--		if isnull(@CompanyType, '') = ''
--		return 55156 	-- Company Type is a compulsory field

--		if isnull(@CmpyRegsName1, '') = '' and isnull(@CmpyRegsName2, '') = ''
--		return 55157 	-- Company Register Name is a compulsory field

--		if isnull(@BusnCategory, '') = ''
--		return 55158 	-- Business Category is a compulsory field
	
		--2003/08/21B
--		if isnull(@TaxId, '') = ''
--			return 55078 -- Company Registration Number is a compulsory field
		--return 55162 	-- Tax ID is a compulsory field
		--2003/08/21E

		if (select count(*) from iss_Address where IssNo = @IssNo and RefTo = 'APPL' and RefKey = @ApplId and MailingInd = 'Y' and RefType = 'ADDRESS') > 1
		return 95258  -- Check duplicate Mailing Indicator

		/*	CP : 20050321[B]
		if isnull(@RcptName,'') = ''
		return 55141	-- Name is a compulsory field 
	
		if isnull(@RcptTel,'') = ''
		return 55085	-- Contact No. is a compulsory field
	
		*/
	--	if isnull(@RcptTaxId,'') = ''
	--	return 55162	-- Tax Id is a compulsory field
	
		--2003/08/21B
	--	if isnull(@RcptFax,'') = ''
	--	return 55178	-- Fax Number is a compulsory field
		--2003/08/21E
	
		select @Street1 = Street1, @Street2 = Street2, @Street3 = (select Descp from iss_State where StateCd = @State),
			 @State = State, @ZipCd = ZipCd 
		from iss_Address where IssNo = @IssNo and RefTo = 'APPL' and RefKey = @ApplId and RefType = 'ADDRESS' and MailingInd = 'Y'
	
		if @@rowcount = 0 or @@error <> 0
		return 95256  -- At least one Mailing Indicator to be fill up
	
		select @Street1 = Street1, @Street2 = Street2, @Street3 = (select Descp from iss_State where StateCd = @State), @Ctry = Ctry
		from iss_Address a, iss_RefLib b 
		where a.IssNo = @IssNo and a.RefTo = 'APPL' and a.RefKey = @ApplId and a.RefType = 'ADDRESS' and b.IssNo = a.IssNo and b.RefType = 'Address' and (b.RefNo & 1) > 0 and a.RefCd = b.RefCd
	
		if isnull(@Street1,'') = ''
		return 55083	-- Address 1 is a compulsory field

		if isnull(@Street2,'') = ''
		return 55237	-- Address 2 is a compulsory field

		if isnull(@State,'') = ''
		return 55238	-- Address 3 is a compulsory field	

		if isnull(@Ctry,'') = ''
		return 55076	--Country is a compulsory field
	
		select @Street1 = Street1, @Street2 = Street2, @Street3 = (select Descp from iss_State where StateCd = @State), @Ctry = Ctry
		from iss_Address a, iss_RefLib b 
		where a.IssNo = @IssNo and a.RefTo = 'APPL' and a.RefKey = @ApplId and a.RefType = 'ADDRESS' and b.IssNo = a.IssNo and b.RefType = 'Address' and (b.RefNo & 4) > 0 and a.RefCd = b.RefCd	
	
		if isnull(@Street1,'') = ''
		return 55083	-- Address 1 is a compulsory field
	
		if isnull(@Street2,'') = ''
		return 55237	-- Address 2 is a compulsory field

		if isnull(@State,'') = ''
		return 55238	-- Address 3 is a compulsory field	

		if isnull(@Ctry,'') = ''
		return 55076	--Country is a compulsory field
	
		select @Street1 = a.Street1, @Street2 = Street2, @Street3 = (select Descp from iss_State where StateCd = @State), @State = a.State, @ZipCd = a.ZipCd 
		from iss_Address a, iss_RefLib b where a.IssNo = @IssNo and a.RefTo = 'APPL' and a.RefKey = @ApplId and a.RefType = 'ADDRESS' and b.IssNo = a.IssNo and b.RefType = 'Address' and (b.RefNo & 8) > 0 and a.RefCd = b.RefCd	
	
		if isnull(@Street1,'') = ''
		return 55083	-- Address 1 is a compulsory field

		if isnull(@Street2,'') = ''
		return 55237	-- Address 2 is a compulsory field

		if isnull(@State,'') = ''
		return 55238	-- Address 3 is a compulsory field	

	-- 2003/08/21B
	--	if isnull(@State,'') = ''
	--	return 55160	-- Province is a compulsory field
	
	--	if isnull(@ZipCd,'') = ''
	--	return 55161	-- Postal Code is a compulsory field
	-- 2003/08/21E
		if not exists (select 1 from iss_Contact a, iss_RefLib b where a.IssNo = @IssNo and a.RefTo = 'APPL' and a.RefKey = @ApplId and b.IssNo = a.IssNo and b.RefType = 'Contact' and (b.RefNo & 1) > 0 and b.RefInd > 0 and a.Refcd = b.Refcd)
		return 55180 	-- Primary Company Contact must be fill up

	-- Commented by CP 2005/09/23
		--2003/10/07B
	--	if @TradeNo is null and isnull(@PreInd,'N') = 'N' return 55193 --Trade No is a compulsory field
		--2003/10/07E

		if exists (select 1 from iaa_BankAccount where IssNo = @IssNo and ApplId = @ApplId and BankAcctNo is null)
		return 55152	-- Bank Account Number is a compulsory field
	
		if exists (select 1 from iaa_BankAccount where IssNo = @IssNo and ApplId = @ApplId and BankAcctNo is null and AcctType is not null)
		return 55153	-- Bank Account Type  is a compulsory field
	
		if exists (select 1 from iaa_BankAccount where IssNo = @IssNo and ApplId = @ApplId and BankAcctNo is not null and BankName is null)
		return 55154	-- Bank Name is a compulsory field
	
		if not exists (select 1 from iaa_ShareHolder where IssNo = @IssNo and ApplId = @ApplId)
		return 55151	-- Shareholder Name is compulsory field

	end	
end
GO
