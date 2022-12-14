USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AuditFileCardDateExtraction]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/******************************************************************************  
Copyright : Cardtrend System Sdn Bhd  
Modular  : Cardtrend Card Management System (CCMS)- Issuing Module  
  
Objective : Extract Card Sts History for PDB    
  
SP Level : Primary  
-------------------------------------------------------------------------------  
When  Who  CRN    Description  
-------------------------------------------------------------------------------  
2011/12/08 Barnett     Initial development.  
*******************************************************************************/  
/*  
exec AuditFileCardDateExtraction 1, null, null  
*/  
CREATE procedure [dbo].[AuditFileCardDateExtraction]  
 @IssNo uIssNo,  
 @BatchId int,  
 @Out varchar(200) output  
  
  as  
begin  
 declare @TSql varchar(Max), @Path varchar(50), @Sts varchar(2),  
   @Min bigint, @PrevSeqNo bigint, @Plastic varchar(30), @PrcsDate varchar(10),  
   @OperationMode char(10), @FileSeq int, @FileName varchar(50), @FileExt varchar(10),  
   @PlasticType uPlasticType, @CardPlan varchar(10), @RecCnt int, @Max bigint  
     
 declare @CreateTable varchar(300), @Header varchar(200), @MySpecialTempTable varchar(100),  
   @Detail varchar(MAX), @Trailer varchar(100), @Command varchar(500), @Unicode int, @RESULT int  
   
  
 set nocount on  
 set dateformat ymd  
  
 truncate table temp_AuditFile  
  
 select  @Unicode=0, @MySpecialTempTable ='temp_AuditFile'  
  
 select @PrcsDate = convert(varchar(10), CtrlDate, 112)  
 from iss_control   
 where Ctrlid = 'PrcsId'  
   
 select @RecCnt = 0  
  
 select @Path = VarcharVal  
 from iss_Default   
 where Deft = 'DeftAuditFilePath'  
  
 if @Path is null   
  select @Path = 'D:\'   
  
 select @FileExt = VarcharVal  
 from iss_Default   
 where Deft = 'DeftAuditFileExt'  
  
 if @FileExt is null  
  select @FileExt = '.txt'  
  
 ---- Contruct file name  
 --select @FileSeq = isnull(FileSeq, 0)+ 1, @OperationMode = cast(isnull(OperationMode, 'N') as char(1)), -- Default set to status New = (GhostCardGen)  
 --  @PlasticType = PlasticType, @CardPlan = CardPlan, @RecCnt = RecCnt +1  
 --from udi_Batch (nolock)   
 --where BatchId = @BatchId   
  
  
 select @FileName = 'AuditFile_CardDate_' + @PrcsDate  
  
 select @Out = @Path + @FileName + @FileExt  
  
  
  -- Create Header Record  
  insert temp_AuditFile (SeqNo, String)   
  select 1, 'H' + -- Header (1)  
    dbo.PadRight(' ', 8, 'HOST') + -- SourceName  
    dbo.PadRight(' ', 20, 'AUDITLOG3') + -- FileType  
    dbo.PadLeft(0, 12, isnull(@FileSeq, 1)) + -- File Sequence  
    dbo.PadRight(' ', 8, 'Out') + -- Destination Name  
    @PrcsDate -- File Date  
    
  
  if @@error <> 0 return 1  
  
  -- Contruct Detail  
  insert temp_AuditFile (SeqNo, String)   
  select row_number() OVER (order by a1.String) + 1, 'D' + dbo.PadLeft(0, 8, convert(varchar(8), row_number() OVER (order by a1.String))) + String      
  from (   
     select   dbo.PadRight(' ' , 20, 'CARD')  
       + dbo.PadRight(' ' , 15, a.AcctNo)  
       + dbo.PadRight(' ' , 19, a.CardNo)  
       + SubString( convert(varchar(8), a.CreationDate, 112), 1, 8)   
       + space(1)   
       + substring( convert(varchar(8), a.CreationDate, 114), 1, 8)  
       + Case   
         when a.ActivationDate is not null then SubString( convert(varchar(8), a.ActivationDate, 112), 1, 8) + space(1) + substring( convert(varchar(8), a.ActivationDate, 114), 1, 8)  
         else space(17)  
         end  
       + Case   
         when a.FirstTxnDate is not null then SubString( convert(varchar(8), a.FirstTxnDate, 112), 1, 8) + space(1) + substring( convert(varchar(8), a.FirstTxnDate, 114), 1, 8)  
         else space(17)  
         end  
       + Case    
         when b.ClosedDate is not null then SubString( convert(varchar(8), b.ClosedDate, 112), 1, 8) + space(1) + substring( convert(varchar(8), b.ClosedDate, 114), 1, 8)             
         else space(17)            
         end  
       + Case   
         when a.LastPurchasedDate is not null then SubString( convert(varchar(8), a.LastPurchasedDate, 112), 1, 8) + space(1) + substring( convert(varchar(8), a.LastPurchasedDate, 114), 1, 8)  
         else space(17)  
         end as String  
       from iac_card a (nolock)  
       left outer join  
       (  
        select b1.IssNo, b1.CreationDate as [ClosedDate], b1.CardNo  
        from (   
         select  max(a2.EventId) as [EventId], a2.CardNo  
         from iac_Event a2 (nolock)   
         join iac_Card b2 (nolock) on b2.CardNo = a2.CardNo  
         join iss_Reflib c2(nolock) on c2.IssNo = 1 and c2.RefType = 'CardSts' and c2.Refcd = b2.Sts and c2.RefInd <> 0 and (c2.RefId & 8) > 0    
         group by a2.CardNo  
         ) a1  
        join iac_Event b1 (nolock) on b1.EventId = a1.EventId  
       ) b on b.cardno = a.CardNo  
   ) a1  
  
  select @RecCnt = @@rowcount  
      
  
  -- Create Detail Record  
  select @TSql = 'T' + -- Header (1)  
      dbo.PadLeft('0', 10, cast(@RecCnt+1 as varchar(10))) -- FileName (20)  
  
  select @Trailer = 'insert '+ @MySpecialTempTable+' (SeqNo, String)'+ 'select ''' + convert(varchar(20), @RecCnt+2 )+ ''',''' + @TSql+ ''''  
  --select @Trailer  
  exec (@Trailer)  
     
  if @@error <> 0 return 1  
 -- select * from  temp_AuditFile  
  
  
 SELECT  @Command = 'bcp "select String from '  
          + @MySpecialTempTable + ' order by SeqNo'  
          + '" queryout '  
          + @Out + ' '  
         + CASE WHEN @Unicode=0 THEN '-c' ELSE '-w' END  
          + ' -T -S' + @@servername  
   
 --select @Command  
  
    EXECUTE @RESULT= MASTER..xp_cmdshell @command, NO_OUTPUT  
  
    
 return 0  
  
end
GO
