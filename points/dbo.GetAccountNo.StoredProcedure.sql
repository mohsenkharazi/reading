USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GetAccountNo]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*****************************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)
Objective	:Generate Account Number.
------------------------------------------------------------------------------------------
When	   	Who		CRN	Description
------------------------------------------------------------------------------------------
2005/09/19 	Chew Pei	Initial development.

*****************************************************************************************/

CREATE procedure [dbo].[GetAccountNo]
	@IssNo uIssNo,
	@CardLogo uCardLogo,
	@AcctNo bigint output
  as
begin
	set nocount on

	-- Retreive the account sequence number
	select @AcctNo = AcctSeq
	from iss_CardLogo (nolock)
	where IssNo = @IssNo and CardLogo = @CardLogo

	if @@error <> 0 or isnull(@AcctNo,0) = 0 return 60005 --Card Logo not found

	-----------------
	BEGIN TRANSACTION
	-----------------

	update iss_CardLogo
	set AcctSeq = @AcctNo + 1
	where IssNo = @IssNo and CardLogo = @CardLogo

	if @@error <> 0
	begin
		rollback transaction
		return 70000	-- Failed to create user account number
	end

	------------------
	COMMIT TRANSACTION
	------------------
	return 0
end
GO
