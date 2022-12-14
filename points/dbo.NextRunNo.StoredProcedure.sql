USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[NextRunNo]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Generate the next sequence number for a control ID

-------------------------------------------------------------------------------
When	   Who		CRN	   Desc
-------------------------------------------------------------------------------
2001/10/02 Jacky		   Initial development

*******************************************************************************/

CREATE	procedure [dbo].[NextRunNo]
	@IssNo uIssNo,
	@Ctrl varchar(20)

--with encryption 
as
begin
	declare @CtrlNo int, @rc int, @er int

	select @CtrlNo = isnull(CtrlNo, 0)
	from iss_Control
	where CtrlId = @Ctrl and IssNo = @IssNo

	if @@rowcount = 0
	begin
		insert iss_Control (IssNo, CtrlId, Descp, CtrlNo, CtrlDate, LastUpdDate)
		values (@IssNo, @Ctrl, 'System Generated', 1, null, getdate())

		if @@error <> 0 return 70330	-- Failed to create new Control

		return 1
	end

	while 1 = 1
	begin
		update iss_Control
		set CtrlNo = @CtrlNo+1
		where CtrlId = @Ctrl and CtrlNo = @CtrlNo and IssNo = @IssNo

		select @er = @@error, @rc = @@rowcount

		if @er <> 0 return 70331	-- Failed to update Control

		if @rc = 1
		begin
			return @CtrlNo+1
		end

		select @CtrlNo = isnull(CtrlNo, 0)
		from iss_Control
		where CtrlId = @Ctrl and IssNo = @IssNo
	end
end
GO
