USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[JobReportExtraction]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure will extract all the report that are ready for printing

------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2013/09/07 Jacky		   Initial development
******************************************************************************************************************/
CREATE PROCEDURE [dbo].[JobReportExtraction]
	@IssNo uIssNo
as
begin
	SET NOCOUNT ON

	declare @rc int,
		@PrcsName varchar(50),
		@StartTime datetime,
		@Msg varchar(80),
		@Sts char(1),
		@BatchId uBatchId

	select JobId, RptFilename, DiskFilename, DiskFileType, RptParam, ConnStr,
		'update job_Report set CompletionDate = GETDATE(), Sts = ''A'' where JobId = '+CAST(JobId as varchar) 'Success',
		'update job_Report set Sts = case when Sts = ''P'' then ''1'' when Sts = ''1'' then ''2'' when Sts = ''2'' then ''3'' when Sts = ''3'' then ''X'' else ''F'' end where JobId = '+CAST(JobId as varchar) 'Failure'
	into #JobList
	from job_Report
	where  (Sts = 'P' and (LastPickDate is null or DATEADD(MINUTE, 10, LastPickDate) < GETDATE()))
		or (Sts = '1' and (LastPickDate is null or DATEADD(MINUTE, 20, LastPickDate) < GETDATE()))
		or (Sts = '2' and (LastPickDate is null or DATEADD(MINUTE, 30, LastPickDate) < GETDATE()))
		or (Sts = '3' and (LastPickDate is null or DATEADD(MINUTE, 60, LastPickDate) < GETDATE()))

	update a set LastPickDate = GETDATE()
	from job_Report a
	join #JobList b on b.JobId = a.JobId

	select RptFilename, DiskFilename, DiskFiletype, RptParam, ConnStr, Success, Failure
	from #JobList
end
GO
