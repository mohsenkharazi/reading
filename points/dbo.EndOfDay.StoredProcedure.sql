USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[EndOfDay]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	:Batch process for updating of card sts or record deletion in TempCredit
-------------------------------------------------------------------------------
When	   Who		CRN		Description
-------------------------------------------------------------------------------
2002/02/25 Wendy			Initial development
2002/04/11 Wendy			Adding in redemption processing 
2003/07/15 Chew Pei			Update account to write off status if write off date is set
2003/11/17 Jacky			Tag/UnTag Over Limit Account Status
2003/12/30 KY				Reset Letter Ref No.
2004/01/05 Chew Pei			Update previous month card odometer into iac_MonthlyInfo
2004/01/16 KY				Delete stmt msg where is not effective
2004/12/06 Chew Pei			Initial codes for deletion of withheldunsettle txn is commented.
							For PDB, deletion of withheldunsettle is based on Credit Hold Day value
							set at Plastic Type Level.
2005/04/08 Chew Pei			Update icl_Task.Sts to 'D'
2005/10/14 Chew Pei			update iac_InvoicePayment, iac_OpenCredit status to 'C'
2009/04/02 Barnett			Reset the withheldPts and UnsettlePts after EOD.
2009/04/09 Chew Pei			Delete record from itx_WithheldUnsettleTxn if Sts <> 'A'
2009/04/15 Barnett			Reset The WithheldPts and UnsettlePts, exclude InputSrc = IPT, OPT, EDC
2009/04/20 Barnett			Update FirstTxnDate & LastTxnDate when CArd done the first & last txn.
2009/08/25 Chew Pei			Comment off withheldunsettle deletion that is not meant for PDB
2009/09/02 Chew Pei			1. Comment off changes made by Barnett on 
								2009/04/15: Reset The WithheldPts and UnsettlePts, exclude InputSrc = IPT, OPT, EDC
								This same updates is put in TxnProcessing.
							2. Comment off changes made by Barnett on
								2009/04/20: Update FirstTxnDate & LastTxnDate when CArd done the first & last txn.
								This same updates is put in TxnProcessing.
*******************************************************************************/

CREATE procedure [dbo].[EndOfDay]
	@IssNo uIssNo
  as
