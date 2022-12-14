USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ExportReport]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



/******************************************************************************
Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend AirTime Reload Management System 
Objective	: Export Report
------------------------------------------------------------------------------------------------------------------
When	   	Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2009/09/08 	Peggy	Initial development
2018/12/12  Fahmi   Special handling of Month Financial Summary Reports
2018/12/19  Fahmi   Special handling for Excel version of LMS007, 012, 016, 017, 025, 028, 029, 031, 050, 056 and LMS076
*******************************************************************************/
--  exec ExportReport 1,112,'LMS001AccountActivity','20090408','20090408','.pdf'
CREATE	procedure [dbo].[ExportReport]
	@IssNo varchar(5),
	@PrcsId varchar(5),
	@RptName varchar(50),	
	@FromDate varchar(10),
	@ToDate varchar(10),	
	@RptType varchar(10),
	@ErrMsg varchar(255) = null output

   as
begin
		declare @InFileName varchar(250), @OutFileName varchar(250)
		declare @PrcsDate datetime, @Date varchar(8)
		declare @InputPath varchar(50), @OutputPath varchar(50)
		declare @InputFileExt varchar(5), @OutputFileExt varchar(5)
		declare @Parameter nvarchar(1000), @RptInd int

		select @InputPath = InputPath, @OutputPath = OutputPath,
			@InputFileExt = InputFileExt
		from iss_Issuer
		where IssNo = @IssNo

		select @OutputFileExt = @RptType

		-- Construct Input File Name
		select @InFileName = @InputPath + @RptName + @InputFileExt

		-- Construct Output File Name
		select @PrcsDate = PrcsDate 
		from cmnv_ProcessLog
		where PrcsId = @PrcsId and IssNo = @IssNo


		IF @PrcsDate is null or @InputPath is null or @OutputPath is null 
			or @InputFileExt is null or @OutputFileExt is null
			RETURN 95211 -- Incomplete Parameter Setup

		select @Date = convert(varchar(8),@PrcsDate , 112)

		select @OutFileName = @OutputPath + @RptName + @Date + @OutputFileExt
		
		-- Special handling for new LMS Finance Summary Reports (Start)

		if ((@RptName like 'LMS087%') OR (@RptName like 'LMS088%') OR (@RptName like 'LMS007%')  OR (@RptName like 'LMS012%')  OR (@RptName like 'LMS016%') OR (@RptName like 'LMS017%')  OR (@RptName like 'LMS025%')  OR (@RptName like 'LMS028%') OR (@RptName like 'LMS029%')  OR (@RptName like 'LMS031%')  OR (@RptName like 'LMS050%') OR (@RptName like 'LMS056%') OR (@RptName like 'LMS076%'))
		begin
			if (@RptType = '.xls')
			begin
				select @InFileName = @InputPath + @RptName + '_xls' + @InputFileExt
			end

		end

		-- Special handling for new LMS Finance Summary Reports (End)

		-- Report Parameter		
		select @Parameter = '@IssNo:'+@IssNo+'|@PrcsId:'+@PrcsId+'|@FromDate:'+@FromDate+'|@ToDate:'+@ToDate

		-- Report Indicator
		select @RptInd = RefNo from iss_RefLib where RefType = 'RptInd' and RefCd = @RptType

		insert into ITS_SYS_REPORT_QUEUE (REPORT_FILE,OUTPUT_FILE,PARAMETERS,REPORT_TYPE)
		select @InFileName, @OutFileName, @Parameter, @RptInd

		if @@error <> 0
		begin
			select @ErrMsg = 'Failed to generate report ' + @RptName 
		end 

end
GO
