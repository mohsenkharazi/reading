USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardRangeMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Insert or update Card Range.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/12 Aeris			Initial development
2004/07/06 Chew Pei			Add LastUpdDate & Card Category
							This is to ensure that user refresh one screen before 
							record is being updated. This is to avoid user updating a
							record while Batch Processing is running / users accessing 
							the same screen and update record concurrently.
*******************************************************************************/
	
CREATE procedure [dbo].[CardRangeMaint]
	@Func varchar(5),
	@CardRangeId nvarchar(10),
	@Descp nvarchar(50),
	@StartNo varchar (19),
	@EndNo varchar (19),
	@CardCategory uRefCd,
	@LastUpdDate varchar(30)
   as
begin
	
	declare @LatestUpdDate datetime

	if @Descp is null return 55017
	if @CardRangeId is null return 55149
	if @StartNo is null or @EndNo is null return 95251
	if convert(bigint,@StartNo) > convert(bigint,@EndNo) return 95250

	if @Func = 'Add'
	begin
		if exists (select 1 from iss_CardRange where @CardRangeId = CardRangeId)
			return 65046
		if exists (Select 1 from iss_CardRange where @StartNo Between StartNo and EndNo)
			return 95048
		if exists (Select 1 from iss_CardRange where  @EndNo Between StartNo and EndNo)
			return 95048
		if exists (Select 1 from iss_CardRange where  StartNo Between @StartNo and @EndNo)
			return 95048
		if exists (Select 1 from iss_CardRange where  EndNo Between @StartNo and @EndNo)
			return 95048
		
		insert into iss_CardRange (CardRangeId, Descp, StartNo, CurrNo, EndNo, CardCategory, LastUpdDate)
		select @CardRangeId, @Descp, convert(bigint,@StartNo), 0, convert(bigint,@EndNo), @CardCategory, getdate()

		if @@rowcount = 0
		begin
			return 70428
		end

		return 50293
	end

	if @Func = 'Save'
	begin
		if not exists (select 1 from iss_CardRange where @CardRangeId = CardRangeId)
			return 95246
		if exists (Select 1 from iss_CardRange where @CardRangeId <> CardRangeId and @StartNo Between StartNo and EndNo)
			return 95048
		if exists (Select 1 from iss_CardRange where @CardRangeId <> CardRangeId and @EndNo Between StartNo and EndNo)
			return 95048
		if exists (Select 1 from iss_CardRange where @CardRangeId <> CardRangeId and StartNo Between @StartNo and @EndNo)
			return 95048
		if exists (Select 1 from iss_CardRange where @CardRangeId <> CardRangeId and EndNo Between @StartNo and @EndNo)
			return 95048
		
		if @LastUpdDate is null
			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

		select @LatestUpdDate = LastUpdDate from iss_CardRange where CardRangeId = @CardRangeId
		if @LatestUpdDate is null
			select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

		-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
		-- it means that record has been updated by someone else, and screen need to be refreshed
		-- before the next update.
		if @LatestUpdDate = convert(datetime, @LastUpdDate)
		begin
			update iss_CardRange
			set Descp =@Descp,
				StartNo = convert(bigint,@StartNo),
				EndNo = convert(bigint,@EndNo),
				CardCategory = @CardCategory,
				LastUpdDate = getdate()
			where CardRangeId = @CardRangeId

			if @@rowcount = 0
			begin
				return 70427
			end

			return 50292
		end
		else 
		begin
			return 95307 -- Application session expired. Please re-Logon
		end
	end

end
GO
