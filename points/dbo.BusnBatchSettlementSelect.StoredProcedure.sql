USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BusnBatchSettlementSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:TxnSettlementSelect
		
		To select transactions belongs to batch id.

Called by	:

SP Level	:Primary

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/17 Sam			   Initial development
2009/03/15 Darren		   Remove convert function on settle date field
2009/03/26 Barnett			Change the validation date format.
2009/12/18 Barnett			Add Nolock
*******************************************************************************/
/*
declare @rc int
exec @rc = BusnBatchSettlementSelect '895000016602502', '26 Feb 2009', '26 Apr 2009'
select @rc
*/
CREATE procedure [dbo].[BusnBatchSettlementSelect]
	@BusnLocation uMerch,
	@FromDate nvarchar(20),
	@ToDate nvarchar(20)
   as
begin
	declare @SysDate datetime,
			@SysToDate datetime,
			@SysFromDate datetime
	set nocount on
	

	select @SysDate = getdate()
--	select @ToDate = convert(nvarchar(12), isnull(@ToDate, @SysDate), 111)
--	select @FromDate = convert(nvarchar(12), isnull(@FromDate, @SysDate), 111)

	if convert(datetime, @FromDate, 112) > convert(datetime, @ToDate +' 23:59:59.000', 112) return 95003	--Starting Date is greater than Ending Date
/*	if convert(datetime, @FromDate, 112) > convert(varchar(12), @SysDate, 112) or	
	convert(datetime, @ToDate +' 23:59:59.000', 112)  > convert(nvarchar(12), @SysDate, 112) 	
	return 95143 --Entry Date greater than system date
*/
	select TxnCd, BusnLocation 'MerchantNo', TermId, BatchId, Qty, Amt 'SettleAmt', 
		BillingAmt, convert(char(10), SettleDate, 103) 'SettleDate', 
		Ids, Descp, PrcsId, LastUpdDate 'PrcsDate', Sts
	from atx_Settlement (nolock)
		where BusnLocation = @BusnLocation and SettleDate between convert(datetime, @FromDate, 112) and convert(datetime, @ToDate +' 23:59:59.000', 112)
		

	return 0
end
GO
