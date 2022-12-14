USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AccountBusnInfoMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO


/*****************************************************************************************************************
Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This is the front end Account capturing procedure.

------------------------------------------------------------------------------------------------
When		Who		CRN		Desc
------------------------------------------------------------------------------------------------
2003/07/02 	KY				Initial development
2003/10/17	Chew Pei			Trade No is a compulsory field
2003/12/08 	Aeris				Check trade no is compulsory for postpaid card only
2004/07/08	Chew Pei			Add LastUpdDate
2005/09/28	Chew Pei		Comment off @TradeNo validation
******************************************************************************************************************/

CREATE procedure [dbo].[AccountBusnInfoMaint]
	@Func varchar(10),
	@IssNo uIssNo,
	@AcctNo uAcctNo,
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
	@TradeNo nvarchar(15),
	@LegalDate datetime,
	@LastUpdDate varchar(30)
 
 as
begin
	declare @LatestUpdDate datetime

	if isnull(@IssNo, 0) = 0
	return 0	-- Mandatory Field IssNo

	if isnull(@AcctNo, '') = ''
	return 0	-- Mandatory Field ApplId

	if isnull(@CompanyType, '') = ''
	return 55156 	-- Company Type is a compulsory field

	if isnull(@CmpyRegsName1, '') = '' and isnull(@CmpyRegsName2, '') = ''
	return 55157 	-- Company Register Name is a compulsory field

	if isnull(@BusnCategory, '') = ''
	return 55158 	-- Business Category is a compulsory field

	--if isnull(@TradeNo, '') = ''
	--return 55193	-- Trade No is a compulsory field
--	if @TradeNo is null
--	begin
		/*if exists (select 1 from iac_Account a join iss_PlasticType b on a.IssNo = b.IssNo and a.CardLogo = b.CardLogo and a.PlasticType = b.PlasticType and PrepaidInd = 'Y')
			return 55193	--Trade No is a compulsory field*/
		--2003/12/08B
--		if exists (select 1 from iac_Account a 
--		join iss_PlasticType b on a.IssNo = b.IssNo and a.CardLogo = b.CardLogo and a.PlasticType = b.PlasticType 
--		where PrepaidInd = 'N' and a.AcctNo = @AcctNo)
--		return 55193	--Trade No is a compulsory field
		--2003/12/08E
--	end

	if @Func = 'Save'
	begin		
		Select AcctNo from iac_Account
		where IssNo = @IssNo and AcctNo = @AcctNo

		if @@rowcount = 0 return 60000	-- Account not found

		if @LastUpdDate is null
			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

		select @LatestUpdDate = LastUpdDate from iac_Account where AcctNo = @AcctNo
		if @LatestUpdDate is null
			select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

		-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
		-- it means that record has been updated by someone else, and screen need to be refreshed
		-- before the next update.
		-----------------
		begin transaction
		-----------------
		if @LatestUpdDate = convert(datetime, @LastUpdDate)
		begin
			update iac_Account
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
				TradeNo = @TradeNo,
				LastUpdDate = getdate()
				
			where IssNo = @IssNo and AcctNo = @AcctNo
		
			if @@error <> 0
			begin
				rollback transaction
				return 70124	--Failed to update Account
			end
		end
		else
		begin
			rollback transaction
			return 95307
		end 

		if isdate(@LegalDate) = 1
		begin
			update iac_AccountFinInfo
			set LegalDate = @LegalDate
			where IssNo = @IssNo and AcctNo = @AcctNo

			if @@error <> 0
			begin
				rollback transaction
				return 70124	--Failed to update Account

			end
		end

		------------------
		commit transaction
		------------------
		return 50091	--Account has been updated successfully
	end
end
GO
