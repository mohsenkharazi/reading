USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[OLTPTxnSts]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:Cash Card CCMS

Objective	:Search list of merchants
------------------------------------------------------------------------------------------
When		Who		CRN	Description
------------------------------------------------------------------------------------------
2007/10/08	Darren		   	Initial development
*****************************************************************************************/

CREATE procedure [dbo].[OLTPTxnSts]
	@Type smallint = 0
	
  as
begin	
	set nocount on
		
	if @Type = 0
	begin

		select '1' 'Type', 'Last 20 Transactions' 'Descp' 
		union all
		select '2' 'Type', 'Transaction Used More than 5 Second' 'Descp'
		union all
		select '3' 'Type', 'Transaction count in atx_OnlineLog missing' 'Descp'
		union all
		select '4' 'Type', 'List of Transaction missing in atx_OnlineLog' 'Descp'
		
	end

	-- Last 20 Transactions
	else if @Type = 1
	begin
	
		select top 20 a.Ids, b.LastUpdDate - b.CreationDate 'TxnRespTime', a.MsgType, 
			a.PrcsCd, b.RespCd, b.HostErrCd, b.Msg, a.CardNo, a.BUsnLocation, a.TermId, a.Amt, b.LastUpdDate 'TxnDate'
		from atx_OnlineLog	a
		join atx_OnlineSubLog b on b.Ids = a.Ids
		order by a.Ids desc
	
	end

	-- Transaction Used More than 5 Second
	else if @Type = 2
	begin

		select top 20 a.Ids, b.LastUpdDate - b.CreationDate 'TxnRespTime', a.MsgType, 
			a.PrcsCd, b.RespCd, b.HostErrCd, b.Msg, a.CardNo, a.BUsnLocation, a.TermId, a.Amt, b.LastUpdDate 'TxnDate'
		from atx_OnlineLog	a
		join atx_OnlineSubLog b on b.Ids = a.Ids
		where b.LastUpdDate - b.CreationDate > '1900-01-01 00:00:05'
		order by a.Ids desc

	end	

	-- Transaction in atx_OnlineLog missing
	else if @Type = 3
	begin
		
		declare @date datetime
		select @date = getdate()
		exec OLTPCheckMissingTxn @date, 'N'

	end

	-- Transaction in atx_OnlineLog missing
	else if @Type = 4
	begin
		
		declare @sdate datetime
		select @date = getdate()
		exec OLTPCheckMissingTxn @sdate, 'Y'

	end

	set nocount off

end
SET QUOTED_IDENTIFIER OFF
GO
