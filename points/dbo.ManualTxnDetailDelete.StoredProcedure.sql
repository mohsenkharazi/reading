USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ManualTxnDetailDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Deletion of manual transaction detail.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/21 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[ManualTxnDetailDelete]
	@AcqNo uAcqNo,
	@BatchId uBatchId,
	@SrcIds uTxnId
  as
begin
	set nocount on

	delete atx_SourceTxnDetail
	where BatchId = @BatchId and SrcIds = @SrcIds
	if @@error <> 0 return 70232 --Failed to update Manual Txn Detail
	return 50192 --Manual Txn Detail has been deleted successfully
end
GO
