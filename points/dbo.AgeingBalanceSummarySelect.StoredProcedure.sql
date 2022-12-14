USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AgeingBalanceSummarySelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Select Account's Ageing Summary

SP Level	: Primary
------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2002/07/07 Jacky		   Initial development
2017/04/18	Humairah		Remove encryption 
							Remove StmtCycId because the column did not exist in the current iac_AgeingBalance table 
******************************************************************************************************************/

CREATE	procedure [dbo].[AgeingBalanceSummarySelect]
	@IssNo uIssNo,
	@AcctNo uAcctNo,
	@StmtCycId int
as
begin
	declare @MTDAgeingInd int,
		@PrcsName varchar(50),
		@Msg nvarchar(80)

	select @PrcsName = 'AgeingBalanceSummarySelect'

	select @MTDAgeingInd = case when @StmtCycId = 0 then 0 else 1 end

	create table #tt (AgeingInd int identity(0,1), StmtCycId int)

	if @StmtCycId = 0
	begin
		insert #tt (StmtCycId) values (0)
	end
	--else																												2017/04/18	Humairah																										
	--begin
	--	-- Regenerate AgeingInd for past statement
	--	insert #tt (StmtCycId)
	--	select StmtCycId from iac_AccountStatement
	--	where AcctNo = @AcctNo and StmtCycId >= @StmtCycId order by StmtCycId											
	--	where AcctNo = @AcctNo order by StmtCycId
	--end

	select	sum(TotalAmt) 'TotalAmt', sum(TotalPts) 'TotalPts',
		sum(MTDCreditAmt) 'MTDCreditAmt', sum(MTDDebitAmt) 'MTDDebitAmt',
		sum(MTDCreditPts) 'MTDCreditPts', sum(MTDVoidCreditPts) 'MTDVoidCreditPts',
		sum(MTDDebitPts) 'MTDDebitPts', sum(MTDVoidDebitPts) 'MTDVoidDebitPts'
	from	(select	sum(Amt) 'TotalAmt',
			0 'TotalPts',
			sum(case when AgeingInd = @MTDAgeingInd then TotalCreditAmt else 0 end) 'MTDCreditAmt',
			sum(case when AgeingInd = @MTDAgeingInd then TotalDebitAmt else 0 end) 'MTDDebitAmt',
			0 'MTDCreditPts',
			0 'MTDVoidCreditPts',
			0 'MTDDebitPts',
			0 'MTDVoidDebitPts'
		from iac_AgeingBalance
		--where AcctNo = @AcctNo and StmtCycId = @StmtCycId																2017/04/18	Humairah
		where AcctNo = @AcctNo 
		group by AcctNo
		union
		select	0 'TotalAmt',
			sum(a.DebitPts+a.VoidDebitPts+a.CreditPts+a.VoidCreditPts) 'TotalPts',
			0 'MTDCreditAmt',
			0 'MTDDebitAmt',
			sum(case when b.AgeingInd = 0 then a.CreditPts else 0 end) 'MTDCreditPts',
			sum(case when b.AgeingInd = 0 then a.VoidCreditPts else 0 end) 'MTDVoidCreditPts',
			sum(case when b.AgeingInd = 0 then a.DebitPts else 0 end) 'MTDDebitPts',
			sum(case when b.AgeingInd = 0 then a.VoidDebitPts else 0 end) 'MTDVoidDebitPts'
		from iac_Points a, #tt b
		where a.AcctNo = @AcctNo and a.StmtCycId >= @StmtCycId
		and b.StmtCycId = a.StmtCycId) as a
end
GO
