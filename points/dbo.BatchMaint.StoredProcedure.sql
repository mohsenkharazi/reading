USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BatchMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module
Objective	: This procedure will update the udi_Batch with the result of processing.

------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2002/09/12 Jacky		   Initial development

******************************************************************************************************************/

CREATE procedure [dbo].[BatchMaint]
	@IssNo uIssNo,
	@Direction char(1),
	@PhyFile varchar(80),
	@BatchId int,
	@LoadedRec int,
	@TotalRec int
   as
begin
	declare	@PrcsName varchar(50),
		@PrcsId uPrcsId,
		@Msg varchar(80)

	select @PrcsName = 'BatchMaint'

	exec TraceProcess @IssNo, @PrcsName, 'Start'

	select @PrcsId = CtrlNo
	from iss_Control
	where IssNo = @IssNo and CtrlId = 'PrcsId'

	if not exists (select 1 from udi_Batch where IssNo = @IssNo and BatchId = @BatchId)
		return 60046	-- Batch not found

	if (@Direction = 'I')
	begin
		update udi_Batch
		set	LoadedRec = @LoadedRec, RecCnt = @TotalRec, Direction = @Direction,
			PrcsId = @PrcsId, Sts = 'L'
		where IssNo = @IssNo and BatchId = @BatchId
	end
	else
	begin
		update udi_Batch
		set PhyFileName = @PhyFile, Sts = 'E'
		where IssNo = @IssNo and BatchId = @BatchId
	end

	if @@error <> 0 return 70265	-- Failed to update Batch

	return 50226	-- Batch updated successfully
end
GO
