USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[EventDetailMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:To insert event details (narratives for active events only).
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/07/15 Sam		   Initial development

*******************************************************************************/

CREATE procedure [dbo].[EventDetailMaint]
	@Func varchar(5),
	@EventId int,
	@Descp nvarchar(200),
	@SeqNo smallint
  as
begin
	if @EventId is null return 60023
	if @Descp is null return 55017

	if @Func = '&Add'
	begin
		select @SeqNo = isnull(max(SeqNo), 0) + 1 from aac_EventDetail where EventId = @EventId

		insert aac_EventDetail
		( EventId, SeqNo, Descp, CreationDate, CreatedBy )
		select @EventId, @SeqNo, @Descp, getdate(), system_user
		if @@rowcount = 0 or @@error <> 0 return 70215
		return 50199
	end

	update aac_EventDetail
	set Descp = @Descp,
		LastUpdDate = getdate()
	where EventId = @EventId and SeqNo = @SeqNo
	if @@rowcount = 0 or @@error <> 0 return 70216
	return 50200
end
GO
