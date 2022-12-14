USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchTypeMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:MCC and SIC maintenance.
		
SP Level	:Primary

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/05/30 Sam			   Initial development
2004/07/08 Chew Pei			Change to standard coding
2004/07/22 Alex				Add LastUpdDate
2005/09/28 Alex				Add Code
*******************************************************************************/

CREATE procedure [dbo].[MerchTypeMaint]
	@Func varchar(6),
	@Type char(1),
	@CategoryCd varchar(5),
	@Descp uDescp50,
	@Code char(1),
	@LastUpdDate varchar(30)
  as
begin
	declare @LatestUpdDate datetime

	if @CategoryCd is null return 55021
	if @Descp is null return 55017
	

	if @Func = 'Add'
	begin
		if exists (select 1 from cmn_MerchantType where Type = @Type and CategoryCd = @CategoryCd)
			return 65009

		insert cmn_MerchantType
		(Type, CategoryCd, Descp, Code, LastUpdDate)
		values
		(@Type, @CategoryCd, @Descp, @Code, getdate())

		if @@rowcount = 0 or @@error <> 0 return 70240
		return 50197		
	end

	if @Func = 'Save'
	begin
		if not exists (select 1 from cmn_MerchantType where Type = @Type and CategoryCd = @CategoryCd)
		return 60038

		if @LastUpdDate is null
		select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

		select @LatestUpdDate = LastUpdDate from cmn_MerchantType where Type = @Type and CategoryCd = @CategoryCd
		if @LatestUpdDate is null
			select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

		-----------------
		begin transaction
		-----------------
	
		-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
		-- it means that record has been updated by someone else, and screen need to be refreshed
		-- before the next update.
		if @LatestUpdDate = convert(datetime, @LastUpdDate)
		begin
			update cmn_MerchantType
			set Descp = @Descp,
				Code = @Code,
				LastUpdDate = getdate()
			where Type = @Type and CategoryCd = @CategoryCd

			if @@rowcount = 0 or @@error <> 0
			begin
				rollback transaction
				return 70241
			end
		end
		else
		begin
			rollback transaction
			return 95307
		end
		------------------
		commit transaction
		------------------
		return 50196
	end

/*	if @Func = 'Save'
	begin
		if not exists (select 1 from cmn_MerchantType where Type = @Type and CategoryCd = @CategoryCd)
			return 60038

		update cmn_MerchantType
		set Descp = @Descp,
			LastUpdDate = getdate()
		where Type = @Type and CategoryCd = @CategoryCd
		if @@rowcount = 0 or @@error <> 0 return 70241
		return 50196
	end

	if exists (select 1 from cmn_MerchantType where Type = @Type and CategoryCd = @CategoryCd)
		return 65009

	insert cmn_MerchantType
	(Type, CategoryCd, Descp, LastUpdDate)
	values
	(@Type, @CategoryCd, @Descp, getdate())
	if @@rowcount = 0 or @@error <> 0 return 70240
	return 50197
*/
end
GO
