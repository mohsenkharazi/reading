USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MonthlyPartnerPtsExpiryEmail]    Script Date: 9/6/2021 10:33:55 AM ******/
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
20160429	Azan			Initial Development 
20190618	Humairah		Change table name from ads_Job to email_Job
							Insert CTS Emailer path to iss default
*******************************************************************************/
--EXEC MonthlyPartnerPtsExpiryEmail 1
CREATE PROCEDURE [dbo].[MonthlyPartnerPtsExpiryEmail]
	@IssNo uIssNo
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @ExpiryDate varchar(10),
			@ActiveSts uRefCd,
			@Content varchar(MAX),
			@Count int,
			@Max int,
			@EmailerPath nvarchar(100)

	SELECT @ExpiryDate	= CONVERT(varchar(10),DATEADD(s,-1,DATEADD(mm,DATEDIFF(m,0,GETDATE())+2,0)),6)  
	SELECT @ActiveSts	= VarcharVal FROM iss_default (nolock) WHERE Deft = 'ActiveSts'	
	SELECT @EmailerPath = VarcharVal FROM iss_Default(nolock) WHERE Deft = 'DeftCTSEmailerPath'
	SELECT @Count		= 1

	CREATE TABLE #PointsAgeing
	(
		id int identity(1,1),
		AcctNo bigint,
		FamilyName varchar(100),
		EmailAddr varchar(100),
		Pts int,
		ExpiryDate datetime
	)

	INSERT #PointsAgeing (AcctNo,FamilyName,EmailAddr,Pts,ExpiryDate)
	SELECT f.AcctNo,c.FamilyName,g.EmailAddr,cast(sum(f.Pts) as int)'Pts',@ExpiryDate 
	FROM iac_Account a (nolock)
	join iac_Card b (nolock) on a.AcctNo = b.AcctNo
	join iac_Entity c (nolock) on a.EntityId = c.EntityId  
	join iss_Contact g (nolock) on c.EntityId = g.RefKey
	join iss_CardType d (nolock) on b.CardType = d.CardType
	join iss_PlasticType e (nolock) on a.PlasticType = e.PlasticType 
	join iacv_PointsAgeing f (nolock) on a.AcctNo = f.AcctNo and e.PtsAgeingPeriod = f.AgeingInd 
	WHERE d.CardRangeId = 'PTSTRD' and a.Sts = @ActiveSts and b.Sts = @ActiveSts and g.RefTo = 'ENTT' and g.RefCd =13
	GROUP BY f.AcctNo,c.FamilyName,g.EmailAddr
	HAVING sum(f.pts)>0

	SELECT @Max = max(Id) FROM #PointsAgeing

	WHILE @Count <=  @Max 
	BEGIN
		INSERT email_Job(ContentId,Rcpt,ParamValue,StartDate,InputSrc,Sts,UserId,CreationDate)
		SELECT 1,EmailAddr,FamilyName+'|'+cast(AcctNo as varchar(10))+'|'+cast(Pts as varchar(20))+'|'+cast( convert(varchar(10),ExpiryDate,103) as varchar(10)),getdate(),'system','P',system_user,getdate() FROM #PointsAgeing WHERE Id = @Count
		
		IF @@rowcount = 0
		BEGIN
			RETURN 70264
		END
		
		SELECT @Count = @Count + 1
	END	

	EXEC master..xp_cmdshell @EmailerPath

	DROP TABLE #PointsAgeing
END
GO
