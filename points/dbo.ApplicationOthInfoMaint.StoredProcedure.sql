USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ApplicationOthInfoMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	:Add The Application Other Info.

-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2005/09/19 	Alex				Initial development
2005/11/07	Chew Pei			Commented @Invoice & @Monthly
2005/11/14	KY				New fields added (Ic & Relationship)
2005/11/24	Chew Pei		Commented update of BillingType
2006/05/24	Chew Pei		Added BusnUnit, Dept, VoteNo, POId (for Tafis)
*******************************************************************************/
	
CREATE procedure [dbo].[ApplicationOthInfoMaint]
	@Func varchar(10),
	@IssNo uIssNo,
	@ApplId uApplId,
	@AcctType char(1),
	@BankAcctNo uBankAcctNo,
	@PymtAmt money,
	@CostCentreRpt char(1),
	@FleetRpt char(1),
	@ByDriver char(1),
	@ByVehicle char(1),
--	@Invoice char(1), 
--	@Monthly char(1),
	@FullAmt char(1),
	@MinPymt char(1),
	@FixedAmt char(1),
	@Title	uRefCd,
	@Name uFamilyName,
	@Ic uNewIc,
	@Relationship uDescp50,
	@BusnUnit uRefCd,
	@DeptId uRefCd,
	@VoteNo varchar(10),
	@POId varchar(10)
  as
begin

	declare @RequiredReport smallint,
		@DeliveryType char(1),
		@BillingType  char(1),
		@PymtMode char(1)

	--Set @RequiredReport
	---------------------
	if (@CostCentreRpt ='Y' and @FleetRpt='Y')
	begin
		Select @RequiredReport = 3
	end
	else if (@CostCentreRpt ='Y' and @FleetRpt='N')
	begin	
		Select @RequiredReport = 2
	end
	else if (@CostCentreRpt ='N' and @FleetRpt='Y')
	begin
		Select @RequiredReport = 1
	end
	else
		Select @RequiredReport = 0
	
	--Set @DeliveryType
	if(@ByDriver ='Y') 
		select @DeliveryType = 'D'
	if (@ByVehicle='Y')
		select @DeliveryType ='V'
	
	--SET @BillingType	
/*	if (@Invoice ='Y')
		select @BillingType ='I'
	if (@Monthly ='Y')
		select @BillingType ='M'
*/
	--SET @PymtMode	
	if (@FullAmt ='Y') 
		select @PymtMode ='F'
	if (@MinPymt='Y')
		select @PymtMode ='M'
	if (@FixedAmt ='Y')
		select @PymtMode ='X'


	--Guarantor Validation Check
	if exists(select 1 where @Title is not null and @Name is null)
		return 55141	-- Name is a compulsory field

	if exists(select 1 where @Name is not null and @Title is null)
		return 55132 -- Title is a compulsory field

	if not exists (select 1 from iap_Application where ApplId = @ApplId and (isnull(@BankAcctNo, '')='' and isnull(@AcctType,'')='' and isnull(@PymtMode,'')='') )
	begin

		if (select @PymtMode ) is null 
		return 55163 -- Payment Method is a compulsory field

		if (isnull(@BankAcctNo, '')='') 
		return 55152 	-- Bank Account Number is a compulsory field

		if (isnull(@AcctType,'') = '') 
		return 55153 	-- Bank Account Type  is a compulsory field

		if ((select @PymtMode)='X' )
		begin
			if (select @PymtAmt) is null
			return 55119 -- Amount is a compulsory field

			else if ((select @PymtAmt)<=0 )
			return 95283-- Amount must be positive
		end
	end
	

	
	-----------------
	begin Transaction
	-----------------
	update iap_Application
	set  RequiredReport = @RequiredReport,
	     DeliveryType = @DeliveryType,
	     AcctType = @AcctType,
	     BankAcctNo = @BankAcctNo,
	   --  BillingType = @BillingType,
	     PymtMode = @PymtMode,
	     PymtAmt = isnull(@PymtAmt,0),
		 BusnUnit = @BusnUnit,
		 DeptId = @DeptId,
		 VoteNo = @VoteNo,
		 POId = @POId
	where ApplId = @ApplId and IssNo = @IssNo

	if @@error <> 0
	begin
		rollback transaction
		return 70144	-- Failed to update Applicant
	end

	if not exists(select 1 from iaa_Guarantor where ApplId = @ApplId)
	begin
		insert iaa_Guarantor(IssNo, AcctNo, ApplId, Name, Title, Ic, Relationship, CmpyType, CmpyName,LastUpdDate)
	 	values(@IssNo, null, @ApplId, @Name, @Title, @Ic, @Relationship, null, null, getdate() )
		
		
		if @@error <> 0
		begin
			rollback transaction
			return 70441	-- Failed to update Guarantor Details
		end
	end
	else
	begin
		update iaa_Guarantor
		set Title = @Title, Name = @Name, Ic = @Ic, Relationship = @Relationship
		where ApplId = @ApplId and Issno = @IssNo 

		if @@error <> 0
		begin
			rollback transaction
			return 70441	-- Failed to update Guarantor Details

		end
	end
	

	------------------
	commit transaction
	------------------
	return 50169	-- Application has been updated successfully
end
GO
