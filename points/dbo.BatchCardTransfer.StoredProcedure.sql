USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BatchCardTransfer]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:

Objective	:

-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2009/11/16	Barnett				Initial Development
2010/10/01	Barnett				Check Account Sts, Stop when closed.
2010/10/20	Barnett				Check if Card got any Txn stuck in WIthHeld, 
								postpone process.
2010/11/25	Barnett				Compare the LastPurchasedate
2015/12/03  Azan                Add checking for IC number, if null select old ic number, if old ic number is null select passport number
2020/03/09  Azan				Add cut off time
*******************************************************************************/
CREATE procedure [dbo].[BatchCardTransfer]
	@IssNo uIssNo,
	@PrcsId	uPrcsId,
	@BatchId uBatchId
   
as
begin

	declare @AcctNo uAcctNo, @Sts char(1), @EntityId int, @SysDate datetime, @CreditAdjTxnCode int, 
			@DebitAdjTxnCode int, @RcptNo int, @ClosedCardSts uRefCd, @Pts money, @RefCd nvarchar(1), @rc int,
			@AcctSts uRefCd, @ClosedAcctSts uRefCd, @RetCd int, @RefInd int, @TermId int, 
			@DebitAdjTxnCodeDescp uDescp50, @CreditAdjTxnCodeDescp uDescp50, @XRefCardNo varchar(20)
			
	declare @CardNo varchar(19),  
			@TrfCardNo varchar(19), 
			@TrfAcctNo varchar(20),
			@BusnLocation Varchar(20),
			@TrfCardFee money, @PrcsDate datetime,
			@OnlineInd char(1),
			@CardActiveSts uRefCd,
			@CutOffDateTime datetime,
			@CutOffTime varchar(20)

	set nocount on 
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	
	select @SysDate = convert(varchar(15), getdate(),112)
	select @CutOffTime = '23:30:000'
	
	if @PrcsId is null
	begin
		select @PrcsId = CtrlNo, @PrcsDate = CtrlDate
		from iss_Control
		where IssNo = @IssNo and CtrlId = 'PrcsId'
	end
	else
	begin
		select @PrcsDate = PrcsDate 
		from cmnv_Processlog 
		where IssNo = @IssNo and Prcsid = @PrcsId
	end

	select @CutOffDateTime = cast((convert(varchar(15), @PrcsDate, 106)) + ' ' + @CutOffTime as datetime)  

	if not exists (select 1 from udii_CardTransfer where BatchId = @BatchId) return 0 -- no batch to process

	-- Reset PrcsSts for PrcsSts ='W' only
	update a
	set a.PrcsSts = 'P',
		a.BatchId = 0
	from udii_CardTransfer a
	where a.PrcsSts ='W' 

	update a 
	set a.PrcsSts = 'P'
	from udii_CardTransfer a
	where a.BatchId = @BatchId and a.PrcsSts is null and a.CreationDate <= @CutOffDateTime   -- Process the ones before cut off time only 

	if not exists (select 1 from udii_CardTransfer where BatchId = @BatchId and PrcsSts = 'P') return 0 -- no batch to process

	-- Check CardNo
	update a
	set a.PrcsSts ='Z' -- Invalid CardNo (Both)
	from udii_CardTransfer a
	where a.BatchId = @BatchId and 
			not exists (select 1 from iac_card b (nolock)  where b.cardno = a.NewCardNo) and
			not exists (select 1 from iac_card c (nolock)  where c.cardno = a.OldCardNo) and 
			a.PrcsSts = 'P'

	update a
	set a.PrcsSts ='X' -- Invalid Old CardNo
	from udii_CardTransfer a
	where  a.BatchId = @BatchId  and 
			not exists (select 1 from iac_card b (nolock)  where b.cardno = a.OldCardNo) 
			and a.PrcsSts = 'P'

	update a
	set a.PrcsSts ='Y' -- Invalid New CardNo
	from udii_CardTransfer a
	where  a.BatchId = @BatchId  and 
			not exists (select 1 from iac_card b (nolock)  where b.cardno = a.NewCardNo) 
			and a.PrcsSts = 'P'
	
	update a
	set a.PrcsSts ='B' -- Same old and new card no.
	from udii_CardTransfer a
	where a.BatchId = @BatchId and a.NewCardNo = a.OldCardNo 
			and a.PrcsSts = 'P'

	-- Collect Data before process
	update a
	set a.OldAcctNo = b.AcctNo,
		a.NewAcctNo = c.AcctNo,
		a.XrefCardNo = b.XRefCardNo,
		a.OldCardStsRefInd = d.RefInd,
		a.NewCardNRIC = case 
							when isnumeric(f.NewIc) = 1 then f.NewIC
							when isnumeric(f.NewIC) = 0 and isnumeric(f.OldIC) = 1 then f.OldIC
							else f.PassportNo
						end, 
		a.OldCardNRIC = case 
							when isnumeric(e.NewIc) = 1 then e.NewIC
							when isnumeric(e.NewIC) = 0 and isnumeric(e.OldIC) = 1 then e.OldIC
							else e.PassportNo
						end, 
		a.CardChkInd = b.CardChkInd,
		a.OldAcctSts = g.Sts,
		a.LastPurchasedDate = case 
								   when b.LastPurchasedDate > c.LastPurchasedDate then b.LastPurchasedDate
								   when c.LastPurchasedDate > b.LastPurchasedDate then c.LastPurchasedDate
								   else null
							  end
	from udii_CardTransfer a
	left join iac_card b (nolock) on b.cardno = a.OldCardNo
	left join iac_Card c (nolock) on c.CardNo = a.NewCardNo
	left join iss_Reflib d (nolock) on d.IssNo = @IssNo and d.RefType = 'CardSts' and d.RefCd = b.Sts
	join iac_Entity e(nolock) on e.EntityId = b.EntityId
	join iac_Entity f(nolock) on f.EntityId = c.EntityId
	join iac_Account g (nolock) on g.AcctNo = b.AcctNo
	where a.BatchId = @BatchId  and a.PrcsSts = 'P' 
	

	-- Check if Card got any Txn stuck in WIthHeld
	update a
	set a.PrcsSts ='W'
	from udii_CardTransfer a
	join itx_WithheldUnsettleTxn b (nolock) on b.AcctNo = a.NewAcctNo and b.OnlineINd ='W'
	where a.BatchId = @BatchId and a.PrcsSts = 'P'
			
	-- Check Old Account Closed
	update a
	set a.PrcsSts ='D'		
	from udii_CardTransfer a
	join iss_reflib b (nolock) on b.RefType='AcctSts' and b.RefInd = 3 and b.RefCd = a.OldAcctSts
	where a.BatchId = @BatchId and a.PrcsSts = 'P'

	update a
	set a.PrcsSts ='C' -- Same old and new AcctNo no.
	from udii_CardTransfer a
	where a.BatchId = @BatchId and a.NewAcctNo = a.OldAcctNo and a.PrcsSts = 'P'

	 -- Check For Multiple NewCardNo card.
	update  a
	set a.PrcsSts = 'M'
	from udii_CardTransfer a
	where a.NewCardNo in (
		select NewCardNo
		from udii_CardTransfer 
		where BatchId = @BatchId
		and PrcsSts = 'P'
		group by NewCardNo 
		having count(NewCardNo)> 1) 
		and a.BatchId = @BatchId and a.PrcsSts = 'P'
		
		
	-- Check For Multiple OldCardNo card.		
	update  a
	set a.PrcsSts = 'M'
	from udii_CardTransfer a
	where a.OldCardNo in (
		select OldCardNo
		from udii_CardTransfer 
		where BatchId = @BatchId
		and PrcsSts = 'P'
		group by OldCardNo 
		having count(OldCardNo)> 1)
		and a.BatchId = @BatchId and a.PrcsSts = 'P'
		
	-- Check both Card NRIC
	update a
	set PrcsSts ='I' --'IC not match'
	from udii_CardTransfer a
	where (isnull(NewCardNRIC, 0) <> NewIc or isnull(OldCardNRIC, 0) <> NewIc) and BatchId = @BatchId  and PrcsSts = 'P'  
	
	update a
	set a.OldCardPrevPtsBal = (b.AccumAgeingPts + isnull(b.WithheldPts,0) + c.WithheldPts) -- divide 100 to convert time RM unit
	from udii_CardTransfer a 
	left outer join  iac_AccountFinInfo b (nolock) on b.AcctNo = a.OldAcctNo
	left outer join iac_OnlineFinInfo c (nolock) on c.IssNo = @IssNo and c.AcctNo = a.OldAcctNo
	where a.BatchId = @BatchId and a.PrcsSts = 'P'
	
	update a
	set a.NewCardPrevPtsBal = (b.AccumAgeingPts + isnull(b.WithheldPts,0) + c.WithheldPts) -- divide 100 to convert time RM unit
	from udii_CardTransfer a 
	left outer join  iac_AccountFinInfo b (nolock) on b.AcctNo = a.NewAcctNo
	left outer join iac_OnlineFinInfo c (nolock) on c.IssNo = @IssNo and c.AcctNo = a.NewAcctNo
	where a.BatchId = @BatchId and a.PrcsSts = 'P'
	
	-- Variable Data
	select @ClosedCardSts = RefCd 
	from iss_RefLib (nolock)
	where IssNo = @IssNo and RefType = 'CardSts' and RefNo = 0 and (RefId & 8) > 0

	select @ClosedAcctSts = RefCd 
	from iss_RefLib (nolock)
	where IssNo = @IssNo and RefType= 'AcctSts' and RefInd = 3 and (MapInd & 4 )> 0

	select @CardActiveSts = RefCd 
	from iss_RefLib (nolock)
	where IssNo = @IssNo and RefType = 'CardSts' and RefNo = 0 and (RefId & 1) > 0

	
	select @CreditAdjTxnCode = IntVal 
	from iss_Default (nolock) where Deft = 'CreditAdjTxnCode'

	select @DebitAdjTxnCode = IntVal 
	from iss_Default (nolock) where Deft = 'DebitAdjTxnCode'

	select @CreditAdjTxnCodeDescp = Descp 
	from itx_TxnCode (nolock) 
	where TxnCd = @CreditAdjTxnCode

	select @DebitAdjTxnCodeDescp = Descp 
	from itx_TxnCode (nolock) 
	where TxnCd = @DebitAdjTxnCode
	
	select  @BusnLocation = VarcharVal
	from iss_Default where IssNo = @IssNo and Deft = 'CardCenterBusnLocation'

	select @TermId  = IntVal
	from iss_Default where IssNo = @IssNo and Deft = 'CardCenterTermId'
	
	select @TrfCardFee = moneyVal
	from iss_default where IssNo = @IssNo and Deft = 'DeftTfnCardFee'
	
	select @BatchId = 0	-- Always that case for non batch transaction
	
	-- Creating Temporary Tables --
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

		

	-- Minus Pts from NewCard
	select @OnlineInd = OnlineInd
	from itx_TxnCode where IssNo = @IssNo and TxnCd = @CreditAdjTxnCode
	
	insert into #SourceTxn (
		BatchId, TxnSeq, IssNo, TxnCd, AcctNo, CardNo, LocalTxnDate, TxnDate,
		LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Descp,
		BusnLocation, Mcc, TermId, Rrn, Stan, AppvCd, CrryCd, Arn, BillMethod,
		PlanId, PrcsId, InputSrc, SrcTxnId, RefTxnId, AuthTxnId, OnlineInd,
		UserId, Sts )
	select	@BatchId, 0, @IssNo, @CreditAdjTxnCode, NewAcctNo, NewCardNo, @PrcsDate, @PrcsDate,
		isnull(NewCardPrevPtsBal/100,0), isnull(NewCardPrevPtsBal/100,0), 0, isnull(NewCardPrevPtsBal,0), 0, @CreditAdjTxnCodeDescp + ' ' + convert(varchar(20), NewCardNo),
		@BusnLocation, null, @TermId, null, null, null, null, 0, null,
		null, @PrcsId, 'USER', null, null, null, @OnlineInd,
		system_user, null
	from udii_Cardtransfer 
	where BatchId = @BatchId and PrcsSts = 'P' and NewCardPrevPtsBal>0

	-- End Minus Pts from NewCard
	
	select @OnlineInd = OnlineInd
	from itx_TxnCode where IssNo = @IssNo and TxnCd = @DebitAdjTxnCode
	
	insert into #SourceTxn (
		BatchId, TxnSeq, IssNo, TxnCd, AcctNo, CardNo, LocalTxnDate, TxnDate,
		LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Descp,
		BusnLocation, Mcc, TermId, Rrn, Stan, AppvCd, CrryCd, Arn, BillMethod,
		PlanId, PrcsId, InputSrc, SrcTxnId, RefTxnId, AuthTxnId, OnlineInd,
		UserId, Sts )
	select	@BatchId, 0, @IssNo, @DebitAdjTxnCode, OldAcctNo, OldCardNo, @PrcsDate, @PrcsDate,
		isnull(NewCardPrevPtsBal/100,0), isnull(NewCardPrevPtsBal/100,0), 0, isnull(NewCardPrevPtsBal,0), 0, @DebitAdjTxnCodeDescp + ' ' + convert(varchar(20), OldCardNo) ,
		@BusnLocation, null, @TermId, null, null, null, null, 0, null,
		null, @PrcsId, 'USER', null, null, null, @OnlineInd,
		system_user, null
	from udii_Cardtransfer 
	where BatchId = @BatchId and PrcsSts = 'P' and NewCardPrevPtsBal>0
	-- Add Pts To Old Account 
	-- End 
	
	
	--Charge the Card Transfer Fee
	select @OnlineInd = OnlineInd 
	from itx_TxnCode where IssNo = @IssNo and TxnCd = 303 -- Replacement Fee (Batch)
	
	insert into #SourceTxn (
		BatchId, TxnSeq, IssNo, TxnCd, AcctNo, CardNo, LocalTxnDate, TxnDate,
		LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Descp,
		BusnLocation, Mcc, TermId, Rrn, Stan, AppvCd, CrryCd, Arn, BillMethod,
		PlanId, PrcsId, InputSrc, SrcTxnId, RefTxnId, AuthTxnId, OnlineInd,
		UserId, Sts )
	select	@BatchId, 0, @IssNo, 303, OldAcctNo, OldCardNo, @PrcsDate, @PrcsDate,
		isnull(@TrfCardFee/100,0), isnull(@TrfCardFee/100,0), 0, isnull(@TrfCardFee,0), 0, 'Replacement fee charged for Card ' +  convert(varchar(20), NewCardNo),
		@BusnLocation, null, @TermId, null, null, null, null, 0, null,
		null, @PrcsId, 'USER', null, null, null, @OnlineInd,
		system_user, null
	from udii_Cardtransfer 
	where BatchId = @BatchId and PrcsSts = 'P'
	--
	
	declare @Counter int
	
	select  @Counter = min(TxnId) from #SourceTxn
	
	while ((select max(TxnId) from #SourceTxn) >= @Counter)
	begin
			Exec @RcptNo = NextRunNo @IssNo, 'RcptNo' 
			
			update #SourceTxn
			set Stan = @RcptNo,
				TxnSeq = TxnId
			where TxnId = @Counter	
			
			select @Counter = @Counter +1
	end
	
	-- select * from #SourceTxn



	--------------------
	BEGIN TRANSACTION
	--------------------
	
	--Pts Transfer & Fee Charges Process
	exec @RetCd = OnlineTxnProcessing @IssNo

	if @@error <> 0 or dbo.CheckRC(@RetCd) <> 0
	begin
		rollback transaction
		return 70109	-- Failed to insert
	end
	

	--Update NewCard Detail
	update b
	set b.XrefAcctNo = a.NewAcctNo,
		b.AcctNo = a.OldAcctNo,
		b.XRefCardNo = a.xRefCardNo,
		b.Sts = @CardActiveSts,
		b.LastPurchasedDate = a.LastPurchasedDate
	from udii_Cardtransfer a
	join iac_Card b (nolock) on b.CardNo = a.NewCardNo
	where a.BatchId = @BatchId and a.PrcsSts = 'P'  
	
	if @@error <> 0
	begin
		rollback transaction
		return 70132  -- Failed to update card detail
	end

	update b
	set b.CardChkInd = a.CardChkInd
	from udii_Cardtransfer a
	join iac_Card b (nolock) on b.CardNo = a.NewCardNo and b.CardChkInd <> 0 
	where a.BatchId = @BatchId and a.PrcsSts = 'P' and a.CardChkInd = 0

	if @@error <> 0
	begin
		rollback transaction
		return 70132  -- Failed to update card detail
	end

	
	-- Tag the Account Sts to closed
	update b
	set b.Sts = @ClosedAcctSts
	from udii_Cardtransfer a
	join iac_Account b (nolock) on b.AcctNo = a.NewAcctNo and b.IssNo = @IssNo
	where a.BatchId = @BatchId and a.PrcsSts = 'P'

	if @@error <> 0
	begin
		rollback transaction
		return 95172  -- Failed to change account status
	end
	
			
	-- set TrfCardNo Sts to closed
	update a
	set a.Sts = @ClosedCardSts
	from iac_card a with (rowlock)
	join udii_Cardtransfer b (nolock) on b.OldCardNo = a.CardNo and b.OldAcctNo = a.AcctNo and b.OldCardStsRefInd <= 4 and b.BatchId = @BatchId and b.PrcsSts = 'P'  

	if @@error <> 0
	begin
		rollback transaction
		return 70363  -- Failed to update Card Status
	end	
	
	insert into iac_Event 
	(IssNo, EventType, AcctNo, CardNo, ReasonCd, Descp, Priority, CreatedBy, AssignTo, XRefDoc, CreationDate, SysInd, Sts)
	select @IssNo, 'ChgSts', OldAcctNo, OldCardNo, 'RPLC', 'Change Status to Closed', 'L', system_user, 
	null, null, getdate(), 'Y', 'C'
	from udii_Cardtransfer
	where BatchId = @BatchId and PrcsSts = 'P' and OldCardStsRefInd <= 4

	if @@error <> 0
	begin
		rollback transaction
		return 70194	-- Failed to create event
	end	
	
	--------------------
	COMMIT TRANSACTION
	--------------------
	
	exec @BatchId = NextRunNo @IssNo, 'UDIBatchId'
	
	update udii_CardTransfer
	set PrcsId = @PrcsId,
		PrcsSts ='E',
		BatchId = @BatchId,
		CreationDate =case 
						when Creationdate is null then Getdate()
						else Creationdate
					  end
	where BatchId = 0 and PrcsId is null and PrcsSts = 'P'
	
	
	update udii_CardTransfer
	set  PrcsId = @PrcsId,
		BatchId = @BatchId
	where BatchId = 0  and isnull(PrcsSts,'') <> '' and PrcsSts <> 'E'  
	
	update a
	set a.OldCardCurrPtsBal = (b.AccumAgeingPts + isnull(b.WithheldPts,0) + c.WithheldPts) -- divide 100 to convert time RM unit
	from udii_CardTransfer a 
	left outer join  iac_AccountFinInfo b (nolock) on b.AcctNo = a.OldAcctNo
	left outer join iac_OnlineFinInfo c (nolock) on c.IssNo = @IssNo and c.AcctNo = a.OldAcctNo
	where a.BatchId = @BatchId and a.PrcsSts ='E'

	update a
	set a.NewCardCurrPtsBal = (b.AccumAgeingPts + isnull(b.WithheldPts,0) + c.WithheldPts) -- divide 100 to convert time RM unit
	from udii_CardTransfer a 
	left outer join  iac_AccountFinInfo b (nolock) on b.AcctNo = a.NewAcctNo
	left outer join iac_OnlineFinInfo c (nolock) on c.IssNo = @IssNo and c.AcctNo = a.NewAcctNo
	where a.BatchId = @BatchId and a.PrcsSts ='E'

	return 0
	
	
end
GO
