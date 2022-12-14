USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ManualTxnSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Manual transaction select.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/21 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[ManualTxnSelect]
	@Ids uTxnId,
	@SrcIds int
  as
begin
	set nocount on

	select a.BatchId, b.CardNo, b.CardExpiry, b.AuthCardNo, b.AuthCardExpiry, 
		b.TxnDate, b.Amt, b.Odometer, b.Ids, b.AuthNo, b.InvoiceNo, 
		b.BillingPts, b.Descp, c.BillMethod, a.TxnCd
	from atx_SourceSettlement a
	left outer join atx_SourceTxn b on a.Ids = b.SrcIds and b.Ids = @Ids
	left outer join atx_TxnCode c on a.AcqNo = c.AcqNo and a.TxnCd = c.TxnCd
	join iss_RefLib d on a.AcqNo = d.IssNo and a.InputSrc = d.RefCd and d.RefType = 'MerchInputSrc' and d.RefNo = 1
	where a.Ids = @SrcIds

	return 0
end
GO
