USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[DailyDatamartEmail]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
    
/******************************************************************************    
Copyright :CardTrend Systems Sdn. Bhd.    
Modular  :    
    
Objective : Datamart log mail    
    
-------------------------------------------------------------------------------    
When  Who  CRN  Description    
-------------------------------------------------------------------------------    
2014/08/21  Azan  Initial Development    
2015/04/02  Humairah Alter email subject when hit error    
2015/06/23  Humairah looping in "jamie_tan@petronas.com.my" for datamart log email    
2015/08/20  Azan  Increase LMS_TRXN minimal size to 50mb   
2016/01/21  Humairah Remove Adi and Jamie's email     
2016/07/27  Humairah Remove Syazani and Dayang email    
2016/12/21  Humairah Remove MK's email  and change directory from "DatamartLog" to "Log"  
2019/04/26  Humairah Remove Subbarao email 
*******************************************************************************/    
/*    
declare @rc int    
exec @rc = DailyDatamartEmail 1    
select @rc    
select top 1 send_request_date, * from msdb.dbo.sysmail_sentitems order by sent_date desc    
@EmailId : 1 for datamart files 2 for SMS files    
*/    
CREATE procedure [dbo].[DailyDatamartEmail]    
  @EmailId int    
as    
begin    
   DECLARE   @Txn decimal,    
    @AFE decimal,     
    @AFCD decimal,    
    @AFCA decimal,    
    @HostM decimal,    
    @HostC decimal,     
    @HostA decimal,    
    @ErrMsg varchar(max),    
    @Subject varchar(50),    
    @Content varchar(max),    
    @Count int,    
    @file varchar(max),    
    @SQL varchar(2000),    
    @time varchar(20)    
    
 if @EmailId = 1    
 Begin    
  Select @time = convert(varchar,getdate(),108)    
  Select @time = substring(@time,1,5)    
    
  Select @Subject = 'LMS PICT Log_'+CONVERT(varchar,getdate(),112)    
    
  -- Select @file = 'E:\Cardtrend\Program\TectiaSFTP\Log\ActivityLog_'+CONVERT(varchar,getdate(),112)+'.log'      
  Select @file = 'D:\Cardtrend\PDBLMS\Logs\SFTP\Datamart\Datamart_'+CONVERT(varchar,getdate(),112)+'.log'    
    
  Select @SQL = 'BULK INSERT ld_DatamartLog FROM'+' '''+@file+''''    
      
  EXECUTE (@SQL)    
    
  INSERT INTO udiE_DatamartLog (String)    
  SELECT *    
  FROM  ld_DatamartLog    
  WHERE String like '%|%'    
    
  UPDATE a    
  SET a.FileName = SUBSTRING(String, 1, CASE CHARINDEX('|', String) WHEN 0 THEN LEN(String) ELSE CHARINDEX('|', String)-1 END)     
  FROM   udiE_DatamartLog a    
    
  UPDATE a    
  SET a.String = replace(a.string,a.filename + '|','')    
  from udiE_DatamartLog a    
    
  UPDATE a    
  SET a.Size = SUBSTRING(String, 1, CASE CHARINDEX('|', String) WHEN 0 THEN LEN(String) ELSE CHARINDEX('|', String)-1 END)     
  FROM   udiE_DatamartLog a    
    
  UPDATE a    
  SET a.String = replace(a.string,a.Size + '|','')    
  from udiE_DatamartLog a    
    
  UPDATE a    
  SET a.Speed = SUBSTRING(String, 1, CASE CHARINDEX('|', String) WHEN 0 THEN LEN(String) ELSE CHARINDEX('|', String)-1 END)     
  FROM   udiE_DatamartLog a    
    
  UPDATE a    
  SET a.String = replace(a.string,a.Speed + '|','')    
  from udiE_DatamartLog a    
    
  UPDATE a    
  SET a.TOC = SUBSTRING(String, 1, CASE CHARINDEX('|', String) WHEN 0 THEN LEN(String) ELSE CHARINDEX('|', String)-1 END)     
  FROM   udiE_DatamartLog a    
    
  UPDATE  a    
  SET a.String = SUBSTRING(FileName, 1, CASE CHARINDEX('_', FileName) WHEN 0 THEN LEN(FileName) ELSE CHARINDEX('_', FileName)-1 END)     
  FROM   udiE_DatamartLog a    
    
  UPDATE udiE_DatamartLog SET Ind = 1 WHERE substring(Filename,1,8) = 'LMS_TRXN'    
  UPDATE udiE_DatamartLog SET Ind = 1 WHERE substring(Filename,1,9) = 'AuditFile'    
  UPDATE udiE_DatamartLog SET Ind = 1 WHERE substring(Filename,1,4) = 'HOST'     
  DELETE from udiE_DatamartLog WHERE isnumeric(Ind) = 0  
  
  
  Select @Txn = CASE     
      WHEN Substring (a.Size, len(size)-1, 1) = 'K'THEN CAST(substring(a.Size,1,len(size)-2) as decimal) * 1000     
      WHEN Substring (a.Size, len(size)-1, 1) = 'M'THEN CAST(substring(a.Size,1,len(size)-2) as decimal) * 1000000    
      WHEN Substring (a.Size, len(size)-1, 1) = 'G'THEN CAST(substring(a.Size,1,len(size)-2) as decimal(5,1))*1000000000    
      WHEN Substring (a.Size, len(size)-1, 1) not in ('K','M','G') THEN CAST(substring(a.Size,1,len(size)-1) as decimal)     
                END    
        from udiE_DatamartLog a    
  WHERE substring(Filename,1,8) = 'LMS_TRXN'    
    
  Select @AFE = CASE     
      WHEN Substring (a.Size, len(size)-1, 1) = 'K'THEN CAST(substring(a.Size,1,len(size)-2) as decimal) * 1000     
      WHEN Substring (a.Size, len(size)-1, 1) = 'M'THEN CAST(substring(a.Size,1,len(size)-2) as decimal) * 1000000    
      WHEN Substring (a.Size, len(size)-1, 1) = 'G'THEN CAST(substring(a.Size,1,len(size)-2) as decimal(5,1))*1000000000    
      WHEN Substring (a.Size, len(size)-1, 1) not in ('K','M','G') THEN CAST(substring(a.Size,1,len(size)-1) as decimal)     
                END    
        from udiE_DatamartLog a    
  WHERE substring(Filename,1,11) = 'AuditFile_E'    
    
  Select @AFCD = CASE     
      WHEN Substring (a.Size, len(size)-1, 1) = 'K'THEN CAST(substring(a.Size,1,len(size)-2) as decimal) * 1000     
      WHEN Substring (a.Size, len(size)-1, 1) = 'M'THEN CAST(substring(a.Size,1,len(size)-2) as decimal) * 1000000    
      WHEN Substring (a.Size, len(size)-1, 1) = 'G'THEN CAST(substring(a.Size,1,len(size)-2) as decimal(5,1))*1000000000    
      WHEN Substring (a.Size, len(size)-1, 1) not in ('K','M','G') THEN CAST(substring(a.Size,1,len(size)-1) as decimal)     
                END    
        from udiE_DatamartLog a    
  WHERE substring(Filename,1,15) = 'AuditFile_CardD'    
            
        Select @AFCA = CASE     
      WHEN Substring (a.Size, len(size)-1, 1) = 'K'THEN CAST(substring(a.Size,1,len(size)-2) as decimal) * 1000     
      WHEN Substring (a.Size, len(size)-1, 1) = 'M'THEN CAST(substring(a.Size,1,len(size)-2) as decimal) * 1000000    
      WHEN Substring (a.Size, len(size)-1, 1) = 'G'THEN CAST(substring(a.Size,1,len(size)-2) as decimal(5,1))*1000000000    
      WHEN Substring (a.Size, len(size)-1, 1) not in ('K','M','G') THEN CAST(substring(a.Size,1,len(size)-1) as decimal)     
                END    
        from udiE_DatamartLog a    
  WHERE substring(Filename,1,15) = 'AuditFile_CardA'    
    
  Select @HostM = CASE     
      WHEN Substring (a.Size, len(size)-1, 1) = 'K'THEN CAST(substring(a.Size,1,len(size)-2) as decimal) * 1000     
      WHEN Substring (a.Size, len(size)-1, 1) = 'M'THEN CAST(substring(a.Size,1,len(size)-2) as decimal) * 1000000    
      WHEN Substring (a.Size, len(size)-1, 1) = 'G'THEN CAST(substring(a.Size,1,len(size)-2) as decimal(5,1))*1000000000    
      WHEN Substring (a.Size, len(size)-1, 1) not in ('K','M','G') THEN CAST(substring(a.Size,1,len(size)-1) as decimal)     
                END    
        from udiE_DatamartLog a    
  WHERE substring(Filename,1,6) = 'HOST M'    
    
  Select @HostC = CASE     
      WHEN Substring (a.Size, len(size)-1, 1) = 'K'THEN CAST(substring(a.Size,1,len(size)-2) as decimal) * 1000     
      WHEN Substring (a.Size, len(size)-1, 1) = 'M'THEN CAST(substring(a.Size,1,len(size)-2) as decimal) * 1000000    
      WHEN Substring (a.Size, len(size)-1, 1) = 'G'THEN CAST(substring(a.Size,1,len(size)-2) as decimal(5,1))*1000000000    
      WHEN Substring (a.Size, len(size)-1, 1) not in ('K','M','G') THEN CAST(substring(a.Size,1,len(size)-1) as decimal)     
                END    
        from udiE_DatamartLog a    
  WHERE substring(Filename,1,6) = 'HOST C'    
    
     Select @HostA = CASE     
      WHEN Substring (a.Size, len(size)-1, 1) = 'K'THEN CAST(substring(a.Size,1,len(size)-2) as decimal) * 1000     
      WHEN Substring (a.Size, len(size)-1, 1) = 'M'THEN CAST(substring(a.Size,1,len(size)-2) as decimal) * 1000000    
      WHEN Substring (a.Size, len(size)-1, 1) = 'G'THEN CAST(substring(a.Size,1,len(size)-2) as decimal(5,1))*1000000000    
      WHEN Substring (a.Size, len(size)-1, 1) not in ('K','M','G') THEN CAST(substring(a.Size,1,len(size)-1) as decimal)     
  END    
        from udiE_DatamartLog a    
  WHERE substring(Filename,1,6) = 'HOST A'    
      
     select @ErrMsg = ''    
            
    
  select @Count = Count(*) from udiE_DatamartLog     
  if @Count < 5 select @ErrMsg = '|ERROR : Missing File' --rowcount < 5    
  if dateName(dw,getdate()) = 'Wednesday' and  @count < 7 select @ErrMsg = @ErrMsg + '|ERROR : Missing File'----rowcount < 7     
  if @Txn < 50000000 select @ErrMsg = @ErrMsg + '|ALERT : Transaction file is too small'    
  if @AFE < 300000 select @ErrMsg = @ErrMsg + '|ALERT : AuditFile_Entity file is too small'    
  if @AFCD < 1000000000 select @ErrMsg = @ErrMsg + '|ALERT : AuditFile_CardDatefile is too small'    
  if @AFCA < 60000 select @ErrMsg = @ErrMsg + '|ALERT : Auditfile_CardAudit is too small'    
  if @HostM < 300000 select @ErrMsg = @ErrMsg + '|ALERT : Host Merchant File is too small'    
  if @HostC < 3000000000 select @ErrMsg = @ErrMsg + '|ALERT : Host CardData File is too small'    
  if @HostA < 3000000000 select @ErrMsg = @ErrMsg + '|ALERT : Host AccountData is too small'    
    
  if datalength(@ErrMsg) > 1 Select @Subject = 'LMS PICT Log_'+CONVERT(varchar,getdate(),112) + '_ERROR!!'   --Humairah 20150402    
    
    
  
  Set @Content =  N'Dear Team,'+    
      N'<br>' +    
      N'<br>' +    
      N'Today''s file upload summary :'+    
         N'<br>' +    
      N'<br>' +    
      N'<table border="1">' +    
      N'<th>FileName</th><th>Size</th>' +    
      CAST ( ( SELECT td = Filename, '',    
          td = Size, ''    
         FROM udiE_DatamartLog     
        FOR XML PATH('tr'), TYPE     
      ) AS NVARCHAR(MAX) ) +    
      N'</table>'+    
                        N'<br>'+    
      N'<br>'+    
                        N'<font color=''red''>'+@ErrMsg+'</font>'+    
      N'<br>'+    
      N'<br>'+    
      N'Kindly receive the attached log file'+    
         N'<br>'+    
      N'<br>'+    
      N'Contact Person  : Office(03-7728 8380), Humairah(019-233 5034)'+    
         N'<br>'+    
      N'<br>';    
      
  
  If @time = '13:00'    
  Begin             
   EXEC msdb..sp_send_dbmail @profile_name='Kad Mesra',    
   @recipients='humairah@cardtrend.com;chengchai.tan@cardtrend.com;helpdesk@cardtrend.com;ERMY-CardtrendOperations@edenred.com',    
   @subject= @subject,    
   @body= @Content,    
   @body_format= 'HTML'--, @file_attachments= @file    
             
   truncate table ld_DatamartLog    
   truncate table udie_DatamartLog    
  End    
    
    
  If @time = '15:30'   
  Begin       
   EXEC msdb..sp_send_dbmail @profile_name='Kad Mesra',    
   @recipients='husni.husin@petronas.com.my;  
    amirah.ibrahim@petronas.com.my;  
    mkhidirkhairy.jalil@petronas.com.my;  
    rahman.yusoffa@petronas.com.my;  
    ishwandi.akadir@petronas.com.my;  
    hidayah.khalid@petronas.com.my;  
    ariffin.hussin@petronas.com.my;  
    {PET-ICTPDBIT}@petronas.com.my;  
    norliana.akarim@petronas.com.my;  
    humairah@cardtrend.com;  
    helpdesk@cardtrend.com;  
    ERMY-CardtrendOperations@edenred.com',    
   @subject= @subject,    
   @body= @Content,    
   @body_format= 'HTML'--, @file_attachments= @file    
    
   truncate table ld_DatamartLog    
   truncate table udie_DatamartLog      
  End    
 Else     
  Begin    
   truncate table ld_DatamartLog    
   truncate table udie_DatamartLog     
  End    
     
 End   
  
--End email id = 1    
    
    
    
 if @EmailId = 2    
 Begin    
  Select @time = convert(varchar,getdate(),108)    
  Select @time = substring(@time,1,5)    
      
  if exists (select 1 from ld_SMSFLog) truncate table ld_SMSFLog    
  if exists (select 1 from udie_SMSFLog) truncate table udie_SMSFLog    
    
  Select @Subject = 'SMS FILE UPLOAD '+CONVERT(varchar,getdate(),112)    
      
  --Select @file = 'E:\Cardtrend\Program\WinSCP\SMSF.log'    
  Select @file = 'D:\Cardtrend\PDBLMS\Logs\SFTP\SMS\SMS_'+CONVERT(varchar,getdate(),112)+'.log'    
   
  Select @SQL = 'BULK INSERT ld_SMSFLog FROM'+' '''+@file+''''    
    
  EXECUTE (@SQL)    
    
  INSERT INTO udie_SMSFLog (String)    
  Select * from ld_SMSFLog     
  where     
  --String like 'E:\Cardtrend\Data\SMS\Redemption_'+CONVERT(varchar(8),getdate()-1,112)+'%'     
  --or String like 'E:\Cardtrend\Data\SMS\Cancellation_'+CONVERT(varchar(8),getdate()-1,112)+'%'    
  String like 'D:\Cardtrend\PDBLMS\Files\SMS\Redemption_'+CONVERT(varchar(8),getdate()-1,112)+'%'     
  or String like 'D:\Cardtrend\PDBLMS\Files\SMS\Cancellation_'+CONVERT(varchar(8),getdate()-1,112)+'%'    
    
  UPDATE a    
  SET a.FileName = SUBSTRING(String, 23,CHARINDEX('|', String)-23)     
  FROM udie_SMSFLog a    
    
  UPDATE a    
  SET a.String = replace(a.string,'D:\Cardtrend\PDBLMS\Files\SMS\'+ a.filename + '|','')    
  from udie_SMSFLog a    
    
  UPDATE a    
  SET a.Size = SUBSTRING(String, 1, CASE CHARINDEX('|', String) WHEN 0 THEN LEN(String) ELSE CHARINDEX('|', String)-1 END)     
  FROM  udie_SMSFLog a    
    
  UPDATE a    
  SET a.String = replace(a.string,a.Size + '|','')    
  from udie_SMSFLog a    
    
  UPDATE a    
  SET a.UploadSpeed = SUBSTRING(String, 1, CASE CHARINDEX('|', String) WHEN 0 THEN LEN(String) ELSE CHARINDEX('|', String)-1 END)     
  FROM udie_SMSFLog a    
    
  UPDATE a    
  SET a.String = replace(a.string,a.UploadSpeed + '|','')    
  from udie_SMSFLog a    
    
  UPDATE a    
  SET a.String = replace(a.string,'binary |','')    
  from udie_SMSFLog a    
    
  UPDATE a    
  SET a.UploadSts = SUBSTRING(String, 1, CASE CHARINDEX('|', String) WHEN 0 THEN LEN(String) ELSE CHARINDEX('|', String)-1 END)     
  FROM udie_SMSFLog a    
    
  UPDATE  a    
  SET a.String = SUBSTRING(FileName, 1, CASE CHARINDEX('_', FileName) WHEN 0 THEN LEN(FileName) ELSE CHARINDEX('_', FileName)-1 END)     
  FROM  udie_SMSFLog a    
    
  Set @Content =  N'Dear Team,'+    
      N'<br>' +    
      N'<br>' +    
      N'Today''s SMS file upload summary :'+    
         N'<br>' +    
      N'<br>' +    
      N'<table border="1">' +    
      N'<th>FileName</th><th>Size</th><th>Upload Status</th>' +    
      CAST ( ( SELECT td = Filename, '',    
          td = Size, '',    
          td = UploadSts, ''    
         FROM udie_SMSFLog     
        FOR XML PATH('tr'), TYPE     
      ) AS NVARCHAR(MAX) ) +    
      N'</table>'+    
                        N'<br>'+    
      N'<br>'+    
      N'<br>'+    
      N'Contact Person : Office(03-7728 8380)'+    
         N'<br>'+    
      N'<br>';    
     
  If @time = '12:30'    
  Begin             
   EXEC msdb..sp_send_dbmail @profile_name='Kad Mesra',    
   @recipients='humairah@cardtrend.com;helpdesk@cardtrend.com',    
   @subject= @subject,    
   @body= @Content,    
   @body_format= 'HTML'    
             
   truncate table ld_SMSFLog    
   truncate table udie_SMSFLog    
  End    
    
          
  If @time = '14:30'    
  Begin       
   EXEC msdb..sp_send_dbmail @profile_name='Kad Mesra',    
   @recipients='sabil.sahimi@petronas.com.my;syazani@cardtrend.com;humairah@cardtrend.com;helpdesk@cardtrend.com',    
   @subject= @subject,    
   @body= @Content,    
   @body_format= 'HTML'    
    
   truncate table ld_SMSFLog    
   truncate table udie_SMSFLog    
  End    
    
  Else     
  Begin    
   truncate table ld_SMSFLog    
   truncate table udie_SMSFLog     
  End    
    
 End   
   
 -- End email id = 2    
end
GO
