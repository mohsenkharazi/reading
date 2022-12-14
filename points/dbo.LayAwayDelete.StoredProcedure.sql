USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[LayAwayDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To delete existing lay away records.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/03/01 Wendy		   Initial development
*******************************************************************************/
	
CREATE procedure [dbo].[LayAwayDelete]	
	@RefId uIssNo
  as
begin
	delete from iac_LayAway where RefId=@RefId 
	return 50120 -- Successfully deleted
end
GO
