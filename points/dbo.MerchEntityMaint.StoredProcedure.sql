USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchEntityMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Merchant/ Business Location entity maintenance.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/08 Sam			   Initial development
2003/02/26 Sam			   Adjustment
2004/07/21 Alex			   Add LastUpdDate
*******************************************************************************/

CREATE procedure [dbo].[MerchEntityMaint]
	@AcqNo uAcqNo,
	@EntityId uEntityId,
	@LicNo uLicNo,
	@BankAcctNo uBankAcctNo,
	@BankName uRefCd,
	@Blood uRefCd,
	@Dob datetime,
	@Dept uRefCd,
	@FamilyName uFamilyName,
	@GivenName uGivenName,
	@Gender uRefCd,
	@Income int,
	@Marital uRefCd,
	@NewIc uNewIc,
	@OldIc uOldIc,
	@Occupation uRefCd, 
	@Passport uPassportNo,
	@Title uRefCd,
	@LastUpdDate varchar(30)
  as
begin
	declare @BusnLocation uMerch, @AcctNo uAcctNo, @LatestUpdDate datetime
	set nocount on

	select @BusnLocation = BusnLocation
	from aac_BusnLocation where EntityId = @EntityId

	if @@rowcount = 0 or @@error <> 0
	begin
		select @AcctNo = AcctNo
		from aac_Account where EntityId = @EntityId

		if @@rowcount = 0 or @@error <> 0 return 60031 --Entity not found

		if not exists (select 1 from aac_Account a join iss_RefLib b on a.AcqNo = b.IssNo and a.Sts = b.RefCd and b.RefType = 'MerchAcctSts' and b.RefInd = 0)
			return 95090 --Account not active
	end
	else
	begin
		if not exists (select 1 from aac_BusnLocation a join iss_RefLib b on a.AcqNo = b.IssNo and a.Sts = b.RefCd and b.RefType = 'MerchAcctSts' and b.RefInd = 0)
			return 95132 --Invalid Business Location status
	end

	if @FamilyName is null return 55037
--	if @Gender is null return 55039
--	if @OldIc is null and @NewIc is null return 55042
--	if (@BankName is not null and @BankAcctNo is null) or (@BankName is null and @BankAcctNo is not null) return 55066

	-- 2003/02/26B
	if @Dob is not null
	begin
		if @Dob > getdate() return 95221
		if datediff(year, @Dob, getdate()) < 18 return 95221
	end
	-- 2003/02/26E

	if @LastUpdDate is null
		select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

	select @LatestUpdDate = LastUpdDate from aac_Entity where AcqNo = @AcqNo and EntityId = @EntityId
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
		update aac_Entity
		set FamilyName = @FamilyName,
			GivenName = @GivenName,
			Gender = @Gender,
			Marital = @Marital,
			Dob = @Dob,
			Blood = @Blood,
			OldIc = @OldIc,
			NewIc = @NewIc,
			Passport = @Passport,
			LicNo = @LicNo,
			Dept = @Dept,
			Occupation = @Occupation,
		 	Income = @Income,
			BankName = @BankName,
			BankAcctNo = @BankAcctNo,
			Title = @Title,
			LastUpdDate = getdate()
		where AcqNo = @AcqNo and EntityId = @EntityId
	
		if @@rowcount = 0 or @@error <> 0
		begin
			rollback transaction
			return 70110 -- fail to uppdate file
		end
		
	end
	else
	begin
		rollback transaction
		return 95307
	end
	------------------
	commit transaction
	------------------
	return 50071 --Updated successfully
end
GO
