USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AgeingBalanceSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Select Account's Ageing balances

SP Level	: Primary
------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2002/01/04 Jacky		   Initial development

******************************************************************************************************************/

CREATE procedure [dbo].[AgeingBalanceSelect]
	@AcctNo uAcctNo,
	@StmtId int
  as
begin
	declare @PrcsName varchar(50),
		@Msg nvarchar(80),
		@MaxAgeingInd int

	select @PrcsName = 'AgeingBalanceSelect'

	create table #tt (AgeingInd int identity(0,1), StmtId int)

	if @StmtId = 0
	begin
		insert #tt (StmtId) values (0)
		insert #tt (StmtId)
		select StmtId from iac_AccountStatement
		where AcctNo = @AcctNo order by StmtId desc
	end
	else
	begin
		-- Regenerate AgeingInd for past statement
		insert #tt (StmtId) values (0)
		insert #tt (StmtId)
		select StmtId
		from iac_AccountStatement
		where AcctNo = @AcctNo and StmtId <= @StmtId order by StmtId desc
	end

/*select * from #tt
select * from iacv_pointsageing
select b.AgeingInd, 0 'AcctBal', sum(a.Pts) 'PtsBal'
from iacv_PointsAgeing a, #tt b
where a.AcctNo = @AcctNo and a.StmtCycId <= case when @StmtCycId = 0 then 99999999 else @StmtCycId end
and b.StmtCycId = a.StmtCycId
group by b.AgeingInd*/
	select	c.Descp 'Ageing', sum(a.PtsBal) 'Pts Bal', a.AgeingInd--, sum(a.AcctBal) 'Acct Bal', a.AgeingInd
	from	(select a.AgeingInd, sum(a.Amt) 'AcctBal', 0 'PtsBal'
		from iac_AgeingBalance a
		where a.AcctNo = @AcctNo and a.StmtId = @StmtId
		group by a.AgeingInd
		having sum(a.Amt) <> 0
		union
		select b.AgeingInd, 0 'AcctBal', sum(a.Pts) 'PtsBal'
		from iacv_PointsAgeing a, #tt b
		where a.AcctNo = @AcctNo and a.CycId <= case when @StmtId = 0 then 99999999 else @StmtId end
		and b.StmtId = a.CycId
		group by b.AgeingInd) as a, iac_Account b, iss_PlasticTypeDelinquency c
	where b.AcctNo = @AcctNo and c.IssNo = b.IssNo and c.CardLogo = b.CardLogo
	and c.PlasticType = b.PlasticType and c.AgeingInd = a.AgeingInd
	group by a.AgeingInd, c.Descp
	order by a.AgeingInd
	

end
GO
