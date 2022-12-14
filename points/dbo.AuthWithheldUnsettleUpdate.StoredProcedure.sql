USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AuthWithheldUnsettleUpdate]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To calc actual billing amt for withheld unsettle transaction update.

-------------------------------------------------------------------------------
When	   Who		CRN		Description
-------------------------------------------------------------------------------
2003/11/27 Sam				Initial development
2005/04/13 Chew Pei			Change "exec TxnBilling @AcqNo"
							to "exec TxnBiling @AcqNo, @AmtInd = 1, @PtsInd = 1"
*******************************************************************************/

CREATE procedure [dbo].[AuthWithheldUnsettleUpdate]
	@AcqNo uAcqNo,
	@Ids uTxnId,
	@BusnLocation uMerch,
	@tCardNo varchar(19),
	@AuthNo char(6)

  as
begin
	declare @Rc int, @CardNo uCardNo, @AuthCardNo uCardNo, @IssTxnCd uTxnCd, @AcctNo uAcctNo, 
		@BillMethod char(1), @PlanId uPlanId, @ArryCnt int, @Seq int, @TxnCd uTxnCd, @OnlineInd uRefCd,
		@AmtCalc money, @PtsCalc money, @WithheldUnsettleId int, @TxnDate datetime, @TermId uTermId, @Descp uDescp50,
		@Amt money

	set nocount on

	select @CardNo = cast(@tCardNo as bigint)
	--select @AuthCardNo = cast(@tAuthCardNo as bigint)

	if @@rowcount = 0 or @@error <> 0 return 95131 --Check active status in acq_Default

	select @TxnCd = TxnCd, 
		@TxnDate = TxnDate,
		@TermId = @TermId,
		@Descp = Descp,
		@Amt = Amt
	from atx_VAETxn where Ids = @Ids and AuthNo = @AuthNo

	if @@error <> 0
	begin
		return 95185	--Invalid Transaction ID
	end

	select @IssTxnCd = IssTxnCd
	from atx_TxnCode where AcqNo = @AcqNo and TxnCd = @TxnCd

	if @@error <> 0
	begin
		return 60006	--Transaction Code not found
	end

	select @OnlineInd = OnlineInd,
		@BillMethod = BillMethod,
		@PlanId = PlanId
	from itx_TxnCode where IssNo = @AcqNo and TxnCd = @IssTxnCd

	if @@error <> 0
	begin
		return 60006	--Transaction Code not found
	end

	select @AcctNo = AcctNo from iac_Card where CardNo = @CardNo

	if @@error <> 0
	begin
		return 60003	--Card Number not found
	end

	--#SourceTxn & #SourceTxnDetail creation.
	select * into #SourceTxn
	from itx_SourceTxn where BatchId = -1
	delete #SourceTxn

	select * into #SourceTxnDetail
	from itx_SourceTxnDetail where BatchId = -1
	delete #SourceTxnDetail

	create unique index IX_SourceTxnDetail
	on #SourceTxnDetail ( BatchId, ParentSeq, TxnSeq )

	if @OnlineInd in ('U', 'W')
	begin
		insert into #SourceTxn (
			BatchId, TxnSeq, IssNo, TxnCd, AcctNo, CardNo, LocalTxnDate, TxnDate,
			LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Descp,
			BusnLocation, Mcc, TermId, Rrn, Stan, AppvCd, CrryCd, Arn, Odometer,
			BillMethod, PlanId, PrcsId, InputSrc, SrcTxnId, RefTxnId, AuthTxnId,
			OnlineTxnId, OnlineInd, UserId, Sts )
		select 1, 1, @AcqNo, @IssTxnCd, @AcctNo, @CardNo, TxnDate, LastUpdDate,
			Amt, Amt, null, null, null, Descp,
			BusnLocation, Mcc, TermId, Rrn, Stan, AuthNo, CrryCd, null, Odometer,
			@BillMethod, @PlanId, PrcsId, 'VAE', SrcIds, null, Ids,
			null, @OnlineInd, UserId, Sts
		from atx_VAETxn
		where Ids = @Ids and AuthNo = @AuthNo

		if @@error <> 0	
		begin
			return 70268	--Failed to update #SourceTxn
		end

		select @ArryCnt = count(*) from atx_VAETxn where SrcIds = @Ids and BusnLocation = @BusnLocation
		if isnull(@ArryCnt,0) > 0
		begin
			select @Seq = isnull(@Seq,0) + 1

			insert #SourceTxnDetail
			( BatchId, ParentSeq, TxnSeq, IssNo, RefTo, RefKey, LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Qty, SrcTxnId, PlanId, Sts)
			select 1,1,@Seq, @AcqNo, 'P', ProdCd, AmtPts, AmtPts, 0,0,0, Qty, null, null, 'A'
			from atx_VAETxnDetail
			where SrcIds = @Ids and BusnLocation = @BusnLocation and Seq = @Seq

			if @@error <> 0
			begin
				return 70266	--Failed to insert into #SourceTxnDetail
			end
			select @Seq = @Seq + 1

			if @Seq <= @ArryCnt
			begin
				insert #SourceTxnDetail
				( BatchId, ParentSeq, TxnSeq, IssNo, RefTo, RefKey, LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Qty, SrcTxnId, PlanId, Sts)
				select 1,1,@Seq, @AcqNo, 'P', ProdCd, AmtPts, AmtPts, 0,0,0, Qty, null, null, 'A'
				from atx_VAETxnDetail
				where SrcIds = @Ids and BusnLocation = @BusnLocation and Seq = @Seq

				if @@error <> 0
				begin
					return 70266	--Failed to insert into #SourceTxnDetail
				end
				select @Seq = @Seq + 1
			end

			if @Seq <= @ArryCnt
			begin
				insert #SourceTxnDetail
				( BatchId, ParentSeq, TxnSeq, IssNo, RefTo, RefKey, LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Qty, SrcTxnId, PlanId, Sts)
				select 1,1,@Seq, @AcqNo, 'P', ProdCd, AmtPts, AmtPts, 0,0,0, Qty, null, null, 'A'
				from atx_VAETxnDetail
				where SrcIds = @Ids and BusnLocation = @BusnLocation and Seq = @Seq

				if @@error <> 0
				begin
					return 70266	--Failed to insert into #SourceTxnDetail
				end
				select @Seq = @Seq + 1
			end

			if @Seq <= @ArryCnt
			begin
				insert #SourceTxnDetail
				( BatchId, ParentSeq, TxnSeq, IssNo, RefTo, RefKey, LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Qty, SrcTxnId, PlanId, Sts)
				select 1,1,@Seq, @AcqNo, 'P', ProdCd, AmtPts, AmtPts, 0,0,0, Qty, null, null, 'A'
				from atx_VAETxnDetail
				where SrcIds = @Ids and BusnLocation = @BusnLocation and Seq = @Seq

				if @@error <> 0
				begin
					return 70266	--Failed to insert into #SourceTxnDetail
				end
				select @Seq = @Seq + 1
			end

			if @Seq <= @ArryCnt
			begin
				insert #SourceTxnDetail
				( BatchId, ParentSeq, TxnSeq, IssNo, RefTo, RefKey, LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Qty, SrcTxnId, PlanId, Sts)
				select 1,1,@Seq, @AcqNo, 'P', ProdCd, AmtPts, AmtPts, 0,0,0, Qty, null, null, 'A'
				from atx_VAETxnDetail
				where SrcIds = @Ids and BusnLocation = @BusnLocation and Seq = @Seq

				if @@error <> 0
				begin
					return 70266	--Failed to insert into #SourceTxnDetail
				end
				select @Seq = @Seq + 1
			end

			if @Seq <= @ArryCnt
			begin
				insert #SourceTxnDetail
				( BatchId, ParentSeq, TxnSeq, IssNo, RefTo, RefKey, LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Qty, SrcTxnId, PlanId, Sts)
				select 1,1,@Seq, @AcqNo, 'P', ProdCd, AmtPts, AmtPts, 0,0,0, Qty, null, null, 'A'
				from atx_VAETxnDetail
				where SrcIds = @Ids and BusnLocation = @BusnLocation and Seq = @Seq

				if @@error <> 0
				begin
					return 70266	--Failed to insert into #SourceTxnDetail
				end
				select @Seq = @Seq + 1
			end
		end

