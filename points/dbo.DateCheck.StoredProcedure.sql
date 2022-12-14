USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[DateCheck]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	:To check the allowable period between termination/expiry date and current date
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/02/25 Wendy		   Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[DateCheck]
	@IssNo uIssNo,
	@CardNo varchar(19),
	@Code char(1) output
  as
begin
	declare @ExpiryDate datetime,
		@TerminationDate datetime,
		@Date datetime

	select	@ExpiryDate = convert(datetime,(convert(varchar,(dateadd(mm, -1, ExpiryDate)), 103)),103),
		@TerminationDate = convert(datetime,(convert(varchar,(dateadd(mm, -1, TerminationDate)), 103)),103)
	from iac_Card where IssNo = @IssNo and CardNo=@CardNo

	select @Date= CtrlDate from iss_Control where IssNo = @IssNo and CtrlId = 'PrcsId'
		
	if (@TerminationDate is null)
	begin
		if (@Date < @ExpiryDate) 
		begin		
			select @Code = '0' --Current date is before expiry date period
		end
		else select @Code = '1' --Current date falls within expiry date period
	end
	else
	begin
		if (@Date < @TerminationDate) 
		begin		
			select @Code = '0' --Current date is before termination date period
		end
		else select @Code = '1' --Current date falls within termination date period
	end
	
end
GO
