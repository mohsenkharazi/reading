USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchGLTxnCodeDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)

Objective	:Delete Merchant GL Txn Code

-------------------------------------------------------------------------------
When		Who		CRN	Description
-------------------------------------------------------------------------------
2005/10/27	Alex			Initial Development
*******************************************************************************/

CREATE procedure [dbo].[MerchGLTxnCodeDelete]
	@AcqNo uAcqNo,
	@GLAcctNo varchar(11),
	@TxnCd uTxnCd,
	@TxnType varchar(10)
  as
begin

--	if exists(select 1 from udiE_GLTxn where AcctTxnCd = @GLAcctNo)
--		return 95329-- Unable to delete GL Code because data is being used

	----------------- 
	Begin Transaction
	-----------------
	delete acq_GLCode
	where TxnCd = @TxnCd and GLAcctNo = @GLAcctNo and TxnType = @TxnType and AcqNo = @AcqNo

	if @@error <> 0
	begin
		--------------------
		Rollback Transaction
		--------------------
		return 70911 -- Failed to delete GL Code
	end	
	------------------
	Commit Transaction
	------------------
	return 50341 -- GL Code has been deleted successfully

end
GO
