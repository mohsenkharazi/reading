USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ApplicationBusnInfoMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************
Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This is the front end Application capturing procedure.

------------------------------------------------------------------------------------------------
When		Who		CRN		Desc
------------------------------------------------------------------------------------------------
2003/06/16 	KY		1103003	Initial development
2003/08/21	Chew Pei		Tax ID is mandatory
2003/10/17	Chew Pei		Trade No is mandatory
2003/10/21  Sam				Check trade no is compulsory for prepaid card only.
2003/12/08 	Aeris			Check trade no is compulsory for postpaid card only
2004/07/08	Chew Pei		Add LastUpdDate
2004/07/28	Chew Pei		Comment off LastUpdDate
2005/09/21 Chew Pei			Change 55162 to 55078 -- Company Registration Number is a compulsory field
2005/09/23 Chew Pei			Comment off Trade No validation, and all company related validation
******************************************************************************************************************/

CREATE procedure [dbo].[ApplicationBusnInfoMaint]
	@Func varchar(10),
	@IssNo uIssNo,
	@ApplId uApplId,
	@CompanyType uRefCd,
	@CmpyRegsName1 uCmpyName,
	@CmpyRegsName2 uCmpyName,
	@CmpyName1 uCmpyName,
	@CmpyName2 uCmpyName,
	@BusnCategory uRefCd,
	@RegsDate datetime,
	@Capital money,
	@NetSales money,
	@TaxId uTaxId,
	@RegsLocation nvarchar(30),
	@ShareHolder smallint,
	@NetProfit money,
	@TradeNo nvarchar(15)

--	@LastUpdDate varchar(30)

  as
begin
	declare @LatestUpdDate datetime

	set nocount on
	
	if isnull(@IssNo, 0) = 0
	return 0	-- Mandatory Field IssNo

	if isnull(@ApplId, '') = ''
	return 0	-- Mandatory Field ApplId

--	if isnull(@CompanyType, '') = ''
--	return 55156 	-- Company Type is a compulsory field

--	if isnull(@CmpyRegsName1, '') = '' and isnull(@CmpyRegsName2, '') = ''
--	return 55157 	-- Company Register Name is a compulsory field

--	if isnull(@BusnCategory, '') = ''
--	return 55158 	-- Business Category is a compulsory field

--	if isnull(@TaxId, '') = ''
--		return 55078 -- Company Registration Number is a compulsory field
	--return 55162 	-- Tax ID is a compulsory field
	

	--2003/10/21B
	--if isnull(@TradeNo, '') = ''
	--return 55193	-- Trade No is a compulsory field
	--2003/10/21E

--	if isnull(@CmpyName1, '') = ''
--	select @CmpyName1 = @CmpyRegsName1

/*	-- CP : 2005/09/21B 
	if isnull(@CmpyName2, '') = ''
	select @CmpyName2 = @CmpyRegsName2

	if @TradeNo is null
	begin
		--if exists (select 1 from iap_Application a join iss_PlasticType b on a.IssNo = b.IssNo and a.CardLogo = b.CardLogo and a.PlasticType = b.PlasticType and PrepaidInd = 'Y')
		--	return 55193	--Trade No is a compulsory field
		--2003/12/08B
		if exists(select 1 from iap_Application a 
		join iss_PlasticType b on a.IssNo = b.IssNo and a.CardLogo = b.CardLogo and a.PlasticType = b.PlasticType 
		where PrepaidInd = 'N' and a.ApplId = @ApplId)
		return 55193	--Trade No is a compulsory field
		--2003/12/08E
	end
*/ -- CP 2005/09/23E

	if @Func = 'Save'
	begin		
		Select ApplId from iap_Application 
		where IssNo = @IssNo and ApplId = @ApplId

		if @@rowcount = 0 return 60022	-- Application not found
		-----------------
		begin transaction
		-----------------

/*		if @LastUpdDate is null
			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

		select @LatestUpdDate = LastUpdDate from iap_Application where IssNo = @IssNo and ApplId = @ApplId
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
*/
		update iap_Application
		set	CmpyType = @CompanyType,
			CmpyRegsName1 = @CmpyRegsName1,
			CmpyRegsName2 = @CmpyRegsName2,
			CmpyName1 = @CmpyName1,
			CmpyName2 = @CmpyName2,
			BusnCategory = @BusnCategory,
			RegsDate = @RegsDate,
			Capital = @Capital,
			NetSales = @NetSales,
			TaxId = @TaxId,
			RegsLocation = @RegsLocation,
			ShareHolder = @ShareHolder,
			NetProfit = @NetProfit,
			TradeNo = @TradeNo			
			--LastUpdDate = getdate()
		where IssNo = @IssNo and ApplId = @ApplId

		if @@error <> 0
		begin
			rollback transaction
			return 70144	-- Failed to update Applicant
		end
/*		end
		else
		begin
			rollback transaction
			return 95307
		end
*/
		------------------
		commit transaction
		------------------
		return 50169	-- Application has been updated successfully
	end

end
GO
