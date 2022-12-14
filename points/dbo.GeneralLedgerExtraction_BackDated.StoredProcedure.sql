USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GeneralLedgerExtraction_BackDated]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure will extract transaction and put into GL

------------------------------------------------------------------------------------------------------------------
When	   Who		CRN		Desc
------------------------------------------------------------------------------------------------------------------
2009/03/16 Chew Pei			Initial Development
2009/08/25 Chew Pei			Enhancement. All parameter can be set front end. 
							And extraction will be based on the parameter set.
2009/10/05 Chew Pei			Added @Rc count to put in udi_Batch..RecCnt
2013/03/26 Barnett			Excluded the Pts Conversion Txn from Settlement summary -- Tune Big Digital
2015/04/02 Humairah			GST enhancement : get backdated data + old GL format
2015/05/27 Humairah			GST enhancement : TxnCd 402 not to locate at post GST GL File
2015/05/28 Humairah			delete 0 txnamt
2015/07/01 Humairah			Add settlement transaction
******************************************************************************************************************/
/*
exec GeneralLedgerExtraction_BackDated 1, 1096
select * from udie_GLTxn where PrcsId = 2187
*/

CREATE procedure [dbo].[GeneralLedgerExtraction_BackDated] 
	@IssNo uIssNo,
	@PrcsId uPrcsId = null
  as
begin
	declare @Rc int, @err int, @BatchId uBatchId,  @TxnDate varchar(10)
	declare @PtsPerUnitPrice money,  @PrcsDate datetime, @FileSeq int
	declare @GLTxnSeqNo int, @GLTxnSummarySeqNo int, @RefNo int, @AcctNo bigint, @TxnCd int
	declare @IssAcqInd char(1)

	set nocount on
	
	if @PrcsId is null 
	begin
		select @PrcsId = CtrlNo,
				@PrcsDate = CtrlDate
		from iss_Control (nolock)
		where IssNo = @IssNo and CtrlId = 'PrcsId'

		if @@rowcount = 0 or @@error <> 0 return 1
	end
	else
	begin
		select @PrcsDate = PrcsDate
		from cmnv_ProcessLog (nolock)
		where IssNo = @IssNo and PrcsId = @PrcsId		
	end

	select @PtsPerUnitPrice = MoneyVal
	from iss_Default (nolock)
	where Deft = 'PtsPerUnitPrice' and IssNo = @IssNo

	select @FileSeq = max(FileSeq)	-- Get the last file sequence
	from udi_Batch (nolock)
	where IssNo = @IssNo and SrcName = 'HOST' and FileName = 'GLTXN'
	
	if @@error <> 0 return 2

	if exists ( select 1 from udiE_GLTxn where PrcsId = @PrcsId ) return 2	

	-- **** Create transaction temp table **** --
	create table #Txn
	(
		RecId int IDENTITY (1,1),
		AcctNo bigint,
		TxnCd int,
		TxnAmt money,
		RedeemPts money,
		LiabilityPts money,
		TxnDate varchar(8)
	)
	create index IX_Txn_TxnCd on #Txn (TxnCd)

	exec @BatchId = NextRunNo @IssNo, 'INSBatchId'

	-- Normal Transaction (Pts Issuance, Adjustment)
	insert into #Txn (AcctNo, TxnCd, TxnAmt,Txndate)
	select a.AcctNo, a.TxnCd, abs(sum(a.Pts * @PtsPerUnitPrice)) as 'TxnAmt',convert(varchar,TxnDate,112)
	from itx_Txn a (nolock)
	join itx_TxnCode b (nolock) on b.TxnCd = a.TxnCd and b.IssNo = @IssNo
	join itx_TxnCategory c (nolock) on c.Category = b.Category and c.IssNo = @IssNo
	join iss_Default d (nolock) on d.Deft = 'RdmpTxnCategory' and d.IntVal <> c.Category and d.IssNo = @IssNo
	where a.PrcsId = @PrcsId and  convert(varchar,a.TxnDate,112) <'20150401'
	group by a.AcctNo, a.TxnCd,convert(varchar,TxnDate,112)
	
	--TxnCd = 402 [2015/05/27]
	insert into #Txn (AcctNo, TxnCd, TxnAmt,Txndate)
	select a.AcctNo, a.TxnCd, abs(sum(a.Pts * @PtsPerUnitPrice)) as 'TxnAmt',convert(varchar,TxnDate,112)
	from itx_Txn a (nolock)
	join itx_TxnCode b (nolock) on b.TxnCd = a.TxnCd and b.IssNo = @IssNo and b.TxnCd in(402,403)
	where a.PrcsId = @PrcsId 
	group by a.AcctNo, a.TxnCd,convert(varchar,TxnDate,112)
	

	-- Normal Redemption Transaction
	insert into #Txn (AcctNo, TxnCd, TxnAmt,TxnDate)
	select a.AcctNo, a.TxnCd, abs(sum(a.Pts * @PtsPerUnitPrice)) as 'TxnAmt',convert(varchar,TxnDate,112)
	from itx_Txn a (nolock)
	join itx_TxnCode b (nolock) on b.TxnCd = a.TxnCd and b.IssNo = @IssNo
	join itx_TxnCategory c (nolock) on c.Category = b.Category and c.IssNo = @IssNo
	join iss_Default d (nolock) on d.Deft = 'RdmpTxnCategory' and d.IntVal = c.Category and d.IssNo = @IssNo
	where a.PrcsId = @PrcsId and a.PromoPts = 0 and  convert(varchar,a.TxnDate,112) <'20150401'
	group by a.AcctNo, a.TxnCd,convert(varchar,TxnDate,112)

	-- Redemption Promo
	insert into #Txn (AcctNo, TxnCd, TxnAmt, RedeemPts, LiabilityPts,TxnDate)
	select a.AcctNo, a.TxnCd, abs(sum(a.SettleTxnAmt * 100)) 'TxnAmt', abs(sum(Pts)) 'RedeemPts', abs((sum(a.SettleTxnAmt * 100) - sum(Pts))) 'LiabilityPts',convert(varchar,TxnDate,112)
	from itx_Txn a (nolock)
	join itx_TxnCode b (nolock) on b.TxnCd = a.TxnCd and b.IssNo = @IssNo
	join itx_TxnCategory c (nolock) on c.Category = b.Category and c.IssNo = @IssNo
	join iss_Default d (nolock) on d.Deft = 'RdmpTxnCategory' and d.IntVal = c.Category and d.IssNo = @IssNo
	where a.PrcsId = @PrcsId and a.PromoPts > 0 and  convert(varchar,a.TxnDate,112) <'20150401'
	group by a.AcctNo, a.TxnCd, convert(varchar,TxnDate,112)

