USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AuditFileCardStsExtraction]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
/******************************************************************************
Copyright	: Cardtrend System Sdn Bhd
Modular		: Cardtrend Card Management System (CCMS)- Issuing Module

Objective	: Extract Card Sts History for PDB  

SP Level	: Primary
-------------------------------------------------------------------------------
When		Who		CRN	   Description
-------------------------------------------------------------------------------
2011/12/07	Barnett		   Initial development.
*******************************************************************************/
/*


declare @rc varchar(200), @rt int, @cnt int
SET @Cnt = 1

while @Cnt <=1
begin

	exec @rt = AuditFileCardStsExtraction 1,null, @rc

	select @Cnt = @Cnt + 1
--	select @rt, @rc

end



*/
CREATE procedure [dbo].[AuditFileCardStsExtraction]
	@IssNo uIssNo,
	@BatchId int,
	@Out varchar(200) output

  as
begin
	declare @TSql varchar(Max), @Path varchar(50), @Sts varchar(2),
			@Min bigint, @PrevSeqNo bigint, @Plastic varchar(30), @PrcsDate varchar(10),
			@OperationMode char(10), @FileSeq int, @FileName varchar(50), @FileExt varchar(10),
			@PlasticType uPlasticType, @CardPlan varchar(10), @RecCnt int, @Max bigint
			
	declare @CreateTable varchar(300), @Header varchar(200), @MySpecialTempTable varchar(100),
			@Detail varchar(MAX), @Trailer varchar(100), @Command varchar(500), @Unicode int, @RESULT int,
			@AuditFileEventId varchar(20), @MaxEventId varchar(20), @PrcsId uPrcsid, @RerunFlag tinyint

	set nocount on
	set dateformat ymd

	truncate table temp_AuditFile

	select 	@Unicode=0, @MySpecialTempTable ='temp_AuditFile'

	select @PrcsId = CtrlNo, @PrcsDate = convert(varchar(10), CtrlDate, 112)
	from iss_control 
	where Ctrlid = 'PrcsId'

	select @RecCnt = 0
	
	
	select @Path = VarcharVal
	from iss_Default 
	where Deft = 'DeftAuditFilePath'

	
	if @Path is null 
		select @Path = 'D:\' 

	select @FileExt = VarcharVal
	from iss_Default 
	where Deft = 'DeftAuditFileExt'

	if @FileExt is null
		select @FileExt = '.txt'

	
	-----------------
	Begin Transaction
	-----------------

	if @BatchId is null 
	begin
				exec @BatchId = NextRunNo @IssNo, 'UDIBatchId'
				
				---- Contruct file name
				select	@FileSeq = isnull(FileSeq, 0)+ 1,
						@AuditFileEventId = isnull(RefNo2,'0')
				from udi_Batch (nolock) 
				where batchId = (select	top 1 Batchid from udi_Batch (nolock) where BatchId < @BatchId and SrcName ='AUDIT' and Filename = 'CARDSTS' order by batchid desc)


				select @MaxEventid = Max(EventId) from iac_event (nolock)
				

	end
	else
	begin
				exec @BatchId = NextRunNo @IssNo, 'UDIBatchId'

				-- Re-Generate the audit file
				select	@FileSeq = FileSeq,
						@AuditFileEventId = RefNo1,
						@MaxEventId = RefNo2,
						@PrcsDate = convert(varchar(10), PrcsDate,112),
						@RerunFlag =1
				from udi_Batch (nolock) 
				where batchId = @BatchId
	
	end





	select @FileName = 'AuditFile_CardSts_' + @PrcsDate

	select @Out = @Path + @FileName + @FileExt


		-- Create Header Record
		insert temp_AuditFile (SeqNo, String) 
		select	1, 'H' +	-- Header (1)
				dbo.PadRight(' ', 8, 'HOST') + -- SourceName
				dbo.PadRight(' ', 20, 'AUDITLOG2') + -- FileType
				dbo.PadLeft(0, 12, isnull(@FileSeq, 1)) + -- File Sequence
				dbo.PadRight(' ', 8, 'Out') + -- Destination Name
				@PrcsDate -- File Date
						

		if @@error <> 0 return 1

		-- Contruct Detail
		insert temp_AuditFile (SeqNo, String) 
		select row_number() OVER (order by a1.String) + 1, 'D' + dbo.PadLeft(0, 8, convert(varchar(8), row_number() OVER (order by a1.String))) + String 
		from
			(
				select 
				  dbo.PadRight(' ' , 20, 'CARD')
				+ dbo.PadLeft(0, 19, a.EventId)
				+ dbo.PadRight(' ' , 15, a.AcctNo)
				+ dbo.PadRight(' ' , 19, a.CardNo)
				+ dbo.PadRight(' ' , 50, a.Reasoncd)
				+ dbo.PadRight(' ' , 100, a.Descp)
				+ dbo.PadRight(' ' , 8, a.CreatedBy)
				+ SubString( convert(varchar(8), a.CreationDate, 112), 1, 8) 
				+ space(1) 
				+ substring( convert(varchar(8), a.CreationDate, 114), 1, 8) as String 
				FROM iac_Event a (nolock)	
				where a.EventType = 'ChgSts' and a.CardNo is not null and a.EventId >  isnull(@AuditFileEventId,1) and a.Eventid < @MaxEventId 
				) a1


			
		select @RecCnt = @@rowcount
				

		-- Create Detail Record
		select @TSql =	'T' +	-- Header (1)
						dbo.PadLeft('0', 10, cast(@RecCnt+1 as varchar(10))) -- FileName (20)

		select @Trailer = 'insert '+ @MySpecialTempTable+' (SeqNo, String)'+ 'select ''' + convert(varchar(20), @RecCnt+2 )+ ''',''' + @TSql+ ''''
		--select @Trailer
		exec (@Trailer)
		 
		if @@error <> 0 return 1
	

	
	-- Create Batch record first before Extraction.
		if @RerunFlag = 0
		begin

				insert udi_Batch(IssNo, BatchId, PhyFileName,SrcName,FileName,FileSeq,DestName,FileDate,LoadedRec,
							RecCnt,PrcsRec,Direction,PrcsId,PrcsDate, RefNo1,RefNo2, Sts)
				select @IssNo, @BatchId, @Out, 'AUDIT', 'CARDSTS', isnull(@FileSeq, 1), 'HOST',getdate(), 0,
							@RecCnt, @RecCnt, 'E', @PrcsId, cast(@PrcsDate as datetime), cast(@AuditFileEventId as nvarchar(30)), cast(@MaxEventId as nvarchar(30)), 'P' 

				if @@error <> 0
				begin
						Rollback Transaction
						return 99
				end
		end
		else
		begin
				update udi_batch 
				set RecCnt = @RecCnt,
					PrcsRec = @RecCnt
				where BatchId = @BatchId

				if @@error <> 0
				begin
						Rollback Transaction
						return 99
				end
		end


	------------------
	Commit Transaction
	------------------
		

	SELECT  @Command = 'bcp "select String from '
          + @MySpecialTempTable + ' order by SeqNo'
          + '" queryout '
          + @Out + ' '
         + CASE WHEN @Unicode=0 THEN '-c' ELSE '-w' END
          + ' -T -S' + @@servername
 
	--select @Command

    EXECUTE @RESULT= MASTER..xp_cmdshell @command, NO_OUTPUT


	return 0

end
GO
