USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchTxnCodeDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:To delete existing txn code.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/07/02 Sam			   Initial development
*******************************************************************************/

CREATE procedure [dbo].[MerchTxnCodeDelete]
	@AcqNo uAcqNo,
	@TxnCd uTxnCd
  as
begin
	set nocount on

	if exists (select 1 from atx_OnlineTxn where TxnCd = @TxnCd)
		return 95000

	if exists (select 1 from atx_Txn where TxnCd = @TxnCd)
		return 95000

	delete atx_TxnCode
	where AcqNo = @AcqNo and TxnCd = @TxnCd

	if @@rowcount = 0 or @@error <> 0
		return 70017
	return 50012
end
GO
