USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[FileProcess]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:

Objective	:

-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2009/04/12	Barnett				Initial Development
*******************************************************************************/
/*
declare @BatchId int,
		@rc int
Exec @rc = FileProcess 'Process', 1, 'EPC', 'TRANSACTION', null, 1, 45, 'I', 98, @BatchId output
select @BatchId

select * from udiv_batch where srcname = 'EPC' and FileSeq = 98
*/
CREATE procedure [dbo].[FileProcess]
	@Func varchar(10),
	@IssNo uIssNo,
	@SrcName varchar(20),
	@FileName varchar(20),
	@PhyFileName varchar(80),
	@DestName varchar(20),
	@RecCnt int,
	@Direction char(1),
	@FileSeq int,
	@BatchId int output,
	@RefNo1 varchar(15) = '',
	@RefNo2 varchar(15) = '',
	@RefNo3 varchar(15) = ''

  
as
begin

	declare @PrcsId uPrcsId, @PrcsDate datetime, @DB varchar(30),
			@Sql varchar(4000), @Sts uRefCd
	
	select @DB = VarcharVal 
	from iss_default (nolock) 
	where Deft ='CCMSDb'

	if @Func ='Validate'
	begin
		
		-- Get new seq
		if isnull(@FileSeq,0) = 0
		begin
			select @FileSeq = isnull(max(FileSeq),0) + 1 
			from udiv_Batch (nolock) 
			where SrcName = @SrcName and FileName = @FileName and Direction = @Direction
		end

		if not exists( select 1 from udi_file (nolock) where SrcName =  @SrcName and FileName = @FileName and Direction = @Direction)
			return 400030 -- Invalid Src name or File Name
		 
		select @Sts = Sts 
		from udiv_Batch (nolock) 
		where SrcName =  @SrcName and FileName = @FileName and Direction = @Direction and FileSeq = @FileSeq 

		if @Sts = 'L'
			return 400031 -- Batch already loaded to the host
		else if @Sts = 'P'
			return 400029 -- Batch already process by host

		exec @BatchId = NextRunNo @IssNo, 'UDIBatchId'

		select @PrcsId = CtrlNo, @PrcsDate = CtrlDate 
		from issv_Control (nolock) 
		where CtrlId = 'PrcsId'

--		-- As the file loaded is for previous prcs id cycle
--		if @SrcName = 'HOST' and @FileName = 'ACK'
--		begin
--			select @PrcsId = @PrcsId - 1
--
--			select @PrcsDate = PrcsDate
--			from cmn_ProcessLog (nolock)
--			where PrcsId = @PrcsId
--		end
--		else if @SrcName = 'BANK' and @FileName = 'DRCD'
--		begin
--			select @PrcsId = @PrcsId - 1
--			
--			select @PrcsDate = PrcsDate
--			from cmn_ProcessLog (nolock)
--			where PrcsId = @PrcsId
--		end

		--------------------
		begin transaction
		--------------------
					
		select @Sql = 'insert into ' + @DB + '..udi_Batch (IssNo, BatchId, PhyFileName, SrcName, FileName, FileSeq, DestName, FileDate, OrigBatchId, LoadedRec,
				RecCnt, PrcsRec, Direction, PrcsId, PrcsDate, RefNo1, RefNo2, RefNo3, RefNo4, Sts, PlasticType, OperationMode, RefNo5, CardPlan) 	
		select ' + convert( varchar(2), @IssNo) + ','+ convert(varchar(10), @BatchId) +','''+ isnull(@PhyFileName,'null') +''','''+ @SrcName+''',''' +@FileName+''','+ convert(varchar(10), @FileSeq) +','''
				+ @DestName+''', getdate(), null, 0,
						0, 0,'''+ @Direction+''',' + convert(varchar(8), @PrcsId)+ ',''' + convert(varchar(10), @PrcsDate, 112)+ ''', ''' + @RefNo1 + ''', null, null, null, ''F'', null,
						null, null, null'

		exec (@Sql)
		
		-------------------
		commit Transaction
		-------------------

		return 0
		
	end 
	
	if @Func ='Process'
	begin

			if @Direction = 'I'
			begin
				select @Sql = 'update ' + @DB +'..udi_Batch set Sts ='+ '''L'''+', PhyFileName = '''+ isnull(@PhyFileName,'null') +''', LoadedRec = ' + cast(@RecCnt as varchar(15)) + ' where BatchId = '  +  convert(varchar(10), @BatchId )
			end
			else
			begin
				select @Sql = 'update ' + @DB +'..udi_Batch set Sts ='+ '''L'''+', LoadedRec = ' + cast(@RecCnt as varchar(15)) + ' where BatchId = '  +  convert(varchar(10), @BatchId )
			end

			exec  (@Sql)
			
			return 0
	end

	if @Func = 'Success'
	begin
			select @Sql = 'update ' + @DB +'..udi_Batch set Sts ='+ '''P''' +', PhyFileName = '''+ isnull(@PhyFileName,'null') + ''' where BatchId = ' + convert(varchar(10), @BatchId )
			
			exec  (@Sql)
			
			return 0
	end

end
GO
