USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BatchPaymentAdjustment]    Script Date: 9/6/2021 10:33:55 AM ******/
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
2012/11/27	Barnett			Initial Development
*******************************************************************************/
	
CREATE procedure [dbo].[BatchPaymentAdjustment]
	@IssNo uIssNo
	--@PaymentBatchId uBatchId
   
as
begin

		

	declare	@TxnCd uTxnCd, @TxnDate datetime, @TxnAmt money, @Descp nvarchar(50), @AppvCd varchar(6),
		@AcctNo varchar(19), @CardNo varchar(19), @DeftBusnLocation varchar(50), @DeftTermId varchar(50), 
		@RcptNo int, @RetCd int,@OnlineInd char(1), @BatchId uBatchId, @TermId uTermId, @Mcc int, @Rrn uRrn, @Stan uStan,
		@InputSrc nvarchar(10), @CrryCd uRefCd, @TxnSeq bigint, @PrcsId uPrcsId, @PrcsDate datetime, @PrcsName varchar(50),
		@Msg varchar(50), @MapInd int, @BusnLocation varchar(20), @PlanId uPlanId, @PaymentBatchId uBatchId

	select @PrcsId = CtrlNo, @PrcsDate = convert(varchar(10),CtrlDate,112)
	from iss_Control 
	where IssNo = @IssNo and CtrlId = 'PrcsId'

	----------------------
	BEGIN TRANSACTION
	----------------------
	
	exec @PaymentBatchId = nextRunNo 1, 'UDIBAtchId'

	-- Tag The transaction need to be process
	Update udii_BatchPaymentCardList
	set BatchId = @PaymentBatchId
	where BatchId is null
		


	 -- Parameters Variable 
	select @Rrn = 0
	select @Stan = 0
	select @InputSrc = 'USER'
	select @TxnDate = getdate()

	
	select @BusnLocation = VarCharVal
	from iss_Default where IssNo = @IssNo and Deft = 'CardCenterBusnLocation'

	select @TermId = IntVal
	from iss_Default where IssNo = @IssNo and Deft = 'CardCenterTermId'

	select @BatchId = 0	-- Always that case for non batch transaction

	-- Validation
	update a 
	set a.Sts = 'C' -- Invalid CardNo
	from udii_BatchPaymentCardList a
	where a.Batchid = @PaymentBatchId and a.cardno not in (select cardno from iac_card (nolock))
		and a.Sts is null
	
	
	update a
	set a.Sts ='T'  -- Invalid TxnCode
	from udii_BatchPaymentCardList a
	where a.Batchid = @PaymentBatchId  and a.TxnCd not in (select TxnCd from itx_TxnCode)
		 and a.Sts is null
	


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


	-- Populate temporary table for further processing
	insert into #SourceTxn (
		BatchId, TxnSeq, IssNo, TxnCd, AcctNo, CardNo, LocalTxnDate, TxnDate,
		LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Descp,
		BusnLocation, Mcc, TermId, Rrn, Stan, AppvCd, CrryCd, Arn, BillMethod,
		PlanId, PrcsId, InputSrc, SrcTxnId, RefTxnId, AuthTxnId, OnlineInd,
		UserId, Sts )
	select @BatchId, 0, @IssNo, a.TxnCd, b.AcctNo, b.CardNo, @TxnDate, @TxnDate,
		isnull(TxnAmt,0), isnull(TxnAmt,0), 0, 0, 0, c.Descp,
		@BusnLocation, @Mcc, @TermId, null, null, @AppvCd, @CrryCd, null, null,
		c.PlanId, @PrcsId, @InputSrc,  null, null, null, c.OnlineInd,
		system_user, null
	from udii_BatchPaymentCardList a (nolock)
	join iac_card b (nolock) on b.CardNo = a.CardNo and b.IssNo = @IssNo
	join itx_TxnCode c (nolock) on c.txnCd = a.TxnCd and c.IssNo = @IssNo
	where a.BatchId = @PaymentBatchId and a.Sts is null

		

	-- Update @RcptNo
	select @TxnSeq = min(TxnId) from #SourceTxn
	
	while @TxnSeq is not null
	begin
		
			Exec @RcptNo = NextRunNo @IssNo, 'RcptNo' 
			
			update #SourceTxn
			set STAN = @RcptNo,
				TxnSeq = TxnId
			where TxnId = @TxnSeq
			
			select @TxnSeq = min(TxnId) from #SourceTxn where TxnId > @TxnSeq
			
	end


	-- Start OnlineTxnProcessing
	exec @RetCd = OnlineTxnProcessing @IssNo

	if @@error <> 0 or dbo.CheckRC(@RetCd) <> 0
	begin
		rollback transaction
		return 70109	-- Failed to insert
	end

	-- If no error then complete 
	update udii_BatchPaymentCardList
	set Sts ='P'
	where BatchId = @PaymentBatchId and Sts is null

	----------------------
	COMMIT TRANSACTION
	----------------------

	
end
GO
