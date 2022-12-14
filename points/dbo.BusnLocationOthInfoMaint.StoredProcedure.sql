USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BusnLocationOthInfoMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module
Objective	:Business Location Other Info
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2005/10/10 KY			Initial development

*******************************************************************************/

CREATE procedure [dbo].[BusnLocationOthInfoMaint]
	@AcqNo uAcqNo,
	@BusnLocation uMerchNo,
	@Msg1 nvarchar(24),
	@Msg2 nvarchar(24)
  as
begin
	if not exists (select 1 from aac_BusnLocation where AcqNo = @AcqNo and BusnLocation = @BusnLocation)
	begin
		return 60010	-- Merchant not found
	end
	else
	begin
		update aac_BusnLocation
		set Msg1 = @Msg1, Msg2 = @Msg2
		where AcqNo = @AcqNo and BusnLocation = @BusnLocation

		if @@error <> 0 return 70222	-- Failed to update Merchant

		return 50179	-- Merchant has been updated successfully
	end
end
GO
