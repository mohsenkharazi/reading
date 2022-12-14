USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GLTxnCodeDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)

Objective	:Delete GL Txn Code

-------------------------------------------------------------------------------
When		Who		CRN	Description
-------------------------------------------------------------------------------
2005/10/05	Alex			Initial Development
2005/11/19	Chew Pei		Added TxnCd and TxnType validation on udie_GLTxn
*******************************************************************************/

CREATE procedure [dbo].[GLTxnCodeDelete]
	@AcctTxnCd varchar(15),
	@TxnCd uTxnCd,
	@TxnType varchar(10)
  as
begin

--	if exists(select 1 from udiE_GLTxn where TxnCd = @TxnCd and AcctTxnCd = @AcctTxnCd and TxnType = @TxnType )
--		return 95329-- Unable to delete GL Code because data is being used

	----------------- 
	Begin Transaction
	-----------------
	delete iss_GLCode
	where TxnCd = @TxnCd and AcctTxnCd = @AcctTxnCd and TxnType = @TxnType

	if @@error <> 0
	begin
		--------------------
		Rollback Transaction
		--------------------
		return 70908 -- Failed to delete GL Code
	end	
	------------------
	Commit Transaction
	------------------
	return 50341 -- GL Code has been deleted successfully
	
end
GO
