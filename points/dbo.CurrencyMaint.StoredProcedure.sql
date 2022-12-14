USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CurrencyMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Insert or update Currency code.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2001/12/19 Sam			   Initial development
2002/02/05 Wendy		   To capture currency details (with exchange rate) 
						   into iss_Currency
2004/07/08 Chew Pei			Change to Standard coding				   	
*******************************************************************************/
	
CREATE procedure [dbo].[CurrencyMaint]
	@Func varchar(5),
	@IssNo smallint,
	@CrryCd uRefCd,
	@Descp uDescp50,
	@Unit int,
	@Rate money,
	@ShortDescp nvarchar(10),
	@LastUpdDate varchar(50)
   as
begin
	declare @LatestUpdDate datetime

	if @Descp is null
	begin
		return 55017
	end

	if @CrryCd is null
	begin
		return 55077
	end

	if @Func = 'Add'
	begin
		insert iss_Currency
		(IssNo, CrryCd, Descp, Unit, Rate, ShortDescp, LastUpdDate)
		select @IssNo,@CrryCd, @Descp,@Unit,@Rate,@ShortDescp, getdate()

		if @@rowcount = 0
		begin
			return 70106
		end
		return 50062
	end

	if @Func = 'Save'
	begin
		if @LastUpdDate is null
			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

		select @LatestUpdDate = LastUpdDate from iss_Currency where IssNo = @IssNo and CrryCd = @CrryCd
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
			update iss_Currency
			set Descp = @Descp, 
				Unit = @Unit, 
				Rate = @Rate, 
				ShortDescp=@ShortDescp,
				LastUpdDate = getdate()
			where IssNo = @IssNo and CrryCd = @CrryCd 

			if @@rowcount = 0
			begin
				return 70107
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
		return 50063
	end
end
GO
