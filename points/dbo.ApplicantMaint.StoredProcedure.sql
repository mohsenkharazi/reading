USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ApplicantMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This is the Application Online Processing stored procedure, for capturing and processing
		of Applicant via front-end for existing Application/Card/Account

SP Level	: Primary
-------------------------------------------------------------------------------\
When	   Who		CRN		Desc
-------------------------------------------------------------------------------
2002/01/02 CK			  	Initial development
					All remarks follow by ** is for further rework/recode.
2002/03/11 CK				Modifications to check the existance of card no in the
					database according to the ApplicantType
2002/11/15 Jac				Revamp

2003/02/26 Sam				Adjustment.
2003/03/03 Sam				Check txn limit for fleet card.
2003/12/04 Chew Pei			Commented duplicate applicant check.
2004/04/06 Chew Pei			#11040008 : Change CostCentre datatype from uRefCd to nvarchar(10)
2004/06/28 Chew Pei			Added Odometer Indicator
2004/07/14 Chew Pei			Added LastUpdDate
2004/07/28 Chew Pei			Comment Off LastUpdDate
2004/11/23 Alex				Add StaffNo
2004/11/26 Alex 			Add GovernmentLevy
2005/09/20 Alex				New field added @VIPInd
2005/09/22 Alex 			Check New CardNo And Reserved card No.
2005/10/11 Chew Pei			If @CardNo = 0, set @CardNo = null
2008/02/20 Peggy			Add JoinDate, PhotographerType
2008/04/01 Peggy			Disable check DOB validation
******************************************************************************************************************/
CREATE procedure [dbo].[ApplicantMaint]
	@IssNo uIssNo,
	@Func varchar(10),
	@AppcType char(1),
	@ApplId uApplId,
	@PriAppcId uAppcId,
	@AcctNo uAcctNo,
	@PriCardNo varchar(19),
	@CardType uRefCd,
	@SCardNo varchar(19),
	@PinInd char(1),
	@OdometerInd char(1),
	@VIPInd char(1),
	@FamilyName uFamilyName,
	@GivenName uGivenName,
	@EmbName uEmbName,
	@Gender uRefCd,
	@Dob datetime,	
	@BloodGroup uRefCd,
	@Marital uRefCd,
	@NewIc uNewIc,
	@OldIc uOldIc,
	@PassportNo uPassportNo,
	@LicNo uLicNo,
	@PriSec char(1),
	@TxnLimit money,
	@ProdGroup uProdGroup,
	@CostCentre nvarchar(10),
	@JoiningFeeCd uRefCd,
	@AnnlFeeCd uRefCd,
	@PartnerRefNo varchar(19),
--	@LastUpdDate varchar(30),
	@AppcId uAppcId output,
	@StaffNo uRefCd,
	@GovernmentLevyFeeCd uRefCd,
	@JoinDate datetime,
	@PhotographerType uRefCd,
	@Race uRefCd,
	@Title uRefCd
  as
begin
	declare @CardNo uCardNo,
		@BatchId uBatchId,
		@PrcsName varchar(50),
		@PrcsId uPrcsId,
		@CreationDate datetime,
		@TrueFalse int,
		@CardLogo uCardLogo,
		@PlasticType uPlasticType,
		@Program char(1),
		@AppcPendingSts char(1),
		@OrigAppcType char(1),
		@OrigCardNo uCardNo,
		@rc int,
		@Msg varchar(80),
		@LatestUpdDate datetime

	select @PrcsName = 'ApplicantMaint'

	exec TraceProcess @IssNo, @PrcsName, 'Start'
	----------------------------
	----- DATA VALIDATION ------
	----------------------------

	if isnull(@IssNo,0) = 0 return 55015		-- Mandatory field IssNo

	if isnull(@AppcType,'') = '' return 55109

	if isnull(@EmbName,'') = '' return 55059

	if isnull(@FamilyName,'') = '' return 55037

	if isnull(@PriSec,'') = '' return 55047

