USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ManualTxnDetailMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Manual transaction detail maintenance.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/21 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[ManualTxnDetailMaint]
	@SrcIds uTxnId,
	@IssNo uIssNo,
	@AcqNo uAcqNo,
	@BusnLocation uMerch,
	@BatchId uBatchId,
	@Seq int,
	@tCardNo varchar(19),
	@tIds varchar(8),
	@Qty money,
	@ProdCd uProdCd,
	@UnitPrice money,
	@AmtPts money,
	@Descp uDescp50,
	@FastTrack money
  as
begin
	declare @cDescp uDescp50, @ProdType uRefCd, @TxnCd uTxnCd, @ParentIds int, 
		@PlanId uPlanId, @CardNo uCardNo, @AcctNo uAcctNo, @Ids int

	set nocount on
	select @CardNo = cast(@tCardNo as bigint)
	select @Qty = isnull(@Qty, 1)
	select @Ids = cast(@tIds as int)

	if @ProdCd is null return 55023	--Product Code is a compulsory field

	select @AcctNo = AcctNo
	from iac_Card where CardNo = @CardNo

	if @@rowcount = 0 or @@error <> 0 return 60003 --Card Number not found

	if exists (select 1 from iaa_ProductUtilization where CardNo = @CardNo)
	begin
		if not exists (select 1 from iaa_ProductUtilization where CardNo = @CardNo and ProdCd = @ProdCd)
			return 95058 --Product Code is not applicable to this card
	end
	else
		if exists (select 1 from iaa_ProductUtilization where IssNo = @IssNo and AcctNo = @AcctNo)
		begin
			if not exists (select 1 from iaa_ProductUtilization where IssNo = @IssNo and AcctNo = @AcctNo and ProdCd = @ProdCd)
				return 95268 --Product Code is not applicable to this account
		end

	if @Descp is null
		select @Descp = Descp from iss_Product where IssNo = @IssNo and ProdCd = @ProdCd

	select @ParentIds = Ids,
		@TxnCd = a.TxnCd
	from atx_SourceSettlement a
	join atx_TxnCode b on a.AcqNo = b.AcqNo and a.TxnCd = b.TxnCd
	where a.AcqNo = @AcqNo and a.BatchId = @BatchId

	if @@rowcount = 0 or @@error <> 0 return 95183 --Failed to retrieve Manual Batch

	select @ProdType = ProdType 
	from iss_Product where IssNo = @IssNo and ProdCd = @ProdCd

	select @Seq = max(Seq) + 1 
	from atx_SourceTxnDetail where BatchId = @BatchId and SrcIds = isnull(@SrcIds, 0)

	insert atx_SourceTxnDetail
	( BatchId, ParentIds, SrcIds, Seq, ProdCd, Qty, AmtPts, UnitPrice, BillingPts, BillingAmt, AcqNo, Descp, FastTrack, BusnLocation, PlanId, ProdType, LastUpdDate)
	values
	( @BatchId, @ParentIds, @Ids, isnull(@Seq,1), @ProdCd, @Qty, @AmtPts, @UnitPrice, 0, 0, @AcqNo, isnull(@Descp, @cDescp), isnull(@FastTrack, 0), @BusnLocation, @PlanId, @ProdType, getdate())

	if @@rowcount = 0 or @@error <> 0 return 70231 --Failed to delete SourceTxnDetail
	return 50190 --Manual Txn Detail has been created successfully
end
GO
