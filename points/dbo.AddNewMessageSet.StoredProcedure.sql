USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AddNewMessageSet]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	: Create a new set of error message for reference based on the 'Item'.

SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/11/29 Jacky		   Initial development

*******************************************************************************/

CREATE procedure [dbo].[AddNewMessageSet]
	@Item varchar(50)
  as
begin
	declare @MsgCd int,
		@Msg varchar(80)

	----------------------------
	-- Add Successful Message --
	----------------------------
	select @MsgCd = isnull(max(MsgCd), 50000)+1
	from iss_Message where MsgCd between 50000 and 53999

	-- Add Nessage
	select @Msg = @Item+' has been added successfully'
	insert iss_Message (MsgCd, LangId, Descp)
	select @MsgCd, 'EN', @Msg

	if @@error <> 0 return 70388	-- Failed to add Message

	select @MsgCd 'MsgCd', @Msg 'Message'

	-- Update Message
	select @Msg = @Item+' has been updated successfully'
	insert iss_Message (MsgCd, LangId, Descp)
	select @MsgCd+1, 'EN', @Msg

	if @@error <> 0 return 70388	-- Failed to add Message

	select @MsgCd+1 'MsgCd', @Msg 'Message'

	-- delete Message
	select @Msg = @Item+' has been deleted successfully'
	insert iss_Message (MsgCd, LangId, Descp)
	select @MsgCd+2, 'EN', @Msg

	if @@error <> 0 return 70388	-- Failed to add Message

	select @MsgCd+2 'MsgCd', @Msg 'Message'

	------------------------
	-- Add Failed Message --
	------------------------
	select @MsgCd = isnull(max(MsgCd), 70000)+1
	from iss_Message where MsgCd between 70000 and 74999

	-- Add Nessage
	select @Msg = 'Failed to add '+@Item
	insert iss_Message (MsgCd, LangId, Descp)
	select @MsgCd, 'EN', @Msg

	if @@error <> 0 return 70388	-- Failed to add Message

	select @MsgCd 'MsgCd', @Msg 'Message'

	-- Update Message
	select @Msg = 'Failed to update '+@Item
	insert iss_Message (MsgCd, LangId, Descp)
	select @MsgCd+1, 'EN', @Msg

	if @@error <> 0 return 70388	-- Failed to add Message

	select @MsgCd+1 'MsgCd', @Msg 'Message'

	-- delete Message
	select @Msg = 'Failed to delete '+@Item
	insert iss_Message (MsgCd, LangId, Descp)
	select @MsgCd+2, 'EN', @Msg

	if @@error <> 0 return 70388	-- Failed to add Message

	select @MsgCd+2 'MsgCd', @Msg 'Message'

	---------------------------
	-- Add Not Found Message --
	---------------------------
	select @MsgCd = isnull(max(MsgCd), 60000)+1
	from iss_Message where MsgCd between 60000 and 64999

	-- Not found Nessage
	select @Msg = @Item+' not found'
	insert iss_Message (MsgCd, LangId, Descp)
	select @MsgCd, 'EN', @Msg

	if @@error <> 0 return 70388	-- Failed to add Message

	select @MsgCd 'MsgCd', @Msg 'Message'

	--------------------------------
	-- Add Already Exists Message --
	--------------------------------
	select @MsgCd = isnull(max(MsgCd), 65000)+1
	from iss_Message where MsgCd between 65000 and 69999

	-- Already exists Nessage
	select @Msg = @Item+' already exists'
	insert iss_Message (MsgCd, LangId, Descp)
	select @MsgCd, 'EN', @Msg

	if @@error <> 0 return 70388	-- Failed to add Message

	select @MsgCd 'MsgCd', @Msg 'Message'
end
GO
