USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[FileExtraction]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************                                                  
Copyright : CardTrend Systems Sdn. Bhd.                                                  
Modular  : CardTrend Card Management System (CCMS)- Issuing Module                                                  
                                                  
Objective : Data file extraction processing. This process should run after the End Of Day has been completed.                                                  
     Hence the process ID use for extraction should be 1 day before the current PrcsId.                                                  
                                                  
------------------------------------------------------------------------------------------------------------------                                                  
When    Who  CRN Desc                                                  
------------------------------------------------------------------------------------------------------------------                                                  
2013/08/13 KY  Initial development                                     
2017/06/28 Jasmine  Add Card adjustment Txn Report Exccel Files                                  
2017/07/17 Humairah Add Monthly Report Files ( Grab and Cards info)                                   
2018/01/11 Humairah Alter GL extraction parameter.                                   
******************************************************************************************************************/                                                  
/*                                                  
declare @rc int                                                  
exec @rc = FileExtraction 1, NULL, NULL                                                  
select @rc                                                  
*/                                                  
CREATE PROCEDURE [dbo].[FileExtraction]                                                  
 @IssNo uIssNo,                                                  
 @PrcsId uPrcsId = null,                                                  
 @MapInd bigint = null                                                  
as                                                  
begin                                                  
 declare                                                  
  @ExportPath varchar(200),                                                  
  @ReportExportPath varchar(200),                                                  
  @Path varchar(200),                                                  
  @CardDeliveryAddress uRefCd,                                                  
  @BatchId uBatchId,                                                  
  @SPName varchar(60),                                                  
  @rc int,                                                  
  @Cnt int,                                                  
  @PrcsDate datetime,                                                  
  @PrcsName varchar(50),                                                  
  @PromptPymtSeqNo bigint,                                                  
  @AcctType int,                                                  
  @ACycStmtId bigint,                                                  
  @CycStmtId bigint,                                                  
  @ACycBillingId bigint,                                                  
  @StmtDate Date,                                                  
  @MonthEnd int,                                                  
  @CycNo int,                                                  
  @CycInd char(1),                                                  
  @Seq int = 1,                                                  
  @AccumSeq int = 0  ,                                            
  @rowcount int  ,                     
  @FileSeq int                                               
             
