USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchMessageHandlerMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
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
When	   Who		CRN	    Description
-------------------------------------------------------------------------------
2002/11/16 Sam			    Initial development
2003/08/21 Sam				Incl. force settlement ind.
2004/07/71 Alex				Add LastUpdDate
*******************************************************************************/

CREATE procedure [dbo].[MerchMessageHandlerMaint]
	@Func varchar(8),
	@AcqNo uAcqNo,
	@MsgType smallint,
	@PrcsCd int,
	@TxnInd char(1),
	@SupportInd uYesNo,
	@Descp uDescp50,
	@ReverseLimitInd uYesNo,
	@ShortDescp nvarchar(20),
	@Remarks uDescp50, 
	@Multiplier uRefCd,
	@ForceSettle uYesNo,
	@LastUpdDate varchar(30)

  as
begin
	declare @eRemarks uDescp50, @LatestUpdDate datetime, @SysDate datetime

	set nocount on
	set dateformat ymd

	select @SysDate = getdate()

	if @MsgType is null return 60067 --Message Type not found
	if @PrcsCd is null return 60066 --Processing Code not found

	if @Func = 'Add'
	begin
		if @Descp is null return 60064 --Program/ Description not found
		if @TxnInd is null return 60064 --Transaction Indicator not found

		if exists (select 1 from acq_MessageHandle where rtrim(ltrim(Remarks)) = rtrim(ltrim(@Remarks)))
			return 95081 --Invalid Description/ Reference No

		insert acq_MessageHandle
		( AcqNo, MsgType, PrcsCd, TxnInd, SupportInd, Descp, ShortDescp, ReverseLimitInd, Remarks, Multiplier, ForceSettlementInd, LastUpdDate )
		values (@AcqNo, @MsgType, @PrcsCd, @TxnInd, @SupportInd, @Descp, @ShortDescp, @ReverseLimitInd, @Remarks, @Multiplier, @ForceSettle, getdate() )

		if @@rowcount = 0 or @@error <> 0 return 70389 --Failed to insert Message Handler
		return 50258 --Merchant Message Handler has been created successfully
	end
	else
	if @Func = 'Save'
	begin
		select @eRemarks = Remarks from acq_MessageHandle where AcqNo = @AcqNo and MsgType = @MsgType and PrcsCd = @PrcsCd

		if @@rowcount = 0 or @@error <> 0 
			return 60068 --Message Handle not found

		if @eRemarks is not null and @eRemarks <> @Remarks
		begin
			if exists (select 1 from acq_MessageHandle where rtrim(ltrim(Remarks)) = rtrim(ltrim(@Remarks)))
					return 95081 --Invalid Description/ Reference No
		end

		if not exists (select 1 from acq_MessageHandle where AcqNo = @AcqNo and MsgType = @MsgType and PrcsCd = @PrcsCd)
			return 60068 --Message Handle not found

		if @Descp is null return 60059 --Program/ Description not found
		if @TxnInd is null return 60065 --Transaction Indicator not found
--		if @TxnSts is null return 55140 --Transaction Status is a compulsory field

		select @LatestUpdDate = LastUpdDate
		from acq_MessageHandle
		where AcqNo = @AcqNo and MsgType = @MsgType and PrcsCd = @PrcsCd

		-----------------
		begin transaction
		-----------------
	
		-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
		-- it means that record has been updated by someone else, and screen need to be refreshed
		-- before the next update.
		if isnull(convert(varchar(30),@LatestUpdDate,120),'') = isnull(@LastUpdDate,'')
		begin

			update acq_MessageHandle
			set TxnInd = @TxnInd, 
				Descp = @Descp, 
				ShortDescp = @ShortDescp, 
				ReverseLimitInd = @ReverseLimitInd, 
				SupportInd = @SupportInd,
				Remarks = @Remarks, 
				Multiplier = @Multiplier, 
				ForceSettlementInd = @ForceSettle,
				LastUpdDate = getdate()
			where AcqNo = @AcqNo and MsgType = @MsgType and PrcsCd = @PrcsCd

			if @@rowcount = 0 or @@error <> 0
			begin
				rollback transaction 
				return 70390 --Failed to update Message Handler
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
		return 50259 --Merchant Message Handler has been updated successfully
	end

	if exists (select 1 from atx_OnlineTxn where AcqNo = @AcqNo and MsgType = @MsgType and PrcsCd = @PrcsCd)
		return 95000

	delete acq_MessageHandle
	where AcqNo = @AcqNo and MsgType = @MsgType and PrcsCd = @PrcsCd

	if @@rowcount = 0 or @@error <> 0 return 70391 --Failed to delete Message Handler
	return 50260 --Merchant Message Handler has been deleted successfully 
end
GO
