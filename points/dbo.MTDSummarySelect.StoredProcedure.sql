USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MTDSummarySelect]    Script Date: 9/6/2021 10:33:55 AM ******/
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

******************************************************************************************************************/

CREATE procedure [dbo].[MTDSummarySelect]
	@IssNo uIssNo,
	@AcctNo uAcctNo,
	@CycId int
  as
begin
	declare @rc int,
		@Amt money,
		@Pts money,
		@PrcsName varchar(50),
		@Msg nvarchar(80)

	select @PrcsName = 'MTDSummarySelect'

	create table #MTDBalance (
		Category nvarchar(50),
		CreditAmt money,
		DebitAmt money,
		CreditPts money,
		VoidCreditPts money,
		DebitPts money)

	exec @rc = MTDBalanceSelect @IssNo, @AcctNo, @CycId	-- Populate info into #MTDBalance

	if @@error <> 0
	begin
		return 95163	-- Error retrieving month-to-date balance
	end

	-- Retrieve total amount
	select @Amt = sum(Amt)
	from iac_AgeingBalance (nolock)
	where AcctNo = @AcctNo and StmtId = @CycId

	-- Retrieve total points
	select @Pts = sum(a.DebitPts+a.VoidDebitPts+a.CreditPts+a.VoidCreditPts)
	from iac_Points a (nolock)
	where a.AcctNo = @AcctNo and a.CycId >= @CycId

	select	/*@Amt 'TotalAmt', */@Pts 'TotalPts',
		--sum(CreditAmt) 'MTDCreditAmt', sum(DebitAmt) 'MTDDebitAmt',
		sum(CreditPts) 'MTDCreditPts', sum(VoidCreditPts) 'MTDVoidCreditPts',
		sum(DebitPts) 'MTDDebitPts', 0 'MTDVoidDebitPts'
	from #MTDBalance
end
GO
