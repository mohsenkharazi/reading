USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:Cardtrend Systems Sdn. Bhd.
Modular		:Cardtrend Card Management System (CCMS)-Acquiring Module

Objective	:Merchant maintenance.
-------------------------------------------------------------------------------
When	   Who		CRN	    Description
-------------------------------------------------------------------------------
2002/05/29 Sam			    Initial development.
2003/08/05 Sam				Incl. CoRegName, TaxId.
2004/02/24 Chew Pei			Withholding Tax Ind & Rate (Optional)
2004/07/09 Chew Pei			Added MerchMaint
2005/09/21 Chew Pei			commented 
							a. if @CorpCd is null return 55009	
							b. if @TaxId is null return 55162 --Tax Id is a compulsory field
2005/09/26 Chew Pei			Comment LastUpdDate
*******************************************************************************/

CREATE procedure [dbo].[MerchMaint]
	@Func varchar(5),
	@AcqNo uAcqNo,
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
--	@AppvInd uYesNo,
	@Sts uRefCd output,
	@EntityId uEntityId output,
	@CoRegName nvarchar(50),
	@TaxId nvarchar(20),
	@BranchCd uBranchCd,
	@WithholdInd uYesNo,
	@WithholdRate money,
	@AcctType uRefCd,
	@LastUpdDate varchar(30)
--	@CycNo uCycNo output
  as
begin
	declare @eMcc smallint, @ActiveSts uRefCd, @Inactive uRefCd, @eSts uRefCd, @Rc int, @Ind tinyint
	declare @LatestUpdDate datetime

	set nocount on

	select @ActiveSts = RefCd
	from iss_RefLib where IssNo = @AcqNo and RefType = 'MerchAcctSts' and RefInd = 0

--	if @Mcc is null select @Mcc = @eMcc
--	if not exists (select 1 from cmn_MerchantType where Type = 'M' and CategoryCd = @Mcc)
--		return 60038
--	if @CorpCd is null return 55009	--Corporate Code is a compulsory field
	if @BusnName is null return 55118
--*	if (@BankName is null and @BankAcctNo is not null) or (@BankName is not null and @BankAcctNo is null) return 95122
--*	if (@BankAcctNo is null and @AutoDebit = 'Y') or (@BankAcctNo is not null and @AutoDebit = 'N')return 95117
	if @AgreeNo is not null and @AgreeDate is null return 95116
--	if @CycNo is null return 55115
--	if @PayeeName is null and @PersonInChrg is not null select @PayeeName = @PersonInChrg
--	if @PayeeName is not null and @PersonInChrg is null select @PersonInChrg = @PayeeName
--*	if @PersonInChrg is null and @PayeeName is null return 55124
--*	if @CoRegName is null return 55186 --Company Registration Name is a compulsory field
--*	if @TaxId is null return 55162 --Tax Id is a compulsory field
--*	if (@BranchCd is null and @BankAcctNo is not null) or (@BranchCd is not null and @BankAcctNo is null) return 55165	--Branch Code is a compulsory field
--*	if (@WithholdInd is null and @WithholdRate is not null) or (@WithholdInd is not null and @WithholdRate is null) return 95276 --Check Withholding Tax Indicator and Rate
--*	if (@WithholdInd = 'N' and @WithholdRate is not null) or (@WithholdInd = 'Y' and @WithholdRate is null) return 95276 --Check Withholding Tax Indicator and Rate
--*	if @BankAcctNo is null return 55066	--Bank Account Number is a compulsory field
--*	if @BranchCd is null return 55165	--Branch Code is a compulsory field
--*	if @AcctType is null return 55153	--Bank Account Type  is a compulsory field
--*	if @BankAcctNo is not null and len(@BankAcctNo) <> 19 return 95122	--Check the Bank Account and Bank Name
--*	if @BankAcctNo is not null and isnumeric(@BankAcctNo) = 0 return 95122	--Check the Bank Account and Bank Name

	if @AcctNo is not null
	begin
		if not exists (select 1 from aac_Account where AcqNo = @AcqNo and AcctNo = @AcctNo)
			select @Ind = 1	
	end

	----------
	begin tran
	----------
	if isnull(@AcctNo, 0) = 0 or (isnull(@Ind, 0) = 1 and @Func = 'Add' and @AcctNo is not null)
	begin
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

		exec GetEntity @AcqNo, @PayeeName, @EntityId output
		if @EntityId is null
		begin
			rollback tran
			return 95120 --Failed to generate Entity
		end

		insert aac_Account
		( AcqNo, AcctNo, CorpCd, BusnName, CoRegNo, AgreementNo, AgreementDate,
		CreationDate, CreatedBy, ReasonCd, AutoDebitInd, BankName, BankAcctNo, PayeeName,
		PersonInCharge, EntityId, Ownership, Mcc, Sic, BusnSize, Sts, CoRegName, TaxId, BranchCd,
		WithholdingTaxInd, WithholdingTaxRate, BankAcctType, LastUpdDate )
		values
		( @AcqNo, @AcctNo, @CorpCd, @BusnName, @CoRegNo, @AgreeNo, @AgreeDate,
		getdate(), system_user, @ReasonCd, @AutoDebit, @BankName, @BankAcctNo, @PayeeName,
		@PersonInChrg, @EntityId, @Ownership, @Mcc, @Sic, @Establishment, @Sts, @CoRegName, @TaxId, @BranchCd,
		@WithholdInd, isnull(@WithholdRate,0), @AcctType, getdate() )

		if @@rowcount = 0 or @@error <> 0
		begin
			rollback tran
			return 70223
		end
		commit tran
		return 50180
	end

	if @Sts is null 
	begin
		rollback tran
		return 55092 --Status is a compulsory field
	end

	if exists (select 1 from iss_RefLib where IssNo = @AcqNo and RefType = 'MerchAcctSts' and RefInd > 0 and RefCd = @Sts)
	begin
		if @ReasonCd is null
		begin
			rollback tran
			return 55055 --Reason Code is a compulsory field
		end
	end
	else
		if @ReasonCd is not null 
		begin
			rollback tran
			return 95212 ----No reason is needed for an approved Merchant
		end

	select @eSts = Sts from aac_Account where AcqNo = @AcqNo and AcctNo = @AcctNo

	if @@rowcount = 0 or @@error <> 0 
	begin
		rollback tran
		return 60048 --Merchant Account not found
	end

