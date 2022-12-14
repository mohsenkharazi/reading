USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[InvoiceControlDetailDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Delete invoice control detail.

-------------------------------------------------------------------------------
When	  	 Who		CRN	   Description
-------------------------------------------------------------------------------
2005/09/29	Esther			   Initial Development
*******************************************************************************/
-- exec InvoiceControlDetailDelete 1,1,'02'
Create procedure [dbo].[InvoiceControlDetailDelete]
	@IssNo uIssNo,
	@CycNo uCycNo,
	@Week smallint
	
as
begin	
	delete  from iss_InvoiceDate where IssNo = @IssNo and CycNo = @CycNo and Week = @Week	
	
	if @@error <> 0
	begin
		return 70907	-- Failed to delete invoice date
	end

	return 54083 -- Invoice Date has been deleted successfully	
end
GO
