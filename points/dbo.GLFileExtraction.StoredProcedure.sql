USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GLFileExtraction]    Script Date: 9/6/2021 10:33:55 AM ******/
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
2007/06/01	Barnett				Initial Development
2015/04/02  Humairah			Back Dated format
*******************************************************************************/
/*
	declare @Out varchar(200), @rc int
exec  @rc = GLFileExtraction 1, 1278, @Out output
select @rc, @Out

*/
	
CREATE	procedure [dbo].[GLFileExtraction]
	@IssNo uIssNo,
	@PrcsId uPrcsid,
	@Out varchar(200) output
  
as
begin

	
	declare @TSql varchar(Max), @Path varchar(50), @Sts varchar(2),
			@Min bigint, @PrevSeqNo bigint, @Plastic varchar(30), @PrcsDate varchar(10),
			@OperationMode char(10), @FileSeq int, @FileName varchar(50), @FileExt varchar(10),
			@PlasticType uPlasticType, @CardPlan varchar(10), @RecCnt int, @Max bigint
			
	declare @CreateTable varchar(300), @Header varchar(2000), @MySpecialTempTable varchar(100),
			@Detail varchar(MAX), @Trailer varchar(2000), @Command varchar(500), @Unicode int, @RESULT int

	set nocount on
	set dateformat ymd

	if @PrcsId is null
	begin

			--Get Current PrcsId and PrcsDate
			select @PrcsId = CtrlNo, @PrcsDate = convert(varchar(10), CtrlDate,112)
			from iss_control where CtrlId ='PrcsId' and IssNo = @IssNo
	end
	else
	begin
			select @PrcsDate = convert(varchar(10), PrcsDate, 112)
			from cmnv_processlog where prcsid = @PrcsId
	end

	--select @PrcsId = 1257, @PrcsDate ='20120913'

	truncate table temp_GLFile

	select 	@Unicode=0, @MySpecialTempTable ='temp_GLFile'

	select @RecCnt = 0

	select @Path = VarcharVal
	from iss_Default 
	where Deft = 'DeftGLFilePath'

	if @Path is null 
		select @Path = 'D:\' 

	select @FileExt = VarcharVal
	from iss_Default 
	where Deft = 'DeftGLFileExt'

	if @FileExt is null
		select @FileExt = '.txt'

	-------------------
	begin transaction
	-------------------


	select @FileName = 'LMS_SAP_' + substring(@PrcsDate, 3,2)  + substring(@PrcsDate, 5,2)  + substring( @PrcsDate , 7,2) + '_B4'

	select @Out = @Path + @FileName + @FileExt

		
	-- Create Header Record
	select @TSql =	'HEADER' +	-- Header (6)
					substring( @PrcsDate, 7,2) + -- DAY(2)
					'.' +
					substring( @PrcsDate, 5,2) + -- MONTH(2)
					'.' +
					substring( @PrcsDate, 3,2) + -- YEAR(2)
					space(240)					 -- Filler(240)
					
	
	select @Header = 'insert '+ @MySpecialTempTable+' ( String)'+ ' select ''' + @TSql +''''
--	select @Header
	exec (@Header)

	if @@error <> 0 
	begin
			rollback transaction
			return 1
	end
	

	-- Contruct Detail
	select @TSql = 'select substring( a.TxnDate, 7,2) + substring(a.TxnDate, 5,2) + substring(a.TxnDate, 3,2)' + --Transaction Date
				'+ dbo.Padleft(0, 6, a.RefNo )' + -- Record
				'+ ''' +'0002' +  '''' +		-- Company Code
				'+ a.SlipSeq' +					--  Slip Sequence
				'+substring( ''' + @PrcsDate + ''', 7,2) + substring(''' + @PrcsDate + ''', 5,2) + substring('''+ @PrcsDate + ''', 3,2) ' +	-- Process Date
				'+ ''' +'MYR' +  '''' +		-- Currency
				'+ dbo.PadRight('' '', 25, substring(a.Descp2, 1, 25 ))' +							-- Transaction Type
				'+ convert(varchar(2), a.TxnType) ' +				-- Post Key
				'+ dbo.PadRight('' '', 10, a.AcctTxnCd) ' +
				'+ dbo.PadLeft(''0'', 13, convert(varchar(20), a.TxnAmt)) ' +
				'+ case 
						when a.IssAcqInd =''I'' then dbo.PadRight('' '', 10, isnull(b.ProfitCenter, '''')) 
						when a.IssAcqInd =''A'' then dbo.PadRight('' '', 10, isnull(c.ProfitCenter, '''')) 
					end ' +
				'+ case 
						when a.IssAcqInd =''I'' then dbo.PadRight('' '', 10, isnull(b.RcCd, '''')) 
						when a.IssAcqInd =''A'' then dbo.PadRight('' '', 10, isnull(c.RcCd, '''')) 
					end  ' +
				'+ dbo.PadRight('' '', 24, space(0))' +
				'+ dbo.PadRight('' '', 60, a.Descp2) '+ 
				'+ dbo.PadRight('' '', 73, space(0))' +
		' from udie_GLTxnSummary a (nolock)
		left outer join iss_GlCode b (nolock) on b.TxnCd = a.TxnCd and a.IssAcqInd =''I'' and b.TxnType = a.TxnType and b.AcctTxnCd = a.AcctTxnCd
		left outer join acq_GlCode c (nolock) on c.TxnCd = a.TxnCd and a.IssAcqInd =''A'' and c.TxnType = a.TxnType and c.GLAcctNo = a.AcctTxnCd
		where a.PrcsId =''' + convert(varchar(10),@PrcsId) + ''' order by cast(a.RefNo as int)'	

		-- Create Detail Record
		select @Detail = 'insert '+ @MySpecialTempTable+' (String) ' +@TSql
		--select @Detail
		exec (@Detail)

	

		if @@error <> 0 
		begin
				rollback transaction
				return 1
		end

		-- Contruct Trailer Record
		select @TSql ='select ''TRAILER''' +	-- Header (7)
				'+ dbo.PadLeft(''0'', 14, Max(RefNo))' +
				'+ dbo.PadLeft(''0'', 14, count(RefNo))' +
				'+ dbo.PadRight('' '', 219, space(0))' +
				' from udie_GLTxnSummary a (nolock)
				where a.PrcsId =''' + convert(varchar(10),@PrcsId) + ''''			


		-- Create Trailer Record			
		select @Trailer = 'insert '+ @MySpecialTempTable+' (String) '+  @TSql+ ''
	--	select @Trailer
		exec (@Trailer)
		
	 

		if @@error <> 0 
		begin
				rollback transaction
				return 1
		end

				
	------------------	
	commit Transaction
	------------------


	if exists(select 1 from temp_GLFile)
	begin


			SELECT  @Command = 'bcp "select String from '
  			        + @MySpecialTempTable + ' order by SeqNo'
      			    + '" queryout '
      			    + @Out + ' '
      			    + CASE WHEN @Unicode=0 THEN '-c' ELSE '-w' END
      			    + ' -T -S' + @@servername
 
		--	select @Command
	
			EXECUTE @RESULT= MASTER..xp_cmdshell @command, NO_OUTPUT
	 
	end

end
GO
