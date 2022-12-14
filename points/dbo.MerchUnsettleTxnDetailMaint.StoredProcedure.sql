USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchUnsettleTxnDetailMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	: Cardtrend Systems Sdn. Bhd.
Modular		: Cardtrend Card Management System (CCMS)- Acquiring Module

Objective	: 
SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2007/08/16 Sam		           Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[MerchUnsettleTxnDetailMaint]
	@Func varchar(10),
	@AcqNo uAcqNo,
	@ParentIds uTxnId,
	@SrcIds uTxnId,
	@Ids uTxnId,
	@Seq tinyint,
	@BatchId uBatchId,
	@ProdCd uProdCd,
	@Qty money,
	@AmtPts money,
	@BillingAmt money,
	@BillingPts money

  as
begin
	declare @PrcsId uPrcsId, @PrcsDate datetime, @SysDate datetime, 
			@Ublc varchar(5), @ActiveSts varchar(5), @tDescp varchar(50),
			@TxnInd varchar(5), @AppvCd varchar(6)

	set nocount on

	select @SysDate = getdate(),
		@AmtPts = isnull(@AmtPts,0),
		@BillingAmt = isnull(@BillingAmt,0),
		@BillingPts = isnull(@BillingPts,0)

	if isnull(@AmtPts,0) = 0 and isnull(@BillingPts,0) = 0 return 95125 --Check counter/ litre or amount

	select @Ublc = RefCd
	from iss_RefLib (nolock)
	where IssNo = @AcqNo and RefType = 'MerchBatchSts' and RefNo = 1

	select @ActiveSts = RefCd
	from iss_RefLib (nolock)
	where IssNo = @AcqNo and RefType = 'MerchBatchSts' and RefNo = 0

	----------
	begin tran
	----------
	if @Func = 'Add'
	begin
		insert atx_SourceTxnDetail
			(AcqNo, SrcIds, ParentIds, Seq, BatchId, ProdCd, Qty, AmtPts, FastTrack, BillingAmt, BillingPts, Descp, BusnLocation, UnitPrice, PlanId, LinkIds, LastUpdDate, UserId, Sts )
		select a.AcqNo, a.Ids, a.SrcIds, @Seq, a.BatchId, @ProdCd, @Qty, @AmtPts, 0, @BillingAmt, @BillingPts, b.Descp, a.BusnLocation, 0, 0, 0, @SysDate, system_user, @ActiveSts
		from atx_SourceTxn a
		join iss_Product b (nolock) on a.AcqNo = b.IssNo and b.ProdCd = @ProdCd
		where a.Ids = @SrcIds and a.BatchId = @BatchId

		if @@error <> 0
		begin
			rollback tran
			return 70269
		end

		-----------
		commit tran
		-----------
	end
	else
	begin
		if exists (select 1 from atx_SourceTxnDetail where Ids = @Ids and BatchId = @BatchId)
		begin
			update a
			set Sts = @ActiveSts,
				Qty = @Qty,
				AmtPts = @AmtPts,
				BillingAmt = @BillingAmt,
				BillingPts = @BillingPts,
				BusnLocation = b.BusnLocation,
				LastUpdDate = @SysDate,
				UserId = system_user,
				ProdCd = @ProdCd
			from atx_SourceTxnDetail a
			join atx_SourceTxn b on a.SrcIds = b.Ids and a.BatchId = b.BatchId
			where a.Ids = @Ids and a.BatchId = @BatchId

			if @@error <> 0
			begin
				rollback tran
				return 70268
			end

			update a
			set PrcsId = 0,
				Sts = @Ublc,
				LastUpdDate = @SysDate
			from atx_SourceTxn a
			join (select SrcIds, BatchId, sum(AmtPts) 'AmtPts', sum(BillingAmt) 'BillingAmt', sum(BillingPts) 'BillingPts'
					from atx_SourceTxnDetail
					where SrcIds = @SrcIds and BatchId = @BatchId
					group by SrcIds, BatchId) b on a.Ids = b.SrcIds and a.BatchId = b.BatchId and (a.Amt <> b.AmtPts or a.BillingAmt <> b.BillingAmt or a.BillingPts <> b.BillingPts)
			where a.Ids = @SrcIds and a.BatchId = @BatchId

			if @@error <> 0
			begin
				rollback tran
				return 70268
			end

			update a
			set PrcsId = @PrcsId,
				Sts = @ActiveSts,
				LastUpdDate = @SysDate
			from atx_SourceTxn a
			join (select SrcIds, BatchId, sum(AmtPts) 'AmtPts', sum(BillingAmt) 'BillingAmt', sum(BillingPts) 'BillingPts'
					from atx_SourceTxnDetail
					where SrcIds = @SrcIds and BatchId = @BatchId
					group by SrcIds, BatchId) b on a.Ids = b.SrcIds and a.BatchId = b.BatchId and (a.Amt = b.AmtPts and a.BillingAmt = b.BillingAmt and a.BillingPts = b.BillingPts)
			where a.Ids = @SrcIds and a.BatchId = @BatchId

			if @@error <> 0
			begin
				rollback tran
				return 70268
			end

			update a
			set PrcsId = 0,
				Sts = @Ublc,
				LastUpdDate = @SysDate
			from atx_SourceSettlement a
			join (select SrcIds, BatchId, count(*) 'Cnt', sum(Amt) 'Amt', sum(Pts) 'Pts', sum(BillingAmt) 'BillingAmt', sum(BillingPts) 'BillingPts'
					from atx_SourceTxn
					where SrcIds = @ParentIds and BatchId = @BatchId
					group by SrcIds, BatchId) b on a.Ids = b.SrcIds and a.BatchId = b.BatchId and (a.Cnt <> b.Cnt or a.Pts <> b.Pts or a.BillingAmt <> b.BillingAmt or a.BillingPts <> b.BillingPts)
			where a.Ids = @ParentIds and a.BatchId = @BatchId

			if @@error <> 0
			begin
				rollback tran
				return 70268
			end

			if not exists (select 1 from atx_SourceTxn where Ids = @SrcIds and BatchId = @BatchId and Sts = @Ublc)
			begin
				update a
				set PrcsId = @PrcsId,
					Sts = @ActiveSts,
					LastUpdDate = @SysDate
				from atx_SourceSettlement a
				where Ids = @ParentIds and BatchId = @BatchId

				if @@error <> 0
				begin
					rollback tran
					return 70268
				end
			end

			-----------
			commit tran
			-----------
			return 50262 --Settlement transaction has been updated successfully
		end

		update a
		set PrcsId = 0,
			Sts = @Ublc,
			LastUpdDate = @SysDate
		from atx_SourceSettlement a
		where Ids = @ParentIds and BatchId = @BatchId

		if @@error <> 0
		begin
			rollback tran
			return 70268
		end

		-----------
		commit tran
		-----------
		return 95205 --Insert error atx_SourceTxnDetail
	end
end
GO
