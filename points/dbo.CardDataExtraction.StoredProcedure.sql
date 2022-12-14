USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardDataExtraction]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure will extract card data (for PDB data mining)

------------------------------------------------------------------------------------------------------------------
When	   Who		CRN		Desc
------------------------------------------------------------------------------------------------------------------
2009/07/27 Chew Pei			Initial Development

******************************************************************************************************************/
/*
exec CardDataExtraction 1, 5
*/
CREATE	procedure [dbo].[CardDataExtraction] 
	@IssNo uIssNo,
	@PrcsId uPrcsId = null
  as
begin
	declare @Rc int, @BatchId uBatchId
	declare @PrcsDate datetime, @FileSeq int

	set nocount on
	
	if @PrcsId is null 
	begin
		select @PrcsId = CtrlNo,
				@PrcsDate = CtrlDate
		from iss_Control
		where IssNo = @IssNo and CtrlId = 'PrcsId'

		if @@rowcount = 0 or @@error <> 0 return 1
	end
	else
	begin
		select @PrcsDate = PrcsDate
		from cmnv_ProcessLog
		where IssNo = @IssNo and PrcsId = @PrcsId		
	end

	if exists (select 1 from udi_Batch where PrcsId = @PrcsId and SrcName ='HOST' and [FileName] ='CARDDATA')
	begin
		return 2
	end

	if (select count(*) from udiE_Card) > 0
	begin
		truncate table udiE_Card
		if @@error <> 0 return 2
	end

	select @FileSeq = isnull(max(FileSeq), 0)	-- Get the last file sequence
	from udi_Batch
	where IssNo = @IssNo and SrcName = 'HOST' and FileName = 'CARDDATA'
	
	if @@error <> 0 return 2

	exec @BatchId = NextRunNo @IssNo, 'INSBatchId'

	-----------------
	BEGIN TRANSACTION
	-----------------
	insert into udie_Card
		(IssNo, BatchId, AcctNo, CardNo, Title, Nationality, FamilyName, NewIc, PassportNo, Dob, Gender, Race, PrefLanguage, PrefCommunication, Interest, InterestInp, Television, TelevisionInp, Radio, RadioInp, NewsPaper, NewsPaperInp, CardTypeDescp, Sts)
	select @IssNo, @BatchId, a.AcctNo, a.CardNo, b.Title, b.Nationality, b.FamilyName, b.NewIc, b.PassportNo, b.Dob, b.Gender, b.Race, 
		  dbo.GetPreferredValue(@IssNo, b.PrefLanguage, 'PrefLanguage') 'PrefLanguage',  
		  dbo.GetPreferredValue(@IssNo, b.PrefCommunication, 'PrefCommunication') 'PrefCommunication', 
			dbo.GetPreferredValue(@IssNo, b.Interest, 'Interest') 'Interest',  
			b.InterestInp, 
		  dbo.GetPreferredValue(@IssNo, b.Television, 'Television') 'Television',  
			b.TelevisionInp,
		  dbo.GetPreferredValue(@IssNo, b.Radio, 'Radio') 'Radio',
			b.RadioInp,
		  dbo.GetPreferredValue(@IssNo, b.NewsPaper, 'NewsPaper') 'NewsPaper',
			b.NewsPaperInp,c.Descp, a.Sts
	from iac_Card a (nolock)
	join iac_Entity b (nolock) on b.EntityId = a.EntityId and b.IssNo = @IssNo
	join iss_CardType c (nolock) on c.CardType = a.CardType

	if @@error <> 0
	begin
		rollback transaction
		return 3
	end

	select @Rc = @@rowcount

	insert udi_Batch (IssNo, BatchId, SrcName, FileName, FileSeq, DestName, FileDate,
			RecCnt, Direction, Sts, PrcsId, PrcsDate)
	select @IssNo, @BatchId, 'HOST', 'CARDDATA', isnull(@FileSeq,0)+1, @IssNo, getdate(),
		@Rc, 'E', 'L', @PrcsId, @PrcsDate

	if @@error <> 0
	begin
		rollback transaction
		return 70265 -- Failed to update Batch
	end

	------------------
	COMMIT TRANSACTION
	------------------

	return 0
end
GO
