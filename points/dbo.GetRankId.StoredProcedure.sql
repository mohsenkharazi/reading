USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GetRankId]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/*****************************************************************

Copyright	: CardTrend Systems Sdn Bhd 
Project		: CardTrend Card Management System Acquirer
Description	: To get the membership ranking
		  (User Definition Functions)

When	   Who		CRN	   Where
------------------------------------------------------------------
2002/04/11 Jacky		   Initial development
******************************************************************/

CREATE procedure [dbo].[GetRankId]
	@AcctNo uAcctNo,
	@RankId tinyint output
  as
begin
--	declare @RankId tinyint

	select top 1 @RankId = RankId
	from (select RankId, Descp from iac_Account a, iss_MembershipRanking b
		where a.AcctNo = @AcctNo and b.IssNo = a.IssNo
		and b.PtsToAchieve <= a.RankingPts) as a
	order by RankId desc

	return @RankId
end
GO
