USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GhostCardGen]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:Cardtrend Systems Sdn. Bhd.
Modular		:Cardtrend Card Management System (CCMS)- Issuing Module

Objective	:To generate ghost account and cards.

			Related to:
					(1) GhostCardGenDlg.cpp/GhostCardGenDlg.h - to capture tot cards to be produce.
					(2) GhostCardGenBatch - create udi_batch header.
					(3) GhostCardProcessing* - looping for udi_batch to call GhostCardGen.
					(4) GhostCardGen - To create card account tables & misc.
					(5) EmbCardExtract - To generate embossing file using xp_cmdshell.
-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2009/02/22	Sam				Reno.
2009/04/27	Chew Pei			Validate CVC len (if < 3, then pad with 0)
*******************************************************************************/
/*

declare @IssNo uIssNo,	@NoAcct smallint,	@NoCards smallint,	@CardLogo uCardLogo,	@PlasticType uPlasticType,	@CardType uCardType,	@CreationFlag char(1)
exec GhostCardGen @IssNo =1, @NoAcct =5, @NoCards =1, @CardLogo ='DEMOLTY', @PlasticType= 'PDBTEST',	@CardType= '1',	@CreationFlag ='Y'

*/
CREATE procedure [dbo].[GhostCardGen]
	@IssNo uIssNo,
	@NoAcct int,
	@NoCards smallint,
	@CardLogo uCardLogo,
	@PlasticType uPlasticType,
	@CardRangeId varchar(10),
	@CardType uCardType,
	@CreationFlag char(1),
	@BatchId int
	--@CardNo varchar(19) output