begin
	declare @PrcsId uPrcsId,
		@PrcsDate datetime,
		@RdmpTxnCd uTxnCd,
		@ExpiredCardSts char(1),
		@TerminatedCardSts char(1),
		@WriteOffSts char(2),
		-- 2003/11/17 Jacky [B]
		@DeftAcctSts uRefCd,
		@OverLimitAcctSts uRefCd,
		@Today datetime,
		-- 2003/11/17 Jacky [E]
		@rc int,
		-- 2004/01/06 KY [B]
		@StartPrcsId uPrcsId,
		@EndPrcsId uPrcsId,
		@Ids uTxnId
		-- 2004/01/06 KY [E]

	exec @rc = InitProcess
	if @@error <> 0 or @rc <> 0 return 99999

	select @PrcsId = CtrlNo, @PrcsDate = CtrlDate
	from iss_Control
	where IssNo = @IssNo and CtrlId = 'PrcsId'

	select @RdmpTxnCd = IntVal
	from iss_Default
	where IssNo = @IssNo and Deft = 'RdmpTxnCd'

	select @ExpiredCardSts = Varcharval
	from iss_default
	where IssNo = @IssNo and Deft = 'ExpiredCardSts'

	select @TerminatedCardSts = Varcharval
	from iss_default
	where IssNo = @IssNo and Deft = 'TerminatedCardSts'

	-- CP: 20030715 [B]
	select @WriteOffSts = VarcharVal
	from iss_Default
	where IssNo = @IssNo and Deft = 'AcctWriteOffSts'
	-- CP: 20030715 [E]

	-- 2003/11/17 Jacky [B]
	select @DeftAcctSts = a.VarcharVal
	from iss_Default a
	where a.IssNo = @IssNo and a.Deft = 'DeftAcctSts'

	select @OverLimitAcctSts = a.VarcharVal
	from iss_Default a
	where a.IssNo = @IssNo and a.Deft = 'OverLimitAcctSts'

	select @Today = convert(char(11), getdate(), 106)
	-- 2003/11/17 Jacky [E]

	if @PrcsId is null or @RdmpTxnCd is null
	or @ExpiredCardSts is null or @TerminatedCardSts is null
		return 95160	-- Unable to retrieve control or default value

	-- 2004/01/06 KY [B]
	select @StartPrcsId = min(PrcsId), @EndPrcsId = max(PrcsId) from cmnv_ProcessLog 
	where IssNo = @IssNo and datepart(mm,PrcsDate) = datepart(mm,@PrcsDate) and datepart(yy,PrcsDate) = datepart(yy,@PrcsDate)
	-- 2004/01/06 KY [E]


	-----------------
	BEGIN TRANSACTION
	-----------------

	-----------------------------------------
	-- TAG/UNTAG OVER LIMIT ACCOUNT STATUS --
	-----------------------------------------
	-- Un-Tag over credit limit status
	update a set a.Sts = @DeftAcctSts
	from iac_Account a
	left join iac_TempCreditLimit c
		on c.IssNo = @IssNo and c.Acctno = a.AcctNo and @Today between c.EffDateFrom and c.EffDateTo
	join iac_AccountFinInfo d
		on d.AcctNo = a.AcctNo and d.AccumAgeingAmt <= (d.CreditLimit + isnull(c.CreditLimit,0))
		and d.CreditLimit > 0
	where a.Sts = @OverLimitAcctSts

	if @@error <> 0
	begin
		rollback transaction
		return 70124	-- Failed to update Account
	end

	-- Account has over spent on the credit limit
	update a set a.Sts = @OverLimitAcctSts
	from iac_Account a
	left join iac_TempCreditLimit c
		on c.IssNo = @IssNo and c.AcctNo = a.AcctNo and @Today between c.EffDateFrom and c.EffDateTo
	join iac_AccountFinInfo d
		on d.AcctNo = a.AcctNo and d.AccumAgeingAmt > (d.CreditLimit + isnull(c.CreditLimit,0))
		and d.CreditLimit > 0
	where a.Sts = @DeftAcctSts

	if @@error <> 0
	begin
		rollback transaction TxnProcessing
		return 70124	-- Failed to update Account
	end

	-------------------------------------------------------------------
	-- UPDATE ACCOUNT TO WRITE OFF STATUS IF WRITE OFF DATE IS SETUP --
	-------------------------------------------------------------------
	update iac_Account set Sts = @WriteOffSts
	where IssNo = @IssNo and WriteOffDate = @PrcsDate
	
	if @@error <> 0
	begin
		rollback transaction
		return 95269	-- Unable to tag expired card
	end

	-----------------------------------------------------------------
	-- REMOVING RECORDS WHICH WERE NO LONGER VALID FROM TEMPCREDIT --
	-----------------------------------------------------------------
	-- Tag Account has over spent on the credit limit after the temp credit limit expired
