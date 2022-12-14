USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[DailyBatchFileEmail]    Script Date: 9/6/2021 10:33:55 AM ******/
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
2016/12/4  Humairah   Initial Development  
*******************************************************************************/  
/*  
declare @rc int  
exec @rc = DailyBatchFileEmail 1  
select @rc  
select top 10 send_request_date, * from msdb.dbo.sysmail_sentitems order by sent_date desc  

*/  
CREATE procedure [dbo].[DailyBatchFileEmail]  
  @EmailId int  
as  
begin  
   DECLARE   @Txn decimal,  
    @ErrMsg varchar(max),  
    @Subject varchar(50),  
    @Content varchar(max),  
    @Count int,  
    @file varchar(max),  
    @SQL varchar(2000),  
    @time varchar(20),
	@recipients varchar (200),
	@Date varchar(8)
  
	 if @EmailId = 1  
		 BEGIN  
				CREATE TABLE #ld_BatchFilesLog( String nvarchar(1000))

				select @Date = convert(varchar(8), getdate(), 112) 
				Select @recipients='ermy-cardtrendoperations@edenred.com;humairah@cardtrend.com;chengchai.tan@cardtrend.com'
				Select @Subject = 'LMS Batch Files Activity Summary -'+CONVERT(varchar,getdate(),112)  
				Select @file = 'D:\Cardtrend\PDBLMS\Logs\SFTP\ActivityLog\ActivityLog_'+@Date+'.log'  
				-- Select @file = 'E:\Cardtrend\Program\TectiaSFTP\Log\ActivityLog_'+@Date+'.log'  
				Select @SQL = 'BULK INSERT #ld_BatchFilesLog FROM'+' '''+@file+''''  

				EXECUTE (@SQL)  
				
				alter table #ld_BatchFilesLog add FileName nvarchar(200)
				alter table #ld_BatchFilesLog add Size nvarchar(50)
				alter table #ld_BatchFilesLog add Speed nvarchar(50)
				alter table #ld_BatchFilesLog add TOC nvarchar(50)

				delete from #ld_BatchFilesLog where String not like '%|%'
				delete from #ld_BatchFilesLog where String is NULL
				
				update #ld_BatchFilesLog set [FileName] =  SUBSTRING(String, 1, CASE CHARINDEX('|', String) WHEN 0 THEN LEN(String) ELSE CHARINDEX('|', String)-1 END) where String like '%|%'
				update #ld_BatchFilesLog set String = replace(string,[filename] + '|','')  

				update #ld_BatchFilesLog set [Size] =  SUBSTRING(String, 1, CASE CHARINDEX('|', String) WHEN 0 THEN LEN(String) ELSE CHARINDEX('|', String)-1 END) where String like '%|%'
				update #ld_BatchFilesLog set String = replace(string,[Size] + '|','') 
				
				select ltrim(rtrim(FileName))'FileName', ltrim(rtrim(Size))'Size' into ld_BatchFilesLog from #ld_BatchFilesLog  -- order by  FileName				
				alter table ld_BatchFilesLog add Id int identity (1,1)


				 Set @Content =  N'Dear Team,'+  
				  N'<br>' +  
				  N'<br>' +  
				  N'Today''s file upload/download summary :'+  
					 N'<br>' +  
				  N'<br>' +  
				  N'<table border="1">' +  
				  N'<th>Id</th><th>FileName</th><th>Size</th>' +  
				  CAST ( ( SELECT	td = Id, '',  
									td = Filename, '',  
									td = Size, ''  
							FROM ld_BatchFilesLog  order by Id
							FOR XML PATH('tr'), TYPE   
							) AS NVARCHAR(MAX) 
						) +  
				  N'</table>'+  
				  N'<br>'+  
				  N'<br>'+  
				  N'Kindly receive the attached log file'+  
					 N'<br>'+  
				  N'<br>'+  
				  N'<br>';  

    

				  Begin           
				   EXEC msdb..sp_send_dbmail  
					@profile_name='Kad Mesra',  
					@recipients=@recipients, 
					@subject= @subject,  
					@body= @Content,  
					@body_format='HTML',  
					@file_attachments= @file 
							        
					if @@error <> 0 or @@rowcount = 0
						begin
							select 'Send Email Failed'
						end 
						else 
						begin 	
							select * from ld_BatchFilesLog					
							select 'Email sent to ' + @recipients
						end

				   drop table ld_BatchFilesLog  
				   End  

		END
end
GO
