USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BatchSettlementSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:TxnSettlementSelect
		
		To select transactions belongs to batch id.

Called by	:

SP Level	:Primary

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/17 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[BatchSettlementSelect]
	@BatchId uBatchId,
	@Ids uTxnId
   as
begin
	select TxnCd, BusnLocation, BatchId, OrigBatchNo, TermId, Qty, Amt, 
		SrvcFee, BillingAmt, convert(char(10), SettleDate, 103) 'SettleDate', 
		Stan, Ids, ChequeNo, ChequeDate, Descp, CrryCd, CtryCd, PrcsId, 
		LastUpdDate 'PrcsDate', CycId, UserId, Sts
	from atx_Settlement where BatchId = @BatchId
	return 0
end
GO
