USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardRangeDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:CardRange deletion.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2003/06/12 Aeris		   Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[CardRangeDelete]
	@CardRangeId nvarchar(10)
   as
begin

	if @CardRangeId is null return 55149

	if exists (select 1 from iss_CardType where CardRangeId = @CardRangeId)
		return 95000

	if exists (select 1 from acq_TxnCodeMapping where CardRangeId = @CardRangeId)
		return 95000

	delete iss_CardRange
	where CardRangeId = @CardRangeId

	if @@rowcount = 0
	begin
		return 70426
	end
	return 50291
	
end
GO
