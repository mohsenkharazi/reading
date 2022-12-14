USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[OccupationDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Job deletion.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/01/23 Wendy		   Initial development

*******************************************************************************/

CREATE procedure [dbo].[OccupationDelete]
	@IssNo uIssNo,
	@OccupationCd uRefCd,
	@Descp uDescp50
  as
begin

	if @Descp is null return 55017
	if @OccupationCd is null return 55087
	
	delete iss_RefLib
	where IssNo = @IssNo and RefCd = @OccupationCd and RefType = 'Occupation'
	
	if @@rowcount = 0
	begin
		return 70116
	end
	
	return 50089
end
GO
