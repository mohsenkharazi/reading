USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MembershipRankingMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	: CarDtrend Systems Sdn. Bhd.
Modular		: CarDtrend Card Management System (CCMS)- Issuing Module

Objective	: To insert new or update existing membership ranking details.

SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/04/24 Wendy		   Initial development
2004/07/08 Chew Pei			Change to standard coding
*******************************************************************************/
	
CREATE procedure [dbo].[MembershipRankingMaint]
	@Func varchar(5),
	@IssNo uIssNo,
	@RankId tinyint,
	@Descp nvarchar(30),
	@PtsToAchieve int
  as
begin
	if @Func = 'Add'	
	begin
		if exists (select 1 from iss_MembershipRanking
		where IssNo = @IssNo and RankId = @RankId)
			return 65034	-- Membership Ranking already exists

		insert iss_MembershipRanking (IssNo, RankId, Descp, PtsToAchieve)
		values (@IssNo, @RankId, @Descp, @PtsToAchieve) 

		if @@error <> 0 return 70328	-- Failed to create Membership Ranking

		return 50228	-- Membership Ranking has been created successfully
	end 
	if @Func = 'Save'
	begin
		if not exists (select 1 from iss_MembershipRanking
		where IssNo = @IssNo and RankId = @RankId)
			return 60051	-- Membership Ranking not found

		update iss_MembershipRanking set	
			Descp=@Descp, 
			PtsToAchieve=@PtsToAchieve 
		where IssNo = @IssNo and RankId = @RankId

		if @@error <> 0 return 70329	-- Failed to update Membership Ranking

		return 50229	-- Membership Ranking has been updated successfully
	end
end
GO
