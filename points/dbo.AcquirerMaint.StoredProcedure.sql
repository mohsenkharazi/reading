USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AcquirerMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Acquirer maintenance
-------------------------------------------------------------------------------
When	   Who		CRN		Description
-------------------------------------------------------------------------------
2001/11/27 Sam				Initial development
2003/06/26 Aeris			Add in VATRate field
2003/09/10 Sam				Incl. TaxId.
2004/07/14 Chew Pei			Add LastUpdDate
*******************************************************************************/
CREATE procedure [dbo].[AcquirerMaint]
	@AcqNo uAcqNo,
	@CoRegNo varchar(15),
	@BusnName uBusnName,
	@Pic nvarchar(50),
	@SetupDate datetime,
	@LangId uRefCd,
	@CrryCd uRefCd,
	@CtryCd uRefCd,
	@CutOffTime varchar(8),
	@VATRate smallint, --2003/06/26
	@TaxId uTaxId,
	@LastUpdDate varchar(30)
  as
begin
	declare @LatestUpdDate datetime
/*	if not exists (select 1 from acq_User where UserId = @User and PrivilegeCd = 1)
	begin
		return '90000'
	end
*/
	if @BusnName is null return 55118
	if @Pic is null return 55124
	if @SetupDate is null return 55170
	if @LangId is null return 55171
	if @CrryCd is null return 55025
	if @CtryCd is null return 55026
	if @VATRate is null return 55169
	if @TaxId is null return 55162	--Tax Id is a compulsory field

	if @LastUpdDate is null
		select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

	select @LatestUpdDate = LastUpdDate from acq_Acquirer where @AcqNo = AcqNo
	if @LatestUpdDate is null
		select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

	-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
	-- it means that record has been updated by someone else, and screen need to be refreshed
	-- before the next update.
	if @LatestUpdDate = convert(datetime, @LastUpdDate)
	begin
		update acq_Acquirer
		set BusnName = @BusnName,
			CoRegsNo = @CoRegNo,
			LangId = @LangId,
			CtryCd = @CtryCd,
			CrryCd = @CrryCd,
			CreationDate = @SetupDate,
			PersonInCharge = @Pic,
			VATRate = @VATRate, --2003/06/26
			TaxId = @TaxId,
			LastUpdDate = getdate()
		where @AcqNo = AcqNo

		if @@rowcount = 0 or @@error <> 0 return 70397 --Failed to update Acquirer

	end
	else
	begin
		return 95307 -- Session Expired
	end

	if len(@CutOffTime) <> 8
		return 95216

	if substring(@CutOffTime, 3,1) <> ':' or substring(@CutOffTime, 6,1) <> ':'
		return 95216 --Invalid cut off time

	if isnumeric(substring(@CutOffTime, 1,2)) <> 1 or isnumeric(substring(@CutOffTime, 4,2)) <> 1 or isnumeric(substring(@CutOffTime, 7,2)) <> 1
		return 95216

	if cast(substring(@CutOffTime, 1,2) as tinyint) > 23 or cast(substring(@CutOffTime, 4,2) as tinyint) > 59 or cast(substring(@CutOffTime, 7,2) as tinyint) > 59
		return 95216

	update acq_Default set VarcharVal = @CutOffTime where AcqNo = @AcqNo and Deft = 'CutOffTime'
	if @@rowcount = 0 or @@error <> 0 
		return 95216

	return 50264 --Acquirer has been updated successfully
end
GO
