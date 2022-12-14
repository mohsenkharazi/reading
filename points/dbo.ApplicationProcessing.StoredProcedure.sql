USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ApplicationProcessing]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- KTC CCMS
Objective	:Perform application processing during the End-of-day

------------------------------------------------------------------------------------------------------
When	   	Who		CRN			Description
------------------------------------------------------------------------------------------------------
2009/03/24	Chew Pei			Changes made to cater for PDB, main changes : produce card number first before
								producing account number.
2009/
********************************************************************************************************/
--ApplicationProcessing 1,0

CREATE	procedure [dbo].[ApplicationProcessing]
	@IssNo uIssNo,
	@BatchId uBatchId
  as
begin
	declare	@RecCnt int,
			@PrcsName varchar(50),
			@BatchSts char(1),
			@PrcsId uPrcsId,
			@PrcsDate datetime,
			@FileDate datetime,
			@UDIDate datetime,
			@Filename nvarchar(15),
			@ApplId uApplId,
			@AppcId uAppcId,
			@AcctNo bigint,
			@CardNo bigint,
			@CardType int,
			@PriSec char(1),
			@CycNo uCycNo,
			@DepositAmt money,
			@PlasticType uPlasticType,
			@CardLogo nvarchar(8),
			@WebPw uPw,
			@PinBlock char(16),
			@rc int,
			@NewAcctSts char(2),
			@NewCardSts char(1),
			@ApplTrsfSts char(1),
			@AppcTrsfSts char(1),
			@CardCenterBusnLocation uMerch,
			@CardCenterTermId uTermId,
			@IssCrryCd uRefCd,
			@NoOfRec int,
			@Complete char(1),
			@SPName varchar(40),
			@ExpiryDate datetime,
			@ExpiryInd char(1),
			@Cvc varchar(3),
			@StoreName uBusnName,
			@SysDate datetime,
			@CardExp datetime,
			@NewContactCardNos syn_CardNumber
			

	select @PrcsName = 'Application Processing'

	exec TraceProcess @IssNo, @PrcsName, 'Beginning Application Processing'

	--------------------------------------------------------------------------
	-- Basic Validation/Verification Check for Batch/Application and Applicant
	--------------------------------------------------------------------------

	if isnull(@BatchId,0) < 0 return 95092	-- Invalid batch id

	if isnull(@IssNo,0) < 0 return 60027	-- Issuer not found

	select @SysDate = getdate()

	if @BatchId > 0	-- Batch Application
	begin
		select	@RecCnt = RecCnt, @BatchSts = Sts, @FileDate = FileDate,
			@UDIDate = PrcsDate, @Filename = Filename
		from udi_Batch
		where @BatchId = BatchId and @IssNo = IssNo

		if @@rowcount = 0 return 60028	-- Batch not found
	end

	if not exists (select 1 from iss_Issuer where IssNo = @IssNo) return 60027

	-- Obtain Process Info
	select @PrcsId = CtrlNo, @PrcsDate = CtrlDate
	from iss_Control 
	where CtrlId = 'PrcsId' and @IssNo = IssNo 

	-- CP 20040722 [B]
	--select @ExpiryInd = RefCd 
	--from iss_Reflib
	--where IssNo = @IssNo and RefType = 'ExpiryInd' and RefNo = 1 -- Expiry at Acct Level
	-- CP 20040722 [E]

	select @Complete = 'Y'	-- Initialize indicator to complete

	----------------------------
	-- Application Validation --
	----------------------------
	select	a.ApplId, a.CardLogo, a.PlasticType, a.CreationDate,
		convert(bigint, null) 'AcctNo', a.CycNo 'CycNo', a.DepositAmt, a.ExpiryDate,
		convert(varchar(6), null) 'WebPw', convert(char(1), null) 'Sts', a.StoreName
	into #Application
	from iap_Application a, iss_RefLib b
	where a.IssNo = @IssNo and a.BatchId = @BatchId and b.IssNo = a.IssNo
	and b.RefType = 'ApplSts' and b.RefCd = a.ApplSts and b.RefInd = 0 and convert(varchar(10),a.AppvDate,112) <= convert(varchar(10),@PrcsDate,112) --2003/12/15

	update a set a.Sts = 'L'	-- Invalid card logo
	from #Application a
	where not exists (select 1 from iss_CardLogo b
			where b.IssNo = @IssNo and b.CardLogo = a.CardLogo)

	update a set a.Sts = 'P'	-- Invalid plastic type
	from #Application a
	where a.Sts is null and not exists (select 1 from iss_PlasticType b
			where b.IssNo = @IssNo and b.PlasticType = a.PlasticType
			and b.CardLogo = a.CardLogo)

	update a set a.Sts = 'F'	-- Invalid creation date
	from #Application a
	where a.Sts is null and a.CreationDate > @PrcsDate

	update a set a.Sts = 'T'	-- Application already transferred
	from #Application a
	where a.Sts is null and exists (select 1 from iac_Account b
		where b.IssNo = @IssNo and b.ApplId = a.ApplId)

	update a set a.Sts = 'X' -- Only Application is created, no applicant is created
	from #Application a
	where a.Sts is null and not exists (select 1 from iap_Applicant b where b.ApplId = a.ApplId) 

	update a set a.Sts = 'Y' -- Only Application is approved, but applicant is still pending
	from #Application a
	where a.Sts is null and exists (select 1 from iap_Applicant b, iss_Reflib c where b.ApplId = a.ApplId and c.RefType = 'AppcSts' and c.RefCd = b.AppcSts and c.RefInd = 1 and c.IssNo = @IssNo)

	update a set a.Sts = b.Sts	-- Update Application Status
	from iap_Application a, #Application b
	where a.IssNo = @IssNo and a.ApplId = b.ApplId

	--------------------------
	-- Applicant Validation --
	--------------------------
	-- 2003/11/11 - Added identity col
	select identity(int,1,1) 'TxnSeq', a.AppcId, a.ApplId, a.AcctNo, a.PriCardNo, a.PriAppcId, a.CardNo, a.CardType, a.PriSec,
		a.CreationDate, convert(nvarchar(8), null) 'CardLogo', convert(nvarchar(8), null) 'PlasticType', convert(datetime, null) 'ExpiryDate',
		convert(int, null) 'EntityId', convert(char(16), null) 'PinBlock', convert(varchar(3), null) 'Cvc',
		convert(char(1), null) 'Sts'
		--2003/03/11B-
		, convert(char(1), null) 'VehInd'
		--2003/03/11E
	into #Applicant
	from iap_Applicant a, iss_RefLib b
	where a.IssNo = @IssNo and a.BatchId = @BatchId and b.IssNo = a.IssNo
	and b.RefType = 'AppcSts' and b.RefCd = a.AppcSts and b.RefInd = 0 and convert(varchar(10),a.AppvDate,112) <= convert(varchar(10),@PrcsDate,112) --2003/12/15

	-- Populate CardLogo and PlasticType
	update a set CardLogo = b.CardLogo, PlasticType = b.PlasticType
	from #Applicant a, iap_Application b
	where a.ApplId is not null and b.IssNo = @IssNo and b.ApplId = a.ApplId

	update a set CardLogo = b.CardLogo, PlasticType = b.PlasticType
	from #Applicant a, iac_Account b
	where a.AcctNo is not null and b.IssNo = @IssNo and b.AcctNo = a.AcctNo

	update a set CardLogo = b.CardLogo, PlasticType = b.PlasticType
	from #Applicant a, iac_Card b
	where a.PriCardNo is not null and b.IssNo = @IssNo and b.CardNo = a.PriCardNo

	update a set a.Sts = 'F'	-- Invalid creation date
	from #Applicant a
	where a.Sts is null and a.CreationDate > @PrcsDate

	update a set a.Sts = 'K'	-- No primary key
	from #Applicant a
	where a.Sts is null and a.ApplId is null and a.AcctNo is null and a.PriCardNo is null

	update a set a.Sts = 'V'	-- Vehicle registration not found
	from #Applicant a, iap_Applicant b, iss_CardType c
	where a.Sts is null and b.IssNo = @IssNo and b.AppcId = a.AppcId and b.CardType = c.CardType and c.VehInd = 'Y' -- b.CardType in ('V','B')
	and b.VehRegsNo is null

	-- CP: 20040428[B]
	update a set a.Sts = 'Q'	-- Card Type does not exists in iss_CardType
	from #Applicant a, iap_Application b 
	where a.ApplId = b.ApplId and not exists (select 1 from iss_CardType c where a.CardType = c.CardType and b.CardLogo = c.CardLogo)
	-- CP: 20040428[E]

	update a set a.Sts = 'M'	-- Mandatory field not present
	from #Applicant a, iap_Applicant b
	where a.Sts is null and b.IssNo = @IssNo and b.AppcId = a.AppcId and (b.EmbName is null
	or b.AppcSts is null or b.AppcType is null or b.PriSec is null
	or (b.AppcType = 'G' and b.CardNo is null))

	update a set a.Sts = 'A'	-- Application not found
	from #Applicant a
	where a.ApplId is not null
	and not exists (select 1 from iap_Application b where b.IssNo = @IssNo and b.ApplId = a.ApplId)

	update a set a.Sts = 'R'	-- Application not approve()
	from #Applicant a, iap_Application b, iss_RefLib c
	where a.Sts is null and a.ApplId is not null and b.ApplId = a.ApplId
	and b.IssNo = @IssNo and c.IssNo = @IssNo and c.RefType = 'ApplSts'
	and c.RefCd = b.ApplSts and (c.RefInd not in (0, 3) or b.Sts is not null)

	update a set a.Sts = 'Z'	-- Primary applicant not found
	from #Applicant a
	where a.Sts is null and a.PriAppcId is not null
	and not exists (select 1 from iap_Applicant b
			where b.IssNo = @IssNo and b.AppcId = a.PriAppcId)

	update a set a.Sts = 'N'	-- Primary applicant not referencing to same application
	from #Applicant a, iap_Applicant b
	where a.Sts is null and a.PriAppcId is not null
	and b.IssNo = @IssNo and b.AppcId = a.PriAppcId and b.ApplId <> a.ApplId

	update a set a.Sts = 'P'	-- Primary applicant not approve
	from #Applicant a, iap_Applicant b, iss_RefLib c
	where a.Sts is null and a.PriAppcId is not null
	and b.IssNo = @IssNo and b.AppcId = a.PriAppcId
	and c.IssNo = @IssNo and c.RefType = 'AppcSts' and c.RefCd = b.AppcSts
	and c.RefInd not in (0, 3)

	update a set a.Sts = 'S'	-- Invalid Primary Secondary indicator
	from #Applicant a
	where a.Sts is null and a.PriSec not in ('P', 'S')

	update a set a.Sts = 'I'	-- Primary applicant is not primary card
	from #Applicant a, iap_Applicant b
	where a.Sts is null and a.PriAppcId is not null and a.PriSec = 'S'
	and b.IssNo = @IssNo and b.AppcId = a.PriAppcId and b.PriSec <> 'P'

	update a set a.Sts = 'E'	-- Account not found
	from #Applicant a
	where a.Sts is null and a.AcctNo is not null
	and not exists (select 1 from iac_Account b where b.IssNo = @IssNo and b.AcctNo = a.AcctNo)

	update a set a.Sts = 'H'	-- Account status not good
	from #Applicant a, iac_Account b, iss_RefLib c
	where a.Sts is null and a.AcctNo is not null
	and b.IssNo = @IssNo and b.AcctNo = a.AcctNo and c.IssNo = @IssNo
	and c.RefType = 'AcctSts' and c.RefCd = b.Sts and c.RefInd <> 0

	update a set a.Sts = 'D'	-- Invalid Primary Card number
	from #Applicant a
	where a.Sts is null and a.PriCardNo is not null and dbo.VerifyCardNo(a.PriCardNo) = 0

	update a set a.Sts = 'J'	-- Invalid Card number
	from #Applicant a
	where a.Sts is null and a.CardNo is not null and dbo.VerifyCardNo(a.CardNo) = 0

	update a set a.Sts = 'C'	-- Card not found
	from #Applicant a
	where a.Sts is null and a.PriCardNo is not null
	and not exists (select 1 from iac_Card b where b.IssNo = @IssNo and b.CardNo = a.PriCardNo)

	update a set a.Sts = 'G'	-- Card is not primary card or Card status is not good
	from #Applicant a, iac_Card b, iss_RefLib c
	where a.Sts is null and a.PriCardNo is not null
	and b.IssNo = @IssNo and b.CardNo = a.PriCardNo and c.IssNo = @IssNo
	and c.RefType = 'CardSts' and c.RefCd = b.Sts and (c.RefInd <> 0 or b.PriSec <> 'P')

	update a set a.Sts = 'O'	-- Invalid Ghost card number
	from #Applicant a, iap_Applicant b
	where a.Sts is null and b.IssNo = @IssNo and b.AppcId = a.AppcId and b.AppcType = 'G'
	and not exists (select 1 from iac_GhostCard c
			where c.IssNo = @IssNo and c.CardNo = a.CardNo and c.Sts = 'U')

	update a set a.Sts = 'T'	-- Applicant already transferred
	from #Applicant a
	where a.Sts is null and exists (select 1 from iac_Entity b
		where b.IssNo = @IssNo and b.AppcId = a.AppcId)

	update a set a.Sts = 'T'	-- Applicant already transferred
	from #Applicant a
	where a.Sts is null and exists (select 1 from iac_Card b
		where b.IssNo = @IssNo and b.AppcId = a.AppcId)

	update a set a.Sts = b.Sts, a.PrcsDate = @PrcsDate	-- Update applicant status
	from iap_Applicant a, #Applicant b
	where a.IssNo = @IssNo and a.AppcId = b.AppcId


	if not exists (select 1 from iss_Control where IssNo = @IssNo and CtrlId = 'AcctNo')
		return 95093	-- Unable to generate new account number

	-------------------------------
	-- Creating Temporary Tables --
	-------------------------------
	select * into #SourceTxn
	from itx_SourceTxn
	where BatchId = -1
	delete #SourceTxn

	select * into #SourceTxnDetail
	from itx_SourceTxnDetail
	where BatchId = -1
	delete #SourceTxnDetail

	-- Creating index for temporary table
	create	unique index IX_SourceTxnDetail on #SourceTxnDetail (
		BatchId,
		ParentSeq,
		TxnSeq )

	-----------------------------------
	-- Generating new account number --
	-----------------------------------
	if exists (select 1 from #Application where Sts is not null) select Complete = 'N'

	delete #Application where Sts is not null	-- Delete rejected application
	
	if exists (select 1 from #Applicant where Sts is not null) select Complete = 'N'

	delete #Applicant where Sts is not null	-- Delete rejected applicant

	select @AppcId = min(AppcId) from #Applicant

	while @AppcId is not null
	begin
		select	@ApplId = ApplId, @AcctNo = AcctNo, @CardNo = CardNo, @CardLogo = CardLogo, @CardType = CardType, 
			@PriSec = PriSec, @PlasticType = PlasticType
		from #Applicant
		where AppcId = @AppcId

		if @CardNo is null

		begin
			select @SPName = StoredProcName from iss_Functions where FuncName = 'GetCardNo' and FuncType = 'P'
			exec @SPName @IssNo, @CardLogo, @CardType, @CardNo output
			if @@error <> 0
			begin
				return @rc
			end

		end

		select @PinBlock = null
		if exists (select 1 from iap_Applicant where IssNo = @IssNo and AppcId = @AppcId and PinInd = 'Y')
		begin
			exec GeneratePIN @CardNo, @PinBlock output
			if @@error <> 0
			begin
				return 95189	-- Unable to generate PIN
			end
			if @PinBlock is null
			begin
				return 95189	-- Unable to generate PIN
			end
		end

		select @AcctNo = cast(right(@CardNo,10) as bigint)
		-- CP 2004/07/28 [B] Get Cvc number 
		exec GenerateCvc @AcctNo, @CardNo, @SysDate, @Cvc output
		if @@error <> 0
		begin
			return 95308 -- Failed to generate Cvc
		end
		-- CP 2004/07/28 [E]
		if len(@Cvc) < 3
		begin
			select @Cvc = replicate ('0', 3 - len(@cvc)) + @cvc
		end

		select @CardExp = dateadd(mm, CardExpiryPeriod + 1, @SysDate)
		from iss_PlasticType (nolock)
		where IssNo = @IssNo and CardLogo = @CardLogo and PlasticType = @PlasticType

		if @@error <> 0 
		begin
			return 60013 --Plastic Type not found
		end

		select @CardExp = cast(substring(convert(varchar,@CardExp,111),1,8) + '01' as datetime) - 1
		update #Applicant set AcctNo = @AcctNo, CardNo = @CardNo, PinBlock = @PinBlock, Cvc = @Cvc, ExpiryDate = @CardExp
		where AppcId = @AppcId
		if @@error <> 0
		begin
			return 95094	-- Unable to generate card number
		end

		-- CP : 20040728 ExpiryDate 
		-- Set Applicant ExpiryDate, If ExpiryInd = 'A', then update card expiry date same as account level, 
		-- else card expiry is set based on CardExpiryPeriod		 
		--update a
		--set ExpiryDate = case c.ExpiryInd when @ExpiryInd then b.ExpiryDate else dateadd(mm, c.CardExpiryPeriod, @PrcsDate) end
		--from #Applicant a, iac_Account b, iss_PlasticType c
		--where a.AppcId = @AppcId and a.PlasticType = @PlasticType and a.PlasticType = b.PlasticType and b.PlasticType = c.PlasticType 
		--and a.CardLogo = @CardLogo and a.CardType = @CardType and a.AcctNo = @AcctNo
		-- CP : 20040728 

		select @AppcId = min(AppcId)
		from #Applicant
		where AppcId > @AppcId -- and CardNo is null  -- CP 20050926
		if @@rowcount = 0 break
	end

	update a
	set AcctNo = b.AcctNo
	from #Application a
	join #Applicant b on b.ApplId = a.ApplId
	if @@error <> 0 return 70188 -- Failed to update Application

	select @ApplId = min(ApplId) from #Application

	while @ApplId is not null
	begin
		select @CardLogo = CardLogo, @PlasticType = PlasticType, @CycNo = CycNo, @ExpiryDate = ExpiryDate
		from #Application where ApplId = @ApplId

		--select @SPName = StoredProcName from iss_Functions 
		--where FuncName = 'GetAccountNo' and FuncType = 'P'
		
		--exec @SPName @IssNo, @CardLogo, @AcctNo output


		If @@error <> 0 
		begin
			return 95093	-- Unable to generate new account number
		end
		-- CRN: 1103001 [E]

--		exec @AcctNo = NextRunNo @IssNo, 'AcctNo'
--		exec @rc = NextAccountNo @IssNo, @CardLogo, @PlasticType, @AcctNo output
		
		if @@error <> 0 or @rc <> 0 return 95093	-- Unable to generate account number

		if @CycNo is null
		begin
			exec @CycNo = NextCycleNo @IssNo, @CardLogo, @PlasticType
			if @@error <> 0 return 95161	-- Unable to generate cycle number
		end

		select @WebPw = dbo.GenPassword(rand())

		update #Application set CycNo = @CycNo, WebPw = @WebPw
		where ApplId = @ApplId
		if @@error <> 0 return 95095	-- Unable to generate account number

		-- CP : 20040728 [B] ExpiryDate
		update a
		set ExpiryDate = case b.ExpiryInd when @ExpiryInd then dateadd(mm, b.CardExpiryPeriod, @PrcsDate) end
		from #Application a, iss_PlasticType b
		where a.PlasticType = b.PlasticType and a.ApplId = @ApplId
		if @@error <> 0 return 70188 -- Failed to update Application
		-- CP : 20040728[E]
		
		select @ApplId = min(ApplId) from #Application where ApplId > @ApplId
		if @@rowcount = 0 break
	end


	-----------------
	BEGIN TRANSACTION
	-----------------

	--------------------
	-- ALTER  Account --
	--------------------
	select @NewAcctSts = VarcharVal
	from iss_Default
	where IssNo = @IssNo and Deft = 'NewAcctSts'

	select @ApplTrsfSts = VarcharVal
	from iss_Default
	where IssNo = @IssNo and Deft = 'ApplTrsfSts'
	
	-- Creating entry in the iac_Account
	insert into iac_Account
		(IssNo, AcctNo, CardLogo, PlasticType, CorpCd, ApplId, EntityId,
		RankingPts, CycNo, PromptPaymtRebate, SrcRefNo, SrcCd, InputSrc,
		--2003/03/16B
		--CreationDate, CautionCd, PrcsId, WebPw, Sts, AgeingInd, CaptDate, CardSeq)
		CreationDate, CautionCd, PrcsId, WebPw, Sts, AgeingInd, CaptDate, CardSeq, PriceShieldInd,
		--2003/03/16E
		-- CRN: 1103003 [B]
		CmpyType, CmpyRegsName1, CmpyRegsName2, CmpyName1, CmpyName2, BusnCategory,
		RegsDate, Capital, NetSales, TaxId, RegsLocation, ShareHolder, NetProfit,
		RequiredReport, PymtMode, BankAcctNo, DeliveryType, BranchCd, SendingCd,
		--2003/10/06B
		--ApplIntroBy, RcptName, RcptTel, RcptFax)
		ApplIntroBy, RcptName, RcptTel, RcptFax, ExpiryDate, TradeNo, Remarks,
		--2003/10/06B
		-- CRN: 1103003 [E]
		GovernmentLevyFeeCd,
		--2004/11/28, Alex add GovernmentLevyFeeCd
		PymtAmt, AcctType, BillingType, StoreName)
		--2005/09/20  Alex
	select	b.IssNo, a.AcctNo, b.CardLogo, b.PlasticType, b.CorpCd, a.ApplId, null,
		0, a.CycNo, 0, b.SrcRefNo, b.SrcCd, b.InputSrc,
		--2003/03/16B
		--@PrcsDate, null, @PrcsId, a.WebPw, isnull(@NewAcctSts, 'P'), 0, b.CreationDate, 0
		@PrcsDate, null, @PrcsId, a.WebPw, isnull(@NewAcctSts, 'P'), 0, b.CreationDate, 0, b.PriceShieldInd,
		--2003/03/16E
		-- CRN: 1103003 [B]
		b.CmpyType, b.CmpyRegsName1, b.CmpyRegsName2, b.CmpyName1, b.CmpyName2, b.BusnCategory,
		b.RegsDate, b.Capital, b.NetSales, b.TaxId, b.RegsLocation, b.ShareHolder, b.NetProfit,
		b.RequiredReport, b.PymtMode, b.BankAcctNo, b.DeliveryType, b.BranchCd, b.SendingCd, 
		--2003/10/06B
		--b.ApplIntroBy, b.RcptName, b.RcptTel, b.RcptFax
		b.ApplIntroBy, b.RcptName, b.RcptTel, b.RcptFax, a.ExpiryDate, b.TradeNo, b.Remarks,
		--2003/10/06E
		-- CRN: 1103003 [E]
		b.GovernmentLevyFeeCd,
		--2004/11/28, Alex Add GovernmentLevyFeeCd
		b.PymtAmt, b.AcctType, b.BillingType, b.StoreName
	from #Application a, iap_Application b, iss_PlasticType c
	where b.IssNo = @IssNo and b.ApplId = a.ApplId and c.PlasticType = a.PlasticType and c.IssNo = @IssNo

	if @@error <> 0
	begin
		rollback transaction
		return 70125	-- Failed to ALTER  account
	end

	-- Creating entry in the iac_AccountFinInfo 
	insert into iac_AccountFinInfo
		(AcctNo, IssNo, CreditLimit, TxnLimit, DepositAmt, AllowanceFactor,
		AccumAgeingAmt, AccumAgeingPts, WithheldAmt,
		WithheldPts, UnsettleAmt, UnsettlePts, LitLimit)
	select	a.AcctNo, @IssNo, isnull(b.CreditLimit,0), 0, b.DepositAmt, c.AllowanceFactor, 0, 0, 0, 0, 0, 0, 0
	from #Application a, iap_Application b, iss_PlasticType c
	where b.IssNo = @IssNo and b.ApplId = a.ApplId and c.IssNo = @IssNo
	and c.CardLogo = a.CardLogo and c.PlasticType = a.PlasticType

	if @@error <> 0
	begin
		rollback transaction
		return 70125	-- Failed to create account
	end

	--2009/03/22B
	insert into iac_OnlineFinInfo
		(AcctNo, IssNo, CreditLimit, TxnLimit, AllowanceFactor,
		AccumAgeingAmt, AccumAgeingPts, WithheldAmt,
		WithheldPts, UnsettleAmt, UnsettlePts, LitLimit)
	select a.AcctNo, @IssNo, 0, 0, 0, 
		0, 0, 0, 
		0, 0, 0, 0
	from #Application a, iap_Application b, iss_PlasticType c
	where b.IssNo = @IssNo and b.ApplId = a.ApplId and c.IssNo = @IssNo
	and c.CardLogo = a.CardLogo and c.PlasticType = a.PlasticType

	if @@error <> 0
	begin
		rollback transaction
		return 70125	-- Failed to create account
	end
	--2009/03/22E

	--2003/08/12B
	-- Creating entry in the iac_AccountVelocityLimit
	--insert into iac_AccountVelocityLimit
	--	(AcctNo, VelocityInd, ProdCd, VelocityLimit, VelocityCnt, SpentLimit, SpentCnt)
	--select a.AcctNo, c.VelocityInd, c.ProdCd, c.VelocityLimit, c.VelocityCnt, 0, 0
	--from #Application a, iap_Application b, iss_PlasticTypeVelocityLimit c
	--where b.IssNo = @IssNo and b.ApplId = a.ApplId and c.IssNo = @IssNo
	--and c.CardLogo = b.CardLogo and c.PlasticType = b.PlasticType and c.AcctCardInd = 'A'

	-- Creating entry in iac_CardVelocityLimit
	insert into iac_AccountVelocityLimit
		(AcctNo, VelocityInd, ProdCd, VelocityLimit, VelocityCnt, VelocityLitre,
		SpentLimit, SpentCnt, LastUpdDate)
	select a.AcctNo, b.VelocityInd, b.ProdCd, b.VelocityLimit, b.VelocityCnt, b.VelocityLitre,
		0, 0, getdate()
	from #Application a, iap_ApplicationVelocityLimit b
	where b.ApplId = a.ApplId
	--2003/08/12E

	if @@error <> 0
	begin
		rollback transaction
		return 70125	-- Failed to create account
	end

	-- CP 20050331[B] -- Add into iac_AccountVelocityLimit from iss_PlasticTypeVelocityLimit where VelocityInd = 'A'
	insert into iac_AccountVelocityLimit
		(AcctNo, VelocityInd, ProdCd, VelocityLimit, VelocityCnt, VelocityLitre,
		SpentLimit, SpentCnt, LastUpdDate)
	select a.AcctNo, b.VelocityInd, b.ProdCd, b.VelocityLimit, b.VelocityCnt, 0, 
		0, 0, getdate()
	from #Application a, iss_PlasticTypeVelocityLimit b
	where b.IssNo = @IssNo and b.CardLogo = a.CardLogo and b.PlasticType = a.PlasticType 
	and b.AcctCardInd = 'A' and not exists (select 1 from iac_AccountVelocityLimit c where c.AcctNo = a.AcctNo)

	if @@error <> 0
	begin
		rollback transaction
		return 70072	-- Failed to create velocity limit
	end
	-- CP 20050331[E]

	-- Update Driver List
