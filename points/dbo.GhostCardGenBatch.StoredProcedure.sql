USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GhostCardGenBatch]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO


/******************************************************************************
Copyright	:Cardtrend Systems Sdn. Bhd.
Modular		:Cardtrend Card Management System (CCMS)- Issuing Module

Objective	:To generate ghost account and cards.

			Related to:
					(1) GhostCardGenDlg.cpp/GhostCardGenDlg.h - to capture tot cards to be produce.
					(2) GhostCardGenBatch - create udi_batch header.
					(3) GhostCardProcessing* - looping for udi_batch to call GhostCardGen.
					(4) GhostCardGen - To create card account tables & misc.
					(5) EmbCardExtract - To generate embossing file using xp_cmdshell.
-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2009/02/22	Sam				Initial development.
2009/03/24	Chew Pei		Comment Card Range Id validation, added FileSeq
*******************************************************************************/
/*

declare @IssNo uIssNo,	@NoAcct smallint,	@NoCards smallint,	@CardLogo uCardLogo,	@PlasticType uPlasticType,	@CardType uCardType
exec GhostCardGenBatch @IssNo =1, @NoAcct =5, @NoCards =1, @CardLogo ='DEMOLTY', @PlasticType= 'PDBTEST',	@CardType= '1'

*/
CREATE procedure [dbo].[GhostCardGenBatch]
	@IssNo uIssNo,
	@NoAcct int,
	@NoCards int,
	@CardLogo uCardLogo,
	@PlasticType uPlasticType,
	@CardType uCardType,
	@CardRangeId varchar(10)

  as
begin
	declare @Rc int, @BatchId uBatchId, @FileSeq int

	set nocount on
	select @NoCards = 1

	if @NoAcct >50000 return 95500 --Number Of Account cannot greater then 30000 per batch

	if isnull(@NoAcct,0) = 0 return 95082 --Number of card must greater than zero
	if @CardLogo is null return 55002 --Card logo is a compulsory field
	if @PlasticType is null return 55003 --Plastic type is a compulsory field
	if @CardType is null return 55048 --Card Type is a compulsory field
--	if @CardRangeId is null return 55149 --Card Range Id is a compulsory field

	if not exists (select 1 from iss_CardLogo (nolock) where IssNo = @IssNo and CardLogo = @CardLogo)
		return 60005 --Card Logo not found

	if not exists (select 1 from iss_PlasticType (nolock) where IssNo = @IssNo and PlasticType = @PlasticType)
		return 95231 --Invalid Plastic Type

	if not exists (select 1 from iss_CardType (nolock) where PlasticType = @PlasticType and CardType = @CardType)
		return 95029 --	

--	if not exists (select 1 from iss_CardRange (nolock) where CardRangeId = @CardRangeId)
--		return 95249 --Card Range Id not found

	exec @BatchId = NextRunNo @IssNo, 'EMBBatchId'

	if @@rowcount = 0 or @@error <> 0  
	begin
		return 70395 --Failed to create new batch
	end


	select @FileSeq = isnull(max(FileSeq), 0) + 1
	from udi_Batch
	where FileName = 'GCGEN' and IssNo = @IssNo

	insert udi_Batch
		(IssNo, BatchId, PhyFileName, SrcName, FileName, 
		FileSeq, DestName, FileDate, OrigBatchId, LoadedRec, 
		RecCnt, PrcsRec, Direction, PrcsId, PrcsDate, 
		RefNo1, RefNo2, RefNo3, RefNo4, Sts, 
		PlasticType, OperationMode, RefNo5)
	select 
		@IssNo, @BatchId, null, 'Host', 'GCGEN', 
		@FileSeq, 'VPI', getdate(), null, 0, 
		@NoAcct, 0, 'E', 0, null, 
		@CardLogo, @CardRangeId, @CardType, null, 'L', 
		@PlasticType, null, null

	if @@error <> 0 return 70219 --Failed to create Ghost Card

	return 50121 --Ghost cards have been generated successfully
end
GO
