USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[DailyPostedTxnExtraction]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Objective	:Extract Daily Txn into udie_txn for export 

-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2009/05/22	Barnett			Initial Development
2009/08/18	Chew Pei		Added udie_TxnDetail
2010/03/24	Barnett			Add Payment Card Prefix
2015/07/03	Humairah		Temporarily change txncout from 1M to 3M/10M before truncate table
2015/07/06	Humairah		Change txncount from 3M/10M back to  1M before truncate table
*******************************************************************************/
/*

select * from itx_txn (nolock) where prcsid = 45
select * from udi_Batch where SrcName ='HOST' and [FileName] ='CARDTXN'
exec DailyPostedTxnExtraction 1, 62
select top 10 TxnDate, * from udie_txn
select * from cmnv_processlog
sp_help udii_APplication


*/
CREATE	procedure [dbo].[DailyPostedTxnExtraction] 
	@IssNo uIssNo,
	@PrcsId uPrcsId = null
  as
begin

	declare @BatchId uBatchId,
			@RecCnt Bigint,
			@PrcsDate datetime

	if (select count(*) from udiE_Txn (nolock) ) > 1000000 --1m
	begin
			truncate table udiE_Txn
	end

	if (select count(*) from udiE_TxnDetail (nolock) ) > 1000000 --1m
	begin
			truncate table udiE_TxnDetail
	end

	--Retrieve Business Process ID
	if @PrcsId is null
	begin
		select @PrcsDate = CtrlDate, @PrcsId = CtrlNo 
		from iss_Control where IssNo = @IssNo and CtrlId = 'PrcsId'
	end
	else
	begin
			select @PrcsDate = PrcsDate
			from cmnv_ProcessLog where IssNo = @IssNo and PrcsId = @PrcsId
	end

	------------------
	begin transaction
	------------------
	 
	exec @BatchId = NextRunNo @IssNo, 'UDIBatchId'

	insert udiE_Txn 
			(IssNo,BatchId,TxnId,TxnCd,AcctNo,CardNo,
				TxnDate,
				PrcsDate,SettleTxnAmt,BillingTxnAmt,Pts,PromoPts,TxnDescp,BusnLocation,TermId,Rrn, PaymtCardPrefix)
	select @IssNo,@BatchId,TxnId,TxnCd,AcctNo,CardNo,
			convert( varchar(10), TxnDate, 112) +
			replicate( '0',2 - len(convert(varchar(2), datepart(hh, TxnDate)))) + convert(varchar(2), datepart(hh, TxnDate))+
			replicate( '0',2 - len(convert(varchar(2), datepart(mi, TxnDate)))) + convert(varchar(2), datepart(mi, TxnDate))+
			replicate( '0',2 - len(convert(varchar(2), datepart(ss, TxnDate)))) + convert(varchar(2), datepart(ss, TxnDate)),		
			PrcsDate,SettleTxnAmt,BillingTxnAmt,Pts,PromoPts,Descp,BusnLocation,TermId,Rrn, isnull(b.PaymtCardPrefix, 0)
	from itx_Txn b (nolock) where PrcsId = @PrcsId
	if @@error <> 0
	begin
		rollback transaction
		return 70272	-- Failed to insert transaction
	end

	select @RecCnt = 0
	select @RecCnt = count(*) from udiE_Txn (nolock) where BatchId = @BatchId


	-- *** [B] Added by CP 20090818 - Include Product Details ***--

	insert udie_TxnDetail
			(IssNo, BatchId, ParentSeqNo, TxnId, TxnSeq, ProdCd, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Qty)
	select @IssNo, @BatchId, b.SeqNo, a.TxnId, a.TxnSeq, a.RefKey, a.SettleTxnAmt, a.BillingTxnAmt, a.Pts, a.PromoPts, a.Qty
	from itx_TxnDetail a
	join udiE_Txn b on b.TxnId = a.TxnId and b.BatchId = @BatchId and b.IssNo = @IssNo
	
	if @@error <> 0
	begin
		rollback transaction
		return 70273	-- Failed to insert transaction detail
	end

	
	-- *** [E] 20090818 - Include Product Details ***--


	if @RecCnt > 0 and not exists (select 1 from udi_Batch where PrcsId = @PrcsId and SrcName ='HOST' and [FileName] ='CARDTXN')
	begin
		insert udi_Batch (IssNo, BatchId, SrcName, FileName, FileSeq, DestName, FileDate,
			LoadedRec, RecCnt, Direction, PrcsId, PrcsDate, Sts)
		select @IssNo, @BatchId, 'HOST', 'CARDTXN',
			(select isnull(max(FileSeq), 0)+1 from udi_Batch
				where IssNo = @IssNo and SrcName = 'HOST' and FileName = 'CARDTXN'),
			'HOST', @PrcsDate, 0, @RecCnt, 'E', @PrcsId, @PrcsDate, 'L'

		if @@error <> 0
		begin
			rollback transaction
			return 70395	-- Failed to create new batch
		end
	end
	
	
	Commit Transaction 
	return 0

end
GO
