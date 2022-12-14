USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ChangeOwnershipCard]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************  
Copyright :CardTrend Systems Sdn. Bhd.  
Modular  :ADPAC  
Objective :Change Card Ownership Backend Development
-------------------------------------------------------------------------------  
When  Who  CRN  Description  
------------------------------------------------------------------------------- 
2019/12/17  Azan		Initial development  
2019/08/07  Azan		Add @Remark 
2020/02/11  Azan        Add Validation 
						- Reject change onwnership if card is STAFF card or CLP card. 
2020/02/13  Azan		Insert into iss_CardEventAuditLog 
******************************************************************************************************************/  
/*
declare @rc int
exec @rc = [ChangeOwnershipCard]			
					@MediaId = 70838155102752568,		
					@CardHolderName	= 'Change Ownership Test 3',	
					@EmailAddress = 'testchangeownership3@gmail.com',		
					@IdentityType = 'newic',		
					@IdentityNumber	= '890911035568',
					@MobileNumber = '0145365167',	
					@Password = 'RziKrB0cKiMi0cj1J6i6/Q==',	
					@Remark = 'CASE342532642642642577'
select @rc
*/

CREATE PROCEDURE [dbo].[ChangeOwnershipCard] 
	@MediaId uCardNo,
	@CardHolderName uFamilyName,
	@EmailAddress nvarchar(80),
	@IdentityType varchar(10),
	@IdentityNumber varchar(25),
	@MobileNumber varchar(20),
	@Password varchar(200)='',
	@Remark varchar(100)=''