--	if isnull(@GivenName,'') = '' return 55038
--	if isnull(@ApplId,0) = 0 return 55033
--	if isnull(@PriCardNo,0) = 0 return 55035
--	if isnull(@AcctNo,0) = 0 return 55036
--	if isnull(@Gender,'') = '' return 55039
--	if isnull(@MaritalSts,'') = '' return 55040
--	if isnull(@Dob,0) = 0 return 55041
	if isnull(@NewIc,'') = '' return 55042
--	if isnull(@OldIc,'') = '' return 55043
--	if isnull(@PassportNo,'') = '' return 55044
--	if isnull(@LicNo,'') = '' return 55045
--	if isnull(@BloodGroup,'') = '' return 55046
	if isnull(@CardType,'') = '' return 55048
--	if isnull(@JoiningFeeCd,'') = '' return 55049
--	if isnull(@AnnualFeeCd,'') = '' return 55050
--	if isnull(@ProdGroup,'') = '' return 55051
--	if isnull(@ReasonCd,'') = '' return 55055
--	if isnull(@PartnerRefNo,0) = 0 return 55057
--	if isnull(@PinInd,'') = '' return 55058
--	if isnull(@CardNo,'') = '' return 55067
	if isnull(@Race, '') = '' return 55274  -- Race is a compulsory field
	if isnull(@Title, '') = '' return 55275 -- Title is a compulsory field



	select @CardNo = convert(bigint, @SCardNo)

	if @CardNo = '0'
		select @CardNo = null

	if @FamilyName is null select @FamilyName = @EmbName

	if @PriSec = 'S' and @PriCardNo is null and  @PriAppcId is null return 55108	-- Primary applicant is a compulsory field

	if @AppcType = 'G' and @CardNo is null
	begin
		return 55067	-- Card number is compulsory
	end

	if @AcctNo is null and @PriCardNo is null and @ApplId is null
	begin
		return 95083	-- Key not found
	end

	--2003/02/26B
	if @AcctNo is null and @ApplId is not null
	begin
		select @AcctNo = AcctNo from iap_Application where IssNo = @IssNo and ApplId = @ApplId and AcctNo is not null and ApplSts = 'T'
	end
/*
	if isdate(@Dob) = 1
	begin
		if @Dob > getdate() return 95221
		if datediff(year, @Dob, getdate()) < 18 or datediff(year, @Dob, getdate()) > 65 return 95221
	end
	--2003/02/26E
*/
	if @AcctNo is not null
	begin
		select @PlasticType = a.PlasticType, @CardLogo = a.CardLogo, @Program = b.Program
		from iac_Account a, iss_CardLogo b
		where a.IssNo = @IssNo and a.AcctNo = @AcctNo
		and b.IssNo = a.IssNo and b.CardLogo = a.CardLogo
		if @@rowcount = 0 return 60000	-- Account not found
	end
	if @PriCardNo is not null
	begin
		if @PriSec = 'P' return 95084	-- must be secondary cardholder
		select @AcctNo = a.AcctNo, @PlasticType = a.PlasticType,
			@CardLogo = a.CardLogo, @Program = b.Program
		from iac_Card a, iss_CardLogo b
		where a.IssNo = @IssNo and a.CardNo = @PriCardNo
		and b.IssNo = a.IssNo and b.CardLogo = a.CardLogo
		if @@rowcount = 0 return 60003	-- Card number not found
	end
	if @ApplId is not null
	begin
