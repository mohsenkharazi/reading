USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[LoadMultipleFiles]    Script Date: 9/6/2021 10:33:55 AM ******/
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
20160404	Azan			Initial Development 
*******************************************************************************/
/*
--LOAD FILE

DECLARE @RC int
EXEC @RC = LoadMultipleFiles 1,11
SELECT @RC

--PROCESS THE POINTS TRANSFER 

DECLARE @RC int
EXEC @RC = BatchPointTransferProcessing  1
SELECT @RC
*/
CREATE PROCEDURE [dbo].[LoadMultipleFiles]
	@IssNo uIssNo,
	@FileId int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	Declare @FileDate varchar(13),@File varchar(255),@SQL varchar(2000),@rc int,
			@FileName varchar(50),@FileDateFmt varchar(10),@FilePath varchar(100), 
			@FileExtension varchar(10),@TableName varchar(50),@String varchar(1000), 
			@Day int,@String2 varchar(1000),@PrcsId uPrcsId,@cmd varchar(500),
			@PrcsDate datetime,@Count int,@Max int,@PaymentBatchId uBatchId,
			@ActiveCardSts uRefCd,@ActiveAcctSts uRefCd

	CREATE TABLE #DirTree 
	(
	SubDirectory nvarchar(255),
	Depth smallint,
	FileFlag bit,
	)
		
	CREATE TABLE #FileList 
	(
	Id int identity(1,1),
	[FileName] nvarchar(255)
	)

	CREATE TABLE #ErrorFileList 
	(
	Id int identity(1,1),
	[FileName] nvarchar(255)
	)
	
	select @PrcsId = CtrlNo, @PrcsDate = CtrlDate
	from iss_Control (nolock)
	where CtrlId = 'PrcsId'
	
	select @rc = 0

	select @Count = 1

	select @ActiveAcctSts = RefCd from iss_RefLib (nolock) where RefType = 'AcctSts' and Descp = 'Active'
	select @ActiveCardSts = RefCd from iss_RefLib (nolock) where RefType = 'CardSts' and Descp = 'Active'

	select  @FileName = FileName,
			@FileDateFmt = FileDateFmt,
			@FilePath = FilePath,
			@FileExtension = FileExtension,
			@TableName = TableName,
			@String = String,
			@String2 = String2,
			@Day = Day
	from ld_FileList
	where FileId = @FileId

	if @@error <> 0
	begin
		return @rc
	end

	if @FileId = 11
	begin
		if exists (select 1 from udii_BatchPointTransferFile where Sts = 'L' and PrcsId = @PrcsId)
		begin
			return @rc
		end

		select @FileDate = convert(varchar(8),getdate() + @Day, 112) 
		 
		INSERT INTO #DirTree
		EXEC master..xp_dirtree @FilePath, 1, 1	

		DELETE from #DirTree where FileFlag = 0
		
        select @SQL = 'TRUNCATE TABLE ' + @TableName 
		exec(@SQL)

		INSERT INTO udii_BatchPointTransferFile (Filename,PrcsId)
		select SubDirectory,@PrcsId from #DirTree

		UPDATE udii_BatchPointTransferFile set Sts = 'F', Descp = 'Invalid file name' where substring(Filename,1,3) <> @FileName and PrcsId = @PrcsId and Sts is null
		
		UPDATE udii_BatchPointTransferFile set Sts = 'F', Descp = 'Invalid file name' where isdate(substring(Filename,4,8)) = 0 and PrcsId = @PrcsId and Sts is null
		
		UPDATE udii_BatchPointTransferFile set Sts = 'F', Descp = 'Invalid file name' where isnumeric(substring(Filename,13,10)) = 0 and PrcsId = @PrcsId and Sts is null
		
		UPDATE udii_BatchPointTransferFile set Sts = 'F', Descp = 'Invalid file type' where right(Filename,3) <> 'csv' and PrcsId = @PrcsId and Sts is null
		
		UPDATE udii_BatchPointTransferFile set Sts = 'F', Descp = 'Duplicate file name' where Filename in (select Filename from ld_FileLog (nolock) where FileId = @FileId and Sts = 'S') and PrcsId = @PrcsId and Sts is null
		
		UPDATE udii_BatchPointTransferFile set Sts = 'F', Descp = 'Invalid Date' where substring(Filename,4,8) <> @FileDate and PrcsId = @PrcsId and Sts is null
		
		UPDATE udii_BatchPointTransferFile 
		set Sts = 'F', 
		Descp = 'Merchant Account not found' where substring(Filename,13,10) not in 
		(
		select a.AcctNo from iac_Account a (nolock) 
		join iac_card b (nolock) on a.AcctNo = b.AcctNo 
		join iss_CardType d (nolock) on b.CardType = d.CardType
		where d.CardRangeId = 'PTSTRD' and a.Sts = @ActiveAcctSts and b.Sts = @ActiveCardSts 
		) 
		and PrcsId = @PrcsId and Sts is null
	
		INSERT INTO #FileList (Filename)
		select Filename from udii_BatchPointTransferFile (nolock) where Sts is null and PrcsId =  @PrcsId
		
		INSERT INTO #ErrorFileList (Filename)
		select Filename from udii_BatchPointTransferFile (nolock) where Sts = 'F' and PrcsId =  @PrcsId
		
		select @Max = max(Id) from #FileList 
		
		while @Count <= @Max
		begin
			exec @PaymentBatchId = nextRunNo 1, 'PtsTrfBatchId'
			select @Filename = [Filename] from #FileList where Id = @Count
			select @File = @FilePath + @FileName 

			select @SQL = 'BULK INSERT ldv_PointTransferTxn'+' '+ 'FROM ''' + @File + ''' WITH ' + @String 
			exec (@SQL)

			select @SQL = 'UPDATE'+' '+@TableName+' '+'SET Filename ='+''''+@FileName+''''+','+'BatchId ='+''''+CAST(@PaymentBatchId as varchar)+''''+' where Filename is null'
			exec (@SQL)

			select @rc = @@error 
			if @rc = 0 -- Successful
			begin
				/** MOVE TO ARCHIVE **/
				select @cmd = 'MOVE ' + @File + ' ' + @FilePath + 'Archive\'
				EXEC MASTER..xp_cmdshell @cmd
				
				insert into ld_FileLog (FileId, Filename, ErrCd, Sts, PrcsId, LastUpdDate)
				values (@FileId,@Filename, @rc, 'S', @PrcsId,  getdate())
				if @@error <> 0
				begin
					return 2
				end
			end
			else
			begin 
				insert into ld_FileLog (FileId, Filename, ErrCd, Sts, PrcsId, LastUpdDate)
				values (@FileId,@FileName, @rc, 'F', @PrcsId, getdate())
				if @@error <> 0
				begin
					return 3
				end
			end

			select @Count = @Count+1 
		end

		update udii_BatchPointTransferFile with (rowlock) set Sts = 'L'  where Sts is null and PrcsId =  @PrcsId
		update udii_BatchPointTransferFile with (rowlock) set Sts = 'R'  where Sts = 'F' and PrcsId =  @PrcsId

		select @Max = max(Id) from #ErrorFileList
		select @Count=1
		select @Filename = null
		select @File = null
		
		while @Count <= @Max
		begin
			select @Filename = [Filename] from #ErrorFileList where Id = @Count 

			select @File = @FilePath + @FileName 

			select @cmd = 'MOVE ' + @File + ' ' + @FilePath + 'Rejected\'
			EXEC MASTER..xp_cmdshell @cmd
			
			select @Count = @Count+1 
		end
	end

	DROP TABLE #DirTree
	DROP TABLE #FileList
	DROP TABLE #ErrorFileList
	return @rc	
END
GO
