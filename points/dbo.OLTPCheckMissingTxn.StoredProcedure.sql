USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[OLTPCheckMissingTxn]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:OLTP

Objective	:Check missing transaction
------------------------------------------------------------------------------------------
When		Who		CRN	Description
------------------------------------------------------------------------------------------
2007/10/08	Darren		   	Initial development
*****************************************************************************************/

CREATE procedure [dbo].[OLTPCheckMissingTxn]
	@TxnDate datetime,
	@ListInd char(1) = 'N'
	
  as
begin	
	set nocount on
		
	BEGIN TRY
		 drop table test..atx_OnlineLog 
	END TRY
	BEGIN CATCH     
	END CATCH;

	declare @MinIds bigint, 
			@MaxIds bigint,
			@StartDate datetime,
			@EndDate datetime

	-------------------------------------
	-- Generate Log condition
	-------------------------------------

	select @StartDate = cast(convert(varchar(20), @TxnDate, 102) as datetime)
	select @EndDate = left(convert(varchar(20), @StartDate, 120) , 10) + ' 23:59:59:599'
	
	select @MinIds = min(Ids) 
	from atx_OnlineLog (nolock) 
	where LastUpdDate >= @StartDate

	select @MaxIds = max(Ids) 
	from atx_OnlineLog (nolock) 
	where LastUpdDate <= @EndDate

--	select @MinIds = @MinIds - 1, @MaxIds = @MaxIds + 1
	
--	select @LogMinIds '@LogMinIds', @LogMaxIds '@LogMaxIds', @StartDate '@StartDate', @EndDate '@EndDate'

	-------------------------------------
	-- Generate temp table
	-------------------------------------
	
	select Ids, LastUpdDate 
	into test..atx_OnlineLog 
	from atx_OnlineLog (nolock) where Ids >= @MinIds and Ids <= @MaxIds	

	-------------------------------------
	-- Check missing txn
	-------------------------------------
	
	declare @CurrIds bigint,			
			@Count int,
			@Cnt int,
			@TotalMissTxn bigint

	select @Count = @MaxIds - @MinIds, @CurrIds = @MinIds, @Cnt = 1
	
	create table #tmp1 (
		SeqId bigint not null,
		Ids bigint,
		LastUpdDate datetime,
		Sts char(1) 
	)
	
	while @Cnt < @Count
	begin
		
		insert #tmp1 (SeqId, Sts)
		values (@CurrIds, 'X')

		select @CurrIds = @CurrIds + 1
		select @cnt = @cnt + 1

	end

	update a set 
		Ids = b.Ids, 
		LastUpdDate = b.LastUpdDate, Sts = 1
	from #tmp1 a 
	join test..atx_onlinelog b (nolock) on b.ids = a.seqid

	if @ListInd = 'N'
	begin
		select isnull(count(*),0) 'TotalMissTxn'
		from #tmp1 
		where sts = 'X'
	end
	else
	begin
		select *
		from #tmp1 
		where sts = 'X' order by ids
	end

	set nocount off

end
SET QUOTED_IDENTIFIER OFF
GO
