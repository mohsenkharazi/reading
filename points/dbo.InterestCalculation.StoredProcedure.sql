USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[InterestCalculation]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure will calculate interest

Calling Sp	: 

Leveling	: Second level
------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2003/07/24 Jacky		   Initial development
2017/04/18	Humairah		Remove encryption 
							Canot recompile this SP (for Migration purpose) ; ERROR : Invalid column name StmtCycId ; if need to use this SP, please re-do the logic
******************************************************************************************************************/

CREATE	procedure [dbo].[InterestCalculation]
	@IssNo uIssNo,
	@PrcsId uPrcsId = null
as
begin
select 'Canot recompile this SP (for Migration purpose) ; ERROR : Invalid column name StmtCycId ; if need to use this SP, please re-do the logic'
/*
	declare	@PrcsDate datetime,
			@PrcsName varchar(50),
			@rc int

	select @PrcsName = 'InterestCalculation'

	exec TraceProcess @IssNo, @PrcsName, 'Start'

	if @PrcsId is null
	begin
		select @PrcsId = CtrlNo, @PrcsDate = CtrlDate
		from iss_Control
		where IssNo = @IssNo and CtrlId = 'PrcsId'
	end
	else
	begin
		select @PrcsDate = PrcsDate
		from cmn_ProcessLog
		where IssNo = @IssNo and PrcsId = @PrcsId

		if @@rowcount = 0 return 95273	-- Unable to retrieve ProcessLog info
	end

	-- Trancate the time value from PrcsDate
	select @PrcsDate = cast(convert(varchar(11), @PrcsDate, 0) as datetime)
	 
	-------------------------
	-- Creating Temp Table --
	-------------------------

	-- Contain current balance
	create table #CurrentAccountBalance (
		AcctNo bigint,
		DueDate datetime,
		TxnDate datetime,
		Category smallint,
		Amt money,
		NextDate datetime )

	if @@error <> 0 return 70270	-- Failed to create temporary table

	-- Initially contain overdue balance but later will add in the current balance for interest calculation
	create table #AccountBalance (
		AcctNo bigint,
		DueDate datetime,
		TxnDate datetime,
		Category smallint,
		Amt money,
		NextDate datetime )

	if @@error <> 0 return 70270	-- Failed to create temporary table

	--------------------------------------------------
	-- Populate temp table for calculating interest --
	--------------------------------------------------

	exec TraceProcess @IssNo, @PrcsName, 'Creating Temp File'

	-- Populate current balance into temp table
	insert #CurrentAccountBalance (AcctNo, DueDate, TxnDate, Category, Amt)
	select a.AcctNo, b.DueDate, dateadd(dd, 1, cast(convert(varchar(11), b.StmtDate, 0) as datetime)), c.Category, sum(c.Amt)/*Opening Balance*/
	from iac_Account a
	join iacv_PrevAccountStatement b on b.AcctNo = a.AcctNo and b.ClsBal > 0
	join iac_AgeingBalance c on c.AcctNo = a.AcctNo and c.StmtCycId = b.StmtCycId
		and c.AgeingInd = 1 and c.Amt > 0
	join iss_PlasticTypeInterest d on d.IssNo = @IssNo and d.PlasticType = a.PlasticType
		and d.Category = c.Category and (d.Interest > 0 or d.CreditUsage > 0)
	where a.IssNo = @IssNo and not exists (select 1 from iac_AccountBalance e
		where e.AcctNo = a.AcctNo and e.Category = c.Category and e.Type = 'C' and StmtCycId = 0
		and e.TxnDate = dateadd(dd, 1, cast(convert(varchar(11), b.StmtDate, 0) as datetime)))
	group by a.AcctNo, b.DueDate, dateadd(dd, 1, cast(convert(varchar(11), b.StmtDate, 0) as datetime)), c.Category
	union
	select a.AcctNo, b.DueDate, c.TxnDate, c.Category, c.Amt/*Daily Balance*/
	from iac_Account a
	join iacv_PrevAccountStatement b on b.AcctNo = a.AcctNo and b.ClsBal > 0
	join iac_AccountBalance c on c.AcctNo = a.AcctNo-- and c.Amt > 0 -- If case of reverse unbilled the Amt can be 0
