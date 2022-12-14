USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchDeviceTypeMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Device Type maintenance.

		Device Model for EDC/ CAT/ Pin Pad/ Printer etc.

Called By	:
SP Level	:Primary
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/08/23 Sam			   Initial development
2004/07/08 Chew Pei			Change to standard coding
2005/04/29 Chew Pei			Add description for Func "Add"
*******************************************************************************/

CREATE procedure [dbo].[MerchDeviceTypeMaint]
	@Func varchar(8),
	@AcqNo uAcqNo,
	@ProdType nvarchar(15),
	@DeviceType uRefCd,
	@Unit int,
	@Descp nvarchar(100),
	@LastUpdDate varchar(10),
	@PurchDate datetime,
	@ManufacturerDate datetime
  as
begin
--	if @ProdType is null return 55121

	if @Func = 'Add'
	begin
		insert atm_DeviceType
		(AcqNo, ProdType, DeviceType, TotalUnit, PurchDate, ManufacturerDate, Descp, CreationDate)
		select @AcqNo, @ProdType, @DeviceType, @Unit, @PurchDate, @ManufacturerDate, @Descp, getdate()

		if @@rowcount = 0 or @@error <> 0 return 70246

		return 50201
	end

	if @Func = 'Save'
	begin
		update atm_DeviceType
		set TotalUnit = @Unit,
			ProdType = @ProdType,
			DeviceType = @DeviceType,
			Descp = @Descp,
			PurchDate = @PurchDate,
			ManufacturerDate = @ManufacturerDate
		where AcqNo = @AcqNo and ProdType = @ProdType

		if @@rowcount = 0 or @@error <> 0 return 70245

		return 50202
	end
/*	if @Func = 'Save'
	begin
		update atm_DeviceType
		set TotalUnit = @Unit,
			ProdType = @ProdType,
			DeviceType = @DeviceType,
			Descp = @Descp,
			PurchDate = @PurchDate,
			ManufacturerDate = @ManufacturerDate
		where AcqNo = @AcqNo and ProdType = @ProdType
		if @@rowcount = 0 or @@error <> 0 return 70245
		return 50202
	end
	else
		if @Func = 'Add'
		begin
			insert atm_DeviceType
				(AcqNo, ProdType, DeviceType, TotalUnit, PurchDate, ManufacturerDate, CreationDate)
			select @AcqNo, @ProdType, @DeviceType, @Unit, @PurchDate, @ManufacturerDate, getdate()
			if @@rowcount = 0 or @@error <> 0 return 70246
			return 50201
		end
*/
	if (select count(*) from atm_TerminalInventory where AcqNo = @AcqNo and ProdType = @ProdType) > 0 return 95000

	delete atm_DeviceType
	where AcqNo = @AcqNo and ProdType = @ProdType
	if @@rowcount = 0 or @@error <> 0 return 70247
	return 50203
end
GO
