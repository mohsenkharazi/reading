USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BusnLocationValidate]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Business location validation.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/22 Sam			   Initial development
2005/09/28 Chew Pei			Comment @TaxId validation
2009/04/03 Barnett			Comment @Brandcd
2009/12/18 Barnett			Add Nolock
*******************************************************************************/

CREATE procedure [dbo].[BusnLocationValidate]
	@AcqNo uAcqNo,
	@BusnLocation uMerch
   as
begin
	declare @PayeeName uPayeeName, @EntityId uEntityId, @AcctNo uAcctNo, 
			@BusnName uBusnName, @BankName uRefCd, @BankAcctNo varchar(20), 
			@Sic uRefCd, @AutoDebit char(1), @Sts uRefCd, @AcctType uRefCd,
			@BranchCd uBranchCd, @TaxId nvarchar(20), @CoRegName nvarchar(50)

	select @PayeeName = PayeeName, 
		@EntityId = EntityId, 
		@BusnName = BusnName,
		@Sic = Sic,
		@AcctNo = AcctNo,
		@AutoDebit = AutoDebitInd,
		@BankName = BankName,
		@BankAcctNo = BankAcctNo,
		@TaxId = TaxId,
		@CoRegName = CoRegName,
		@BranchCd = BranchCd,
		@AcctType = BankAcctType
	from aac_BusnLocation a (nolock)
	where BusnLocation = @BusnLocation

	if @@rowcount = 0 or @@error <> 0 return 60010 --Business Location not found

	if @Sic is null return 55188
	if isnull(@PayeeName, '') = '' return 95118 --Check the Payee Name and Person In Charge
	if @EntityId is null return 60031 --Entity not found
	if @BusnName is null return 55141 --Name is a compulsory field
	if (@BankName is not null and @BankAcctNo is null) or
		(@BankName is null and @BankAcctNo is not null) 
			return 95122 --Check the Bank Account and Bank Name
		
	if (isnull(@AutoDebit,'')='')
	begin
		if @BankName is null return 95117 --Check Auto Debit and bank account
		if @AcctType is null return 55153 --Bank Account Type  is a compulsory field
	end

	if @CoRegName is null return 55186 --Company Registration Name is a compulsory field
--	if @TaxId is null return 55162 --Tax Id is a compulsory field
--	if (@BranchCd is null and @BankAcctNo is not null) or (@BranchCd is not null and @BankAcctNo is null) return 55165	--Branch Code is a compulsory field
	

	if not exists (select 1 from iss_Address (nolock) where IssNo = @AcqNo and RefTo = 'BUSN' and RefType = 'ADDRESS' and RefKey = @BusnLocation and MailingInd = 'Y')
		return 95256 --At least one Mailing Indicator to be fill up

	select @Sts = Sts from aac_Account where AcqNo = @AcqNo and AcctNo = @AcctNo

	if @@rowcount = 0 or @@error <> 0 return 60048 --Merchant Account not found

	if not exists (select 1 from iss_RefLib (nolock) where IssNo = @AcqNo and RefType = 'MerchAcctSts' and RefCd = @Sts and RefInd = 0)
		return 95267 --Check account status

	return 0
end
GO
