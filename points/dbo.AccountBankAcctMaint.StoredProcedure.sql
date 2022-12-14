USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AccountBankAcctMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*****************************************************************************************************************
Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Update account Bank Account Info.

-------------------------------------------------------------------------------
When		Who		CRN	Desc
-------------------------------------------------------------------------------
2003/07/03 	KY			Initial development
2004/07/14	Chew Pei		Add LastUpdDate
2005/09/16	Alex			Add Amt(Loan Amount)
******************************************************************************************************************/

CREATE procedure [dbo].[AccountBankAcctMaint]
	@Func varchar(10),
	@IssNo uIssNo,
	@AcctNo uAcctNo,
	@BankAcctNo uBankAcctNo,
	@AcctType uRefCd,
	@BankName uRefCd,
	@Id uApplId,
	@Amt money,
	@LastUpdDate varchar(30)
  as
begin
	declare @LatestUpdDate datetime

	if isnull(@IssNo,0) = 0
	return 0	--Mandatory Field IssNo

	if isnull(@AcctNo,'') = ''
	return 0	--Mandatory Field ApplId

	if isnull(@BankAcctNo,'') = ''
	return 55152	--Bank Account Number is a compulsory field

	if isnull(@AcctType,'') = ''
	return 55153	--Bank Account Type  is a compulsory field

	if isnull(@BankName,'') = ''
	return 55154	--Bank Name is a compulsory field

	if isnull(cast(@Amt as varchar(20)),'')=''
	return 55119 --Amount is a compulsory field

	if (select @Amt) <=0 return 95283 --Amount must be positive


	select @AcctType = RefCd from iss_RefLib
	where IssNo = @IssNo and RefType = 'BankAcctType' and Descp =  @AcctType

	select @BankName = RefCd from iss_RefLib
	where IssNo = @IssNo and RefType = 'Bank' and Descp = @BankName

	if @Func = 'Add'
	begin
		if exists (select 1 from iaa_BankAccount where IssNo = @IssNo and AcctNo = @AcctNo and BankAcctNo = @BankAcctNo and AcctType = @AcctType and BankName = @BankName)
		return 65048 	-- Bank Account Number already exist

		-----------------
		begin transaction
		-----------------
		insert into iaa_BankAccount (IssNo, AcctNo, BankAcctNo, AcctType, BankName, Amt, LastUpdDate)
		values	(@IssNo, @AcctNo, @BankAcctNo, @AcctType, @BankName, @Amt, getdate())

		if @@error <> 0	
		begin
			rollback transaction
			return 70436	-- Failed to create Bank Account
		end
		------------------
		commit transaction
		------------------

		return 50301	-- Bank Account has been inserted successfully
	end

	if @Func = 'Save'
	begin
		if not exists (select 1 from iaa_BankAccount where IssNo = @IssNo and AcctNo = @AcctNo and Id = @Id)
		return 60073	-- Bank Account not found

		if @LastUpdDate is null
			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

		select @LatestUpdDate = LastUpdDate from iaa_BankAccount where IssNo = @IssNo and AcctNo = @AcctNo and Id = @Id

		if @LatestUpdDate is null
			select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

		-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
		-- it means that record has been updated by someone else, and screen need to be refreshed
		-- before the next update.
		if @LatestUpdDate = convert(datetime, @LastUpdDate)
		begin

			-----------------
			begin transaction
			-----------------

			update iaa_BankAccount
			set	BankAcctNo = @BankAcctNo,
				AcctType = @AcctType,
				BankName = @BankName,
				Amt = @Amt,
				LastUpdDate = getdate()
			where IssNo = @IssNo and AcctNo = @AcctNo and Id = @Id

			if @@error <> 0
			begin
				rollback transaction
				return 70437	-- Failed to update Bank Account
			end
			------------------
			commit transaction
			------------------

			return 50302	-- Bank Account has been updated successfully
		end
		else
		begin
			return 95307
		end
	end
end
GO
