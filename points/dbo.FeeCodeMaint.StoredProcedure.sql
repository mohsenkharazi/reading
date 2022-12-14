USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[FeeCodeMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To insert new or update existing fee code.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2001/12/20 Sam			   Initial development
2004/07/08 Chew Pei			Change to standard coding
2004/07/21 Alex				Add LastUpdDate
*******************************************************************************/
	
CREATE procedure [dbo].[FeeCodeMaint]
	@Func varchar(5),
	@IssNo uIssNo,
	@FeeCd uRefCd,
	@Descp uDescp50,
	@TxnCd uTxnCd,
	@Fee money,
	@Pts money,
	@FeeType uRefCd,
	@LastUpdDate varchar(30)
  as
begin
	declare @LatestUpdDate datetime	

	if @FeeCd is null return 55022
	if @Descp is null return 55017
	if @TxnCd is null return 55069
	if @FeeType is null return 55106

	if @Func = 'Add'	
	begin
		if exists (select 1 from iss_FeeCode where IssNo = @IssNo and FeeCd = @FeeCd)
			return 65006	-- Fee code already exists

		insert iss_FeeCode (IssNo, FeeCd, Descp, TxnCd, Fee, Pts, FeeType, LastUpdDate)
		select @IssNo, @FeeCd, isnull(@Descp, 'X'), @TxnCd, @Fee, @Pts, @FeeType, getdate()

		if @@error <> 0
		begin
			return 70018
		end
		return 50013
	end
	if @Func = 'Save'
	begin
		if not exists (select 1 from iss_FeeCode where IssNo = @IssNo and FeeCd = @FeeCd)
			return 60050	-- Fee code not found
		
		if @LastUpdDate is null
			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

		select @LatestUpdDate = LastUpdDate from iss_FeeCode where IssNo = @IssNo and FeeCd = @FeeCd
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
			update iss_FeeCode
			set Descp = @Descp, 
			    TxnCd = @TxnCd,
			    Fee = @Fee,
			    Pts = @Pts, 
			    FeeType = @FeeType,
			    LastUpdDate = getdate()
			where IssNo = @IssNo and FeeCd = @FeeCd

			if @@error <> 0
			begin
				return 70019
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

		return 50014
	end
end
GO