--	 Merchant Settlement
	select a.BatchId, a.TxnCd, convert(varchar,a.SettleDate,112)'SettleDate', a.AcctNo, b.SlipSeq,
			b.RcCd, b.GLAcctNo, b.Descp, b.AcctName, b.GLTxnDescp, b.TxnType, 
			CASE 
				WHEN b.TxnType ='40' and isnull(b.SrvcInd, 'N') = 'N' THEN abs(a.BillingAmt)
				WHEN b.TxnType ='50' and isnull(b.SrvcInd, 'N') = 'N' then abs(a.BillingAmt)
	--			WHEN b.TxnType ='C' and isnull(b.SrvcInd, 'Y') = 'Y' then a.SrvcFee
			END as 'TxnAmt',
			b.ExtInd
	into #MerchTemp
	from atx_Settlement a (nolock)
	join acq_GLCode  b (nolock) on  b.AcqNo = a.AcqNo and b.TxnCd = a.TxnCd
	where a.PrcsId = @PrcsId and a.BillingAmt <> 0 and busnlocation <> '000000090040452' -- Tune Big Digital
			and  convert(varchar,a.SettleDate,112) < '20150401'
	order by a.SettleDate

	-----------------
	BEGIN TRANSACTION
	-----------------

	-- Input to GLTxn for ALL Transaction where it is not a promo txn
	insert udiE_GLTxn 
			(IssNo, BatchId, RcCd, TxnDate, SlipSeq, AcctTxnCd, TxnType, TxnAmt, RefNo,
			Descp1, Descp2, PrcsId, AcctNo, TxnCd, IssAcqInd, PromoInd, ExtInd )
	select	@IssNo, @BatchId, b.RcCd, a.TxnDate,
			b.SlipSeq, b.AcctTxnCd, b.TxnType, a.TxnAmt, a.RecId,
			b.AcctName, b.GLTxnDescp, @PrcsId, a.AcctNo, b.TxnCd, 'I', PromoInd, ExtInd
		from #Txn a
		join iss_GLCode b (nolock) on b.TxnCd = a.TxnCd
		where not exists (select 1 from iss_GLCode c (nolock)where c.TxnCd = a.TxnCd and PromoInd = 'Y')
		order by a.RecId, a.AcctNo

	if @@error <> 0
	begin
		rollback transaction
		return 2
	end
	
	-- For Promo Ind 'Y' Txn

	insert udiE_GLTxn 
			(IssNo, BatchId, RcCd, TxnDate, SlipSeq, AcctTxnCd, TxnType, TxnAmt, RefNo,
			Descp1, Descp2, PrcsId, AcctNo, TxnCd, IssAcqInd, PromoInd, ExtInd )
	select	@IssNo, @BatchId, b.RcCd,a.TxnDate,
			b.SlipSeq, b.AcctTxnCd, b.TxnType, 
					case when TxnType = 50 and PromoInd = 'N' then a.TxnAmt
								when TxnType = 40 and PromoInd = 'Y' then a.RedeemPts
								when TxnType = 40 and PromoInd = 'N' then a.LiabilityPts 
					end, a.RecId,
			b.AcctName, b.GLTxnDescp, @PrcsId, a.AcctNo, b.TxnCd, 'I', PromoInd, ExtInd
		from #Txn a
		join iss_GLCode b (nolock) on b.TxnCd = a.TxnCd
		where exists (select 1 from iss_GLCode c (nolock) where c.TxnCd = a.TxnCd and PromoInd = 'Y')
		order by a.AcctNo

	if @@error <> 0
	begin
		rollback transaction
		return 2
	end

	insert udiE_GLTxn (IssNo, BatchId, RcCd, TxnDate, SlipSeq, AcctTxnCd, TxnType, TxnAmt, RefNo,
			Descp1, Descp2, PrcsId, AcctNo, TxnCd, IssAcqInd, ExtInd )
	select @IssNo, @BatchId, RcCd, SettleDate, --left(convert(varchar, @PrcsDate, 103), 2) + substring(convert(varchar, @PrcsDate, 103), 4,2) + right(convert(varchar, @PrcsDate, 103), 2),
			SlipSeq, GLAcctNo, TxnType, TxnAmt, null,
			AcctName, GLTxnDescp, @PrcsId, AcctNo ,TxnCd, 'A', ExtInd
		from #MerchTemp
		order by AcctNo

	if @@error <> 0
	begin
		rollback transaction
		return 2
	end

