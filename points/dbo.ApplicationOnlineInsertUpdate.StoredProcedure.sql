USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ApplicationOnlineInsertUpdate]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This is the front end Application capturing procedure.


-------------------------------------------------------------------------------
When	   Who		CRN		Desc
-------------------------------------------------------------------------------
2001/12/14 CK			  	Initial development
					All remarks follow by ** is for further rework/recode.

					**insert into iss_Debug values ('ApplicationOnlineInsert','Y')
2003/03/16 Sam				To enable account with price shield.

2003/06/30 KY		1103003		Enable remark field to be store data.
2003/10/11 Chew Pei				1.	Validate Credit Limit field, Credit Limit field is mandatory for Postpaid
								2.	Comment OrigApplInd = 0 (RejDate
2004/05/19 Chew Pei			Added Deposit Amt
2004/07/05 Chew Pei			Added LastUpdDate
							This is to ensure that user refresh one screen before 
							record is being updated. This is to avoid user updating a
							record while Batch Processing is running / users accessing 
							the same screen and update record concurrently.					
2004/11/05 Chew Pei			Added CustSvcId
2004/12/06 Chew Pei			Added Government Levy Fee Cd
2005/07/25 Chew Pei			Added MDTCA No
2008/03/12 Peggy			Added StoreName
2009/03/27 Barnett			If appl approved , update the appc sts also approved.
******************************************************************************************************************/

CREATE procedure [dbo].[ApplicationOnlineInsertUpdate]
	@Func varchar(10),
	@IssNo uIssNo,
	@ApplRef nvarchar(35),
	@SrcCd uSrcCd,
	@SrcRefNo varchar(19),
	@CardLogo uCardLogo,
	@PlasticType uPlasticType,
	@CreditLimit money,
	@LocNo uLocNo,
	@CorpCd uRefCd,
	@CycNo uCycNo,
	@DepositAmt money, 
	@ApplSts char(1),
	@RecvDate datetime,	-- This field is referring to the Application Date in F.End
	@AppvDate datetime,
	@TrsfDate datetime,
	@ApplId uApplId output,
	@PriceShieldInd char(1),
	@Remarks uDescp50, 	-- CRN: 1103003
	@CustSvcId uUserId,
	@GovernmentLevyFeeCd uRefCd,
	@MDTCANo varchar(15), 
	@LastUpdDate varchar(30),
	@BillingType char(1),
	@StoreName uBusnName

  as
begin
	declare @PrcsName varchar(50),
		@PrcsId uPrcsId,
		@CreationDate datetime,
		@ApplInd tinyint,
		@OrigApplInd tinyint,
		@PrepaidInd char(1),
		@LatestUpdDate datetime

	select @PrcsName = 'ApplicationOnlineInsertUpdate'
	
	/******************************************************************************
	Those field that has been remarked of might not be mandatory (For CUSTOMIZATION)
	******************************************************************************/
	exec TraceProcess @IssNo, @PrcsName, 'Checking mandatory fields'

	if isnull(@IssNo,0) = 0
	return 0	--Mandatory Field IssNo

--	if isnull(@SrcRefNo,0) = 0
--	return 55000	--Mandatory Field SrcRefNo

	if isnull(@ApplRef,'') = ''
	return 55001	--Mandatory Field ApplRef

	if isnull(@CardLogo,'') = ''	
	return 55002	--Mandatory Field CardLogo

	if isnull(@PlasticType,'') = ''
	return 55003	--Mandatory Field PlasticType

	if isnull(@ApplSts,'') = ''
	return 55013	--Mandatory Field ApplSts

--	if isnull(@ReceiveDate,0) = 0
--	return 55005	--Mandatory Field ReceiveDate

--	if isnull(@SrcCd,0) = 0
--	return 55006	--Mandatory Field SrcCd

--	if isnull(@InputSrc,'') = ''
--	return 55007	--Mandatory Field InputSrc

--	if isnull(@LocNo,0) = 0
--	return 55008	--Mandatory Field LocNo

--	if isnull(@CorpCd,'') = ''
--	return 55009	--Mandatory Field CorpCd

	if isnull(@CycNo, '') = ''
	return 55115	--Cycle no is a compulsory field
	
	
	select @PrepaidInd = PrepaidInd from iss_PlasticType where PlasticType = @PlasticType
	/*if @PrepaidInd = 'N'
	begin
		if isnull(convert(varchar(15),@CreditLimit) , '') = ''
		return 55014 -- Credit Limit is a compulsory field
	end*/

	-- Obtain Business Date
	select @PrcsId = CtrlNo, @CreationDate = CtrlDate
	from iss_Control 
	where CtrlId = 'PrcsId' and @IssNo = IssNo 

	select @ApplInd = RefInd
	from iss_RefLib
	where IssNo = @IssNo and RefType = 'ApplSts' and RefCd = @ApplSts

	if @Func = 'Add'
	begin
		-----------------
		begin transaction
		-----------------
		insert into iap_Application
			(IssNo, BatchId, SeqNo, ApplRef, SrcCd, SrcRefNo, ApplType,
			CardLogo, PlasticType, CreditLimit, LocNo, CorpCd, CycNo, DepositAmt, InputSrc,
			RecvDate, CreationDate, AppvDate, TrsfDate, AppvInd, ApplSts,
			AcctNo, Remarks, PrcsId, Sts, BillingType, UserId, LastUpdDate, PriceShieldInd, CustSvcId, GovernmentLevyFeeCd, MDTCANo, StoreName)
		values (@IssNo, 0, 0, @ApplRef, @SrcCd, @SrcRefNo, null,
			@CardLogo, @PlasticType, @CreditLimit, @LocNo, @CorpCd, @CycNo, @DepositAmt, 'USR',
			@RecvDate, @CreationDate, case when @ApplInd = 0 then @CreationDate else null end, @TrsfDate, null, @ApplSts,
			null, @Remarks, @PrcsId, null, @BillingType, system_user, getdate(), @PriceShieldInd, @CustSvcId, @GovernmentLevyFeeCd, @MDTCANo, @StoreName)

		select @ApplId = @@identity

		if @@error <> 0	
		begin
			rollback transaction
			return 70200	-- Failed to create application
		end

		------------------
		commit transaction
		------------------
		return 50168	-- Application has been created successfully
	end

	if @Func = 'Save'
	begin
		-- CP: 20040705[B]
		if @LastUpdDate is null
			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

		select @LatestUpdDate = LastUpdDate from iap_Application where ApplId = @ApplId and ApplSts <> 'T'
		if @LatestUpdDate is null
			select @LatestUpdDate = isnull(@LatestUpdDate, getdate())
		-- 20040705[E]

		-----------------
		begin transaction
		-----------------
		select @OrigApplInd = b.RefInd
		from iap_Application a, iss_RefLib b
		where a.IssNo = @IssNo and a.ApplId = @ApplId and b.IssNo = a.IssNo and b.RefType = 'ApplSts' and b.RefCd = a.ApplSts

		if @@rowcount = 0 return 60022	-- Application not found

		-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
		-- it means that record has been updated by someone else, and screen need to be refreshed
		-- before the next update.
		if @LatestUpdDate = convert(datetime, @LastUpdDate)
		begin
			update iap_Application
			set	ApplRef = @ApplRef, 
				SrcCd = @SrcCd,
				SrcRefNo = @SrcRefNo,
				CardLogo = @CardLogo,
				PlasticType = @PlasticType,
				CreditLimit = @CreditLimit,
				LocNo = @LocNo,
				CorpCd = @CorpCd,
				CycNo = @CycNo,
				DepositAmt = @DepositAmt,
				RecvDate = @RecvDate,
				AppvDate = case when @OrigApplInd <> 0 and @ApplInd = 0 then getdate() when @ApplInd <> 0 then null else AppvDate end,
				RejDate = case when @ApplInd = 2 then getdate() when @ApplInd = 0 then null else RejDate end,
				--@OrigApplInd = 0 and @ApplInd = 2 then getdate() when @ApplInd = 0 then null else RejDate end,
				TrsfDate = @TrsfDate,
				ApplSts = @ApplSts,
				LastUpdDate = getdate(),
				PriceShieldInd = @PriceShieldInd,
				Remarks = @Remarks,	-- CRN: 1103003
				CustSvcId = @CustSvcId,
				GovernmentLevyFeeCd = @GovernmentLevyFeeCd,
				MDTCANo = @MDTCANo,
				StoreName = @StoreName
			--	BillingType = @BillingType
			where ApplId = @ApplId
			and ApplSts <> 'T'

			if @@error <> 0
			begin
				rollback transaction
				return 70188
			end
			-- KY: cancel the update applicants status task
			if @ApplSts in ((select RefCd from iss_RefLib where RefInd = 0 and RefType = 'ApplSts' and IssNo = @IssNo))
			begin
				-- Update Applicant status to follow Application status
				-- if the Applicant status is pending/referral
				update a set a.AppcSts = b.RefCd, a.AppvDate = getdate()
				from iap_Applicant a, iss_RefLib b
				where a.IssNo = @IssNo and a.ApplId = @ApplId and b.IssNo = a.IssNo
				and b.RefType = 'AppcSts' and  b.RefInd = 0

				if @@error <> 0
				begin
					rollback transaction
					return 70144	-- Failed to update Applicant
				end
			end
			------------------
			commit transaction
			------------------
		end
		else
		begin
			rollback transaction
			return 95307
		end
	end
	return 50169	-- Application has been updated successfully
end
GO