--		and ((c.StmtCycId = b.StmtCycId and c.Type = 'U') or (c.StmtCycId = 0 and c.Type = 'B'))
		and c.StmtCycId = 0 and c.Type = 'C'
	join iss_PlasticTypeInterest d on d.IssNo = @IssNo and d.PlasticType = a.PlasticType
		and d.Category = c.Category and (d.Interest > 0 or d.CreditUsage > 0)
	where a.IssNo = @IssNo
	-- insert terminator record
	union
	select a.AcctNo, b.DueDate, cast(convert(varchar(11), dateadd(dd, 1, @PrcsDate), 0) as datetime), c.Category, 0/*Closing Balance*/
	from iac_Account a
	join iacv_PrevAccountStatement b on b.AcctNo = a.AcctNo and b.ClsBal > 0
	join iac_AgeingBalance c on c.AcctNo = a.AcctNo and c.StmtCycId = b.StmtCycId
		and c.AgeingInd = 1 and c.Amt > 0
	join iss_PlasticTypeInterest d on d.IssNo = @IssNo and d.PlasticType = a.PlasticType
		and (d.Interest > 0 or d.CreditUsage > 0)
	where a.IssNo = @IssNo

	if @@error <> 0 return 70318	-- Failed to insert account balance

	exec TraceProcess @IssNo, @PrcsName, 'Creating Index for Temp File'

	CREATE  INDEX IX_AcctNoCategory ON #CurrentAccountBalance (AcctNo, Category)
	CREATE	INDEX IX_Category ON #CurrentAccountBalance (Category)
	CREATE	INDEX IX_TxnDateDueDate ON #CurrentAccountBalance (TxnDate, DueDate)

	exec TraceProcess @IssNo, @PrcsName, 'Updating NextDate in Temp File'

	update a set NextDate =
		(select min(b.TxnDate) from #CurrentAccountBalance b
			where b.AcctNo = a.AcctNo and b.Category = a.Category and b.TxnDate > a.TxnDate)
	from #CurrentAccountBalance a

	if @@error <> 0 return 70333	-- Failed to update account balance

--select * from #currentAccountBalance
	-- Clean up unwanted record i.e. Amount = 0
	-- Delete records with NextDate < DueDate because do not calculate interest for balance before
	-- the duedate (IDBB requirement)
	delete #CurrentAccountBalance
	where Amt = 0 or (NextDate <= DueDate)

 	if @@error <> 0 return 70470	-- Failed to delete Account Balance

	-- Update the transaction date which closes to due date (just before due date) to the due date
	-- Which one account only will have 1 record closes to due date. If there is no transaction
	-- for the account for that month than the closes record is last months closing
	update #CurrentAccountBalance
	set TxnDate = DueDate
	where TxnDate < DueDate and NextDate >= DueDate

	if @@error <> 0 return 70333	-- Failed to update account balance

--select * from #currentAccountBalance
	-- Populate overdue balance into temp table
	insert #AccountBalance (AcctNo, DueDate, TxnDate, Category, Amt)
	select a.AcctNo, b.DueDate, dateadd(dd, 1, cast(convert(varchar(11), b.StmtDate, 0) as datetime)), c.Category, sum(c.Amt)/*Opening Balance*/
	from iac_Account a
	join iacv_PrevAccountStatement b on b.AcctNo = a.AcctNo and b.ClsBal > 0
	join iac_AgeingBalance c on c.AcctNo = a.AcctNo and c.StmtCycId = b.StmtCycId
		and c.AgeingInd > 1 and c.Amt > 0
	join iss_PlasticTypeInterest d on d.IssNo = @IssNo and d.PlasticType = a.PlasticType
		and d.Category = c.Category and (d.Interest > 0 or d.CreditUsage > 0)
	where a.IssNo = @IssNo and not exists (select 1 from iac_AccountBalance e
		where e.AcctNo = a.AcctNo and e.Category = c.Category and e.Type = 'D' and StmtCycId = 0
		and e.TxnDate = dateadd(dd, 1, cast(convert(varchar(11), b.StmtDate, 0) as datetime)))
	group by a.AcctNo, b.DueDate, dateadd(dd, 1, cast(convert(varchar(11), b.StmtDate, 0) as datetime)), c.Category
	union
	select a.AcctNo, b.DueDate, c.TxnDate, c.Category, c.Amt/*Daily Balance*/
	from iac_Account a
	join iacv_PrevAccountStatement b on b.AcctNo = a.AcctNo and b.ClsBal > 0
	join iac_AccountBalance c on c.AcctNo = a.AcctNo-- and c.Amt > 0 -- If case of reverse unbilled the Amt can be 0
