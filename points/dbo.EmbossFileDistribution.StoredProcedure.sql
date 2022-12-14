USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[EmbossFileDistribution]    Script Date: 9/6/2021 10:33:55 AM ******/
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
2009/04/14	Barnett				Initial Development
*******************************************************************************/
	
CREATE	procedure [dbo].[EmbossFileDistribution]
	@IssNo uIssNo,
	@BatchId uBatchId
  
as
begin
	declare @Out varchar(200), @rc int
		--declare @BatchId uBatchId, @Out varchar(200), @rc int

	--select @BatchId = min(BatchId) 
	--from udi_batch (nolock) where IssNo = @IssNo and SrcName ='Host' and FIleName ='GCGEN'
	--and PhyFileName is null and Direction ='E' and DestName='VPI' and Sts = 'P' and PrcsId > 0

	If isnull(@BatchId, 0) = 0 return 0 -- No batch record. 

	update udi_batch
	set Sts ='D' -- Temporary set to 'D', mean Distributor are taking this batch.
	where BatchId = @BatchId

	exec @Rc = EmbCardExtract @IssNo, @BatchId, @Out output
	
	if @@error <> 0 or dbo.CheckRC(@Rc) <> 0 
	begin
		return 70483 --Failed to insert emboss record
	end

	update udi_batch
	set Sts ='P', -- Sts set to 'P', mean Distributor are Process this batch.
			PhyFileName = @Out
	where BatchId = @BatchId

	If @@error <> 0
	begin
		return 100
	end

	
	return 0

end
GO
