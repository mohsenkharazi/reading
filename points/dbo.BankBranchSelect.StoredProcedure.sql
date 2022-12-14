USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BankBranchSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:To select bank branch in name sequence.

Called by	:

SP Level	:Primary

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/09/02 Sam			   Initial development

*******************************************************************************/
CREATE procedure [dbo].[BankBranchSelect]
	@IssNo uIssNo
   as
begin
	--select RefCd 'BranchCd', substring(Descp,5,44) + ' (' + convert(varchar(6), RefCd) + ')' 'Descp' from iss_RefLib
	select RefCd 'BranchCd', Descp + ' (' + convert(varchar(6), RefCd) + ')' 'Descp' from iss_RefLib
	where IssNo = @IssNo and RefType = 'KTBBranchCd'
	order by Descp
	return 0
end
GO
