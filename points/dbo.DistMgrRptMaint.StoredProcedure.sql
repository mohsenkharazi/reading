USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[DistMgrRptMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CCMS

Objective	:Insert into ITS reporting schedules
------------------------------------------------------------------------------------------
When		Who		CRN	Description
------------------------------------------------------------------------------------------
2009/04/12	Darren		   	Initial development
*****************************************************************************************/
/* 
	declare @rc int
	exec @rc = DistMgrRptMaint 1, 'LMS001AccountActivity'
	select @rc
*/

CREATE procedure [dbo].[DistMgrRptMaint]
	@IssNo smallint,
	@RptName varchar(50),
	@RptType varchar(15) = 'Adhoc'
	
  as
begin	

	set nocount on

	declare @Rc int,
			@PrcsId uPrcsId, 
			@PrcsDate datetime,
			@StrIssNo varchar(5),
			@StrPrcsId varchar(5),
			@StrFromDate varchar(10),
			@StrToDate varchar(10),		
			@ErrMsg varchar(255)

	-- Select system process detail
	select @PrcsId = CtrlNo, @PrcsDate = CtrlDate
	from iss_Control (nolock)
	where IssNo = @IssNo and CtrlId = 'PrcsId'

	-- Need to reduce the process else export report will reject
	if @RptType = 'Adhoc'
	begin
		select @PrcsId = @PrcsId - 1
	end

	-- Call Report Printing Stored Procedure
	select @StrIssNo = convert(varchar(5), @IssNo)
	select @StrPrcsId = convert(varchar(5), @PrcsId)
	select @StrFromDate = convert(varchar(8), getdate(), 112)	
	select @StrToDate = convert(varchar(8), getdate(), 112)	

	exec @rc = ExportReport @StrIssNo, @StrPrcsId, @RptName, @StrFromDate, @StrToDate, @ErrMsg output

	if @rc > 0
	begin
		return @rc
	end

	return 0

	set nocount off

end
SET QUOTED_IDENTIFIER OFF
GO
