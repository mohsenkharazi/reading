USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GeneralLedgerExtraction_GST]    Script Date: 9/6/2021 10:33:55 AM ******/
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
2015/02/25 Humairah			Add Busn Location in UdiE_GLTxn and UdiE_GLTxnSummary for GST 
2015/03/23 Humairah			GST : Self Billing 
2015/05/11 Humairah			GST : Fix VAT Amount calculation
2015/05/25 Humairah			Fix Amount of Pts Issuance (Calculation) and remove -ve sign
2015/05/27 Humairah			GST enhancement : TxnCd 402 not to locate at post GST GL File
2015/06/30 Humairah			Include transaction for Replacement Fee,Pts Cancellation & Pts Expiry
******************************************************************************************************************/
/*
truncate table udiE_GLTxn_GST
truncate table udie_GLTxnSummary_GST

declare @RC int
exec @RC = GeneralLedgerExtraction_GST 1, 2480
select @RC

*/

CREATE  procedure [dbo].[GeneralLedgerExtraction_GST]
	@IssNo uIssNo,
	@PrcsId uPrcsId = null
  as
begin
	declare @Rc int, @err int, @BatchId uBatchId,  @TxnDate varchar(10),@PtsIssueTxnCategory int
	declare @PtsPerUnitPrice money,  @PrcsDate datetime, @FileSeq int,@RdmpTxnCategory int
	declare @GLTxnSeqNo int, @GLTxnSummarySeqNo int, @AcctNo bigint, @TxnCd int,@AdjustTxnCategory int
	declare @IssAcqInd char(1),@BusnLocation uMerchNo, @RefNoCheck int, @a varchar(300),@SlipSeq varchar(3)
	declare @Ind tinyint, @MaxNo int, @RefNo int, @SeqNo tinyint, @PrvSeqNo tinyint, @TCd uTxnCd, @PrvTCd uTxnCd

	set nocount on

	select @Ind = 0, @MaxNo = 0, @RefNo = 1
	
	if @PrcsId is null 
	begin
		select @PrcsId = CtrlNo,
				@PrcsDate = CtrlDate
		from iss_Control (nolock)
		where IssNo = @IssNo and CtrlId = 'PrcsId'

		if @@rowcount = 0 or @@ERROR <> 0 return 1
	end
	else
	begin
		select @PrcsDate = PrcsDate
		from cmnv_ProcessLog (nolock)
		where IssNo = @IssNo and PrcsId = @PrcsId		
	end

	select @PtsIssueTxnCategory = IntVal
	from iss_Default (nolock)
	where Deft = 'PtsIssueTxnCategory' and IssNo = @IssNo

	select @AdjustTxnCategory = IntVal
	from iss_Default (nolock)
	where Deft = 'AdjustTxnCategory' and IssNo = @IssNo

	select 	@RdmpTxnCategory = IntVal
	from iss_Default (nolock)
	where Deft = 'RdmpTxnCategory' and IssNo = @IssNo

	select @PtsPerUnitPrice = MoneyVal
	from iss_Default (nolock)
	where Deft = 'PtsPerUnitPrice' and IssNo = @IssNo

	-- Get the last file sequence
	select @FileSeq = max(FileSeq)	
	from udi_Batch (nolock)
	where IssNo = @IssNo and SrcName = 'HOST' and FileName = 'GLTXN'
	
	if @@ERROR <> 0 return 2

	--IF exists (select 1 from udi_Batch_1000 where SrcName = 'Host' and FileName = 'GLTxn' and PrcsId = @PrcsId) 
	IF exists (select 1 from udi_Batch (nolock) where SrcName = 'Host' and FileName = 'GLTxn' and PrcsId = @PrcsId) 
	return 0

	truncate table udiE_GLTxn_GST

