USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ApplicationShareholderDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	:Delete application shareholder info.

-------------------------------------------------------------------------------
When		Who		CRN	Description
-------------------------------------------------------------------------------
2003/07/03 	KY		1103003	Initial development

*******************************************************************************/

CREATE procedure [dbo].[ApplicationShareholderDelete]
	@IssNo uIssNo,
	@ApplId uApplId,
	@Id uApplId
  as
begin
	if isnull(@IssNo,0) = 0
	return 0	--Mandatory Field IssNo

	if isnull(@ApplId,'') = ''
	return 0	--Mandatory Field ApplId

	if not exists (select 1 from iaa_Shareholder where IssNo = @IssNo and ApplId = @ApplId and Id = @Id)
	return 60072 -- Shareholder not found
	
	-----------------
	begin transaction
	-----------------
	delete iaa_Shareholder
	where IssNo = @IssNo and ApplId = @ApplId and Id = @Id
	
	if @@error <> 0	
	begin
		rollback transaction
			return 70432 -- Failed to delete Shareholder
	end
	------------------
	commit transaction
	------------------
	return 50297 -- Shareholder has been deleted successfully
end
GO
