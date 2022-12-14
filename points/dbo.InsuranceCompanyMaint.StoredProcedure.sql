USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[InsuranceCompanyMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To update edited insurance company info.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/03/08 Sam			   Initial development
2004/07/21 Alex			   Add LastUpdDate
*******************************************************************************/

CREATE procedure [dbo].[InsuranceCompanyMaint]
	@Func varchar(7),
	@IssNo uIssNo,
	@InsurNo smallint,
	@InsuranceCmpy uDescp50,
	@ShortDescp nvarchar(15),
	@Branch uRefCd,
	@RegsNo nvarchar(10),
	@BankAcctNo varchar(15),
	@Bank uRefCd,
	@LastUpdDate varchar(30)
  as
begin
	declare @LatestUpdDate datetime
	
	if @Func = 'Add'
	begin
		insert iss_InsuranceCompany
		( IssNo, Name, BranchLocation, ShortDescp, CoRegsNo, BankAcctNo, Bank, LastUpdDate )
		select @IssNo, @InsuranceCmpy, isnull(@Branch, 'HQ'), upper(@ShortDescp), upper(@RegsNo), @BankAcctNo, @Bank, getdate()
		if @@rowcount = 0 or @@error <> 0 return 70152
		return 50122
	end
	else
	if @Func = 'Save'
	begin

		if @LastUpdDate is null
			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

		select @LatestUpdDate = LastUpdDate from iss_InsuranceCompany where IssNo = @IssNo and InsuranceCmpy = @InsurNo
		if @LatestUpdDate is null
			select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

		-----------------
		begin transaction
		-----------------
	
		-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
		-- it means that record has been updated by someone else, and screen need to be refreshed
		-- before the next update.
		if @LatestUpdDate = convert(datetime, @LastUpdDate)
		begin
			update iss_InsuranceCompany
			set Name = @InsuranceCmpy,
				ShortDescp = upper(@ShortDescp),
				CoRegsNo = upper(@RegsNo),
				BankAcctNo = @BankAcctNo,
				Bank = @Bank,
				LastUpdDate = getdate()
			where IssNo = @IssNo and InsuranceCmpy = @InsurNo
			
			if @@rowcount = 0 or @@error <> 0 return 70153
			return 50123
			
		end
		else
		begin
			rollback transaction
			return 95307
		end

		------------------
		commit transaction
		------------------
	end
	delete iss_InsuranceCompany where IssNo = @IssNo and InsuranceCmpy = @InsurNo
	if @@rowcount = 0 or @@error <> 0 return 70154
	return 50124
end
GO
