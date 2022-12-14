USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MTDBalanceSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Select Account's MTD debit/credit info

SP Level	: Secondary
------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2002/10/07 Jacky		   Initial development

******************************************************************************************************************/

CREATE procedure [dbo].[MTDBalanceSelect]
	@IssNo uIssNo,
	@AcctNo uAcctNo,
	@CycId int
  as
begin
	declare @MTDAgeingInd smallint,
		@PrcsName varchar(50),
		@Msg nvarchar(80)

	select @PrcsName = 'MTDBalanceSelect'

	select @MTDAgeingInd = case when @CycId = 0 then 0 else 1 end

	insert #MTDBalance (Category, CreditAmt, DebitAmt, CreditPts, VoidCreditPts, DebitPts)
	select	b.Descp 'Category', sum(CreditAmt) 'CreditAmt', sum(DebitAmt) 'DebitAmt',
		sum(CreditPts) 'CreditPts', sum(VoidCreditPts) 'VoidCreditPts',
		sum(DebitPts) 'DebitPts'--, sum(VoidDebitPts) 'VoidDebitPts'
	from	(select	Category,
			TotalCreditAmt 'CreditAmt',
			TotalDebitAmt 'DebitAmt',
			0 'CreditPts',
			0 'VoidCreditPts',
			0 'DebitPts',
			0 'VoidDebitPts'
		from iac_AgeingBalance (nolock)
		where AcctNo = @AcctNo and StmtId = @CycId and AgeingInd = @MTDAgeingInd
		union
		select	Category,
			0 'CreditAmt',
			0 'DebitAmt',
			a.CreditPts,
			a.VoidCreditPts,
			a.DebitPts,
			a.VoidDebitPts
		from iac_Points a (nolock)
		--where a.AcctNo = @AcctNo and a.CycId = @CycId) as a, itx_TxnCategory b
		where a.AcctNo = @AcctNo and a.CycId <= case when @CycId = 0 then 99999999 else @CycId end
			and (a.CycId > 0 or (a.CycId = 0 and @CycId = 0)) ) as a, itx_TxnCategory b
	where b.IssNo = @IssNo and b.Category = a.Category
	group by b.Descp, b.Priority
	order by b.Priority

end
GO
