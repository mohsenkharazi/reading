USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ManualSettlementDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Manual batch settlement deletion.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/24 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[ManualSettlementDelete]
	@AcqNo uAcqNo,
	@Ids uTxnId
  as
begin
	declare @BatchId uBatchId

	----------
	begin tran
	----------
	delete atx_SourceSettlement
	where AcqNo = @AcqNo and Ids = @Ids

	if @@rowcount = 0 or @@error <> 0
	begin
		rollback tran
		return 70227
	end
	
	delete atx_SourceTxn
	where SrcIds = @Ids

	if @@error <> 0
	begin
		rollback tran
		return 70227
	end

	delete atx_SourceTxnDetail
	where ParentIds = @Ids

	if @@error <> 0
	begin
		rollback tran
		return 70227
	end

	commit tran
	return 50186
end
GO
