USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BusnCategoryDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To delete existing Business Category.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2004/12/22 Alex			   Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[BusnCategoryDelete]
	@IssNo uIssNo,
	@BusnCategory uRefCd,
	@Descp uDescp50
   as
begin

	set nocount on


	delete iss_RefLib
	where IssNo = @IssNo and RefCd = @BusnCategory
	
		if @@rowcount = 0
		begin
			return 70881 -- Failed to delete Business Category
		end

	return 54072 -- Business Category has been deleted successfully

end
GO
