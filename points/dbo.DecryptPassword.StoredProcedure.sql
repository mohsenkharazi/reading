USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[DecryptPassword]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
declare @DecryptedPw varchar(500)
exec [DecrypttPassword] 'RHKaxjWz6UsOuD0boWf3DA==',@DecryptedPw output
select @DecryptedPw
*/

CREATE PROCEDURE [dbo].[DecryptPassword]  
	@Pw varchar(100),
	@DecryptedPw varchar(500) OUTPUT
AS
BEGIN 
	Declare @xmlOut varchar(8000)
	Declare @RequestText as varchar(8000);
	set @RequestText=
	'<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
	 <soap:Body>
	 <HSMDecrypt xmlns="http://tempuri.org/">
      <input>'+@Pw+'</input>
	</HSMDecrypt>
	</soap:Body>
	</soap:Envelope>'
	exec spHTTPRequest 
	'http://172.22.52.4:1354/EmailAPI/msite/Service.asmx', 
	'POST', 
	@RequestText,
	'http://tempuri.org/HSMDecrypt',
	'', '', @xmlOut out

	set @DecryptedPw = @xmlOut
END
GO
