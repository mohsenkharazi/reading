USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ManualTransactionInsert]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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
2003/05/02 Kenny	9903001	Printing of Payment Receipt
2003/07/14 Jacky			Added Arn number
2003/08/10 Sam				Enlarge @Descp 30 to 50.
2003/12/15 Aeris			cardno is a mandatory field when TxnCategory = Fee
2004/08/04 Chew Pei			Change CheqNo to ChqNo
******************************************************************************************************************/
CREATE	procedure [dbo].[ManualTransactionInsert]
	@IssNo uIssNo,
	@TxnCd uTxnCd,
	@TxnDate datetime,
	@TxnAmt money,
	@Pts money,
	@Descp nvarchar(50), --2003/08/10
	@AppvCd varchar(6),
	@AcctNo varchar(19),
	@CardNo varchar(19),
	@DeftBusnLocation varchar(50),
	@DeftTermId varchar(50),
	@BusnLocation uMerch,
	-- 2003/07/14 Jacky
	@Arn uArnNo,
	@SrcTxnId uTxnId,
	@RefTxnId uTxnId, --Add by aeris 2003/07/17
	-- 2003/05/02 9903001 Added 2 lines --> @RcptNo int,@ChqNo int
	@RcptNo int,
	@ChqNo int
  as
begin
	declare @BatchId uBatchId,
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
			@Msg varchar(50),
			@MapInd int,
			@AdjChkCardNoFlag int

	select @PrcsName = 'ManualTransactionInsert'

	exec TraceProcess @IssNo, @PrcsName, 'Start'

	if isnull(@BusnLocation,'') = ''
	begin
		select @BusnLocation = VarCharVal
		from iss_Default where IssNo = @IssNo and Deft = @DeftBusnLocation

		if @@error <> 0 or @@rowcount = 0 return 60010	-- Business Location not found
	end
	else
	begin
		if not exists (select 1 from aac_BusnLocation where BusnLocation = @BusnLocation) --iac_BusnLocation
			return 60010	-- Business Location not found
	end

	select @BatchId = 0	-- Always that case for non batch transaction

--	select @Mcc = a.Mcc, @CrryCd = b.CrryCd
--	from aac_BusnLocation a, acq_Acquirer b
--	where a.BusnLocation = @BusnLocation and b.AcqNo = @IssNo and a.AcqNo = b.AcqNo

--	if @@rowcount = 0 return 60010	-- Business Location not found

	select @TermId = IntVal
	from iss_Default where IssNo = @IssNo and Deft = @DeftTermId

	select @AdjChkCardNoFlag = IntVal
	from iss_default where IssNo = @IssNo and Deft ='AdjChkCardNoFlag'

	
	if @@rowcount = 0 return 60032	-- Terminal Id not found

	select @Rrn = 0
	select @Stan = 0
	select @InputSrc = 'USER'

	select @OnlineInd = OnlineInd
	from itx_TxnCode where IssNo = @IssNo and TxnCd = @TxnCd

	if @@rowcount = 0 return 60006	-- Transaction code not found

	--2003/12/15B
	select @MapInd = a.MapInd
	from itx_TxnCode a
	where a.TxnCd = @TxnCd and  a.IssNo = @IssNo
	
	if @AdjChkCardNoFlag = 1 -- Flag to indicate the cardno is a mandatory field 
	begin
			if ((@MapInd & 256) > 0  or @CardNo is null)
	 			return 55067 --Card Number is a compulsory field
			--2003/12/15E
	end
	
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
		-- 2003/05/02 9903001 Replaced one line
--		@BusnLocation, @Mcc, @TermId, @Rrn, @Stan, @AppvCd, @CrryCd, null, null,
		@BusnLocation, @Mcc, @TermId, @ChqNo, @RcptNo, @AppvCd, @CrryCd, @Arn, null,
		null, @PrcsId, @InputSrc, @SrcTxnId, @RefTxnId, null, @OnlineInd,
		system_user, null

	if @@error <> 0 return 70109	-- Failed to insert into itx_SourceTxn table

	exec TraceProcess @IssNo, @PrcsName, 'End'

	return 0
end
GO
