USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[EntityMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************  
Copyright :CarDtrend Systems Sdn. Bhd.  
Modular  :CarDtrend Card Management System (CCMS)- Issuing Module  
  
Objective :To update existing entities.  
-------------------------------------------------------------------------------  
When    Who  CRN    Description  
-------------------------------------------------------------------------------  
2002/01/21 Wendy   Initial development  
2003/02/26 Sam			Adjustment.  
2004/07/14 Chew Pei		Add LastUpdDate  
2008/04/22 Peggy		Take out the DOB validation check.  
2009/03/29 Barnett		Add Race and Title  
2019/01/10 Humairah		Add iC Validation. Can re-use ic for 'Closed','Blocked','Suspended'   
2019/10/21 Azan			Alter new ic validation - check for IC exists and not closed 
						Add validation for old ic and passport number 
*******************************************************************************/  
  
CREATE procedure [dbo].[EntityMaint]  
 @EntityId uEntityId,  
 @IssNo uIssNo,  
 @FamilyName uFamilyName,  
 @GivenName nvarchar(50),  
 @Gender char(1),  
 @Marital char(1),  
 @Dob datetime,  
 @BloodGroup char(3),  
 @OldIc uOldIc,  
 @NewIc uNewIc,  
 @PassportNo uPassportNo,  
 @LicNo uLicNo,  
 @CmpyName uCmpyName,  
 @Dept nvarchar(30),  
 @Occupation char(3),  
 @Income int,  
 @BankName uRefCd,   
 @BankAcctNo varchar(12),  
 @PriEntityId uEntityId,  
 @Relationship uRefCd,  
 @LastUpdDate varchar(30),  
 @Race uRefCd,  
 @Title uRefCd,  
 @Nationality uRefCd  
  as  
begin  
-- if @GivenName is null  return 55038   
-- if @Marital is null  return 55040  
-- if @BloodGroup is null  return 55046       
-- if @OldIc is null  return 55043     
 if @NewIC is null and @OldIc is null and @PassportNo is null  return 95779 -- Identity number is a compulsory field                   
-- if @PassportNo is null  return 55044     
-- if @LicNo is null  return 55045     
-- if @CmpyName is null  return 55061  
-- if @Dept is null  return 55062  
-- if @Occupation is null  return 55063  
-- if @Income is null  return 55064     
-- if @BankName is null  return 55065  
-- if @BankAcctNo is null  return 55066                 
  
-- if isnull(@Race, '') = '' return 55274  -- Race is a compulsory field  
-- if isnull(@Title, '') = '' return 55275 -- Title is a compulsory field  
if @FamilyName is null return 55037     
if len(@NewIC) <12 return 95501 -- New IC must contain 12 Number  
if @Gender is null return 55039     
  
declare @LatestUpdDate datetime  
declare @IdentityType int 
declare @CardNo uCardNo

if isnull(@NewIc,'') <> '' set @IdentityType = 1 
else if isnull(@OldIc,'') <> '' set @IdentityType = 2
else if isnull(@PassportNo,'') <> '' set @IdentityType = 3

select @CardNo = CardNo from iac_Card where EntityId = @EntityId

set nocount on  

if isdate(@Dob) = 1  
begin  
-- 2003/02/26B  
if @Dob > getdate() return 95221  
--if (datediff(year, @Dob, getdate()) < 18) or (datediff(year, @Dob, getdate()) > 90) return 95221  
-- 2003/02/26E  
end  
  
if exists (select 1 from iac_Card a, iss_RefLib b where a.EntityId = @EntityId  
and b.IssNo = @IssNo and b.RefType = 'CardType' and b.RefCd = a.CardType and b.RefInd = 0)  
begin  
	if @DOB is null return 55041  
end  
  
if not exists (select 1 from iac_Entity where IssNo = @IssNo and Entityid = @EntityId) 
return 60031 -- Entity not found  
  
if @LastUpdDate is null  
select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))  
  
select @LatestUpdDate = LastUpdDate from iac_Entity where EntityId=@EntityId  
if @LatestUpdDate is null  select @LatestUpdDate = isnull(@LatestUpdDate, getdate())  
      
if isnull(@NewIc,'') <> '' 
begin 
	if ISNUMERIC(@NewIc) = 0
	begin 
		return 95811 -- Invalid IC Format	
	end											
	if ISNUMERIC(@NewIc) =1 and len(@NewIc)<>12 														
	begin
			
		return 95811 -- Invalid IC Format																
	end	

	if substring(@NewIc,1,2) not like '[0-9][0-9]'
	begin 
		return 95811 -- Invalid IC Format							
	end

	if cast(substring(@NewIc,3,2) as int) not between 1 and 12
	begin 
		return 95811 -- Invalid IC Format	 						
	end

	if cast(substring(@NewIc,5,2) as int) not between 1 and 31
	begin 
		return 95811 -- Invalid IC Format							
	end
		
	if  exists(select 1 
				from iac_Card c (nolock) 
				inner join iac_entity e (nolock) ON c.EntityId = e.EntityId  
				where c.EntityId <> @EntityId AND c.sts = 'A' AND e.NewIC = @NewIc)                                   
	begin    
		return 65116 -- IC Number already exist                       
	end  

	if exists(select 1 from [Demo_lms_web]..web_membership a (nolock) 
				join iac_Card b (nolock) on cast(a.Refkey as bigint) = b.CardNo 
				where b.CardNo <> @CardNo and b.Sts = 'A' and IdentityNumber = @NewIc and IdentityType = 1) 
	begin 
		return 65116  -- IC number already exist 
	end 
