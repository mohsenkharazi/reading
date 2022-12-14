USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AdjustmentSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Search the merchant adjustment.
		It will be posted into atx_Settlement and atx_Txn respectively. 
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/07/12 Sam			   Initial development

*******************************************************************************/
CREATE procedure [dbo].[AdjustmentSelect]
	@BusnLocation uMerch
  as
begin
	select BatchId, Amt, SettleDate, TxnCd, a.Descp, UserId, LastUpdDate, BusnLocation, TxnInd
	from atx_SourceSettlement a
	/*left outer*/ join cmn_RefLib b on a.TxnInd = b.RefCd and b.RefType = 'TxnInd' and RefNo = 1
	where a.BusnLocation = @BusnLocation

	return 0
end
GO
