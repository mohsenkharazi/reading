USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CheckUnpostedTransaction]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************
Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Automation send email regarding unposted transaction
-------------------------------------------------------------------------------
When		Who		CRN	Desc
-------------------------------------------------------------------------------
2019/05/08	Seng	Initial Development
******************************************************************************************************************/
-- exec CheckUnpostedTransaction @IssNo
CREATE procedure [dbo].[CheckUnpostedTransaction]
	@IssNo uIssNo
AS
BEGIN
  
	Declare @PrcsId uPrcsId, @Content nvarchar(max), @xml nvarchar(max), @xml2 nvarchar(max), @xml3 nvarchar(max),@xml4 nvarchar(max), @body nvarchar(max)  

	select @PrcsId = max(prcsid) from cmnv_ProcessLog (nolock)    
			
	if exists ( select top 1 1 from atx_SourceTxn (nolock) where PrcsId = @PrcsId and UserId = 'lmsiAuth' and Sts <> 'A' )   
	begin  
		      
		select identity (int, 1,1) 'Id', 
			a.SrcIds, 
			a.CardNo, 
			a.TxnCd,
			b.Descp'TransactionDescp', 
			convert( nvarchar(100), a.TxnDate, 21)'TxnDate',  
			cast(a.Amt as money)'Amt', 
			cast(a.Pts as money)'Pts', 
			cast(a.BillingAmt as money)'BillingAmt', 
			cast(a.BillingPts as money)'BillingPts', 
			cast(a.VATAmt as money)'VATAmt', 
			a.BusnLocation, 
			a.TermId, 
			a.InvoiceNo, 
			a.Descp, 
			a.Rrn, 
			a.Arn, 
			a.PrcsId, 
			a.WithheldUnsettleId, 
			isnull(a.Stan,'')'Stan' , 
			isnull(a.ExternalTransactionId,'')as 'ExternalTransactionId' , 
			a.Sts
		into #temp
		from atx_SourceTxn a  (nolock) 
		join atx_TxnCode b (nolock) on b.TxnCd = a.TxnCd   
		where PrcsId = @PrcsId and UserId = 'lmsiAuth' and Sts <> 'A' 
		order by TxnDate 
		

		select TxnCd, TransactionDescp, count(1) as 'Count'
		into #tempSummary 
		from #temp
		group by TxnCd, TransactionDescp

		select b.BusnName, a.BusnLocation, a.TermId, a.InvoiceNo, a.Sts, Count(1) 'Count'
		into #MerchSummary
		from #temp a 
		join aac_BusnLocation b (nolock) on b.BusnLocation =  a.BusnLocation
		group by b.BusnName, a.BusnLocation, a.TermId, a.InvoiceNo, a.Sts
		order by b.BusnName, a.BusnLocation, a.TermId, a.InvoiceNo, a.Sts

		select Sts, Case Sts 
					when 'C' then 'Invalid business location'
					when 'Z' then 'Invalid original transaction amount'
					when 'D' then 'Transaction date out of range'
					when 'G' then 'Transaction date greater than process date'
					when 'T' then 'Invalid transaction code'
					when 'X' then 'Total detail transaction does not tally with parent transaction'
					when 'P' then 'Invalid product code/ Updating parent transaction with invalid Product Code status'
					when 'U' then 'Settlement & transaction data are not balance'
					end 'StatusDescription', 
					count(1) as 'Count'
		into #StatusSummary 
		from #temp
		group by Sts,  Case Sts 
					when 'C' then 'Invalid business location'
					when 'Z' then 'Invalid original transaction amount'
					when 'D' then 'Transaction date out of range'
					when 'G' then 'Transaction date greater than process date'
					when 'T' then 'Invalid transaction code'
					when 'X' then 'Total detail transaction does not tally with parent transaction'
					when 'P' then 'Invalid product code/ Updating parent transaction with invalid Product Code status'
					when 'U' then 'Settlement & transaction data are not balance'
					end 


		SET @xml = CAST(( SELECT Id						AS 'td','',
								 SrcIds					AS 'td','',
								 CardNo					AS 'td','',
								 TxnCd					AS 'td','',
								 TransactionDescp		AS 'td','',
								 TxnDate				AS 'td','', 
								 Amt					AS 'td','', 
								 Pts					AS 'td','', 
								 BillingAmt				AS 'td','', 
								 BillingPts				AS 'td','', 
								 VATAmt					AS 'td','', 
								 BusnLocation			AS 'td','', 
								 TermId					AS 'td','', 
								 InvoiceNo				AS 'td','', 
								 Descp					AS 'td','', 
								 Rrn					AS 'td','', 
								 Arn					AS 'td','', 
								 PrcsId					AS 'td','', 
								 WithheldUnsettleId		AS 'td','', 
								 Stan					AS 'td','', 
								 ExternalTransactionId  AS 'td','', 
								 Sts					AS 'td'
					FROM #Temp 			
					FOR XML PATH('tr'), ELEMENTS ) AS NVARCHAR(MAX))

		set @xml2 = CAST(( SELECT  TxnCd				AS 'td','', 
								   TransactionDescp		AS 'td','', 
								   [Count]				AS 'td'
					FROM #tempSummary 			
					FOR XML PATH('tr'), ELEMENTS ) AS NVARCHAR(MAX))
		
		set @xml3 = CAST(( SELECT  BusnName				AS 'td','', 
								   BusnLocation			AS 'td','', 
								   TermId				AS 'td','', 
								   InvoiceNo			AS 'td','', 
								   Sts					AS 'td','', 
								   [Count]				AS 'td'
					FROM #MerchSummary 			
					FOR XML PATH('tr'), ELEMENTS ) AS NVARCHAR(MAX))
		
		set @xml4 = CAST(( SELECT  Sts					AS 'td','', 
								   StatusDescription	AS 'td','', 
								   [Count]				AS 'td'
					FROM #StatusSummary 			
					FOR XML PATH('tr'), ELEMENTS ) AS NVARCHAR(MAX))


		SET @body ='<html><body><H2 style = "color:red">Transactions Stuck in Source Transaction Table!</H2>
					<style> table, th, td { border: 1px solid black; border-collapse: collapse;}</style>
					<p> Dear Team, </p>
					<p> There are unposted transactions found in atx_SourceTxn table that need your urgent attention and action.</p>
					<p> Kindly refer below table for the list of the transaction(s).</p>
					<tr>Summary by Merchant: </tr>
					<br>
					<table BORDER=1 BORDERCOLOR="#0000FF" BORDERCOLORLIGHT="#33CCFF" BORDERCOLORDARK="#0000CC"> 
					<tr>
						<th bgcolor = #5DA1C8> BusnName </th> 
						<th bgcolor = #5DA1C8> BusnLocation </th> 
						<th bgcolor = #5DA1C8> TermId </th>
						<th bgcolor = #5DA1C8> InvoiceNo </th> 
						<th bgcolor = #5DA1C8> Sts </th>
						<th bgcolor = #5DA1C8> Count </th>
					</tr>
					'                              
					+ @xml3 
					+ '</table>' 
					+ '<br>
					<tr>Summary by Status: </tr>
					<br>
					<table BORDER=1 BORDERCOLOR="#0000FF" BORDERCOLORLIGHT="#33CCFF" BORDERCOLORDARK="#0000CC"> 
					<tr>
						<th bgcolor = #5DA1C8> Sts </th> 
						<th bgcolor = #5DA1C8> StatusDescription </th> 
						<th bgcolor = #5DA1C8> Count </th>
					</tr>
					'                              
					+ @xml4 
					+ '</table>' 
					+ '<br>
					<br>
					<tr>Summary by Transaction Code: </tr>
					<br>'
					+'<table BORDER=1 BORDERCOLOR="#0000FF" BORDERCOLORLIGHT="#33CCFF" BORDERCOLORDARK="#0000CC"> 
					<tr>
						<th bgcolor = #5DA1C8> TxnCd </th> 
						<th bgcolor = #5DA1C8> TransactionDescp </th> 
						<th bgcolor = #5DA1C8> Count </th>
					</tr>'                           
					+ @xml2 
					+ '</table>' 
					+ '<br>
					   <br>
					   <tr>All transactions: </tr>
					   <br>'
					+'
					<table BORDER=1 BORDERCOLOR="#0000FF" BORDERCOLORLIGHT="#33CCFF" BORDERCOLORDARK="#0000CC"> 
					<tr>
						<th bgcolor = #5DA1C8> Id </th> 
						<th bgcolor = #5DA1C8> SrcIds </th> 
						<th bgcolor = #5DA1C8> CardNo </th> 
						<th bgcolor = #5DA1C8> TxnCd </th> 
						<th bgcolor = #5DA1C8> TransactionDescp </th> 
						<th bgcolor = #5DA1C8> TxnDate </th> 
						<th bgcolor = #5DA1C8> Amt </th> 
						<th bgcolor = #5DA1C8> Pts </th>
						<th bgcolor = #5DA1C8> BillingAmt </th> 
						<th bgcolor = #5DA1C8> BillingPts </th> 
						<th bgcolor = #5DA1C8> VATAmt </th> 
						<th bgcolor = #5DA1C8> BusnLocation </th>
						<th bgcolor = #5DA1C8> TermId </th> 
						<th bgcolor = #5DA1C8> InvoiceNo </th> 
						<th bgcolor = #5DA1C8> Descp </th> 
						<th bgcolor = #5DA1C8> Rrn </th>
						<th bgcolor = #5DA1C8> Arn </th> 
						<th bgcolor = #5DA1C8> PrcsId </th> 
						<th bgcolor = #5DA1C8> WithheldUnsettleId </th> 
						<th bgcolor = #5DA1C8> Stan </th>
						<th bgcolor = #5DA1C8> ExternalTransactionId </th> 
						<th bgcolor = #5DA1C8> Sts </th> 
					</tr>
					'  
					+ @xml 
					+ '</table>' 
					+'
					<br>
					<br>
					</body>
					</html>'
						
		exec msdb.dbo.sp_send_dbmail 
			@profile_name = 'Kad Mesra',          
			@recipients = 'chenghoon@cardtrend.com;support@cardtrend.com',
			@subject = 'LMS Unposted Transactions Alert!!',          
			@body = @body,          
			@body_format= 'HTML'
				
		drop table #temp
		drop table #tempSummary
		drop table #MerchSummary
		drop table #StatusSummary			
				
				
				      
	end




end
GO
