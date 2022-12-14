USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ApplicantOtherMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure use for capturing and processing
		of Applicant via front-end for existing Application/Card/Account

SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN		Desc
-------------------------------------------------------------------------------
2002/11/12 Jac			  	Initial development
2003/07/08 Aeris			Add the checking for Dept according the 
					Category
2004/07/16 Chew Pei			Added LastUpdDate
******************************************************************************************************************/
CREATE  procedure [dbo].[ApplicantOtherMaint]
		@IssNo uIssNo,
		@Func varchar(10),
		@AppcId uAppcId,
		@CmpyName uCmpyName,
		@Dept nvarchar(30),
		@Occupation uRefCd,
		@Income int,
		@BankName uRefCd,
		@BankAcctNo varchar(12),
		@LastUpdDate varchar(30)
  as
begin
	declare @PrcsName varchar(50),
		@rc int,
		@Msg varchar(80),
		@CardCategory uRefCd,
		@LatestUpdDate datetime

	select @PrcsName = 'ApplicantOtherMaint'

	exec TraceProcess @IssNo, @PrcsName, 'Start'
	----------------------------
	----- DATA VALIDATION ------
	----------------------------

	if isnull(@IssNo,0) = 0 return 55015		-- Mandatory field IssNo

	--Add by Aeris 08/07/03B
	select @CardCategory = CardCategory from iap_applicant a, iss_CardType b where a.CardType = b.CardType and a.AppcID =@AppcId 
	if @CardCategory <> 'B'
		if isnull(@Dept,'') = '' return 55062 --Dept is a compulsory field when the card category is not b

	--Add by Aeris 08/07/03E
--	if isnull(@CmpyName,'') = '' return 55061
	
--	if isnull(@Dept,'') = '' return 55062

--	if isnull(@Occupation,'') = '' return 55063

--	if isnull(@Income,0) = 0 return 55064

--	if isnull(@BankName,'') = '' return 55065

--	if isnull(@BankAcctNo,0) = 0 return 55066

	if @LastUpdDate is null
		select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

	select @LatestUpdDate = LastUpdDate from iap_Applicant where IssNo = @IssNo and AppcId = @AppcId
	if @LatestUpdDate is null
		select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

	-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
	-- it means that record has been updated by someone else, and screen need to be refreshed
	-- before the next update.
	if @LatestUpdDate = convert(datetime, @LastUpdDate)
	begin
		update iap_Applicant
		set	CmpyName = @CmpyName, Dept = @Dept,
			Occupation = @Occupation, Income = @Income,
			BankName = @BankName, BankAcctNo = @BankAcctNo
		where	IssNo = @IssNo and AppcId = @AppcId

		if @@error <> 0
		begin
			rollback transaction
			return 70144	-- 'Failed to update Applicant'
		end
	end
	else
	begin
		rollback transaction
		return 95307 -- Session Expired
	end
	return 50171
end
GO