-- with encryption 
as
begin
	declare @Rc int, @x tinyint, @y tinyint, @SPName varchar(50), @CardSPName varchar(50), @AcctNo uAcctNo, @WebPw varchar(10), @CycNo uCycNo,
		@AllowanceFactor tinyint, @PrcsId uPrcsId, @BillingType varchar(10), @GhostAcctSts char(1), @GhostCardSts char(1), 
		@EntityId uEntityId, @PriCardNo uCardNo, @CardNo varchar(19), @Cvc varchar(3), @MaxPinTries tinyint,
		@SysDate datetime, @Err int, @CardExp datetime, @a int, @vSysDate varchar(8)

	set nocount on
	select @SysDate = getdate()
	select @vSysDate = convert(varchar(8),@SysDate,112)
	select @NoCards = 1
	select @MaxPinTries = 255

	if isnull(@NoCards,0) = 0 return 95082 --Number of card must greater than zero
	if @CardLogo is null return 55002 --Card logo is a compulsory field
	if @PlasticType is null return 55003 --Plastic type is a compulsory field
	if @CardType is null return 55048 --Card Type is a compulsory field

	select @a = 0, @x = 0, @y = 0
	--select @NoAcct = @NoCards, @NoCards = 1

	if not exists (select 1 from iss_CardLogo (nolock) where IssNo = @IssNo and CardLogo = @CardLogo)
		return 60005 --Card Logo not found

	if not exists (select 1 from iss_PlasticType (nolock) where IssNo = @IssNo and PlasticType = @PlasticType)
		return 95231 --Invalid Plastic Type

	select @MaxPinTries = IntVal
	from iss_Default (nolock)
	where Deft = 'MaxPinExceedCnt'

	if @@error <> 0 return 95099 --Unable to retrieve information from iss_Default table

	select @PrcsId = CtrlNo 
	from iss_Control (nolock)
	where IssNo = @IssNo and CtrlId = 'PrcsId'

	if @@error <> 0 or @@rowcount = 0 return 70368 --Failed to retrieve business date process id

	select @GhostAcctSts = VarcharVal
	from iss_Default (nolock)
	where IssNo = @IssNo and Deft = 'GhostAcctSts'

	if @@error <> 0 or @@rowcount = 0 return 95160 --Unable to retrieve control or default values

	select @GhostCardSts = VarcharVal
	from iss_Default (nolock)
	where IssNo = @IssNo and Deft = 'GhostCardSts'

	if @@error <> 0 or @@rowcount = 0 return 95160 --Unable to retrieve control or default values

	-- Get Expiry Date
	select @CardExp = dateadd(mm, CardExpiryPeriod + 1, @SysDate), 
		@BillingType = BillingType, 
		@AllowanceFactor = AllowanceFactor
	from iss_PlasticType (nolock)
	where IssNo = @IssNo and CardLogo = @CardLogo and PlasticType = @PlasticType

	if @@error <> 0 return 60013 --Plastic Type not found

	select @CardExp = cast(substring(convert(varchar,@CardExp,111),1,8) + '01' as datetime) - 1

	select @SPName = StoredProcName 
	from iss_Functions (nolock)
	where FuncName = 'GetAccountNo' and FuncType = 'P'

	select @CardSPName = StoredProcName 
	from iss_Functions (nolock) 
	where FuncName = 'GetCardNo' and FuncType = 'P'

	exec @CycNo = NextCycleNo @IssNo, @CardLogo, @PlasticType

	if @@error <> 0 return 95161 --Unable to generate cycle number

	--if isnull(@CycNo,0) = 0 return 95161 --Unable to generate cycle number

	create table #tmp_GCard
	(
		AcctNo bigint,
		CardNo bigint,
		EntityId bigint,
		Cvc varchar(3),
		WebPw varchar(15)
	)

	
	create unique index IX_Tmp_GCard
	on #tmp_GCard ( AcctNo, CardNo )




	-----------------
	BEGIN TRANSACTION
	-----------------
	
	while (@a < @NoAcct)
	begin
		exec @Rc = @CardSPName @IssNo, @CardLogo, @CardType, @CardNo output

		if @@error <> 0 or isnull(@CardNo,'') = ''
		begin
			rollback transaction
			return @Rc
		end
		
		select @AcctNo = cast(right(@CardNo,10) as bigint)

		if isnull(@AcctNo,0) = 0
		begin
			rollback transaction
			return 95093	-- Unable to generate new account number
		end

		select @WebPw = dbo.GenPassword(rand())

		exec GenerateCvc @AcctNo, @CardNo, @SysDate, @Cvc output

		if len(@Cvc) < 3
		begin
			select @Cvc = replicate ('0', 3 - len(@cvc)) + @cvc
		end

		insert into iac_Entity
			(IssNo, FamilyName, GivenName, Gender, Marital, Dob, BloodGroup, OldIc, NewIc, PassportNo, LicNo, CmpyName, 
			Dept, Occupation, Income, BankName, BankAcctNo, PriEntityId, Relationship, ApplId, AppcId, Sts, LastUpdDate)
		values
			(@IssNo, null, null, null, null, null, null, null, null, null, null, null,
			null, null, null, null, null, null, null, null,	null, null, @SysDate)

		select @Err = @@error, @EntityId = @@identity

		if @Err <> 0
		begin
			rollback transaction
			return 70189 -- Failed to create entity
		end

		if isnull(@EntityId,0) = 0
		begin
			rollback transaction
			return 95337 --Failed to retrieve Entity No
		end

		insert #tmp_GCard
			(AcctNo, CardNo, EntityId, Cvc, WebPw)
		select @AcctNo, @CardNo, @EntityId, @Cvc, @WebPw

		if @@error <> 0
		begin
			rollback transaction
			return 70271 --Failed to insert into temporary table
		end

		select @a = @a + 1
	end
	------------------
	COMMIT TRANSACTION
	------------------

	-----------------
	BEGIN TRANSACTION
	-----------------

	insert into iac_Account
		(IssNo, AcctNo, CardLogo, PlasticType, CorpCd, ApplId, EntityId, RankingPts, CycNo, PromptPaymtRebate, 
		SrcRefNo, SrcCd, InputSrc, CreationDate, CautionCd, PriceShieldInd, CmpyType, CmpyRegsName1, CmpyRegsName2, 
		CmpyName1, CmpyName2, TaxId, BusnCategory, RegsDate, RegsLocation, Shareholder, Capital, NetSales, NetProfit, 
		RequiredReport, RcptName, RcptTel, RcptFax, PymtMode, PymtAmt, BankAcctNo, AcctType, BillingType, DeliveryType,
		SendingCd, BranchCd, ApplIntroByKTC, ApplIntroBy, Remarks, PrcsId, WebPw, CardSeq, AgeingInd, AutoReinstate, 
		CaptDate, WriteOffDate, ExpiryDate, TradeNo, CustSvcId, GovernmentLevyFeeCd, MDTCANo, BusnUnit, DeptId, VoteNo, 
		POId, Sts, LastUpdDate)
	select 
		@IssNo, AcctNo, @CardLogo, @PlasticType, null, null, EntityId, 0, @CycNo, 0, 
		null, null, 'GCGen', @SysDate, null, 'Y', null, null, null,
		null, null, null, null, null, null, null, null, null, null,
		null, null, null, null, null, null, null, null, @BillingType, null,
		null, null, null, null, null, @PrcsId, WebPw, 0, 0, 'Y',
		@SysDate, null, null, null, null, null, null, null, null, null,
		null, @GhostAcctSts, null
	from #tmp_GCard

	if @@error <> 0
	begin
		rollback transaction
		return 70125	-- Failed to create account
	end

	insert into iac_AccountFinInfo
		(AcctNo, IssNo, LocNo, CreditLimit, TxnLimit, 
		LitLimit, DepositAmt, AllowanceFactor, AccumAgeingAmt, AccumAgeingPts, 
		WithheldAmt, WithheldPts, UnsettleAmt, UnsettlePts, AccruedInterestAmt, 
		AccruedCreditUsageAmt, WriteOffPrincipleAmt, WriteOffPaymtAmt, StmtDate, DueDate, 
		MinRepaymt, LegalDate, LastCashRecvDate, LastCashRecvAmt, LastPaymtRecvDate, 
		LastPaymtRecvAmt, TCBSts, LastUpdDate)
	select
		AcctNo, @IssNo, null, 0, 0, 
		0, null, isnull(@AllowanceFactor,0), 0, 0, 
		0, 0, 0, 0, 0, 
		0, 0, 0, null, null, 
		0, null, null, 0, null, 
		0, null, null
	from #tmp_GCard

	if @@error <> 0
	begin
		rollback transaction
		return 70125	-- Failed to create account
	end

	-- Tag PriSec to 'S' for supplementary card
	insert into iac_Card
		(IssNo, CardNo, CardLogo, PlasticType, CardType, 
		AcctNo, CostCentre, PriCardNo, XrefCardNo, EntityId, 
		PriSec, EmbName, MemSince, ExpiryDate, OldExpiryDate, 
		TerminationDate, RenewalInd, VIPInd, Cvc, Cvc2, 
		OdometerInd, PinInd, PinBlock, CycNo, PriorityNo, 
		CreationDate, ActivationDate, FirstTxnDate, ProdGroup, PartnerRefNo, 
		JoiningFeeCd, AnnlFeeCd, VehRegsNo, ApplId, AppcId, 
		PrcsId, DriverCd, GroupId, StaffNo, GovernmentLevyFeeCd, 
		Sts, LastUpdDate, CardChkInd)
	select
		@IssNo, CardNo, @CardLogo, @PlasticType, @CardType, 
		AcctNo, null, null, null, EntityId, 
		'P', null, @SysDate, @CardExp, null, 
		null, 'N', 'N', Cvc, null, 
		'N', 'N', null, null, null, 
		@SysDate, null, null, null, null, 
		null, null, null, 0, 0, 
		@PrcsId, null, null, null, null, 
		@GhostCardSts, null, 1
	from #tmp_GCard

	if @@error <> 0
	begin
		rollback transaction
		return 70190	-- Failed to create card
	end

	insert iac_OnlineFinInfo
		(AcctNo, IssNo, CreditLimit, TxnLimit, LitLimit, AllowanceFactor, AccumAgeingAmt, AccumAgeingPts, WithheldAmt, WithheldPts, UnsettleAmt, UnsettlePts, LastUpdDate)
	select AcctNo, @IssNo, 0, 0, 0, @AllowanceFactor, 0, 0, 0, 0, 0, 0, null
	from #tmp_GCard

	if @@error <> 0
	begin
		rollback transaction
		return 70125	-- Failed to create account
	end

	insert into iac_CardFinInfo
		(CardNo, IssNo, TxnLimit, LitLimit, LitPerDay, LitPerMth, LitDayUpdDate, LitMthUpdDate, PinExceedCnt, PinAttempted, PinTriedUpdDate, EncrVal, LastUpdDate)
	select CardNo, @IssNo, 0, 0, 0, 0, null, null, @MaxPinTries, 0, null, null, @SysDate
	from #tmp_GCard

	if @@error <> 0
	begin
		rollback transaction
		return 70191 --Failed to create Card Financial Info
	end

	--exec @BatchId = NextRunNo @IssNo, 'EMBBatchId'

	--if @@rowcount = 0 or @@error <> 0  
	--begin
	--	rollback transaction
	--	return 70395 --Failed to create new batch
	--end

	insert into iac_PlasticCard 
		(IssNo, BatchId, CardLogo, PlasticType, AcctNo, 
		CardNo, EmbName, ExpiryDate, CVC1, DeliveryMethod, 
		CourierCmpy, HandCollectionDate, InputSrc, CreationDate, Sts, 
		SendingCd, BranchCd, ZipCd)
	select
		@IssNo, @BatchId, @CardLogo, @PlasticType, AcctNo, 
		CardNo, null, @CardExp, null, null, 
		null, null, 'GCGen', @SysDate, 'E', 
		null, null, null
	from #tmp_GCard
	order by CardNo 

	if @@error <> 0
	begin
		rollback transaction
		return 70352 --Failed to create Plastic Card
	end

	

	------------------
	COMMIT TRANSACTION
	------------------
	return 54027 --Embossing file extracted successfully
end
GO