--	if exists ( select 1 from udiE_GLTxn_GST where PrcsId = @PrcsId ) return 2	

	-- **** Create transaction temp table **** --
	create table #Txn
	(
		RecId int IDENTITY (1,1),
		AcctNo bigint,
		BusnLocation varchar(15),
		TxnCd int,
		TxnAmt money,
		RedeemPts money,
		LiabilityPts money,
		ProdCd varchar(15),
		VATCd varchar(15),
		VATAmt money
	)
	create index #IX_Txn_TxnCd on #Txn (TxnCd)
	create index #IX_Txn_VATCd on #Txn (VATCd)

	create table #udie_GLTxnSummary_GST_temp
	(
		RecId int IDENTITY (1,1),
		IssNo tinyint null,
		SeqNo int null,
		RefNo int null,
		BatchId bigint null,
		RcCd varchar(20) null,
		TxnDate datetime null,
		SlipSeq varchar(5) null,
		AcctTxnCd varchar(20) null,
		BusnLocation varchar(15) null,
		TxnType varchar(10) null,
		TxnAmt money null,
		Descp1 varchar(100) null,
		Descp2 varchar(200) null,
		PrcsId int,
		TxnCd int null,
		IssAcqInd varchar(5) null,
		DocFlag tinyint null,
		ProdCd varchar(15) null, 
		ProdDescp varchar(100) null, 
		VATCd char(5), 
		VATAmt money
	)

	CREATE INDEX #udie_GLTxnSummary_GST_temp_MID on #udie_GLTxnSummary_GST_temp (BusnLocation)
	CREATE INDEX #udie_GLTxnSummary_GST_temp_RecId on #udie_GLTxnSummary_GST_temp (RecId)
	CREATE INDEX #udie_GLTxnSummary_GST_temp_SeqNo on #udie_GLTxnSummary_GST_temp (SeqNo)
	CREATE INDEX #udie_GLTxnSummary_GST_temp_AcctTxnCd on #udie_GLTxnSummary_GST_temp (AcctTxnCd)
	CREATE INDEX #udie_GLTxnSummary_GST_temp_SlipSeq on #udie_GLTxnSummary_GST_temp (SlipSeq)

	create table #udie_GLTxnSummary_GST_final
	(
		RecId int IDENTITY (1,1),
		IssNo tinyint null,
		SeqNo int null,
		RefNo int null,
		BatchId bigint null,
		RcCd varchar(20) null,
		TxnDate datetime null,
		SlipSeq varchar(5) null,
		AcctTxnCd varchar(20) null,
		BusnLocation varchar(15) null,
		TxnType varchar(10) null,
		TxnAmt money null,
		Descp1 varchar(100) null,
		Descp2 varchar(200) null,
		PrcsId int,
		TxnCd int null,
		IssAcqInd varchar(5) null,
		DocFlag tinyint null,
		ProdCd varchar(15) null, 
		ProdDescp varchar(100) null, 
		VATCd char(5), 
		VATAmt money
	)
	CREATE INDEX #udie_GLTxnSummary_GST_final_RecId on #udie_GLTxnSummary_GST_final(RecId)
	CREATE INDEX #udie_GLTxnSummary_GST_final_RefNo on #udie_GLTxnSummary_GST_final(RefNo)

	-- Normal Transaction (Pts Issuance) 
	insert into #Txn (AcctNo, TxnCd, TxnAmt)
	select a.AcctNo, a.TxnCd, sum(a.Pts)*@PtsPerUnitPrice as 'TxnAmt'
	from itx_Txn a (nolock)
	join itx_TxnCode b (nolock) on b.TxnCd = a.TxnCd and b.Category not in (@AdjustTxnCategory,@RdmpTxnCategory)and b.IssNo = @IssNo 
	where a.PrcsId = @PrcsId and  convert(varchar,a.TxnDate,112) >='20150401' 
	group by a.AcctNo, a.TxnCd

	IF @@ERROR <> 0 return 111

	-- Adjustment Transaction
	insert into #Txn (AcctNo, BusnLocation,TxnCd, TxnAmt)
	select a.AcctNo, a.BusnLocation, a.TxnCd, sum(a.Pts)*@PtsPerUnitPrice as 'TxnAmt'
	from itx_Txn a (nolock)
	join itx_TxnCode b (nolock) on b.TxnCd = a.TxnCd and b.IssNo = @IssNo and b.TxnCd not in(402,403) --[2015/05/27 ]
	join itx_TxnCategory c (nolock) on c.Category = b.Category and c.IssNo = @IssNo and C.category = @AdjustTxnCategory
	where a.PrcsId = @PrcsId and a.PromoPts = 0 and convert(varchar,a.TxnDate,112) >='20150401'
	group by a.AcctNo, a.BusnLocation, a.TxnCd


	IF @@ERROR <> 0 return 112

	-- Normal Redemption Transaction
	insert into #Txn (AcctNo, BusnLocation,TxnCd, TxnAmt,ProdCd,VATCd,VATAmt)
	select a.AcctNo, a.BusnLocation, a.TxnCd, abs(sum(a1.SettleTxnAmt))as 'TxnAmt',a1.RefKey,a1.VATCd,abs(sum(a1.VATAmt))as 'VATAmt'
	from itx_Txn a (nolock)
	left join itx_TxnDetail a1(nolock) on a1.TxnId  = a.TxnId
	join itx_TxnCode b (nolock) on b.TxnCd = a.TxnCd and b.TxnCd not in (508)and b.IssNo = @IssNo
	join itx_TxnCategory c (nolock) on c.Category = b.Category and c.IssNo = @IssNo
	join iss_Default d (nolock) on d.Deft = 'RdmpTxnCategory' and d.IntVal = c.Category and d.IssNo = @IssNo
	where a.PrcsId = @PrcsId and a.PromoPts = 0 and convert(varchar,a.TxnDate,112) >='20150401'
	group by a.AcctNo, a.BusnLocation, a.TxnCd,a1.RefKey,a1.VATCd,a1.VATAmt


	IF @@ERROR <> 0 return 113

	-- Normal Redemption Transaction(no txn detail)
	insert into #Txn (AcctNo, BusnLocation,TxnCd, TxnAmt)
	select a.AcctNo, a.BusnLocation, a.TxnCd, abs(sum(a.SettleTxnAmt))as 'TxnAmt'
	from itx_Txn a (nolock)
	join itx_TxnCode b (nolock) on b.TxnCd = a.TxnCd and b.TxnCd in (508) and b.IssNo = @IssNo
	join itx_TxnCategory c (nolock) on c.Category = b.Category and c.IssNo = @IssNo
	join iss_Default d (nolock) on d.Deft = 'RdmpTxnCategory' and d.IntVal = c.Category and d.IssNo = @IssNo
	where a.PrcsId = @PrcsId and a.PromoPts = 0 and convert(varchar,a.TxnDate,112) >='20150401'
	group by a.AcctNo, a.BusnLocation, a.TxnCd

	IF @@ERROR <> 0 return 1131

	-- Redemption Promo
	insert into #Txn (AcctNo,BusnLocation, TxnCd, TxnAmt, RedeemPts, LiabilityPts,ProdCd,VATCd,VATAmt)
	select a.AcctNo, a.BusnLocation, a.TxnCd, abs(sum(a1.SettleTxnAmt)) 'TxnAmt', abs(sum(a.Pts)) 'RedeemPts', abs((sum(a.SettleTxnAmt * 100) - sum(a.Pts))) 'LiabilityPts',a1.RefKey,a1.VATCd,a1.VATAmt
	from itx_Txn a (nolock)
	left join itx_TxnDetail a1(nolock) on a1.TxnId  = a.TxnId
	join itx_TxnCode b (nolock) on b.TxnCd = a.TxnCd and b.IssNo = @IssNo
	join itx_TxnCategory c (nolock) on c.Category = b.Category and c.IssNo = @IssNo
	join iss_Default d (nolock) on d.Deft = 'RdmpTxnCategory' and d.IntVal = c.Category and d.IssNo = @IssNo
	where a.PrcsId = @PrcsId and a.PromoPts > 0  and convert(varchar,a.TxnDate,112) >='20150401'
	group by a.AcctNo, a.BusnLocation, a.TxnCd,a1.RefKey,a1.VATCd,a1.VATAmt

	IF @@ERROR <> 0 return 114

	exec @BatchId = dbo.NextRunNo @IssNo, 'INSBatchId'



	-- Input to GLTxn for ALL Transaction where it is not a promo txn

	insert udiE_GLTxn_GST
			(IssNo, BatchId, RcCd, 
			 TxnDate, 
			 SlipSeq, AcctTxnCd, TxnType, TxnAmt, RefNo,
			 Descp1, Descp2, PrcsId, AcctNo, TxnCd, IssAcqInd, PromoInd, ExtInd , BusnLocation, ProdCd,
			 VATCd,VATAmt)
	select	@IssNo, @BatchId, b.RcCd,  
			left(convert(varchar(10), @PrcsDate, 103), 2) + substring(convert(varchar(10), @PrcsDate, 103), 4,2) + right(convert(varchar(10), @PrcsDate, 103), 2),
			b.SlipSeq, b.AcctTxnCd, b.TxnType, a.TxnAmt, a.RecId, b.AcctName as 'Descp1', 
			 CASE  
					WHEN (BusnLocation is not null ) THEN substring(a.BusnLocation + ' ' + rtrim(ltrim(b.GLTxnDescp)), 1, 80)
					ELSE rtrim(ltrim(b.GLTxnDescp))
					END as 'Descp2', 
			@PrcsId, a.AcctNo, b.TxnCd, 'I', PromoInd, ExtInd,a.BusnLocation, a.ProdCd,
			c.RefId,a.VATAmt
		from #Txn a
		join iss_GLCode_GST b (nolock) on b.TxnCd = a.TxnCd
		left join iss_reflib c (nolock) on c.RefCd = a.VATCd and c.Reftype = 'VATCd'
		where not exists (select 1 from iss_GLCode_GST c (nolock)where c.TxnCd = a.TxnCd and PromoInd = 'Y')
		order by a.RecId, a.AcctNo

	if @@ERROR <> 0 return 999

	-- For Promo Ind 'Y' Txn
	insert udiE_GLTxn_GST
			(IssNo, BatchId, RcCd, TxnDate, SlipSeq, AcctTxnCd, TxnType, TxnAmt, RefNo,
			 Descp1, Descp2,PrcsId, AcctNo, TxnCd, IssAcqInd, PromoInd, ExtInd, BusnLocation,ProdCd,
			 VATCd,VATAmt)
	select	@IssNo, @BatchId, b.RcCd,  left(convert(varchar(10), @PrcsDate, 103), 2) + substring(convert(varchar(10), @PrcsDate, 103), 4,2) + right(convert(varchar(10), @PrcsDate, 103), 2),
			b.SlipSeq, b.AcctTxnCd, b.TxnType, 
					case when TxnType = 50 and PromoInd = 'N' then a.TxnAmt
								when TxnType = 40 and PromoInd = 'Y' then a.RedeemPts
								when TxnType = 40 and PromoInd = 'N' then a.LiabilityPts 
					end, a.RecId, b.AcctName as 'Descp1', 
			 CASE  
					WHEN (BusnLocation is not null ) THEN substring(a.BusnLocation + ' ' + rtrim(ltrim(b.GLTxnDescp)), 1, 80)
					ELSE rtrim(ltrim(b.GLTxnDescp))
					END as 'Descp2',  
			@PrcsId, a.AcctNo, b.TxnCd, 'I', PromoInd, ExtInd,a.BusnLocation,a.ProdCd,
			c.RefId,a.VATAmt
		from #Txn a
		join iss_GLCode_GST b (nolock) on b.TxnCd = a.TxnCd
		join iss_reflib c (nolock) on c.RefCd = a.VATCd and c.Reftype = 'VATCd'
		where exists (select 1 from iss_GLCode_GST c (nolock) where c.TxnCd = a.TxnCd and PromoInd = 'Y')
		order by a.AcctNo

	if @@ERROR <> 0 return 999

	--settlement entry (Bank)
	insert #udie_GLTxnSummary_GST_temp (IssNo, BatchId, RcCd, TxnDate, SlipSeq, AcctTxnCd, BusnLocation, TxnType, TxnAmt,
			Descp1, Descp2, PrcsId,  TxnCd, IssAcqInd, SeqNo)
	select a.IssNo, a.BatchId, a.RcCd, a.TxnDate, b.SlipSeq, b.GLAcctNo 'AcctTxnCd', a.BusnLocation, a.TxnType, Sum(a.TxnAmt),
			b.AcctName, isnull(cast(a.BusnLocation as varchar) + ' ','') + cast(isnull(b.GLTxnDescp,'') as varchar), a.PrcsId, a.TxnCd, 'A', 99
	from udiE_GLTxn_GST a (nolock)
	join acq_GLCode_GST b (nolock) on b.TxnCd = a.TxnCd and b.TxnType = a.TxnType
	where a.PrcsId = @PrcsId and a.IssNo = @IssNo
	group by a.IssNo, a.BatchId, a.RcCd, a.TxnDate, b.SlipSeq, a.BusnLocation, a.TxnType, a.Descp1,a.Descp2, a.PrcsId, a.TxnCd, 
			b.GLAcctNo,b.AcctName,b.GLTxnDescp

	if @@ERROR <> 0 return 900

	--settlement entry (MID)
	insert #udie_GLTxnSummary_GST_temp (IssNo, BatchId, RcCd, TxnDate, SlipSeq, AcctTxnCd, BusnLocation, TxnType, TxnAmt,
			Descp1, Descp2, PrcsId,  TxnCd, IssAcqInd, SeqNo)
	select a.IssNo,a.BatchId, a.RcCd, a.TxnDate, b.SlipSeq, c.SAPNo , a.BusnLocation , 25 , sum(a.TxnAmt),
			b.AcctName,cast(a.BusnLocation as varchar) + ' ' + cast(isnull(b.GLTxnDescp,'') as varchar), a.PrcsId, a.TxnCd, 'A', 99
	from udiE_GLTxn_GST a (nolock)
	join acq_GLCode_GST b (nolock) on b.TxnCd = a.TxnCd and b.TxnType = a.TxnType
	join aac_busnLocation c(nolock) on c.BusnLocation = a.busnLocation
	where a.PrcsId = @PrcsId and a.IssNo = @IssNo
	group by a.IssNo,a.BatchId, a.RcCd, a.TxnDate, b.SlipSeq, a.BusnLocation, a.TxnType, a.Descp1,a.Descp2, a.PrcsId, a.TxnCd, 
			c.SAPNo, b.AcctName, b.GLTxnDescp

	if @@ERROR <> 0 return 901

	--all kind of txn (Summary)
	insert #udie_GLTxnSummary_GST_temp (IssNo, BatchId, RcCd, TxnDate, SlipSeq, AcctTxnCd, BusnLocation, TxnType, TxnAmt,
			Descp1, Descp2, PrcsId,  TxnCd, IssAcqInd, ProdCd, ProdDescp, VATCd, VATAmt, SeqNo)
	select  a.IssNo, a.BatchId, a.RcCd, a.TxnDate, a.SlipSeq, a.AcctTxnCd,a.BusnLocation, a.TxnType, sum(a.TxnAmt),
			a.Descp1,a.Descp2, a.PrcsId, a.TxnCd, a.IssAcqInd, a.ProdCd, c.Descp, a.VATCd, sum(isnull(a.VATAmt,0)), 0
	from udiE_GLTxn_GST a
	join iss_Reflib b (nolock) on b.RefType = 'GLExtractionInd' and b.RefCd = a.ExtInd and b.RefNo = 0 and b.IssNo = @IssNo -- Summary
	left outer join iss_Product c (nolock) on c.ProdCd = a.ProdCd
	where PrcsId = @PrcsId
	group by a.IssAcqInd, a.IssNo, a.BatchId, a.RcCd, a.TxnDate, a.SlipSeq, a.AcctTxnCd, a.BusnLocation, a.TxnType, a.Descp1, a.Descp2, 
			a.PrcsId, a.TxnCd, a.ProdCd, c.Descp, a.VATCd
	having sum(isnull(a.TxnAmt,0))<> 0

	if @@ERROR <> 0 return 902


	--Put non sales transaction of '20202110' & '17991000' GL to trash
	update a  set DocFlag = 9 
	from #udie_GLTxnSummary_GST_temp a 