--		and ((c.StmtCycId = b.StmtCycId and c.Type = 'U') or (c.StmtCycId = 0 and c.Type = 'B'))
		and c.StmtCycId = 0 and c.Type = 'D'
	join iss_PlasticTypeInterest d on d.IssNo = @IssNo and d.PlasticType = a.PlasticType
		and d.Category = c.Category and (d.Interest > 0 or d.CreditUsage > 0)
	where a.IssNo = @IssNo
	-- insert terminator record
	union
	select a.AcctNo, b.DueDate, cast(convert(varchar(11), dateadd(dd, 1, @PrcsDate), 0) as datetime), c.Category, 0/*Closing Balance*/
	from iac_Account a
	join iacv_PrevAccountStatement b on b.AcctNo = a.AcctNo and b.ClsBal > 0
	join iac_AgeingBalance c on c.AcctNo = a.AcctNo and c.StmtCycId = b.StmtCycId
		and c.AgeingInd > 1 and c.Amt > 0
	join iss_PlasticTypeInterest d on d.IssNo = @IssNo and d.PlasticType = a.PlasticType
		and (d.Interest > 0 or d.CreditUsage > 0)
	where a.IssNo = @IssNo

	if @@error <> 0 return 70318	-- Failed to insert account balance

	exec TraceProcess @IssNo, @PrcsName, 'Creating Index for Temp File'

	CREATE  INDEX IX_AcctNoCategory ON #AccountBalance (AcctNo, Category)
	CREATE	INDEX IX_Category ON #AccountBalance (Category)

	exec TraceProcess @IssNo, @PrcsName, 'Updating NextDate in Temp File'

	update a set NextDate =
		(select min(b.TxnDate) from #AccountBalance b
			where b.AcctNo = a.AcctNo and b.Category = a.Category and b.TxnDate > a.TxnDate)
	from #AccountBalance a

	if @@error <> 0 return 70333	-- Failed to update account balance

	-- Clean up unwanted record i.e. Amount = 0
	delete #AccountBalance
	where Amt = 0

 	if @@error <> 0 return 70470	-- Failed to delete Account Balance

	-- Merge Current Balance table to Overdue Balance table

	insert #AccountBalance
	select * from #CurrentAccountBalance

	if @@error <> 0 return 70333	-- Failed to update account balance

	exec TraceProcess @IssNo, @PrcsName, 'Creating Prompt Payment Temp File'

	-- Create prompt payment temp table (payment before StmtDueDate+GracePeriod)
	select a.AcctNo
	into #PromptPaymentAccount
	from iacv_PrevAccountStatement a
	join iac_Account b on b.IssNo = @IssNo and b.AcctNo = a.AcctNo
	join itx_Txn c on c.AcctNo = a.AcctNo 
		and cast(convert(varchar(11), c.TxnDate, 0) as datetime) <= dateadd(dd, a.GracePeriod, a.DueDate)
		and c.StmtCycId = 0 and c.BillingTxnAmt < 0
	join itx_TxnCode d on d.IssNo = @IssNo and d.TxnCd = c.TxnCd and d.ReverseUnbilledInd <> 'Y'--d.MinRepaymtInd = 'Y'
	where a.ClsBal > 0
	group by a.AcctNo
	having abs(sum(isnull(c.BillingTxnAmt, 0))) >= avg(a.ClsBal)

	if @@error <> 0 return 70457	-- Failed to create #PromptPayment

