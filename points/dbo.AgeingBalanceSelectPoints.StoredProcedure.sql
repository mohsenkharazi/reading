USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AgeingBalanceSelectPoints]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Select Account's Ageing balances for Points

SP Level	: Primary
------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2002/01/04 Jacky		   Initial development
2009/06/30 Barnett		   Add Nolock to the select Statement
******************************************************************************************************************/

CREATE procedure [dbo].[AgeingBalanceSelectPoints]
	@AcctNo uAcctNo,
	@CycId int
  as
begin
	declare @PrcsName varchar(50),
		@Msg nvarchar(80),
		@MaxAgeingInd int

	select @PrcsName = 'AgeingBalanceSelectPoints'

/*	select isnull(convert(char(11), c.StmtDate, 105), 'Current') 'Bal as of', sum(a.Pts) 'Points', a.AgeingInd
	from iacv_PointsAgeing a
	join iac_Account b on b.AcctNo = @AcctNo
	left outer join iac_StatementCycle c on c.IssNo = b.IssNo and c.StmtId = a.CycId
	where a.AcctNo = @AcctNo and a.CycId <= case when @CycId = 0 then 99999999 else @CycId end
	and (a.CycId > 0 or (a.CycId = 0 and @CycId = 0))
	group by a.CycId, isnull(convert(char(11), c.StmtDate, 105), 'Current'), a.AgeingInd
	order by a.CycId
*/
	select isnull(convert(char(11), c.CycDate, 105), 'Current') 'Bal as of', sum(a.Pts) 'Points', a.AgeingInd
	from iacv_PointsAgeing a (nolock)
	join iac_Account b (nolock) on b.AcctNo = @AcctNo
	left outer join iac_AgeingCycle c (nolock) on c.IssNo = b.IssNo and c.CycId = a.CycId
	where a.AcctNo = @AcctNo and a.CycId <= case when @CycId = 0 then 99999999 else @CycId end
	and (a.CycId > 0 or (a.CycId = 0 and @CycId = 0))
	group by a.CycId, isnull(convert(char(11), c.CycDate, 105), 'Current'), a.AgeingInd
	order by a.CycId
	
end
GO
