USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardTypeMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To insert new or update existing Card Type.
-------------------------------------------------------------------------------
When	   Who		CRN		Description
-------------------------------------------------------------------------------
2003/06/16 Aeris			Initial development
2004/07/07 Chew Pei			Added VehInd & LastUpdDate
							This is to ensure that user refresh one screen before 
							record is being updated. This is to avoid user updating a
							record while Batch Processing is running / users accessing 
							the same screen and update record concurrently.
2004/07/29 Chew Pei			Add Attribute and AuthCardType and Billing Ind
							Attribute Column(Bit 1 = Dual Card, Bit 2 = Billing Ind)
2004/12/07 Chew Pei			If Attribute (Or Dual Card Ind is null) then set Attribute to 0
2009/02/15 Sam				To includes PlasticType as part of pri key.
2009/03/16 Barnett			Add Min/MaxTxnAmt, MaxRdmpCnt/Amt, MaxTxnCnt/Amt
*******************************************************************************/
	
CREATE procedure [dbo].[CardTypeMaint]
	@Func varchar(5),
	@CardLogo uCardLogo,
	@PlasticType uPlasticType,
	@CardType uCardType,
	@CardRangeId nvarChar(10),
	@CardCategory uRefCd,
	@CardTypeDescp uDescp50,
	@VehInd char(1),
	@Attribute char(1), -- Dual Card
	@BillingInd char(1), -- Billing Ind
	@AuthCardType uCardType,
	@LastUpdDate varchar(30),
	@Descp uDescp50,
	@MinAmt money,
	@MaxAmt money,
	@DailySalesMaxCnt int, 
	@DailySalesMaxAmt money,
	@DailyRdmpMaxCnt int,
	@DailyRdmpMaxAmt money
	

   as
begin
	declare @LatestUpdDate datetime
	set nocount on
	
	if @CardLogo is null return 55002
--2009/02/15B
--	if @PlasticType is null return 55003 --Plastic Type is a compulsory field
--2009/02/15E
--	if @CardTypeDescp is null return 55048
--	if @CardRangeId is null return 55149
	if @CardCategory is null return 55150
	if @Descp is null return 55017 -- Description is a compulsory field
	if @VehInd is null select @VehInd = 'N'
	if @MinAmt >= @MaxAmt return 95447 -- Minimum Amt cannot greater or equal to Maximum Amt

--	select @CardTypeDescp = 
--	(select Descp-- + ' ' + cast(StartNo as varchar(19)) +  ' - ' + cast(EndNo as varchar(19)) 'Descp' 
--	From iss_CardRange (nolock))

	if @Attribute = 'Y'
	begin
		if @BillingInd = 'Y' 
		begin
			select @Attribute = '3'  -- Is a Dual Card and Transaction will bill to this card type
		end
		if @BillingInd = 'N'
		begin
			select @Attribute = '1' -- Is a Dual Card but transaction will not be billed to this card
		end
	end
	else
		select @Attribute = 0

	if @Func = 'Add'
	begin
--2009/02/15B
		--if exists (select 1 from iss_CardType where CardRangeId = @CardRangeId) return 65046 --Card Range Id already exists
--2009/02/15E
		insert into iss_CardType 
			(CardLogo, PlasticType, Descp, CardRangeId, CardCategory, VehInd, Attribute, AuthCardType, LastUpdDate,
			MinAmt,MaxAmt,DailySalesMaxCnt,DailySalesMaxAmt,DailyRdmpMaxCnt,DailyRdmpMaxAmt)
		values (@CardLogo, @PlasticType, @Descp, @CardRangeId, @CardCategory, @VehInd, @Attribute, @AuthCardType, getdate(),
				@MinAmt, @MaxAmt, @DailySalesMaxCnt, @DailySalesMaxAmt, @DailyRdmpMaxCnt, @DailyRdmpMaxAmt)
		if @@rowcount = 0
		begin
			return 70430
		end
		return 50295
	end

	if @Func = 'Save'
	begin
		if @LastUpdDate is null
			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

		select @LatestUpdDate = LastUpdDate 
		from iss_CardType (nolock) where CardType = @CardType

		if @LatestUpdDate is null
			select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

		-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
		-- it means that record has been updated by someone else, and screen need to be refreshed
		-- before the next update.
		if @LatestUpdDate = convert(datetime, @LastUpdDate)
		begin
			update iss_CardType
			set CardLogo = @CardLogo,
				PlasticType = @PlasticType,
				Descp = @Descp,
				CardRangeId = @CardRangeId,
				CardCategory = @CardCategory,
				VehInd = @VehInd,	
				Attribute = @Attribute,
				AuthCardType = @AuthCardType,
				LastUpdDate = getdate(),
				MinAmt =@MinAmt,
				MaxAmt =@MaxAmt,
				DailySalesMaxCnt = @DailySalesMaxCnt,
				DailySalesMaxAmt = @DailySalesMaxAmt,
				DailyRdmpMaxCnt = @DailyRdmpMaxCnt,
				DailyRdmpMaxAmt = @DailyRdmpMaxAmt
			where CardType = @CardType

			if @@rowcount = 0
			begin
				return 70431
			end
		end
		else
		begin
			return 95307	-- Session Expired
		end
		return 50296
	end
end
GO
