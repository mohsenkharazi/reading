USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BankDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Bank code deletion.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/05/16 Jac			   Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[BankDelete]
	@IssNo smallint,
	@BankCd uRefCd
   as
begin
	if @BankCd is null return 55065

	if exists (select 1 from iss_PlasticType where IssNo = @IssNo and BankName = @BankCd)
		return 95000

	if exists (select 1 from iac_Entity where IssNo = @IssNo and BankName = @BankCd)
		return 95000

	delete iss_RefLib
	where IssNo = @IssNo and RefType = 'Bank' and RefCd = @BankCd

	if @@rowcount = 0
	begin
		return 70184
	end
	return 50165
end
GO
