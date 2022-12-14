USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AdjustmentDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Adjustment transaction deletion.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/07/12 Sam			   Initial development

*******************************************************************************/

CREATE  procedure [dbo].[AdjustmentDelete]
	@TxnId uTxnId
  as
begin
	set nocount on
	----------
	BEGIN TRAN
	----------
	delete atx_SourceSettlement
	where BatchId = @TxnId
	if @@rowcount = 0 or @@error <> 0 
	begin
		rollback tran
		return 70255 --Failed to delete Adjustment
	end

	delete atx_SourceTxn
	where BatchId = @TxnId
	if @@rowcount = 0 or @@error <> 0
	begin
		rollback tran
		return 70255
	end
	commit tran
	return 50213 --Adjustment has been deleted successfully
end
GO
