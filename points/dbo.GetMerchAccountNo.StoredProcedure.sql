USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GetMerchAccountNo]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)-Acquiring Module

Objective	:Generate account number.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/03 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[GetMerchAccountNo]
	@AcqNo uAcqNo,
	@AcctNo uAcctNo output
  as
begin
	declare @Error int, @Rowcount int

	set nocount on

	select @AcctNo = isnull(LastAcctNo, 0)
	from acq_Acquirer
	where AcqNo = @AcqNo

	if @@error <> 0 return 70330	-- Failed to create new Control

	while 1 = 1
	begin
		update acq_Acquirer
		set LastAcctNo = @AcctNo + 1
		where AcqNo = @AcqNo

		if @@error = 0
		begin
			if exists (select 1 from acq_Acquirer where LastAcctNo = @AcctNo + 1)
				return 0
		end

		select @AcctNo = isnull(LastAcctNo, 0)
		from acq_Acquirer
		where AcqNo = @AcqNo

		if @@error <> 0 break
	end
	return 0
end
GO
