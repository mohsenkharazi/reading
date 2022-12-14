USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ManualSettlementSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Select the manual settlement info.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/24 Sam			   Initial development
2009/12/18 Barnett			Add nolock
*******************************************************************************/

CREATE procedure [dbo].[ManualSettlementSelect]
	@Ids int,
	@BusnLocation uMerch
  as
begin
	declare @CtrlCnt smallint, @CtrlAmt money

	select @CtrlCnt = 0, @CtrlAmt = 0
	select @CtrlCnt = count(*), @CtrlAmt = sum(Amt)
	from atx_SourceTxn (nolock)
	where SrcIds = isnull(@Ids, -1)

	select Ids, BatchId, TermId, BusnLocation 'MerchantNo', isnull(OrigBatchNo, BatchId) 'OrigBatchNo', TxnCd, SettleDate, Cnt, Amt, Sts, @CtrlCnt 'CtrlCnt', @CtrlAmt 'CtrlAmt'
	from atx_SourceSettlement (nolock)
	where Ids = isnull(@Ids, -1)-- (Jacky 2002 Nov 30 PrcsId should have value) and isnull(PrcsId, 0) = 0
	return 0
end
GO
