USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[EventDetailInsert]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To insert event details (narratives for active events only)
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/01/15 Wendy		   Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[EventDetailInsert]
	@EventId uEventId,
	@Descp nvarchar(400),
	@CreatedBy uUserId
  as
begin
	declare	@CreationDate datetime,
		@Seq int
	
	if @Descp is null return 55017

	select @CreationDate = GETDATE()

	select @Seq = max(Seq) from iac_EventDetail where EventId = @EventId

	select @Seq = isnull(@Seq, 0) + 1

	insert into iac_EventDetail (EventId, Seq, Descp, CreationDate, CreatedBy)
	values (@EventId, @Seq, @Descp, @CreationDate, system_user) 

	if @@error <> 0 return 70196	-- Failed to insert event detail

	return 50070	-- Successfully added
end
GO
