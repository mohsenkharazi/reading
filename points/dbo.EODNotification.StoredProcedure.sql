USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[EODNotification]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE procedure [dbo].[EODNotification]	
as
begin
	set nocount on
	
	declare @msg varchar(200),
			@ErrInd char(1),
			@HTML  nvarchar(max),			
			@Subject nvarchar(200),
			@PrcsId int,
			@PrcsDate datetime,
			@EODStartDate datetime,
			@EODEndDate datetime,
			@EODSts char(1),
			@MsgStep01 varchar(200),
			@MsgStep02 varchar(200),
			@MsgStep03 varchar(300),
			@CntInAtxSourceTxn int,
			@CntInItxSourceTxn int,
			@CntInItxTxn int

	---------------------------------------------------------
	-- Step 1 : Check disk space
	---------------------------------------------------------

	exec dbo.spExec_SufficientDiskSpace 170, 'G', @msg output, @ErrInd output

	if @ErrInd = 'Y'
	begin		
		select @MsgStep01 = '<font color="Red">' + @msg + '</font>'
	end
	else
	begin
		select @MsgStep01 = '<font color="green">' + @msg + 
							' <br> Note : Admin, please make sure the available free space has sufficient space to store 2 eod''s db backup!</font>'
	end

	---------------------------------------------------------
	-- Step 2 : Check EOD Results
	---------------------------------------------------------

	select @PrcsId = CtrlNo
	from iss_Control (nolock) where CtrlId = 'PrcsId'
		
	-- Search for previous prcsid date job status
	select @PrcsId = @PrcsId - 1

	select @PrcsId = PrcsId, @PrcsDate = PrcsDate, @EODStartDate = StartDate, @EODEndDate = EndDate, @EODSts = Sts
	from cmnv_ProcessLog (nolock)
	where PrcsId = @PrcsId

	if @@rowcount = 0
	begin
		select @MsgStep02 = '<font color="Red">No record found in cmnv_ProcessLog, Admin please investigate!</font>'
	end
	else
	begin		
		if exists(select top 1 1 from cmnv_JobLog (nolock) where PrcsId = @PrcsId and Sts <> 'S')
		begin
			select @MsgStep02 = '<font color="Red">Some of the job in the eod failed to run, Admin please investigate!</font>'
		end
		else
		begin
			select @MsgStep02 = '<font color="green">EOD successfully executed</font>'	
		end
	end

	---------------------------------------------------------
	-- Critical Validation
	---------------------------------------------------------

	-- Check atx_SourceTxn count for unprocess txn
	select @CntInAtxSourceTxn = count(*) from atx_SourceTxn (nolock)

	if @CntInAtxSourceTxn > 0
	begin
		select @MsgStep03 = '<font color="red">atx_SourceTxn Count : ' + cast(@CntInAtxSourceTxn as varchar(12)) + ' (Admin please investigate)</font><br>'
	end
	else
	begin
		select @MsgStep03 = '<font color="green">atx_SourceTxn Count : 0</font><br>'
	end

	-- Check itx_SourceTxnCnt for unprocess txn
	select @CntInItxSourceTxn = count(*) from itx_SourceTxn (nolock)

	if @CntInItxSourceTxn > 0
	begin
		select @MsgStep03 = @MsgStep03 + '<font color="red">itx_SourceTxn Count : ' + cast(@CntInItxSourceTxn as varchar(12)) + ' (Admin please investigate)</font><br>'
	end
	else
	begin
		select @MsgStep03 = @MsgStep03 + '<font color="green">itx_SourceTxn Count : 0</font><br>'
	end

	-- Check atx_SourceTxnCnt for process txn
	select @CntInItxTxn = count(*) from itx_Txn (nolock) where PrcsId = @PrcsId
	
	if @CntInItxTxn > 0
	begin
		select @MsgStep03 = @MsgStep03 + '<font color="green">itx_Txn Count : ' + cast(@CntInItxTxn as varchar(12)) + '</font><br>'
	end
	else
	begin
		select @MsgStep03 = @MsgStep03 + '<font color="red">itx_Txn Count : 0 (Admin please investigate)</font><br>'
	end

	-- Check atx_SourceTxnCnt for process txn
	select @CntInItxTxn = count(*) from itx_Txn (nolock) where PrcsId = @PrcsId and TxnCd = 204
	
	if isnull(@CntInItxTxn,0) = 0
	begin		
		select @MsgStep03 = @MsgStep03 + '<font color="red">itx_Txn Points Issuance Count : 0 (Admin please investigate)</font><br>'
	end

	---------------------------------------------------------
	-- Construct HTML
	---------------------------------------------------------
	
	set @HTML =
		N'<font style="font-family:arial;font-size:12px;fore-color:#000">' +
--		N'<b><u>Server ('+ @@servername +') Noti Reports</u></b>' + '<br><br>' +
		N'<u>Step 1 - Check Disk drive</u>' + 
			'<br>' + @MsgStep01 + '<br><br>' +
		N'<u>Step 2 - Check EOD Result</u>' + 
			'<br> PrcsId : ' + cast(@PrcsId as varchar(10)) + ' | PrcsDate : ' + convert(varchar(25), @PrcsDate, 120) + 
			' | StartDate : ' + convert(varchar(25), @EODStartDate, 120) +  ' | EndDate : ' + convert(varchar(25), @EODEndDate, 120) + 
			' | Status : ' + @EODSts +
			'<br>' + @MsgStep02 + '<br><br>' +
		N'<u>Step 3 - Critical Validations</u>' + 
			'<br>' + @MsgStep03 + '<br><br>' +
		N'</font>'
	
	set @Subject = N'' + @@servername + ' - EOD Notification reports (' + convert(varchar(25), getdate(), 120) + ')'

	EXEC msdb.dbo.sp_send_dbmail	@profile_name = 'Kad Mesra',
									@recipients='sam@cardtrend.com;helpdesk@cardtrend.com;humairah@cardtrend.com;kksiow@cardtrend.com',
									@subject = @Subject,
									@body = @HTML,
									@body_format = 'HTML' ;

	return 0

end
GO
