USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ApplicationBankAcctDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	:Delete application bank account info.

-------------------------------------------------------------------------------
When		Who		CRN	Description
-------------------------------------------------------------------------------
2003/06/17 	KY		1103003	Initial development

*******************************************************************************/

CREATE procedure [dbo].[ApplicationBankAcctDelete]
	@IssNo uIssNo,
	@ApplId uApplId,
	@Id uApplId
  as
begin
	if isnull(@IssNo,0) = 0
	return 0	--Mandatory Field IssNo

	if isnull(@ApplId,'') = ''
	return 0	--Mandatory Field ApplId
	
	if not exists (select 1 from iaa_BankAccount where IssNo = @IssNo and ApplId = @ApplId and Id = @Id)
	return 60073 -- Bank Account Number not found

	-----------------
	begin transaction
	-----------------
	delete iaa_BankAccount
	where IssNo = @IssNo and ApplId = @ApplId and Id = @Id
	
	if @@error <> 0	
	begin
		rollback transaction
		return 70435 -- Failed to delete Bank Account
	end
	------------------
	commit transaction
	------------------

	return 50300 -- Bank Account has been deleted successfully

end
GO
