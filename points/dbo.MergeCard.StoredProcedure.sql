USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MergeCard]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************  
Copyright :CardTrend Systems Sdn. Bhd.  
Modular  :ADPAC  
Objective :Merge Card Backend Development
-------------------------------------------------------------------------------  
When  Who  CRN  Description  
------------------------------------------------------------------------------- 
2018/05/06  Azan		Initial development  
2020/02/11  Azan        Add Validation 
						- Reject merging if cards are STAFF card or CLP card. 
						- Reject if cards in @MergeMediaIdList is suspended, closed or fraud blocked 
2020/02/13  Azan		Insert into iss_CardEventAuditLog 
******************************************************************************************************************/  
/*
declare @rc int
exec @rc =  MergeCard '70838155100000051','newic','540101037773','70838155100000135|70838155100000143'
select @rc 
*/

CREATE PROCEDURE [dbo].[MergeCard]
	@TargetMediaId uCardNo,
	@IdentityType nvarchar(15),
	@IdentityNumber nvarchar(15),
	@MergeMediaIdList varchar(max)
AS
BEGIN
	SET NOCOUNT ON  

	declare @dtNow datetime
	declare @ResponseCode int =95813
	declare @IssNo uIssNo 

	declare @DebitAdjTxnCode int
	declare @DebitAdjTxnCodeDescp uDescp50
	declare @CreditAdjTxnCode int
	declare @CreditAdjTxnCodeDescp uDescp50
	declare @ClosedAcctSts uRefCd
	declare @ClosedCardSts uRefCd
	declare @IdentityTypeCode int
	declare @CardCentreBusnlocation varchar(50)
	declare @CardCenterTermId varchar(50)

	declare @AvailPoint money =0
	declare @ToAcctNo uAcctNo =''
	declare @TargetMediaIdSts uRefCd

	declare @EmailAddr uEmail = ''
	declare @EntityId uEntityId
	
	declare @CardEventBatchId int
	declare @OperationId int
	declare @SourceId uRefCd
	--------------------------------------------------------------------------------------------------------------------
	--------------------------------- RETRIEVES NECESSARY INFORMATION FOR PROCESSING -----------------------------------
	--------------------------------------------------------------------------------------------------------------------
	set @dtNow = getDate()
	set @IssNo ='1'
	select @DebitAdjTxnCode = IntVal from iss_Default where Deft = 'DebitAdjTxnCode' and IssNo =@IssNo
	select @DebitAdjTxnCodeDescp = Descp from itx_TxnCode where TxnCd = @DebitAdjTxnCode and IssNo =@IssNo
	select @CreditAdjTxnCode = IntVal from iss_Default (nolock) where Deft = 'CreditAdjTxnCode' and IssNo =@IssNo
	select @CreditAdjTxnCodeDescp = Descp from itx_TxnCode (nolock) where TxnCd = @CreditAdjTxnCode and IssNo =@IssNo
	select @ClosedAcctSts = RefCd from iss_RefLib (nolock) where  RefType= 'AcctSts' and RefInd = 3 and (MapInd & 4 )> 0
	select @ClosedCardSts = RefCd from iss_RefLib (nolock)  where RefType = 'CardSts' and RefNo = 0 and (RefId & 8) > 0
	select @OperationId = OperationId from [Demo_lms_web]..sec_Operation (nolock) where OperationName = 'Card Merging'
	select @SourceId = RefCd from iss_Reflib (nolock) where Reftype = 'ApiSourceId' and Descp = 'Mesralink'
	set @CardCentreBusnlocation =  'CardCenterBusnLocation'
	set @CardCenterTermId = 'CardCenterTermId'

	------------------------------------------------------------------------------------------------
	----------------------------------------Data Validation------------------------------------------ 
	-------------------------------------------------------------------------------------------------

	if @TargetMediaId is null  
	begin	
		set @ResponseCode =  95326 ---Invalid card number
		goto ResponseExit;
	end

	if not exists(select 1 from iac_Card(nolock) where CardNo = @TargetMediaId)  
	begin	
		set @ResponseCode =  95326 ---Invalid card number
		goto ResponseExit;
	end 	
																			
	if not exists(select 1 from iac_Card(nolock) where CardNo = @TargetMediaId and Sts = 'A')  
	begin	
		set @ResponseCode =  95064 ---Check on card status
		goto ResponseExit;
	end

	if exists(select 1 from iac_Card (nolock) where CardNo = @TargetMediaId and CardType in (2,5,7,3,18,24)) -- STAFF and CLP card are not allowed for merging
	begin 
		set @ResponseCode = 95029 --- Card Type is not valid  
		goto ResponseExit;
	end  

	if @IdentityType is null OR rtrim(ltrim(@IdentityType))=''
	begin
		set @ResponseCode = 95777 -- Invalid Identity Type
		goto ResponseExit;
	end

	if isnull(@IdentityNumber,'') = ''
	begin
		set @ResponseCode = 95779 -- Identity number is a compulsory field 
		goto ResponseExit;
	end

	if not exists(select 1 from iss_Reflib a (nolock) where RefType = 'IdentityType' and Descp =  @IdentityType)  
	begin	
		set @ResponseCode = 95777 -- Invalid Identity Type
		goto ResponseExit;
	end

	select @IdentityTypeCode = RefCd 
	from iss_Reflib where RefType = 'IdentityType' and Descp =  @IdentityType

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
	end 

	if @MergeMediaIdList is null OR rtrim(ltrim(@MergeMediaIdList))=''
	begin
		set @ResponseCode =  95326 ---Invalid card number
		goto ResponseExit;
	end

	DECLARE @ItemStr varchar(MAX)
	DECLARE @ItemID int

	DECLARE item_cursor CURSOR LOCAL FOR   
	select  [Data],Id
	from dbo.Split(@MergeMediaIdList, '|')
	order by Id

	OPEN item_cursor  
	FETCH NEXT FROM item_cursor 
	INTO @ItemStr, @ItemID;
  
	WHILE @@FETCH_STATUS = 0  
	BEGIN																
		if exists(select 1 from iac_Card (nolock) where CardNo = @ItemStr and Sts in ('O','C','F'))     --Suspended, Closed and Fraud blocked cards are not allowed for merging  
		begin	
			set @ResponseCode =  95064 ---Check on card status
			goto ResponseExit;
		end
		if exists(select 1 from iac_Card (nolock) where CardNo = @ItemStr and CardType in (2,5,7,3,18,24)) -- STAFF and CLP card are not allowed for merging
		begin 
			set @ResponseCode = 95029 --- Card Type is not valid  
			goto ResponseExit;
		end  
		if @IdentityTypeCode = 1
		begin 
			if not exists (select 1 from iac_Card a (nolock) join iac_Entity b (nolock) on a.EntityId = b.EntityId where a.CardNo = @ItemStr and b.NewIc = @IdentityNumber)
			begin 
				set @ResponseCode =  95326 ---Invalid card number
				goto ResponseExit;
			end
		end 
		
		if @IdentityTypeCode = 2
		begin 
			if not exists (select 1 from iac_Card a (nolock) join iac_Entity b (nolock) on a.EntityId = b.EntityId where a.CardNo = @ItemStr and b.OldIc = @IdentityNumber)
			begin 
				set @ResponseCode =  95326 ---Invalid card number
				goto ResponseExit;
			end
		end

		if @IdentityTypeCode = 3
		begin 
			if not exists (select 1 from iac_Card a (nolock) join iac_Entity b (nolock) on a.EntityId = b.EntityId where a.CardNo = @ItemStr and b.PassportNo = @IdentityNumber)
			begin 
				set @ResponseCode =  95326 ---Invalid card number
				goto ResponseExit;
			end
		end  

		if @IdentityTypeCode = 4
		begin 
			if not exists (select 1 from iac_Card a (nolock) join iac_Entity b (nolock) on a.EntityId = b.EntityId where a.CardNo = @ItemStr and b.LegalDocumentId = @IdentityNumber)
			begin 
				set @ResponseCode =  95326 ---Invalid card number
				goto ResponseExit;
			end
		end 
		
		if exists (select 1 from udii_CardTransfer (nolock) where OldCardNo = @ItemStr or NewCardNo = @ItemStr and BatchId = 0)
		begin 
			set @ResponseCode =  95825 ---Card is in the process of replacement. Card merge is not allowed
			goto ResponseExit;
		end 

		if (@ItemStr = @TargetMediaId)
		begin	
			set @ResponseCode =  95326 ---Invalid card number
			goto ResponseExit;
		end

		FETCH NEXT FROM item_cursor 
		INTO @ItemStr,@ItemID
	END

	------------------------------------------------------------------------------------------------------------------------------------------   
	------------------------------------------------------------------------------------------------------------------------------------------    
	select @ToAcctNo = AcctNo, @EntityId = EntityId from iac_Card (nolock) where CardNo = @TargetMediaId
	select @EmailAddr = EmailAddr from iss_Contact (nolock) where IssNo = @IssNo and Refto = 'ENTT' and Reftype = 'CONTACT' and RefCd = 13 and Refkey = @EntityId

	BEGIN TRANSACTION MergeTrx
	BEGIN TRY

		exec @CardEventBatchId = NextRunNo @IssNo,'CardEventBatchId'   

		insert into iss_CardEventAuditLog (EventBatchId,OperationId,AcctNo,CardNo,PriSec,FromTo,FamilyName,CardSts,NewIc,OldIc,PassportNo,EmailAddr,MobileNo,CreationDate,SourceId)
		select @CardEventBatchId,@OperationId,a.AcctNo,a.CardNo,'P',NULL,b.FamilyName,a.Sts,b.NewIc,b.OldIc,b.PassportNo,c.EmailAddr,d.ContactNo,getdate(),@SourceId
		from iac_Card a (nolock) 
		join iac_Entity b (nolock) on a.EntityId = b.EntityId
		left join iss_Contact c (nolock) on c.IssNo = @IssNo and cast(b.EntityId as varchar(20)) = c.RefKey and c.RefTo = 'ENTT' and c.RefType = 'CONTACT' and c.RefCd = 13
		left join iss_Contact d (nolock) on d.IssNo = @IssNo and cast(b.EntityId as varchar(20)) = d.RefKey and d.RefTo = 'ENTT' and d.RefType = 'CONTACT' and d.RefCd = 11
		where a.CardNo = @TargetMediaId

		DECLARE @RecStr varchar(MAX)
		DECLARE @RecID int
		DECLARE record_cursor CURSOR LOCAL FOR   
		select  [Data],Id
		from dbo.Split(@MergeMediaIdList, '|')
		order by Id;

		OPEN record_cursor  
		FETCH NEXT FROM record_cursor 
		INTO @RecStr, @RecID;
  
		WHILE @@FETCH_STATUS = 0  
		BEGIN
			
			declare @Pts money = 0
			declare @FromAcctNo uAcctNo =''
			declare @FromCardno uCardno 
			declare @FromCardStatus uRefCd=''
			declare @WebId uniqueidentifier

			set @FromCardno = @RecStr
			select @FromAcctNo = AcctNo , @FromCardStatus = Sts
			from iac_Card(nolock) where CardNo = @FromCardno 	
				
			select @Pts = (a.AccumAgeingPts + isnull(a.WithheldPts,0) + b.WithheldPts) / 100 -- divide 100 to convert to Money Amount (RM) unit
			from iac_AccountFinInfo a (nolock)
			join iac_OnlineFinInfo b (nolock) on b.AcctNo = a.AcctNo
			where a.AcctNo = @FromAcctNo
			------------------------------------------------------------------------------------------------------------------------
			if @Pts > 0
			begin
				declare @RcptNo int
				declare @RetCd int
				declare @rc int
				exec @rc = PaymentAdjustment @IssNo, @CreditAdjTxnCode, @dtNow, @Pts, @Pts, @CreditAdjTxnCodeDescp, null, @FromAcctNo, @FromCardno, 
								@CardCentreBusnlocation, @CardCenterTermId, null, @RcptNo output, @RetCd output 

				--	exec PaymentAdjustment @IssNo, @PtsTransferFromTxnCd, @SysDate, @Point, @Point, @Descp , null, @TrfAcctNo, @TrfCardNo, 
				--		'CardCenterBusnLocation', 'CardCenterTermId', null, @RcptNo output, @RetCd output 

				if dbo.CheckRC(@rc) <> 0
				begin
					if @@TRANCOUNT > 0
					begin
						ROLLBACK TRANSACTION MergeTrx
					end

					set @ResponseCode =@rc
					goto ResponseExit;
				end

				exec @rc = PaymentAdjustment @IssNo, @DebitAdjTxnCode, @dtNow, @Pts, @Pts, @DebitAdjTxnCodeDescp, null, @ToAcctNo, @TargetMediaId, 
							   @CardCentreBusnlocation, @CardCenterTermId, null, @RcptNo output, @RetCd output 
			
				if dbo.CheckRC(@rc) <> 0
				begin
					if @@TRANCOUNT > 0
					begin
						ROLLBACK TRANSACTION MergeTrx
					end

					set @ResponseCode =@rc
					goto ResponseExit;
				end
			end
		
			------------------------------------------------------------------------------------------------------------------------
			if @FromAcctNo <> @ToAcctNo 
			begin 
				update iac_account 
				set Sts = @ClosedAcctSts
				where AcctNo = @FromAcctNo
			end

			update iac_Card
			set Sts = @ClosedCardSts
			where CardNo = @FromCardno 

			------------------------------------------------------------------------------------------------------------------------
			------------------------------------------------------------------------------------------------------------------------
			if exists (select 1 from [Demo_lms_web]..web_membership where cast(RefKey as bigint) = @FromCardno)  
			begin
				if not exists (select 1 from [Demo_lms_web]..web_membership where cast(RefKey as bigint) = @TargetMediaId)  
				begin
					update [Demo_lms_web]..web_Membership with (rowlock)        
					set RefKey = cast(@TargetMediaId as varchar(17))    
					where cast(RefKey as bigint) = @FromCardno 
     
					update [Demo_lms_web]..web_UsersInRoles with (rowlock)     
					set RefKey = cast(@TargetMediaId as varchar(17))      
					where cast(RefKey as bigint) = @FromCardno 

					update [Demo_lms_web]..web_Membership with (rowlock)
					set Username = @EmailAddr,
						Email = @EmailAddr
					where cast(RefKey as bigint) = @TargetMediaId 
				end
				else
				begin
					select @WebId = UserId from [Demo_lms_web]..web_Membership (nolock) where cast(RefKey as bigint) = @FromCardno  
					delete from [Demo_lms_web]..web_Membership where UserId = @WebId

					delete from [Demo_lms_web]..web_UsersInRoles
					where cast(RefKey as bigint) = @FromCardno 
				end 
			end
			
			------------------------------------------------------------------------------------------------------------------------
			insert into iac_Event 
			(
			IssNo, EventType, AcctNo, CardNo, ReasonCd, Descp, 
			[Priority], CreatedBy, AssignTo, XRefDoc, CreationDate, SysInd, Sts
			)
			values 
			(
			@IssNo, 'ChgSts', @FromAcctNo, @FromCardno, 'TRNC', 'Merge card',
			'L', system_user, null, null, @dtNow, 'Y', 'C'
			)

			insert into iss_CardEventAuditLog (EventBatchId,OperationId,AcctNo,CardNo,PriSec,FromTo,FamilyName,CardSts,NewIc,OldIc,PassportNo,EmailAddr,MobileNo,CreationDate,SourceId)
			select @CardEventBatchId,@OperationId,a.AcctNo,a.CardNo,'S',NULL,b.FamilyName,a.Sts,b.NewIc,b.OldIc,b.PassportNo,c.EmailAddr,d.ContactNo,getdate(),@SourceId
			from iac_Card a (nolock) 
			join iac_Entity b (nolock) on a.EntityId = b.EntityId
			left join iss_Contact c (nolock) on c.IssNo = @IssNo and cast(b.EntityId as varchar(20)) = c.RefKey and c.RefTo = 'ENTT' and c.RefType = 'CONTACT' and c.RefCd = 13
			left join iss_Contact d (nolock) on d.IssNo = @IssNo and cast(b.EntityId as varchar(20)) = d.RefKey and d.RefTo = 'ENTT' and d.RefType = 'CONTACT' and d.RefCd = 11
			where a.CardNo = @FromCardno

			FETCH NEXT FROM record_cursor 
			INTO @RecStr,@RecID
		END

		IF @@TRANCOUNT > 0
		BEGIN
			COMMIT TRANSACTION MergeTrx
		END
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION MergeTrx
		END
		
		set @ResponseCode =71058
		goto ResponseExit;
	END CATCH

	---------------------------------------------------------------------------------------------------------------
	select @AvailPoint = isnull(a.AccumAgeingPts,0) + isnull(a.WithheldPts,0) + isnull(b.WithheldPts,0) 
	from iac_AccountFinInfo a (nolock)
	join iac_OnlineFinInfo b (nolock) on a.AcctNo = b.AcctNo
	where  a.AcctNo = @ToAcctNo

	select @TargetMediaIdSts = b.Descp from iac_Card a (nolock) 
	join iss_Reflib b (nolock) on b.RefCd = a.Sts and b.RefType = 'CardSts'
	where CardNo = @TargetMediaId

	ResponseExit:
	RETURN @ResponseCode
END
GO