/*	update a set a.Sts = @OverLimitAcctSts
	from iac_Account a
	join iac_TempCreditLimit c
		on c.IssNo = @IssNo and c.AcctNo = a.AcctNo and c.EffDateTo < @Today
	join iac_AccountFinInfo d
		on d.AcctNo = a.AcctNo and d.AccumAgeingAmt > d.CreditLimit and d.CreditLimit > 0
	where a.Sts = @DeftAcctSts

	if @@error <> 0
	begin
		rollback transaction TxnProcessing
		return 70124	-- Failed to update Account
	end
*/
	delete from iac_TempCreditLimit
	where IssNo = @IssNo and EffDateTo < @Today

	if @@error <> 0
	begin
		rollback transaction
		return 95156	-- Unable to remove temporary credit limit
	end

	------------------------------------------
	-- TAG PROCESSED REDEMPTION TRANSACTION --
	------------------------------------------
	update a set PrcsId = @PrcsId
	from itx_RedemptionTxn a, itx_HeldTxn b
	where b.IssNo = @IssNo and b.TxnCd = @RdmpTxnCd and b.Sts = 'E' and b.PrcsId = @PrcsId
	and b.LinkTxnId is not null and b.SrcTxnId is not null
	and a.IssNo = b.IssNo and a.RdmpId = b.SrcTxnId

	if @@error <> 0
	begin
		rollback transaction
		return 95157	-- Unable to tag redemption transaction
	end

	------------------------------------------------
	-- REMOVING UNSETTLE TRANSACTION OVER 30 DAYS --
	------------------------------------------------
	/* Commented by CP : 20041206
	select AcctNo, WithheldUnsettleId, BillingTxnAmt, Pts into #UnsettleOverDue
	from itx_WithheldUnsettleTxn
	where IssNo = @IssNo and OnlineInd = 'U' and @PrcsDate > dateadd(d, 30, TxnDate)
	*/
	-- Added by CP : 20041206[B]
/*	select b.Ids, b.TxnInd, b.CardNo, b.AuthCardNo, b.Rrn, a.AcctNo, a.WithheldUnsettleId, a.BillingTxnAmt, a.Pts 
	into #UnsettleOverDue
	from itx_WithheldUnsettleTxn a
	join atx_OnlineTxn b on b.AcqNo = @IssNo and a.WithheldUnsettleId = b.WithheldUnsettleId
	join iac_Account c on c.AcctNo = a.AcctNo and c.IssNo = @IssNo
	join iss_PlasticType d on d.PlasticType = c.PlasticType and d.CardLogo = c.CardLogo
	where a.IssNo = @IssNo and a.OnlineInd = 'W' and @PrcsDate > dateadd(d, d.CreditHoldDay, a.TxnDate)
	-- 20041206[E]

	declare @CardNo uCardNo, @AuthCardNo uCardNo, @Rrn char(12), @RespCd char(2), @AcctNo uAcctNo, @Msg varchar(50), @TxnInd char(1)

	select @Ids = min(Ids) from #UnsettleOverDue where TxnInd = 'R'
	while @Ids <= (select max(Ids) from #UnsettleOverDue)
	begin
		select @CardNo = CardNo, @AuthCardNo = AuthCardNo, @Rrn = Rrn, @RespCd = null, @AcctNo = AcctNo, @Msg = null, @TxnInd = 'R'
		from #UnsettleOverDue where Ids = @Ids

		exec OnlineLimitPreAuthReversal @Ids, @CardNo, @AuthCardNo, @Rrn, @RespCd output, @AcctNo, @Msg output,	@TxnInd

		if @@error <> 0 or @RespCd <> '00'
		begin
			rollback transaction
			return 70073	-- Failed to update Velocity Limit
		end

		select @Ids = min(Ids) from #UnsettleOverDue where Ids > @Ids and TxnInd = 'R'
	end

	update a set UnSettleAmt = a.UnSettleAmt - b.Amt,
		UnSettlePts = a.UnSettlePts - b.Pts
	from iac_AccountFinInfo a, (select AcctNo, sum(BillingTxnAmt) 'Amt', sum(Pts) 'Pts'
		from #UnsettleOverDue group by AcctNo) as b
	where a.AcctNo = b.AcctNo

	if @@error <> 0
	begin
		rollback transaction
		return 70127	-- Failed to update Account Financial Info
	end

	delete a
	from itx_WithheldUnsettleTxn a
	join #UnsettleOverDue b on b.WithheldUnsettleId = a.WithheldUnsettleId

	if @@error <> 0
	begin
		rollback transaction
		return 70447	-- Failed to update withheld unsettle txn
	end
*/
	-----------------------------------------------------------------------
	-- DELETE WITHHELDUNSETTLE TXN WHICH STS <> 'A' --
	-- V = VOID, K = REVERSAL --
	-----------------------------------------------------------------------
	
