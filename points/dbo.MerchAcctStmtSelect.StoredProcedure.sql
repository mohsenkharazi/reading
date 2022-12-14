USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchAcctStmtSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:Merchant Account Statement Report

Objective	:Weekly merchant account statement

-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2007/08/16	Sam				Initial Development.
*******************************************************************************/
--exec MerchAcctStmtSelect 1,119,111,500000000000008
CREATE	procedure [dbo].[MerchAcctStmtSelect]
	@AcqNo uAcqNo,
	@PrcsId uPrcsId,
	@StmtCycId int,
	@BusnLocation uMerchNo
  
as
begin
	declare @FromPrcsId uPrcsid

	set nocount on
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	SET DATEFORMAT YMD

--	select @FromPrcsId = dbo.GetPrcsId(@FromDate)
--	select @ToPrcsId = dbo.GetPrcsId(@ToDate)

	select @FromPrcsId = max(PrcsId) + 1
	from acq_CycleDate where PrcsId < @PrcsId

	select convert(varchar(15),b.TxnDate,105) 'TxnDate', convert(varchar(10),e.PrcsDate,105) 'PostDate', isnull(b.Amt,0) 'TxnAmt',
		case 
			when isnull(d.Ids,0) <> 0 and c.Category = 1 then isnull(d.TxnMerchFee,0)
			else 0
		end 'DrTxnAmt',
		case
			when isnull(b.Ids,0) <> 0 and c.Category = 20 then isnull(b.BillingPts,b.Pts)
			else 0
		end 'CrTxnAmt',
		case
			when isnull(b.Ids,0) <> 0 and c.Category in (2,3,4,5,6,21) then isnull(b.BillingAmt,b.Amt)
			else 0
		end 'MiscTxnAmt',
		case
			when c.Category in (1,20) then isnull(c.TxnCdDescp,b.Descp)
			else isnull(b.Descp,c.TxnCdDescp)
		end 'TxnDescp',
		b.TxnCd, 
		b.Ids, 
		b.TermId, 
		cast(b.CardNo as varchar(19)) 'CardNo', 
		b.AuthNo 'AppvCdTime'
	from aac_AccountStatement a
	left outer join atx_Txn b on a.BusnLocation = b.BusnLocation and (b.PrcsId between @FromPrcsId and @PrcsId)
	left outer join (select TxnCd, Category, Descp 'TxnCdDescp', PlanId, Multiplier
						from atx_TxnCode (nolock)
						where AcqNo = @AcqNo) c on b.TxnCd = c.TxnCd
	left outer join atx_MiscTxnFee d (nolock) on b.Ids = d.Ids
	left outer join cmnv_ProcessLog e (nolock) on b.PrcsId = e.PrcsId
	where a.AcqNo = @AcqNo and a.PrcsId = @PrcsId and a.BusnLocation = @BusnLocation
	order by b.TxnDate

end
GO
