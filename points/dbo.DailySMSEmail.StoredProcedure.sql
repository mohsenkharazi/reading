USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[DailySMSEmail]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:

Objective	: Datamart log mail

-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2015/09/08 	Humairah		Initial Development
*******************************************************************************/
/*
declare @rc int
exec @rc = DailySMSEmail 1
select @rc

@EmailId : 1 for datamart files 2 for SMS files
*/
CREATE procedure [dbo].[DailySMSEmail]
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


		Select @time = convert(varchar,getdate(),108)
		Select @time = substring(@time,1,5)
		
		if exists (select 1 from ld_SMSFLog) truncate table ld_SMSFLog
		if exists (select 1 from udie_SMSFLog) truncate table udie_SMSFLog

        Select @Subject = 'SMS FILE UPLOAD '+CONVERT(varchar,getdate(),112)
		
		Select @file = 'E:\Cardtrend\Program\WinSCP\SMSF.log'

		Select @SQL = 'BULK INSERT ld_SMSFLog FROM'+' '''+@file+''''

		EXECUTE (@SQL)

	    INSERT INTO udie_SMSFLog (String)
		Select * from ld_SMSFLog 
		where 
		String like 'E:\Cardtrend\Data\SMS\Redemption_'+CONVERT(varchar(8),getdate()-1,112)+'%' 
		or String like 'E:\Cardtrend\Data\SMS\Cancellation_'+CONVERT(varchar(8),getdate()-1,112)+'%'

		UPDATE a
		SET a.FileName = SUBSTRING(String, 23,CHARINDEX('|', String)-23) 
		FROM udie_SMSFLog a

		UPDATE a
		SET a.String = replace(a.string,'E:\Cardtrend\Data\SMS\'+ a.filename + '|','')
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
						N'Contact Person : Azan(0145371897), Office(03-7728 8380)'+
					    N'<br>'+
						N'<br>';
	
        If @time = '14:51'
		Begin									
			EXEC msdb..sp_send_dbmail @profile_name='Kad Mesra',
			@recipients='syazani@cardtrend.com;humairah@cardtrend.com;helpdesk@cardtrend.com',
			@subject= @subject,
			@body= @Content,
			@body_format= 'HTML'
	        
			truncate table ld_SMSFLog
			truncate table udie_SMSFLog

select 'a'
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
select 'b'
		End

		Else 
		Begin
			truncate table ld_SMSFLog
			truncate table udie_SMSFLog	
		End	
end
GO
