USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[DailyAccruedInterestCalculation]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure will calculate daily accrued interest

Calling Sp	: 

Leveling	: Second level
------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2003/07/24 Jacky		   Initial development
******************************************************************************************************************/

CREATE procedure [dbo].[DailyAccruedInterestCalculation]
	@IssNo uIssNo,
	@PrcsId uPrcsId = null
  as
begin
	declare	@PrcsName varchar(50),
			@rc int

	select @PrcsName = 'InterestCalculation'

	exec TraceProcess @IssNo, @PrcsName, 'Start'

	if @PrcsId is null
	begin
		select @PrcsId = CtrlNo
		from iss_Control
		where IssNo = @IssNo and CtrlId = 'PrcsId'
	end

	-----------------------------------------------------------------
	BEGIN TRANSACTION
	-----------------------------------------------------------------

	exec @rc = InterestCalculation @IssNo, @PrcsId

	if @@error <> 0 or dbo.CheckRC(@rc) <> 0
	begin
		rollback transaction
		return @rc
	end

	-----------------------------------------------------------------
	COMMIT TRANSACTION
	-----------------------------------------------------------------

	return 50319	-- Daily Accrued Interest Calculation has completed successfully
end
GO
