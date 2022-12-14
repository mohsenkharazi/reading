USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AgeingBalanceMTDSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Select Account's MTD debit/credit info

SP Level	: Primary
------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2002/01/07	Jacky			Initial development
2017/04/18	Humairah		Remove encryption 
							Remove StmtCycId because the column did not exist in the current table 
******************************************************************************************************************/

CREATE	procedure [dbo].[AgeingBalanceMTDSelect]
	@IssNo uIssNo,
	@AcctNo uAcctNo,
	@StmtCycId int
as
begin
	declare @MTDAgeingInd smallint,
		@PrcsName varchar(50),
		@Msg nvarchar(80)

	select @PrcsName = 'AgeingBalanceMTDSelect'

	select @MTDAgeingInd = case when @StmtCycId = 0 then 0 else 1 end

	select	b.Descp 'Category', sum(CreditAmt) 'Credit Amount', sum(DebitAmt) 'Debit Amount',
		sum(CreditPts) 'Credit Points', sum(VoidCreditPts) 'Void Credit Points',
		sum(DebitPts) 'Debit Points'--, sum(VoidDebitPts) 'VoidDebitPts'
	from	(select	Category,
			TotalCreditAmt 'CreditAmt',
			TotalDebitAmt 'DebitAmt',
			0 'CreditPts',
			0 'VoidCreditPts',
			0 'DebitPts',
			0 'VoidDebitPts'
		from iac_AgeingBalance
		--where AcctNo = @AcctNo and StmtCycId = @StmtCycId and AgeingInd = @MTDAgeingInd									--2017/04/18	Humairah   
		where AcctNo = @AcctNo and AgeingInd = @MTDAgeingInd
		union
		select	Category,
			0 'CreditAmt',
			0 'DebitAmt',
			a.CreditPts,
			a.VoidCreditPts,
			a.DebitPts,
			a.VoidDebitPts
		from iac_Points a
		--where a.AcctNo = @AcctNo and a.StmtCycId = @StmtCycId) as a, itx_TxnCategory b								--2017/04/18	Humairah   
		where a.AcctNo = @AcctNo ) as a, itx_TxnCategory b
	where b.IssNo = @IssNo and b.Category = a.Category
	group by b.Descp, b.Priority
	order by b.Priority
end
GO