--		if @CardType <> 'V' and @PriSec = 'S' and @PriAppcId is null return 55108	-- Primary applicant is a compulsory field
		select @PlasticType = a.PlasticType, @CardLogo = a.CardLogo, @Program = b.Program
		from iap_Application a, iss_CardLogo b
		where a.IssNo = @IssNo and a.ApplId = @ApplId
		and b.IssNo = a.IssNo and b.CardLogo = a.CardLogo
		if @@rowcount = 0 return 60022	-- Application Id not found
	end
	if @CardNo is not null
	begin
		select @rc = dbo.VerifyCardNo(@CardNo)
		if @rc = 0 return 95015	-- Card number check digit validation failed
		if not exists (select 1 from iss_CardType a, iss_CardRange b 
				where a.CardType = @CardType and b.CardRangeId = a.CardRangeId and @CardNo between (StartNo*10) and ((EndNo*10)+9))
			return 95249	-- Card Range Id not found
		if exists (select 1 from iac_Card where IssNo = @IssNo and CardNo = @CardNo)
			return 65017	-- Already exists
		if @AppcType = 'N'
		begin
			if exists (select 1 from iac_GhostCard where IssNo = @IssNo and CardNo = @CardNo)
				return 65017	-- Already exists
		end
		if @AppcType = 'G'
		begin
			if not exists (select 1 from iac_GhostCard where IssNo = @IssNo and CardNo = @CardNo)
				return 60024	-- Ghost Card not found
		end
	end

	-- Check Multiple Primary Card
	if @PriSec = 'P' and exists (select 1 from iss_PlasticType where IssNo = @IssNo
	and CardLogo = @CardLogo and PlasticType = @PlasticType and AllowMultiPri = 'N')
	begin
		if @ApplId is not null
		begin
			if @Func = 'Add'
			begin
				if exists (select 1 from iap_Applicant where IssNo = @IssNo
				and ApplId = @ApplId and PriSec = 'P')
					return 95190	-- Multiple primary card not allow
			end
			else
			begin
				if exists (select 1 from iap_Applicant where IssNo = @IssNo
				and ApplId = @ApplId and PriSec = 'P' and AppcId <> @AppcId)
					return 95190	-- Multiple primary card not allow
			end
		end
		else
		if @AcctNo is not null
		begin
			if exists (select 1 from iac_Card where AcctNo = @AcctNo and PriSec = 'P')
				return 95190	-- Multiple primary card not allow
		end
	end

	if @Program = 'F'
	begin
		if @CardType is null return 55048 --Card Type is a compulsory field
		--2003/03/03B
		--comment off by aeris 28/07/2003if @TxnLimit is null return 55148 --Transaction limit is a compulsory field
		--2003/03/03E
		if exists (select 1 from iss_RefLib where IssNo = @IssNo and RefType = 'CardType' and RefCd = @CardType and RefInd = 0)
		begin
			if isnull(@FamilyName,'') = '' return 55037
--			if isnull(@Dob,0) = 0 return 55041
		end
	end

	select @AppcPendingSts = VarCharVal
	from iss_Default
	where IssNo = @IssNo and Deft = 'AppcPendingSts'

	select @PrcsId = CtrlNo, @CreationDate = CtrlDate
	from iss_Control 
	where CtrlId = 'PrcsId' and @IssNo = IssNo 

	exec TraceProcess @IssNo, @PrcsName, @Func


	if @Func = 'Add'
	begin
		--CP 2003/12/04B
		--2003/02/26B
		--if exists (select 1 from iap_Applicant where CardType = @CardType and FamilyName = @FamilyName and AppcSts <> 'T')
		--	return 95222 -- Check duplicate applicant
		--2003/02/26E
		--CP 2003/12/04E

		if @CardNo is not null
		begin
			if exists (select 1 from iap_ReservedCardNo where IssNo = @IssNo and CardNo = @CardNo and Sts='Y')
				return 65017	-- Already exists

			if @AppcType = 'G'
			begin
				if exists (select 1 from iac_GhostCard where IssNo = @IssNo and CardNo = @CardNo and Sts is not null)
					return 95085	-- Card number in used
			end
		end

