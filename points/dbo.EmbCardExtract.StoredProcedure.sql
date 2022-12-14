USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[EmbCardExtract]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/******************************************************************************  
Copyright : Cardtrend System Sdn Bhd  
Modular  : Cardtrend Card Management System (CCMS)- Issuing Module  
  
Objective : sp_cmdshell output embossing file.  
  
SP Level : Primary  
-------------------------------------------------------------------------------  
When  Who  CRN    Description  
-------------------------------------------------------------------------------  
2009/02/22 Sam      Initial development.  
  
   Related to:  
     (1) GhostCardGenDlg.cpp/GhostCardGenDlg.h - to capture tot cards to be produce.  
     (2) GhostCardGenBatch - create udi_batch header.  
     (3) GhostCardProcessing* - looping for udi_batch to call GhostCardGen.  
     (4) GhostCardGen - To create card account tables & misc.  
     (5) EmbCardExtract - To generate embossing file using xp_cmdshell.  
  
2009/03/24 Darren   Changes file name and format based on VPI_SPEC_V1.4  
       Include Mailing List generation  
*******************************************************************************/  
/*  
  
update iac_plasticCard set Sts = 'E' where Batchid = 166  
  
declare @rc varchar(200), @rt int  
  
exec @rt = embcardextract 1,'166', @rc  
  
select @rt  
  
165  
166  
select * from udi_Batch where filename ='GCGEN'  
  
  
*/  
CREATE procedure [dbo].[EmbCardExtract]  
 @IssNo uIssNo,  
 @BatchId int,  
 @Out varchar(200) output  
  
  as  
begin  
 declare @TSql varchar(1000), @Path varchar(50), @Sts varchar(2),  
   @Min bigint, @PrevSeqNo bigint, @Plastic varchar(30), @PrcsDate varchar(10),  
   @OperationMode char(10), @FileSeq int, @FileName varchar(50), @FileExt varchar(10),  
   @PlasticType uPlasticType, @CardPlan varchar(10), @RecCnt int, @Max bigint  
     
 declare @CreateTable varchar(300), @Header varchar(100), @MySpecialTempTable varchar(100),  
   @Detail varchar(MAX), @Trailer varchar(100), @Command varchar(500), @Unicode int, @RESULT int  
  
 set nocount on  
 set dateformat ymd  
  
 truncate table temp_emboss  
 truncate table temp_PlasticCard  
  
 insert temp_PlasticCard(IssNo,BatchId,SeqNo,CardLogo,PlasticType,AcctNo,CardNo,EmbName,ExpiryDate,CVC1,DeliveryMethod,CourierCmpy,HandCollectionDate,InputSrc,CreationDate,Sts,SendingCd,BranchCd,ZipCd)  
 select IssNo,BatchId,SeqNo,CardLogo,PlasticType,AcctNo,CardNo,EmbName,ExpiryDate,CVC1,DeliveryMethod,CourierCmpy,HandCollectionDate,InputSrc,CreationDate,Sts,SendingCd,BranchCd,ZipCd   
 from iac_PlasticCard  
 where batchId  = @BatchId order by CardNo  
  
   
  
 select  @Unicode=0  
 select @MySpecialTempTable = isnull(VarcharVal,'CCMS') + '..temp_Emboss' from iss_default  where deft = 'CCMSDb' and IssNo = @IssNo  
  
 select @PrcsDate = convert(varchar(10),getdate(),112)  
 select @RecCnt = 0  
  
 select @Path = VarcharVal  
 from iss_Default   
 where Deft = 'DeftEmbossFilePath'  
  
 if @Path is null   
  select @Path = 'D:\'   
  
 select @FileExt = VarcharVal  
 from iss_Default   
 where Deft = 'DeftEmbossFileExt'  
  
 if @FileExt is null  
  select @FileExt = '.txt'  
  
 select @Min = min(SeqNo), @Max = Max(SeqNo) + 1  
 from Temp_PlasticCard (nolock)  
 where BatchId = @BatchId and Sts = 'E'  
  
 if @@error <> 0 return 70483 --Failed to insert emboss record  
  
 select @BatchId = cast(BatchId as varchar(8))  
 from Temp_PlasticCard (nolock)  
 where BatchId = @BatchId and SeqNo = @Min  
  
 -- Contruct file name  
 select @FileSeq = FileSeq, @OperationMode = cast(isnull(OperationMode, 'N') as char(1)), -- Default set to status New = (GhostCardGen)  
   @PlasticType = PlasticType, @CardPlan = CardPlan, @RecCnt = RecCnt +1  
 from udi_Batch (nolock)   
 where BatchId = @BatchId   
  
 -- Validation before processing  
 if @OperationMode = 'M'  
 begin  
  if isnull(@PlasticType, '') = ''   
   return 60013 -- Plastic Type not found  
  
  if isnull(@CardPlan, '') = ''  
   return 60005 -- Card Logo not found  
 end  
  
 select @FileName = 'EMB_' + rtrim(@OperationMode) + '_' + @PrcsDate + '_' + dbo.PadLeft('0', '5', cast(@FileSeq as varchar(5)))  
  
 select @Out = @Path + @FileName + @FileExt  
  
 if isnull(@Min,0) > 0  
 begin  
  
