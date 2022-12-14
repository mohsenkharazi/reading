USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ManualTxnDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Delete manual transaction.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/22 Sam			   Initial development
2004/12/01 Chew Pei			Add AcqNo as pass-in param
*******************************************************************************/

CREATE procedure [dbo].[ManualTxnDelete]
	@AcqNo uAcqNo,
--	@BatchId uBatchId,
	@Ids uTxnId
--	@BusnLocation uMerchNo
  as
begin
	declare @rc int,
		@SrcIds uTxnId

	select @SrcIds = SrcIds
	from atx_SourceTxn
	where Ids = @Ids

	------------------
	BEGIN TRANSACTION
	-----------------

	delete atx_SourceTxn
	where Ids = @Ids
	if @@rowcount = 0 or @@error <> 0
	begin
		rollback transaction
		return 70230
	end

	delete atx_SourceTxnDetail where Ids = @Ids

	if @@error <> 0
	begin
		rollback transaction
		return 70230
	end

	exec @rc = ManualSettlementValidate @AcqNo, @SrcIds -- Added @AcqNo on 20041201 by CP

	if @@error <> 0 or @rc <> 0
	begin
		rollback transaction
		return 70226 --Failed to update Manual Batch
	end

	-------------------
	COMMIT TRANSACTION
	-------------------

	return 50189
end
GO
