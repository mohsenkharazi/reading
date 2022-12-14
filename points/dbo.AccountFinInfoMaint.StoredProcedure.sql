USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AccountFinInfoMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	: CarDtrend Systems Sdn. Bhd.
Modular		: CarDtrend Card Management System (CCMS)- Issuing Module

Objective	: Update Account Financial info detail.

SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/01/24 Jacky		   Initial development
2004/07/02 Chew Pei			Added in LastUpdDate. 
							This is to ensure that user refresh one screen before 
							record is being updated. This is to avoid user updating a
							record while Batch Processing is running / users accessing 
							the same screen and update record concurrently.
*******************************************************************************/
	
CREATE	procedure [dbo].[AccountFinInfoMaint]
	@AcctNo uAcctNo,
	@CreditLimit money,
	@AllowanceFactor tinyint,
	@LitLimit money,
	@LastUpdDate varchar(30)
  as
begin
	declare @PrcsName varchar(50),
		@IssNo uIssNo,
		@LatestUpdDate datetime

	select @PrcsName = 'AccountFinInfoMaint'

	exec TraceProcess @IssNo, @PrcsName, 'Start'
	
	if @LastUpdDate is null
		select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))
	
	select @LatestUpdDate = LastUpdDate from iac_AccountFinInfo where AcctNo = @AcctNo
	if @LatestUpdDate is null
		select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

	-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
	-- it means that record has been updated by someone else, and screen need to be refreshed
	-- before the next update.

	if @LatestUpdDate = convert(datetime, @LastUpdDate)
	begin
		update iac_AccountFinInfo set CreditLimit = @CreditLimit,
			AllowanceFactor = @AllowanceFactor, LitLimit = @LitLimit, LastUpdDate = getdate()
		where AcctNo = @AcctNo

		if @@rowcount = 0
			return 70126	-- Failed to update

		return 50092	-- Updated successfully
	end
	else
	begin
		return 95307
	end
	
end
GO
