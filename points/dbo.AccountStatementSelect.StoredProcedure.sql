USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AccountStatementSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Select Statement info

SP Level	: Primary
------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2002/01/07 Jacky		   Initial development

******************************************************************************************************************/

CREATE procedure [dbo].[AccountStatementSelect]
	@AcctNo uAcctNo,
	@StmtId int
  as
begin
	declare @PrcsName varchar(50),
		@Msg nvarchar(80)

	select @PrcsName = 'AccountStatementSelect'

	if @StmtId = 0
	begin
		if exists (select 1 from iac_AccountStatement where AcctNo = @AcctNo)
		begin
			select	a.ClsBal 'OpnBal', b.AccumAgeingAmt 'ClsBal',
				a.ClsPts 'OpnPts', b.AccumAgeingPts 'ClsPts', null 'MinRepaymt', null 'DueDate'
			from iac_AccountStatement a, iac_AccountFinInfo b
			where a.AcctNo = @AcctNo and a.StmtId = isnull((select max(StmtId)
									from iac_AccountStatement
									where AcctNo = @AcctNo), 0)
			and b.AcctNo = a.AcctNo
		end
		else
		begin
			select	cast(0 as money) 'OpnBal', AccumAgeingAmt 'ClsBal', cast(0 as money) 'OpnPts', AccumAgeingPts 'ClsPts',
				null 'MinRepaymt', null 'DueDate'
			from iac_AccountFinInfo
			where AcctNo = @AcctNo
		end
	end
	else
	begin
		select OpnBal, ClsBal, OpnPts, ClsPts, MinRepaymt, DueDate
		from iac_AccountStatement
		where AcctNo = @AcctNo and StmtId = @StmtId
	end

end
GO
