USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ManualSettlementValidate]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:Cardtrend Systems Sdn. Bhd.
Modular		:Cardtrend Card Management System (CCMS)- Acquiring Module

Objective	:Manual batch settlement validation.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/07/18 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[ManualSettlementValidate]
	@AcqNo uAcqNo,
	@Ids uTxnId
  as
begin
	declare @SysDate datetime, @PrcsId uPrcsId

	set nocount on
	select @SysDate = getdate()

	select @PrcsId = CtrlNo
	from iss_Control
	where IssNo = @AcqNo and CtrlId = 'PrcsId'

	update a
	set a.Sts = b.RefCd, a.PrcsId = @PrcsId
	from atx_SourceSettlement a
	join iss_RefLib b on a.AcqNo = b.IssNo and b.RefType = 'MerchBatchSts' and b.RefNo = 1
	where Ids = @Ids

	if @@error <> 0 return 70226 --Failed to update Manual Batch

	update a 
	set a.Sts = c.RefCd, LastUpdDate = @SysDate
	from atx_SourceSettlement a
	join ( select SrcIds, count(*) 'Cnt', sum(amt) 'Amt'
		from atx_SourceTxn where SrcIds = @Ids
		group by SrcIds 
		) as b on a.Ids = b.SrcIds and a.Cnt = b.Cnt and a.Amt = b.Amt
	join iss_RefLib c on a.AcqNo = c.IssNo and c.RefType = 'MerchBatchSts' and RefNo = 0

	if @@error <> 0 return 70226 --Failed to update Manual Batch

	update a
	set a.Sts = b.Sts
	from atx_SourceTxn a
	join atx_SourceSettlement b on a.SrcIds = b.Ids and b.Ids = @Ids

	if @@error <> 0 return 70226 --Failed to update Manual Batch
	return 0
end
GO
