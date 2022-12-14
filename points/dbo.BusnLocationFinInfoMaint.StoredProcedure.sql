USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BusnLocationFinInfoMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Business Location financial info
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/10 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[BusnLocationFinInfoMaint]
	@Func varchar(5),
	@AcqNo uAcqNo,
	@BusnLocation uMerch,
	@FlrLmt money
   as
begin
	update aac_BusnLocationFinInfo
	set FloorLimit = isnull(@FlrLmt, 0)
	where BusnLocation = @BusnLocation
	if @@rowcount = 0 or @@error <> 0
	begin
		insert aac_BusnLocationFinInfo
		(BusnLocation, LastUpdDate, FloorLimit, LastPaymtDate, LastPaymtAmt)
		values
		(@BusnLocation, null, @FlrLmt, null, 0)
		if @@rowcount = 0 or @@error <> 0 return 70259
		return 50219
	end
	return 50219
end
GO
