USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchUnpostedOnlineSettlementSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	: Cardtrend Systems Sdn. Bhd.
Modular		: Cardtrend Card Management System (CCMS)- Acquiring Module

Objective	: To select the unposted online settlement transactions 
		  for further rectification

SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/12/10 Sam		           Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[MerchUnpostedOnlineSettlementSelect]
	@AcqNo uAcqNo,
	@Ids uTxnId
  as
begin
	set nocount on

	select a.BusnLocation, a.TermId, a.BatchId, a.SettleDate, a.Cnt, 
		a.Amt, a.Pts, a.TxnInd, b.Descp 'StsDescp', a.Sts, a.Ids, a.PrcsId
	from atx_SourceSettlement a
	left outer join iss_RefLib b on a.AcqNo = b.IssNo and a.Sts = b.RefCd and b.RefType = 'TxnSts'
	where a.Ids = @Ids and a.AcqNo = @AcqNo and a.InputSrc = 'EDC'
	return 0
end
GO