--		exec TraceProcess @IssNo, @PrcsName, 'Inserting into iap_Applicant table records'

		--------------------------
		BEGIN TRANSACTION
		--------------------------
		insert into iap_Applicant
			(IssNo, BatchId, SeqNo, ParentSeqNo, AppcType, ApplId, PriAppcId, AcctNo,
			PriCardNo, CardType, CardNo, PinInd, OdometerInd, VIPInd, FamilyName, GivenName, EmbName,
			Gender, Dob, BloodGroup, Marital, NewIc, OldIc, PassportNo, LicNo,
			PriSec, TxnLimit, ProdGroup, CostCentre, JoiningFeeCd, AnnlFeeCd,
			CmpyName, Dept, Occupation, Income, PartnerRefNo,BankName, BankAcctNo,
			VehRegsNo, VehRegsDate, Manufacturer, Model, ManufacturerDate,
			VehSvc, RoadTaxExpiry, RoadTaxAmt, RoadTaxPeriod, InsrcCmpy, PolicyNo,
			PolicyStartDate, PolicyExpiryDate, PremiumAmt, InsuredAmt,
			CreationDate, AppvDate, AppcSts, ReasonCd, UserId, PrcsId, LastUpdDate, StaffNo, GovernmentLevyFeeCd,
			JoinDate, PhotographerType, Race, Title)
		select	@IssNo, 0, 0, 0, @AppcType, @ApplId, @PriAppcId, @AcctNo,
			@PriCardNo, @CardType, @CardNo, @PinInd, @OdometerInd, @VIPInd, @FamilyName, @GivenName, @EmbName,
			@Gender, @Dob, @BloodGroup, @Marital, @NewIc, @OldIc, @PassportNo, @LicNo,
			@PriSec, @TxnLimit, @ProdGroup, @CostCentre, @JoiningFeeCd, @AnnlFeeCd,
			null, null, null, null, @PartnerRefNo, null, null,
			null, null, null, null, null,
			null, null, null, null, null, null,
			null, null, null, null,
			@CreationDate, null, isnull(@AppcPendingSts, 'P'), null, system_user, @PrcsId, getdate(),@StaffNo, @GovernmentLevyFeeCd,
			@JoinDate, @PhotographerType, @Race , @Title

		if @@error <> 0
		begin
			rollback transaction
			return 70082	-- 'Failed to create applicant'
		end

		select @AppcId = @@identity

		if @CardNo is not null and @AppcType = 'N'
		begin
			--2005/09/22 Alex[BEGIN]
			if exists (select 1 from iap_ReservedCardNo where CardNo = @CardNo and IssNo = @IssNo  and isnull(Sts, '') <> 'Y')
			begin
				update iap_ReservedCardNo
				set Sts = 'Y',
				    AppcId = @AppcId,
				    LastUpdDate =getdate()
				where CardNo =@CardNo

				if @@error <> 0
				begin
					rollback transaction
					return 70082 --Failed to create Applicant
				end
			end
			else
			begin
				insert into iap_ReservedCardNo (IssNo, AppcId, CardNo, Sts, LastUpdDate)
				select @IssNo, @AppcId, @CardNo, 'Y', getdate()
	
				if @@error <> 0
				begin
					rollback transaction
					return 70081	-- Failed to create Reserver Card Number
				end
			end
			--2005/09/22 Alex[END]
		end

		
		if @CardNo is not null and @AppcType = 'G'
		begin
			update iac_GhostCard
			set Sts = 'U'
			where IssNo = @IssNo and CardNo = @CardNo

			if @@error <> 0
			begin
				rollback transaction
				return 70187
			end
		end

		--------------------------
		COMMIT TRANSACTION
		--------------------------
		return 50170
	end

	if @Func = 'Save'
	begin
		select @OrigAppcType = AppcType, @OrigCardNo = CardNo
		from iap_Applicant
		where IssNo = @IssNo and AppcId = @AppcId

		if @@rowcount = 0
		begin
			return 60023	-- 'Applicant not found'
		end

		if @CardNo is not null
		begin
			if @CardNo <> isnull(@OrigCardNo, 0)
			begin
				if exists (select 1 from iap_ReservedCardNo where IssNo = @IssNo and CardNo = @CardNo and Sts ='Y')
					return 65017	-- Already exists

				if @AppcType = 'G'
				begin
					if exists (select 1 from iac_GhostCard where IssNo = @IssNo and CardNo = @CardNo and Sts is not null)
						return 95085	-- Card number in used
				end
			end
		end

--		exec TraceProcess @IssNo, @PrcsName, 'Updating iap_Applicant table records'
		--------------------------
		BEGIN TRANSACTION
		--------------------------