--  exec sp_configure 'show advanced options', 1  
--  reconfigure  
   
--  exec sp_configure 'xp_cmdshell', 1  
--  reconfigure   
  
  
  -- Create Header Record  
  select @TSql = 'H' + -- Header (1)  
      dbo.PadRight(' ', 20, @FileName)  
  
  select @Header = 'insert '+ @MySpecialTempTable+' (SeqNo, String)'+ ' select 1,''' + @TSql +''''  
  --select @Header  
  exec (@Header)  
    
  if @@error <> 0 return 1  
  
    -- Contruct Detail  
  select @TSql =   
    'select a.SeqNo, ''' + 'D' + -- Detail (1)  
    '%' + -- T1 SS (1)  
    'B'''+ '+' + -- T1 FC (1)  
    'dbo.PadLeft(0, 17, cast(a.CardNo as varchar(17)))' +  -- T1 CardNo (17)  
    '+''' +'^'+'''+'+ -- T1 FS (1) ^^ Because dos act ^ as reserved key  
    'dbo.PadRight('''+' '+''', 26, isnull(a.EmbName,''''))' + -- T1 CardHolder Name (26)  
    '+''' +'^'+'''+'+ -- T1 FS (1)  
    'substring(convert(char(8), c.ExpiryDate,112),3,4)' + -- T1 Expiry Date YYMM (4)  
    '+''' +'201'+'''+' + -- T1 Service Code (3)  
    'isnull(c.CVC,000) +' + -- Combine T1 PVV with (DD) Below (3)  
    'dbo.PadRight(0, 6, substring(cast(cast(rand(right((a.CardNo),6)) * 10000000000 as numeric) as varchar(30)),4,6)) +' + '''               ''' +  ---- T1 DD combile with (PVV) Below (above) (21)   
    '+''?''' + -- T1 ES (1)  
    '+'';''+' + -- T2 SS (1)  
    'dbo.PadLeft(0, 17, cast(a.CardNo as varchar(17)))' +  -- T2 CardNo (17)  
    '+''=''+' + -- T2   
    'substring(convert(char(8), c.ExpiryDate,112),3,4)' +                  --MC-LINE-2-EXPIRY-YYMM  
    '+''' +'201'+'''+' +  
    'isnull(c.CVC,000) +' +   
    'dbo.PadRight(0, 6, substring(cast(cast(rand(right((a.CardNo),6)) * 10000000000 as numeric) as varchar(30)),4,6))' +       --MC-CVC  
    '+''?''' +  
  ' from temp_PlasticCard a (nolock)  
  join iac_Account b (nolock) on a.AcctNo = b.AcctNo   
  join iac_Card c (nolock) on a.IssNo = c.IssNo and a.CardNo = c.CardNo   
  left outer join iac_Entity d (nolock) on a.IssNo = d.IssNo and b.EntityId = d.EntityId  
  where a.BatchId =''' + convert(varchar(10),@BatchId) + ''''   
  
  if len(@Detail) <> 116 -- Actual len is 116 due to two ^^ need to add 2 len  
  begin  
   return 70487  -- Failed to insert Card Profile  
  end  
  
  select @Detail = 'insert '+ @MySpecialTempTable+' (SeqNo, String) ' +@TSql  
  --select @Detail  
  exec (@Detail)  
  
  if @@error <> 0 return 1  
  
  
  -- Create Detail Record  
  select @TSql = 'T' + -- Header (1)  
      dbo.PadLeft('0', 6, cast(@RecCnt as varchar(6))) -- FileName (20)  
  
  select @Trailer = 'insert '+ @MySpecialTempTable+' (SeqNo, String)'+ 'select ''' + convert(varchar(20), @Max )+ ''',''' + @TSql+ ''''  
  --select @Trailer  
  exec (@Trailer)  
     
  if @@error <> 0 return 1  
 end  
  
-- exec('select * from '+ @MySpecialTempTable)  
  
 SELECT  @Command = 'bcp "select String from '  
          + @MySpecialTempTable + ' order by SeqNo'  
          + '" queryout '  
          + @Out + ' '  
         + CASE WHEN @Unicode=0 THEN '-c' ELSE '-w' END  
          + ' -T -S' + @@servername  
   
 --select @Command  
  
  --EXECUTE @RESULT= MASTER..xp_cmdshell @command, NO_OUTPUT  
  
  exec ('select String from '  
          + @MySpecialTempTable + ' order by SeqNo')
  
  
 -----------------------------------------------------  
 -- Create Mailing List only for Migrated Members  
 -----------------------------------------------------  
  
 if @OperationMode = 'M'  
 begin  
    
  -- Reinitialise variable  
  select @RecCnt = 0  
  
  -- Reselect Record for Mailing List  
  select @Min = min(SeqNo)  
  from iac_PlasticCard (nolock)  
  where BatchId = @BatchId and Sts = 'E'  
  
  if @@error <> 0 return 70483 --Failed to insert emboss record  
  
  if isnull(@Min,0) > 0  
  begin  
       
   -- Create File Name  
   select @FileName = 'VPI_MAIL_' + rtrim(@OperationMode) + '_' + @PrcsDate + '_' + dbo.PadLeft('0', '5', cast(@FileSeq as varchar(5)))  
   select @Out = @Path + @FileName + @FileExt   
  
   -- Create Header Record  
   select @TSql = 'echo ' +  
       'H' + -- Header (1)  
       'VPI     ' + -- SourceName (8)  
       'MAILER              ' + -- File Type (20)  
       dbo.PadLeft('0', 12, cast(@FileSeq as varchar(12))) + -- FileSeq (12)         
       '1       ' + -- Destination Name (8)  
       @PrcsDate +  -- File Date (8)  
       dbo.PadRight(' ', 8, @PlasticType) + -- PlasticType (8)  
       dbo.PadRight(' ', 8, @CardPlan) + -- CardPlan (8)  
       cast(@OperationMode as char(1)) + -- OperationMode (1)  
       '>> ' + @Out -- File Name (20)  
         
   exec master..xp_cmdshell @TSql, no_output  
  
   -- Create Detail Record  
   while isnull(@Min,0) > 0  
   begin  
      
    -- Record Counter  
    select @RecCnt = @RecCnt + 1  
  
    -- Contruct Detail       
    select @TSql= 'echo ' +   
        'D' + -- Record indicator (1)  
        dbo.PadLeft('0', 10, @RecCnt) +  -- Record Seq (10)          
        dbo.PadRight(' ', 17, a.CardNo) + -- Card No (17)  
        dbo.PadRight(' ', 20, g.Descp)  + -- Title (20)  
        dbo.PadRight(' ', 50, d.FamilyName) + -- Name (50)   
        dbo.PadRight(' ', 25, e.Street1) + -- Address 1 (25)   
        dbo.PadRight(' ', 25, e.Street2) + -- Address 2 (25)  
        dbo.PadRight(' ', 25, e.Street3) + -- Address 3 (25)  
        dbo.PadRight(' ', 28, e.City) +  -- City (28)  
        dbo.PadRight(' ', 25, f.Descp) + -- State (25)  
        dbo.PadLeft('0', 5, e.ZipCd) + -- Postcode (5)     
        '>> ' + @Out  
    from iac_PlasticCard a (nolock)  
    join iac_Account b (nolock) on a.AcctNo = b.AcctNo   
    join iac_Card c (nolock) on a.IssNo = c.IssNo and a.CardNo = c.CardNo   
    left outer join iac_Entity d (nolock) on a.IssNo = d.IssNo and b.EntityId = d.EntityId  
    left outer join iss_Address e (nolock) on e.RefKey = b.AcctNo and e.RefTo = 'ACCT' and e.MailingInd = 'Y'  
    left outer join iss_State f (nolock) on f.CtryCd = e.Ctry and f.StateCd = e.State  
    left outer join iss_RefLib g (nolock) on g.RefType = 'Title' and g.RefCd = d.Title  
    where a.SeqNo = @Min  
  
    exec master..xp_cmdshell @TSql, no_output  
  
    if @@error <> 0 return 1  
  
    select @PrevSeqNo = @Min  
  
    select @Min = min(SeqNo)  
    from iac_PlasticCard (nolock)  
    where BatchId = @BatchId and Sts = 'E' and SeqNo > @PrevSeqNo  
  
    if @@error <> 0 return 1  
   end  
  
   -- Increase Cnt to include Trailer record  
   select @RecCnt = @RecCnt + 1  
  
   -- Create Detail Record  
   select @TSql = 'echo ' +  
       'T' + -- Header (1)  
       dbo.PadLeft('0', 10, cast(@RecCnt as varchar(10))) + '>> ' + @Out -- FileName (20)  
  
   exec master..xp_cmdshell @TSql, no_output  
  
  end  
 end  
  
-- exec sp_configure 'xp_cmdshell', 0  
-- reconfigure   
  
-- exec sp_configure 'show advanced options', 0  
-- reconfigure  
  
   
  
  
 update iac_PlasticCard  
 set Sts = 'P'  
 where BatchId = @BatchId and Sts = 'E'  
  
 if @@error <> 0 return 1  
  
 update a  
 set PrcsRec = b.Cnt  
 from udi_Batch a  
 join (select InputSrc, count(*) 'Cnt'  
   from iac_PlasticCard (nolock)   
   where BatchId = @BatchId and Sts = 'P'  
   group by InputSrc) b on a.FileName = b.InputSrc   
 where a.SrcName = 'Host' and a.DestName = 'VPI' and a.BatchId = @BatchId  
  
 if @@error <> 0 return 1  
  
 truncate table temp_PlasticCard  
  
 return 0  
end
GO
