USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[EDCUnsettleTxnSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
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
2002/01/04 Jacky		   Initial development
2009/12/18 Barnett		   Add nolock
******************************************************************************************************************/

CREATE procedure [dbo].[EDCUnsettleTxnSelect]
	@TermId uTermId
  as
begin
	declare @PrcsName varchar(50),
		@Ids uTxnId,
		@SettledIds uTxnId,
		@LastBatchId uBatchId,
		@BusnLocation uMerch,
		@BusnName nvarchar(50),
		@Msg nvarchar(80)

	select @SettledIds = isnull(max(a.LogIds), 0)
	from atx_OnlineSettlement a
	join atx_OnlineLog b on b.Ids = a.LogIds and b.MsgType = 500 and b.RespCd = '00'
	where a.TermId = @TermId

	select @Ids = isnull(max(Ids), 0)
	from atx_OnlineLog a
	where TermId = @TermId and MsgType = 500 and Ids > @SettledIds

	if isnull(@SettledIds, 0) > 0 and isnull(@Ids, 0) > 0
	begin
		select	a.Ids, convert(varchar(20), a.LastUpdDate, 113) 'LastUpdDate', a.InvoiceNo, a.Msg,
			a.FleetSalesCnt, convert(money, a.FleetSalesAmt/100.00) 'FleetSalesAmt',
			a.PreSalesCnt,	convert(money, a.PreSalesAmt/100.00) 'PreSalesAmt',
			a.RedemptionCnt, convert(money, a.RedemptionAmt/100.00) 'RedemptionAmt',
			a.PreReloadCnt, convert(money, a.PreReloadAmt/100.00) 'PreReloadAmt',
			@SettledIds 'SettledIds', isnull(b.LastBatchId, 0) 'LastBatchId'
		from atx_OnlineLog a (nolock)
		join atm_TerminalInventory b (nolock) on b.TermId = a.TermId
		where a.Ids = @Ids
	end
	else
		select 0 'Ids', null 'LastUpdDate', null 'InvoiceNo', null 'Msg',
			null 'FleetSalesCnt', null 'FleetSalesAmt', null 'PreSalesCnt', null 'PreSalesAmt',
			null 'RedemptionCnt', null 'RedemptionAmt', null 'PreReloadCnt', null 'PreReloadAmt', @SettledIds 'SettledIds',
			null 'LastBatchId'
	return 0
end
GO
