USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BatchSettlementSearch]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:BatchSettlementSearch
		
		Only search for settled batch transactions
		

Called by	:

SP Level	:Primary

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/17 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[BatchSettlementSearch]
	@BusnLocation uMerch,
	@TermId uTermId,
	@BatchId uBatchId,
	@SettleFromDate datetime,
	@SettleToDate datetime
   as
begin
	declare @WildCard int, @StartDate char(8), @EndDate char(8), @SysDate datetime

--	if @TermId is null and @BatchId is null and isdate(@SettleFromDate) = 0 and isdate(@SettleToDate) = 0 return 95144
	set nocount on

--	select @WildCard = isnull(charindex('%', @TermId), 0)

	select @SysDate = getdate()

	if isdate(@SettleFromDate) = 0 select @SettleFromDate = @SysDate
	if isdate(@SettleToDate) = 0 select @SettleToDate = @SysDate
	if convert(char(8), @SettleFromDate, 112) > convert(char(8), @SettleToDate, 112) return 95003
	if convert(char(8), @SettleToDate, 112) > convert(char(8), @SysDate, 112) return 95143
	select @StartDate = convert(char(8), @SettleFromDate, 112)
	select @EndDate = convert(char(8), @SettleToDate, 112)

	if isnull(@TermId,'') <> ''
	begin
		if isnull(@BatchId,0) > 0
		begin
			select BusnLocation 'Merchant No', TermId, SettleDate, InvoiceNo, Amt 'TxnAmt', BatchId, TxnCd, Ids
			from atx_Settlement
			where BusnLocation = @BusnLocation and TermId = @TermId and BatchId = @BatchId
			and convert(char(8), SettleDate, 112) between convert(char(8), @SettleFromDate, 112) and convert(char(8), @SettleToDate, 112)
			return 0
		end

		select BusnLocation 'Merchant No', TermId, SettleDate, InvoiceNo, Amt 'TxnAmt', BatchId, TxnCd, Ids
		from atx_Settlement
		where BusnLocation = @BusnLocation and TermId = @TermId
		and convert(char(8), SettleDate, 112) between convert(char(8), @SettleFromDate, 112) and convert(char(8), @SettleToDate, 112)
		return 0
	end

	if isnull(@BatchId,0) > 0
	begin
		select BusnLocation 'Merchant No', TermId, SettleDate, InvoiceNo, Amt 'TxnAmt', BatchId, TxnCd, Ids
		from atx_Settlement
		where BusnLocation = @BusnLocation and BatchId = @BatchId
		and convert(char(8), SettleDate, 112) between convert(char(8), @SettleFromDate, 112) and convert(char(8), @SettleToDate, 112)
		return 0
	end

	select BusnLocation 'Merchant No', TermId, SettleDate, InvoiceNo, Amt 'TxnAmt', BatchId, TxnCd, Ids
	from atx_Settlement
	where BusnLocation = @BusnLocation
	and convert(char(8), SettleDate, 112) between convert(char(8), @SettleFromDate, 112) and convert(char(8), @SettleToDate, 112)
	return 0
end
GO
