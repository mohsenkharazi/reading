USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchValidate]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Merchant account validation.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/22 Sam			   Initial development
2005/09/26 Chew Pei			Comment off validation --*
*******************************************************************************/

CREATE procedure [dbo].[MerchValidate]
	@AcqNo uAcqNo,
	@AcctNo uAcctNo
  as
begin
	declare @PayeeName uPayeeName, @EntityId uEntityId, @CorpCd uRefCd, 
			@BusnName uBusnName, @BankName uRefCd, @BankAcctNo varchar(20),
			@CoRegName nvarchar(50), @WithholdInd uYesNo, @WithholdRate money,
			@BranchCd uBranchCd, @TaxId nvarchar(20), @AcctType uRefCd

	select @PayeeName = PayeeName, 
		@EntityId = EntityId, 
		@CorpCd = CorpCd, 
		@BusnName = BusnName,
		@CoRegName = CoRegName,
		@BranchCd = BranchCd,
		@WithholdInd = WithholdingTaxInd,
		@WithholdRate = WithholdingTaxRate,
		@TaxId = TaxId,
		@BankAcctNo = BankAcctNo,
		@AcctType = BankAcctType
	from aac_Account 
	where AcctNo = @AcctNo

	if @@rowcount = 0 or @@error <> 0 return 60048 --Merchant Account not found

--*	if @PayeeName is null return 95118 --Check the Payee Name and Person In Charge
	if @EntityId is null return 60031 --Entity not found
--*	if @CorpCd is null return 55009	--Corporate Code is a compulsory field
	if @BusnName is null return 55141 --Name is a compulsory field
--*	if @CoRegName is null return 55186 --Company Registration Name is a compulsory field
--*	if @TaxId is null return 55162 --Tax Id is a compulsory field
--*	if (@BranchCd is null and @BankAcctNo is not null) or (@BranchCd is not null and @BankAcctNo is null) return 55165	--Branch Code is a compulsory field
--*	if (@WithholdInd is null and @WithholdRate is not null) or (@WithholdInd is not null and @WithholdRate is null) return 95276 --Check Withholding Tax Indicator and Rate
--*	if (@WithholdInd = 'N' and @WithholdRate is not null) or (@WithholdInd = 'Y' and @WithholdRate is null) return 95276 --Check Withholding Tax Indicator and Rate
--*	if @AcctType is null return 55153	--Bank Account Type  is a compulsory field

--*	if not exists (select 1 from iss_Address where IssNo = @AcqNo and RefTo = 'MERCH' and RefKey = @AcctNo and RefType = 'ADDRESS' and MailingInd = 'Y')
--*		return 95256 --At least one Mailing Indicator to be fill up

	select @BankName = BankName,
		@BankAcctNo = BankAcctNo
	from aac_Entity where AcqNo = @AcqNo and EntityId = @EntityId

	if @@rowcount = 0 or @@error <> 0 return 60031 --Entity not found

	if (@BankName is not null and @BankAcctNo is null) or (@BankName is null and @BankAcctNo is not null) 
		return 95122 --Check the Bank Account and Bank Name

	return 0
end
GO
