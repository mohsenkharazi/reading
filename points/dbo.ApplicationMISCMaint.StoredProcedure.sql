USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ApplicationMISCMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************
Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This is the front end Application capturing procedure.

------------------------------------------------------------------------------------------------
When		Who		CRN	Desc
------------------------------------------------------------------------------------------------
2003/06/24 	KY		1103003	Initial development
2003/09/12	Chew Pei	Make @ApplIntroBy to be optional
						Added KTC BranchCd (BranchCd1)
2004/07/13	Chew Pei	Add LastUpdDate
******************************************************************************************************************/

CREATE procedure [dbo].[ApplicationMISCMaint]
	@Func varchar(10),
	@IssNo uIssNo,
	@ApplId uApplId,
	@RequiredReport char(1),
	@Pymt1 char(1),
	@Pymt2 char(2),
	@BankAcctNo uBankAcctNo,
	@Delivery1 char(1),
	@Delivery2 char(1),
	@BranchCd1 uRefCd,
	@BranchCd uRefCd,
	@Delivery3 char(1),
	@HandDelivery nvarchar(20),
	@Delivery4 char(1),
	@MailDelivery nvarchar(20),
	@ApplIntroBy uRefCd,
	@Name uFamilyName,
	@Title uRefCd,
	@CmpyType uRefCd,
	@CmpyName uCmpyName,
	@LastUpdDate varchar(30)
	
  as
begin
	declare @PymtMode char(1),
			@DeliveryType char(1),
			@SendingCd nvarchar(20),
			@LatestUpdDate datetime

	if isnull(@IssNo, 0) = 0
	return 0	-- Mandatory Field IssNo

	if isnull(@ApplId, '') = ''
	return 0	-- Mandatory Field ApplId

	if (@Pymt1 = 'N') and (@Pymt2 = 'N')
	return 55163 	-- Payment Method is a compulsory field

	if (@Pymt2 = 'Y') and isnull(@BankAcctNo, '') = ''
	return 55152 	-- Bank Account Number is a compulsory field

	if (@Delivery1 = 'N') and (@Delivery2 = 'N') and (@Delivery3 = 'N') and (@Delivery4 = 'N')
	return 55164 	-- Delivery Type is a compulsory field

	if (@Delivery1 = 'Y') and isnull(@BranchCd1, '') = ''
	return 55165 	-- Branch Code is a compulsory field

	if (@Delivery2 = 'Y') and isnull(@BranchCd, '') = ''
	return 55165 	-- Branch Code is a compulsory field

	if (@Delivery3 = 'Y') and isnull(@HandDelivery, '') = ''
	return 55166 	-- By Hand is a compulsory field

	if (@Delivery4 = 'Y') and isnull(@MailDelivery, '') = ''
	return 55167 	-- By Mail is a compulsory field

--	if isnull(@ApplIntroBy, 0) = 0
--	return 55168	-- Introduced By is a compulsory field

	if (@Pymt1 = 'Y')
		select @PymtMode = 'C', @BankAcctNo = null

	if (@Pymt2 = 'Y')
		select @PymtMode = 'D'
	
	-- Retrieve Sending Code from iss_Default and assign to @SendingCd 
	if (@Delivery1 = 'Y')
	begin
		select @SendingCd = Varcharval
		from iss_Default 
		where IssNo = @IssNo and Deft = 'SendingCdAtKTCDept'

		select @DeliveryType = 'K', @BranchCd = null, @SendingCd = @SendingCd
	end

	-- Retrieve Sending Code from iss_Default and assign to @SendingCd
	if (@Delivery2 = 'Y')
	begin
		select @SendingCd = Varcharval
		from iss_Default 
		where IssNo = @IssNo and Deft = 'SendingCdAtAgtBranch'

		select @DeliveryType = 'B', @BranchCd1 = null, @SendingCd = @SendingCd
	end

	if (@Delivery3 = 'Y')
		select @DeliveryType = 'H', @BranchCd1 = null, @BranchCd = null, @SendingCd = @HandDelivery

	if (@Delivery4 = 'Y')
		select @DeliveryType = 'R', @BranchCd1 = null, @BranchCd = null, @SendingCd = @MailDelivery

	if @Func = 'Save'
	begin		
		Select ApplId from iap_Application 
		where IssNo = @IssNo and ApplId = @ApplId

		if @@rowcount = 0 return 60022	-- Application not found

		-----------------
		begin transaction
		-----------------

		if @BranchCd1 is not null
			select @BranchCd = @BranchCd1

		update iap_Application
		set	RequiredReport = @RequiredReport,
			PymtMode = @PymtMode,
			BankAcctNo = @BankAcctNo,
			DeliveryType = @DeliveryType,
			BranchCd = @BranchCd,
			SendingCd = @SendingCd,
			ApplIntroBy = @ApplIntroBy
		where IssNo = @IssNo and ApplId = @ApplId

		if @@error <> 0
		begin
			rollback transaction
			return 70144	-- Failed to update Applicant
		end

		if exists (select 1 from iaa_Guarantor where IssNo = @IssNo and ApplId = @ApplId)
		begin

			if @LastUpdDate is null
				select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

			select @LatestUpdDate = LastUpdDate from iaa_Guarantor where IssNo = @IssNo and ApplId = @ApplId
			if @LatestUpdDate is null
				select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

			-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
			-- it means that record has been updated by someone else, and screen need to be refreshed
			-- before the next update.
			if @LatestUpdDate = convert(datetime, @LastUpdDate)
			begin
				update iaa_Guarantor
				set	Name = @Name,
					Title = @Title,
					CmpyType = @CmpyType,
					CmpyName = @CmpyName,
					LastUpdDate = getdate()
				where IssNo = @IssNo and ApplId = @ApplId

				if @@error <> 0
				begin
					rollback transaction
					return 70144	-- Failed to update Applicant
				end
			end
			else
			begin
				rollback transaction
				return 95307
			end
		end
		else
		begin
			insert into iaa_Guarantor
			(IssNo, AcctNo, ApplId, Name, Title, CmpyType, CmpyName, LastUpdDate)
			values 			 
			(@IssNo, null, @ApplId, @Name, @Title, @CmpyType, @CmpyName, getdate())
			
			if @@error <> 0
			begin
				rollback transaction
				return 70144	-- Failed to update Applicant
			end
		end
		------------------
		commit transaction
		------------------
		return 50169	-- Application has been updated successfully
	end

end
GO
