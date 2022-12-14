USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AccountDataExport]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:

Objective	:

-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2007/06/01	Barnett				Initial Development
2014/04/21	Humairah			Change Filename format
2014/07/17  Humairah			add truncate table temp_DataExtraction at SP end  
*******************************************************************************/
/*
DECLARE @OUT varchar(200) 
EXEC AccountDataExport 1008823, @OUT output
select @OUT

use Demo_lms_tools
GO
exec AccountDataExtraction 1
*/	

CREATE	procedure [dbo].[AccountDataExport]
	@BatchId uBatchId,
	@Out varchar(200) output
--with encryption 

as
begin
	truncate table temp_DataExtraction

	------------------------------------
	declare @IssNo uIssNo, @TSql varchar(1000), @Path varchar(50), @Sts varchar(2),
			@Min bigint, @PrevSeqNo bigint, @Plastic varchar(30), @PrcsDate varchar(10),
			@OperationMode char(10), @FileSeq int, @FileName varchar(50), @FileExt varchar(10),
			@PlasticType uPlasticType, @CardPlan varchar(10), @RecCnt int, @Max bigint, @SrcName varchar(50),
			@SrcFileName varchar(20), @FileDate datetime, @DestName varchar(20), @RowCount bigint
			
	declare @CreateTable varchar(300), @Header varchar(100), @MySpecialTempTable varchar(100),
			@Detail varchar(MAX), @Trailer varchar(100), @Command varchar(500), @Unicode int, @RESULT int

	set nocount on;
	set transaction isolation level read uncommitted;
	set dateformat ymd

insert iss_JobAudit (RunTime, IssNo, PrcsName, Descp)
select getdate(), @IssNo, 'AccountExtraction', 'begin'

	select 	@Unicode=0, @MySpecialTempTable ='Demo_lms..temp_DataExtraction'

	select @PrcsDate = convert(varchar(10),getdate(),112)
	select @RecCnt = 0

	select @Path = VarcharVal
	from iss_Default 
	where Deft = 'DeftDataExtractFilePath'


	if @Path is null 
		select @Path = 'D:\' 

--	select @FileExt = VarcharVal																						--20140421 Humairah 
--	from iss_Default 
--	where Deft = 'DeftEmbossFileExt'
--	if @FileExt is null
--		select @FileExt = '.txt'

	select @Min = min(SeqNo)
	from udiE_Account (nolock)
	where BatchId = @BatchId 


	select @BatchId = cast(BatchId as varchar(8))
	from udiE_Account (nolock)
	where BatchId = @BatchId and SeqNo = @Min


	-- Contruct file name
	select	@FileSeq = FileSeq, @OperationMode = cast(isnull(OperationMode, 'N') as char(1)), -- Default set to status New = (GhostCardGen)
			@RecCnt = RecCnt +1, @SrcName = SrcName, @SrcFileName = FileName, @FileDate = FileDate, @DestName = DestName
	from udi_Batch (nolock) 
	where BatchId = @BatchId 

	
--	select @FileName = @SrcName+ '_' + @SrcFileName + '_'+ convert(varchar(8), @batchId)+'_'+@PrcsDate					--20140421 Humairah 
	select @FileName = @SrcName+ ' ' + @SrcFileName 																	--20140421 Humairah 
	select @FileExt =  '.' + convert(varchar(8), @batchId)																--20140421 Humairah 	
	select @Out = '"' + @Path + @FileName + @FileExt+'"'
	

	-- Create Header Record
	select @TSql =	'H' +	 -- Header (1)
						dbo.PadRight(' ', 8, @SrcName) +
						dbo.PadRight(' ', 20, @SrcFileName) +
						dbo.PadLeft('0', 12, @FileSeq) +
						dbo.PadRight(' ', 8, @DestName) +
						dbo.PadLeft(' ', 8, convert(varchar(8), @FileDate, 112)) 
	
	insert temp_DataExtraction (String)
	select @TSql

insert iss_JobAudit (RunTime, IssNo, PrcsName, Descp)
select getdate(), @IssNo, 'AccountExtraction', 'insert H temp_DataExtrcation'

	-- insert Detail
	insert temp_DataExtraction (String)
	select 'D'+  -- Detail(1)
		dbo.PadLeft('0', 8, SeqNo) + --RecSeq(8),
		dbo.PadLeft(' ', 10, AcctNo) + -- AcctNo (10)
		dbo.Padleft('0', 11, convert(int, AccumAgeingPts*100)) + -- AccumAgeingPts(11),
		dbo.Padleft('0', 11, convert(int, PtsIssued*100)) + -- PtsIssued (11)
		dbo.Padleft('0', 11, convert(int, PtsRedeemed*100)) + -- PtsRedeemed (11)
		dbo.PadRight(' ', 50, substring(Street1, 1, case when len(Street1)>50 then 50 else len(Street1) end)) + -- Street1 (50)
		dbo.PadRight(' ', 50, substring(Street2, 1, case when len(Street2)>50 then 50 else len(Street2) end)) + -- Street2 (50)
		dbo.PadRight(' ', 50, substring(Street3, 1, case when len(Street3)>50 then 50 else len(Street3) end)) + -- Street3 (50)
		dbo.PadRight(' ', 100, substring(City, 1, len(City))) + -- City (100)
		dbo.PadRight(' ', 50, substring(State, 1, len(State))) + -- State (50)
		dbo.PadRight(' ', 5, substring(ZipCd, 1, len(ZipCd))) + -- ZipCd (5)
		dbo.PadRight(' ', 15, substring(rtrim(MobileNo), 1, 15)) + -- MobileNo (15)
		dbo.PadRight(' ', 15, substring(rtrim(HomeNo), 1, 15)) + -- HomeNo (15)
		dbo.PadRight(' ', 15, substring(rtrim(OfficeNo), 1, 15)) + -- OfficeNo (15)
		dbo.PadRight(' ', 80, substring(rtrim(Email), 1, 80)) -- Email (80)
	from udiE_Account 
	where BatchId = @BatchId
	order by SeqNo

insert iss_JobAudit (RunTime, IssNo, PrcsName, Descp)
select getdate(), @IssNo, 'AccountExtraction', 'insert D temp_DataExtrcation end'
	
	select @RowCount = count(String) from temp_DataExtraction

	--insert trailer
	select @TSql = 'T' + -- Trailer (1)
					dbo.PadLeft('0', 6, @RowCount)
	from temp_DataExtraction
	

	insert temp_DataExtraction (String)
	select @TSql

insert iss_JobAudit (RunTime, IssNo, PrcsName, Descp)
select getdate(), @IssNo, 'AccountExtraction', 'insert T temp_DataExtrcation'

	--Start File Export
	SELECT  @Command = 'bcp "select String from '
          + @MySpecialTempTable + ' order by SeqNo'
          + '" queryout '
          + @Out + ' '
         + CASE WHEN @Unicode=0 THEN '-c' ELSE '-w' END
          + ' -T -S' + @@servername
 
	--select @Command
insert iss_JobAudit (RunTime, IssNo, PrcsName, Descp)
select getdate(), @IssNo, 'AccountExtraction', 'extract out'

	 EXECUTE @RESULT= MASTER..xp_cmdshell @command, NO_OUTPUT

insert iss_JobAudit (RunTime, IssNo, PrcsName, Descp)
select getdate(), @IssNo, 'AccountExtraction', 'end'

	truncate table temp_DataExtraction																					--2014/07/17  Humairah
end
GO
