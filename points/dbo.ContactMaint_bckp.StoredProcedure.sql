USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ContactMaint_bckp]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
  
  
/******************************************************************************  
Copyright :CardTrend Systems Sdn. Bhd.  
Modular  :CardTrend Card Management System (CCMS)- Issuing Module  
  
Objective :To insert new or update existing contacts.  
-------------------------------------------------------------------------------  
When		Who			Description  
-------------------------------------------------------------------------------  
2002/01/22  Wendy		Initial development  
2003/06/19	KY			1103003 change @RefTo data length from 6 to uRefCd.  
2008/03/25	Peggy		Add PromoteInd field  
2015/12/30  Azan		Modify validation, exclude checking for email address exist at card level under same account  
2018/11/01	Humairah	Add contact maint on web_membership  
2019/05/09  Azan	    update email at web_membership according to change at iss_contact 	
*******************************************************************************/  
/*
DECLARE @RC int
EXEC @RC = ContactMaint 
	 @Func = 'save',  
	 @IssNo = 1,  
	 @RefTo = 'ENTT',  
	 @RefKey = '8337877',  
	 @RefCd = '13',  
	 @ContactName = NULL,  
	 @Occupation = NULL,  
	 @ContactNo = NULL,  
	 @Sts = 'A',  
	 @EmailAddr = 'ctstestcardmail@gmail.com',  
	 @PromoteInd = NULL,  
	 @LastUpdDate = NULL
select @RC
*/
CREATE  procedure [dbo].[ContactMaint_bckp]  
	 @Func varchar(5),  
	 @IssNo uIssNo,  
	 @RefTo uRefCd,  
	 @RefKey varchar(19),  
	 @RefCd uRefCd,  
	 @ContactName nvarchar(50),  
	 @Occupation uRefCd,  
	 @ContactNo uEmail,  
	 @Sts char(1),  
	 @EmailAddr nvarchar(80),  
	 @PromoteInd char(1),  
	 @LastUpdDate varchar(30)  
   as  
begin  
	declare   
		  @LatestUpdDate datetime,  
		  @AcctNo uAcctNo,  
		  @CardNo uCardNo,  
		  @Subject varchar(100),   
		  @Content varchar(max),   
		  @Email nvarchar(max) ,   
		  @Name nvarchar(max) ,   
		  @Id int,  
		  @RoleId uniqueidentifier ,  
		  @ParamValue nvarchar(128),  
		  @logid bigint  
  
	 if isnull(@IssNo,'') = ''  
	  return 0  --Mandatory field IssNo  
  
	 if isnull(@RefKey,'') = ''  
	  return 0 --Mandatory field RefKey  
  
	 if isnull(@RefTo,'') = ''  
	  return 0 --Mandatory field RefTo  
  
	 if isnull(@RefCd,'') = ''  
	  return 55089 --Contact Type Code is a compulsory field  
   
	 select @AcctNo = AcctNo , @CardNo = CardNo  
	 from iac_Card (nolock) where EntityId = @Refkey   
  
	 if exists
	 (  
		 select  1   
		 from iss_Contact a (nolock)   
		 join iac_card b (nolock) on b.EntityId = a.RefKey and b.CardNo <> @CardNo and b.Sts <> 'C'  
		 where a.RefTo = 'ENTT' and a.EmailAddr = @EmailAddr   
	 )  
	 begin  
	   return 65093 -- Email address already exists  
	 end  
  
	 if exists (select 1 from iss_default where Deft = 'EmailRefcd' and IntVal <> @RefCd)  
	 begin  
		  if isnull(@ContactNo,'') = ''  
		  return 55085 --Contact No. is a compulsory field  
	 end 
  


	 if @Func = 'Add'   
	 begin  

		if exists (select 1 from iss_Contact where IssNo = @IssNo and RefTo = @RefTo and RefKey = @RefKey and RefCd = @RefCd)   
		begin
			return 95035 -- Contact type already exist  
		end
		--------------------------------------------------------------------------------------------------------------------------------------------------
		BEGIN TRANSACTION  
		---------------------------------------------------------------------------------------------------------------------------------------------------

		insert into iss_Contact (IssNo, RefTo, RefKey, RefType, RefCd, ContactName, Occupation, ContactNo, Sts, EmailAddr, PromoteInd, LastUpdDate)  
		values (@IssNo, @RefTo, @RefKey, 'CONTACT', @RefCd, @ContactName, @Occupation, @ContactNo, isnull(@Sts, 'A'), @EmailAddr, @PromoteInd, getdate())  
		if @@error <> 0 
		begin
			ROLLBACK TRANSACTION
			return 70084 -- Failed to create  
		end
		if @RefCd = 13   
		begin     
			update [Demo_lms_web]..web_Membership 
				set Email = @EmailAddr 
			where Refkey = cast(@CardNo as varchar(17))

			if @@error <> 0   
			begin  
				ROLLBACK TRANSACTION
				return 70146 -- Failed to update  
			end  
		end
		--------------------------------------------------------------------------------------------------------------------------------------------------
		COMMIT TRANSACTION  
		--------------------------------------------------------------------------------------------------------------------------------------------------
		return 50075 -- Successfully added  
	end   
  
	 if @Func = 'Save'  
	 begin  

		  if not exists (select 1 from iss_Contact where IssNo = @IssNo and RefTo = @RefTo and RefKey = @RefKey and RefCd = @RefCd) 
		  begin 
			return 60025  
		  end
  
		 ---------------------------------------------------------------------------------------------------------------------------------------------------
		 BEGIN TRANSACTION  
		 ---------------------------------------------------------------------------------------------------------------------------------------------------
		  if @LastUpdDate is null select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))  
  
		  select @LatestUpdDate = LastUpdDate from iss_Contact where IssNo = @IssNo and RefTo = @RefTo and RefKey=@RefKey and RefCd=@RefCd  
   
		  if @LatestUpdDate is null select @LatestUpdDate = isnull(@LatestUpdDate, getdate())  
  
		  -- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate  
		  -- it means that record has been updated by someone else, and screen need to be refreshed  
		  -- before the next update.  
		  if @LatestUpdDate <= convert(datetime, @LastUpdDate)  
		  begin  
				update iss_Contact  
					set ContactName=@ContactName,   
					Occupation = @Occupation,   
					ContactNo=@ContactNo,   
					Sts=@Sts,   
					EmailAddr = @EmailAddr,  
					PromoteInd = @PromoteInd,  
					LastUpdDate = getdate()  
				where IssNo = @IssNo and RefTo = @RefTo and RefKey=@RefKey and RefCd=@RefCd  
   
				if @@error <> 0 
				begin
					ROLLBACK TRANSACTION
					return 70146 -- Failed to update  
				end

				if @RefCd = 13  
				begin  
					update [Demo_lms_web]..web_Membership 
						set Email = @EmailAddr
					where RefKey = cast(@CardNo as varchar(17))  

					if @@error <> 0   
					begin   
						ROLLBACK TRANSACTION  
						return 70146 -- Failed to update  
					end   
				end  
				--------------------------------------------------------------------------------------------------------------------------------------------------
				COMMIT TRANSACTION
				--------------------------------------------------------------------------------------------------------------------------------------------------      
				return 50075 -- Successfully added  
		  end  
		  else  
		  begin  
				ROLLBACK TRANSACTION
				return 95307 -- Session Expired  
		  end  
	 end  
end
GO
