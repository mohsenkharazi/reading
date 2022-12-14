USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MircoSiteUserDataUpdateProcess]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:

Objective	:Micro Site Data update Process & Pts Issuance Module.

-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2013/09/18	Barnett			Initial Development
2013/11/29	Barnett			Add Emaill address update will update the Web_membership & web_userInRole
2013/12/19  Humairah		Create a while loop to update details to iac_entity table because its trigger 
							only update iss_object table once at a time
2014/01/08	Humairah		Update email address to iss_contact
2015/06/24  Azan			Bind EntityId from iac_Card instead of iac_Account
*******************************************************************************/
	
CREATE procedure [dbo].[MircoSiteUserDataUpdateProcess]
	@IssNo uIssNo
--with encryption 
as
begin

	declare @BatchId uBatchId, @TxnCd uTxnCd, @TermId uTermId, @Mcc int, @Rrn uRrn, @Stan uStan,
			@TxnDate datetime, @InputSrc nvarchar(10), @TxnAmt money, @BusnLocation varchar(20),
			@Prcsid uPrcsid,@CardNo uCardNo,
			@NewContactCardNos syn_CardNumber,
			@UpdatedContactCardNos syn_CardNumber,
			@rc int
	
	create table #TmpContact(RefKey varchar(20), 
					 MailAddress char(1), 
						 HomeTel char(1),
						 OfficeTel char(1),
						 MobileTel char(1),
						 Emailadd char(1)	
							)
	------------------							
	Begin transaction
	------------------							
			
	select @Prcsid = ctrlno  from iss_control  where ctrlid = 'PrcsId'
				
	update Web_MircoSiteUserData
	Set PrcsId = @Prcsid
	where UpdateInd is null
	

	--Bind the Entity ID 
	update a
	set EntityId = b.EntityId
	from Web_MircoSiteUserData a
	join iac_Card b (NOLOCK) on b.CardNo = a.CardNo 
	join iac_Account c (NOLOCK) on c.AcctNo = b.AcctNo
	where a.UpdateInd is null and a.PrcsId = @Prcsid 
	
	
	-- Manage the Vehicle Information update indicator
	update a
	set a.VehInd = 'U' -- Update only, VehInd is null mean no Vehicle Info in iac_Vehicle
	from Web_MircoSiteUserData a
	join iac_card b (nolock) on b.CardNo = a.CardNo
	join iac_Vehicle c (nolock) on c.VehRegsNo = b.VehRegsNo
	where a.PrcsId = @Prcsid 
	
	-- Temp Table do identify address and contact record in DB.
	insert #TmpContact(Refkey, MailAddress, MobileTel, HomeTel, 
					OfficeTel,  Emailadd)
	select a.EntityId, case 
							when isnull(b.Refkey, 0)=0 then 0 -- no record
							else 1							  -- got record
						end,
					   case when isnull(c.RefKey, 0) =0 then 0
							else 1
						end, 
						case when isnull(d.RefKey, 0)=0 then 0
							else 1
						end,
						case when isnull(e.RefKey, 0) =0 then 0
							else 1
						end, 
						case when isnull(f.RefKey, 0) =0 then 0
							else 1
						end
	from Web_MircoSiteUserData a (nolock)
	left outer join iss_Address b (nolock) on b.RefKey = a.EntityId and b.RefTo ='ENTT' and b.RefCd = 12 and b.RefType='Address'
	left outer join iss_Contact c (nolock) on c.RefKey = a.EntityId and c.RefTo ='ENTT' and c.RefCd = 11 and c.RefType='Contact'  -- mobile
	left outer join iss_Contact d (nolock) on d.RefKey = a.EntityId and d.RefTo ='ENTT' and d.RefCd = 10 and d.RefType='Contact' -- HomeTel
	left outer join iss_Contact e (nolock) on e.RefKey = a.EntityId and e.RefTo ='ENTT' and e.RefCd = 1  and e.RefType='Contact' -- OfficeTel
	left outer join iss_Contact f (nolock) on f.RefKey = a.EntityId and f.RefTo ='ENTT' and f.RefCd = 13 and f.RefType='Contact' -- Email
	where a.UpdateInd is null and a.PrcsId = @Prcsid
	
		
	--update iac_entity data
	select @CardNo = min(cardno) from Web_MircoSiteUserData where Updateind is null -- Humairah 2013/12/19

	while isnull(@CardNo, 0) <> 0
	begin
			update a
			set NewIc = b.NewIc,
				PassportNo = b.PassportNo,
				FamilyName = b.FamilyName,
				Gender = b.Gender,
				Race = b.Race,
				PrefLanguage = b.PrefLanguage,
				PrefCommunication = b.PrefCommunication,
				Income = b.IncomeGroup
			from iac_Entity a (nolock)
			--join Web_MircoSiteUserData b (nolock) on a.EntityId = b.EntityId and b.UpdateInd is null and b.PrcsId = @Prcsid
			join Web_MircoSiteUserData b (nolock) on a.EntityId = b.EntityId and b.UpdateInd is null and b.cardno = @CardNo and b.PrcsId = @Prcsid-- Humairah 2013/12/19
			
			select @CardNo = min(cardno) from Web_MircoSiteUserData where Updateind is null and PrcsId = @Prcsid and CardNo > @CardNo
	end
	
	-- If Address not exists, Insert Address
	insert into iss_Address (IssNo, RefTo, RefKey, RefType, RefCd, 
							Street1, 
							Street2, 
							Street3, City, State, ZipCd, Ctry, EntityInd, MailingInd, LastUpdDate)
	select @IssNo, 'ENTT', a.EntityId, 'ADDRESS', 12, 
					case
						when a.Street1='' then a.Street2
						when a.Street1='' and a.Street2 ='' then a.Street3
						else a.Street1
					end, 
					case
						when a.Street2='' then a.Street3
						else a.Street2
					end, 
					a.Street3, a.City, a.State, a.ZipCd, Ctry, null, 'Y', getdate()
	from Web_MircoSiteUserData a (nolock)
	join #TmpContact b on b.RefKey = a.EntityId and b.MailAddress = 0
	where a.UpdateInd is null and a.PrcsId = @Prcsid
	
	if @@error <> 0
	begin
			rollback Transaction 
			return 70083	-- Failed to insert Address
	end
		
	
		
	--If Address exists, Update address
	update a
	set a.Street1 = case
						when b.Street1='' then b.Street2
						when b.Street1='' and b.Street2 ='' then b.Street3
						else b.Street1
					end,						
		a.Street2 = case
						when b.Street2='' then b.Street3
						else b.Street2
					end,
		a.Street3 = b.Street3,
		a.State = b.State,
		a.City = b.City,
		a.ZipCd = b.ZipCd,
		a.Ctry = 458,
		a.LastUpdDate = getdate()
	from iss_Address a (nolock), Web_MircoSiteUserData b (nolock), #TmpContact c (nolock)
	where b.EntityId  = a.RefKey and a.RefTo ='ENTT' and a.RefCd = 12 and a.RefType='Address' and 
		  b.PrcsId = @PrcsId and b.UpdateInd is null and c.RefKey = b.EntityId and c.MailAddress =1
		  
		
		
	if @@error <> 0
	begin
			rollback Transaction 
			return 70083	-- Failed to insert Address
	end
		
				
	-- Insert Acct Contact // REFCD =11 = handphone No
	-- mobile no
	INSERT INTO @NewContactCardNos
	select a.CardNo
	from Web_MircoSiteUserData a (nolock)
	join #TmpContact b on b.RefKey = a.EntityId and b.MobileTel = 0
	where a.PrcsId = @PrcsId and a.UpdateInd is null

	insert into iss_Contact 
		(IssNo, RefTo, RefKey, RefType, RefCd, ContactName, Occupation, ContactNo, Sts, EmailAddr, LastUpdDate)
	select @IssNo, 'ENTT', a.EntityId, 'CONTACT', 11, a.FamilyName, null, a.ContactNo, 'A', null, getdate()
	from Web_MircoSiteUserData a (nolock)
	join #TmpContact b on b.RefKey = a.EntityId and b.MobileTel = 0
	where a.PrcsId = @PrcsId and a.UpdateInd is null
	
	if @@error <> 0
	begin
			rollback Transaction  
			return 70084	-- Failed to insert Contact
	end
	else
	begin
		EXEC @rc = usp_CommandQueue_Insert_CreateCardContactCommand_Bulk @NewContactCardNos
	end

	-- update Acct Contact // REFCD =11 = handphone No
	-- mobile no

	--truncate table @NewContactCardNos

	INSERT INTO @UpdatedContactCardNos
	select b.CardNo
	from iss_Contact a (nolock), Web_MircoSiteUserData b (nolock), #TmpContact c (nolock)
	where b.EntityId = a.RefKey and a.RefTo ='ENTT' and a.RefCd = 11 and a.RefType='Contact' 
			and b.PrcsId = @PrcsId and b.UpdateInd is null and c.RefKey = b.EntityId and c.MobileTel = 1

	update a
	set a.ContactName = b.FamilyName,
		a.ContactNo = b.ContactNo,
		LastUpdDate = getdate()
	from iss_Contact a (nolock), Web_MircoSiteUserData b (nolock), #TmpContact c (nolock)
	where b.EntityId = a.RefKey and a.RefTo ='ENTT' and a.RefCd = 11 and a.RefType='Contact' 
			and b.PrcsId = @PrcsId and b.UpdateInd is null and c.RefKey = b.EntityId and c.MobileTel = 1
		  
	if @@error <> 0
	begin
			rollback Transaction 
			return 70084	-- Failed to insert Contact
	end
	else
	begin
		EXEC @rc = usp_CommandQueue_Insert_UpdateCardContactCommand_Bulk @UpdatedContactCardNos
	end
	
	--	/* 20140108 - humairah- update email address   
	-- Insert Acct Contact // REFCD =13 = Email
	insert into iss_Contact 
		(IssNo, RefTo, RefKey, RefType, RefCd, ContactName, Occupation, ContactNo, Sts, EmailAddr, LastUpdDate)
	select @IssNo, 'ENTT', a.EntityId, 'CONTACT', 13, a.FamilyName, null, null, 'A', a.EmailAddr, getdate()
	from Web_MircoSiteUserData a (nolock)
	join #TmpContact b on b.RefKey = a.EntityId and b.Emailadd = 0
	where a.PrcsId = @PrcsId and a.UpdateInd is null
	
	if @@error <> 0
	begin
			rollback Transaction  
			return 70084	-- Failed to insert Contact
	end

	-- update Acct Contact //REFCD =13 = Email

	update a
	set a.ContactName = b.FamilyName,
		a.EmailAddr = b.EmailAddr,
		LastUpdDate = getdate()
	from iss_Contact a (nolock), Web_MircoSiteUserData b (nolock), #TmpContact c (nolock)
	where b.EntityId = a.RefKey and a.RefTo ='ENTT' and a.RefCd = 13 and a.RefType='CONTACT' 
			and b.PrcsId = @PrcsId and b.UpdateInd is null and c.RefKey = b.EntityId and c.Emailadd = 1
		  
	if @@error <> 0
	begin
			rollback Transaction 
			return 70084	-- Failed to insert Contact
	end
	
	--	*/
	
	
	-- insert the new Vehicle info
	insert iac_Vehicle (IssNo,VehRegsNo, MainFuel, EngineCapacity, VehicleType)
		select @IssNo,b.VehRegsNo, VehicleEngType, VehicleEngCapacity, VehicleType
	from Web_MircoSiteUserData a
	join iac_Card b (NOLOCK) on b.CardNo = a.CardNo 
	where a.PrcsId = @PrcsId and a.VehInd is null
	
	if @@error <> 0
	begin
			rollback Transaction 
			return 70130	-- Failed to update Card Vehicle Detail
	end
	
	
	
	update c
	set MainFuel = a.VehicleEngType,
		EngineCapacity = a.VehicleEngCapacity,
		VehicleType = a.VehicleType
	from Web_MircoSiteUserData a
	join iac_Card b (NOLOCK) on b.CardNo = a.CardNo 
	join iac_Vehicle c on c.VehRegsNo = b.VehRegsNo
	where a.PrcsId = @PrcsId and a.VehInd ='U'
	
	if @@error <> 0
	begin
			rollback Transaction 
			return 70130	-- Failed to update Card Vehicle Detail
	end

	-- Tag the Data Update Ind.
	Update Web_MircoSiteUserData
	Set UpdateInd = 'E'
	where PrcsId = @PrcsId
	
	--------------------------------------------------------------------------------
	--End of Process for data update 
	--------------------------------------------------------------------------------

	------------------
	Commit transaction
	------------------


	--Start Update the Info to web account
	update c
	set c.Name = a.FamilyName
	from Web_MircoSiteUserData a (nolock)
	join iac_Card b (nolock) on b.CardNo = a.CardNo
	join [Demo_lms_web]..web_Membership c on c.AcctNo = b.AcctNo
	where a.PrcsId = @PrcsId

	--Update Email address to web_UsersInRoles - first
	update d
	set d.UserName = a.EmailAddr
	from Web_MircoSiteUserData a (nolock)
	join iac_Card b (nolock) on b.CardNo = a.CardNo
	join [Demo_lms_web]..web_Membership c on c.AcctNo = b.AcctNo
	join [Demo_lms_web]..web_UsersInRoles d on d.RoleId = c.UserId
	where a.PrcsId = @PrcsId and a.EmailAddr <>''


	--Update Email address to web_Membership - second
	update c
	set c.Email = a.EmailAddr,
		c.UserName = a.EmailAddr
	from Web_MircoSiteUserData a (nolock)
	join iac_Card b (nolock) on b.CardNo = a.CardNo
	join [Demo_lms_web]..web_Membership c on c.AcctNo = b.AcctNo
	where a.PrcsId = @PrcsId and a.EmailAddr <>''


end
GO
