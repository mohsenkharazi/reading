USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ExportAcctStmtReport]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend AirTime Reload Management System 
Objective	: Export Report
*******************************************************************************/
-- exec ExportAcctStmtReport 1,16,'STMT_','20090701','20090701'
CREATE	procedure [dbo].[ExportAcctStmtReport]
	@IssNo varchar(5),
	@PrcsId varchar(5),
	@RptName varchar(50),	
	@FromDate varchar(10),
	@ToDate varchar(10),
	@AcctNo varchar(20), 
	@StmtId varchar(5), 
	@StmtDate varchar(10),	
	@ErrMsg varchar(255) = null output
  as
begin
		declare @InFileName varchar(250), @OutFileName varchar(250)
		declare @PrcsDate datetime, @Date varchar(8)
		declare @InputPath varchar(25), @OutputPath varchar(25)
		declare @InputFileExt varchar(5), @OutputFileExt varchar(5)
		declare @Parameter varchar(1000)
				
		

		select @InputPath = InputPath, @OutputPath = OutputPath,
			@InputFileExt = InputFileExt, @OutputFileExt = OutputFileExt
		from iss_Issuer
		where IssNo = @IssNo

		-- Construct Input File Name
		select @InFileName = @InputPath + @RptName + @InputFileExt

		-- Construct Output File Name
		select @PrcsDate = PrcsDate 
		from cmnv_ProcessLog
		where PrcsId = @PrcsId and IssNo = @IssNo


		IF @PrcsDate is null or @InputPath is null or @OutputPath is null 
			or @InputFileExt is null or @OutputFileExt is null
			RETURN 95211 -- Incomplete Parameter Setup


		select @OutFileName = @OutputPath + @RptName + '_' + @StmtDate + '_' + @StmtId + '_' + @AcctNo + @OutputFileExt
				
		select @Parameter = '@IssNo:'+@IssNo+'|@PrcsId:'+@PrcsId+'|@FromDate:'+@AcctNo+'|@ToDate:'+@StmtId

		insert into ITS_SYS_REPORT_QUEUE (REPORT_FILE, OUTPUT_FILE, PARAMETERS)
		select @InFileName, @OutFileName, @Parameter

		if @@error <> 0
		begin
			select @ErrMsg = 'Failed to generate report ' + @RptName 
		end 

end
GO
