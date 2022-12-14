USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ApplicationDataValidation]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Objective	:To view card unredeem amount (card liability), by monthly cumulative.

-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2009/02/24	Barnett			Checking the Data import from PDB VPI.
*******************************************************************************/
/*
drop table #Temp1
declare @BatchId int, @Counter int, @CardNo varchar(20)

create table #Temp1
	(
		Ids int identity(1,1),
		BatchId int,
		OperationMode char(1)
		
	)
	
	set @Counter = 1
	
	insert #Temp1 (BatchId, OperationMode)
	select BatchId, OperationMode
	from udi_batch where SrcName ='SCAN'

	while ((select isnull(max(Ids),0) from #Temp1) >= @Counter)
	begin
			select @BatchId = BatchId from #Temp1 where Ids = @Counter	
	
			exec ApplicationDataValidation 3000078, 'A'
			exec ApplicationDataValidation 3000137, 'P'
		
			select @Counter = @Counter + 1 
	end


declare @BatchId int, @Counter int, @CardNo varchar(20)
exec ApplicationDataValidation 3000124, 'A', @CardNo output
select @CardNo




select * from #Temp1

select  * from udii_Application (nolock) where Batchid = 3000057


delete iss_ApplCheck
where mode is null

select * from iss_ApplCheck (nolock) where mode='P'


truncate table iss_ApplCheck

select * from udii_Application where NationalIcChk = 0

and cardno ='70838155103129543'
order by ApplId


select * from udi_batch where srcname ='scan'

*/
CREATE procedure [dbo].[ApplicationDataValidation] 
	@BatchId uBatchId,
	@Mode char(1)
  as
begin
	
	SET NOCOUNT ON
	
	declare @MinApplId uApplId,	@MaxApplId uApplId,	@ApplId uApplId, @Title varchar(10), @CardNo varchar(20),
			@FullName varchar(50), @NewIc varchar(30), @OldIc varchar(30),	@Street1 varchar(50), 
			@Street2 varchar(50), @Street3 varchar(50), @OldCardNo varchar(30), @AcctNo bigint,
			@City varchar(50) , @State varchar(10),@ZipCd varchar(10), @MobileNo varchar(20), 
			@HomeNo varchar(20), @OfficeNo varchar(20),@EmailAddr varchar(66), @DOB varchar(30), 
			@Gender varchar(1), @Race varchar(10), @Language varchar(10),@Communication varchar(50), 
			@Interest varchar(50), @Television varchar(50), @Radio varchar(50),@Newspaper varchar(50),
			@Nationality varchar(2),
			@Length int, @ContactChk char(1), @AddressChk char(1), @CardNoChk char(1), @NameChk char(1),
			@NationalICChk char(1),
			@Counter int, @SignDate varchar(20)
	
