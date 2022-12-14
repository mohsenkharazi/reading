USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ContactDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	:To delete existing contact.
-------------------------------------------------------------------------------
When		Who		CRN	Description
-------------------------------------------------------------------------------
2002/01/22 	Wendy		Initial development
2002/02/05 	CK			Modify to cater for corporate contact entry
2018/11/01	Humairah	Add deletion on web_membership
2019/05/09  Azan		Update email in web_memebrship to null if email deleted 
*******************************************************************************/
/*
DECLARE @RC int
EXEC @RC = ContactDelete
	@IssNo = 1,
	@RefKey = 8337877,
	@RefCd = 13,
	@RefTo = 'ENTT'
SELECT @RC
*/	
CREATE procedure [dbo].[ContactDelete]
	@IssNo uIssNo,
	@RefKey nvarchar(19),
	@RefCd uRefCd,
	@RefTo uRefCd	-- Require front-end to pass in this value
   as
begin
	declare @CardNo uCardNo, @rc int
	select @CardNo = CardNo from iac_Card (nolock) where EntityId = @RefKey
	
BEGIN TRANSACTION

	if @RefCd = 11
	begin
		exec @rc = usp_CommandQueue_Insert_DeleteCardContactCommand @CardNo
	end

	delete  from iss_Contact
	where RefKey = @RefKey and RefCd = @RefCd and RefTo = @RefTo and IssNo = @IssNo
	
		if @@error <> 0   
			begin  
				rollback transaction
				return 70146 -- Failed to update  
			end  
		
	if @RefCd  = 13 --and exists ( select 1 from Demo_lms_web..web_membership (nolock) where Refkey = @CardNo )
	begin
		--delete from[$(Demo_lms_web)]..web_Membership  where RefKey = @CardNo 
		update [Demo_lms_web]..web_Membership set Email = '' where Refkey =  cast(@CardNo as varchar(17))
  
		if @@error <> 0   
		begin  
				rollback transaction
				return 70146 -- Failed to update  
		end  
	end

COMMIT TRANSACTION
return 50077	-- Successfully deleted

end
GO
