USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BatchPointTransferProcessing]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:

Objective	:

-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
20160225	Azan			Initial Development 
*******************************************************************************/
/*
DECLARE @RC int
EXEC @RC = BatchPointTransferProcessing  1
SELECT @RC
*/
CREATE PROCEDURE [dbo].[BatchPointTransferProcessing]	
	@IssNo uIssNo
AS
BEGIN
	SET NOCOUNT ON;
	Declare 
		@PrcsId uPrcsId,	
		@PrcsDate datetime,
		@SysDate datetime,
		@TxnAmt money,
		@PtsTransferFromTxnCd int, 
		@PtsTransferToTxnCd int,
		@CardActiveSts uRefCd,
		@AcctActiveSts uRefCd,
		@BatchId uBatchId,
		@PaymentBatchId uBatchId,
		@DescpFrom varchar(50),
		@DescpTo varchar(50),
		@Rrn uRrn,
		@Stan uStan, 
		@InputSrc nvarchar(10),
		@TxnDate datetime,
		@BusnLocation varchar(20),
		@TermId uTermId,
		@TxnSeq bigint,
		@FromAcctNo uAcctNo,
		@FromCardNo uCardNo,
		@RetCd int, 
		@RcptNo int,
		@TotalPts money,
		@Max int,
		@Count int,
		@RecCnt int,
		@MerchantName varchar(50),
		@FileSeq int,
		@Filename varchar(50)

	create table #BulkPointTransfer
	(
	BatchId int,
	AcctNo bigint,
	CardNo bigint,
	TxnCd int,
	TxnAmt money,
	Description nvarchar(50) 
	)
	
	create table #SegregateAcctNo
	(
	Id int identity(1,1),
	BatchId int,
	AcctNo bigint,
	TotalPts money
	)
	
	create table #distinctbatchId
	(
	Id int identity(1,1),
	BatchId int
	)
	
	select @Count =1 
	select @SysDate = convert(varchar(8),getdate(),112)

	select
		@PrcsId = CtrlNo, 
		@PrcsDate = convert(varchar(8),CtrlDate,112)
	from iss_Control 
	where 
		IssNo = @IssNo and CtrlId = 'PrcsId'  

	if @SysDate > @PrcsDate  
	begin
		return 95280
	end

	if not exists (Select 1 from ld_PointTransferTxn (nolock)) 
	begin 
		return 60086
	end

	select @PtsTransferFromTxnCd = IntVal from iss_Default where Deft = 'PtsTransferFromTxnCd'
	select @PtsTransferToTxnCd = IntVal from iss_Default where Deft = 'PtsTransferToTxnCd'
	select @AcctActiveSts = RefCd from iss_RefLib (nolock) where RefType= 'AcctSts' and  Descp = 'Active'
	select @CardActiveSts = RefCd from iss_RefLib (nolock) where RefType= 'CardSts' and  Descp = 'Active'

	insert udii_BatchPointTransferTxn (BatchId,Filename,FromAcctNo,ToCardNo,Pts,PrcsId)
	select BatchId,Filename,FromAcctNo,ToCardNo,Pts,@PrcsId from ld_PointTransferTxn (nolock) 

	update a
	set a.Sts = 'F',
		a.Descp = 'Merchant account not found'
	from udii_BatchPointTransferTxn a (nolock) where a.FromAcctNo not in 
	(
	select a.AcctNo from iac_Account a (nolock) 
	join iac_card b (nolock) on a.AcctNo = b.AcctNo 
	join iss_CardType d (nolock) on b.CardType = d.CardType
	where d.CardRangeId = 'PTSTRD' and a.Sts = @AcctActiveSts and b.Sts = @CardActiveSts
	)
	and a.Sts is null and a.PrcsId = @PrcsId
	
	update a
	set a.Sts = 'F',	
		a.Descp = 'Invalid merchant account'
	from udii_BatchPointTransferTxn a (nolock) where a.FromAcctNo <> substring(Filename,13,10) and a.Sts is null and a.PrcsId = @PrcsId

	update a
	set a.Sts = 'F',
		a.Descp = 'Merchant account not in active status'
	from udii_BatchPointTransferTxn a (nolock) 
	join iac_Account b (nolock) on a.FromAcctNo = b.AcctNo 
	where b.Sts <> @AcctActiveSts and a.PrcsId = @PrcsId and a.BatchId = @PaymentBatchId and a.Sts is null and a.PrcsId = @PrcsId
	
	update a
	set a.Sts = 'F',
		a.Descp = 'Card number not found'
	from udii_BatchPointTransferTxn a (nolock) where a.ToCardNo not in (select CardNo from iac_card (nolock)) and a.Sts is null and a.PrcsId = @PrcsId

	update a
	set a.Sts = 'F',
		a.Descp = 'Card number not in active status'
	from udii_BatchPointTransferTxn a (nolock)
	join iac_Card b (nolock) on a.ToCardNo = b.CardNo where b.Sts <> @CardActiveSts and a.Sts is null and a.PrcsId = @PrcsId

	update a 
	set a.Sts = 'F',
		a.Descp = 'Invalid points to be transfered'
	from udii_BatchPointTransferTxn a (nolock) where isnumeric(a.Pts) = 0 and a.Sts is null and a.PrcsId = @PrcsId

	update a 
	set a.Sts = 'F',
		a.Descp = 'Invalid points to be transfered'
	from udii_BatchPointTransferTxn a (nolock) where a.Pts <= 0 and a.Sts is null and a.PrcsId = @PrcsId 

	update a 
	set a.Sts = 'F',
		a.Descp = 'Invalid points to be transfered'
	from udii_BatchPointTransferTxn a (nolock) where a.Pts <> round(a.Pts,0) and a.Sts is null and a.PrcsId = @PrcsId  

	insert #SegregateAcctNo(BatchId,AcctNo,TotalPts)
	select BatchId,FromAcctNo,sum(Pts) from udii_BatchPointTransferTxn where Sts is null and PrcsId = @PrcsId
	group by BatchId,FromAcctNo 

	select a.BatchId,a.AcctNo,sum(b.TotalPts)'SumTotalPts' 
	into #SegregateAcctNoSum
	from #SegregateAcctNo a join #SegregateAcctNo b on a.Id >= b.Id
	group by a.Id,a.BatchId,a.AcctNo
	
	update a
	set a.Sts = 'F',
		a.Descp = 'Insufficient points to be transfered'
	from udii_BatchPointTransferTxn a 
	join #SegregateAcctNoSum b on a.BatchId = b.BatchId
	join iac_AccountFinInfo c (nolock) on a.FromAcctNo = c.AcctNo  
	where b.SumTotalPts > (c.AccumAgeingPts+c.WithheldPts) and a.Sts is null and PrcsId = @PrcsId

	insert into #distinctbatchId(BatchId)
	select distinct(BatchId) 
	from udii_BatchPointTransferTxn (nolock) 
	where Sts is null and PrcsId = @PrcsId 
	order by BatchId

	select @Max = max(Id) from #distinctbatchId 

	while @Count <= @Max
	begin
		exec @BatchId = NextRunNo @IssNo, 'UDIBatchId'
		select @PaymentBatchId = BatchId from #distinctbatchId where Id = @Count
		select @RecCnt = count(*) from udii_BatchPointTransferTxn (nolock) where BatchId = @PaymentBatchId 
		select @FileSeq = SUBSTRING(Filename,24,CHARINDEX('.',Filename) - 24) from udii_BatchPointTransferTxn where BatchId = @PaymentBatchId 
		select @Filename = Filename from udii_BatchPointTransferTxn where BatchId = @PaymentBatchId 

		insert udi_Batch (IssNo, BatchId,PhyFilename,SrcName, FileName,FileSeq,DestName, FileDate, RecCnt, Direction, PrcsId, PrcsDate,RefNo1,Sts)
		select distinct @IssNo,@BatchId,@Filename,'PTSTRF','TRANSACTION',@FileSeq,'HOST',getdate(),@RecCnt,'I',@PrcsId,@PrcsDate,@PaymentBatchId,'P' 

		update a
		set a.FromCardNo = b.CardNo, 
			a.ToAcctNo = c.AcctNo
		from udii_BatchPointTransferTxn a (nolock) 
		join iac_card b (nolock) on b.AcctNo = a.FromAcctNo  
		join iac_card c (nolock) on c.CardNo = a.ToCardNo 
		where a.BatchId = @PaymentBatchId and a.Sts is null and a.PrcsId = @PrcsId
		
		select @FromAcctNo = FromAcctNo from udii_BatchPointTransferTxn where BatchId = @PaymentBatchId and Sts is null and PrcsId = @PrcsId 
		select @FromCardNo = FromCardNo from udii_BatchPointTransferTxn where BatchId = @PaymentBatchId and Sts is null and PrcsId = @PrcsId 
		select @TotalPts = sum(Pts) from udii_BatchPointTransferTxn where BatchId = @PaymentBatchId and Sts is null and PrcsId = @PrcsId

		select @MerchantName = a.FamilyName from iac_entity a (nolock) join iac_account b (nolock) on a.EntityId = b.EntityId where b.AcctNo = @FromAcctNo
		
		select @DescpTo = Descp + ' '+'batch'+' '+convert(varchar(20), @PaymentBatchId) from itx_TxnCode (nolock) where TxnCd = @PtsTransferToTxnCd
		select @DescpFrom = Descp + ' '+convert(varchar(50), @MerchantName) from itx_TxnCode (nolock) where TxnCd = @PtsTransferFromTxnCd

		insert into #BulkPointTransfer(BatchId,AcctNo,CardNo,TxnCd,TxnAmt,Description) -- insert transfer to record
		select @PaymentBatchId,@FromAcctNo,@FromCardNo,@PtsTransferToTxnCd,@TotalPts* 0.01,@DescpTo  

		insert into #BulkPointTransfer(BatchId,AcctNo,CardNo,TxnCd,TxnAmt,Description) -- insert transfer from record
		select BatchId,ToAcctNo,ToCardNo,@PtsTransferFromTxnCd,Pts* 0.01,@DescpFrom from udii_BatchPointTransferTxn 
		where BatchId = @PaymentBatchId and Sts is null and PrcsId = @PrcsId
		
		select @Count = @Count+1
		select @FromAcctNo = null
		select @FromCardNo = null
		select @TotalPts = null
		select @MerchantName = null
		select @DescpTo = null
		select @DescpFrom = null
	end

	update udii_BatchPointTransferTxn with (rowlock) set Sts = 'S' where Sts is null and PrcsId = @PrcsId
	update udii_BatchPointTransferFile with (rowlock) set Sts = 'P' where Sts = 'L' and PrcsId = @PrcsId

	truncate table ld_PointTransferTxn

	---------------------------------------------------------------------------------------------------------------
	BEGIN TRANSACTION
	---------------------------------------------------------------------------------------------------------------

	select @Rrn = 0
	select @Stan = 0
	select @InputSrc = 'USER'
	select @TxnDate = getdate()

	select @BusnLocation = VarCharVal
	from iss_Default where IssNo = @IssNo and Deft = 'CardCenterBusnLocation'

	select @TermId = IntVal
	from iss_Default where IssNo = @IssNo and Deft = 'CardCenterTermId'

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
	create	unique index IX_SourceTxnDetail on #SourceTxnDetail (BatchId,ParentSeq,TxnSeq )

	-- Populate temporary table for further processing
	insert into #SourceTxn (
		BatchId, TxnSeq, IssNo, TxnCd, AcctNo, CardNo, LocalTxnDate, TxnDate,
		LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Descp,
		BusnLocation, Mcc, TermId, Rrn, Stan, AppvCd, CrryCd, Arn, BillMethod,
		PlanId, PrcsId, InputSrc, SrcTxnId, RefTxnId, AuthTxnId, OnlineInd,
		UserId, Sts )
	select 0, 0, @IssNo, a.TxnCd, a.AcctNo, a.CardNo, @TxnDate, @TxnDate,
		isnull(TxnAmt,0), isnull(TxnAmt,0), 0, 0, 0, a.Description,
		@BusnLocation, null, @TermId, null, null, null, null, null, null,
		c.PlanId, @PrcsId, @InputSrc,  null, null, null, c.OnlineInd,
		system_user, null
	from #BulkPointTransfer a (nolock)
	join iac_card b (nolock) on b.CardNo = a.CardNo and b.IssNo = @IssNo
	join itx_TxnCode c (nolock) on c.txnCd = a.TxnCd and c.IssNo = @IssNo
	where a.AcctNo is not null and a.CardNo is not null

	-- Update @RcptNo
	select @TxnSeq = min(TxnId) from #SourceTxn
	
	while @TxnSeq is not null
	begin
			exec @RcptNo = NextRunNo @IssNo, 'RcptNo' 
			
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
		return @RetCd	
	end

	COMMIT TRANSACTION

	drop table #BulkPointTransfer
	drop table #SegregateAcctNo
	drop table #distinctbatchId

	return 0  --'Points Transferred successfully'
END
GO