-- delete 0 txnamt
	delete from udiE_GLTxn where txnamt = 0 and prcsid = @PrcsId

	insert udie_GLTxnSummary (IssNo, BatchId, RcCd, TxnDate, SlipSeq, AcctTxnCd, TxnType, TxnAmt,
			Descp1, Descp2, PrcsId,  TxnCd, IssAcqInd)
	select  a.IssNo, a.BatchId, a.RcCd, a.TxnDate, a.SlipSeq, a.AcctTxnCd, a.TxnType, Sum(a.TxnAmt) as 'TxnAmt',
		a.Descp1, a.Descp2, a.PrcsId, a.TxnCd, a.IssAcqInd
	from udiE_GLTxn a
	join iss_Reflib b (nolock) on b.RefType = 'GLExtractionInd' and b.RefCd = a.ExtInd and b.RefNo = 0 and b.IssNo = @IssNo -- Summary
	where PrcsId = @PrcsId
	group by a.IssAcqInd, a.IssNo, a.BatchId, a.RcCd, a.TxnDate, a.SlipSeq, a.AcctTxnCd, a.TxnType, a.Descp1, a.Descp2, a.PrcsId, a.TxnCd
	order by a.TxnCd, a.IssAcqInd desc, a.TxnType desc
	if @@error <> 0
	begin
		rollback transaction
		return 2
	end

	insert udie_GLTxnSummary (IssNo, BatchId, RcCd, TxnDate, SlipSeq, AcctTxnCd, TxnType, TxnAmt, 
			Descp1, Descp2, PrcsId,  TxnCd, IssAcqInd)
	select  a.IssNo, a.BatchId, a.RcCd, a.TxnDate, a.SlipSeq, a.AcctTxnCd, a.TxnType, a.TxnAmt,
		a.Descp1, a.Descp2, a.PrcsId, a.TxnCd, a.IssAcqInd
	from udiE_GLTxn a
	join iss_Reflib b (nolock) on b.RefType = 'GLExtractionInd' and b.RefCd = a.ExtInd and b.RefNo = 1 and b.IssNo = @IssNo -- Line
	where PrcsId = @PrcsId
	order by a.TxnCd, a.IssAcqInd desc --, a.TxnType desc
	if @@error <> 0
	begin
		rollback transaction
		return 2
	end

	select @Rc = count(*) from udie_GLTxnSummary where BatchId = @BatchId and PrcsId = @PrcsId

	select min(SeqNo)'SeqNo' into #GLTxnSummarySeq from udie_GLTxnSummary where BatchId = @BatchId group by TxnCd, IssAcqInd,TxnDate
	create	unique index IX_GLTxnSummSeqNo on #GLTxnSummarySeq (SeqNo)

	select @GLTxnSummarySeqNo = min(SeqNO) from #GLTxnSummarySeq

	select @RefNo = 1
	while (@GLTxnSummarySeqNo is not null) 
	begin
		select @TxnCd = TxnCd, @IssAcqInd = IssAcqInd ,@TxnDate = Txndate from udie_GLTxnSummary where  BatchId = @BatchId and SeqNo = @GLTxnSummarySeqNo
		update udie_GLTxnSummary set RefNo = @RefNo where BatchId = @BatchId and TxnCd = @TxnCd and IssAcqInd = @IssAcqInd and Txndate = @TxnDate
		select @RefNo = @RefNo + 1
		select @GLTxnSummarySeqNo = min(SeqNo) from #GLTxnSummarySeq where SeqNo > @GLTxnSummarySeqNo
	end
	
	insert udi_Batch (IssNo, BatchId, SrcName, FileName, FileSeq, DestName, FileDate,
			RecCnt, Direction, Sts, PrcsId, PrcsDate)
	select @IssNo, @BatchId, 'HOST', 'GLTXN', isnull(@FileSeq,0)+1, 'SAPGL', getdate(),
		@Rc, 'E', 'L', @PrcsId, @PrcsDate

	if @@error <> 0
	begin
		rollback transaction
		return 70265 -- Failed to update Batch
	end


	------------------
	COMMIT TRANSACTION
	------------------

	drop table #Txn
	drop table #MerchTemp

	return 0
end
GO