--select * from #accountbalance order by acctno
	---------------------------------------------------------------------------------------
	SAVE TRANSACTION InterestCalculation
	---------------------------------------------------------------------------------------

	------------------------
	-- Calculate Interest --
	------------------------

	-- Reset AccuredInterest and AccuredCreditUsage
	update iac_AccountFinInfo set AccruedInterestAmt = 0, AccruedCreditUsageAmt = 0
	where IssNo = @IssNo

	if @@error <> 0
	begin
		rollback transaction InterestCalculation
		return 70127	-- Failed to update Account Financial Info
	end

	-- Delete previous Daily Accrued Interest record
	delete iac_DailyAccruedInterest where IssNo = @IssNo

	if @@error <> 0
	begin
		rollback transaction InterestCalculation
		return 70473	-- Failed to delete Daily Accrued Interest
	end

	exec TraceProcess @IssNo, @PrcsName, 'Step 1'

	-- Calculate interest
	insert iac_DailyAccruedInterest
		(IssNo, AcctNo, TxnCd, AccruedInterestAmt, AccruedCreditUsageAmt, Type, LastUpdDate)
	select @IssNo, a.AcctNo, c.TxnCd,
		round(sum(datediff(dd, a.TxnDate, a.NextDate) * a.Amt * c.Interest / 36500),2),
--		round(sum(datediff(dd, a.TxnDate, a.NextDate) * a.Amt * c.CreditUsage / 36500),2),
		0, 'I',
		getdate()
	from #AccountBalance a
	join iac_Account b on b.AcctNo = a.AcctNo
	join iss_PlasticTypeInterest c
		on c.IssNo = @IssNo and c.CardLogo = b.CardLogo and c.PlasticType = b.PlasticType
		and c.Category = a.Category and c.Interest > 0
		and a.Amt > c.MaxInterestVoidAmt
	where a.NextDate is not null
		and not exists (select 1 from #PromptPaymentAccount d where d.AcctNo = a.AcctNo)
	group by a.AcctNo, c.TxnCd

	if @@error <> 0
	begin
		rollback transaction InterestCalculation
		return 70475	-- Failed to create Daily Accrued Interest
	end

	exec TraceProcess @IssNo, @PrcsName, 'Step 2'

	-- Calculate credit usage
	insert iac_DailyAccruedInterest
		(IssNo, AcctNo, TxnCd, AccruedInterestAmt, AccruedCreditUsageAmt, Type, LastUpdDate)
	select @IssNo, a.AcctNo, c.CreditUsageTxnCd,
--		round(sum(datediff(dd, a.TxnDate, a.NextDate) * a.Amt * c.Interest / 36500),2),
		round(sum(datediff(dd, a.TxnDate, a.NextDate) * a.Amt * c.CreditUsage / 36500),2),
		0, 'C',
		getdate()
	from #AccountBalance a
	join iac_Account b on b.AcctNo = a.AcctNo
	join iss_PlasticTypeInterest c
		on c.IssNo = @IssNo and c.CardLogo = b.CardLogo and c.PlasticType = b.PlasticType
		and c.Category = a.Category and c.CreditUsage > 0
		and a.Amt > c.MaxInterestVoidAmt
	where a.NextDate is not null
		and not exists (select 1 from #PromptPaymentAccount d where d.AcctNo = a.AcctNo)
	group by a.AcctNo, c.CreditUsageTxnCd

	if @@error <> 0
	begin
		rollback transaction InterestCalculation
		return 70475	-- Failed to create Daily Accrued Interest
	end

	exec TraceProcess @IssNo, @PrcsName, 'Step 3'

	-- Update AccountFinInfo
	update a set AccruedInterestAmt = b.Interest, AccruedCreditUsageAmt = b.CreditUsage
	from iac_AccountFinInfo a
	join (	select a.AcctNo,
			sum(case when a.Type = 'I' then a.AccruedInterestAmt else 0 end) 'Interest',
			sum(case when a.Type = 'C' then a.AccruedInterestAmt else 0 end) 'CreditUsage'
			from iac_DailyAccruedInterest a where a.IssNo = @IssNo
			group by a.AcctNo) b on b.AcctNo = a.AcctNo

	if @@error <> 0
	begin
		rollback transaction InterestCalculation
		return 70474	-- Failed to update Daily Accrued Interest
	end

	exec TraceProcess @IssNo, @PrcsName, 'End Interest Calculation'
*/
end
GO