AS
BEGIN 
	SET NOCOUNT ON  
	
	declare  @ResponseCode int = 95814, -- Change ownership completed successfully
			 @IssNo uIssNo,
			 @PrcsId uPrcsId,
			 @dtNow datetime,
			 @CurrentIdentityTypeCode int,
			 @CurrentIdentityNumber varchar(50),
			 @CurrentAcctNo uAcctNo,
			 @CurrentNoOfRecord integer,
			 @CurrentEntityId uEntityId,
			 @vCurrentEntityId varchar(20),
			 @CurrentMobileNo varchar(20),
			 @CurrentEmailaddress uEmail,
			 @Gender char(1),
			 @IdentityTypeCode int,
			 @RoleName nvarchar(255),
			 @RoleId uniqueidentifier,
			 @ApplId uApplId,
			 @Id varchar(max),
			 @OtherMediaId uCardNo,
			 @OtherAcctNo uAcctNo,
			 @Descp varchar(50),
			 @Identity int,
			 @SourceId uRefCd,
			 @Refkey nvarchar(20),
			 @rowcount int,
			 @rc int,
			 @CardEventBatchId int,
			 @OperationId int,
			 @WebId uniqueidentifier

	--------------------------------------------------------------------------------------------------------------------
	--------------------------------- RETRIEVES NECESSARY INFORMATION FOR PROCESSING -----------------------------------
	--------------------------------------------------------------------------------------------------------------------
	set @IssNo =1
	set @RoleName = 'CARD'
	SET @dtNow = getDate()
	select @PrcsId = CtrlNo from iss_Control (nolock) where IssNo = @IssNo and CtrlId = 'PrcsId'
	select @SourceId = RefCd from iss_Reflib (nolock) where Reftype = 'ApiSourceId' and Descp = 'Mesralink'
	select @OperationId = OperationId from [Demo_lms_web]..sec_Operation (nolock) where OperationName = 'Change Ownership'

	create table #CardNo(
	Ids int identity(1,1),
	AcctNo bigint,
	CardNo bigint,
	LastPurchasedDate Date  
	)
	
	set @Descp = 'Change ownership (Mesralink)'

	--Validate Media Id----------------------------------------------------------------------------------------------------
	if @MediaId is null  
	begin	
		set @ResponseCode =  95326 ---Invalid card number
		goto ResponseExit;
	end

	if not exists(select 1 from iac_Card (nolock) where CardNo = @MediaId)  
	begin	
		set @ResponseCode =  95326 ---Invalid card number
		goto ResponseExit;
	end 	

	if not exists(select 1 from iac_Card (nolock) where CardNo = @MediaId and Sts in ('A'))  
	begin	
		set @ResponseCode =  95064 ---Check on card status
		goto ResponseExit;
	end

	if exists(select 1 from iac_Card (nolock) where CardNo = @MediaId and CardType in (2,5,7,3,18,24)) -- STAFF and CLP card are not allowed for change ownership 
	begin 
		set @ResponseCode = 95029 --- Card Type is not valid  
		goto ResponseExit;
	end  

	if not exists(select 1 from iac_Card c (nolock) join iac_Account a (nolock) on c.AcctNo = a.AcctNo where c.CardNo = @MediaId and a.Sts ='A')
	begin	
		set @ResponseCode =  95090 ---Account is not active
		goto ResponseExit;
	end

	--Validate CardHolder Name---------------------------------------------------------------------------------------------------
	if @CardHolderName is null OR rtrim(ltrim(@CardHolderName))=''
	begin
		set @ResponseCode = 55141 -- Name is a compulsory field	
		goto ResponseExit;														
	end		

	--Validate Email Address---------------------------------------------------------------------------------------------------
	if len(@EmailAddress)>0
	begin											        
		if @emailAddress not like '%_@_%._%'  	
		begin
			set @ResponseCode =  95408  --Invalid Email Format
			goto ResponseExit;
		end
		if exists (select 1 
						from iac_Card a (nolock) 
						join (
						select cast(con.RefKey as int) 'EntityId'
						from iss_contact con (nolock) 
						join iss_Reflib ref (nolock) on ref.RefCd = con.RefCd and ref.IssNo = @IssNo and ref.RefType = 'Contact' and Ref.Descp = 'Email'
						where con.RefTo = 'ENTT' and con.RefType = 'CONTACT' and con.EmailAddr = @emailAddress
						) as b on a.EntityId = b.EntityId and a.Sts <> 'C')
		begin
			set @ResponseCode =  65093  -- Email address already exist
			goto ResponseExit;															
		end	
		if exists(select 1 from [Demo_lms_web]..web_membership a (nolock)
					join iac_Card b (nolock) on cast(a.Refkey as bigint) = b.CardNo and b.Sts <> 'C'
					where a.Email = @emailAddress) 
		begin
			set @ResponseCode =  65093  -- Email address already exist
			goto ResponseExit;																
		end	
	end
	--Validate Identity Number---------------------------------------------------------------------------------------------------
	if isnull(@IdentityNumber,'') = ''
	begin 
		set @ResponseCode = 95779 -- Identity number is a compulsory field
		goto ResponseExit;
	end

	if len(@IdentityNumber) <= 5
	begin 
		set @ResponseCode = 95791 -- Identity Number should be more than 5 characters
		goto ResponseExit;
	end
	--Validate Identity Type---------------------------------------------------------------------------------------------------
	if @IdentityType is null OR rtrim(ltrim(@IdentityType))=''
	begin
		set @ResponseCode = 95777 -- Invalid Identity Type
		goto ResponseExit;
	end

	if not exists(select 1 from iss_Reflib a (nolock) where RefType = 'IdentityType' and Descp =  @IdentityType)  
	begin	
		set @ResponseCode =95777 -- Invalid Identity Type
		goto ResponseExit;
	end

	select @IdentityTypeCode = RefCd 
	from iss_Reflib 
	where RefType = 'IdentityType' and Descp =  @IdentityType

	--Validate New Ic---------------------------------------------------------------------------------------------------
	if @IdentityTypeCode = 1
	begin 
		if ISNUMERIC(@IdentityNumber) = 0
		begin 
			set @ResponseCode = 95811   -- Invalid IC Format
			goto ResponseExit;	
		end											
		if ISNUMERIC(@IdentityNumber) =1 and len(@identityNumber)<>12 														
		begin
			set @ResponseCode = 95811   -- Invalid IC Format
			goto ResponseExit;																
		end	

		if substring(@IdentityNumber,1,2) not like '[0-9][0-9]'
		begin 
			set @ResponseCode = 95811   -- Invalid IC Format
			goto ResponseExit;							
		end

		if cast(substring(@IdentityNumber,3,2) as int) not between 1 and 12
		begin 
			set @ResponseCode = 95811   -- Invalid IC Format
			goto ResponseExit;							
		end

		if cast(substring(@IdentityNumber,5,2) as int) not between 1 and 31
		begin 
			set @ResponseCode = 95811  -- Invalid IC Format
			goto ResponseExit;							
		end

		if exists(select 1 from iac_Card a (nolock) join iac_entity b (nolock) on b.EntityId = cast(a.EntityId as varchar) where a.sts <> 'C' and b.NewIc = @identityNumber)                               
		begin
			set @ResponseCode = 65116  -- IC Number already exist
			goto ResponseExit;
		end	

		if  (substring(@identityNumber, 12, 1)%2) = 0 
		begin
			set @Gender = 'F'
		end
		else if  (substring(@identityNumber, 12, 1)%2) > 0
		begin
			set @Gender = 'M'
		end
	end 

	--Validate old ic----------------------------------------------------------------------------------------------------
	if @IdentityTypeCode = 2
	begin                                
		if exists(select 1 from iac_Card a (nolock) join iac_entity b (nolock) on b.EntityId = cast(a.EntityId as varchar) where a.sts <> 'C' and b.OldIc = @identityNumber) 
		begin			
			set @ResponseCode = 95786  -- Old IC number already exist
			goto ResponseExit;														
		end	
	end 
	
	--Validate passport number----------------------------------------------------------------------------------------------------
	if @IdentityTypeCode = 3
	begin                       
		if exists(select 1 from iac_Card a (nolock) join iac_entity b (nolock) on b.EntityId = cast(a.EntityId as varchar) where a.sts <> 'C' and b.PassportNo = @identityNumber) 
		begin
			set @ResponseCode = 65131  --Passport number already exist 
			goto ResponseExit;																		
		end
	end  

	--Validate legal document Id----------------------------------------------------------------------------------------------------
	if @IdentityTypeCode = 4
	begin                             
		if exists(select 1 from iac_Card a (nolock) join iac_entity b (nolock) on b.EntityId = cast(a.EntityId as varchar) where a.sts <> 'C' and b.LegalDocumentId = @identityNumber) 
		begin
			set @ResponseCode = 95789  --Legal Document Id already exists
			goto ResponseExit; 																
		end
	end

	--Validate Mobile Number--------------------------------------------------------------------------------------------------------
	if isnull(@MobileNumber,'') = '' 
	begin
		set @ResponseCode = 60025 --Contact Number not found
		goto ResponseExit;	
	end

	if ISNUMERIC(@MobileNumber) = 0 or LEN(@MobileNumber) < 10 
	begin
		set @ResponseCode = 95455 --Invalid contact no, length or format
		goto ResponseExit;	
	end
	---------------------------------------------------------------------------------------------------------------------------------
	select	
		@CurrentIdentityNumber = case 
									when isnull(e.NewIc,'') <> '' then e.NewIc 
									when isnull(e.OldIc,'') <> '' then e.OldIc
									when isnull(e.PassportNo,'') <> '' then e.PassportNo
									when isnull(e.LegalDocumentId,'') <> '' then e.LegalDocumentId
								 end,
		@CurrentIdentityTypeCode = case 
									when isnull(e.NewIc,'') <> '' then 1
									when isnull(e.OldIc,'') <> '' then 2
									when isnull(e.PassportNo,'') <> '' then 3
									when isnull(e.LegalDocumentId,'') <> '' then 4
								 end, 
		@CurrentEntityId  = c.EntityId, 
		@CurrentAcctNo = c.AcctNo
	from  iac_Card  c (nolock)
	inner join iac_Entity e (nolock) on e.EntityId = c.EntityId
	where c.cardno=@MediaId

	select @vCurrentEntityId = cast(@CurrentEntityId as varchar)

	if isnull(@CurrentIdentityNumber,'') = ''
	begin 
		set @ResponseCode = 95403 
		goto ResponseExit;
	end 

	if @CurrentIdentityTypeCode =  1
	begin 
		set @CurrentNoOfRecord =0 
		select @CurrentNoOfRecord= count(*)
		from  iac_Card c (nolock)
		inner join iac_Entity e (nolock)on e.EntityId = c.EntityId
		where e.NewIc = @CurrentIdentityNumber 
		and c.sts ='A'
	end 
	
	if @CurrentIdentityTypeCode = 2
	begin 
		set @CurrentNoOfRecord =0 
		select @CurrentNoOfRecord= count(*)
		from  iac_Card c (nolock)
		inner join iac_Entity e (nolock)on e.EntityId = c.EntityId
		where e.OldIc = @CurrentIdentityNumber 
		and c.sts ='A'
	end 

	if @CurrentIdentityTypeCode = 3
	begin 
		set @CurrentNoOfRecord =0 
		select @CurrentNoOfRecord= count(*)
		from  iac_Card c (nolock)
		inner join iac_Entity e (nolock)on e.EntityId = c.EntityId
		where e.PassportNo = @CurrentIdentityNumber 
		and c.sts ='A'
	end 

	if @CurrentIdentityTypeCode = 4
	begin 
		set @CurrentNoOfRecord =0 
		select @CurrentNoOfRecord= count(*)
		from  iac_Card c (nolock)
		inner join iac_Entity e (nolock)on e.EntityId = c.EntityId
		where e.LegalDocumentId = @CurrentIdentityNumber 
		and c.sts ='A'
	end 

	if @CurrentNoOfRecord <=1
	begin
		set @ResponseCode = 95792 --At least one active card must be kept by the existing owner
		goto ResponseExit;	
	end

	set @CurrentNoOfRecord =0 
	select @CurrentNoOfRecord= count(*)
	from  iac_Card c (nolock)
	where c.AcctNo = @CurrentAcctNo and c.sts ='A'
	if @CurrentNoOfRecord >1
	begin
		set @ResponseCode = 95190 --Multiple primary card not allow
		goto ResponseExit;	
	end

	------------------------------------------------------------------------------------------------------------------------------------------  
	BEGIN TRANSACTION 
	------------------------------------------------------------------------------------------------------------------------------------------  
	BEGIN TRY

		select @rowcount = count(*) from iss_Contact (nolock) where IssNo = @IssNo and  RefTo = 'ENTT' and RefType = 'CONTACT' and RefCd = 11 and RefKey = @vCurrentEntityId

		if @rowcount > 0
		Begin
			exec @rc = usp_CommandQueue_Insert_DeleteCardContactCommand @MediaId
		End
		
		exec @CardEventBatchId = NextRunNo @IssNo,'CardEventBatchId'   

		insert into iss_CardEventAuditLog (EventBatchId,OperationId,AcctNo,CardNo,PriSec,FromTo,FamilyName,CardSts,NewIc,OldIc,PassportNo,EmailAddr,MobileNo,CreationDate,SourceId)
		select @CardEventBatchId,@OperationId,a.AcctNo,a.CardNo,NULL,'F',b.FamilyName,a.Sts,b.NewIc,b.OldIc,b.PassportNo,c.EmailAddr,d.ContactNo,getdate(),@SourceId 
		from iac_Card a (nolock) 
		join iac_Entity b (nolock) on a.EntityId = b.EntityId
		left join iss_Contact c (nolock) on c.IssNo = @IssNo and cast(b.EntityId as varchar(20)) = c.RefKey and c.RefTo = 'ENTT' and c.RefType = 'CONTACT' and c.RefCd = 13
		left join iss_Contact d (nolock) on d.IssNo = @IssNo and cast(b.EntityId as varchar(20)) = d.RefKey and d.RefTo = 'ENTT' and d.RefType = 'CONTACT' and d.RefCd = 11
		where a.CardNo = @MediaId

		update iac_Entity Set
		FamilyName = @CardHolderName ,
		GivenName= null, Race= null, Title= null, Gender = null, Marital= null, Dob= null, BloodGroup= null,
		NewIc = case when @IdentityTypeCode = 1 then @IdentityNumber else NULL end, 
		OldIc= case when @IdentityTypeCode = 2 then @IdentityNumber else NULL end,
		PassportNo = case when @IdentityTypeCode = 3 then @IdentityNumber else NULL end,
		LegalDocumentId = case when @IdentityTypeCode = 4 then @IdentityNumber else NULL end,
		LicNo= null, 
		CmpyName= null, Dept= null, Occupation= null, Income= null, BankName= null, BankAcctNo= null, 
		PrefLanguage= null, PrefCommunication= null, Interest= null, InterestInp= null, Television= null, TelevisionInp= null, 
		Radio= null, RadioInp= null, NewsPaper= null, NewsPaperInp= null, SignDate= null,
		Nationality = null , LastUpdDate = @dtNow
		Where EntityId =  @CurrentEntityId

		delete from iss_Contact
		where RefKey = @vCurrentEntityId and RefTo = 'ENTT' and IssNo = @IssNo

		insert into iss_Contact
		(
		IssNo, RefTo, RefKey, RefType, RefCd, ContactName, Occupation, ContactNo, Sts, EmailAddr, LastUpdDate
		)
		values
		(
		@IssNo, 'ENTT', @vCurrentEntityId, 'CONTACT', 13, @CardHolderName, null, null, 'A', @EmailAddress, @dtNow
		)

		insert into iss_Contact
		(
		IssNo, RefTo, RefKey, RefType, RefCd, ContactName, Occupation, ContactNo, Sts, EmailAddr, LastUpdDate
		)
		values
		(
		@IssNo, 'ENTT', @vCurrentEntityId, 'CONTACT', 11, @CardHolderName, null, @MobileNumber, 'A', null, @dtNow
		)

		if @@Error = 0
		Begin
			exec @rc = usp_CommandQueue_Insert_CreateCardContactCommand @MediaId
		End

		select @WebId = UserId from [Demo_lms_web]..web_Membership (nolock) where cast(RefKey as bigint) = @MediaId 
		delete from [Demo_lms_web]..web_Membership where UserId = @WebId

		delete from [Demo_lms_web]..web_UsersInRoles
		where cast(RefKey as bigint) = @MediaId 

		if exists(select 1 from [Demo_lms_web]..web_membership (nolock) where IdentityNumber = @IdentityNumber and IdentityType = @IdentityTypeCode)
		begin 
				select @Refkey = Refkey 
				from [Demo_lms_web]..web_membership (nolock)
				where IdentityNumber = @IdentityNumber and IdentityType = @IdentityTypeCode 

				delete from [Demo_lms_web]..web_membership 
				where Refkey = @RefKey 

				delete from [Demo_lms_web]..web_UsersInRoles
				where RefKey = @RefKey 
		end

		insert into web_OnlineApplication 
		(
		Issno,CardNo,[Name],NewIc,OldIc,PassportNo,LegalDocumentId,
		Gender,	MobileNo,EmailAddr,PrcsId,CreationDate,
		Sts,Token,TokenExpDate,Password,EntityId,IdentityType,
		ActivationDate,SourceId
		) 
		values
		(
		@IssNo,@MediaId,@CardHolderName,
		case when @IdentityTypeCode = 1 then @IdentityNumber else null end,
		case when @IdentityTypeCode = 2 then @IdentityNumber else null end,
		case when @IdentityTypeCode = 3 then @IdentityNumber else null end,
		case when @IdentityTypeCode = 4 then @IdentityNumber else null end,
		@Gender,@MobileNumber,@EmailAddress,@PrcsId,@dtNow,'T'  -- Status T : Transfered
		,null,null,@Password,@CurrentEntityId,@IdentityTypeCode,
		@dtNow,@SourceId
		)

		insert into [Demo_lms_web]..web_Membership
		(
		UserName, ApplicationName, Email, [Password], IsApproved, CreationDate, 
		AcctNo, RefKey, Name,IdentityNumber,IdentityType
		)
		values
		(
		isnull(@EmailAddress,''), 'PDBWeb', isnull(@EmailAddress,''), @Password, 0, getdate(), 
		@CurrentAcctNo, cast(@MediaId as varchar), @CardHolderName,@IdentityNumber,@IdentityTypeCode
		)	
		
		select @RoleId = RoleId
		from [Demo_lms_web]..web_Roles (nolock)
		where RoleName = @RoleName

		insert into [Demo_lms_web]..web_UsersInRoles
		(
		RoleId, Username, RefKey, Rolename, ApplicationName
		)
		values
		(
		@RoleId,isnull(@EmailAddress,''),cast(@MediaId as varchar),@RoleName,'PDBWeb'
		)	

		insert into iac_Event 
		(
		IssNo, EventType, AcctNo, CardNo, ReasonCd, Descp, 
		[Priority], CreatedBy, AssignTo, XRefDoc, CreationDate, SysInd, Sts
		)
		values 
		(
		@IssNo, 'ChgOwner', @CurrentAcctNo, @MediaId, 'OTHS',@Descp,'L', system_user, null, null, @dtNow, 'Y', 'A'
		)

		set @Identity = @@Identity

		insert into iac_EventDetail (EventId,Seq,CreationDate,CreatedBy,Descp,Remark)
		values (@Identity,1,getdate(),substring(system_user,1,8),'',@Remark)

		insert into iss_CardEventAuditLog (EventBatchId,OperationId,AcctNo,CardNo,PriSec,FromTo,FamilyName,CardSts,NewIc,OldIc,PassportNo,EmailAddr,MobileNo,CreationDate,SourceId )
		select @CardEventBatchId,@OperationId,a.AcctNo,a.CardNo,NULL,'T',b.FamilyName,a.Sts,b.NewIc,b.OldIc,b.PassportNo,c.EmailAddr,d.ContactNo,getdate(),@SourceId
		from iac_Card a (nolock) 
		join iac_Entity b (nolock) on a.EntityId = b.EntityId
		left join iss_Contact c (nolock) on c.IssNo = @IssNo and cast(b.EntityId as varchar(20)) = c.RefKey and c.RefTo = 'ENTT' and c.RefType = 'CONTACT' and c.RefCd = 13
		left join iss_Contact d (nolock) on d.IssNo = @IssNo and cast(b.EntityId as varchar(20)) = d.RefKey and d.RefTo = 'ENTT' and d.RefType = 'CONTACT' and d.RefCd = 11
		where a.CardNo = @MediaId

	------------------------------------------------------------------------------------------------------------------------------------------  
	COMMIT TRANSACTION 
	------------------------------------------------------------------------------------------------------------------------------------------  
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION UpdTrx
		END
		
		set @ResponseCode =71059--Failed to update record
	END CATCH


	ResponseExit:

	Return @ResponseCode

END
GO
