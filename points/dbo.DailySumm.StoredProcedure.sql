USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[DailySumm]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	:Generate count on Cards,Account and Transactions 
-------------------------------------------------------------------------------
When	   Who		CRN			Description
-------------------------------------------------------------------------------
2014/09/18 Syazani				Initial development
*******************************************************************************/
--EXEC DailySumm 1
CREATE procedure [dbo].[DailySumm]
	@IssNo uIssNo,
	@Date datetime = NULL,
	@FromDate datetime = NULL,
	@ToDate datetime = NULL
as
begin
set nocount on
declare 
	@CurDate datetime,
	@DateFrom datetime,
	@DateTo datetime
	
	if isnull(@Date,'') = ''
	begin
		set @CurDate = {fn curdate()} 
	end
	else
	begin
		set @CurDate = @Date
	end
	
	if isnull(@FromDate,'') = ''
	begin
		set @DateFrom = dateadd(dd,-1,{fn curdate()})
	end
	else
	begin
		set @DateFrom = @FromDate
	end
	
	if isnull(@ToDate,'') = ''
	begin
		set @DateTo = {fn curdate()} 
	end
	else
	begin
		set @DateTo = @ToDate
	end

	Select 'Number of Cards' as'Data',Count(*)as'Count' , @CurDate as Date from iac_card(nolock)
	union all
	Select 'Number of Accounts'as'Data',Count(*) as'Count' , @CurDate as Date  from iac_account(nolock)
	union all
	Select 'Number of Transaction'as'Data',Count(*) as'Count', @DateFrom as Date from itx_txn(nolock) 
	where TxnDate between @DateFrom and @DateTo 
end
GO
