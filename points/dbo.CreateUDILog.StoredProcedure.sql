USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CreateUDILog]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: ALTER  Job Log


*******************************************************************************/

CREATE procedure [dbo].[CreateUDILog]
	@IssNo uIssNo,
	@BatchId uBatchId,
	@Direction char(1),
	@Descp varchar(128),
	@Sts char(1)
   as
begin
	declare @PrcsId int

	if @PrcsId is null
	begin
		select @PrcsId = isnull(CtrlNo, 0)
		from iss_Control
		where IssNo = @IssNo and CtrlId = 'PrcsId'
	end

	insert udi_Log (IssNo, PrcsDate, PrcsId, BatchId, Direction, Descp, UserId, Sts)
	select @IssNo, getdate(), @PrcsId, @BatchId, @Direction, @Descp, system_user, @Sts

	if @@error <> 0 return 70264	-- Failed to create Job Log

	return 50225	-- Job Log created successfully
end
GO
