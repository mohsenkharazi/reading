USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardFinInfoMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	:To update existing card financial information.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/01/28 Wendy		   Initial development
2004/06/28 Chew Pei			Added Odometer Ind
2004/07/02 Chew Pei			Added LastUpdDate.
							This is to ensure that user refresh one screen before 
							record is being updated. This is to avoid user updating a
							record while Batch Processing is running / users accessing 
							the same screen and update record concurrently.
*******************************************************************************/
	
CREATE procedure [dbo].[CardFinInfoMaint]
	@Func varchar(7),
	@CardNo varchar(19),
	@TxnLimit money,
	@LitLimit money,
	@PinAttempted smallint,
	@Pinind uYesNo,
	@OdometerInd uYesNo,
	@LastUpdDate varchar(30)

   as
begin

--	if @EmbName is null return 55059
--	if @AnnlFeeCd is null return 55050
	declare @LatestUpdDate datetime

	if @Func='Save'
	begin

		if @LastUpdDate is null
			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

		select @LatestUpdDate = LastUpdDate from iac_CardFinInfo where CardNo = @CardNo
		if @LatestUpdDate is null
			select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

		-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
		-- it means that record has been updated by someone else, and screen need to be refreshed
		-- before the next update.
		if @LatestUpdDate = convert(datetime, @LastUpdDate)
		begin
			update iac_CardFinInfo set TxnLimit = @TxnLimit, LitLimit = @LitLimit, LastUpdDate = getdate()
			where CardNo=convert(bigint,@CardNo)

			if @@error <> 0 return 70131

			update iac_Card
			set PinInd = @PinInd, OdometerInd = @OdometerInd
			where CardNo = @CardNo

			if @@error <> 0 return 70131
			return 50102
		end
		else
		begin
			return 95307
		end
	end
	else
	begin

		update  iac_CardFinInfo set PinAttempted = @PinAttempted
		where CardNo=convert(bigint,@CardNo)

		if @@error <> 0 return 70131
		--return 50102
		return 50324	--PIN count has been reset successfully   
	end
end
GO