--		CP 20050413 [B]
--		exec @Rc = TxnBilling @AcqNo
		exec @Rc = TxnBilling @AcqNo, @AmtInd = 1, @PtsInd = 1  -- CP: Added @AmtInd & @PtsInd
--		CP 20050413 [E]

		if @@error <> 0 or dbo.CheckRC(@Rc) <> 0
		begin
			return @Rc
		end

		select @AmtCalc = isnull(BillingTxnAmt,0), @PtsCalc = isnull(Pts,0)
		from #SourceTxn where BatchId = 1 and TxnSeq = 1

		exec @Rc = WithheldUnsettleTxnUpdate
			@AcqNo,
			'VAE',
			@IssTxnCd,
			@AcctNo,
			@CardNo,
			@TxnDate,
			@Amt,
			@AmtCalc,
			@PtsCalc,
			@BusnLocation,
			@TermId,
			@Descp,
			@WithheldUnsettleId output

		if @@error <> 0 
		begin
			return 70447	--Failed to insert withheld unsettle txn
		end

		if dbo.CheckRC(@Rc) <> 0
		begin
			return @Rc
		end

		if isnull(@WithheldUnsettleId,0) > 0
		begin
			update atx_VAETxn
			set WithheldUnsettleId = @WithheldUnsettleId
			where Ids = @Ids and AuthNo = @AuthNo

			if @@error <> 0
				return 70366	--Failed to update Voice Authorised transaction
		end
	end

	drop table #SourceTxn
	drop index #SourceTxnDetail.IX_SourceTxnDetail
	drop table #SourceTxnDetail

	return 50242	--Voice Authorised transaction has been created successfully
end
GO
