USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[LoadFiles]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	: Cardtrend Systems Sdn. Bhd.
Modular		: Cardtrend Card Management System (CCMS)- Issuing Module

Objective	: up-to-date online fin info updates.

SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN		Description
-------------------------------------------------------------------------------
2010/06/02 Chew Pei			Initial development
							For NewSkiesFile, it is always as of yesterday file, 
							thus, if today is Sept 7, then at EOD, CMS will process
							newskiesfile dated 6 Sept.
2010/10/19 Chew Pei			Added File Date Format and Day
							Date format is retrieve frm iss_Reflib..RefType = 'DateFmt'
2011/05/18 Peggy			Add FileDateFormat 
2012/01/30 Peggy			Add Excel file loaded status log
2012/02/12 barnett			Add FileDateFormat 4 can loaded from Excel File			
							FileDateFormat 4 =XXXX_YYYYMMDD_XXXX.xxx
2014/03/14 Humairah			Add @FileDateFmt = 5
2014/04/29 Humairah			make fileid = 5 to process current month  file
--2016/03/18 Humairah			restrict CLP file process to 7th day of every month
*******************************************************************************/
CREATE procedure [dbo].[LoadFiles]
	@IssNo uIssNo,
	@FileId int
--	@DateAddNo int

  as
begin

	declare @FileDate varchar(13), @File varchar(255), @SQL varchar(2000), @rc int
	declare @FileName varchar(50), @FileDateFmt varchar(10), @FilePath varchar(100), 
			@FileExtension varchar(10), @TableName varchar(50), @String varchar(1000), 
			@Day int, @String2 varchar(1000)
	declare @PrcsId uPrcsId, @cmd varchar(500), @Id int, @Cnt int, @PrcsDate datetime

	select @PrcsId = CtrlNo, @PrcsDate = CtrlDate
	from iss_Control (nolock)
	where CtrlId = 'PrcsId'
	
	select @rc = 0

	select @FileName = FileName,
			@FileDateFmt = FileDateFmt,
			@FilePath = FilePath,
			@FileExtension = FileExtension,
			@TableName = TableName,
			@String = String,
			@String2 = String2,
			@Day = Day
	from ld_FileList
	where FileId = @FileId

	if @FileName is null or @FilePath is null or @TableName is null or @String is null
	begin
		return 95099	--	Unable to retrieve information from iss_Default table
	end

	-- always truncate table to ensure no old data in the table
	select @SQL = 'TRUNCATE TABLE ' + @TableName 
	exec (@SQL)
	if @@error <> 0
	begin
		return 1
	end


	if exists (select 1 from ld_FileLog (nolock) where PrcsId = @PrcsId and FileId = @FileId and Sts = 'S')
	begin
		return 70988	--	Batch record already process
	end

	

	

	

	if @FileDateFmt = 4  -- XXXX_YYYYMMDD_XXXX.xxx
	begin 
		
		CREATE TABLE #Files
		(
		   fn VARCHAR(255)
		)


		CREATE TABLE #FileDate
		(
		   Id int identity(1,1) not null,
		   FileDate VARCHAR(255),
		   Tag char(1)
		)

		select @cmd = 'dir /b ' + @FilePath
		
		INSERT #files
		EXEC master..xp_cmdshell @cmd 
				
		delete #files where fn is null
	
		insert into #FileDate(FileDate)
		SELECT substring(fn,len(Fn)-16,17) FROM #Files 
		where fn like '%'+convert(varchar(8), dateadd(DAY,@Day,GETDATE()), 112)+'%'
		
		select @Cnt = COUNT(*) from #FileDate 

		select @Id = 1
	
			
		while (1=1)
		begin
			select @Id = min(Id)
			from #FileDate
			where Tag is null 

			if @Id is null break

			SELECT @FileDate = FileDate from #FileDate where Id = @Id
		
			-- do bulk insert	
			--select @FileDate = convert(varchar(8), getdate() + @DateAddNo, 112) -- always processed yesterday's file
			select @File = @FilePath + @FileName + @FileDate + @FileExtension
			
			if isnull(@String,'') = ''
			begin
				
					select @SQL = 'BULK INSERT ' + @TableName + ' FROM ''' + @File +''''
				
			end
			else
			begin
	
					if @FileExtension = '.xls'
					begin
							
						select @SQL = 'INSERT INTO ' + @TableName + @String + @File + @String2 
						
					end
					else
					begin
			
						select @SQL = 'BULK INSERT ' + @TableName + ' FROM ''' + @File + ''' WITH ' + @String
					end	
			end

	
			if @FileExtension = '.xls'
			begin
					
					BEGIN TRY
						
						EXECUTE (@Sql)
					 		        
					END TRY
					BEGIN CATCH
								
						
						-- If error get return code
						select @rc = @@error 
						if @rc <> 0 -- Successful
						begin
						
							insert into ld_FileLog (FileId, Filename, ErrCd, Sts, PrcsId, LastUpdDate)
							values (@FileId, @FileName+@FileDate, @rc, 'F', @PrcsId, getdate())
							
							if @@error <> 0
							begin
								return 3
							end
						end	

					END CATCH
					
					-- If no Error
					if @rc =0
					begin
					
						insert into ld_FileLog (FileId, Filename, ErrCd, Sts, PrcsId, LastUpdDate)
						values (@FileId, @FileName+@FileDate, @rc, 'S', @PrcsId,  getdate())
						
						if @@error <> 0
						begin
							return 2
						end
					end
			end
			else 
			begin

					exec (@Sql)
					
					-- log file loaded
					select @rc = @@error 
					if @rc = 0 -- Successful
					begin

						insert into ld_FileLog (FileId, Filename, ErrCd, Sts, PrcsId, LastUpdDate)
						values (@FileId, @FileName+@FileDate, @rc, 'S', @PrcsId,  getdate())
						if @@error <> 0
						begin
							return 2
						end
					end
					else
					begin 
						insert into ld_FileLog (FileId, Filename, ErrCd, Sts, PrcsId, LastUpdDate)
						values (@FileId, @FileName+@FileDate, @rc, 'F', @PrcsId, getdate())
						if @@error <> 0
						begin
							return 3
						end
					end

 			end
 			
 			update #FileDate set Tag = 'Y'
			where Id = @Id
			
 			if @@error <> 0 break
			
		end
		
		drop table #Files
		drop table #FileDate
		
	end
	else
	begin	
		select @FileDate = case when @FileDateFmt = 0 then convert(varchar(8), getdate() + @Day, 112) 
								when @FileDateFmt = 3 then substring(convert(varchar(8), getdate() + @Day, 112) ,1,6)
								when @FileDateFmt = 5 then convert(varchar(6), getdate(), 112)  
								end
								
		-- do bulk insert	
--		select @FileDate = convert(varchar(8), getdate() + @DateAddNo, 112) -- always processed yesterday's file
		select @File = @FilePath + @FileName + @FileDate + @FileExtension
		
--		 Prcs on the 7th only <BL1N82K>
--		if @FileId = 5	and DATEPART(DAY,@PrcsDate) <> 7  -- comment for UAT
--			return 99999


		if isnull(@String,'') = ''
		begin
			select @SQL = 'BULK INSERT ' + @TableName + ' FROM ''' + @File +''''
			
		end
		else
		begin
	
			if @FileExtension = '.xls'
			begin
					
				select @SQL = 'INSERT INTO ' + @TableName + @String + @File + @String2 
				
			end
			else
			begin
				select @SQL = 'BULK INSERT ' + @TableName + ' FROM ''' + @File + ''' WITH ' + @String
			end	
		end
		
	
	
			if @FileExtension = '.xls'
			begin
					BEGIN TRY
						
						EXECUTE (@Sql)
					 		        
					END TRY
					BEGIN CATCH
								
						
						-- If error get return code
						select @rc = @@error 
						if @rc <> 0 -- Successful
						begin
						
							insert into ld_FileLog (FileId, Filename, ErrCd, Sts, PrcsId, LastUpdDate)
							values (@FileId, @FileName+@FileDate, @rc, 'F', @PrcsId, getdate())
							
							if @@error <> 0
							begin
								return 3
							end
						end	

					END CATCH
					
					-- If no Error
					if @rc =0
					begin
					
						insert into ld_FileLog (FileId, Filename, ErrCd, Sts, PrcsId, LastUpdDate)
						values (@FileId, @FileName+@FileDate, @rc, 'S', @PrcsId,  getdate())
						
						if @@error <> 0
						begin
							return 2
						end
					end
			end
			else 
			begin

					exec (@Sql)
					
					-- log file loaded
					select @rc = @@error 
					if @rc = 0 -- Successful
					begin
						/** MOVE TO ARCHIVE **/
						if @FileId = 5
						begin
							select @cmd = 'MOVE ' + @File + ' ' + @FilePath + 'Archive\'
							EXEC MASTER..xp_cmdshell @cmd
						end
						
						insert into ld_FileLog (FileId, Filename, ErrCd, Sts, PrcsId, LastUpdDate)
						values (@FileId, @FileName+@FileDate, @rc, 'S', @PrcsId,  getdate())
						if @@error <> 0
						begin
							return 2
						end
					end
					else
					begin 
						insert into ld_FileLog (FileId, Filename, ErrCd, Sts, PrcsId, LastUpdDate)
						values (@FileId, @FileName+@FileDate, @rc, 'F', @PrcsId, getdate())
						if @@error <> 0
						begin
							return 3
						end
					end

 			end
					
	end
	
	return @rc	
end
GO
