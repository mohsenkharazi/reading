USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BusnMTDSummarySelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)-Acquiring Module

Objective	:Business location month to date summary list for 
		 prod cd & txn cd.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/10/01 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[BusnMTDSummarySelect]
	@AcqNo uAcqNo,
	@SummType char(1),
	@BusnLocation uMerch,
	@StmtCycId int
   as
begin
	set nocount on
/*	if @SummType = 'P'
	begin
		select a.ProdCd, b.Descp, TermId, isnull(sum(a.Cnt), 0) 'Count', isnull(sum(a.Amt), 0) 'TxnAmt', isnull(sum(a.BillingAmt), 0) 'BillingAmt', isnull(sum(a.BillingPts), 0) 'BillingPts'
		from acq_MTDProdCd a
		left outer join iss_Product b on b.ProdCd = a.ProdCd and b.IssNo = a.AcqNo 
		where a.BusnLocation = @BusnLocation and isnull(a.StmtCycId, 0) = isnull(@StmtCycId, 0)
		group by a.ProdCd, a.TermId, b.Descp
		return 0
	end

	select a.TxnCd, b.Descp, TermId, isnull(sum(a.Cnt), 0) 'Count', isnull(sum(a.Amt), 0) 'TxnAmt', isnull(sum(a.BillingAmt), 0) 'BillingAmt', isnull(sum(a.BillingPts), 0) 'BillingPts'
	from acq_MTDTxnCd a
	left outer join atx_TxnCode b on b.TxnCd = a.TxnCd and b.AcqNo = a.AcqNo
	where BusnLocation = @BusnLocation and isnull(a.StmtCycId, 0) = isnull(@StmtCycId, 0)
	group by a.TxnCd, a.TermId, b.Descp */

	if @SummType = 'P'
	begin
		select substring(a.PrcsDate,1,4) + '/' + substring(a.PrcsDate,5,2) 'PrcsDate', a.ProdCd, b.Descp, TermId, isnull(sum(a.Cnt), 0) 'Cnt', isnull(sum(a.Amt), 0) 'Amt', isnull(sum(a.BillingPts), 0) 'BillingPts'
		from acq_MTDProdCd a
		left outer join iss_Product b on b.ProdCd = a.ProdCd and b.IssNo = a.AcqNo 
		where a.BusnLocation = @BusnLocation
		group by a.PrcsDate, a.ProdCd, a.TermId, b.Descp
		return 0
	end

	select substring(a.PrcsDate,1,4) + '/' + substring(a.PrcsDate,5,2) 'PrcsDate', a.TxnCd, b.Descp, TermId, isnull(sum(a.Cnt), 0) 'Cnt', isnull(sum(a.Amt), 0) 'Amt', isnull(sum(a.BillingPts), 0) 'BillingPts'
	from acq_MTDTxnCd a
	left outer join atx_TxnCode b on b.TxnCd = a.TxnCd and b.AcqNo = a.AcqNo
	where BusnLocation = @BusnLocation
	group by a.PrcsDate, a.TxnCd, a.TermId, b.Descp
	return 0
end
GO
