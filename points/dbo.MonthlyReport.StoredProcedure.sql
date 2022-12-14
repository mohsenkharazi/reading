USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MonthlyReport]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************
Copyright	:	CardTrend Systems Sdn. Bhd.
Modular		:	CardTrend Card Management System (CCMS)- Issuing Module

Objective	:	This stored procedure will print all monthly report.
			Output Report Name : Crystal Report Name + Date
					eg : NewAcctApplMthlySts20021231 (27 char in length)
			Length for Output Report Name should not more than 30 char.
------------------------------------------------------------------------------------------------------------------
When	   	Who		Desc
------------------------------------------------------------------------------------------------------------------
2003/01/24 	Chew Pei	Initial development
2004/01/14	Chew Pei	Commented StmtOfAcct and Txn (These two rpt is a cycle rpt)
2004/02/11	Aeris		Add checking on First day of the month exists in cmn_Processlog
2004/05/21  Aeris		Added Merchant Sales Performance Report
2005/03/17	Kenny		Added Card Production Summary and Account Creation Summary
******************************************************************************************************************/
-- exec MonthlyReport 1,36
CREATE procedure [dbo].[MonthlyReport]
	@IssNo uIssNo,
	@PrcsId uPrcsId = null
  as
begin
	declare @PrcsName varchar(50),
		@RptName varchar(50),
		@PrcsDate datetime,
		@FromDate datetime,
		@ToDate datetime,
		@Day int,
		@Ind char(1)	

	if @PrcsId is null
	begin
		select @PrcsId = CtrlNo, @PrcsDate = CtrlDate
		from issv_Control
		where IssNo = @IssNo and CtrlId = 'PrcsId'
	end

	select @PrcsDate = PrcsDate
	from cmn_ProcessLog
	where PrcsId = @PrcsId

	select @FromDate = PrcsDate, @ToDate = PrcsDate
	from cmn_ProcessLog
	where PrcsId = @PrcsId

	--select @Day = datepart(dd,@PrcsDate)
	select @Day = datepart(dd,(dateadd(d,1, @PrcsDate)))

	-- Print Report on last day of each month
	if @Day <> 1 return 

	select @Ind = 'M'  -- Monthly

--	select @FromDate = dateadd(mm, -1, @PrcsDate )
--	select @ToDate = dateadd(dd, -1, @PrcsDate)	-- Get last day of the month

	declare @NoOfDay int
	select @NoOfDay = datepart(dd, @PrcsDate )
	select @FromDate = dateadd(dd, -@NoOfDay + 1, @PrcsDate)	-- Get First day of the month

	-- 2004/02/11B
	if not exists (select 1 from cmn_Processlog where PrcsDate = @FromDate and IssNo = @IssNo)
	Begin
		Select @FromDate = min(PrcsDate) from cmn_ProcessLog
	End
	-- 2004/02/11E

	select @ToDate = @PrcsDate

	-----------------------------------------------------
	-- Expiry Point Report (FLT201)
	-----------------------------------------------------
	select @PrcsName = 'Point Expiry Report'
	select @RptName = 'LMS022PointExpiry'

	exec PrintReport @IssNo, @PrcsId, @PrcsName, @RptName, @Ind, @FromDate, @ToDate

	-----------------------------------------------------
	-- Monthly Suspicious Fraud Transaction Report (FLT201)
	-----------------------------------------------------
	select @PrcsName = 'Monthly Suspicious Fraud Transaction Report'
	select @RptName = 'LMS040MonthlySuspiciousFraudTxn'

	exec PrintReport @IssNo, @PrcsId, @PrcsName, @RptName, @Ind, @FromDate, @ToDate



end
GO