--	update b set AcctNo = a.AcctNo
--	from #Application a, iac_Driver b
--	where b.IssNo = @IssNo and b.ApplId = a.ApplId

--	if @@error <> 0
--	begin
--		rollback transaction
--		return 70379	-- Failed to update Driver Info
--	end

	-- Updating Application
	update a
	set a.AcctNo = b.AcctNo, a.ApplSts = isnull(@ApplTrsfSts, 'T'), a.TrsfDate = @PrcsDate, a.ExpiryDate = b.ExpiryDate
	from iap_Application a, #Application b
	where a.IssNo = @IssNo and a.ApplId = b.ApplId

	if @@error <> 0
	begin
		rollback transaction
		return 70188	-- Failed to update application
	end


	--------------------------------
	-- Generating new card number --
	--------------------------------
/*	-- Commented as there AcctNo has already been put into #Applicant earlier
	update a set AcctNo = b.AcctNo	-- Populate Account number from Application
	from #Applicant a, iap_Application b
	where a.ApplId is not null and b.IssNo = @IssNo and b.ApplId = a.ApplId

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temp. table
	end
*/
	update a set PriCardNo = b.CardNo	-- Populate primary card number from temp. table
	from #Applicant a, #Applicant b
	where a.PriSec = 'S' and a.PriAppcId is not null and b.AppcId = a.PriAppcId
	and b.PriSec = 'P'

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temp. table
	end

	update a set PriCardNo = b.CardNo	-- Populate primary card number from applicant
	from #Applicant a, iap_Applicant b
	where a.PriCardNo is null and a.PriSec = 'S' and a.PriAppcId is not null
	and b.AppcId = a.PriAppcId and b.PriSec = 'P'

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temp. table
	end

	update a set Acctno = b.AcctNo	-- Populate Account number from Card
	from #Applicant a, iac_Card b
	where a.PriCardNo is not null and b.IssNo = @IssNo and b.CardNo = a.PriCardNo

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temp. table
	end



	-----------------

	-- Create Card --
	-----------------
	select @NewCardSts = VarcharVal
	from iss_Default
	where IssNo = @IssNo and Deft = 'NewCardSts'

	select @AppcTrsfSts = VarcharVal
	from iss_Default
	where IssNo = @IssNo and Deft = 'AppcTrsfSts'

	-- Creating entry in iac_Entity
	insert into iac_Entity
		(IssNo, FamilyName, GivenName, Race, Title, Gender, Marital, Dob, BloodGroup, OldIc,
		NewIc, PassportNo, LicNo, CmpyName, Dept, Occupation, Income, BankName,
		BankAcctNo, ApplId, AppcId, 
		PrefLanguage, PrefCommunication, Interest, InterestInp, Television, TelevisionInp, 
		Radio, RadioInp, NewsPaper, NewsPaperInp, SignDate)		
	select	@IssNo, b.FamilyName, b.GivenName, b.Race, b.Title, b.Gender, b.Marital, b.Dob, b.BloodGroup, b.OldIc,
		b.NewIc, b.PassportNo, b.LicNo, b.CmpyName, b.Dept, b.Occupation, b.Income, b.BankName,
		b.BankAcctNo, b.ApplId, b.AppcId, 
		b.PrefLanguage, b.PrefCommunication, b.Interest, b.InterestInp, b.Television, b.TelevisionInp, 
		b.Radio, b.RadioInp, b.NewsPaper, b.NewsPaperInp, b.SignDate
	from #Applicant a, iap_Applicant b
	where b.IssNo = @IssNo and b.AppcId = a.AppcId

	if @@error <> 0
	begin
		rollback transaction
		return 70189	-- Failed to create entity
	end


	update a set a.EntityId = b.EntityId	-- Update entity id in temp. table
	from #Applicant a, iac_Entity b
	where b.IssNo = @IssNo and b.AppcId = a.AppcId

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temp. table
	end

	-- Creating entry in iss_Address
	insert into iss_Address
		(IssNo, RefTo, RefKey, RefType, RefCd, Street1, Street2,
		Street3, State, ZipCd, Ctry, MailingInd, LastUpdDate)
	select @IssNo, 'ENTT', b.EntityId, a.RefType, a.RefCd, a.Street1, a.Street2,
		a.Street3, a.State, a.ZipCd, a.Ctry, case when b.PriSec = 'P' then 'Y' else 'N' end, getdate()
	from iss_Address a, #Applicant b
	where a.IssNo = @IssNo and a.RefTo = 'APPC' and a.RefKey = b.AppcId

	if @@error <> 0
	begin
		rollback transaction
		return 70176	-- Failed to insert address
	end


	-- Creating entry in iss_Contact
	--Add in occupation by aeris 2003/07/11B
	insert into iss_Contact
		(IssNo, RefTo, RefKey, RefType, RefCd, ContactName, Occupation, ContactNo, Sts, EmailAddr, PromoteInd, LastUpdDate)
	--Add in occupation by aeris 2003/07/11E
	select @IssNo, 'ENTT', b.EntityId, a.RefType, a.RefCd, a.ContactName, a.Occupation, a.ContactNo, 'A', a.EmailAddr, a.PromoteInd, getdate()
	from iss_Contact a, #Applicant b
	where a.IssNo = @IssNo and a.RefTo = 'APPC' and a.RefKey = b.AppcId

	if @@error <> 0
	begin
		rollback transaction
		return 70084	-- Failed to insert Contact
	end

	-- Creating entry in iac_Card
	--2004/11/23 Alex
	--Add StaffNo new column to iac_Card
	insert into iac_Card
		(IssNo, CardNo, CardLogo, PlasticType, CardType, AcctNo, PriCardNo,
		EntityId, PriSec, EmbName, MemSince, ExpiryDate, OdometerInd, Cvc, PinInd, PinBlock,
		RenewalInd, CreationDate, ProdGroup, CostCentre, PartnerRefNo, JoiningFeeCd,
		AnnlFeeCd, VehRegsNo, ApplId, AppcId, PrcsId,Sts, StaffNo, 
		GovernmentLevyFeeCd,
		--2004/11/26 Alex Add governmentLevyFeeCd)
		VIPInd,
		--2005/09/20 Alex
		JoinDate,
		PhotographerType)
		--2008/03/06 Peggy
	select @IssNo, a.CardNo, a.Cardlogo, a.PlasticType, b.CardType, a.AcctNo, a.PriCardNo,
		a.EntityId, b.PriSec, b.EmbName, @PrcsDate, a.ExpiryDate, b.OdometerInd, a.Cvc, b.PinInd, a.PinBlock,
		'Y', getdate(), b.ProdGroup, b.CostCentre, b.PartnerRefNo, b.JoiningFeeCd,
		b.AnnlFeeCd, b.VehRegsNo, a.ApplId, a.AppcId, @PrcsId , isnull(@NewCardSts, 'P'), b.StaffNo,
		b.GovernmentLevyFeeCd,
		--2004/11/26 Alex Add governmentLevyFeeCd
		b.VIPInd,
		--2005/09/20 Alex
		b.JoinDate,	
		b.PhotographerType
		--2008/03/06 Peggy
	from #Applicant a, iap_Applicant b, iss_PlasticType c
	where b.IssNo = @IssNo and b.AppcId = a.AppcId and c.IssNo = @IssNo
	and c.CardLogo = a.CardLogo and c.PlasticType = a.PlasticType 

	if @@error <> 0
	begin
		rollback transaction
		return 70190	-- Failed to create card
	end
	else
	begin
	
		INSERT INTO @NewContactCardNos
		select a.CardNo
		from #Applicant a (nolock)
		join iss_Contact b (nolock) on b.RefKey = a.EntityId 
		INNER JOIN iss_Reflib c (nolock) on c.RefCd = b.RefCd and c.RefType = 'contact' and c.Descp = 'Mobile No'

		EXEC @rc = usp_CommandQueue_Insert_CreateCardContactCommand_Bulk @NewContactCardNos
	end

	-- Creating entry in iac_CardFinInfo
	insert into iac_CardFinInfo
		(CardNo, IssNo, TxnLimit, LitLimit, LitPerDay, LitPerMth, LitDayUpdDate,
		LitMthUpdDate, PinExceedCnt, PinAttempted, PinTriedUpdDate, EncrVal, LastUpdDate)
	select a.CardNo, @IssNo, b.TxnLimit, 0, 0, 0, 0, null, 3, 0, null, null, getdate()
	from #Applicant a, iap_Applicant b
	where b.IssNo = @IssNo and b.AppcId = a.AppcId

	if @@error <> 0
	begin
		rollback transaction
		return 70191	-- Failed to create card financial info
	end

	-- Creating entry in iac_CardVelocityLimit
	insert into iac_CardVelocityLimit
		(CardNo, VelocityInd, ProdCd, VelocityLimit, VelocityCnt, VelocityLitre,
		SpentLimit, SpentCnt, LastUpdDate)
	select a.CardNo, b.VelocityInd, b.ProdCd, b.VelocityLimit, b.VelocityCnt, b.VelocityLitre,
		0, 0, getdate()
	from #Applicant a, iap_ApplicantVelocityLimit b
	where b.AppcId = a.AppcId

	if @@error <> 0
	begin
		rollback transaction
		return 70192	-- Failed to create card velocity limit
	end

	insert into iac_CardVelocityLimit
		(CardNo, VelocityInd, ProdCd, VelocityLimit, VelocityCnt,
		SpentLimit, SpentCnt, LastUpdDate)
	select a.CardNo, b.VelocityInd, b.ProdCd, b.VelocityLimit, b.VelocityCnt,
		0, 0, getdate()
	from #Applicant a, iss_PlasticTypeVelocityLimit b
	where b.IssNo = @IssNo and b.CardLogo = a.CardLogo and b.PlasticType = a.PlasticType
	and b.AcctCardInd = 'C' and not exists (select 1 from iac_CardVelocityLimit c
	where c.CardNo = a.CardNo)

	if @@error <> 0
	begin
		rollback transaction
		return 70192	-- Failed to create card velocity limit
	end

	--2003/03/11B
	-- To create Card Sub Limit into iac_CardSubLimit
	insert into iac_CardSubLimit
		(IssNo, AcctNo, CardNo, ProdCategory, VelocityInd, SchemeFlag, 
		VelocityCnt, VelocityLimit, SpentCnt, SpentLimit, LastUpdDate)
	select @IssNo, a.AcctNo, a.CardNo, b.ProdCategory, b.VelocityInd, b.SchemeFlag,
		b.VelocityCnt, b.VelocityLimit, 0, 0, getdate()
	from #Applicant a
	join iap_ApplicantSubLimit b on a.AppcId = b.AppcId and b.IssNo = @IssNo

	if @@error <> 0
	begin
		rollback transaction
		return 70424	-- Failed to update card sub limit
	end

	-- To indicate vehicle registration no already exists.
	update a
	set VehInd = 'Y'
	from #Applicant a
	join iap_Applicant b on a.AppcId = b.AppcId --comment off by aeris 2003/07/10and b.CardType in ('V', 'B')
	-- Check by VehRegsNoPrefix and VehRegsNoSuffix B2003/06/23
	--join iac_Vehicle c on b.VehRegsNo = c.VehRegsNo and b.IssNo = c.IssNo
	join iac_Vehicle c on b.VehRegsNoPrefix = c.VehRegsNoPrefix and  b.VehRegsNoSuffix = c.VehRegsNoSuffix and b.IssNo = c.IssNo
	-- Check by VehRegsNoPrefix and VehRegsNoSuffix E2003/06/23
	--2003/03/11E

	if @@error <> 0
	begin
		rollback transaction
		return 70193	-- Failed to create vehicle detail
	end

	-- Creating entry in iac_Vehicle
	--Add VehRegsNoPrefix & VehRegsNoSuffix B2003/06/23
	insert into iac_Vehicle
		(IssNo, VehRegsNo,VehRegsNoPrefix, VehRegsNoSuffix, VehRegsDate, Manufacturer, Model, Color, ManufacturerDate,
		MainFuel, VehSvc, Remark, RoadTaxExpiry, RoadTaxAmt, RoadTaxPeriod, StartOdoReading,
		StartOdoUpd, CurrOdoReading, OdoLastUpd, InsrcCmpy, PolicyNo, PolicyStartDate,
		PolicyExpiryDate, PremiumAmt, InsuredAmt, LastUpdDate)
	select @IssNo, b.VehRegsNo, b.VehRegsNoPrefix, b.VehRegsNoSuffix, b.VehRegsDate, b.Manufacturer, b.Model, b.Color, b.ManufacturerDate,
		null, b.VehSvc, b.VehRemark, b.RoadTaxExpiry, b.RoadTaxAmt, b.RoadTaxPeriod, null,
		null, null, null, b.InsrcCmpy, b.PolicyNo, b.PolicyStartDate,
		b.PolicyExpiryDate, b.PremiumAmt, b.InsuredAmt, getdate()
	--Add VehRegsNoPrefix & VehRegsNoSuffix E2003/06/23
	from #Applicant a, iap_Applicant b, iss_CardType c
	where b.IssNo = @IssNo and b.AppcId = a.AppcId and b.CardType = c.CardType and 
	(c.VehInd = 'Y' or (VehRegsNoPrefix is not null and VehRegsNoSuffix is not null)) -- 2003/08/22
	--2003/03/11B
	--and a.VehInd is null
	--2003/03/11E

	if @@error <> 0
	begin
		rollback transaction
		return 70193	-- Failed to create vehicle detail

	end

	-- Updating primary entity id

	update c set c.PriEntityId = b.EntityId
	from #Applicant a, iac_Card b, iac_Entity c
	where a.PriSec = 'S' and a.PriCardNo is not null and b.IssNo = @IssNo
	and b.CardNo = a.PriCardNo and c.IssNo = @IssNo and c.EntityId = a.EntityId

	if @@error <> 0
	begin
		rollback transaction
		return 70110	-- Failed to update entity
	end

	-- Updating ghost card
	update c set c.Sts = 'A'
	from #Applicant a, iap_Applicant b, iac_GhostCard c
	where b.IssNo = @IssNo and b.AppcId = a.AppcId and b.AppcType = 'G' and c.IssNo = @IssNo
	and c.CardNo = b.CardNo

	if @@error <> 0
	begin
		rollback transaction
		return 70187	-- Failed to update ghost card
	end

	insert iac_PlasticCard (IssNo, CardLogo, PlasticType, AcctNo, CardNo,
		EmbName, ExpiryDate, InputSrc, CreationDate)
	select @IssNo, c.CardLogo, c.PlasticType, a.AcctNo, c.CardNo,
		c.EmbName, c.ExpiryDate, 'NEW', getdate()
	from #Applicant a, iap_Applicant b, iac_Card c
	where b.IssNo = @IssNo and b.AppcId = a.AppcId and b.AppcType <> 'G'
	and c.IssNo = @IssNo and c.CardNo = a.CardNo

	if @@error <> 0
	begin
		rollback transaction
		return 70220	-- Failed to update ghost card
	end

	-- Updating Applicant
	update a set
		a.AcctNo = isnull(a.AcctNo, b.AcctNo), a.PriCardNo = isnull(a.PriCardNo, b.PriCardNo),
		a.CardNo = b.CardNo, a.EntityId = b.EntityId, a.AppcSts = isnull(@AppcTrsfSts,'T'),
		a.TrsfDate = @PrcsDate
	from iap_Applicant a, #Applicant b
	where a.IssNo = @IssNo and a.AppcId = b.AppcId

	if @@error <> 0
	begin
		rollback transaction
		return 70144	-- Failed to update applicant
	end

	-- Updating the first primary cardholder to account
	update a set a.EntityId = b.EntityId
	from iac_Account a, (select AcctNo, min(EntityId) 'EntityId' from #Applicant where PriSec = 'P' group by AcctNo) b
	where a.IssNo = @IssNo and a.AcctNo = b.AcctNo and a.EntityId is null

	if @@error <> 0
	begin
		rollback transaction
		return 70124	-- Failed to update account
	end

	--------------------------------------
	-- Creating Joining and Annual Fees --
	--------------------------------------

	select @CardCenterBusnLocation = VarcharVal
	from iss_Default
	where IssNo = @IssNo and Deft = 'CardCenterBusnLocation'

	select @CardCenterTermId = IntVal
	from iss_Default
	where IssNo = @IssNo and Deft = 'CardCenterTermId'

	select @IssCrryCd = CrryCd
	from iss_Issuer
	where IssNo = @IssNo

	-- 2003/11/11
	select @NoOfRec = count(*) from #Applicant

	-- Create Joining Fee and Annual Fee
	insert into #SourceTxn (
		BatchId, TxnSeq, IssNo, TxnCd, AcctNo, CardNo, LocalTxnDate, TxnDate,
		LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Descp,
		BusnLocation, Mcc, TermId, Rrn, Stan, AppvCd, CrryCd, Arn, BillMethod,
		PlanId, PrcsId, InputSrc, SrcTxnId, RefTxnId, AuthTxnId, OnlineInd,
		UserId, Sts )
	-- 2003/07/07 Jacky - Use AppcId as the TxnSeq to make the record in #Source is unique
	-- in TxnSeq. WithheldUnsettleTxnUpdate will make use the TxnSeq for processing.
	-- 2003/07/19 Jacky - Insert null to LocalTxnDate and TxnDate so the transaction will
	-- only post upon CycleProcessing
	-- 2003/11/11 Jacky - Make TxnSeq unique by using TxnSeq from #Applicant
