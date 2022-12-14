USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchUnpostedOnlineTxnSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	: Cardtrend Systems Sdn. Bhd.
Modular		: Cardtrend Card Management System (CCMS)- Acquiring Module

Objective	: Select unposted online transactions for further rectification
SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/12/10 Sam		           Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[MerchUnpostedOnlineTxnSelect]
	@Ids uTxnId
  as
begin
	set nocount on

	select TxnCd, LocalDate, LocalTime, ArrayCnt, Qty, Amt, InvoiceNo, DriverCd, Ids, SrcIds, BusnName, c.Descp 'Sts'
	from atx_SourceTxn a
	join aac_BusnLocation b on a.BusnLocation = b.BusnLocation
	join iss_RefLib c on a.Sts = c.RefCd and c.RefType = 'TxnSts'
	where a.SrcIds = @Ids
	return 0
end
GO
