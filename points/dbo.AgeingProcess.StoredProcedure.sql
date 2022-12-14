USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AgeingProcess]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure will call the respective stored procedure to do cycle statement and ageing.

SP Level	: Primary
------------------------------------------------------------------------------------------------------------------
When	   Who		CRN		Desc
------------------------------------------------------------------------------------------------------------------
2002/04/15 Jacky			Initial development
2003/03/15 Sam				Fixes. Requested by Jacky.
2003/07/19 Jacky			All transaction (interest,late payment,rebate, etc...) will be post
							in a single batch
2003/07/20 Jacky			Retrieve and Post transactions from itx_HeldTxn 
2004/10/12 Jacky			Add Odometer Validation -- temporary comment off, as this changes has not been applied to KTC
2004/12/28 Chew Pei			Insert into #CardInfo if Odometer is not null and Odometer > 0
2005/11/17 Chew Pei			Added OpnCredit Field while inserting #AccountCycle
2009/12/01 Jacky			Remove Payment related functions for Loyalty only program
******************************************************************************************************************/
--exec AgeingProcess 1,'DEMOLTY','PETSTAFF','1'
CREATE	procedure [dbo].[AgeingProcess]
	@IssNo uIssNo,
	@CardLogo uCardLogo,
	@PlasticType uPlasticType,
	@CycNo uCycNo
  as
begin
	declare @CycId int,
		@BatchId int,
		@TxnSeq bigint,
		@BusnLocation uMerchNo,
		@TermId uTermId,
		@Descp uDescp50,
		@Mcc smallint,
		@CrryCd uRefCd,
		@MinRepaymtAmt money,
		@MinRepaymtRate money,
		@CycDueDay tinyint,
		@CycDueDate datetime,
		@GracePeriod int,
		@MaxLatePaymtVoidAmt money,
		@LatePaymtInterest money,
		@LatePaymtTxnCd uTxnCd,
		@PromptPaymtTxnCd uTxnCd,
		@ProdRebateTxnCd uTxnCd,
		@AgeingBucket int,
		@PtsAgeingPeriod int,
		@InterestType char(1),
		@PtsIssueTxnCategory int,
		@RdmpTxnCategory int,
		@AdjustTxnCategory int,
		@ExpiredTxnCategory int,
		@PaymtTxnCategory int,
		@DeftAcctSts uRefCd,
		@BillingType char(1),
		@TaskId int,
		@rc int,
		@Program char(1),
		@PrcsId uPrcsId,
		@PrcsDate datetime,
		@PrcsName varchar(50)

	set nocount on

	exec @rc = InitProcess
	if @@error <> 0 or @rc <> 0 return 99999

	select @PrcsName = 'AgeingProcess'

	exec TraceProcess @IssNo, @PrcsName, 'Start'

	----------------------------------------------------------
	-- Retrieves necessary information for later processing --
	----------------------------------------------------------

	-- This Stored Procedure only process account will Billing Type = Monthly
	--select @BillingType = 'M'

	select @PrcsId = CtrlNo, @PrcsDate = CtrlDate
	from iss_Control
	where IssNo = @IssNo and CtrlId = 'PrcsId'

	select @CycDueDate = c.DueDate, @CycDueDay = c.DueDay, @GracePeriod = GracePeriod
	from iss_CycleControl a
	join iss_PlasticTypeCycle b on b.IssNo = @IssNo and b.CardLogo = @CardLogo
		and b.PlasticType = @PlasticType and b.CycNo = a.CycNo
	join iss_CycleDate c on c.IssNo = @IssNo and c.CycNo = b.CycNo and c.CycDate = @PrcsDate
	where a.IssNo = @IssNo and a.CycNo = @CycNo and a.Sts = 'A'

	if @@rowcount = 0 or (@CycDueDate is null and @CycDueDay is null and @GracePeriod is null)
	begin
		return 95167	-- Cycle day not match
	end

	if @CycDueDate is null
		select @CycDueDate = dateadd(dd, isnull(@CycDueDay, 1), @PrcsDate)

	select
		@AgeingBucket = isnull(AgeingBucket, 0),
		@PtsAgeingPeriod = isnull(PtsAgeingPeriod, 0),
		@MinRepaymtAmt = MinRepaymtAmt,
		@MinRepaymtRate = MinRepaymtRate,
		@MaxLatePaymtVoidAmt = MaxLatePaymtVoidAmt,
		@LatePaymtInterest = LatePaymtInterest,
		@LatePaymtTxnCd = LatePaymtTxnCd,
		@PromptPaymtTxnCd = PromptPaymtTxnCd,
		@ProdRebateTxnCd = ProdRebateTxnCd,
		@InterestType = InterestType
	from iss_PlasticType
	where IssNo = @IssNo and CardLogo = @CardLogo and PlasticType = @PlasticType

	if @@rowcount = 0
	begin
		return 60013	-- Plastic Type not found
	end

	select @PaymtTxnCategory = IntVal
	from iss_Default
	where IssNo = @IssNo and Deft = 'PaymtTxnCategory'

	select @PtsIssueTxnCategory = IntVal
	from iss_Default
	where IssNo = @IssNo and Deft = 'PtsIssueTxnCategory'

	select @RdmpTxnCategory = IntVal
	from iss_Default
	where IssNo = @IssNo and Deft = 'RdmpTxnCategory'

	select @AdjustTxnCategory = IntVal
	from iss_Default
	where IssNo = @IssNo and Deft = 'AdjustTxnCategory'

	select @ExpiredTxnCategory = IntVal
	from iss_Default
	where IssNo = @IssNo and Deft = 'ExpiredTxnCategory'

	select @BusnLocation = VarCharVal
	from iss_Default
	where IssNo = @IssNo and Deft = 'CardCenterBusnLocation'

	select @TermId = IntVal
	from iss_Default
	where IssNo = @IssNo and Deft = 'CardCenterTermId'

	select @DeftAcctSts = VarCharVal
	from iss_Default
	where IssNo = @IssNo and Deft = 'DeftAcctSts'

	select @Mcc = a.Mcc, @CrryCd = b.CrryCd
	from aac_BusnLocation a, acq_Acquirer b
	where a.BusnLocation = @BusnLocation and b.AcqNo = a.AcqNo

	select @Descp = Descp
	from itx_TxnCode
	where IssNo = @IssNo and TxnCd = @LatePaymtTxnCd

	select @Program = Program
	from iss_CardLogo
	where CardLogo = @CardLogo

