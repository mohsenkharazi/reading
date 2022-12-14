USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CycleProcess]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
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
2005/11/17 Chew Pei			Added OpnCredit Field while inserting #AccountStatement
2017/04/18	Humairah		Remove encryption 
							Canot recompile this SP (for Migration purpose) ; ERROR : Invalid column name StmtCycId ; if need to use this SP, please re-do the logic
******************************************************************************************************************/
--exec CycleProcess 1,'FUJI','FUJILTY','1'
CREATE	procedure [dbo].[CycleProcess]
	@IssNo uIssNo,
	@CardLogo uCardLogo,
	@PlasticType uPlasticType,
	@CycNo uCycNo
as
begin

select 'Canot recompile this SP (for Migration purpose) ; ERROR : Invalid column name StmtCycId ; if need to use this SP, please re-do the logic'
/*
	declare @StmtCycId int,
		@BatchId int,
		@TxnSeq bigint,
		@BusnLocation uMerchNo,
		@TermId uTermId,
		@Descp uDescp50,
		@Mcc smallint,
		@CrryCd uRefCd,
		@MinRepaymtAmt money,
		@MinRepaymtRate money,
		@StmtDueDay tinyint,
		@StmtDueDate datetime,
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
		@StmtNo bigint,
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

	select @PrcsName = 'CycleProcess'

	exec TraceProcess @IssNo, @PrcsName, 'Start'

	----------------------------------------------------------
	-- Retrieves necessary information for later processing --
	----------------------------------------------------------

	-- This Stored Procedure only process account will Billing Type = Monthly
	select @BillingType = 'M'

	select @PrcsId = CtrlNo, @PrcsDate = CtrlDate
	from iss_Control
	where IssNo = @IssNo and CtrlId = 'PrcsId'

	select @StmtDueDate = c.DueDate, @StmtDueDay = c.DueDay, @GracePeriod = GracePeriod
	from iss_CycleControl a
	join iss_PlasticTypeCycle b on b.IssNo = @IssNo and b.CardLogo = @CardLogo
		and b.PlasticType = @PlasticType and b.CycNo = a.CycNo
	join iss_CycleDate c on c.IssNo = @IssNo and c.CycNo = b.CycNo and c.StmtDate = @PrcsDate
	where a.IssNo = @IssNo and a.CycNo = @CycNo and a.Sts = 'A'

	if @@rowcount = 0 or (@StmtDueDate is null and @StmtDueDay is null and @GracePeriod is null)
	begin
		return 95167	-- Cycle day not match
	end

	if @StmtDueDate is null
		select @StmtDueDate = dateadd(dd, isnull(@StmtDueDay, 1), @PrcsDate)

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

	-- Retrieve the last statement number from the same statement date
	select top 1 @StmtNo = a.StmtNo
	from iac_AccountStatement a
	join (select top 1 StmtCycId
		from iac_StatementCycle a
		where a.IssNo = @IssNo and a.StmtDate = @PrcsDate and isnull(RecCnt, 0) > 0
		order by StmtCycId desc) as b
		on b.StmtCycId = a.StmtCycId
	order by a.StmtNo desc

	-- If this is the first cycle process for this statement date then @StmtNo = 0
	select @StmtNo = isnull(@StmtNo, 0)

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

	-- Creating temporary table to store the select account for cycle cut
	create table #AccountStatementTxnDetail (
		AcctNo bigint not null
		)

	if @@error <> 0 return 70270	-- Failed to create temporary table

	create table #AccountStatementPtsDetail (
		AcctNo bigint not null
		)

	if @@error <> 0 return 70270	-- Failed to create temporary table

	select * into #AccountStatementMessage from iac_AccountStatementMessage where StmtCycId = 0

	if @@error <> 0 return 70270	-- Failed to create temporary table

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

	-- Populate last statement info into temporary tables
	select a.AcctNo, b.StmtCycId, b.OpnBal, b.ClsBal, b.ClsPts,
		b.MinRepaymt, b.StmtDate, b.DueDate, b.GracePeriod
	into #PrevAccountStatement 
	from iac_Account a
	join iacv_PrevAccountStatement b on b.AcctNo = a.AcctNo
	where a.IssNo = @IssNo and a.CardLogo = @CardLogo and a.PlasticType = @PlasticType
	and a.CycNo = @CycNo and a.BillingType = @BillingType /*and a.Sts = @Sts*/

	select * into #AccountStatement
	from iac_AccountStatement where AcctNo = 0

	-- Create this month statement file
	insert #AccountStatement (AcctNo, StmtCycId, StmtNo, OpnBal, ClsBal, OpnPts,
		ClsPts, OpnCredit, TotalPaymt, MinRepaymt, PtsIssued, PtsRdm, PtsVoidRdm, PtsAdj, PtsExpired, PtsMisc,
		StmtDate, DueDate, GracePeriod, ExpiryDate1, ExpiryPts1, ExpiryDate2, ExpiryPts2,
		ExpiryDate3, ExpiryPts3, ExpiryDate4, ExpiryPts4, ExpiryDate5, ExpiryPts5,
		ExpiryDate6, ExpiryPts6, Sts)
	select a.AcctNo, 0, 0, isnull(b.ClsBal,0), isnull(b.ClsBal,0), isnull(b.ClsPts,0),
		isnull(b.ClsPts,0), 0, 0, 0, 0, 0, 0, 0, 0, 0,
		@PrcsDate, @StmtDueDate, @GracePeriod, dateadd(mm,1,@PrcsDate), null, dateadd(mm,2,@PrcsDate), null,
		dateadd(mm,3,@PrcsDate), null, dateadd(mm,4,@PrcsDate), null, dateadd(mm,5,@PrcsDate), null,
		dateadd(mm,6,@PrcsDate), null, a.Sts
	from iac_Account a
	left outer join #PrevAccountStatement b on b.AcctNo = a.AcctNo
	--left outer join iss_Address c
	--	on c.IssNo = @IssNo and c.RefTo = 'ACCT' and c.RefKey = a.AcctNo and c.MailingInd = 'Y'
	where a.IssNo = @IssNo and a.CardLogo = @CardLogo and a.PlasticType = @PlasticType
	and a.CycNo = @CycNo and a.BillingType = @BillingType --and a.Sts = @Sts
	--order by c.ZipCd, a.AcctNo

	if @@error <> 0 return 70332	-- Failed to insert new row into #AccountStatement

	if (select count(*) from #AccountStatement) = 0 return 54086	-- No Account has been processed in this cycle

	-- Generate the Statement No for this process
	select a.AcctNo, identity(int, 1, 1) 'StmtNo'
	into #StatementNo
	from #AccountStatement a
	left outer join iss_Address b
		on b.IssNo = @IssNo and b.RefTo = 'ACCT' and b.RefKey = a.AcctNo and b.MailingInd = 'Y'
	order by b.ZipCd, a.AcctNo

	if @@error <> 0 return 70270	-- Failed to create temporary table

	-- Update Statement No into #AccountStatement continue from the last statement number
	update a set StmtNo = b.StmtNo+@StmtNo
	from #AccountStatement a
	join #StatementNo b on b.AcctNo = a.AcctNo

	if @@error <> 0 return 70461	-- Failed to update Statement No

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
	join #AccountStatement b on b.AcctNo = a.AcctNo
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
	from itx_HeldTxn a
	join itx_TxnCode b on b.IssNo = a.IssNo and b.TxnCd = a.TxnCd
	join iss_RefLib c on c.IssNo = b.IssNo and c.RefType = 'TxnType' and c.RefCd = b.Multiplier
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
	from itx_HeldTxnDetail a
	join itx_HeldTxn b on b.IssNo = @IssNo and b.TxnDate is null and b.Sts = 'P' and b.TxnId = a.TxnId
	join itx_TxnCode c on c.IssNo = @IssNo and c.TxnCd = b.TxnCd
	join iss_RefLib d on d.IssNo = @IssNo and d.RefType = 'TxnType' and d.RefCd = c.Multiplier

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

	exec @rc = InterestCalculation @IssNo

	if @@error <> 0 or dbo.CheckRC(@rc) <> 0
	begin
		rollback transaction
		return @rc
	end

	-------------------------
	-- Creating Temp Table --
	-------------------------

	-- Create prompt payment temp table (payment before StmtDueDate+GracePeriod)
	select a.AcctNo, avg(a.ClsBal) 'ClsBal', sum(isnull(b.BillingTxnAmt, 0)) 'TotalPaymt'
	into #PromptPayment
	from #PrevAccountStatement a
	join itx_Txn b on b.AcctNo = a.AcctNo 
		and cast(convert(varchar(11), b.TxnDate, 0) as datetime) <= dateadd(dd, a.GracePeriod, a.DueDate)
		and b.StmtCycId = 0 and b.BillingTxnAmt < 0
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
	from #AccountStatement a
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
	-- Credit Usage Charge --
	-------------------------

/*	insert #CycleTxn (TxnCd, AcctNo, Descp, BusnLocation, TermId, Amt, Pts, Type, Ind)
	select c.TxnCd, a.AcctNo, d.Descp, @BusnLocation, @TermId, c.AccruedCreditUsageAmt, 0, 'CUSG', 'P'
	from #AccountStatement a
	left outer join #PromptPayment b on b.AcctNo = a.AcctNo
	join iac_DailyAccruedInterest c on c.AcctNo = a.AcctNo and c.AccruedCreditUsageAmt > 0
	join itx_TxnCode d on d.IssNo = @IssNo and d.TxnCd = c.TxnCd
	where b.AcctNo is null or (b.AcctNo > 0 and b.ClsBal + b.TotalPaymt > 0)

	if @@error <> 0
	begin
		rollback transaction
		return 70334	-- Failed to create interest transaction
	end
*/
	-------------------------
	-- Late Payment Charge --
	-------------------------

	insert #CycleTxn (TxnCd, AcctNo, Descp, BusnLocation, TermId, Amt, Pts, Type, Ind)
	select @LatePaymtTxnCd, a.AcctNo, @Descp, @BusnLocation, @TermId,
		round(((a.MinRepaymt+isnull(b.TotalPaymt,0))*@LatePaymtInterest/100),2), 0, 'LATE', 'P'
	from #PrevAccountStatement a
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
	from #PrevAccountStatement a
	join iac_AgeingBalance b on b.AcctNo = a.AcctNo and b.StmtCycId = a.StmtCycId
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

	-----------------------------
	-- Product Rebate (Global) --
	-----------------------------

	select a.AcctNo, e.ProdRebateTxnCd 'TxnCd', d.ProdCd, d.DebitBillingTxnAmt 'Amt', d.DebitQty 'Qty'
	into #ProductRebate
	from #AccountStatement a
	join iac_Account b on b.AcctNo = a.AcctNo
	join iss_ProductRebate c on c.IssNo = @IssNo and c.PlasticType = b.PlasticType
	join iac_MTDProduct d on d.AcctNo = a.AcctNo and d.ProdCd = c.ProdCd
		and d.StmtCycId = 0 and d.DebitBillingTxnAmt > 0
	join iss_PlasticType e on e.IssNo = @IssNo and e.CardLogo = b.CardLogo
		and e.PlasticType = b.PlasticType and e.ProdRebateTxnCd > 0

	if @@error <> 0
	begin
		rollback transaction
		return 70374	-- Failed to create Product Type Rebate
	end

	insert #CycleTxn (TxnCd, AcctNo, Descp, BusnLocation, TermId, Amt, Pts, Type, Ind)
	select a.TxnCd, a.AcctNo, b.Descp, @BusnLocation, @TermId, sum(a.Amt), 0, 'PRDR', 'P'
	from #ProductRebate a
	join itx_TxnCode b on b.IssNo = @IssNo and b.TxnCd = a.TxnCd
	group by a.AcctNo, a.TxnCd, b.Descp

	if @@error <> 0
	begin
		rollback transaction
		return 70374	-- Failed to create Product Type Rebate
	end

	insert #CycleTxnDetail (ParentSeq, ProdCd, Amt, Pts, Qty)
	select b.TxnSeq, a.ProdCd, sum(a.Amt), 0, sum(a.Qty)
	from #ProductRebate a
	join #CycleTxn b on b.AcctNo = a.AcctNo and b.TxnCd = a.TxnCd and b.Type = 'PRDR'
	group by a.AcctNo, b.TxnSeq, a.ProdCd

	if @@error <> 0
	begin
		rollback transaction
		return 70374	-- Failed to create Product Type Rebate
	end

	--------------------------------------------------
	-- Product Code Discount for individual Account --
	--------------------------------------------------

	insert #CycleTxn (TxnCd, AcctNo, Descp, BusnLocation, TermId, Amt, Pts, Type, Ind)
	select a.TxnCd, a.AcctNo, b.Descp+' - '+c.Descp, @BusnLocation, @TermId, a.Amt, 0, 'PRDD', 'P'
	from (select a.AcctNo, b.ProdCd, b.TxnCd, sum(c.DebitBillingTxnAmt) 'Amt'
		from #AccountStatement a
		join iac_ProductDiscount b on b.AcctNo = a.AcctNo and b.TxnCd > 0
		join iac_MTDProduct c on c.AcctNo = a.AcctNo and c.StmtCycId = 0 and c.ProdCd = b.ProdCd
		group by a.AcctNo, b.ProdCd, b.TxnCd) as a
	join iss_Product b on b.IssNo = @IssNo and b.ProdCd = a.ProdCd
	join itx_TxnCode c on c.IssNo = @IssNo and c.TxnCd = a.TxnCd

	if @@error <> 0
	begin
		rollback transaction
		return 70375	-- Failed to create Product Type Discount transaction
	end

	-------------------------
	-- Other fixed Charges --
	-------------------------

--select * from #accountstatement
--select * from #PrevAccountStatement
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

	-----------------------------------
	-- Create Statement Cycle record --
	-----------------------------------

	insert iac_StatementCycle (IssNo, CardLogo, PlasticType,
		CycNo, StmtDate, BillingType, PrcsId, PrcsDate, RecCnt, Sts)
	select @IssNo, @CardLogo, @PlasticType,
		@CycNo, @PrcsDate, @BillingType, @PrcsId, @PrcsDate, (select count(*) from #AccountStatement), 'S'

	if @@error <> 0 or @@rowcount = 0
	begin
		rollback transaction
		return 70336	-- Failed to create Statement Cycle Record'
	end

	select @StmtCycId = @@identity

	update iss_Control
	set CtrlNo = @StmtCycId, CtrlDate = @PrcsDate
	where IssNo = @IssNo and CtrlId = 'StmtCycId'

	--------------------------------------
	-- Update Statement closing balance --
	--------------------------------------

	update a set
		ClsBal = isnull(b.Amt, 0),
		MinRepaymt = case when isnull(b.Amt,0) > 0 then b.Amt else 0 end,
		ClsPts = isnull(c.Pts, 0)
	from #AccountStatement a,
		(select a.AcctNo, sum(isnull(b.Amt,0)) 'Amt'
		from #AccountStatement a, iac_AgeingBalance b
		where b.AcctNo =* a.AcctNo and b.StmtCycId = 0 and b.AcctNo =* a.AcctNo
		group by a.AcctNo) as b,
		(select a.AcctNo, sum(c.DebitPts+c.VoidDebitPts+c.CreditPts+c.VoidCreditPts) 'Pts'
		from #AccountStatement a, iac_Points c
		where c.AcctNo =* a.AcctNo
		group by a.AcctNo) as c
	where a.AcctNo *= b.AcctNo and a.AcctNo *= c.AcctNo

	if @@error <> 0
	begin
		rollback transaction
		return 70339	-- Failed to update statement closing balance
	end

	-------------------------
	-- Age Account Balance --
	-------------------------

	update a set AgeingInd = a.AgeingInd + 1
	from iac_AgeingBalance a, #AccountStatement b
	where a.AcctNo = b.AcctNo and a.StmtCycId = 0

	if @@error <> 0
	begin
		rollback transaction
		return 95168	-- Unable to age account
	end

/*	update a set AccumAgeingAmt = case when @Program = 'L' then b.Amt else AccumAgeingAmt end--,
--		AccumAgeingPts = b.Pts
	from iac_AccountFinInfo a
	join	(select a.AcctNo, sum(a.Amt) 'Amt', sum(a.Pts) 'Pts'
		from iac_AgeingBalance a, #AccountStatement b
		where a.AcctNo = b.AcctNo and a.StmtCycId = 0
		and a.AgeingInd <= @AgeingBucket
		group by a.AcctNo) as b
	on a.AcctNo = b.AcctNo

	if @@error <> 0
	begin
		rollback transaction
		return 70340	-- Failed to update ageing balance
	end
*/
	-- Sum the overflow Ageing Amount into the last bucket
	update a set Amt = a.Amt+d.Amt--, Pts = a.Pts+d.Pts
	from iac_AgeingBalance a
	join (	select b.AcctNo, b.Category, sum(b.Amt) 'Amt'--, sum(b.Pts) 'Pts'
			from iac_AgeingBalance b
			join #AccountStatement c on c.AcctNo = b.AcctNo
			where b.StmtCycId = 0 and b.AgeingInd > @AgeingBucket and b.Amt <> 0 --(b.Amt <> 0 or b.Pts <> 0)
			group by b.AcctNo, b.Category ) as d
	on a.AcctNo = d.AcctNo and a.StmtCycId = 0
	and a.AgeingInd = @AgeingBucket and a.Category = d.Category

	if @@error <> 0
	begin
		rollback transaction
		return 70340	-- Failed to update ageing balance
	end

	-- Create the last bucket if its not exists
	insert iac_AgeingBalance (AcctNo, StmtCycId, AgeingInd, Category, Amt)
	select a.AcctNo, 0, @AgeingBucket, a.Category, a.Amt
	from (	select b.AcctNo, b.Category, sum(b.Amt) 'Amt'
			from iac_AgeingBalance b
			join #AccountStatement c on c.AcctNo = b.AcctNo
			where b.StmtCycId = 0 and b.AgeingInd > @AgeingBucket and b.Amt <> 0
			group by b.AcctNo, b.Category ) a
	where not exists (select 1 from iac_AgeingBalance b where b.AcctNo = a.AcctNo
	and b.StmtCycId = 0 and b.AgeingInd = @AgeingBucket and b.Category = a.Category)

	if @@error <> 0
	begin
		rollback transaction
		return 70140	-- Failed to insert Ageing Bucket
	end

	-- Delete overflowed ageing bucket
	delete a
	from iac_AgeingBalance a, #AccountStatement b
	where a.AcctNo = b.AcctNo and a.StmtCycId = 0 and a.AgeingInd > @AgeingBucket

	if @@error <> 0
	begin
		rollback transaction
		return 70341	-- Failed to clear ageing balance
	end

	-- Backup the ageing balance
	insert iac_AgeingBalance (AcctNo, StmtCycId, AgeingInd, Category, Amt,
		TotalCreditAmt, TotalDebitAmt, Pts, TotalCreditPts, TotalDebitPts)
	select a.AcctNo, @StmtCycId, a.AgeingInd, a.Category, a.Amt,
		a.TotalCreditAmt, a.TotalDebitAmt, a.Pts, a.TotalCreditPts, a.TotalDebitPts
	from iac_AgeingBalance a, #AccountStatement b
	where a.AcctNo = b.AcctNo and a.StmtCycId = 0
	and (a.Amt <> 0 or a.Pts <> 0 or a.AgeingInd < 2)

	if @@error <> 0
	begin
		rollback transaction
		return 70140	-- Failed to insert Ageing Bucket
	end

	-- Delete un-wanted ageing record
	delete a
	from iac_AgeingBalance a, #AccountStatement b
	where a.AcctNo = b.AcctNo and a.StmtCycId = 0 and a.Amt = 0 and a.Pts = 0

	if @@error <> 0
	begin
		rollback transaction
		return 70342	-- Failed to delete unwanted ageing record
	end

	------------------------
	-- Age Min. Repayment --
	------------------------
	update a set AgeingInd = a.AgeingInd + 1
	from iac_MinRepayment a, #AccountStatement b
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
	from #AccountStatement a
--	join iac_Account b on b.AcctNo = a.AcctNo
	join (	select a.AcctNo, isnull(max(b.AgeingInd),1) 'AgeingInd'
			from #AccountStatement a
			left outer join iacv_MinRepayment b on b.AcctNo = a.AcctNo and b.Sts = 'A'
			group by a.AcctNo) c on c.AcctNo = a.AcctNo 
	join iss_PlasticTypeDelinquency d on d.IssNo = @IssNo and d.CardLogo = @CardLogo
		and d.PlasticType = @PlasticType and d.AgeingInd = c.AgeingInd and d.FullPaymtInd = 'N'
	where a.ClsBal > 0

	if @@error <> 0
	begin
		rollback transaction
		return 95169	-- Failed to calculate min repayment
	end

	update a set a.MinRepaymt = a.ClsBal - b.MinRepaymt
	from #AccountStatement a,
		(select b.AcctNo, sum(b.MinRepaymt-isnull(b.AmtPaid,0)) 'MinRepaymt'
		from #AccountStatement a, iac_MinRepayment b
		where b.AcctNo = a.AcctNo and b.Sts = 'A' group by b.AcctNo) b
	where a.MinRepaymt > 0 and b.AcctNo = a.AcctNo
	and (a.MinRepaymt + b.MinRepaymt) > a.ClsBal

	if @@error <> 0
	begin
		rollback transaction
		return 95169	-- Failed to calculate min repayment
	end

	-- Create min. repayment record
	insert iac_MinRepayment (IssNo, AcctNo, StmtCycId, MinRepaymt, AgeingInd, AmtPaid, Sts)
	select @IssNo, AcctNo, @StmtCycId, MinRepaymt, 1, 0, 'A'
	from #AccountStatement
	where MinRepaymt > 0

	if @@error <> 0
	begin
		rollback transaction
		return 70344	-- Failed to create min repayment
	end

	-- Update Statement min repayment
	update a set a.MinRepaymt = b.MinRepaymt
	from #AccountStatement a,
		(select b.AcctNo, sum(b.MinRepaymt-isnull(b.AmtPaid,0)) 'MinRepaymt'
		from #AccountStatement a, iac_MinRepayment b
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
	join #AccountStatement b on b.AcctNo = a.AcctNo
	join iss_RefLib c on c.IssNo = @IssNo and c.RefType = 'AcctSts' and c.RefCd = a.Sts
	join (	select a.AcctNo, isnull(max(b.AgeingInd), 0) 'AgeingInd'
			from #AccountStatement a
			left outer join iacv_MinRepayment b on b.AcctNo = a.AcctNo and b.Sts = 'A'
			group by a.AcctNo) as d
		on d.AcctNo = a.AcctNo
	left outer join iss_PlasticTypeDelinquency e
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

	exec @rc = CollectionTaskAssignment @IssNo, @CardLogo, @PlasticType, @CycNo, @StmtCycId

	if @@error <> 0 or dbo.CheckRC(@rc) <> 0 or @rc = 95159
	begin
		rollback transaction
		return @rc
	end

/*	-- Cancel existing Collection Tasks/Cases
	update a set Sts = d.RefCd
	from icl_Task a
	join #AccountStatement b on b.AcctNo = a.AcctNo
	join iss_RefLib c on c.IssNo = @IssNo and c.RefType = 'CollectionTaskSts'
		and c.RefCd = a.Sts and c.RefInd = 0
	join iss_RefLib d on d.IssNo = @IssNo and d.RefType = 'CollectionTaskSts' and d.RefInd = 2 

	if @@error <> 0
	begin
		rollback transaction
		return 70477	-- Failed to update Collection Task
	end

	-- Store the last TaskId
	select @TaskId = isnull(max(TaskId), 0) from icl_Task

	-- Create new Collection Tasks/Cases
	insert	icl_Task (IssNo, AcctNo, AcctSts, AgeingInd, StmtCycId,
			CreationDate, AssignDate, UserId, Sts)
	select @IssNo, a.AcctNo, b.Sts, b.AgeingInd, @StmtCycId,
			@PrcsDate, null, null, d.VarcharVal
	from #AccountStatement a
	join iac_Account b on b.AcctNo = a.AcctNo and b.AgeingInd > 0
	join iss_RefLib c on c.IssNo = @IssNo and c.RefType = 'AcctSts' and c.RefCd = b.Sts and c.RefInd <> 0
	left outer join iss_Default d on d.IssNo = @IssNo and d.Deft = 'NewCollectionTaskSts'
	order by b.AgeingInd

	if @@error <> 0
	begin
		rollback transaction
		return 70476	-- Failed to create new Collection Task
	end

	-- Assign Task to Collector

	-- Create a list of collector to be assign to each task
	select identity(smallint,1,1) 'Seq', a.UserId, a.AgeingInd
	into #CollectorGroup 
	from icl_Group a
	join iss_User b on b.IssNo = @IssNo and b.UserId = a.UserId
	join iss_RefLib c on c.IssNo = @IssNo and c.RefType = 'UserSts'
		and c.RefCd = b.Sts and c.RefInd = 0
	where a.IssNo = @IssNo and a.PlasticType = @PlasticType
	order by AgeingInd

	if @@error <> 0
	begin
		rollback transaction
		return 70270	-- Failed to create temporary table
	end

	-- Create a list of overdue account
	select a.TaskId, a.TaskId-@TaskId 'Seq', a.AgeingInd
	into #Task
	from icl_Task a
	order by a.AgeingInd

	if @@error <> 0
	begin
		rollback transaction
		return 70270	-- Failed to create temporary table
	end

	update a set UserId = b.UserId, AssignDate = getdate()
	from icl_Task a
	join #CollectorGroup b on b.AgeingInd = a.AgeingInd and
		((a.TaskId - (	select min(c.TaskId)
						from icl_Task c
						where c.StmtCycId = @StmtCycId and c.AgeingInd = a.AgeingInd ) + 1) %
		(select count(*) from #CollectorGroup d where d.AgeingInd = b.AgeingInd) + 1) =
		(b.Seq - (select min(e.Seq) from #CollectorGroup e where e.AgeingInd = b.AgeingInd) + 1)
	where StmtCycId = @StmtCycId

	if @@error <> 0
	begin
		rollback transaction
		return 70477	-- Failed to update Collection Task
	end*/

	------------------------
	-- Age Points Balance --
	------------------------

	update a set StmtCycId = @StmtCycId
	from iac_Points a, #AccountStatement b
	where a.AcctNo = b.AcctNo and a.StmtCycId = 0

	if @@error <> 0
	begin
		rollback transaction
		return 95173	-- Failed to age points
	end

	update a set AgeingInd = a.AgeingInd + 1
	from iac_Points a, #AccountStatement b
	where a.AcctNo = b.AcctNo-- and a.StmtCycId = 0

	if @@error <> 0
	begin
		rollback transaction
		return 95173	-- Failed to age points
	end

	---------------------
	-- Update MTD Info --
	---------------------

	-- Tag MTD Category with StmtCycId = 0 to this cycle
	update a set StmtCycId = @StmtCycId, StmtDate = @PrcsDate
	from iac_MTDTxnCategory a, #AccountStatement b
	where a.AcctNo = b.AcctNo and a.StmtCycId = 0

	if @@error <> 0
	begin
		rollback transaction
		return 70354	-- Failed to update MTD TxnCategory
	end

	-- Tag MTD Product with StmtCycId = 0 to this cycle
	update a set StmtCycId = @StmtCycId, StmtDate = @PrcsDate
	from iac_MTDProduct a, #AccountStatement b
	where a.AcctNo = b.AcctNo and a.StmtCycId = 0

	if @@error <> 0
	begin
		rollback transaction
		return 70356	-- Failed to update MTD Product
	end

	-- Tag MTD TxnCd with StmtCycId = 0 to this cycle
	update a set StmtCycId = @StmtCycId, StmtDate = @PrcsDate
	from iac_MTDTxnCode a, #AccountStatement b
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
		from itx_Txn a, #AccountStatement b
		where a.AcctNo = b.AcctNo and a.Odometer is not null and a.Odometer > 0 and a.PrcsDate <= @PrcsDate -- Added by CP 20041228: Odometer > 0 
		and isnull(a.StmtCycId,0) = 0 group by a.AcctNo, a.CardNo) b
	where a.AcctNo = b.AcctNo and a.CardNo = b.CardNo and a.TxnDate = b.TxnDate
	and a.PrcsDate <= @PrcsDate and isnull(a.StmtCycId, 0) = 0
	group by b.AcctNo, b.CardNo

	update a set StmtCycid = @StmtCycId, StmtDate = @PrcsDate
	from iac_MTDCardInfo a, #AccountStatement b
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
			from #AccountStatement a
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
	-------------------------
	-- Tag Account Balance --
	-------------------------

	-- Tag iac_AccountBalance to this cycle
	update a set StmtCycId = @StmtCycId
	from iac_AccountBalance a, #AccountStatement b
	where a.AcctNo = b.AcctNo and a.StmtCycId = 0

	if @@error <> 0
	begin
		rollback transaction
		return 70466	-- Failed to update account balance
	end

	-- Tag iac_CreditSummary to this cycle
	update a set StmtCycId = @StmtCycId
	from iac_CreditSummary a
	join #AccountStatement b on b.AcctNo = a.AcctNo
	where a.StmtCycId = 0

	if @@error <> 0
	begin
		rollback transaction
		return 70468	-- Failed to update Credit Summary record
	end

	-----------------------
	-- Statement Summary --
	-----------------------

	-- Update Total Payment
	update a
	set TotalPaymt = b.Amt
	from #AccountStatement a
	join (	select a.AcctNo, sum(b.CreditBillingTxnAmt) 'Amt'
			from #AccountStatement a
			join iac_MTDTxnCode b on b.AcctNo = a.AcctNo and b.StmtCycId = @StmtCycId
			join itx_TxnCode c on c.IssNo = @IssNo and c.TxnCd = b.TxnCd and c.MinRepaymtInd = 'Y'
			group by a.AcctNo) b on b.AcctNo = a.AcctNo

	-- Update Total Points Issued
	update a
	set PtsIssued = b.DebitPts + b.VoidDebitPts + b.CreditPts + b.VoidCreditPts
	from #AccountStatement a, iac_Points b
	where b.AcctNo = a.AcctNo and b.StmtCycId = @StmtCycId and b.Category = @PtsIssueTxnCategory

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temporary table
	end

	-- Update Total Points Redeemed
	update a
	set PtsRdm = b.CreditPts, PtsVoidRdm = b.VoidCreditPts
	from #AccountStatement a, iac_Points b
	where b.AcctNo = a.AcctNo and b.StmtCycId = @StmtCycId and b.Category = @RdmpTxnCategory

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temporary table
	end

	-- Update Total Points Adjusted
	update a
	set PtsAdj = b.DebitPts + b.VoidDebitPts + b.CreditPts + b.VoidCreditPts
	from #AccountStatement a, iac_Points b
	where b.AcctNo = a.AcctNo and b.StmtCycId = @StmtCycId and b.Category = @AdjustTxnCategory

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temporary table
	end

	-- Update Total Points Expired
	update a
	set PtsExpired = b.DebitPts + b.VoidDebitPts + b.CreditPts + b.VoidCreditPts
	from #AccountStatement a, iac_Points b
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
	from #AccountStatement a

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temporary table
	end

	-- Update expiry points
	update a set
			ExpiryPts1 = b.Pts1, ExpiryPts2 = b.Pts2, ExpiryPts3 = b.Pts3,
			ExpiryPts4 = b.Pts4, ExpiryPts5 = b.Pts5, ExpiryPts6 = b.Pts6
	from #AccountStatement a,
		(select	a.AcctNo,
			sum(case when a.AgeingInd >= @PtsAgeingPeriod then a.Pts else 0 end) 'Pts1',
			sum(case when a.AgeingInd = @PtsAgeingPeriod-1 then a.Pts else 0 end) 'Pts2',
			sum(case when a.AgeingInd = @PtsAgeingPeriod-2 then a.Pts else 0 end) 'Pts3',
			sum(case when a.AgeingInd = @PtsAgeingPeriod-3 then a.Pts else 0 end) 'Pts4',
			sum(case when a.AgeingInd = @PtsAgeingPeriod-4 then a.Pts else 0 end) 'Pts5',
			sum(case when a.AgeingInd = @PtsAgeingPeriod-5 then a.Pts else 0 end) 'Pts6'
		from iacv_PointsAgeing a, #AccountStatement b
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
	insert #AccountStatementMessage (StmtCycId, AcctNo, StmtMsgType, StmtMsgId)
	select @StmtCycId, a.AcctNo, d.StmtMsgType, c.DelinquencyMsg
	from #AccountStatement a, iac_Account b, iss_PlasticTypeDelinquency c, iss_StatementMessage d
	where b.AcctNo = a.AcctNo and c.IssNo = @IssNo and c.CardLogo = b.CardLogo
	and c.PlasticType = b.PlasticType and c.AgeingInd = b.AgeingInd and d.IssNo = @IssNo
	and d.StmtMsgId = c.DelinquencyMsg

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temporary table
	end

	-- Plastic Type Message
	insert #AccountStatementMessage (StmtCycId, AcctNo, StmtMsgType, StmtMsgId)
	select @StmtCycId, a.AcctNo, d.StmtMsgType, c.StmtMsgId
	from #AccountStatement a, iac_Account b, iss_PlasticTypeStatementMessage c, iss_StatementMessage d
	where b.AcctNo = a.AcctNo and c.IssNo = @IssNo and c.CardLogo = b.CardLogo
	and c.PlasticType = b.PlasticType and d.IssNo = @IssNo and d.StmtMsgId = c.StmtMsgId
	and @PrcsDate between d.StartDate and dateadd(ss, -1, dateadd(dd, 1, d.EndDate))

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temporary table
	end

	-- Broadcast Message
	insert #AccountStatementMessage (StmtCycId, AcctNo, StmtMsgType, StmtMsgId)
	select @StmtCycId, a.AcctNo, b.StmtMsgType, b.StmtMsgId
	from #AccountStatement a
	join iss_StatementMessage b on b.StmtMsgType = 'BCM'
		and @PrcsDate between b.StartDate and dateadd(ss, -1, dateadd(dd, 1, b.EndDate))

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temporary table
	end

	-- Account Message
	insert #AccountStatementMessage (StmtCycId, AcctNo, StmtMsgType, StmtMsgId)
	select @StmtCycId, a.AcctNo, c.StmtMsgType, b.StmtMsgId
	from #AccountStatement a, iac_AccountMessageList b, iss_StatementMessage c
	where b.AcctNo = a.AcctNo and b.StmtCycId is null and c.IssNo = @IssNo
	and c.StmtMsgId = b.StmtMsgId

	if @@error <> 0
	begin
		rollback transaction
		return 95095	-- Unable to update temporary table
	end

	update #AccountStatement set StmtCycId = @StmtCycId

	update b set StmtCycId = @StmtCycId
	from #AccountStatement a, iac_AccountMessageList b
	where b.AcctNo = a.AcctNo and b.StmtCycId is null

	if @@error <> 0
	begin
		rollback transaction
		return 70346	-- Failed to update account message list
	end

	------------------------------
	-- Update Account Statement --
	------------------------------

	-- Create AccountStatement History
	insert iac_AccountStatement
	select * from #AccountStatement

	if @@error <> 0
	begin
		rollback transaction
		return 70347	-- Failed to create Account Statement
	end

	-- Create AccountStatementMessage History
	insert iac_AccountStatementMessage
	select * from #AccountStatementMessage

	if @@error <> 0
	begin
		rollback transaction
		return 70348	-- Failed to create Account Statement Message
	end

	-- Update Financial Info
	update a set a.StmtDate = b.StmtDate, a.DueDate = b.DueDate, a.MinRepaymt = b.MinRepaymt
	from iac_AccountFinInfo a, #AccountStatement b
	where a.AcctNo = b.AcctNo

	if @@error <> 0
	begin
		rollback transaction
		return 70127	-- Failed to update Account Financial Info
	end

	-- Update StmtCycId into Transactions
	update a set a.StmtCycId = @StmtCycId
	from itx_Txn a, #AccountStatement b
	where a.AcctNo = b.AcctNo and a.PrcsDate <= @PrcsDate and isnull(a.StmtCycId,0) = 0

	if @@error <> 0
	begin
		rollback transaction
		return 70349	-- Failed to update Transaction
	end

	set nocount off

--select 'itx_txn',* from itx_txn order by acctno
--select 'itx_heldtxn',* from itx_heldtxn order by acctno
--select 'iac_ageingbalance',* from iac_ageingbalance order by acctno
--select 'iac_account', * from iac_account
--select 'iac_accountfininfo',* from iac_accountfininfo 
--select 'iac_accountbalance',* from iac_accountbalance order by acctno
--select 'iac_minrepayment',* from iac_minrepayment
--select 'icl_task',* from icl_task
--select '#PromptPayment',* from #PromptPayment
--select '#AccountStatement',* from #AccountStatement
--select '#PromptPayment',* from #PromptPayment
--select '#CycleTxn',* from #CycleTxn
--select '#CycleTxnDetail',* from #CycleTxnDetail
--select '#ProductRebate',* from #ProductRebate
--rollback transaction
--return 54026
	-----------------------------------------------------------------------------------
	COMMIT TRANSACTION
	-----------------------------------------------------------------------------------

	drop table #AccountStatement

	exec TraceProcess @IssNo, @PrcsName, 'End'

	return 54026	-- Statement processing completed successfully
	*/
end
GO
