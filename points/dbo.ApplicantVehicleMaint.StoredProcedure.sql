USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ApplicantVehicleMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure is use for capturing and processing
		of Applicant via front-end for existing Application/Card/Account

SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN		Desc
-------------------------------------------------------------------------------
2002/11/12 Jac			  	Initial development
2003/03/11 Sam				Enable for vehicle cardholder swap to new card.
2003/03/17 Sam				Check if duplicate vehicle captured on pending or approved status.
2003/06/26 Aeris			Add VehRegsNoPrefix and  VehRegsNoSuffix
2003/07/14 Aeris 			Check the vehregsNoprefix and VehRegsNoSuffix whether is compulsory
							fields
2003/09/12 Chew Pei			Make Vehicle Model to be optional
2004/07/16 Chew Pei			Added LastUpdDate
2005/07/27 Chew Pei			Added Subsidized Litre, Vehicle Class
2005/11/16 Chew Pei			Added Vehicle Remark (insert into iap_Applicant..VehRemark)
******************************************************************************************************************/
CREATE procedure [dbo].[ApplicantVehicleMaint]
	@IssNo uIssNo,
	@Func varchar(10),
	@AppcId uAppcId,
	--Add by Aeris B23/06/03
	@VehRegsNoPrefix nvarchar(4),
	@VehRegsNoSuffix nvarchar(6),
	--@VehRegsNo nvarchar(10),
	--Add by Aeris E23/06/03
	@VehRegsDate datetime,
	@Manufacturer uRefCd,
	@Model uModel,
	@Color uRefCd,
	@ManufacturerDate datetime,
	@VehSvc int,
	@VehRemark nvarchar(100),
	@RoadTaxExpiry datetime,
	@RoadTaxAmt money,
	@RoadTaxPeriod tinyint,
	@InsrcCmpy uRefCd,
	@PolicyNo nvarchar(20),
	@PolicyStartDate datetime,
	@PolicyExpiryDate datetime,
	@PremiumAmt money,
	@InsuredAmt money,
	@SubsidizedLitre money,
	@VehClass uRefCd,
	@LastUpdDate varchar(30)
  as
begin
	declare @PrcsName varchar(50),
		@CreationDate datetime,
		@rc int,
		@Msg varchar(80),
		@LatestUpdDate datetime

	set nocount on
--	select @PrcsName = 'ApplicantVehicleMaint'
--	exec TraceProcess @IssNo, @PrcsName, 'Start'

	----------------------------
	----- DATA VALIDATION ------
	----------------------------

	if isnull(@IssNo,0) = 0 return 55015		-- Mandatory field IssNo

	--2003/07/14B
	if exists (Select 1 from iap_Applicant a, iss_CardType b where a.IssNo = @IssNo and a.AppcId = @AppcId and a.CardType = b.CardType and b.VehInd = 'Y')
	Begin
	--2003/07/14E
		if @VehRegsNoPrefix is null or @VehRegsNoSuffix is null return 55159
		if @Manufacturer is null return 55071 -- Manufacturer is a compulsory field
		-- 2003/09/12B
		--if @Model is null return 55072	-- Vehicle model is a compulsory field
		-- 2003/09/12E
	End

	--2003/03/11B
	--if exists (select 1 from iap_Applicant where VehRegsNo = @VehRegsNo and AppcId <> @AppcId)
	--	return 65043	-- Vehicle Registration Number already exists

	--if exists (select 1 from iac_Vehicle where VehRegsNo = @VehRegsNo)
	--	return 65043	-- Vehicle Registration Number already exists
	--2003/03/11E

	--2003/03/17B
	if exists (select 1 from iap_Applicant where IssNo = @IssNo and VehRegsNoPrefix = @VehRegsNoPrefix and VehRegsNoSuffix = @VehRegsNoSuffix and AppcSts in ('P', 'A') and AppcId <> @AppcId)
		return 65043 --Vehicle Registration Number already exists

	if exists (select 1 from iac_Vehicle where VehRegsNoPrefix = @VehRegsNoPrefix and VehRegsNoSuffix = @VehRegsNoSuffix)
		return 65043	-- Vehicle Registration Number already exists
	--2003/03/17E

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
		set	-- Add VehRegsNoPrefix, VehRegsNoSuffix and combine the VehRegsNoSuffix+VehRegsNoPrefix to VehRegsNo by Aeris B23/06/03
			VehRegsNoPrefix = @VehRegsNoPrefix, VehRegsNoSuffix = @VehRegsNoSuffix, VehRegsNo = @VehRegsNoPrefix+@VehRegsNoSuffix, 
			-- Add VehRegsNoPrefix, VehRegsNoSuffix and combine the VehRegsNoSuffix+VehRegsNoPrefix to VehRegsNo by Aeris E23/06/03
			VehRegsDate = @VehRegsDate, Manufacturer = @Manufacturer, Model = @Model, Color = @Color, ManufacturerDate = @ManufacturerDate, 
			VehSvc = @VehSvc, RoadTaxExpiry = @RoadTaxExpiry, RoadTaxAmt = @RoadTaxAmt, RoadTaxPeriod = @RoadTaxPeriod, InsrcCmpy = @InsrcCmpy, 
			PolicyNo = @PolicyNo, PolicyStartDate = @PolicyStartDate, PolicyExpiryDate = @PolicyExpiryDate, PremiumAmt = @PremiumAmt, InsuredAmt = @InsuredAmt,
			SubsidizedLitre = @SubsidizedLitre, VehClass = @VehClass, VehRemark = @VehRemark,
			LastUpdDate = getdate()
		where IssNo = @IssNo and AppcId = @AppcId

		if @@error <> 0
		begin
			return 70144	-- 'Failed to update Applicant'
		end
	end
	else
	begin
		return 95307 -- Session Expired
	end
	return 50171
end
GO