/*	delete a
	from itx_WithHeldUnsettleTxn a 
	where Sts <> 'A'
	if @@error <> 0
	begin
		rollback transaction
		return 70447	-- Failed to update withheld unsettle txn
	end
*/	

	-----------------------------------------------------------------------
	-- RECALCULATE WITHHELD AND UNSETTLE AMOUNT FROM WITHHELDUNSETTLETXN --
	-----------------------------------------------------------------------

	Update a set WithheldPts = isnull(b.WithheldPts,0), UnsettlePts = isnull(b.UnsettlePts,0)
--	select a.AcctNo, a.WithheldAmt, a.UnsettleAmt,isnull(b.WithheldAmt,0) 'WAmt', isnull(b.UnsettleAmt,0) 'UAmt'
	from iac_AccountFinInfo a
	left outer join (select a.AcctNo,
						sum(case when a.OnlineInd = 'W' then a.Pts else 0 end)'WithheldPts',
						sum(case when a.OnlineInd = 'U' then a.Pts else 0 end)'UnsettlePts'
					from itx_WithheldunsettleTxn a (nolock)
					where InputSrc not in ('IPT', 'OPT', 'EDC', 'EPC', 'lmsiAuth')							--20181205 exclude lmsiauth
					group by a.AcctNo) as b on b.AcctNo = a.AcctNo
	where (a.WithheldPts <> isnull(b.WithheldPts,0) or a.UnsettlePts <> isnull(b.UnsettlePts,0))

	if @@error <> 0
	begin
		rollback transaction
		return 70447	-- Failed to update withheld unsettle txn
	end

	---------------------------------------------------
	-- UPDATING CARD STS WHICH WAS EXPIRED YESTERDAY --
	---------------------------------------------------
	update iac_Card set Sts = @ExpiredCardSts
	where IssNo = @IssNo
	and CONVERT(varchar, ExpiryDate + 1, 103) = CONVERT( varchar , getdate(), 103)

	if @@error <> 0
	begin
		rollback transaction
		return 95154	-- Unable to tag expired card
	end

	------------------------------------------------------
	-- UPDATING CARD STS WHICH WAS TERMINATED YESTERDAY --
	------------------------------------------------------
	update iac_Card set Sts = @TerminatedCardSts
	where IssNo = @IssNo
	and CONVERT(varchar, TerminationDate + 1, 103) = CONVERT( varchar , getdate(), 103)

	if @@error <> 0
	begin
		rollback transaction
		return 95155	-- Unable to tag terminated card
	end

	---------------------------------------------------------
	-- UPDATE LAST MONTH TXN ODOMETER into iac_MonthlyInfo --
	---------------------------------------------------------
	declare @Day tinyint, @Mth tinyint, @Year smallint	
	select @Day = datepart(dd,(dateadd(d,1, @PrcsDate))) -- Add 1 day to prcsdate, if today 
														-- is last day of the month or tomorrow 
														-- is first day of the month, then perform
														-- below statement.
	if @Day = 1 
	begin
		insert into iac_MonthlyInfo (AcctNo, CardNo, Yr, Mth, Odometer, LastUpdDate)
		select b.AcctNo, a.CardNo, datepart(yy,(dateadd(d,1, @PrcsDate))), datepart(mm,(dateadd(d,1, @PrcsDate))), max(a.Odometer), getdate() -- Khar Yeong, you may add in the checking here.
		from atx_Txn a
		join iac_Card as b on a.CardNo = b.CardNo and b.IssNo = @IssNo
		join	(select CardNo, max(TxnDate) 'TxnDate' from atx_Txn
			 where PrcsId between @StartPrcsId and @EndPrcsId and Odometer is not null and Odometer > 0 group by CardNo)
			 as c on a.CardNo = c.CardNo and a.TxnDate = c.TxnDate
		group by b.AcctNo, a.CardNo

		if @@error <> 0
		begin
			rollback transaction
			return 99999	-- Failed
		end
	end


	-- Extented payment

	-- Auto Renewal

	-- Annual Fee billing

	-- Burn expired points

	-----------------------------------------------------------
	-- RESET LETTER REFERENCE NO. WHEN THIS YEAR HAS GONE BY --
	-----------------------------------------------------------
	if exists (select 1 from iss_Control where IssNo = @IssNo and CtrlId = 'PrcsId' and convert(varchar(4), CtrlDate,112) <> convert(varchar(4), (@PrcsDate + 1), 112))
	begin
		update iss_Control
		set CtrlNo = 0
		where IssNo = @IssNo and CtrlId = 'LetterRefNo' -- For Welcome Letter

		if @@error <> 0
		begin
			rollback transaction
			return 70331	-- Failed to update Control
		end

		update iss_Control
		set CtrlNo = 0
		where IssNo = @IssNo and CtrlId = 'ReIssuePINRefNo' -- For Reissue PIN Letter

		if @@error <> 0
		begin
			rollback transaction
			return 70331	-- Failed to update Control
		end
	end

	---------------------------------------------------------
	-- DELETE STATEMENT MESSAGE WHICH ARE NOT EFFECTIVE --
	---------------------------------------------------------

	delete iss_StatementMessage
	where IssNo = @IssNo and EndDate < @PrcsDate

	if @@error <> 0
	begin
		rollback transaction
		return 70035	-- Failed to delete Statement Message
	end

	----------------------------------------------------------
	-- Update iac_Card..FirstTxnDate
	----------------------------------------------------------