/*		if @LastUpdDate is null
			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

		select @LatestUpdDate = LastUpdDate from iap_Applicant where IssNo = @IssNo and AppcId = @AppcId
		if @LatestUpdDate is null
			select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

		-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
		-- it means that record has been updated by someone else, and screen need to be refreshed
		-- before the next update.
		
		--------------------------
		BEGIN TRANSACTION
		--------------------------

		if @LatestUpdDate = convert(datetime, @LastUpdDate)
		begin
*/
			update iap_Applicant
			set	AppcType = @AppcType, ApplId = @ApplId, PriAppcId = @PriAppcId,
				AcctNo = @AcctNo, PriCardNo = @PriCardNo, CardType = @CardType,
				CardNo = @CardNo, PinInd = @PinInd, OdometerInd = @OdometerInd, VIPInd = @VIPInd,
				FamilyName = @FamilyName, GivenName = @GivenName, EmbName = @EmbName, Gender = @Gender, Dob = @Dob,
				BloodGroup = @BloodGroup, Marital = @Marital, NewIc = @NewIc,
				OldIc = @OldIc, PassportNo = @PassportNo, LicNo = @LicNo, PriSec = @PriSec,
				TxnLimit = @TxnLimit, ProdGroup = @ProdGroup, CostCentre = @CostCentre,
				JoiningFeeCd = @JoiningFeeCd, AnnlFeeCd = @AnnlFeeCd,
				PartnerRefNo = @PartnerRefNo, StaffNo = @StaffNo, GovernmentLevyFeeCd = @GovernmentLevyFeeCd,
				JoinDate = @JoinDate, PhotographerType = @PhotographerType, 
				Race = @Race,
				Title = @Title
				--LastUpdDate = getdate()
			where	IssNo = @IssNo and AppcId = @AppcId
		
			if @@error <> 0
			begin
				rollback transaction
				return 70144	-- 'Failed to update Applicant'
			end
/*		end
		else
		begin
			rollback transaction
			return 95307 -- Session Expired
		end
*/
		if @@error <> 0
		begin
			rollback transaction
			return 70144	-- Failed to update applicant
		end

		update iac_GhostCard
		set Sts = null
		where @OrigAppcType = 'G' and @OrigCardNo is not null
		and IssNo = @IssNo and CardNo = @OrigCardNo

		if @@error <> 0
		begin
			rollback transaction
			return 70187
		end

		
		if @CardNo is not null and @AppcType = 'N'
		begin
			--2005/09/22 Alex[BEGIN]
			if exists (select 1 from iap_ReservedCardNo where AppcId = @AppcId and IssNo = @IssNo)
			begin
				update iap_ReservedCardNo
				set Sts = 'N',
				    AppcId = 0,
				    LastUpdDate =getdate()
				where  AppcId = @AppcId 
				
				if @@error <> 0
				begin
					rollback transaction
					return  70082 --Failed to create Applicant
				end
			end

			if exists (select 1 from iap_ReservedCardNo where IssNo = @IssNo and CardNo = @CardNo)
			begin
				update iap_ReservedCardNo
				set Sts = 'Y',
				    AppcId = @AppcId,
				    LastUpdDate =getdate()
				where CardNo =@CardNo

				if @@error <> 0
				begin
					rollback transaction
					return 70082 --Failed to create Applicant
				end
			end
			else
			begin
				insert into iap_ReservedCardNo (IssNo, AppcId, CardNo, Sts, LastUpdDate)
				select @IssNo, @AppcId, @CardNo, 'Y', getdate()
	
				if @@error <> 0
				begin
					rollback transaction
					return 70081 --Failed to create Reserver Card Number
				end
			
			end
			--2005/09/22 Alex [END]

		end


		if @CardNo is not null and @AppcType = 'G'
		begin
			update iac_GhostCard
			set Sts = 'U'
			where IssNo = @IssNo and CardNo = @CardNo

			if @@error <> 0
			begin
				rollback transaction
				return 70187
			end
		end

		--------------------------
		COMMIT TRANSACTION
		--------------------------
		return 50171
	end
end
GO
