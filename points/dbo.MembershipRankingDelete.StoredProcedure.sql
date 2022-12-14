USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MembershipRankingDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	: CarDtrend Systems Sdn. Bhd.
Modular		: CarDtrend Card Management System (CCMS)- Issuing Module

Objective	: To delete existing membership ranking records.

SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/04/24 Wendy		   Initial development


*******************************************************************************/
	
CREATE procedure [dbo].[MembershipRankingDelete]
	@IssNo uIssNo,
	@RankId tinyint
  as
begin
	delete from iss_MembershipRanking
	where RankId=@RankId and IssNo = @IssNo

--	return 50073	-- Successfully deleted
end
GO
