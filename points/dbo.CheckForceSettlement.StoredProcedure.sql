USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CheckForceSettlement]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/*************************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)

Objective	: This stored procedure is to 

SP Level	: Primary

Calling By	: 

--------------------------------------------------------------------------------------------------------------------------
When	   Who		CRN		Desc
--------------------------------------------------------------------------------------------------------------------------
2019/05/27 Adi				Initial development
**************************************************************************************************************************/

CREATE PROCEDURE [dbo].[CheckForceSettlement]
	@IssNo uIssNo
AS
--with encryption as
BEGIN
	
	SET NOCOUNT ON

	DECLARE @PrcsId BIGINT,
		@PrcsDate DATETIME,
		@xml NVARCHAR(MAX),
		@body NVARCHAR(MAX)

	SELECT @PrcsId = max(PrcsId), @PrcsDate = max(PrcsDate) FROM cmnv_processlog (NOLOCK) 

	SELECT 
		TFS.Id, TFS.SettlementTypeId, TFS.HostCount, TFS.HostAmount,
		BL.BackendBusinessLocationId, D.BackendDeviceId
	INTO #ForceSettlement
	FROM [Demo_lms_iAuth].[txn_TransactionForceSettlement] TFS
	JOIN [Demo_lms_iAuth].[acq_BusinessLocation] BL ON BL.Id = TFS.BusinessLocationId
	JOIN [Demo_lms_iAuth].[acq_Device] D ON D.Id = TFS.DeviceId
	WHERE CONVERT(VARCHAR,TFS.CreationDate,112) = @PrcsDate

	IF (SELECT COUNT(1) FROM #ForceSettlement) = 0
	BEGIN
		SET @body = '
		<html>
			<body>
				<H2 style = "color:red">No Force Settlement?</H2>
				<style> table, th, td { border: 1px solid black; border-collapse: collapse;}</style>
				<p> Dear Team, </p>
				<p> There is no force settlement triggered. Is the services running? or... ? </p>
			</body>
		</html>
		'

		GOTO SendMail
	END

	SET @xml = CAST((
		SELECT 
			Id AS 'td', '',
			SettlementTypeId AS 'td', '',
			HostCount AS 'td', '',
			HostAmount AS 'td', '',
			BackendBusinessLocationId AS 'td', '',
			BackendDeviceId AS 'td', ''
		FROM #ForceSettlement a
		WHERE NOT EXISTS (	SELECT 1 FROM atx_Settlement b (NOLOCK) 
							WHERE b.PrcsId = @PrcsId 
								AND b.BusnLocation = a.BackendBusinessLocationId
								AND b.TermId = a.BackendDeviceId
								AND b.LinkIds = a.Id)
		FOR XML PATH('tr'), ELEMENTS) AS NVARCHAR(MAX))

	IF ISNULL(@xml, '') <> ''
	BEGIN
		SET @body = '
		<html>
			<body>
				<H2 style = "color:red">Unposted Force Settlement Found!</H2>
				<style> table, th, td { border: 1px solid black; border-collapse: collapse;}</style>
				<p> Dear Team, </p>
				<p> Unposted settlement as below:</p>
				<br>
				<table>
				<tr>
					<th bgcolor = #5DA1C8> Settlement Id  </th>
					<th bgcolor = #5DA1C8> Settlement Type Id  </th>
					<th bgcolor = #5DA1C8> Count </th>
					<th bgcolor = #5DA1C8> Amount </th>
					<th bgcolor = #5DA1C8> Business Location Id  </th>
					<th bgcolor = #5DA1C8> Terminal Id </th>
				 </tr>
				 ' + @xml + '
				</table>
			</body>
		</html>
		'

		GOTO SendMail
	END	

	SendMail:
		exec msdb.dbo.sp_send_dbmail  
			@profile_name = 'Kad Mesra',  
			@recipients = 'support@cardtrend.com',  
			@subject = 'LMS - Unposted Force Settlement',  
			@body = @body,  
			@body_format= 'HTML'

	DROP TABLE #ForceSettlement

	RETURN 0

END
GO
