USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MircoSiteUserDataMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:

Objective	:Micro Site Data update & insert 

-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2013/09/13	Barnett			Initial Development
2013/11/20  Humairah		NewIC can accept null if passport<>null 
2015/06/24  Azan            Add checking to reject inactive cards
*******************************************************************************/
	
CREATE	procedure [dbo].[MircoSiteUserDataMaint]
	@CardNo uCardNo,
	@NewIc uNewIc,
	@PassportNo uPassportNo,
	@FamilyName uFamilyName,	
	@MobileNo uEmail,
	@EmailAddr nvarchar(80),
	@Gender char(1),
	@Race uRefCd,
	@PrefLanguage int,
	@PrefCommunication int,
	@Street1 nvarchar(100),
	@Street2 nvarchar(50),
	@Street3 nvarchar(50),
	@State uRefCd,
	@City nvarchar(100),
	@ZipCd uZipCd,
	@Ctry uRefcd,
	@VehicleType uRefCd,
	@VehicleEngCapacity uRefCd,
	@VehicleEngType uRefCd,
	@IncGrp uRefCd
  
as
begin

	declare @Nationality uRefCd
	
	
	------------------------------------------------------------------------------------------------
	-- Data Validation
	------------------------------------------------------------------------------------------------
	if isnumeric(@Cardno)= 0 return 95326 -- Invalid Card No
	if len(@CardNo) <> 17 return  95326 -- Invalid Card No
	if not exists(select 1 from iac_Card a (nolock) join iss_reflib b (nolock) on a.Sts = b.RefCd and b.RefType='CardSts' and b.RefInd = 0 where a.CardNo = @CardNo)  return  95326 -- Invalid Card No
	if @NewIC ='' and @PassportNo ='' return 95405 -- New IC and Old IC cannot be empty
	if Isnumeric(@NewIC) = 0 and @PassportNo ='' return 95406 -- New IC Only Contain Numeric   ---2013/11/20  Humairah
	if Isnumeric(@NewIC) = 1 and len(@NewIC) <> 12 return  95501 -- New IC must contain 12 Number ---2013/11/20  Humairah
	if @Gender not in ('M','F')  return 55039 -- Gender is a compulsory field
	if @EmailAddr <> '' and dbo.vaValidEmail(@EmailAddr) = 0 and len(@EmailAddr) <=6 return 95408 -- Invalid Email Format
	if len(@MobileNo) <= 5 or isnumeric(@MobileNo) = 0  return 95455 -- Invalid Contact No Length & Format
	if @Street1 ='' return 95106 -- Recipient Address 1 is a compulsory field
	if not exists (select 1 from iss_RefLib (nolock) where RefType = 'IncomeGrp' and RefCd =@IncGrp) return 55064 --Income is a compulsory field
	
	

	if (len(@NewIC) = 12) and (@PassportNo ='') 
	begin
			select @Nationality = '01'
	end
	else
	begin
			select @Nationality = '99'
	end
	
	------new New Message Code    -----------------------------------------------------------------
	if @FamilyName <>'' and len (@FamilyName) <=2 return 95636 -- FamilyName cannot be empty and must more than 2 character		
	if @NewIc ='' and len(@PassportNo) <= 5 return 95635 --if NewIC not available, PassportNo or other must More than 5 character
	if @Nationality ='01' and @Gender = 'F' and (substring(@NewIc, 12, 1)%2) <> 0  return 95633 -- Invalid Gender
	if @Nationality ='01' and @Gender = 'M' and (substring(@NewIc, 12, 1)%2) = 0  return  95633 -- Invalid Gender
	
	------------------------------------------------------------------------------------------------
	-- End Data Validation
	------------------------------------------------------------------------------------------------


		
	-----------------------
	Begin Transaction
	-----------------------
	
	-- Insert New Data
	if not exists (	select 1 from  Web_MircoSiteUserData where CardNo = @CardNo)
	begin
			
			
			insert Web_MircoSiteUserData(CardNo,NewIc,PassportNo,FamilyName,ContactNo,EmailAddr,Gender,Race,PrefLanguage,
						PrefCommunication,Street1,Street2,Street3,State,City,ZipCd,Ctry,LastUpdDate, VehicleType, VehicleEngCapacity, VehicleEngType, IncomeGroup)
			select @CardNo, @NewIc, @PassportNo, @FamilyName, @MobileNo, @EmailAddr, @Gender, @Race, @PrefLanguage, 
						@PrefCommunication, @Street1, @Street2, @Street3, @State, @City, @ZipCd, @Ctry, GETDATE(),
						@VehicleType, @VehicleEngCapacity, @VehicleEngType, @IncGrp
					
			if @@ERROR <> 0
			begin
					---------------------
					Rollback Transaction
					---------------------
					return	70183 --Failed to update Personality info
			end
	
	end
	else -- if CardNo already exists, update follow the cardno.
	begin
			update Web_MircoSiteUserData
			set CardNo = @CardNo,
				NewIc = @NewIc,
				PassportNo = @PassportNo,
				FamilyName = @FamilyName,
				ContactNo = @MobileNo,
				EmailAddr = @EmailAddr,
				Gender = @Gender,
				Race = @Race,
				PrefLanguage = @PrefLanguage,
				PrefCommunication = @PrefCommunication,
				Street1 = @Street1,
				Street2 = @Street2,
				Street3 = @Street3,
				State = @State,
				City = @City,
				ZipCd = @ZipCd,
				Ctry = @Ctry,
				LastUpdDate = GETDATE(),
				UpdateInd = null,
				VehicleType = @VehicleType, 
				VehicleEngCapacity = @VehicleEngCapacity, 
				VehicleEngType = @VehicleEngType,
				IncomeGroup = @IncGrp
			where CardNo = @CardNo
			
			if @@ERROR <> 0
			begin
					---------------------
					Rollback Transaction
					---------------------
					return	70183 --Failed to update Personality info
			end
			
	end
		
	-------------------
	commit transaction
	-------------------
	return 50164 -- Personal info has been saved successfully
	
end
GO
