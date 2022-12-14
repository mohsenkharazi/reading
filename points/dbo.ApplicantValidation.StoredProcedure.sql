USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ApplicantValidation]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module
Objective	:Applicant validation

drop procedure ApplicantValidation
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2003/07/01 Aeris           	Initial Development
2003/07/14 Aeris            Change the checking for the vehicle no
2003/09/22 Chew Pei			Make @Model to be optional 
							Make @Manufacturer to be mandatory
						
*******************************************************************************/

CREATE procedure [dbo].[ApplicantValidation]
	@IssNo uIssNo,
	@AppcId uAppcId
  as
Begin
	Set nocount on

	declare @CardCategory uRefCd,
		@VehregsNo uVehRegsNo,
		@Manufacturer uRefCd,
		@Dept nvarchar(30),
		@Model uModel,
		@Pin char(1),
		@EmbName uEmbName


	/*select @CardCategory = a.CardCategory from iss_CardType a, iap_Applicant b where b.IssNo = @IssNo and b.AppcId = @AppcId and a.CardType = b.CardType and a.VehInd = 'y'  
	if @CardCategory = 'b'
	Begin
  		select @VehregsNo = Vehregsno from iap_Applicant where IssNo = @IssNo and AppcId = @AppcId
			if isnull (@VehRegsNo, '') = '' return 55107 --Vehicle registration number is a compulsory field

	End
	else	
		Begin
			select @Model = Model from iap_Applicant where IssNo = @IssNo and AppcId = @AppcId
				if isnull(@Model, '') = '' return 55174 -- Vehicle model is a compulsory field where
									-- cardcategory is G, I
	
		End -- Comment off by aeris 2003/07/14*/

	--2003/07/14B
	if exists (Select 1 from iap_Applicant a ,iss_CardType b where a.AppcId = @AppcID and a.CardType = b.CardType and b.VehInd = 'Y')
	Begin
		select @VehregsNo = Vehregsno, @Manufacturer = Manufacturer, @Model = Model from iap_Applicant where IssNo = @IssNo and AppcId = @AppcId
			if isnull (@VehRegsNo, '') = '' return 55107 --Vehicle registration number is a compulsory field
			if isnull (@Manufacturer, '') = '' return 55071 --Vehicle Manufacturer is a compulsory field
			--if isnull(@Model, '') = '' return 55174 -- Vehicle model is a compulsory field 
	End 
	--2003/07/14E
	
	select @CardCategory = a.CardCategory, @Dept = b.dept, @Pin = b.PinInd, @EmbName = b.EmbName from iss_CardType a, iap_Applicant b where b.IssNo = @IssNo and b.AppcId = @AppcId and a.CardType = b.CardType
	/*if @CardCategory <> 'b'
		begin
			if isnull (@Dept, '') = '' return 55062 -- Department is a compulsory field where
									-- cardcategory is G, I
		end*/ --comment off by aeris 2003/07/28

	--if @Pin = 'N' return 55058 --pin Indicator is a compulsory field

	if isnull(@EmbName, '') = '' return 55059 --Emboss name is a compulsory field


End
GO
