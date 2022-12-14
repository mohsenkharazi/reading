USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[EDCInvoiceNoMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:This is to update the InvoiceNo for batch settlement of EDC
		 in order to proceed and success the EDC settlement process.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2003/01/15 Sam			   Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[EDCInvoiceNoMaint]
	@AcqNo uAcqNo,
	@TermId uTermId,
	@InvoiceNo uBatchId
  as
begin
	declare @BatchId uBatchId

	select @BatchId = LastBatchId from atm_TerminalInventory where AcqNo = @AcqNo and TermId = @TermId and Sts <> 'T'

	if @@error <> 0 return 95219

	if isnull(@BatchId, 0) = isnull(@InvoiceNo, 0) return 95220 --Entered Invoice No same as the last Invoice No
		
	update atm_TerminalInventory
	set LastBatchId = isnull(@InvoiceNo, 0)
	where TermId = @TermId

	if @@rowcount > 0 and @@error = 0 return 50277 --Settlement Invoice No has been updated successfully
	return 70411 --Failed to update Settlement Invoice No

end
GO
