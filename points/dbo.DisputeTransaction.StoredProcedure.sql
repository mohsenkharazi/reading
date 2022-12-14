USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[DisputeTransaction]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Dispute Transactions

SP Level	: Primary

-------------------------------------------------------------------------------
When	   Who		CRN		Desc
-------------------------------------------------------------------------------
2004/12/07 Aeris			  	Initial development
******************************************************************************************************************/
CREATE	procedure [dbo].[DisputeTransaction]
	@IssNo uIssNo,
	@AcctNo varchar(19),
	@CardNo varchar(19),
	@Busnlocation uMerch,
	@TermId uTermId,
	@OriginTxnId uTxnId,
	@TxnCd uTxnCd,
	@RetCd int output
as
Begin

	set nocount on

	Declare @TxnDate datetime,
		@CAdjTxnCd uTxnCd,
		@Descp varchar(50),
		@EventType varchar(10), 
		@Msg varchar(240),
		@PrcsName varchar(50),
		@DeftBusnLocation varchar(30),
		@DeftTermId varchar(30),
		@CAdjTxnId uTxnId, 
		@TxnAmt money,
		@Pts money

	select @PrcsName = 'DisputeTransaction'
	exec TraceProcess @IssNo, @PrcsName, 'Start'

	-- get dispute event type
	select @EventType=RefCd from iss_Reflib where refType = 'EventType' and ISsNo = @Issno and RefInd & 1 > 0

	-- Get the credit adjustment transaction code
	select @CAdjTxnCd = TxnCd, @Descp = Descp from itx_TxnCode where IssNo = @ISsNo and TxnCd = 401

	Select @TxnDate = getdate()

	select @DeftTermId =  'CardCenterTermId', @DeftBusnLocation = 'CardCenterBusnLocation' 

	select @TxnAmt = SettleTxnAmt, @Pts = Pts from itx_Txn where txnid = @OriginTxnId 

	-- Creating Temporary Tables --
	select * into #SourceTxn
	from itx_SourceTxn
	where BatchId = -1
	delete #SourceTxn

	select * into #SourceTxnDetail
	from itxv_SourceTxnProductDetail
	where BatchId = -1
	delete #SourceTxnDetail

	-- Creating index for temporary table
	create	unique index IX_SourceTxnDetail on #SourceTxnDetail (
		BatchId,
		ParentSeq,
		TxnSeq )

	if @Descp is null
	begin
		select @Descp = Descp from itx_TxnCode where IssNo = @IssNo and TxnCd = @TxnCd
	end

	exec @RetCd = ManualTransactionInsert
			@IssNo=@IssNo, @TxnCd=@CAdjTxnCd, @TxnDate=@TxnDate, @TxnAmt=@TxnAmt, @Pts=@Pts,
			@Descp=@Descp, @AppvCd=null, @AcctNo=@AcctNo, @CardNo=@CardNo,
			@DeftBusnLocation='CardCenterBusnLocation', @DeftTermId=@DeftTermId,
			@BusnLocation=null, @Arn=null, @SrcTxnId=null,
			-- 2003/05/02 9903001 Added @RcptNo, @CheqNo
			--Added new parameter @RefTxnId 2003/07/17
			@RefTxnId=@OriginTxnId, @RcptNo=null, @ChqNo=null

	if @@error <> 0 or dbo.CheckRC(@RetCd) <> 0
	begin
		return @RetCd
	end

	
	insert #SourceTxnDetail (BatchId, ParentSeq, TxnSeq, IssNo, ProdCd, LocalTxnAmt, SettleTxnAmt,
		BillingTxnAmt, Pts, PromoPts, Qty, SrcTxnId, PlanId, OdometerReading,
		PricePerUnit, Sts)
	select 0, 0, TxnSeq, @IssNo, ProdCd, LocalTxnAmt, SettleTxnAmt ,
		BillingTxnAmt, Pts, PromoPts, Qty, SrcTxnID, PlanId, OdometerReading,
		PricePerLitre, 'A'
	from itxv_TxnProductDetail where TxnId = @OriginTxnId
	

	--------------------
	BEGIN TRANSACTION
	--------------------

	exec @RetCd = OnlineTxnProcessing @IssNo

	if @@error <> 0 or dbo.CheckRC(@RetCd) <> 0
	begin
		rollback transaction
		return 70109	-- Failed to insert
	end

	--------------------
	COMMIT TRANSACTION
	--------------------

	select @CAdjTxnId =TxnId from itx_HeldTxn where IssNo=  @ISsNo and cardNo = @CardNo and AcctNo = @AcctNo and TxnCd = @CAdjTxnCd and RefTxnId = @OriginTxnId
	
	select @Msg = 'Original TxnId =' + convert(varchar(5), @OriginTxnId) + ' CardNo = ' + @CardNo 
		+ ' Txn Amt = ' + convert(varchar(10),@TxnAmt) + ' TxnCode = ' +  convert(varchar(5), @TxnCd) 
		+ ' Busnlocation = ' + @Busnlocation + ' CAdj TxnId = ' + convert(varchar(5), @CAdjTxnId)
	
	insert into iac_Event (ISsNo, EventType, AcctNo, CArdNo, Descp, Priority, CreatedBy, CreationDate, SysInd, Sts)
	values (@IssNo, @EventType,@AcctNo, @CardNo, @Msg, 'L', system_user, getdate(), 'Y', 'C') 

	if @@error <> 0
	begin

		return 70194	-- Failed to create event
	end
	

	exec TraceProcess @IssNo, @PrcsName, 'End'

	return 50104

	set nocount off

End
GO
