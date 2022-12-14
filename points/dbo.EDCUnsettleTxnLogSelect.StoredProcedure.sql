USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[EDCUnsettleTxnLogSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- OLTP Module

Objective	: Select Last Unsuccessfull Settlement

SP Level	: Primary
------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2003/11/04 Jacky		   Initial development
2009/12/18 Barnett		   Add nolock
******************************************************************************************************************/

CREATE procedure [dbo].[EDCUnsettleTxnLogSelect]
	@TermId uTermId
  as
begin
	declare @PrcsName varchar(50),
		@Ids uTxnId,
		@SettledIds uTxnId,
		@Msg nvarchar(80)

	select @SettledIds = isnull(max(a.LogIds), 0)
	from atx_OnlineSettlement a
	join atx_OnlineLog b on b.Ids = a.LogIds and b.MsgType = 500 and b.RespCd = '00'
	where a.TermId = @TermId

	select	MsgType, PrcsCd, CardNo, convert(money, isnull(Amt,0)/100.00) 'TxnAmt', LocalTime,
			LocalDate, SysTraceAudit, RRN, RespCd, --FleetSalesCnt 'PostpaidCnt',
			--convert(money,FleetSalesAmt/100.00) 'PostPaidAmt', PreSalesCnt,
			--convert(money,PreSalesAmt/100.00) 'PrePaidAmt',
/*			ProdCd1, convert(money, isnull(Qty1,0)/100), convert(money, isnull(AmtPts1,0)/100) 'Amt1',
			ProdCd2, convert(money, isnull(Qty2,0)/100), convert(money, isnull(AmtPts2,0)/100) 'Amt2',
			ProdCd3, convert(money, isnull(Qty3,0)/100), convert(money, isnull(AmtPts3,0)/100) 'Amt3',
			ProdCd4, convert(money, isnull(Qty4,0)/100), convert(money, isnull(AmtPts4,0)/100) 'Amt4',
			ProdCd5, convert(money, isnull(Qty5,0)/100), convert(money, isnull(AmtPts5,0)/100) 'Amt5'*/
			ProdCd1, convert(money,Qty1/100.00) 'Qty1', convert(money, AmtPts1/100.00) 'Amt1',
			ProdCd2, convert(money,Qty2/100.00) 'Qty2', convert(money, AmtPts2/100.00) 'Amt2',
			ProdCd3, convert(money,Qty3/100.00) 'Qty3', convert(money, AmtPts3/100.00) 'Amt3',
			ProdCd4, convert(money,Qty4/100.00) 'Qty4', convert(money, AmtPts4/100.00) 'Amt4',
			ProdCd5, convert(money,Qty5/100.00) 'Qty5', convert(money, AmtPts5/100.00) 'Amt5'
	from atx_OnlineLog a (nolock)
	where TermId = @TermId and Ids > @SettledIds

	return 0
end
GO
