USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BusnBankDetailMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Add Bank Detail

-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2005/09/16	Alex				Initial Development
2005/09/27	Chew Pei			Change @BankAcctNo from varchar(15) to varchar(20)
*******************************************************************************/
	
CREATE procedure [dbo].[BusnBankDetailMaint]
	@Func varchar(5),
	@AcqNo uAcqNo,
	@BusnLocation uMerchNo,
	@BankName uRefCd,
	@BankAcctNo varchar(20),
	@AutoDebit uYesNo,
	@BranchCd uBranchCd,
	@BankAcctType uRefCd,
	@LastUpdDate datetime
   
as
begin

	if ((@BankName is not null) or(@BankAcctNo is not null) or (@BankAcctType is not null) or (@AutoDebit = 'Y' )or (@BranchCd is not null)) 
	begin
		if (@BankAcctNo is null and @AutoDebit = 'Y') or (@BankAcctNo is not null and @AutoDebit = 'N') return 95117
		if (@BankName is null and @BankAcctNo is not null) or (@BankName is not null and @BankAcctNo is null) return 95122
		--	if (@BankName is null and @AutoDebit = 'Y') or (@BankAcctNo is not null and @AutoDebit = 'N') return 95117
		if @BankAcctNo is null return 55066	--Bank Account Number is a compulsory field
		if @BranchCd is null return 55165	--Branch Code is a compulsory field
		if @BankAcctType is null return 55153	--Bank Account Type  is a compulsory field
		if @BankAcctNo is not null and len(@BankAcctNo) > 20 return 95122	--Check the Bank Account and Bank Name
		if @BankAcctNo is not null and isnumeric(@BankAcctNo) = 0 return 95122	--Check the Bank Account and Bank Name

	end

	if @Func ='Save'
	begin
		-----------------
		Begin Transaction
		-----------------
		update aac_BusnLocation
		set 	BankName = @BankName,
			BankAcctNo = @BankAcctNo,
			BranchCd = @BranchCd,
			UserId = system_user,
			LastUpdDate = getdate(),
			BankAcctType = @BankAcctType,
			AutoDebitInd = @AutoDebit
		where   BusnLocation = @BusnLocation and AcqNo = @AcqNo

		if @@rowcount = 0 or @@error <> 0
		begin
			rollback tran
			return 70437 --Failed to update Bank Account
		end
		-----------
		COMMIT TRAN
		-----------
		return 50302 --Bank Account has been updated successfully
	end
	
	
end
GO
