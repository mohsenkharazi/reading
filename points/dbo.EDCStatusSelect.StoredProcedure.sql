USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[EDCStatusSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To select the status of EDC dail-up on negative, product & reward
		 downloading.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2003/03/22 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[EDCStatusSelect]
	@AcqNo uAcqNo,
	@TermId uTermId,
	@Date char(7)
  as
begin
	declare @SysDate char(6), @EnterDate char(6)
	set nocount on

	select @SysDate = substring(convert(char(8), getdate(), 112), 1,6)
	if @Date is null or substring(@Date,1,2) = ' ' select @EnterDate = @SysDate
	else
	begin
		if len(@Date) <> 6 or
			isnumeric(substring(@Date, 1,4)) <> 1 or
			isnumeric(substring(@Date, 6,2)) <> 1 or
			substring(@Date, 6,2) < '01' or
			substring(@Date, 6,2) > '12' or
			substring(@Date, 5,1) <> '/' or
			substring(@Date, 1,4) > substring(@SysDate, 1,4) or
			substring(@Date, 1,4) < '1999' or substring(@Date, 1,4) > '2050'
			select @EnterDate = @SysDate
		else
			select @EnterDate = substring(@Date,1,4) + substring(@Date,6,2)
		if @EnterDate > @SysDate select @EnterDate = @SysDate --return 95143 --Entry Date greater than system date
	end

	select LastUpdDate, RefNo, LastNo
	from aac_DownLoadLog
	where AcqNo = @AcqNo and TermId = @TermId and substring(convert(char(8), LastUpdDate, 112), 1,6) = @EnterDate
	return 0
end
GO
