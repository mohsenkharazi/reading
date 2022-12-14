USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[NextTaxInvoice]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Generate the next sequence number for a control ID
			Counter check last update month, reset to 0 if the month is diff.

-------------------------------------------------------------------------------
When	   Who		CRN	   Desc
-------------------------------------------------------------------------------
2001/09/03 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[NextTaxInvoice]
	@IssNo uIssNo,
	@PrcsDate datetime,
	@Ctrl varchar(20)
  as
begin
	declare @CtrlNo int, @rc int, @er int, @CtrlDate datetime

	select @CtrlNo = isnull(CtrlNo, 0),
			@CtrlDate = CtrlDate
	from iss_Control
	where CtrlId = @Ctrl and IssNo = @IssNo

	if @@rowcount > 0 and @@error = 0
	begin
		if datepart(mm, @CtrlDate) <> datepart(mm, @PrcsDate)
		begin
			select @CtrlNo = 0

			update iss_Control
			set CtrlNo = @CtrlNo,
				CtrlDate = @PrcsDate
			where CtrlId = @Ctrl and IssNo = @IssNo

			if @@error <> 0 return 70330	-- Failed to create new Control
		end
	end
	else
	begin
		insert iss_Control (IssNo, CtrlId, Descp, CtrlNo, CtrlDate, LastUpdDate)
		values (@IssNo, @Ctrl, 'TaxInvoice', 0, null, getdate())

		if @@error <> 0 return 70330	-- Failed to create new Control
	end

	while 1 = 1
	begin
		update iss_Control
		set CtrlNo = @CtrlNo + 1,
			CtrlDate = @PrcsDate
		where CtrlId = @Ctrl and CtrlNo = @CtrlNo and IssNo = @IssNo

		select @er = @@error, @rc = @@rowcount

		if @er <> 0 return 70331	-- Failed to update Control

		if @rc = 1
		begin
			return @CtrlNo + 1
		end

		select @CtrlNo = isnull(CtrlNo, 0)
		from iss_Control
		where CtrlId = @Ctrl and IssNo = @IssNo
	end
end
GO