--	join itx_TxnCode b on b.txnCd = a.TxnCd and b.Category  not in (@AdjustTxnCategory,@PtsIssueTxnCategory)            --2015/06/30 Humairah	(to delete redemption transaction details only bcoz it will be segregate later in the self billing handling )
	join itx_TxnCode b (nolock) on b.txnCd = a.TxnCd and b.Category  = @RdmpTxnCategory
	where AcctTxnCd in ('20202110','17991000') or isnull(TxnAmt,0) =0													-- **  only for points issuance/sales transaction

	if @@ERROR <> 0 return 913

	update a  set DocFlag = 9 
	from #udie_GLTxnSummary_GST_temp a 
	join itx_TxnCode b (nolock) on b.txnCd = a.TxnCd and b.Category = @AdjustTxnCategory
	where isnull(a.DocFlag,0) <> 9 and a.AcctTxnCd in ('20202110','17991000')  and a.TxnCd in (406,407,408,409,410,411)									--2015/06/30 Humairah	(to delete redemption transaction details only bcoz it will be segregate later in the self billing handling )

	if @@ERROR <> 0 return 904
	
	--summ of redemption group by PSS.
	insert #udie_GLTxnSummary_GST_temp (IssNo,BatchId,RcCd,TxnDate,SlipSeq,AcctTxnCd,BusnLocation,TxnType,TxnAmt,
			Descp1, Descp2, PrcsId, TxnCd, IssAcqInd, VATCd, VATAmt, ProdCd, ProdDescp, DocFlag, SeqNo)
	select  a.IssNo, a.BatchId, a.RcCd, a.TxnDate, a.SlipSeq, a.AcctTxnCd,a.BusnLocation, a.TxnType, sum(isnull(a.TxnAmt,0.00))- sum(isnull(a.VATAmt,0.00)) as 'TxnAmt',
			a.Descp1,a.Descp2, a.PrcsId, a.TxnCd, a.IssAcqInd, NULL, case a.TxnCd when 508 then 0 else NULL end, NULL, NULL, case when a.BusnLocation is null then 9 else NULL end, 
			case when a.BusnLocation is null then 0 else 1 end--case d.Category when @AdjustTxnCategory then 0 when @RdmpTxnCategory then 1  else 0 end
	from udiE_GLTxn_GST a
	join iss_Reflib b (nolock) on b.RefType = 'GLExtractionInd' and b.RefCd = a.ExtInd and b.RefNo = 0 and b.IssNo = @IssNo -- Summary
	left join iss_Product c (nolock) on c.ProdCd = a.ProdCd
	join itx_TxnCode d (nolock) on d.TxnCd = a.TxnCd 
	where PrcsId = @PrcsId and a.IssAcqInd = 'I' and AcctTxnCd in ('20202110','17991000') 
	group by a.IssAcqInd, a.IssNo, a.BatchId, a.RcCd, a.TxnDate, a.SlipSeq, a.AcctTxnCd, a.BusnLocation, a.TxnType, a.Descp1, a.Descp2, a.PrcsId, a.TxnCd,d.Category 
	having sum(isnull(a.TxnAmt,0.00))- sum(isnull(a.VATAmt,0.00)) > 0 

	if @@ERROR <> 0 return 905

	--Put Txnamt = 0 transaction to trash
	update a 
	set DocFlag = '9'
	from #udie_GLTxnSummary_GST_temp a 
	join (	select IssNo,BatchId,RcCd,TxnDate,RecId,BusnLocation,PrcsId,TxnCd,IssAcqInd
		from #udie_GLTxnSummary_GST_temp (nolock)
		where DocFlag = 1 
		group by IssNo, BatchId, RcCd, TxnDate, BusnLocation, RecId, BusnLocation, PrcsId, TxnCd, IssAcqInd
		having sum(isnull(TxnAmt,0))=0) b on b.RecId = a.RecId

	if @@ERROR <> 0 return 905

	delete from #udie_GLTxnSummary_GST_temp where DocFlag = 9

	if @@ERROR <> 0 return 906

	update #udie_GLTxnSummary_GST_temp set DocFlag = NULL

	if @@ERROR <> 0 return 907