declare                                   
@Str as varchar (100) ,                                   
@ACCTDATABatId bigint ,                                   
@CARDDATABatId bigint ,                                   
@MERCHBatId bigint,                                  
@FileCount int ,                                   
@FileName nvarchar (200),                               
@FromDate DATETIME,                                  
@ToDate DATETIME                                  
                     
                                                  
 SET NOCOUNT ON                                                  
                            
 select @PrcsName = 'FileExtration'                                                  
                                                  
 exec TraceProcess @IssNo, @PrcsName, 'Start'                                                  
                                                  
 --------------------------------------------------------------------------------------------------------------------                                                  
 --------------------------------- RETRIEVES NECESSARY INFORMATION FOR PROCESSING -----------------------------------                                                  
 --------------------------------------------------------------------------------------------------------------------                                                  
                                     
 if @PrcsId is null                                                  
 begin                                                  
  select @PrcsId = CtrlNo - 1                                   
  from iss_Control (nolock)                                                  
  where IssNo = @IssNo and CtrlId = 'PrcsId'                                                  
 end                                  
                                                  
 select @PrcsDate = PrcsDate                                                  
 from cmnv_ProcessLog (nolock)                                                  
 where IssNo = @IssNo and PrcsId = @PrcsId                                                  
                  
                                         
 select @ExportPath = VarcharVal                                                  
 from iss_Default (nolock)                                            
 where IssNo = @IssNo and Deft = 'FileExportPath'                                                  
                                                  
 select @ReportExportPath = VarCharVal                                                  
 from iss_Default (nolock)                                                  
 where IssNo = @IssNo and Deft = 'ReportExportPath'                                                  
                                                   
 if @ExportPath is null select @ExportPath = ''                                                  
                                                  
 select @FromDate = PrcsDate, @ToDate = PrcsDate                                  
 from [Demo_lms_tools]..cmn_ProcessLog                                  
 where PrcsId = @PrcsId;               
             
        
 --------------------------------------------------------------------------------------------------------------------                                                  
 -------------------------------------------- CREATE TEMPORARY TABLES -----------------------------------------------                                                  
 --------------------------------------------------------------------------------------------------------------------                                                  
                                              
 create table #JobTable (                                                  
  SqlCmd varchar(3000),                                        
  OutputFile varchar(250),                                                  
  SummaryFile varchar(250),                                                  
  RecSprt varchar(2) NULL              
 )                                                  
                                                  
 if @@ERROR <> 0 return 70270 -- Failed to create temporary table                                                  
                                                        
                                                  
 --------------------------------------------------------------------------------------------------------------------                                      
 ------------------------------------------- POPULATE TEMPORARY TABLES ----------------------------------------------                                                  
 --------------------------------------------------------------------------------------------------------------------                                                  
                                                  
 --------------------------------------------------------------------------------------------------------------------                                                  
 ------------------------------------------------ DATA VALIDATION ---------------------------------------------------                                                  
 --------------------------------------------------------------------------------------------------------------------                                                  
                                        
 -- If End Of Day processes has been completed then update the ProcessLog, else stop running and wait for -----------                                                  
 -- next time this process being invoke again -----------------------------------------------------------------------                                                  
                                                  
 if not exists (select 1 from cmnv_ProcessLog where IssNo = @IssNo and PrcsId = @PrcsId and Sts = 'S') return                                                  
                                                  
 update a set ExtractStartDate = GETDATE()                                                  
 from [Demo_lms_tools]..cmn_ProcessLog a                                                  
 where IssNo = @IssNo and PrcsId = @PrcsId and Sts = 'S' and EndDate is not null and ExtractStartDate is null                                                  
                                              
 --------------------------------------------------------------------------------------------------------------------                                                  
 ---------------------------------------------------- PROCESS -------------------------------------------------------                                                  
 --------------------------------------------------------------------------------------------------------------------                                                  
                                           
                                           
 --Extract SPO file (bit 1 value 1) -----------------------------------------------------------------------                                                  
 if (@MapInd is null or (@MapInd & 1) > 0)                                                  
 begin                                                     
  insert #JobTable (SqlCmd, OutputFile, SummaryFile)                                                  
  select 'exec ExtractLmspetFile 1,' +  CONVERT(VARCHAR,@PrcsId) + ',NULL' ,'D:\Cardtrend\ERMY\Files\SPO\OUT\lmspet'+FORMAT(@PrcsDate, 'yyyyMMdd')+'.txt',null                                                         
 end                                                  
                                                   
 ---Extract SAP file  (bit 2 value 2) -----------------------------------------------------------------------                                      
 if (@MapInd is null or (@MapInd & 2) > 0)                                                  
 begin                                                  
  insert #JobTable (SqlCmd, OutputFile, SummaryFile)                                                  
  select 'exec GeneralLedgerExtraction_GST1 1,' +  CONVERT(VARCHAR,@PrcsId)  + ',NULL' , 'D:\Cardtrend\ERMY\Files\GL\LMS_SAP_'+FORMAT(@PrcsDate, 'yyMMdd')+'.txt',null                                                  
       
     insert #JobTable (SqlCmd, OutputFile, SummaryFile)                                                  
  select 'exec GeneralLedgerExtraction_BackDated 1,' +  CONVERT(VARCHAR,@PrcsId) , 'D:\Cardtrend\ERMY\Files\GL\LMS_SAP_B4_'+FORMAT(@PrcsDate, 'yyMMdd')+'.txt',null                   
                                  
 end                                            
                                                   
 -- Extract Card Embossing file (bit 3 value 4) -------------------------------------------------------------------------                 
  if (@MapInd is null or (@MapInd & 4) > 0)                                                  
  begin                                                  
  select  @FileCount = count(*) from udi_batch  (nolock) where Filename = 'GCGEN' and srcname = 'HOST' and PhyFileName is null                                  
                                  
  while @FileCount > 0                                  
  begin                                   
   select @FileSeq = min(FileSEq) from udi_batch (nolock) where Filename = 'GCGEN' and srcname = 'HOST' and PhyFileName is NULL                                  
   select @BatchId = BatchId  from udi_batch (nolock) where Filename = 'GCGEN' and srcname = 'HOST' and FileSEq  = @FileSeq                                  
   select @FileName = 'D:\Cardtrend\ERMY\Files\Emboss\EMB_N_'+FORMAT(@PrcsDate, 'yyyyMMdd')+'_' + cast (dbo.PadLeft(0, 5,@FileSeq)as varchar(10)) +'.txt'                                  
                                  
   insert #JobTable (SqlCmd, OutputFile, SummaryFile)                                               
   select 'exec Demo_lms_tools..EmbossFileDistribution 1,' + cast ( @BatchId as varchar(10)) ,@FileName ,null                                       
                                    
   update udi_batch set PhyFileName = @FileName where Filename = 'GCGEN' and srcname = 'HOST' and FileSeq = @FileSeq                                  
   select @FileCount = count(*) from udi_batch (nolock) where Filename = 'GCGEN' and srcname = 'HOST' and PhyFileName is null                                  
                           
   if @FileCount = 0 break                                   
  end                                            
  end                                                  
                                          
 ----Extract LMS_TRXN file (bit 4 value 8) -------------------------------------------------------------------------                                                  
 if (@MapInd is null or (@MapInd & 8) > 0)                                                  
 begin                                                  
  insert #JobTable (SqlCmd, OutputFile, SummaryFile)                                     
  select 'exec ExtractTransactionFile 1,' +  CONVERT(VARCHAR,@PrcsId) , 'D:\Cardtrend\ERMY\Files\CardTxn\LMS_TRXN_'+FORMAT(@PrcsDate, 'yyMMdd')+'.dat',null                                                  
 end                                                  
                                                  
 ----Extract SMS  File (bit 5 value 16) -------------------------------------------------------------------------                                                  
                                                  
 if  (@MapInd is null or (@MapInd & 16) > 0)                                                  
 begin                                               
 select @rowcount = count(String) -1 from udie_Sms                                            
 insert #JobTable (SqlCmd, OutputFile, SummaryFile)                                                  
 select 'exec SMSExtraction 1,' +  CONVERT(VARCHAR,@PrcsId) , 'D:\Cardtrend\ERMY\Files\SMS\Redemption_'+convert(varchar(10), @PrcsDate, 112) +'_'+convert(varchar(20), @rowcount)+'.csv',null                                                  
 end                                                  
                                                   
 ------Extract  Audit Files (bit 6 value 32) -------------------------------------------------------------------------                                                  
                                               
 if  (@MapInd is null or (@MapInd & 32) > 0)                                                  
 begin                                        
                                            
 select top 1  @Str =   String from temp_AuditFileCardAudit order by SeqNo                                   
 select @FileSeq = substring (@Str, 30,12)                                  
 insert #JobTable (SqlCmd, OutputFile, SummaryFile)      --AuditFileCardAuditExtraction                                            
 select 'select String from temp_AuditFileCardAudit order by SeqNo' , 'D:\Cardtrend\ERMY\Files\Audit\AuditFile_CardAudit_'+convert(varchar(10), @PrcsDate, 112)+ '_' + dbo.PadLeft('0', '5', cast(@FileSeq as varchar(5)))+'.txt',null                      
  
     
     
        
          
            
               
                                          
 insert #JobTable (SqlCmd, OutputFile, SummaryFile)    --AuditFileCardDateExtraction                                              
 select 'select String from temp_AuditFileCardDate order by SeqNo'  , 'D:\Cardtrend\ERMY\Files\Audit\AuditFile_CardDate_'+convert(varchar(10), @PrcsDate, 112)+ '.txt',null                               
                                              
 select top 1  @Str =   String from temp_AuditFileEntity order by SeqNo                                   
 select @FileSeq = substring (@Str, 30,12)                                   
 insert #JobTable (SqlCmd, OutputFile, SummaryFile)      --AuditFileEntityExtraction                                            
 select 'select String from temp_AuditFileEntity order by SeqNo' , 'D:\Cardtrend\ERMY\Files\Audit\AuditFile_Entity_'+convert(varchar(10), @PrcsDate, 112)+ '_' + dbo.PadLeft('0', '5', cast(@FileSeq as varchar(5)))+'.txt',null                             
  
    
      
                                          
 end                                   
                                             
 ------Extract Host Files(bit 7 value 64) -------------------------------------------------------------------------                                                  
                                                  
 if  (@MapInd is null or (@MapInd & 64) > 0)                                                  
 begin                                                  
                                  
 select @ACCTDATABatId = BatchId from udi_batch where prcsid = @PrcsId and SrcName = 'HOST' and FileName = 'ACCTDATA'                                  
 select @CARDDATABatId = BatchId from udi_batch where prcsid = @PrcsId and SrcName = 'HOST' and FileName = 'CARDDATA'                                  
 select @MERCHBatId = BatchId from udi_batch where prcsid = @PrcsId and SrcName = 'HOST' and FileName = 'MERCH'                                   
                                  
 insert #JobTable (SqlCmd, OutputFile, SummaryFile)                                                  
 select 'exec AccountDataExport ' + cast( @ACCTDATABatId as varchar(10)),'D:\Cardtrend\ERMY\Files\Host\HOST ACCTDATA.'+ cast( @ACCTDATABatId as varchar(10)) ,null                                                         
 union all                                   
 select 'exec CardDataExport ' + cast( @CARDDATABatId as varchar(10)),'D:\Cardtrend\ERMY\Files\Host\HOST CARDDATA.'+ cast( @CARDDATABatId as varchar(10)),null                                                 
 union all                                   
 select 'exec MerchDataExport ' + cast( @MERCHBatId as varchar(10)),'D:\Cardtrend\ERMY\Files\Host\HOST MERCH.'+  cast( @MERCHBatId as varchar(10)) ,null                                                         
                                  
                                           
 end                                                  
                                      
 ------Extract Daily Report Files (bit 8 value 128) -------------------------------------------------------------------------                                                  
 if  (@MapInd is null or (@MapInd & 128) > 0)                                                  
 begin                                           
 --Card adjustment Txn Report Exccel                                         
  DECLARE @tmpsql varchar(8000)                                  
 SET @tmpsql='EXEC ' + 'Demo_lms..RptCardAdjTxnExporter ' + CAST(@IssNo AS VARCHAR) + ', ' + CAST(@PrcsId AS VARCHAR) + ', ''' + CONVERT(VARCHAR,@FromDate,112) + ''', ''' + CONVERT(VARCHAR,@ToDate,112) + ''''                                  
                                   
 INSERT #JobTable (SqlCmd, OutputFile, SummaryFile)                                  
 SELECT @tmpsql ,                                   
   'D:\Cardtrend\ERMY\Files\Report\OUT\LMS004CardAdjTxn_'+CONVERT(VARCHAR,@PrcsDate,112)+'.csv',                                  
   NULL                                  
                                     
 end                                       
                                          
 ------Extract Monthly Report Files (bit 9 value 256) -------------------------------------------------------------------------                                                  
                                                  
 if  (@MapInd is null or (@MapInd & 256) > 0)                                                  
 begin                                        
 --report Monthly Mesra Grab                                   
 if (select datepart (day,@PrcsDate)) = 7                                  
 begin                                          
  INSERT #JobTable (SqlCmd, OutputFile, SummaryFile)                                  
  SELECT 'Exec RptMonthlyMesraGrab 1' ,'D:\Cardtrend\ERMY\Files\Report\OUT\LMS010MonthlyMesraGrab_'+CONVERT(VARCHAR,@PrcsDate,112)+'.csv', NULL                                       
 end                                   
                                     
 --report Active Cards Info                                  
 if (select datepart (day,@PrcsDate)) = 20                                  
 begin                 
  INSERT #JobTable (SqlCmd, OutputFile, SummaryFile)                                  
  SELECT 'Exec RptActiveCardsInfo 1' ,'D:\Cardtrend\ERMY\Files\Report\OUT\LMS006ActiveCardsInfo_'+CONVERT(VARCHAR,@PrcsDate,112)+'.csv', NULL                                       
 end                                   
                                              
 end                             
                              
  ------Extract Program SMS File (bit 10 value 512) -------------------------------------------------------------------------                         
                      
 if  (@MapInd is null or (@MapInd & 512) > 0)                                                
 begin                                              
 select top 1 @FileSeq = isnull(FileSeq,0)  from udi_Batch (nolock) where filename = 'PROGRAM' and PrcsId = @PrcsId  and  Refno3 = 1                          
                      
 if @FileSeq > 0                                
  begin                                          
   INSERT #JobTable (SqlCmd, OutputFile, SummaryFile)                                  
   SELECT 'exec ProgramSMSExtraction '+ cast(@IssNo as nvarchar(1)) + ',' + cast(@PrcsId as nvarchar) ,        
   'D:\Cardtrend\ERMY\Files\SMS\PDBPA_SpendingProgress_'+CONVERT(VARCHAR(8),@PrcsDate,112)+ '_'+ cast(@FileSeq as nvarchar) +'.csv', NULL                                    
                              
  update  udi_Batch                               
  set Sts = 'D',  --Done                               
   PhyFileName = 'PDBPA_SpendingProgress_'+CONVERT(VARCHAR(8),@PrcsDate,112)+ '_'+ cast(@FileSeq as nvarchar) +'.csv'                             
  where FileName = 'PROGRAM' and PrcsId=  @PrcsId and  Sts = 'P'  and  Refno3 = 1      -- 20190124                      
                  
  --SELECT 'exec ProgramSMSExtraction '+ cast(@IssNo as nvarchar(1)) + ',' + cast(@PrcsId as nvarchar) ,                          
  -- 'D:\Cardtrend\ERMY\Files\Programme\AXXESS\OUT\PDBPA_SpendingProgress_'+CONVERT(VARCHAR(8),@PrcsDate,112)+ '_'+ cast(@FileSeq as nvarchar) +'.csv', NULL                                    
                       
                                  
  end                                           
 end                   
                                       
  ------Extract Program Response File (bit 11 value 1024) -------------------------------------------------------------------------                                                        
 if  (@MapInd is null or (@MapInd & 1024) > 0)                                                
 begin                            
  INSERT #JobTable (SqlCmd, OutputFile, SummaryFile)                                 
  select 'exec ExtractProgramResponse_AccessPA '+ cast(@IssNo as nvarchar(1)) + ',' +  cast(@PrcsId as nvarchar) ,                          
  'D:\Cardtrend\ERMY\Files\Programme\AXXESS\OUT\PDBPA_OptInResponse_'+CONVERT(VARCHAR,@PrcsDate,112) +'.csv', NULL     

  update  udi_Batch                       -- 20190124          
  set Sts = 'D',  --Done                               
   PhyFileName = 'PDBPA_OptInResponse_'+CONVERT(VARCHAR,@PrcsDate,112) +'.csv'                            
  where FileName = 'PROGRAM' and PrcsId=  @PrcsId and  Sts = 'P'  and  Refno3 = 2                                  
  end               
  
  ------Extract Program -LMS New Customer List (bit 11 value 2048) -------------------------------------------------------------------------                                                             
 if  (@MapInd is null or (@MapInd & 2048) > 0) and (DATEPART (DD, @PrcsDate) = 15 or           
             DATEPART (DD, @PrcsDate) = DATEPART (DD, EOMONTH(@PrcsDate,0)))        
                    
 begin                            
  INSERT #JobTable (SqlCmd, OutputFile, SummaryFile)                           
  select 'exec ExtractProgramNewProfile ' + cast(@IssNo as nvarchar) + ','+ cast(@PrcsId as nvarchar) ,                          
   'D:\Cardtrend\ERMY\Files\Programme\AXXESS\OUT\PDBPA_NewProfile_' + +CONVERT(VARCHAR,@PrcsDate,112)+'.csv', NULL                           
                          
 exec  @BatchId =  NextRunNo @IssNo, 'BatchId'                          
                          
 if not exists (select 1 from udi_batch (nolock) where [FileName] = 'NewProfile')                           
  begin                          
   set  @FileSeq = 1                           
  end                           
  else                           
  begin                          
   select @FileSeq = max(FileSeq) + 1 from udi_batch (nolock) where [FileName] = 'NewProfile'                          
  end                           
 insert into udi_Batch (IssNo, BatchId,SrcName,[FileName],PhyFileName,FileSeq,DestName,FileDate,Direction,PrcsId,PrcsDate,Sts)                          
 select @IssNo, @BatchId,'HOST','NewProfile',                          
   'D:\Cardtrend\ERMY\Files\Programme\AXXESS\OUT\PDBPA_NewProfile_' + +CONVERT(VARCHAR,@PrcsDate,112)+'.csv' as 'PhyFileName',                          
   @FileSeq,'PROGRAM',getdate(),'E',@PrcsId,@PrcsDate,'S'                          
 end
 
 ------Extract Program Response File (bit 12 value 4096) -------------------------------------------------------------------------                                                        
 if  (@MapInd is null or (@MapInd & 4096) > 0)                                                
 begin
	 INSERT #JobTable (SqlCmd, OutputFile, SummaryFile) 
 	 SELECT 'EXEC ReconFileExtraction 1, ' + CONVERT(varchar, BatchId) ,
 	 REPLACE(case right([FullName], 4) when '.csv' then substring([FullName], 1, len([FullName]) -4)
 		else [FileName] end + '.ack.csv','\IN\','\OUT\'),
 	 NULL
 	 FROM cbf_batch(nolock)  WHERE FileId = 'RECON' and sts = 'P' and PrcsId = @PrcsId
 end

 ------Extract Program Response File (bit 13 value 8192) -------------------------------------------------------------------------                                                        
 if  (@MapInd is null or (@MapInd & 8192) > 0)                                                
 begin
	INSERT #JobTable (SqlCmd, OutputFile, SummaryFile) 
 	 SELECT 'EXEC ReconAABConversionFileExtraction 1, ' + CONVERT(varchar, BatchId) ,
 	 REPLACE(case right([FullName], 4) when '.csv' then substring([FullName], 1, len([FullName]) -4)
 		else [FileName] end + '.ack.csv','\IN\','\OUT\'),
 	 NULL
 	 FROM cbf_batch(nolock)  WHERE FileId = 'RCNAABCV' and sts = 'P' and PrcsId = @PrcsId
 end	
 
 --------------------------------------------------------------------------------------------------------------------                                                  
 ------------------------------------------------ UPDATE PARAMETERS -------------------------------------------------                                                  
 --------------------------------------------------------------------------------------------------------------------                                                  
                                                  
 update a set ExtractEndDate = GETDATE()                                                  
 from [Demo_lms_tools]..cmn_ProcessLog a                                                  
 where IssNo = @IssNo and PrcsId = @PrcsId                                                  
                                                  
 --------------------------------------------------------------------------------------------------------------------                                                  
 ---------------------------------------------------- FOR DEBUG -----------------------------------------------------                                                  
 --------------------------------------------------------------------------------------------------------------------                                                  
                                                  
 -- Final Result ----------------------------------------------------------------------------------------------------                                                  
                             
          
 select * from #JobTable                                                   
                                                  
 exec TraceProcess @IssNo, @PrcsName, 'End'                                                  
                                                  
 return 54143 --Process successfully completed                                                  
end
GO