/*	update a 
	set a.FirstTxnDate = TxnDate
	from iac_Card a
	join (
			select min(a1.TxnDate)'TxnDate', a1.CardNo
			from itx_Txn a1 (nolock) 
			join itx_TxnCode b1 (nolock) on b1.TxnCd = a1.TxnCd
			join iss_default c1 (nolock) on c1.Deft = 'PurchTxnCategory' and c1.IntVal = b1.Category
			where a1.PrcsId = @PrcsId
			group by a1.CardNo
			) b on b.CardNo = a.CardNo
	where a.FirstTxnDate is null
	
	if @@error <> 0
	begin
		rollback transaction
		return 71100	-- Failed to update FirstTxnDate
	end

	--------------------------------------
	-- Update iac_card..LastPurchaseDate
	--------------------------------------

	update a 
	set a.LastPurchasedDate = b.TxnDate
	from iac_Card a
	join (
			select max(a1.TxnDate)'TxnDate', a1.CardNo
			from itx_Txn a1 (nolock) 
			join itx_TxnCode b1 (nolock) on b1.TxnCd = a1.TxnCd
			join iss_default c1 (nolock) on c1.Deft = 'PurchTxnCategory' and c1.IntVal = b1.Category
			where a1.PrcsId = @PrcsId
			group by a1.CardNo
			) b on b.CardNo = a.CardNo
	
	
	
	if @@error <> 0
	begin
		rollback transaction
		return 71101	-- Failed to update LastPurchaseDate
	end
*/

	-- COLLECTION
	---------------------------------------------------------------------
	-- Update icl_Task..Sts to 'D' when Account has made full payment,	-- 
	-- and payment is made between DUE DATE and PROMISE DATE			--
	---------------------------------------------------------------------

