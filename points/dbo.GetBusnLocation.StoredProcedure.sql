USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GetBusnLocation]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Generate business location number.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/10 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[GetBusnLocation]
	@AcqNo uAcqNo,
	@BusnLocation uMerch output
  as
begin
	declare @iBusnLocation bigint, @rBusnLocation varchar(15)

	set nocount on

	select @iBusnLocation = cast(isnull(LastBusnLocation, '0') as bigint)
	from acq_Acquirer
	where AcqNo = @AcqNo

	if @@error <> 0 return 70330	-- Failed to create new Control

	while 1 = 1
	begin
		select @rBusnLocation = replicate ('0', 15 - len(cast(@iBusnLocation + 1 as varchar(15)))) + convert(varchar(15), @iBusnLocation + 1)

		update acq_Acquirer
		set LastBusnLocation = @rBusnLocation
		where AcqNo = @AcqNo

		if @@error = 0
		begin
			select @BusnLocation = @rBusnLocation
			if exists (select 1 from acq_Acquirer where LastBusnLocation = @rBusnLocation)
				return 0
		end

		select @iBusnLocation = cast(isnull(LastBusnLocation, '0') as bigint)
		from acq_Acquirer
		where AcqNo = @AcqNo

		if @@error <> 0 break
	end

	return 0
end
GO
