USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[EncryptPassword]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
declare @EncryptedPw varchar(100)
exec [EncryptPassword] '1234abcd#',@EncryptedPw output
select @EncryptedPw
*/
CREATE PROCEDURE [dbo].[EncryptPassword]  
	@Pw varchar(100),
	@EncryptedPw varchar(100) OUTPUT
AS
BEGIN 
	Declare @xmlOut varchar(8000)
	Declare @RequestText as varchar(8000);
	set @RequestText=
	'<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
	  <soap:Body>
		<HSMEncrypt xmlns="http://tempuri.org/">
		  <input>'+@Pw+'</input>
		</HSMEncrypt>
	  </soap:Body>
	</soap:Envelope>'
	exec spHTTPRequest 
	'http://172.22.52.4:1354/EmailAPI/msite/Service.asmx', 
	'POST', 
	@RequestText,
	'http://tempuri.org/HSMEncrypt',
	'', '', @xmlOut out

	set @EncryptedPw = substring(@xmlOut,charindex('<HSMEncryptResult>',@xmlOut)+len('<HSMEncryptResult>'),24)
END
GO