--	if @LastUpdDate is null
--		select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

--	select @LatestUpdDate = LastUpdDate from aac_Account where AcctNo = @AcctNo
--	if @LatestUpdDate is null
--		select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

	-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
	-- it means that record has been updated by someone else, and screen need to be refreshed
	-- before the next update.
--	if @LatestUpdDate = convert(datetime, @LastUpdDate)
--	begin
		update aac_Account
		set CorpCd = @CorpCd, 
			BusnName = @BusnName,
			CoRegNo = @CoRegNo,
			CoRegName = @CoRegName,
			TaxId = @TaxId,
			AgreementNo = @AgreeNo,
			AgreementDate = @AgreeDate,
			ReasonCd = @ReasonCd,
			AutoDebitInd = @AutoDebit,
			BankName = @BankName,
			BankAcctNo = @BankAcctNo,
			PayeeName = @PayeeName,
			PersonInCharge = @PersonInChrg,
			Ownership = @Ownership,
			Mcc = @Mcc,
			Sic = @Sic,
			BusnSize = @Establishment,
			Sts = @Sts,
	--		CycNo = @CycNo,
			UserId = system_user,
			LastUpdDate = getdate(),
			BranchCd = @BranchCd,
			WithholdingTaxInd = @WithholdInd,
			WithholdingTaxRate = @WithholdRate,
			BankAcctType = @AcctType
		where AcctNo = @AcctNo

		if @@rowcount = 0 or @@error <> 0
		begin
			rollback tran
			return 70224
		end
--	end
--	else
--	begin
--		rollback tran
--		return 95307
--	end

	if @eSts <> @ActiveSts and @Sts = @ActiveSts
	begin
		exec @Rc = MerchValidate @AcqNo, @AcctNo

		if @@error <> 0 or @Rc > 0 
		begin
			update aac_Account
			set Sts = @eSts
			where AcqNo = @AcqNo and AcctNo = @AcctNo		

			if @@rowcount = 0 or @@error <> 0 
			begin
				rollback tran
				return 70124 --Failed to update Account
			end
			select @Sts = @eSts
			commit tran
			return @Rc
		end

		if not exists (select 1 from iss_Address where IssNo = @AcqNo and RefTo = 'MERCH' and RefKey = @AcctNo and RefType = 'Address' and MailingInd = 'Y')
		begin
			rollback tran
			return 95256 --At least one Mailing Indicator to be fill up
		end
	end

	-----------
	commit tran
	-----------
	return 50181
end
GO
