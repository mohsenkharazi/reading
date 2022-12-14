USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ContactTypeDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Contact Type Code deletion.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/01/23 Wendy		   Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[ContactTypeDelete]
	@IssNo  uIssNo,
	@ContactTypeCd uRefCd,
	@Descp uDescp50 
   as
begin

	if @Descp is null return 55017
	if @ContactTypeCd is null return 55089

	
	delete iss_RefLib
	where IssNo = @IssNo and RefCd = @ContactTypeCd and RefType = 'Contact'

	
	if @@rowcount = 0
	begin
		return 70122
	end
	else return 50086
end
GO
