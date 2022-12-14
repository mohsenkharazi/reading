USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AgeingBalancePeriodSelectPoints]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Select Account's points balances by period

SP Level	: Primary
------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2002/07/10 Jacky		   Initial development

******************************************************************************************************************/

CREATE procedure [dbo].[AgeingBalancePeriodSelectPoints]
	@IssNo uIssNo,
	@AcctNo uAcctNo,
	@StmtCycId int,
	@AgeingInd smallint
  as
begin
	declare @PrcsName varchar(50),
		@Msg nvarchar(80)

	select @PrcsName = 'AgeingBalancePeriodSelectPoints'

	select b.Descp 'Category', a.Pts 'Points'
	from iacv_PointsAgeing a
	join itx_TxnCategory b on b.IssNo = @IssNo and b.Category = a.Category
	where a.AcctNo = @AcctNo and a.AgeingInd = @AgeingInd
	and a.Pts <> 0
	order by a.Category
end
GO