end

if isnull(@OldIc,'') <> '' 
begin
	if len(@OldIc) > 9
	begin 
		return 95785 -- Invalid old IC number length 
	end 

	if exists(select 1 
				from iac_Card c (nolock) 
				inner join iac_entity e (nolock) ON c.EntityId = e.EntityId  
				where c.EntityId <> @EntityId AND c.Sts = 'A' AND e.OldIc = @OldIc)
	begin 
		return 95786    -- Old Ic number already exist 
	end 

	if exists(select 1 from [Demo_lms_web]..web_membership a (nolock) 
				join iac_Card b (nolock) on cast(a.Refkey as bigint) = b.CardNo 
				where b.CardNo <> @CardNo and b.Sts = 'A' and a.IdentityNumber = @OldIc and a.IdentityType = 2) 
	begin 
		return 95786 -- Old IC number already exist		 
	end  
end

if isnull(@PassportNo,'') <> '' 		
begin 
	if exists(select 1 
				from iac_Card c (nolock) 
				inner join iac_entity e (nolock) ON c.EntityId = e.EntityId  
				where c.EntityId <> @EntityId AND c.Sts = 'A' AND e.PassportNo = @PassportNo)
	begin
		return 65131 --Passport number already exist 												
	end	
	if exists(select 1 from [Demo_lms_web]..web_membership a (nolock) 
				join iac_Card b (nolock) on cast(a.Refkey as bigint) = b.CardNo 
				where b.CardNo <> @CardNo  and b.Sts = 'A' and a.IdentityNumber = @PassportNo and a.IdentityType = 3) 
	begin 
		return 65131 --Passport number already exist 	 
	end   
end
  
 -- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate  
 -- it means that record has been updated by someone else, and screen need to be refreshed  
 -- before the next update.  
 

 if @LatestUpdDate = convert(datetime, @LastUpdDate)  
 begin  

  BEGIN TRANSACTION 


  update iac_Entity set    
   FamilyName = @FamilyName,   
   GivenName = @GivenName,   
   Gender = @Gender,   
   Marital = @Marital,   
   Dob = @Dob,   
   Bloodgroup = @BloodGroup,   
   OldIc = @OldIc,   
   NewIc = @NewIc,    
   PassportNo = @PassportNo,    
   LicNo = @LicNo,  
   CmpyName = @CmpyName,    
   Dept = @Dept,   
   Occupation = @Occupation,   
   Income = @Income,   
   BankName = @BankName,   
   BankAcctNo = @BankAcctNo,   
   PriEntityId = @PriEntityId,   
   Relationship = @Relationship,  
   LastUpdDate = getdate(),  
   Race = @Race,  
   Title = @Title,  
   Nationality = @Nationality  
  where EntityId=@EntityId  
    
  if @@error <> 0  
  begin  
   ROLLBACK TRANSACTION
   return 70110  
  end  

  if @IdentityType = 1
  begin 
		update a
		set a.IdentityNumber = @NewIc,
			a.IdentityType = @IdentityType 
		from [Demo_lms_web]..web_membership a (nolock)  
		where a.Refkey = cast(@CardNo as varchar(17))

		if @@error <> 0    
		begin    
			ROLLBACK TRANSACTION    
			return 70001    
		end  
  end 
  else if @IdentityType = 2
  begin 
		update a
		set a.IdentityNumber = @OldIc,
			a.IdentityType = @IdentityType 
		from [Demo_lms_web]..web_membership a (nolock) 
		where a.Refkey = cast(@CardNo as varchar(17))

		if @@error <> 0    
		begin    
			ROLLBACK TRANSACTION    
			return 70001    
		end  
  end
  else if @IdentityType = 3
  begin 
		update a
		set a.IdentityNumber = @PassportNo,
			a.IdentityType = @IdentityType 
		from [Demo_lms_web]..web_membership a (nolock) 
		where a.Refkey = cast(@CardNo as varchar(17))

		if @@error <> 0    
		begin    
			ROLLBACK TRANSACTION    
			return 70001    
		end  
  end

  COMMIT TRANSACTION 

  return 50071 --Updated successfully  
 end  
 else  
 begin  
  return 95307 -- Session Expired  
 end  
end
GO