--	Delete 	iss_ApplCheck where BatchId = @BatchId
	
	-- Check Operation Mode
	if (select 1 from udi_batch where BatchId = @BatchId and (OperationMode is null or OperationMode not in ( 'N', 'U' , 'R', 'T'))) = 1
	begin
			insert iss_ApplCheck(BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
			select @BatchId, null, 95401, 'OperationMode', isnull(OperationMode, null), 'Please Check Udi_Batch'
			from udi_batch where BatchId = @BatchId
	end	
	
	select @MaxApplId = Max(ApplId) from udii_Application (nolock) where BatchId = @BatchId --and Sts = 'T'
	select @minApplId = min(ApplId) from udii_Application (nolock) where BatchId = @BatchId --and Sts = 'T'
	
	select @ApplId = @minApplId

	if @mode = 'A'
	begin
		while @ApplId <= @MaxApplId
		begin
				select @Title = Title, @FullName = FullName, @NewIc = NewIc, @OldIc = OldIc,
						@Street1 = Address1, @Street2 = Address2, @Street3 = Address3, @City = City, 
						@State = @State, @ZipCd = ZipCd, @MobileNo = MobileNo, @HomeNo = HomeNo, 
						@OfficeNo = OfficeNo, @EmailAddr = EmailAddr, @DOB= DOB, @Gender = Gender,
						@Race =Race, @Language = Language, @Communication = Communication, 
						@Interest = Interest, @Television = Television, @Radio = Radio, @Newspaper = Newspaper,
						@OldCardNo = OldCardNo, @AcctNo = AcctNo, @CardNo = CardNo, @Nationality = Nationality,
						@ContactChk = ContactChk, @AddressChk = AddressChk, @CardNoChk = CardNoChk,
						@SignDate = SignDate
				from udii_Application (nolock) where ApplId = @ApplId and BatchId = @BatchId
				
				
				-- Email
				if @EmailAddr <> '' 
				begin
						if  dbo.vaValidEmail(@EmailAddr) = 1
						begin
								insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
								select @BatchId, @CardNo, 95408, 'Email', @EmailAddr, 'Invalid Email address format'
						end
						
						if len(@EmailAddr) < 6
						begin
						
								insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
								select @BatchId, @CardNo, 95404, 'Email', @EmailAddr, 'Email address length must more then 6 character'
						end
				end
				
				-- Contact
				
				if ( @MobileNo = '' and @OfficeNo = '' and @HomeNo = '')
				begin				
						insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
						select @BatchId, @CardNo, 95403, 'Contact', null, 'At least fill in one type of Contact No.'
				end

				if @@error<>0
					select @MobileNo, @OfficeNo, @HomeNo
					
				--Mobile No
				if (@MobileNo <> '')
				begin 
						if len(@MobileNo) <=5
						begin
								insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
								select @BatchId, @CardNo, 95455, 'Contact', @MobileNo, 'Contact No length must more then 5.'
						end 
						
						if isnumeric(@MobileNo)= 0
						begin
								insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
								select @BatchId, @CardNo, 95402, 'Contact', @MobileNo, 'Contact No Must be numeric.'
						end
				end
				
				--Office No
				if (@OfficeNo <> '')
				begin 
						if len(@OfficeNo) <=5
						begin
								insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
								select @BatchId, @CardNo, 95455, 'Contact', @OfficeNo, 'Contact No length must more then 5.'
						end 
						
						if isnumeric(@OfficeNo)= 0
						begin
								insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
								select @BatchId, @CardNo, 95402, 'Contact', @OfficeNo, 'Contact No Must be numeric.'
						end
				end
				
				--Home No
				if (@HomeNo <> '')
				begin 
						if len(@HomeNo) <=5
						begin
								insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
								select @BatchId, @CardNo, 95455, 'Contact', @HomeNo, 'Contact No length must more then 5.'
						end 
						
						if isnumeric(@HomeNo)= 0
						begin
								insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
								select @BatchId, @CardNo, 95402, 'Contact', @HomeNo, 'Contact No Must be numeric.'
						end
				end
				--COntact Checking END
			

				-- Address
				if @AddressChk =0
				begin
						if @Street1 = '' and @Street1 ='' and @Street3 =''
						begin
								insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
								select @BatchId, @CardNo, 95403, 'Address', '', 'Address cannot be blank.'
						end

						if len(@ZipCd ) <> 5
						begin
								insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
								select @BatchId, @CardNo, 95404, 'Address', @ZipCd, 'Zip Code must Contain 5 digit only.'
						end
						
						if @zipcd =''
						begin
								insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
								select @BatchId, @CardNo, 95403, 'Address', @ZipCd, 'Zip Code must not be blank.'
									
						end
						
						if isnumeric(@ZipCd) =0
						begin
						
								insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
								select @BatchId, @CardNo, 95407, 'Address', @ZipCd, 'Zip Code must be numeric.'
						end
				end
				
				
				--DOB
				if  isdate(@DOB) =1 and @DOB not between '19100101' and dateadd(yy, -10, getdate())
				begin
					
						insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
						select @BatchId, @CardNo, 95320, 'DOB', @DOB, 'Valid date range from 01/01/1910 to (Current date - 10years).'	
				end
				
				if @Gender =''
				begin
						insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
						select @BatchId, @CardNo, 95403, 'Gender', @Gender, 'Gender Cannot Not Be Blank'	
				end
				else if @Gender <> 'M' and @Gender <> 'F'
				begin
						
						insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
						select @BatchId, @CardNo, 95409, 'Gender', @Gender, 'Valid Gender Code is [M] or [F]'	
				end
				
				if isnumeric(@Race) = 1 and @Race <>''
				begin
						if not exists(select 1 from iss_reflib where reftype='Race' and RefNo = @Race or @Race =99)--99 = other
						begin
								insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
								select @BatchId, @CardNo, 95409, 'Race', @Race, 'Valid Race Code'
						end
				end
				else
				begin
						insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
						select @BatchId, @CardNo, 95409, 'Race', @Race, 'Valid Race Code'
				end
					
				if @OldCardNo <>'' and isnumeric(@OldCardNo) = 0
				begin
						insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
						select @BatchId, @CardNo, 95407, 'Old Mesra CardNo', @OldCardNo, 'Old Mesra CardNo only contain numeric character'
				end
			
				if @SignDate <> '' and isdate(@SignDate) =0
				begin
						
						insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2)
						select @BatchId, @CardNo, 95320, 'SignDate', @SignDate, 'Invalid Date Format.'
				end
				
				select @ApplId = @ApplId + 1

		end
	end
		

	if @Mode ='P'
	begin

			
			while @ApplId <= @MaxApplId
			begin
				select @Title = Title, @FullName = FullName, @NewIc = NewIc, @OldIc = OldIc,
							@Street1 = Address1, @Street2 = Address2, @Street3 = Address3, @City = City, 
							@State = @State, @ZipCd = ZipCd, @MobileNo = MobileNo, @HomeNo = HomeNo, 
							@OfficeNo = OfficeNo, @EmailAddr = EmailAddr, @DOB= DOB, @Gender = Gender,
							@Race =Race, @Language = Language, @Communication = Communication, 
							@Interest = Interest, @Television = Television, @Radio = Radio, @Newspaper = Newspaper,
							@OldCardNo = OldCardNo, @AcctNo = AcctNo, @CardNo = CardNo, @Nationality = Nationality,
							@ContactChk = ContactChk, @AddressChk = AddressChk, @CardNoChk = CardNoChk, @NationalICChk = NationalICChk,
							@NameChk = NameChk,
							@SignDate = SignDate
					from udii_Application (nolock) where ApplId = @ApplId and BatchId = @BatchId


				if @CardNoChk = 0 
				begin

						if isnumeric(@CardNo)= 1 and charindex('.', @CardNo) = 0
						begin 
								if len(@CardNo) <> 17
								begin
										insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2, Mode)
										select @Batchid, @CardNo, 95404, 'CardNo', @CardNo , 'CardNo length must equal 17', @Mode
								end

								
								if not exists (select 1 from iac_card (nolock) where CardNo = @CardNo)
								begin
										insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2, Mode)
										select @Batchid, @CardNo, 60003	, 'CardNo', @CardNo , 'CardNo not exists', @Mode 
								end
						end
						else
						begin
								insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2, Mode)
								select @Batchid, @CardNo, 95407, 'CardNo', @CardNo , 'Invalid Card Number Format', @Mode
						end
				end 

				if @NameChk = 0
				begin	
				
						if @FullName = ''
						begin								
								insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2, Mode)
								select @BatchId, @CardNo, 95403, 'FamilyName', @FullName, 'Name cannot be blank', @Mode
						end 
						else if len(@FullName) <=2
						begin
								insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2, Mode)
								select @BatchId, @CardNo, 95404, 'FamilyName', @FullName, 'Must More then 2 character', @Mode
						end
				end


				if (PATINDEX('%[0-9]%', @NewIc))= 0 and @NewIc <> '' -- NewIc is numeric
				begin
						insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2, Mode)
						select @BatchId, @CardNo, 95406, 'NewIc', @NewIc, null, @Mode
				end
	
				if @NationalICChk = 0  
				begin
						
						if isnumeric(@Nationality) =1 and charindex('.', @NewIc)  = 0
						begin
								if @Nationality ='01' and @NewIc ='' and len(@OldIC)<= 5 -- if NewIc is null then check Old IC
								begin
										insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2, Mode)
										select @BatchId, @CardNo, 95404, 'PassportNo', @OldIc, 'Old Ic length must greater then 5', @Mode
								end
					
								if @Nationality ='01' and isnumeric(@NewIc)>0 and len(@NewIC) <> 12 -- if NewIc not null and len=12
								begin
										insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2, Mode)
										select @BatchId, @CardNo, 95404, 'NewIc', @NewIc, 'New Ic length must equal to 12 digits', @Mode
								end
								

								if @Nationality ='99' and len(@OldIc) <= 5
								begin
										insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2, Mode)
										select @BatchId, @CardNo, 95404, 'PassportNo', @OldIc, 'Old Ic length must greater then 5', @Mode
								end
						end 


						if isnumeric(@Nationality) =0 and charindex('.', @NewIc)  = 0
						begin
							
								if (len(@NewIC) <> 12) 
								begin
										insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2, Mode)
										select @BatchId, @CardNo, 95404, 'NewIc', @NewIc, 'New Ic length must equal to 12 digits', @Mode
								end
								else if len(@OldIc)<=5
								begin
										insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2, Mode)
										select @BatchId, @CardNo, 95404, 'PassportNo', @OldIc, 'Old Ic length must greater then 5', @Mode
								end
						end
				end

				if substring(@Newspaper, len(@Newspaper), 1) <> '|' and @Newspaper <>''
				begin
						insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2, Mode)
						select @BatchId, @CardNo, 95410, 'Newspaper', @Newspaper, 'Last Charater must be "|"', @Mode
				end

				if substring(@Radio, len(@Radio), 1) <> '|' and @Radio <> ''
				begin
						insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2, Mode)
						select @BatchId, @CardNo, 95410, 'Radio', @Radio, 'Last Charater must be "|"', @Mode
				end

				if substring(@Communication, len(@Communication), 1) <> '|' and @Communication <> ''
				begin
						insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2, Mode)
						select @BatchId, @CardNo, 95410, 'Communication', @Communication, 'Last Charater must be "|"', @Mode
				end

				
				if substring(@Language, len(@Language), 1) <> '|' and @Language <> ''
				begin
						insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2, Mode)
						select @BatchId, @CardNo, 95410, 'Language', @Language, 'Last Charater must be "|"', @Mode
				end

				if substring(@Interest, len(@Interest), 1) <> '|' and @Interest <>''
				begin
						insert iss_ApplCheck (BatchId,RefKey,MsgCd,FieldName,Remark1,Remark2, Mode)
						select @BatchId, @CardNo, 95410, 'Interest', @Interest, 'Last Charater must be "|"', @Mode
				end

				select @ApplId = @ApplId + 1
		end
	end


end
GO
