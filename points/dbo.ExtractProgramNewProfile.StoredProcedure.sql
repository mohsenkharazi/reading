USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ExtractProgramNewProfile]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/*************************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure is to 

SP Level	: Primary

Calling By	: 

--------------------------------------------------------------------------------------------------------------------------
When	   Who		CRN		Desc
--------------------------------------------------------------------------------------------------------------------------
2013/07/07 Developer		Initial development
**************************************************************************************************************************/
--exec ExtractProgramNewProfile 1, 2828,1
--exec ExtractProgramNewProfile 1, 2812,2
CREATE PROCEDURE [dbo].[ExtractProgramNewProfile]
	@IssNo uIssNo,
	@PrcsId uPrcsId
as
begin
	declare
		@rc int,
		@BatchId uBatchId,
		@PrcsDate datetime,
		@PrcsName varchar(50),
		@StartDate date,
		@EndDate date

	SET NOCOUNT ON
	--------------------------------------------------------------------------------------------------------------------
	--------------------------------- RETRIEVES NECESSARY INFORMATION FOR PROCESSING -----------------------------------
	--------------------------------------------------------------------------------------------------------------------
	-- Retrieve Billing Settings --------------------------------------------------------------------------------------

	select @PrcsDate = PrcsDate
	from cmnv_ProcessLog (nolock)
	where PrcsId = @PrcsId

	if DATEPART (DD, @PrcsDate) = 1 -- card activated from 16th to last day of previous month
	begin		
		select @EndDate = DATEADD(s,-1,DATEADD(mm, DATEDIFF(m,0,@PrcsDate),0))
		select @StartDate =DATEFROMPARTS ( DATEPART(YYYY,@EndDate), DATEPART(MM,@EndDate), 16)
	end 
	
	else if  DATEPART (DD, @PrcsDate) = 16 -- card activated from 1st to 15th of the month
	begin		
		select @StartDate =DATEADD(mm,DATEDIFF(mm,0,@PrcsDate),0) 
		select @EndDate = DATEFROMPARTS ( DATEPART(YYYY,@StartDate), DATEPART(MM,@StartDate), 15)
	end 

	else
	begin
		return 95409	--	Invalid Data
	end 

	--select @PrcsDate,@StartDate, @EndDate

	--------------------------------------------------------------------------------------------------------------------
	------------------------------------------- DATA EXTRACTION ----------------------------------------------
	--------------------------------------------------------------------------------------------------------------------
	-- Details data 
	select  identity (int,1,1) as 'Id', 
			'D' 
			+ ',' + cast(ROW_NUMBER()over (order by a.CardNo) as nvarchar)
			+ ',' + substring(isnull(c.FamilyName,''), 1,50)
			+ ',' + case when c.NewIc is not null then '1' when c.PassportNo is not null then '2' when c.OldIc is not null then '3'  else '' end--IdType
			+ ',' + cast(replace(isnull(isnull(isnull( c.NewIc,  c.PassportNo) , c.OldIc),''),'-','') as nvarchar(12))--IdNumber
			+ ',' + cast(isnull(isnull(e.refcd, d.refcd),'') as nvarchar(4))--ContcatType
			+ ',' + cast(isnull(isnull(e.ContactNo, d.ContactNo),'') as nvarchar(11))--ContactNumber			
			--+ ',' + substring(cast(a.CardNo as nvarchar(17)), 14,4)--MesraCardNumber 		
			+ ',' + cast(a.CardNo as nvarchar(17))--MesraCardNumber 
			+ ',' + substring(isnull(f.EmailAddr,''), 1,50)--EmailAddress 
			as 'String'
	into #myData
	from iac_Card a (nolock) 
	join iac_Account b (nolock) on b.AcctNo = a.AcctNo 
	join iac_Entity c (nolock) on c.EntityId = b.EntityId  
	left outer join iss_Contact d (nolock) on d.RefTo = 'ENTT' and d.RefKey = c.EntityId  and d.Refcd in (10) and d.ContactNo is not null
	left outer join iss_Contact e (nolock) on e.RefTo = 'ENTT' and e.RefKey = c.EntityId  and e.Refcd in (11) and e.ContactNo is not null
	left outer join iss_Contact f (nolock) on f.RefTo = 'ENTT' and f.RefKey = c.EntityId  and f.Refcd = 13 and f.EmailAddr is not null
	where a.Sts = 'A' and  a.ActivationDate  is not null and cast(a.ActivationDate as date) >= @StartDate and cast(a.ActivationDate as date) <=@EndDate

	--Full Extraction
	select 'H,NewProfile,PETRONAS,' + convert(varchar(8),@PrcsDate,112) 

	union all 

	select String from #myData 
	
	union all 

	select 'T,' + cast(isnull(max(Id),0) as varchar(10))
	from #myData

end
GO
