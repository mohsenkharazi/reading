USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardDataExport]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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
2014/07/14  Humairah			Add truncate table temp_DataExtraction
*******************************************************************************/
/*
DECLARE @OUT varchar(200) 
EXEC CardDataExport 1008824, @OUT output
select @OUT
*/	

CREATE	procedure [dbo].[CardDataExport]
	@BatchId uBatchId,
	@Out varchar(200) output
  
as
begin


	truncate table temp_DataExtraction

	------------------------------------
	declare @TSql varchar(1000), @Path varchar(50), @Sts varchar(2),
			@Min bigint, @PrevSeqNo bigint, @Plastic varchar(30), @PrcsDate varchar(10),
			@OperationMode char(10), @FileSeq int, @FileName varchar(50), @FileExt varchar(10),
			@PlasticType uPlasticType, @CardPlan varchar(10), @RecCnt int, @Max bigint, @SrcName varchar(50),
			@SrcFileName varchar(20), @FileDate datetime, @DestName varchar(20), @RowCount bigint
			
	declare @CreateTable varchar(300), @Header varchar(100), @MySpecialTempTable varchar(100),
			@Detail varchar(MAX), @Trailer varchar(100), @Command varchar(500), @Unicode int, @RESULT int

	set nocount on
	set dateformat ymd

	

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
	from udiE_Card (nolock)
	where BatchId = @BatchId 


	select @BatchId = cast(BatchId as varchar(8))
	from udiE_Card (nolock)
	where BatchId = @BatchId and SeqNo = @Min


	-- Contruct file name
	select	@FileSeq = FileSeq, @OperationMode = cast(isnull(OperationMode, 'N') as char(1)), -- Default set to status New = (GhostCardGen)
			@RecCnt = RecCnt +1, @SrcName = SrcName, @SrcFileName = FileName, @FileDate = FileDate, @DestName = DestName
	from udi_Batch (nolock) 
	where BatchId = @BatchId 

	
--	select @FileName = @SrcName+ '_' + @SrcFileName + '_'+ convert(varchar(8), @batchId)+'_'+ @PrcsDate					--20140421 Humairah 
	select @FileName = @SrcName+ ' ' + @SrcFileName 																	--20140421 Humairah 
	select @FileExt =  '.' + convert(varchar(8), @batchId)																--20140421 Humairah 
	select @Out = '"' + @Path + @FileName + @FileExt + '"'
	

	-- Create Header Record
	select @TSql =	'H' +	 -- Header (1)
						dbo.PadRight(' ', 8, @SrcName) +
						dbo.PadRight(' ', 20, @SrcFileName) +
						dbo.PadLeft('0', 12, @FileSeq) +
						dbo.PadRight(' ', 8, @DestName) +
						dbo.PadLeft(' ', 8, convert(varchar(8), @FileDate, 112)) 
	
	insert temp_DataExtraction (String)
	select @TSql


	-- insert Detail
	insert temp_DataExtraction (String)
	select 'D'+  -- Detail(1)
		dbo.PadLeft('0', 8, SeqNo) + --RecSeq(8),
		dbo.PadLeft(' ', 10, AcctNo) + -- AcctNo (10)
		dbo.PadLeft(' ', 17, CardNo) + -- CardNo (17)
		dbo.PadLeft(' ', 10, isnull(Title,'')) + -- Title (10)
		dbo.PadLeft(' ', 2, isnull(Nationality,'')) + -- Nationality (2)	
		dbo.PadRight(' ', 50, rtrim(isnull(FamilyName,''))) + -- Name (10)	
		dbo.PadRight(' ', 15, rtrim(isnull(NewIc,''))) + -- NewIc (15)	
		dbo.PadRight(' ', 15, rtrim(isnull(PassportNo,''))) +  -- PassportNo (15)	
		dbo.PadLeft(' ', 8, convert(varchar(8), isnull(Dob,''), 112)) + -- DOB (8)	
		case when isnull(gender,'') ='' then ' ' else Gender end + -- Gender (1)
		case when isnull(Race,'') ='' then ' ' else Race end + -- Race (1)	
		dbo.PadRight(' ', 14, isnull(PrefLanguage,'')) + -- PrefLanguage(14)	
		dbo.PadRight(' ', 14, isnull(PrefCommunication,'')) + -- PrefCommunication(14)	
		dbo.PadRight(' ', 35, isnull(Television,'')) + -- Television(35)	
	
		Case when isnull(TelevisionInp,'')='' then dbo.PadRight(' ', 25, isnull(TelevisionInp,'')) 
			 when TelevisionInp <>'' and len(TelevisionInp) < 25 then dbo.PadRight(' ', 25, rtrim(substring(TelevisionInp, 1, 25)))
			 else substring(isnull(TelevisionInp,''), 1, 25) end + -- TelevisionInp(25)

		dbo.PadRight(' ', 35, isnull(Radio,'')) + -- Radio(35)
		
		Case when isnull(RadioInp,'')='' then dbo.PadRight(' ', 25, isnull(RadioInp,'')) 
			 when Radioinp <>'' and len(RadioInp) < 25 then dbo.PadRight(' ', 25, rtrim(substring(RadioInp, 1, 25)))
			 else substring(isnull(RadioInp,''), 1, 25) end + -- RadioInp(25)

		dbo.PadRight(' ', 35, isnull(NewsPaper,'')) + -- NewsPaper(35)	
		
			
		Case when isnull(NewsPaperInp,'')='' then dbo.PadRight(' ', 25, isnull(NewsPaperInp,'')) 
			 when NewsPaperInp <>'' and len(NewsPaperInp) < 25 then dbo.PadRight(' ', 25, rtrim(substring(NewsPaperInp, 1, 25)))
			 else substring(isnull(NewsPaperInp,''), 1, 25) end + -- NewsPaperInp(25)

		dbo.PadRight(' ', 35, isnull(Interest,'')) + -- Interest(35)	

		Case when isnull(InterestInp,'')='' then dbo.PadRight(' ', 25, isnull(InterestInp,'')) 
			 when InterestInp <>'' and len(InterestInp) < 25 then dbo.PadRight(' ', 25, rtrim(substring(InterestInp, 1, 25)))
			 else substring(isnull(InterestInp,''), 1, 25) end + -- InterestInp(25)
		
		dbo.PadRight(' ', 50, isnull(CardTypeDescp,'')) + -- CardTypeDescp(50)	
		dbo.PadRight(' ', 1, substring(isnull(Sts,''), 1, 1)) -- Sts(1)	
	from udiE_Card 
	where BatchId = @BatchId
	order by SeqNo
	
	select @RowCount = count(String) from temp_DataExtraction

	--insert trailer
	select @TSql = 'T' + -- Trailer (1)
					dbo.PadLeft('0', 6, @RowCount)
	from temp_DataExtraction
	

	insert temp_DataExtraction (String)
	select @TSql


	--Start File Export
	SELECT  @Command = 'bcp "select String from '
          + @MySpecialTempTable + ' order by seqno '
          + '" queryout '
          + @Out + ' '
         + CASE WHEN @Unicode=0 THEN '-c' ELSE '-w' END
          + ' -T -S' + @@servername
 
	--select @Command

	 EXECUTE @RESULT= MASTER..xp_cmdshell @command, NO_OUTPUT


	truncate table temp_DataExtraction																					--2014/07/14  Humairah

end
GO
