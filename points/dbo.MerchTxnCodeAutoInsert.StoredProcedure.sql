USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchTxnCodeAutoInsert]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)-Acquiring Module

Objective	:Auto insertion on txn code for business location.

Called by	:BusnLocationApprovalInsert
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/05/29 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[MerchTxnCodeAutoInsert]
	@AcqNo uAcqNo,
	@BusnLocation uMerch

  as
begin
	declare @ActiveSts uDescp50, @SysDate datetime, @AcctNo uAcctNo
	select @SysDate = getdate()

	select @ActiveSts = RefCd from iss_RefLib where IssNo = @AcqNo and RefType = 'MerchAcctSts' and RefNo = 0

	select @AcctNo = AcctNo from aac_BusnLocation where BusnLocation = @BusnLocation and Sts = @ActiveSts

	if @@rowcount > 0 and @@error = 0
	begin
		if (select 1 from acq_TxnCodeMapping where BusnLocation = @BusnLocation) > 0 return 0

		select * into #TxnCodeMapping
		from acq_TxnCodeMapping
		where BusnLocation = -1


		update #TxnCodeMapping
		set AcqNo = @AcqNo, AcctNo = @AcctNo, BusnLocation = @BusnLocation, LastUpdDate = @SysDate

		insert acq_TxnCodeMapping
		( AcqNo, AcctNo, BusnLocation, MsgType, PrcsCd, TxnCd, UserId, LastUpdDate, Sts )
		select AcqNo, AcctNo, BusnLocation, MsgType, PrcsCd, TxnCd, system_user, LastUpdDate, Sts
		from #TxnCodeMapping
	end
	return 0
end
GO
