USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MTDDetailSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
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
2002/10/07 Jacky		   Initial development

******************************************************************************************************************/

CREATE procedure [dbo].[MTDDetailSelect]
	@IssNo uIssNo,
	@AcctNo uAcctNo,
	@CycId int
  as
begin
	declare @rc int,
		@PrcsName varchar(50),
		@Msg nvarchar(80)

	select @PrcsName = 'MTDDetailSelect'

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

	select	Category, --CreditAmt 'Credit Amount', DebitAmt 'Debit Amount',
		CreditPts 'Credit Points', VoidCreditPts 'Void Credit Points',
		DebitPts 'Debit Points'
	from #MTDBalance
	where CreditAmt <> 0 or DebitAmt <> 0 or CreditPts <> 0
	or VoidCreditPts <> 0 or DebitPts <> 0
end
GO
