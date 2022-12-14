USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[JobCBFCreateBatch]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE proc [dbo].[JobCBFCreateBatch]
	@FileId varchar(50),
	@Filename nvarchar(200),
	@FullName nvarchar(500),
	@RecCnt int,
	@CreationDate datetime
as
begin
	declare @BatchId bigint, @PrcsId int
	
	select @PrcsId=CtrlNo 
	from iss_Control
	where CtrlId='PrcsId'
	
	exec @BatchId = NextRunNo 1, 'UDIBatchId'
	
	insert cbf_Batch (FileId, BatchId, Filename, FullName, RecCnt, CreationDate, Direction, PrcsId, Sts)
	select @FileId, @BatchId, @Filename, @FullName, @RecCnt, @CreationDate, 'I', @PrcsId, 'L'
end
GO
