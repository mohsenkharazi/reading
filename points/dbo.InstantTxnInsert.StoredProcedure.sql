USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[InstantTxnInsert]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Manual Transaction Capturing via Front-End Application (Dummy Version)

SP Level	: Primary

-------------------------------------------------------------------------------
When	   Who		CRN		Desc
-------------------------------------------------------------------------------
2002/06/17 Jac			  	Initial development

******************************************************************************************************************/

CREATE procedure [dbo].[InstantTxnInsert]
	@IssNo uIssNo,
	@TxnCd uTxnCd,
	@TxnDate datetime,
	@TxnAmt money,
	@Pts money,
	@Descp nvarchar(30),
	@AppvCd varchar(6),
	@AcctNo varchar(19),
	@CardNo varchar(19),
	@DeftBusnLocation varchar(50),
	@DeftTermId varchar(50),
	@RdmpLocation varchar(50),
	@SrcTxnId uTxnId,
	@RetCd int output
  as
begin
	declare @BatchId uBatchId,
		@BusnLocation uMerch,
		@TermId uTermId,
		@Mcc int,
		@Rrn uRrn,
		@Stan uStan,
		@InputSrc nvarchar(10),
		@CrryCd uRefCd,
		@OnlineInd char(1),
		@PrcsId uPrcsId,
		@PrcsDate datetime,
		@PrcsName varchar(50),
		@Msg varchar(50)

	select @PrcsName = 'InstantTxnInsert'

	exec TraceProcess @IssNo, @PrcsName, 'Start'

	select @Msg = cast(@IssNo as varchar(2))+' '+@DeftBusnLocation + ' ' + @DeftTermId

	exec TraceProcess @IssNo, @PrcsName, @Msg

	select @BatchId = 0	-- Always that case for non batch transaction

	if isnull(@RdmpLocation,'') = ''
	begin
		select @BusnLocation = VarCharVal
		from iss_Default where IssNo = @IssNo and Deft = @DeftBusnLocation

		if @@rowcount = 0 return 60010	-- Business Location not found
	end
	else
	begin
		select @BusnLocation = @RdmpLocation

		if @@rowcount = 0 return 60010	-- Business Location not found
	end

--	select @Mcc = a.Mcc, @CrryCd = b.CrryCd
--	from aac_BusnLocation a, acq_Acquirer b
--	where a.BusnLocation = @BusnLocation and b.AcqNo = @IssNo and a.AcqNo = b.AcqNo

--	if @@rowcount = 0 return 60010	-- Business Location not found

	select @TermId = IntVal
	from iss_Default where IssNo = @IssNo and Deft = @DeftTermId

	if @@rowcount = 0 return 60032	-- Terminal Id not found

	select @Rrn = 0
	select @Stan = 0
	select @InputSrc = 'USER'

	select @OnlineInd = OnlineInd
	from itx_TxnCode where IssNo = @IssNo and TxnCd = @TxnCd

	if @@rowcount = 0 return 60006	-- Transaction code not found

	select @PrcsId = CtrlNo, @PrcsDate = CtrlDate
	from iss_Control where IssNo = @IssNo and CtrlId = 'PrcsId'

	-- Populate temporary table for further processing
	insert into #SourceTxn (
		BatchId, TxnSeq, IssNo, TxnCd, AcctNo, CardNo, LocalTxnDate, TxnDate,
		LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Descp,
		BusnLocation, Mcc, TermId, Rrn, Stan, AppvCd, CrryCd, Arn, BillMethod,
		PlanId, PrcsId, InputSrc, SrcTxnId, RefTxnId, AuthTxnId, OnlineInd,
		UserId, Sts )
	select	@BatchId, 0, @IssNo, @TxnCd, @AcctNo, isnull(@CardNo,0), @TxnDate, @TxnDate,
		isnull(@TxnAmt,0), isnull(@TxnAmt,0), 0, isnull(@Pts,0), 0, @Descp,
		@BusnLocation, @Mcc, @TermId, @Rrn, @Stan, @AppvCd, @CrryCd, null, null,
		null, @PrcsId, @InputSrc, @SrcTxnId, 0, null, @OnlineInd,
		system_user, null

	if @@error <> 0 return 70109	-- Failed to insert into itx_SourceTxn table

	exec TraceProcess @IssNo, @PrcsName, 'End'

	return 0
end
GO