/*	update a
	set a.Sts = 'D'
	from icl_Task a
	join icl_TaskAction b on b.TaskId = a.TaskId and b.IssNo = @IssNo
	join iac_AccountFinInfo c on convert(varchar(10), c.LastCashRecvDate, 112) between convert(varchar(10), c.DueDate, 112) and convert(varchar(10), b.CardhdActionDate, 112) and 
									c.AccumAgeingAmt <= 0 and c.AcctNo = a.AcctNo and c.IssNo = @IssNo
	where a.Sts = 'O' and a.IssNo = @IssNo
	if @@error <> 0
	begin
		rollback transaction
		return 70477 -- Failed to update Collection Task
	end

	---------------------------------------------------------------------
	-- Update icl_Task..Sts to 'D' when Account has made full payment,	-- 
	-- and payment is made between STMT DATE and DUE DATE				--
	---------------------------------------------------------------------
	update a
	set a.Sts = 'D'
	from icl_Task a
	join iac_AccountFinInfo b on b.AcctNo = a.AcctNo and convert(varchar(10), b.LastCashRecvDate, 112) between convert(varchar(10), b.StmtDate, 112) and convert(varchar(10), b.DueDate, 112) and 
									b.AccumAgeingAmt <= 0 and b.AcctNo = a.AcctNo and b.IssNo = @IssNo 
	where a.Sts = 'O' and a.IssNo = @IssNo

	if @@error <> 0
	begin
		rollback transaction
		return 70477 -- Failed to update Collection Task
	end
	--------------------------------------------------------------------
	-- Change icl_TaskAction to be "Broken Promise" for account holder--
	-- who did not pay on the promised date							--
	--------------------------------------------------------------------
	declare @Sts varchar(2)

	-- Broken Promise	
	select @Sts = RefCd from iss_Reflib where RefType = 'CollectionTaskSts' and RefInd = 3
	
	update a
	set Sts = @Sts 
	from icl_TaskAction a
	join iss_Reflib b on b.RefType = 'CollectionAction' and b.RefCd = a.TaskAction and (b.RefNo & 1) > 0 and b.IssNo = @IssNo
	join icl_Task c on c.TaskId = a.TaskId and c.Sts = 'O' and c.IssNo = @IssNo
	join iac_AccountFinInfo d on d.AcctNo = c.AcctNo and (isnull(convert(varchar(10), d.LastCashRecvDate, 112),0)  < convert(varchar(10), a.ActionDate, 112) or
		isnull(convert(varchar(10),d.LastCashRecvDate, 112),0) > convert(varchar(10), a.CardhdActionDate, 112)) and d.IssNo = @IssNo
	where a.CardhdActionDate = @PrcsDate 

	if @@error <> 0
	begin
		rollback transaction
		return 70477 -- Failed to update Collection Task
	end

	-- Insufficient Payment	
	select @Sts = RefCd from iss_Reflib where RefType = 'CollectionTaskSts' and RefInd = 4
*/
/*	insert icl_TaskAction 
	(IssNo, TaskId, UserId, ActionDate, TaskAction, CardhdActionDate, Descp, Sts)
	select a.IssNo, a.TaskId, system_user, @PrcsDate, @TaskAction, null, null, null 
	from icl_TaskAction a, iss_Reflib b, iac_AccountFinInfo c, icl_Task d
	where a.CardhdActionDate = @PrcsDate and a.TaskAction = b.RefCd and (b.RefNo & 1) > 0 
	and b.RefType = 'CollectionAction' and a.TaskId = d.TaskId and c.AcctNo = d.AcctNo and d.Sts = 'O'
	and convert(varchar(10), a.ActionDate, 112) < < convert()
	--(convert(varchar(10),c.LastCashRecvDate, 112)  < convert(varchar(10), c.DueDate, 112) or
	--convert(varchar(10),c.LastCashRecvDate, 112)  > convert(varchar(10), a.CardhdActionDate, 112))


	if @@error <> 0
	begin
		rollback transaction
		return 70472	-- Failed to create task action
	end
*/

	COMMIT TRANSACTION

	return 54023	-- End Of Day completed successfully
end
GO