--	select @PtsIssueTxnCategory, @RdmpTxnCategory, @AdjustTxnCategory,
--	@ExpiredTxnCategory, @BusnLocation, @TermId, @DeftAcctSts, @Program

	if @PaymtTxnCategory is null or @PtsIssueTxnCategory is null or @RdmpTxnCategory is null
	or @AdjustTxnCategory is null or @ExpiredTxnCategory is null or @BusnLocation is null
	or @TermId is null or @DeftAcctSts is null or @Program is null or @PtsAgeingPeriod is null
	or @PtsAgeingPeriod = 0
		return 95160	-- Unable to retrieve control or default values

	----------------------------------------------------------
	-- Preparing temporary tables --
	----------------------------------------------------------

	select * into #SourceTxn
	from itx_SourceTxn where BatchId = -1

	select * into #SourceTxnDetail
	from itx_SourceTxnDetail where BatchId = -1

	-- Creating index for temporary table
	create	unique index IX_SourceTxnDetail on #SourceTxnDetail (
		BatchId,
		ParentSeq,
		TxnSeq )

	create table #CycleTxn (
		TxnSeq bigint identity(1, 1),
		TxnCd int,
		AcctNo bigint,
		Descp varchar(50),
		BusnLocation bigint,
		TermId varchar(10),
		Amt money,
		Pts money,
		Type char(4),
		Ind char(1) -- value 'P' - Post now, 'H' - Write to heldtxn Post next cycle
		)

	if @@error <> 0 return 70270	-- Failed to create temporary table

	create table #CycleTxnDetail (
		ParentSeq bigint,
		TxnSeq int identity(1, 1),
		ProdCd varchar(15),
		Amt money,
		Pts money,
		Qty int
		)

	if @@error <> 0 return 70270	-- Failed to create temporary table

	-- Populate last cycle info into temporary tables
	select a.AcctNo, b.CycId, b.OpnBal, b.ClsBal, b.ClsPts,
		b.MinRepaymt, b.CycDate, b.DueDate, b.GracePeriod
	into #PrevAccountCycle 
	from iac_Account a (nolock)
	join iacv_PrevAccountCycle b on b.AcctNo = a.AcctNo
	where a.IssNo = @IssNo and a.CardLogo = @CardLogo and a.PlasticType = @PlasticType
	and a.CycNo = @CycNo /*and a.BillingType = @BillingType and a.Sts = @Sts*/

	select * into #AccountCycle
	from iac_AccountCycle (nolock) where AcctNo = 0

	create	unique index IX_PrevAccountCycle on #PrevAccountCycle ( AcctNo )
	
	if @@error <> 0 return 70270	-- Failed to create temporary table

	create	unique index IX_AccountCycle on #AccountCycle ( AcctNo )

	if @@error <> 0 return 70270	-- Failed to create temporary table

	-- Create this month statement file
	insert #AccountCycle (AcctNo, CycId, OpnBal, ClsBal, OpnPts,
		ClsPts, MinRepaymt, CycDate, DueDate, GracePeriod, Sts)
	select a.AcctNo, 0, isnull(b.ClsBal,0), isnull(b.ClsBal,0), isnull(b.ClsPts,0),
		isnull(b.ClsPts,0), 0, @PrcsDate, @CycDueDate, @GracePeriod, a.Sts
	from iac_Account a (nolock)
	left outer join #PrevAccountCycle b on b.AcctNo = a.AcctNo
	where a.IssNo = @IssNo and a.CardLogo = @CardLogo and a.PlasticType = @PlasticType
	and a.CycNo = @CycNo /* and a.BillingType = @BillingType --and a.Sts = @Sts*/

	if @@error <> 0 return 70332	-- Failed to insert new row into #AccountCycle

	if (select count(*) from #AccountCycle) = 0 return 54086	-- No Account has been processed in this cycle

	-----------------------------------------------------------------------------------
	BEGIN TRANSACTION
	-----------------------------------------------------------------------------------

	---------------------------------
	-- Extracting Held Transaction --
	---------------------------------

	-- Retrieve a BatchId Held Txn
	exec @BatchId = NextRunNo @IssNo, 'INSBatchId'

	update a set Sts = 'P'	-- Pending
	from itx_HeldTxn a
	join #AccountCycle b on b.AcctNo = a.AcctNo
	where a.IssNo = @IssNo and a.TxnDate is null and a.Sts is null

	if @@error <> 0
	begin
		rollback transaction
		return 70199	-- Failed to update held transaction
	end

	insert itx_SourceTxn
		(BatchId, TxnSeq, IssNo, TxnCd, AcctNo, CardNo, LocalTxnDate, TxnDate,
		LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, Descp, BusnLocation,
		TermId, AppvCd, CrryCd, BillMethod, PlanId, OnlineTxnId, RefTxnId, WithheldUnsettleId,
		OnlineInd, UserId)
	select @BatchId, a.TxnId, a.IssNo, a.TxnCd, a.AcctNo, a.CardNo, @PrcsDate, @PrcsDate,
		a.LocalTxnAmt, a.LocalTxnAmt, (a.BillingTxnAmt*c.RefNo), (a.Pts*c.RefNo), a.Descp, a.BusnLocation,
		a.TermId, a.AppvCd, a.CrryCd, a.BillMethod, a.PlanId, a.TxnId, a.RefTxnId, a.WithheldUnsettleId,
		a.OnlineInd, a.UserId
	from itx_HeldTxn a (nolock)
	join itx_TxnCode b (nolock) on b.IssNo = a.IssNo and b.TxnCd = a.TxnCd
	join iss_RefLib c (nolock) on c.IssNo = b.IssNo and c.RefType = 'TxnType' and c.RefCd = b.Multiplier
	where a.IssNo = @IssNo and a.TxnDate is null and a.Sts = 'P' 

	if @@error <> 0
	begin
		rollback transaction
		return 70337	-- Failed to insert interest transaction into itx_SourceTxn
	end

	insert into itx_SourceTxnDetail (IssNo, BatchId, ParentSeq, TxnSeq, RefTo, RefKey,
		LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Qty, SrcTxnId,
		PlanId, OdometerReading, PricePerUnit, Sts)
	select @IssNo, @BatchId, a.TxnId, a.TxnSeq, a.RefTo, a.RefKey,
		a.LocalTxnAmt, a.SettleTxnAmt, (a.BillingTxnAmt*d.RefNo), a.Pts, 0, a.Qty, null,
		null, a.Odometer, 0, 'A'
	from itx_HeldTxnDetail a (nolock)
	join itx_HeldTxn b (nolock) on b.IssNo = @IssNo and b.TxnDate is null and b.Sts = 'P' and b.TxnId = a.TxnId
	join itx_TxnCode c (nolock) on c.IssNo = @IssNo and c.TxnCd = b.TxnCd
	join iss_RefLib d (nolock) on d.IssNo = @IssNo and d.RefType = 'TxnType' and d.RefCd = c.Multiplier

	if @@error <> 0
	begin
		rollback transaction
		return 70266	-- Failed to insert into #SourceTxnDetail
	end

	update itx_HeldTxn set Sts = 'E', PrcsId = @PrcsId	-- Extracted
	where IssNo = @IssNo and TxnDate is null and Sts = 'P' 

	if @@error <> 0
	begin
		rollback transaction
		return 70199	-- Failed to update held transaction
	end

	---------------------------
	-- Post Held Transaction --
	---------------------------

	-- Post the transaction if there is any
	if exists (select 1 from itx_SourceTxn where BatchId = @BatchId)
	begin
		exec @rc = BatchTxnProcessing @IssNo, @BatchId

		if @@error <> 0 or dbo.CheckRC(@rc) <> 0 or @rc = 95159
		begin
			rollback transaction
			return @rc
		end
	end

	--------------------------------------
	-- Calculate Daily Accrued Interest --
	--------------------------------------

/*	exec @rc = InterestCalculation @IssNo

	if @@error <> 0 or dbo.CheckRC(@rc) <> 0
	begin
		rollback transaction
		return @rc
	end

	-------------------------
	-- Creating Temp Table --
	-------------------------

	-- Create prompt payment temp table (payment before CycDueDate+GracePeriod)
	select a.AcctNo, avg(a.ClsBal) 'ClsBal', sum(isnull(b.BillingTxnAmt, 0)) 'TotalPaymt'
	into #PromptPayment
	from #PrevAccountCycle a
	join itx_Txn b on b.AcctNo = a.AcctNo 
		and cast(convert(varchar(11), b.TxnDate, 0) as datetime) <= dateadd(dd, a.GracePeriod, a.DueDate)
		and b.CycId = 0 and b.BillingTxnAmt < 0
	join itx_TxnCode c on c.IssNo = @IssNo and c.TxnCd = b.TxnCd and c.MinRepaymtInd = 'Y'
	group by a.AcctNo

	if @@error <> 0
	begin
		rollback transaction
		return 70457	-- Failed to create #PromptPayment
	end

	---------------------
	-- Interest Charge --
	---------------------

	insert #CycleTxn (TxnCd, AcctNo, Descp, BusnLocation, TermId, Amt, Pts, Type, Ind)
	select c.TxnCd, a.AcctNo, d.Descp, @BusnLocation, @TermId, c.AccruedInterestAmt, 0, 'INTR', 'P'
	from #AccountCycle a
	left outer join #PromptPayment b on b.AcctNo = a.AcctNo
	join iac_DailyAccruedInterest c
		on c.AcctNo = a.AcctNo and c.AccruedInterestAmt > 0
	join itx_TxnCode d on d.IssNo = @IssNo and d.TxnCd = c.TxnCd
	where b.AcctNo is null or (b.AcctNo > 0 and b.ClsBal + b.TotalPaymt > 0)

	if @@error <> 0
	begin
		rollback transaction
		return 70334	-- Failed to create interest transaction
	end

	-------------------------
	-- Late Payment Charge --
	-------------------------

	insert #CycleTxn (TxnCd, AcctNo, Descp, BusnLocation, TermId, Amt, Pts, Type, Ind)
	select @LatePaymtTxnCd, a.AcctNo, @Descp, @BusnLocation, @TermId,
		round(((a.MinRepaymt+isnull(b.TotalPaymt,0))*@LatePaymtInterest/100),2), 0, 'LATE', 'P'
	from #PrevAccountCycle a
	left outer join #PromptPayment b on b.AcctNo = a.AcctNo
	where a.MinRepaymt > 0 and (a.MinRepaymt + isnull(b.TotalPaymt, 0)) > @MaxLatePaymtVoidAmt
	and @LatePaymtInterest is not null and @LatePaymtInterest > 0

	if @@error <> 0
	begin
		rollback transaction
		return 70335	-- Failed to create late payment transaction
	end

	---------------------------
	-- Prompt Payment Rebate --
	---------------------------

	insert #CycleTxn (TxnCd, AcctNo, Descp, BusnLocation, TermId, Amt, Pts, Type, Ind)
	select f.PromptPaymtTxnCd, a.AcctNo, g.Descp, @BusnLocation, @TermId,
		round((sum(b.Amt)*avg(d.PromptPaymtRebate)/100),2) 'Amt', 0, 'PRMT', 'P'
	from #PrevAccountCycle a
	join iac_AgeingBalance b on b.AcctNo = a.AcctNo and b.CycId = a.CycId
		and b.AgeingInd = 1 and b.Amt > 0
	join #PromptPayment c on c.AcctNo = a.AcctNo and abs(c.TotalPaymt) >= a.ClsBal
	join iac_Account d on d.AcctNo = a.AcctNo and d.PromptPaymtRebate > 0
	join iss_RefLib e on e.IssNo = @IssNo and e.RefType = 'AcctSts' and e.RefCd = d.Sts and e.RefInd = 0
	join iss_PlasticType f on f.IssNo = @IssNo and f.CardLogo = d.CardLogo
		and f.PlasticType = d.PlasticType and f.PromptPaymtTxnCd > 0
	join itx_TxnCode g on g.IssNo = @IssNo and g.TxnCd = f.PromptPaymtTxnCd
	group by f.PromptPaymtTxnCd, a.AcctNo, g.Descp

	if @@error <> 0
	begin
		rollback transaction
		return 70373	-- Failed to create prompt payment transaction
	end

	-------------------------
	-- Other fixed Charges --
	-------------------------

--select * from #AccountCycle
--select * from #PrevAccountCycle
--select * from #agedaccount
--select * from #accountbalance
--select * from #interesttxn
--select * from #Latepaymenttxn where OverdueAmt > @MaxLatePaymtVoidAmt
--select * from #Promptpaymtaccount
--select * from #ProductTypeRebate
--return 99


	------------------------------
	-- Create Cycle Transaction --
	------------------------------

	-- Retrieve a BatchId to post Interest, Late Payment charge, Rebate and etc...
	exec @BatchId = NextRunNo @IssNo, 'INSBatchId'

	insert into itx_SourceTxn
		(BatchId, TxnSeq, IssNo, TxnCd, AcctNo, CardNo, LocalTxnDate, TxnDate,
		LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Descp, BusnLocation,
		Mcc, TermId, Rrn, Stan, AppvCd, CrryCd, Arn, BillMethod, PlanId, PrcsId,
		InputSrc, SrcTxnId, RefTxnId, UserId, Sts)
	select @BatchId, TxnSeq, @IssNo, TxnCd, AcctNo, 0, @PrcsDate, @PrcsDate,
		Amt, Amt, 0, 0, 0, Descp, BusnLocation,
		@Mcc, TermId, null, null, null, @CrryCd, null, null, null, @PrcsId,
		'SYS', null, null, system_user, 'A'
	from #CycleTxn
	where Ind = 'P'	-- Post now

	if @@error <> 0
	begin
		rollback transaction
		return 70337	-- Failed to insert interest transaction into itx_SourceTxn
	end

	insert into itx_SourceTxnDetail (IssNo, BatchId, ParentSeq, TxnSeq, RefTo, RefKey,
		LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Qty, SrcTxnId,
		PlanId, PricePerUnit, Sts)
	select @IssNo, @BatchId, a.ParentSeq, a.TxnSeq, 'P', a.ProdCd,
		isnull(a.Amt, 0), isnull(a.Amt, 0), 0, isnull(a.Pts, 0), 0, a.Qty, null,
		null, 0, 'A'
	from #CycleTxnDetail a
	join #CycleTxn b on b.TxnSeq = a.ParentSeq and b.Ind = 'P'	-- Post now

	if @@error <> 0
	begin
		rollback transaction
		return 70884	-- Failed to insert into itx_SourceTxn
	end

	----------------------------
	-- Post Cycle Transaction --
	----------------------------

	-- Post the transaction if there is any
	if exists (select 1 from itx_SourceTxn where BatchId = @BatchId)
	begin
		exec @rc = BatchTxnProcessing @IssNo, @BatchId

		if @@error <> 0 or dbo.CheckRC(@rc) <> 0 or @rc = 95159
		begin
			rollback transaction
			return @rc
		end
	end

	-----------------------------
	-- Create Held Transaction --
	-----------------------------

	insert into #SourceTxn (
		BatchId, TxnSeq, IssNo, TxnCd, AcctNo, CardNo, LocalTxnDate, TxnDate,
		LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Descp,
		BusnLocation, Mcc, TermId, Rrn, Stan, AppvCd, CrryCd, Arn, BillMethod,
		PlanId, PrcsId, InputSrc, SrcTxnId, RefTxnId, AuthTxnId, OnlineInd,
		UserId, Sts )
	select	@BatchId, TxnSeq, @IssNo, TxnCd, AcctNo, 0, null, null,
		isnull(Amt,0), isnull(Amt,0), 0, 0, 0, Descp,
		BusnLocation, @Mcc, TermId, null, null, null, @CrryCd, null, null,
		null, @PrcsId, 'SYS', null, null, null, null,
		system_user, null
	from #CycleTxn
	where Ind = 'H'	-- Post next cycle

	if @@error <> 0
	begin
		rollback transaction
		return 70109	-- Failed to insert into #SourceTxn table
	end

	insert into #SourceTxnDetail (IssNo, BatchId, ParentSeq, TxnSeq, RefTo, RefKey,
		LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Qty, SrcTxnId,
		PlanId, OdometerReading, PricePerUnit, Sts)
	select @IssNo, @BatchId, a.ParentSeq, a.TxnSeq, 'P', a.ProdCd,
		isnull(a.Amt, 0), isnull(a.Amt, 0), 0, isnull(a.Pts, 0), 0, a.Qty, null,
		null, 0, 0, 'A'
	from #CycleTxnDetail a
	join #CycleTxn b on b.TxnSeq = a.ParentSeq and b.Ind = 'H'

	if @@error <> 0
	begin
		rollback transaction
		return 70266	-- Failed to insert into #SourceTxnDetail
	end

	exec @rc = OnlineTxnProcessing @IssNo

	if @@error <> 0 or dbo.CheckRC(@rc) <> 0
	begin
		rollback transaction
		return @rc
	end
*/
	-----------------------------------
	-- Create Ageing Cycle record --
	-----------------------------------

	insert iac_AgeingCycle (IssNo, CardLogo, PlasticType,
		CycNo, CycDate, StmtId, BillingType, PrcsId, PrcsDate, RecCnt, Sts)
	select @IssNo, @CardLogo, @PlasticType,
		@CycNo, @PrcsDate, 0, @BillingType, @PrcsId, @PrcsDate, (select count(*) from #AccountCycle), 'S'

	if @@error <> 0 or @@rowcount = 0
	begin
		rollback transaction
		return 70336	-- Failed to create Statement Cycle Record'
	end

	select @CycId = @@identity

	update iss_Control
	set CtrlNo = @CycId, CtrlDate = @PrcsDate
	where IssNo = @IssNo and CtrlId = 'CycId'

	--------------------------------------
	-- Update Cycle closing balance --
	--------------------------------------

	update a set
		ClsBal = isnull(b.Amt, 0),
		MinRepaymt = case when isnull(b.Amt,0) > 0 then b.Amt else 0 end,
		ClsPts = isnull(c.Pts, 0)
	from #AccountCycle a
	left outer join
		(select a.AcctNo, sum(isnull(b.Amt,0)) 'Amt'
		from #AccountCycle a
		left outer join iac_AgeingBalance b (nolock) on b.AcctNo = a.AcctNo and b.CycId = 0
		group by a.AcctNo) as b on b.AcctNo = a.AcctNo
	left outer join
		(select a.AcctNo, sum(c.DebitPts+c.VoidDebitPts+c.CreditPts+c.VoidCreditPts) 'Pts'
		from #AccountCycle a
		left outer join iac_Points c (nolock) on c.AcctNo = a.AcctNo
		group by a.AcctNo) as c on c.AcctNo = a.AcctNo

	if @@error <> 0
	begin
		rollback transaction
		return 70339	-- Failed to update statement closing balance
	end

	-------------------------
	-- Age Account Balance --
	-------------------------

	update a set AgeingInd = a.AgeingInd + 1
	from iac_AgeingBalance a, #AccountCycle b
	where a.AcctNo = b.AcctNo and a.CycId = 0

	if @@error <> 0
	begin
		rollback transaction
		return 95168	-- Unable to age account
	end

	-- Sum the overflow Ageing Amount into the last bucket
	update a set Amt = a.Amt+d.Amt--, Pts = a.Pts+d.Pts
	from iac_AgeingBalance a
	join (	select b.AcctNo, b.Category, sum(b.Amt) 'Amt'--, sum(b.Pts) 'Pts'
			from iac_AgeingBalance b (nolock)
			join #AccountCycle c on c.AcctNo = b.AcctNo
			where b.CycId = 0 and b.AgeingInd > @AgeingBucket and b.Amt <> 0 --(b.Amt <> 0 or b.Pts <> 0)
			group by b.AcctNo, b.Category ) as d
	on a.AcctNo = d.AcctNo and a.CycId = 0
	and a.AgeingInd = @AgeingBucket and a.Category = d.Category

	if @@error <> 0
	begin
		rollback transaction
		return 70340	-- Failed to update ageing balance
	end

	-- Create the last bucket if its not exists
	insert iac_AgeingBalance (AcctNo, CycId, AgeingInd, Category, StmtId, Amt)
	select a.AcctNo, 0, @AgeingBucket, a.Category, 0, a.Amt
	from (	select b.AcctNo, b.Category, sum(b.Amt) 'Amt'
			from iac_AgeingBalance b (nolock)
			join #AccountCycle c on c.AcctNo = b.AcctNo
			where b.CycId = 0 and b.AgeingInd > @AgeingBucket and b.Amt <> 0
			group by b.AcctNo, b.Category ) a
	where not exists (select 1 from iac_AgeingBalance b where b.AcctNo = a.AcctNo
	and b.CycId = 0 and b.AgeingInd = @AgeingBucket and b.Category = a.Category)

	if @@error <> 0
	begin
		rollback transaction
		return 70140	-- Failed to insert Ageing Bucket
	end

	-- Delete overflowed ageing bucket
	delete a
	from iac_AgeingBalance a, #AccountCycle b
	where a.AcctNo = b.AcctNo and a.CycId = 0 and a.AgeingInd > @AgeingBucket

	if @@error <> 0
	begin
		rollback transaction
		return 70341	-- Failed to clear ageing balance
	end

	-- Backup the ageing balance
	insert iac_AgeingBalance (AcctNo, CycId, AgeingInd, Category, StmtId, Amt,
		TotalCreditAmt, TotalDebitAmt, Pts, TotalCreditPts, TotalDebitPts)
	select a.AcctNo, @CycId, a.AgeingInd, a.Category, 0, a.Amt,
		a.TotalCreditAmt, a.TotalDebitAmt, a.Pts, a.TotalCreditPts, a.TotalDebitPts
	from iac_AgeingBalance a (nolock), #AccountCycle b
	where a.AcctNo = b.AcctNo and a.CycId = 0
	and (a.Amt <> 0 or a.Pts <> 0 or a.AgeingInd < 2)

	if @@error <> 0
	begin
		rollback transaction
		return 70140	-- Failed to insert Ageing Bucket
	end

	-- Delete un-wanted ageing record
	delete a
	from iac_AgeingBalance a, #AccountCycle b
	where a.AcctNo = b.AcctNo and a.CycId = 0 and a.Amt = 0 and a.Pts = 0

	if @@error <> 0
	begin
		rollback transaction
		return 70342	-- Failed to delete unwanted ageing record
	end

	------------------------
	-- Age Min. Repayment --
	------------------------
	update a set AgeingInd = a.AgeingInd + 1
	from iac_MinRepayment a, #AccountCycle b
	where a.AcctNo = b.AcctNo

	if @@error <> 0
	begin
		rollback transaction
		return 70343	-- Failed to age min. repayment
	end

	-- Calculate current min. repayment
	update a set MinRepaymt =
		case when round((a.ClsBal * @MinRepaymtRate / 100), 2) > @MinRepaymtAmt then
			round((a.ClsBal * @MinRepaymtRate / 100), 2)
		else
		case when a.ClsBal > @MinRepaymtAmt then
			@MinRepaymtAmt
		else
			a.ClsBal end
		end
	from #AccountCycle a
--	join iac_Account b on b.AcctNo = a.AcctNo
	join (	select a.AcctNo, isnull(max(b.AgeingInd),1) 'AgeingInd'
			from #AccountCycle a
			left outer join iacv_MinRepayment b (nolock) on b.AcctNo = a.AcctNo and b.Sts = 'A'
			group by a.AcctNo) c on c.AcctNo = a.AcctNo 
	join iss_PlasticTypeDelinquency d (nolock) on d.IssNo = @IssNo and d.CardLogo = @CardLogo
		and d.PlasticType = @PlasticType and d.AgeingInd = c.AgeingInd and d.FullPaymtInd = 'N'
	where a.ClsBal > 0

	if @@error <> 0
	begin
		rollback transaction
		return 95169	-- Failed to calculate min repayment
	end

	update a set a.MinRepaymt = a.ClsBal - b.MinRepaymt
	from #AccountCycle a,
		(select b.AcctNo, sum(b.MinRepaymt-isnull(b.AmtPaid,0)) 'MinRepaymt'
		from #AccountCycle a, iac_MinRepayment b (nolock)
		where b.AcctNo = a.AcctNo and b.Sts = 'A' group by b.AcctNo) b
	where a.MinRepaymt > 0 and b.AcctNo = a.AcctNo
	and (a.MinRepaymt + b.MinRepaymt) > a.ClsBal

	if @@error <> 0
	begin
		rollback transaction
		return 95169	-- Failed to calculate min repayment
	end

	-- Create min. repayment record
	insert iac_MinRepayment (IssNo, AcctNo, CycId, MinRepaymt, AgeingInd, AmtPaid, Sts)
	select @IssNo, AcctNo, @CycId, MinRepaymt, 1, 0, 'A'
	from #AccountCycle
	where MinRepaymt > 0

	if @@error <> 0
	begin
		rollback transaction
		return 70344	-- Failed to create min repayment
	end

	-- Update Statement min repayment
	update a set a.MinRepaymt = b.MinRepaymt
	from #AccountCycle a,
		(select b.AcctNo, sum(b.MinRepaymt-isnull(b.AmtPaid,0)) 'MinRepaymt'
		from #AccountCycle a, iac_MinRepayment b (nolock)
		where b.AcctNo = a.AcctNo and b.Sts = 'A' group by b.AcctNo) b
	where b.AcctNo = a.AcctNo

	if @@error <> 0
	begin
		rollback transaction
		return 95170 	-- Failed to update statement min repayment
	end

	---------------------------
	-- Change Account Status --
	---------------------------

	-- Update account status
	update a set
		a.Sts = case	--when d.AgeingInd is null then @DeftAcctSts
						when c.RefCd < f.RefCd then e.Sts
						else a.Sts end,
		a.AgeingInd = case	when d.AgeingInd is null then 0
							else e.AgeingInd end,
		a.AutoReinstate = case	when d.AgeingInd is null then 'Y'
								else e.AutoReinstate end
	from iac_Account a
	join #AccountCycle b on b.AcctNo = a.AcctNo
	join iss_RefLib c (nolock) on c.IssNo = @IssNo and c.RefType = 'AcctSts' and c.RefCd = a.Sts
	join (	select a.AcctNo, isnull(max(b.AgeingInd), 0) 'AgeingInd'
			from #AccountCycle a
			left outer join iacv_MinRepayment b (nolock)on b.AcctNo = a.AcctNo and b.Sts = 'A'
			group by a.AcctNo) as d
		on d.AcctNo = a.AcctNo
	left outer join iss_PlasticTypeDelinquency e (nolock)
		on e.IssNo = @IssNo and e.CardLogo = a.CardLogo and e.PlasticType = a.PlasticType
		and e.AgeingInd = d.AgeingInd
	left outer join iss_RefLib f on f.IssNo = @IssNo and f.RefType = 'AcctSts' and f.RefCd = e.Sts

	if @@error <> 0
	begin
		rollback transaction
		return 95172	-- Failed to change account status
	end

	---------------------------------------
	-- Create and Assign Collection Task --
	---------------------------------------

/*	exec @rc = CollectionTaskAssignment @IssNo, @CardLogo, @PlasticType, @CycNo, @CycId

	if @@error <> 0 or dbo.CheckRC(@rc) <> 0 or @rc = 95159
	begin
		rollback transaction
		return @rc
	end
*/
	------------------------
	-- Age Points Balance --
	------------------------

	update a set CycId = @CycId
	from iac_Points a, #AccountCycle b
	where a.AcctNo = b.AcctNo and a.CycId = 0

	if @@error <> 0
	begin
		rollback transaction
		return 95173	-- Failed to age points
	end

	update a set AgeingInd = a.AgeingInd + 1
	from iac_Points a, #AccountCycle b
	where a.AcctNo = b.AcctNo-- and a.StmtCycId = 0

	if @@error <> 0
	begin
		rollback transaction
		return 95173	-- Failed to age points
	end

	---------------------
	-- Update MTD Info --
	---------------------
/*
	-- Tag MTD Category with StmtCycId = 0 to this cycle
	update a set StmtCycId = @StmtCycId, StmtDate = @PrcsDate
	from iac_MTDTxnCategory a, #AccountCycle b
	where a.AcctNo = b.AcctNo and a.StmtCycId = 0

	if @@error <> 0
	begin
		rollback transaction
		return 70354	-- Failed to update MTD TxnCategory
	end

	-- Tag MTD Product with StmtCycId = 0 to this cycle
	update a set StmtCycId = @StmtCycId, StmtDate = @PrcsDate
	from iac_MTDProduct a, #AccountCycle b
	where a.AcctNo = b.AcctNo and a.StmtCycId = 0

	if @@error <> 0
	begin
		rollback transaction
		return 70356	-- Failed to update MTD Product
	end

	-- Tag MTD TxnCd with StmtCycId = 0 to this cycle
	update a set StmtCycId = @StmtCycId, StmtDate = @PrcsDate
	from iac_MTDTxnCode a, #AccountCycle b
	where a.AcctNo = b.AcctNo and a.StmtCycId = 0

	if @@error <> 0
	begin
		rollback transaction
		return 70460	-- Failed to update MTD Transaction Code
	end

	-- Tag MTD CardInfo with StmtCycId = 0 to this cycle
	select b.AcctNo, b.CardNo, max(a.TxnId) 'TxnId'
	into #CardInfo
	from itx_Txn a, (select a.AcctNo, a.CardNo, max(a.TxnDate) as TxnDate
		from itx_Txn a, #AccountCycle b
		where a.AcctNo = b.AcctNo and a.Odometer is not null and a.Odometer > 0 and a.PrcsDate <= @PrcsDate -- Added by CP 20041228: Odometer > 0 
		and isnull(a.StmtCycId,0) = 0 group by a.AcctNo, a.CardNo) b
	where a.AcctNo = b.AcctNo and a.CardNo = b.CardNo and a.TxnDate = b.TxnDate
	and a.PrcsDate <= @PrcsDate and isnull(a.StmtCycId, 0) = 0
	group by b.AcctNo, b.CardNo

	update a set StmtCycid = @StmtCycId, StmtDate = @PrcsDate
	from iac_MTDCardInfo a, #AccountCycle b
	where a.AcctNo = b.AcctNo and a.StmtCycId = 0

	if @@error <> 0
	begin
		rollback transaction
		return 70359	-- Failed to update MTD CardInfo
	end

	-- Create the next starting odometer reading for each card
	insert iac_MTDCardInfo (IssNo, AcctNo, CardNo, StmtCycId, Odometer)
	select @IssNo, a.AcctNo, a.CardNo, 0, a.Odometer
	from itx_Txn a, #CardInfo b
	where a.TxnId = b.TxnId

	if @@error <> 0
	begin
		rollback transaction
		return 70358	-- Failed to create MTD CardInfo
	end

	-- 2004/10/12 Jacky
	/*insert iac_MTDCardInfo (IssNo, AcctNo, CardNo, StmtCycId, Odometer)
	select @IssNo, a.AcctNo, a.CardNo, 0, b.Odometer
	from (	select b.AcctNo, b.CardNo, max(c.StmtCycId) 'StmtCycId'
			from #AccountCycle a
			join iac_Card b on b.AcctNo = a.AcctNo
			join iac_MTDCardInfo c on c.IssNo = @IssNo and c.AcctNo = b.AcctNo
				and c.CardNo = b.CardNo and c.StmtCycId > 0
			group by b.AcctNo, b.CardNo) as a
	join iac_MTDCardInfo b on b.IssNo = @IssNo and b.AcctNo = a.AcctNo
		and b.CardNo = a.CardNo and b.StmtCycId = a.StmtCycId
	where not exists (select 1 from iac_MTDCardInfo c where c.IssNo = @IssNo
		and c.AcctNo = a.AcctNo and c.CardNo = a.CardNo and c.StmtCycId = 0)

	if @@error <> 0
	begin
		rollback transaction
		return 70358	-- Failed to create MTD CardInfo
	end
	*/
*/
	-------------------------
	-- Tag Account Balance --
	-------------------------

	-- Tag iac_AccountBalance to this cycle
	update a set CycId = @CycId
	from iac_AccountBalance a, #AccountCycle b
	where a.AcctNo = b.AcctNo and a.CycId = 0

	if @@error <> 0
	begin
		rollback transaction
		return 70466	-- Failed to update account balance
	end

	-- Tag iac_CreditSummary to this cycle
	update a set CycId = @CycId
	from iac_CreditSummary a
	join #AccountCycle b on b.AcctNo = a.AcctNo
	where a.CycId = 0

	if @@error <> 0
	begin
		rollback transaction
		return 70468	-- Failed to update Credit Summary record
	end

	-----------------------
	-- Statement Summary --
	-----------------------
/*
	-- Update Total Payment
	update a
	set TotalPaymt = b.Amt
	from #AccountCycle a
	join (	select a.AcctNo, sum(b.CreditBillingTxnAmt) 'Amt'
			from #AccountCycle a
			join iac_MTDTxnCode b on b.AcctNo = a.AcctNo and b.StmtCycId = @StmtCycId
			join itx_TxnCode c on c.IssNo = @IssNo and c.TxnCd = b.TxnCd and c.MinRepaymtInd = 'Y'
			group by a.AcctNo) b on b.AcctNo = a.AcctNo

	-- Update Total Points Issued
	update a
	set PtsIssued = b.DebitPts + b.VoidDebitPts + b.CreditPts + b.VoidCreditPts
	from #AccountCycle a, iac_Points b
	where b.AcctNo = a.AcctNo and b.StmtCycId = @StmtCycId and b.Category = @PtsIssueTxnCategory

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temporary table
	end

	-- Update Total Points Redeemed
	update a
	set PtsRdm = b.CreditPts, PtsVoidRdm = b.VoidCreditPts
	from #AccountCycle a, iac_Points b
	where b.AcctNo = a.AcctNo and b.StmtCycId = @StmtCycId and b.Category = @RdmpTxnCategory

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temporary table
	end

	-- Update Total Points Adjusted
	update a
	set PtsAdj = b.DebitPts + b.VoidDebitPts + b.CreditPts + b.VoidCreditPts
	from #AccountCycle a, iac_Points b
	where b.AcctNo = a.AcctNo and b.StmtCycId = @StmtCycId and b.Category = @AdjustTxnCategory

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temporary table
	end

	-- Update Total Points Expired
	update a
	set PtsExpired = b.DebitPts + b.VoidDebitPts + b.CreditPts + b.VoidCreditPts
	from #AccountCycle a, iac_Points b
	where b.AcctNo = a.AcctNo and b.StmtCycId = @StmtCycId and b.Category = @ExpiredTxnCategory

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temporary table
	end

	-- Update Total Points Misc
	update a
	set PtsMisc = 
		isnull((select sum(b.DebitPts + b.VoidDebitPts + b.CreditPts + b.VoidCreditPts)
			--2003/03/15B
			--from iac_Points b where b.AcctNo = a.AcctNo)
			from iac_Points b where b.AcctNo = a.AcctNo and b.StmtCycId = @StmtCycId)
			--2003/03/15E
			- (PtsIssued+PtsRdm+PtsVoidRdm+PtsAdj+PtsExpired), 0)
	from #AccountCycle a

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temporary table
	end

	-- Update expiry points
	update a set
			ExpiryPts1 = b.Pts1, ExpiryPts2 = b.Pts2, ExpiryPts3 = b.Pts3,
			ExpiryPts4 = b.Pts4, ExpiryPts5 = b.Pts5, ExpiryPts6 = b.Pts6
	from #AccountCycle a,
		(select	a.AcctNo,
			sum(case when a.AgeingInd >= @PtsAgeingPeriod then a.Pts else 0 end) 'Pts1',
			sum(case when a.AgeingInd = @PtsAgeingPeriod-1 then a.Pts else 0 end) 'Pts2',
			sum(case when a.AgeingInd = @PtsAgeingPeriod-2 then a.Pts else 0 end) 'Pts3',
			sum(case when a.AgeingInd = @PtsAgeingPeriod-3 then a.Pts else 0 end) 'Pts4',
			sum(case when a.AgeingInd = @PtsAgeingPeriod-4 then a.Pts else 0 end) 'Pts5',
			sum(case when a.AgeingInd = @PtsAgeingPeriod-5 then a.Pts else 0 end) 'Pts6'
		from iacv_PointsAgeing a, #AccountCycle b
		where a.AcctNo = b.AcctNo and a.Pts > 0 and a.AgeingInd > @PtsAgeingPeriod-6
		group by a.AcctNo) as b
	where a.AcctNo = b.AcctNo

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temporary table
	end

	-----------------------
	-- Statement Message --
	-----------------------
	-- Delinquency Message
	insert #AccountCycleMessage (StmtCycId, AcctNo, StmtMsgType, StmtMsgId)
	select @StmtCycId, a.AcctNo, d.StmtMsgType, c.DelinquencyMsg
	from #AccountCycle a, iac_Account b, iss_PlasticTypeDelinquency c, iss_StatementMessage d
	where b.AcctNo = a.AcctNo and c.IssNo = @IssNo and c.CardLogo = b.CardLogo
	and c.PlasticType = b.PlasticType and c.AgeingInd = b.AgeingInd and d.IssNo = @IssNo
	and d.StmtMsgId = c.DelinquencyMsg

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temporary table
	end

	-- Plastic Type Message
	insert #AccountCycleMessage (StmtCycId, AcctNo, StmtMsgType, StmtMsgId)
	select @StmtCycId, a.AcctNo, d.StmtMsgType, c.StmtMsgId
	from #AccountCycle a, iac_Account b, iss_PlasticTypeStatementMessage c, iss_StatementMessage d
	where b.AcctNo = a.AcctNo and c.IssNo = @IssNo and c.CardLogo = b.CardLogo
	and c.PlasticType = b.PlasticType and d.IssNo = @IssNo and d.StmtMsgId = c.StmtMsgId
	and @PrcsDate between d.StartDate and dateadd(ss, -1, dateadd(dd, 1, d.EndDate))

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temporary table
	end

	-- Broadcast Message
	insert #AccountCycleMessage (StmtCycId, AcctNo, StmtMsgType, StmtMsgId)
	select @StmtCycId, a.AcctNo, b.StmtMsgType, b.StmtMsgId
	from #AccountCycle a
	join iss_StatementMessage b on b.StmtMsgType = 'BCM'
		and @PrcsDate between b.StartDate and dateadd(ss, -1, dateadd(dd, 1, b.EndDate))

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temporary table
	end

	-- Account Message
	insert #AccountCycleMessage (StmtCycId, AcctNo, StmtMsgType, StmtMsgId)
	select @StmtCycId, a.AcctNo, c.StmtMsgType, b.StmtMsgId
	from #AccountCycle a, iac_AccountMessageList b, iss_StatementMessage c
	where b.AcctNo = a.AcctNo and b.StmtCycId is null and c.IssNo = @IssNo
	and c.StmtMsgId = b.StmtMsgId

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temporary table
	end

	update b set StmtCycId = @StmtCycId
	from #AccountCycle a, iac_AccountMessageList b
	where b.AcctNo = a.AcctNo and b.StmtCycId is null

	if @@error <> 0
	begin
		rollback transaction
		return 70346	-- Failed to update account message list
	end
*/
	update #AccountCycle set CycId = @CycId

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temporary table
	end

	------------------------------
	-- Update Account Statement --
	------------------------------

	-- Create AccountStatement History
	insert iac_AccountCycle
	select * from #AccountCycle

	if @@error <> 0
	begin
		rollback transaction
		return 70347	-- Failed to create Account Statement
	end

	-- Create AccountStatementMessage History
/*	insert iac_AccountCycleMessage
	select * from #AccountCycleMessage

	if @@error <> 0
	begin
		rollback transaction
		return 70348	-- Failed to create Account Statement Message
	end
*/
	-- Update Financial Info
	update a set a.StmtDate = b.CycDate, a.DueDate = b.DueDate, a.MinRepaymt = b.MinRepaymt
	from iac_AccountFinInfo a, #AccountCycle b
	where a.AcctNo = b.AcctNo

	if @@error <> 0
	begin
		rollback transaction
		return 70127	-- Failed to update Account Financial Info
	end

	-- Update StmtCycId into Transactions
	update a set a.CycId = @CycId
	from itx_Txn a, #AccountCycle b
	where a.AcctNo = b.AcctNo and a.PrcsId <= @PrcsId and isnull(a.CycId,0) = 0

	if @@error <> 0
	begin
		rollback transaction
		return 70349	-- Failed to update Transaction
	end

	set nocount off

/*select 'iac_AccountCycle', * from iac_AccountCycle
select 'iac_AgeingCycle', * from iac_AgeingCycle
select 'itx_txn',* from itx_txn order by acctno
select 'itx_heldtxn',* from itx_heldtxn order by acctno
--select 'iac_ageingbalance',* from iac_ageingbalance order by acctno
--select 'iac_account', * from iac_account
select 'iac_points', * from iac_points
select 'iac_accountfininfo',* from iac_accountfininfo 
select 'iac_accountbalance',* from iac_accountbalance order by acctno
select 'iac_minrepayment',* from iac_minrepayment
--select 'icl_task',* from icl_task
select '#PromptPayment',* from #PromptPayment
select '#AccountCycle',* from #AccountCycle
select '#CycleTxn',* from #CycleTxn
select '#CycleTxnDetail',* from #CycleTxnDetail
--select '#ProductRebate',* from #ProductRebate
rollback transaction
return 54026
*/
	-----------------------------------------------------------------------------------
	COMMIT TRANSACTION
	-----------------------------------------------------------------------------------

	drop table #AccountCycle

	exec TraceProcess @IssNo, @PrcsName, 'End'

	return 54026	-- Statement processing completed successfully
end
GO