--Handling Self billing requirement (Merchan's Invoice)[B]
	update a 
	set DocFlag = 1 ,
		SlipSeq = 'RE',
		Descp2 = 
			case when a.VATCd = 'I1' then 'REDEEMED '+ substring(rtrim(isnull(a.ProdDescp,'')),1,12)+ '(6%)'
				 else 'REDEEMED '+ substring(rtrim(isnull(a.ProdDescp,'')),1,12)+ '(0%)' 
			end,
		SeqNo = case when b.Category = 2 then 0 else 2 end
	from #udie_GLTxnSummary_GST_temp a 
	join itx_TxnCode b (nolock) on a.TxnCd = b.TxnCd  and b.Category in (@AdjustTxnCategory,@RdmpTxnCategory)
	where a.AcctTxnCd = '71300100' and a.TxnCd <> 508 and a.PrcsId = @PrcsId   -- exclude points conversion (redemption)transaction

	if @@ERROR <> 0 return 908

	insert #udie_GLTxnSummary_GST_temp
		(IssNo,BatchId,RcCd,TxnDate,SlipSeq,AcctTxnCd,BusnLocation, TxnType,TxnAmt,RefNo,
		Descp1, Descp2, PrcsId, TxnCd, IssAcqInd, VATAmt, SeqNo)
	select a.IssNo,a.BatchId,a.RcCd,a.TxnDate,'RE',b.SAPNo as 'AcctTxnCd',a.BusnLocation, 31 as 'TxnType',sum(a.TxnAmt)'TxnAmt',a.RefNo,
		b.DBAName 'Descp1' ,  a.BusnLocation + ' POINT REDEMPTION BY CARDMEMBER' as 'Descp2', a.PrcsId, a.TxnCd, a.IssAcqInd, convert(money,0) as 'VATAmt', 2
	from #udie_GLTxnSummary_GST_temp a (nolock) 
	join aac_BusnLocation b (nolock) on b.BusnLocation = a.BusnLocation
	where a.DocFlag = 1
	group by a.IssNo,a.BatchId,a.RcCd,a.TxnDate,b.SAPNo,a.BusnLocation,a.RefNo,b.DBAName,a.BusnLocation,a.PrcsId,a.TxnCd,a.IssAcqInd

	if @@ERROR <> 0 return 909

--Handling Self billing requirement [E]

	select @Rc = count(*) from #udie_GLTxnSummary_GST_temp where BatchId = @BatchId and PrcsId = @PrcsId
	
	insert into #udie_GLTxnSummary_GST_final
		(IssNo,	SeqNo, RefNo, BatchId, RcCd, TxnDate,SlipSeq, AcctTxnCd, BusnLocation, TxnType, TxnAmt, Descp1,
		Descp2,	PrcsId,	TxnCd, IssAcqInd, DocFlag, ProdCd,ProdDescp, VATCd, VATAmt)
	select IssNo, SeqNo, RefNo,	BatchId, RcCd, TxnDate,	SlipSeq, AcctTxnCd,	BusnLocation, TxnType, TxnAmt, Descp1,
		Descp2,	PrcsId,	TxnCd, IssAcqInd, DocFlag, ProdCd, ProdDescp,	VATCd,	VATAmt
	from #udie_GLTxnSummary_GST_temp
	order by BusnLocation, TxnCd, SeqNo

	IF @@ERROR <> 0 return 888


	select @MaxNo = min(RecId)
	from #udie_GLTxnSummary_GST_final
	where RefNo is null

	while 1=1 and @MaxNo > 0
	BEGIN
		select @SeqNo = SeqNo,
			@TCd = TxnCd
		from #udie_GLTxnSummary_GST_final
		where RecId = @MaxNo

		IF @Ind = 0
		BEGIN
			select @PrvSeqNo = @SeqNo,
				@PrvTCd = @TCd,
				@Ind = 1
		END

		IF @SeqNo <> @PrvSeqNo or @TCd <> @PrvTCd select @RefNo = @RefNo + 1

		update #udie_GLTxnSummary_GST_final
		set RefNo = @RefNo
		where RecId = @MaxNo

		IF @@ERROR <> 0 return 99999

		select @PrvSeqNo = @SeqNo,
			@PrvTCd = @TCd

		select @MaxNo = min(RecId)
		from #udie_GLTxnSummary_GST_final
		where RefNo is null	and RecId > @MaxNo

		IF @MaxNo is null break
	END

	--special request : txncd 214 is a BIG - KM pts conversion, set VatCd to O0 because PDB need to pay to TM, just like the normal redemption
	-- indicator : 90040452
	update  #udie_GLTxnSummary_GST_final set VatCd = 'OZ' where TxnCd = 214 and TxnType = 50
	
	--manually set vatcd for null vatcd 
	update #udie_GLTxnSummary_GST_final set VatCd = 'I0'  where  SlipSeq = 'RE' and TxnType = 40  and VATCd is null 

	--remove -ve sign
	update #udie_GLTxnSummary_GST_final set TxnAmt = replace(TxnAmt,'-','')

	----------
	BEGIN TRAN
	----------
--select * into udie_GLTxnSummary_GST_1000 from udie_GLTxnSummary_GST where PrcsId = 9202929292
--insert udie_GLTxnSummary_GST_1000 (IssNo, BatchId, RcCd, TxnDate, SlipSeq, AcctTxnCd, BusnLocation, TxnType, TxnAmt, RefNo, Descp1, Descp2,
		insert udie_GLTxnSummary_GST (IssNo, BatchId, RcCd, TxnDate, SlipSeq, AcctTxnCd, BusnLocation, TxnType, TxnAmt, RefNo, Descp1, Descp2,
			PrcsId, TxnCd, IssAcqInd, VATCd, VATAmt, ProdCd, ProdDescp, DocFlag)
		select IssNo, BatchId, RcCd, substring(convert(varchar(8),getdate(),112),7,2) + substring(convert(varchar(8),getdate(),112),5,2) + substring(convert(varchar(8),getdate(),112),3,2), SlipSeq, AcctTxnCd, BusnLocation, TxnType, TxnAmt, RefNo, Descp1, Descp2,
				PrcsId, TxnCd, IssAcqInd, VATCd, VATAmt, ProdCd, ProdDescp,SeqNo
		from #udie_GLTxnSummary_GST_final

		if @@ERROR <> 0
		begin
			rollback transaction
			return 70265 -- Failed to update Batch
		end
--drop table  udi_Batch_1000
--truncate table udi_Batch_1000
--select * into udi_Batch_1000 from udi_Batch where FileName = 'GLTxn'
--insert udi_Batch_1000 (IssNo, BatchId, SrcName, FileName, FileSeq, DestName, FileDate,
		insert udi_Batch (IssNo, BatchId, SrcName, FileName, FileSeq, DestName, FileDate,
				RecCnt, Direction, Sts, PrcsId, PrcsDate)
		select @IssNo, @BatchId, 'HOST', 'GLTXN', isnull(@FileSeq,0)+1, 'SAPGL', getdate(),
			@Rc, 'E', 'L', @PrcsId, @PrcsDate

		if @@ERROR <> 0
		begin
			rollback transaction
			return 70265 -- Failed to update Batch
		end

	------------------
	COMMIT TRANSACTION
	------------------

	drop table #Txn
	drop table #udie_GLTxnSummary_GST_temp 
	drop table #udie_GLTxnSummary_GST_final

	return 0
end
GO