--	select	0, b.AppcId, @IssNo, c.TxnCd, a.AcctNo, a.CardNo, /*@PrcsDate, @PrcsDate*/null, null,
	select	0, a.TxnSeq, @IssNo, c.TxnCd, a.AcctNo, a.CardNo, @PrcsDate, @PrcsDate, --null, null,
		c.Fee, c.Fee, 0, 0, 0, c.Descp,
		@CardCenterBusnLocation, null, @CardCenterTermId, null, null, null, @IssCrryCd, null, null,
		null, @PrcsId, 'SYS', null, 0, null, d.OnlineInd,
		system_user, null
	from #Applicant a, iap_Applicant b, iss_FeeCode c, itx_TxnCode d
	where b.IssNo = @IssNo and b.AppcId = a.AppcId and b.JoiningFeeCd is not null
	and c.IssNo = @IssNo and c.FeeCd = b.JoiningFeeCd and d.IssNo = @IssNo and d.TxnCd = c.TxnCd
	union all
	select	0, @NoOfRec + a.TxnSeq, @IssNo, c.TxnCd, a.AcctNo, a.CardNo, @PrcsDate, @PrcsDate, --null, null,
		c.Fee, c.Fee, 0, 0, 0, c.Descp,
		@CardCenterBusnLocation, null, @CardCenterTermId, null, null, null, @IssCrryCd, null, null,
		null, @PrcsId, 'SYS', null, 0, null, d.OnlineInd,
		system_user, null
	from #Applicant a, iap_Applicant b, iss_FeeCode c, itx_TxnCode d
	where b.IssNo = @IssNo and b.AppcId = a.AppcId and b.AnnlFeeCd is not null
	and c.IssNo = @IssNo and c.FeeCd = b.AnnlFeeCd and d.IssNo = @IssNo and d.TxnCd = c.TxnCd

	union all -- CP 20041130 Get Government Levy at Card
	select	0, (@NoOfRec*1) + a.TxnSeq, @IssNo, c.TxnCd, a.AcctNo, a.CardNo, @PrcsDate, @PrcsDate,
		c.Fee, c.Fee, 0, 0, 0, c.Descp,
		@CardCenterBusnLocation, null, @CardCenterTermId, null, null, null, @IssCrryCd, null, null,
		null, @PrcsId, 'SYS', null, 0, null, d.OnlineInd,
		system_user, null
	from #Applicant a, iap_Applicant b, iss_FeeCode c, itx_TxnCode d
	where b.IssNo = @IssNo and b.AppcId = a.AppcId and b.GovernmentLevyFeeCd is not null
	and c.IssNo = @IssNo and c.FeeCd = b.GovernmentLevyFeeCd and d.IssNo = @IssNo and d.TxnCd = c.TxnCd
	union all -- CP 20041130 Get Government Levy at Application
	select	0, (@NoOfRec*2) + e.TxnSeq, @IssNo, c.TxnCd, a.AcctNo, 0, @PrcsDate, @PrcsDate,
		c.Fee, c.Fee, 0, 0, 0, c.Descp,
		@CardCenterBusnLocation, null, @CardCenterTermId, null, null, null, @IssCrryCd, null, null,
		null, @PrcsId, 'SYS', null, 0, null, d.OnlineInd,
		system_user, null
	from #Application a, iap_Application b, iss_FeeCode c, itx_TxnCode d, #Applicant e, iap_Applicant f
	where b.IssNo = @IssNo and b.ApplId = a.ApplId and b.GovernmentLevyFeeCd is not null
	and c.IssNo = @IssNo and c.FeeCd = b.GovernmentLevyFeeCd and d.IssNo = @IssNo and d.TxnCd = c.TxnCd
	and f.IssNo = @IssNo and f.ApplId = a.ApplId and f.AppcId = e.AppcId and f.GovernmentLevyFeeCd is null 

	if @@error <> 0
	begin
		rollback transaction
		return 70109	-- Failed to insert into itx_SourceTxn
	end

	exec @rc = OnlineTxnProcessing @IssNo

	if @@error <> 0 or dbo.CheckRC(@rc) <> 0
	begin
		rollback transaction
		return 70109	-- Failed to insert into itx_SourceTxn
	end

	-- CRN: 1103003 [B]
	update a
	set a.AcctNo = b.AcctNo
	from iaa_BankAccount a, #Application b
	where a.IssNo = @IssNo and a.ApplId = b.ApplId

	if @@error <> 0
	begin
		rollback transaction
		return 70437	-- Failed to update Bank Account
	end
		
	update a
	set a.AcctNo = b.AcctNo
	from iaa_Guarantor a, #Application b
	where a.IssNo = @IssNo and a.ApplId = b.ApplId

	if @@error <> 0
	begin
		rollback transaction
		return 70441	-- Failed to update Guarantor Details
	end
		
	update a
	set a.AcctNo = b.AcctNo
	from iaa_ShareHolder a, #Application b
	where a.IssNo = @IssNo and a.ApplId = b.ApplId

	if @@error <> 0
	begin
		rollback transaction
		return 70434	-- Failed to update Shareholder
	end

	insert into iac_AccountAcceptance (IssNo, AcctNo, BusnLocation, Sts)
	select @IssNo, b.AcctNo, a.BusnLocation, a.Sts 
	from iap_ApplicationAcceptance a, #Application b
	where a.IssNo = @IssNo and a.ApplId = b.ApplId

	if @@error <> 0
	begin
		rollback transaction
		return 70442	-- Failed to update Application Acceptance
	end

	insert into iss_Address (IssNo, RefTo, RefKey, RefType, RefCd, Street1, Street2, Street3, State, ZipCd, Ctry, EntityInd, MailingInd)
	select @IssNo, 'ACCT', b.AcctNo, a.RefType, a.RefCd, a.Street1, a.Street2, a.Street3, a.State, a.ZipCd, a.Ctry, a.EntityInd, a.MailingInd
	from iss_Address a, #Application b
	where a.IssNo = @IssNo and a.RefTo = 'APPL' and a.RefKey = b.ApplId

	if @@error <> 0
	begin
		rollback transaction
		return 70083	-- Failed to insert Address
	end

	-- Creating Cost Centre Address into iss_Address
	insert into iss_Address (IssNo, RefTo, RefKey, RefType, RefCd, Street1, Street2, Street3, State, ZipCd, Ctry, EntityInd, MailingInd)
	select @IssNo, 'ACCTCOSTC', c.CostCentreId, a.RefType, a.RefCd, a.Street1, a.Street2, a.Street3, a.State, a.ZipCd, a.Ctry, a.EntityInd, a.MailingInd
	from iss_Address a, #Application b, iaa_CostCentre c
	where a.IssNo = @IssNo and a.RefTo = 'APPLCOSTC' and a.RefKey = c.CostCentreId and b.ApplId = c.ApplId

	if @@error <> 0
	begin
		rollback transaction
		return 70083 	-- Failed to insert Address
	end

	--2003/10/06B
	--insert into iss_Contact (IssNo, RefTo, RefKey, RefType, RefCd, ContactName, Occupation, ContactNo, Sts, EntityInd)
	--select @IssNo, 'ACCT', b.AcctNo, a.RefType, a.RefCd, a.ContactName, a.Occupation, a.ContactNo, a.Sts, a.EntityInd
	insert into iss_Contact (IssNo, RefTo, RefKey, RefType, RefCd, ContactName, Occupation, ContactNo, Sts, EntityInd, EmailAddr)
	select @IssNo, 'ACCT', b.AcctNo, a.RefType, a.RefCd, a.ContactName, a.Occupation, a.ContactNo, a.Sts, a.EntityInd, a.EmailAddr
	--2003/10/06E
	from iss_Contact a, #Application b
	where a.IssNo = @IssNo and a.RefTo = 'APPL' and a.RefKey = b.ApplId

	if @@error <> 0
	begin
		rollback transaction
		return 70084 	-- Failed to insert Contact
	end
	

	-- Creating Cost Centre Address into iss_Address
	insert into iss_Contact (IssNo, RefTo, RefKey, RefType, RefCd, ContactName, Occupation, ContactNo, Sts, EntityInd, EmailAddr)
	select @IssNo, 'ACCTCOSTC', c.CostCentreId, a.RefType, a.RefCd, a.ContactName, a.Occupation, a.ContactNo, a.Sts, a.EntityInd, a.EmailAddr
	from iss_Contact a, #Application b, iaa_CostCentre c
	where a.IssNo = @IssNo and a.RefTo = 'APPLCOSTC' and a.RefKey = c.CostCentreId and b.ApplId = c.ApplId

	if @@error <> 0
	begin
		rollback transaction
		return 70084	-- Failed to update Contact
	end

	-- CRN: 1103003 [E]

	--2003/07/09B
	update a
	set a.CardNo = b.CardNo -- a.AcctNo = b.AcctNo, a.CardNo = b.CardNo Remark by CP
	from iaa_ProductUtilization a, #Applicant b
	where a.IssNo = @IssNo and a.AppcId = b.AppcId
	if @@error <> 0
	begin
		rollback transaction
		return 70135	-- Failed to update Product List
	end
	--2003/07/09E	

/*	--2003/07/24, Kenny
	--insert a record into iac_PINMailer
	insert into iac_PINMailer (IssNo, BatchId, CardNo, InputSrc, PrcsId, Sts, LastUpdDate, UserId)
	select @IssNo, @BatchId, a.CardNo, 'NEW', @PrcsId, 'A', convert(varchar ,getdate(),112), system_user
	from #Applicant a, iap_Applicant b
	where a.AppcId = b.AppcId and b.IssNo = @IssNo and b.PinInd = 'Y'

	if @@error <> 0
	begin
		return 70465
	end
*/

	------------------
	COMMIT TRANSACTION
	------------------
	
	drop table #Application
	drop table #Applicant

	if @Complete = 'Y' return 54024	-- Application processing completed successfully

	return 95159	-- Not all record has been processed
end
GO
