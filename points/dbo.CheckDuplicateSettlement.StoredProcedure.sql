USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CheckDuplicateSettlement]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************
Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Automation send email regarding double posting  
-------------------------------------------------------------------------------
When		Who		CRN	Desc
-------------------------------------------------------------------------------
2019/05/08	Seng	Initial Development
******************************************************************************************************************/
-- exec CheckDuplicateSettlement
CREATE procedure [dbo].[CheckDuplicateSettlement]
	@IssNo uIssNo
AS
BEGIN

	--------------------------------------
	--LMS monitoring (maybe can avoid it)
	--------------------------------------
	declare @PrcsId uPrcsId , @body nvarchar(max), @xml nvarchar(max)
	select @PrcsId = max(PrcsId) from cmnv_processlog (nolock) 
	
	select top 100 count(a.BusnLocation) 'count', a.Busnlocation, a.Termid, a.Invoiceno, a.TxnInd, a.PrcsId
	into #DuplicateSettlement
	from atx_settlement a (nolock)
	where a.Prcsid = @PrcsId
	group by a.Busnlocation, a.Termid, a.Invoiceno , a.TxnInd, a.PrcsId
	having count(a.BUsnLocation) > 1
	
	create index Idx_DuplicateSettlement on #DuplicateSettlement (BusnLocation, TermId, InvoiceNo)
	
	select top 200 a.Ids, a.BusnLocation, a.TermId, a.InvoiceNo, a.TxnInd
	into #DuplicateSettlementSrcIds
	from atx_settlement a (nolock)
	join #DuplicateSettlement b on b.BusnLocation = a.BusnLocation and b.TermId = a.TermId and b.InvoiceNo = a.InvoiceNo and a.TxnInd = b.TxnInd
	where a.Prcsid = @PrcsId
	
	create index Idx_Idss on #DuplicateSettlementSrcIds (Ids)
	
	create table #DuplicateTransaction(
			[Count] int,
			MinIds bigint,
			MaxIds bigint,
			BusnLocation varchar(15),
			TermId varchar(8),
			InvoiceNo int,
			CardNo bigint,
			Amt Money,
			Pts Money,
			TxnDate varchar(16)
		)
	
	if exists(select top 1 1
			  from atx_Txn a (nolock) 
			  join #DuplicateSettlementSrcIds b (nolock) on b.Ids = a.SrcIds
			  where a.PrcsId = @PrcsId
			  group by a.Busnlocation, a.Termid, a.Invoiceno, a.Cardno, a.Amt, a.Pts, convert(varchar(16), TxnDate, 20)
			  having count(a.BUsnLocation) > 1)
	begin
	
	
		--removed stan due to invoiceno 0, stan value blank on other api, filter to minute for avoid milisecond to second, vatno no is blank and rrn might contain 0 for other api,
		--show only top 100 to avoid performance issue 
		insert into #DuplicateTransaction([Count], MinIds, MaxIds, Busnlocation, Termid, Invoiceno, Cardno, Amt, Pts, TxnDate)
		select top 100 count(a.BusnLocation) 'Count', Min(a.Ids) 'MinIds', Max(a.Ids) 'MaxIds', a.Busnlocation, a.Termid, a.Invoiceno, a.Cardno, a.Amt, a.Pts, convert(varchar(16), TxnDate, 20) 
		from atx_Txn a (nolock) 
		join #DuplicateSettlementSrcIds b (nolock) on b.Ids = a.SrcIds
		where a.PrcsId = @PrcsId
		group by a.Busnlocation, a.Termid, a.Invoiceno, a.Cardno, a.Amt, a.Pts, convert(varchar(16), TxnDate, 20)
		having count(a.BUsnLocation) > 1
		
	
	end
	
	if exists(select top 1 1 from #DuplicateTransaction)
	begin
	
		SET @xml = CAST(( SELECT [Count]					AS 'td','',
								 MinIds						AS 'td','',
								 MaxIds						AS 'td','',
								 BusnLocation               AS 'td','',
								 TermId						AS 'td','',
								 InvoiceNo					AS 'td','', 
								 CardNo						AS 'td','', 
								 Amt						AS 'td','', 
								 Pts						AS 'td','', 
								 TxnDate					AS 'td'
					FROM #DuplicateTransaction 			
					FOR XML PATH('tr'), ELEMENTS ) AS NVARCHAR(MAX))
	
	
		set @body = '<html><body><H2 style = "color:red">Duplicate Transactions in Merchant Posted Transaction Table!</H2>
						 <style> table, th, td { border: 1px solid black; border-collapse: collapse;}</style>
						 <p> Dear Team, </p>
						 <p> There are duplicate transactions found in atx_Txn table that need your urgent attention and action.</p>
						 <p> Kindly refer below table for the list of the transaction(s).</p>
						 <tr>Summary by Settlement: </tr>
					<br>
					<table BORDER=1 BORDERCOLOR="#0000FF" BORDERCOLORLIGHT="#33CCFF" BORDERCOLORDARK="#0000CC"> 
					<tr>
						<th bgcolor = #5DA1C8> Count		</th>
						<th bgcolor = #5DA1C8> MinIds		</th>
						<th bgcolor = #5DA1C8> MaxIds		</th>
						<th bgcolor = #5DA1C8> BusnLocation </th>
						<th bgcolor = #5DA1C8> TermId		</th>
						<th bgcolor = #5DA1C8> InvoiceNo	</th>
						<th bgcolor = #5DA1C8> CardNo		</th>
						<th bgcolor = #5DA1C8> Amt			</th>
						<th bgcolor = #5DA1C8> Pts			</th>
						<th bgcolor = #5DA1C8> TxnDate		</th>
					</tr>
					'                              
					+ @xml 
					+ '</table>
					</body>
					</html>'
	
	
			exec msdb.dbo.sp_send_dbmail
				@profile_name = 'Kad Mesra',
				@recipients = 'chenghoon@cardtrend.com;support@cardtrend.com',
				@subject = 'LMS - Double Posting Data',
				@body = @body,
				@body_format= 'HTML'
	
	end
	
	--select * from #DuplicateSettlementSrcIds
	--select * from #DuplicateSettlement
	--select * from #DuplicateTransaction
	
	drop table #DuplicateSettlementSrcIds
	drop table #DuplicateSettlement
	drop table #DuplicateTransaction


END
GO
