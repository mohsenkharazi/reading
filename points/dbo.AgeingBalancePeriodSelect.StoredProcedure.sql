USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AgeingBalancePeriodSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Select Account's Ageing balances by period

SP Level	: Primary
------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2002/07/10 Jacky		   Initial development

******************************************************************************************************************/

CREATE procedure [dbo].[AgeingBalancePeriodSelect]
	@IssNo uIssNo,
	@AcctNo uAcctNo,
	@StmtId int,
	@AgeingInd smallint
  as
begin
	declare @PrcsName varchar(50),
		@Msg nvarchar(80)

	select @PrcsName = 'AgeingBalancePeriodSelect'

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

--select * from #tt
--select * from iacv_pointsageing	
/*select a.Category, 0 'Amt', a.Pts
from iacv_PointsAgeing a, #tt b
where a.AcctNo = @AcctNo and a.StmtCycId <= case when @StmtCycId = 0 then 99999999 else @StmtCycId end and a.Pts <> 0
and b.StmtCycId = a.StmtCycId and a.AgeingInd = @AgeingInd*/
	select b.Descp 'Category', sum(a.Pts) 'Pts Bal', sum(a.Amt) 'Acct Bal'
	from	(select a.Category, a.Amt, 0 'Pts'
		from iac_AgeingBalance a
		where a.AcctNo = @AcctNo and a.CycId = @StmtId
		and a.AgeingInd = @AgeingInd and a.Amt <> 0
		union
		select a.Category, 0 'Amt', a.Pts
		from iacv_PointsAgeing a, #tt b
		where a.AcctNo = @AcctNo and/* b.StmtCycId = @StmtCycId and*/ a.Pts <> 0
		and b.StmtId = a.CycId and b.AgeingInd = @AgeingInd)
	as a, itx_TxnCategory b
	where b.IssNo = @IssNo and b.Category = a.Category
	group by b.Descp
	order by b.Category
end
GO
