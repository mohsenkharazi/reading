USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GhostCardProcessing]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/******************************************************************************
Copyright	:Cardtrend Systems Sdn. Bhd.
Modular		:Cardtrend Card Management System (CCMS)- Issuing Module

Objective	:To generate ghost account and cards processing.

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
2009/09/24	Barnett			Disable the create object part because Trigger are on back.
*******************************************************************************/
/*
declare @r int
exec @r = GhostCardProcessing 1,null
select @r
*/
CREATE procedure [dbo].[GhostCardProcessing]
	@IssNo uIssNo,
	@PrcsId uPrcsId = null

  as
begin
	declare @Rc int, @NoAcct int, @NoCards smallint, @CardRangeId varchar(10),
		@CardLogo uCardLogo, @PlasticType uPlasticType, @CardType uCardType, @CreationFlag char(1),
		@BatchId uBatchId, @PrevBatchId uBatchId, @Out varchar(200)

	set nocount on

	if @PrcsId is null
	begin
		select @PrcsId = CtrlNo
		from iss_Control
		where IssNo = @IssNo and CtrlId = 'PrcsId'
	end

	select @BatchId = min(BatchId)
	from udi_Batch
	where SrcName = 'Host' and DestName = 'VPI' and Sts = 'L'
	
	if isnull(@BatchId,0) = 0 return 50121 --Ghost cards have been generated successfully
	
	while 1 = 1
	begin
		select @NoAcct = RecCnt,
			@CardLogo = RefNo1,
			@CardRangeId = RefNo2,
			@CardType = RefNo3,
			@PlasticType = PlasticType,
			@CreationFlag = 'Y'
		from udi_Batch (nolock)
		where SrcName = 'Host' and DestName = 'VPI' and BatchId = @BatchId

		if @@rowcount = 0 break --Ghost cards have been generated successfully

		select @PrevBatchId = @BatchId, @Rc = 0

		exec @Rc = GhostCardGen @IssNo,	@NoAcct, @NoCards, @CardLogo, @PlasticType, @CardRangeId, @CardType, @CreationFlag, @BatchId

		if @@error <> 0 or dbo.CheckRC(@Rc) <> 0 return @Rc
			
		--exec @Rc = EmbCardExtract @IssNo, @BatchId, @Out output

		--if @@error <> 0 or dbo.CheckRC(@Rc) <> 0 return 70483 --Failed to insert emboss record

		update udi_Batch
		set Sts = 'P',
			PhyFileName = @Out,
			PrcsId = @PrcsId
		where SrcName = 'Host' and DestName = 'VPI' and BatchId = @BatchId

		if @@error <> 0 or @@rowcount = 0 return 70156 --Failed to update UDI Source

		----------------
		-- Create Object
		----------------
		--Acct level
		--insert iss_Object (IssNo, Obj, Val, Src, LinkNo)
		--select @IssNo, 'AcctNo', a.AcctNo, 'Account', a.AcctNo
		--from iac_PlasticCard a 
		--where a.BatchId = @BatchId and a.Sts = 'E'

		---- Card Level
		--insert iss_Object (IssNo, Obj, Val, Src, LinkNo)
		--select @IssNo, 'CardNo', a.CardNo, 'Card', a.CardNo
		--from iac_PlasticCard a 
		--where a.BatchId = @BatchId and a.Sts = 'E'
		
		--insert iss_Object (IssNo, Obj, Val, Src, LinkNo)
		--select @IssNo, 'AcctNo', a.AcctNo, 'Card', a.CardNo
		--from iac_PlasticCard a 
		--where a.BatchId = @BatchId and a.Sts = 'E'
		
		--insert iss_Object (IssNo, Obj, Val, Src, LinkNo)
		--select @IssNo, 'EntityId', b.EntityId, 'Card', a.CardNo
		--from iac_PlasticCard a
		--join iac_Card b on b.CardNo = a.CardNo
		--where a.BatchId = @BatchId and a.Sts = 'E' 

		select @BatchId = min(BatchId)
		from udi_Batch
		where SrcName = 'Host' and DestName = 'VPI' and Sts <> 'P'

		if isnull(@BatchId,0) = 0 break
	end

	return 50121 --Successfully added
end
GO
