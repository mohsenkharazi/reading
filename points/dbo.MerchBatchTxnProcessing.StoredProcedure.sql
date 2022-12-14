USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchBatchTxnProcessing]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*****************************************************************************************************************            
            
Copyright : CardTrend Systems Sdn. Bhd.            
Modular  : CardTrend Card Management System (CCMS)- Acquiring Module            
            
Objective : This stored procedure process transaction in batch             
    and call MerchTxnProcessing and to finish the rest of the processing.            
            
SP Level : Secondary            
            
  --Online settlement & transaction status code            
  "U"=Unbalance            
  "B"=Upload batch            
  "A"=Settled successfully & active            
            
  --MerchBatchTxnProcessing status code:            
  "A"=Active            
  "C"=Invalid business location            
  "Z"=Invalid original transaction amount            
  "D"=Transaction date out of range            
  "G"=Transaction date greater than process date            
  "T"=Invalid transaction code            
  "X"=Total detail transaction does not tally with parent transaction            
  "P"=Invalid product code/ Updating parent transaction with invalid Product Code status            
            
            
-------------------------------------------------------------------------------            
When  Who  CRN    Desc            
-------------------------------------------------------------------------------            
2001/10/02 Jacky   Initial development            
2002/11/18 Sam    Reconciliation            
2008/06/11 Peggy   Add matching table field            
2009/03/17 Chew Pei  Commented @RedemptionTxnInd selection            
2009/07/27 Chew Pei  Added nolock for itx_SourceTxn and itx_SourceTxnDetail            
2009/09/02 Darren   Due to split payment the parent detail and the child detail will always unbalance            
       Remove the validation between parent detail and child detail if billmethod is 'T'            
2009/09/30 Sam    Caused by Sts ='U', abs(Pts) and abs            
2015/02/10 Sam    Cater for GST.            
******************************************************************************************************************/              
-- EXEC MerchBatchTxnProcessing 1,19            
CREATE procedure [dbo].[MerchBatchTxnProcessing]             
 @AcqNo uAcqNo,            
 @PrcsId uPrcsId            
--with encryption             
as            
begin            
 declare @Rc int, @Cnt int, @PrcsDate char(8), @PrcsName varchar(50),             
   @ActiveSts uRefCd, @RedemptionTxnInd uRefCd            
            
 --SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED            
 set nocount on;            
         
 EXEC @rc = dbo.InitProcess  
          
 if @@ERROR <> 0 or @rc <> 0 return 99999            
            
 select @PrcsName = 'MerchBatchTxnProcessing'            
 EXEC TraceProcess @AcqNo, @PrcsName, 'Start'            
            
 if @PrcsId is null            
 begin            
  select @PrcsId = CtrlNo, @PrcsDate = convert(char(8),CtrlDate,112)            
  from iss_Control (nolock)            
  where IssNo = @AcqNo and CtrlId = 'PrcsId'            
 end            
 else            
 begin            
  select @PrcsDate = convert(char(8),PrcsDate,112)            
  from cmnv_ProcessLog (nolock)            
  where IssNo = @AcqNo and PrcsId = @PrcsId            
 end            
            
 select @ActiveSts = RefCd    from iss_RefLib (nolock) where IssNo = @AcqNo and RefType = 'MerchBatchSts' and RefNo = 0            
            
 if @ActiveSts is null return 95049 --Status Code is invalid            
            
 -- CP Commented - not used            
 --select @RedemptionTxnInd = RefCd            
 --from iss_RefLib where IssNo = @AcqNo and RefType = 'TxnInd' and RefNo = 1            
            
 --if @@rowcount = 0 or @@ERROR <> 0 return 95049 --Status Code is invalid            
            
 -- Validate batch id            
 select @Cnt = count(*)            
 from atx_SourceTxn (nolock)            
 where AcqNo = @AcqNo and PrcsId = @PrcsId            
            
 if isnull(@Cnt,0) = 0 return 54022 -- Batch contain no record            
            
 -- To activate all settlement            
 update atx_SourceSettlement             
 set Sts = @ActiveSts            
 where AcqNo = @AcqNo and PrcsId = @PrcsId            
            
 -- To activate all transaction details with 'A'ctive status.            
 update atx_SourceTxn             
 set Sts = @ActiveSts            
 where AcqNo = @AcqNo and PrcsId = @PrcsId            
            
 -- To activate all transaction details with 'A'ctive status.            
 update a             
set a.Sts = @ActiveSts            
 from atx_SourceTxnDetail a, atx_SourceTxn b (nolock)            
 where b.AcqNo = @AcqNo and b.PrcsId = @PrcsId and a.SrcIds = b.Ids            
            
 -- Total count and amount in settlement does not tally with total transaction            
 update a             
 set a.Sts = 'U'            
 from atx_SourceSettlement a            
 join ( select a.Ids, a.BatchId, count(*) 'Cnt', sum(b.Amt) 'Amt'            
  from atx_SourceSettlement a (nolock)            
  join atx_SourceTxn b (nolock) on a.Ids = b.SrcIds and a.PrcsId = b.PrcsId and a.BatchId = b.BatchId            
  where a.Acqno = @AcqNo and a.PrcsId = @PrcsId and a.Sts = @ActiveSts            
  group by a.Ids, a.BatchId ) as b on a.Ids = b.Ids and a.BatchId = b.BatchId             
          and (isnull(a.Cnt, 0) <> isnull(b.Cnt, 0)             
          or isnull(a.Amt, 0) <> isnull(b.Amt, 0) )            
            
-- Settlement not ready            
-- update a set Sts = 'B'            
-- from atx_SourceTxn a, atx_SourceSettlement b            
-- where b.AcqNo = @AcqNo and b.PrcsId = @PrcsId and b.Sts <> @ActiveSts and a.AcqNo = @AcqNo            
-- and a.PrcsId = @PrcsId and a.SrcIds = b.Ids            
            
 --Invalid Business Location            
 update a             
 set a.Sts = 'C'            
 from atx_SourceTxn a            
 where AcqNo = @AcqNo and PrcsId = @PrcsId and Sts = @ActiveSts            
 and isnull(a.BusnLocation,'0') > '0' and not exists (select 1 from aac_BusnLocation b (nolock) where a.BusnLocation = b.BusnLocation)            
            
 --Invalid Original Transaction Amount            
 update atx_SourceTxn            
 set Sts = 'Z'            
 where AcqNo = @AcqNo and PrcsId = @PrcsId and Sts = @ActiveSts and isnull(Amt, 0) < 0            
            
 --Transaction date out of range.            
 update atx_SourceTxn            
 set Sts = 'D'            
 where AcqNo = @AcqNo and PrcsId = @PrcsId and Sts = @ActiveSts            
 and TxnDate < dateadd(yy, -1, getdate())            
            
 --Transaction date greater than process date            
 update atx_SourceTxn            
 set Sts = 'G'            
 where AcqNo = @AcqNo and PrcsId = @PrcsId and Sts = @ActiveSts            
 and convert(char(8),TxnDate,112) > @PrcsDate            
            
 --Invalid Transaction Code            
 update a             
 set a.Sts = 'T'            
 from atx_SourceTxn a            
 where AcqNo = @AcqNo and PrcsId = @PrcsId and Sts = @ActiveSts            
 and not exists (select 1 from atx_TxnCode b (nolock) where a.TxnCd = b.TxnCd)            
            
 --Total detail transaction does not tally with parent transaction            
 update a             
 set a.Sts = 'U'            
 from atx_SourceTxn a            
 join ( select b.Ids, sum(c.AmtPts) 'SettleTxnAmt', sum(c.BillingAmt) 'BillingTxnAmt', sum(c.BillingPts) 'Pts', sum(c.BillingPts) 'PromoPts'            
  from atx_SourceTxn b (nolock)            
  join atx_SourceTxnDetail c (nolock) on b.AcqNo = c.AcqNo and b.Ids = c.SrcIds and b.BatchId = c.BatchId            
  join atx_TxnCode d (nolock) on d.TxnCd = b.TxnCd and d.BillMethod = 'P'  -- 20090902 (Darren) Only check for tally if its a product method calculation cater for split payment redemption             
  where b.AcqNo = @AcqNo and b.PrcsId = @PrcsId and b.Sts = @ActiveSts            
  group by b.Ids ) d on a.Ids = d.Ids       
       and (isnull(a.Amt, 0) <> isnull(d.SettleTxnAmt, 0)            
       or isnull(a.BillingAmt, 0) <> isnull(d.BillingTxnAmt, 0)            
--2009/09/30B            
--       or isnull(a.Pts, 0) <> isnull(d.Pts, 0)             
--       or isnull(a.BillingPts, 0) <> isnull(d.PromoPts, 0) )            
       or abs(isnull(a.Pts, 0)) <> isnull(d.Pts, 0)             
       or abs(isnull(a.BillingPts, 0)) <> isnull(d.PromoPts, 0) )            
--2009/09/30E            
 --Invalid Product Code            
 update a             
 set a.Sts = 'P'            
 from atx_SourceTxnDetail a            
 join atx_SourceTxn b (nolock) on a.SrcIds = b.Ids and b.PrcsId = @PrcsId and a.Sts = b.Sts            
where a.Sts = @ActiveSts and not exists ( select 1 from iss_Product c (nolock) where c.IssNo = @AcqNo and a.ProdCd = c.ProdCd )            
            
 --Updating parent transaction with invalid Product Code status            
 update a             
 set a.Sts = 'P'            
 from atx_SourceTxn a            
 join atx_SourceTxnDetail b (nolock) on a.AcqNo = b.AcqNo and a.Ids = b.SrcIds and a.BatchId = b.BatchId and b.Sts = 'P'            
 where a.AcqNo = @AcqNo and a.PrcsId = @PrcsId and a.Sts = @ActiveSts            
            
 --Tag settlement transaction to error if the child transactions is not valid            
 update a             
 set a.Sts = 'E'            
 from atx_SourceSettlement a            
 join atx_SourceTxn b (nolock) on a.AcqNo = b.AcqNo and a.Ids = b.SrcIds and a.BatchId = b.BatchId and b.Sts <> @ActiveSts            
            
 EXEC TraceProcess @AcqNo, @PrcsName, 'Creating merch temporary tables'            
 --Create temporary tables to store all transactions are going to be process            
            
 select * into #SourceTxn   from itx_SourceTxn (nolock) where BatchId = -1            
 select * into #SourceTxnDetail  from itx_SourceTxnDetail (nolock) where BatchId = -1            
            
 delete #SourceTxn            
 delete #SourceTxnDetail            
            
             
 --Creating index for temporary table            
 create unique index IX_SourceTxnDetail            
 on #SourceTxnDetail ( BatchId, ParentSeq, TxnSeq )            
             
            
            
 insert into #SourceTxn             
  (BatchId, TxnSeq, IssNo, TxnCd, AcctNo, CardNo, LocalTxnDate, TxnDate,            
  LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Descp,            
  BusnLocation, Mcc, TermId, Rrn, Stan, AppvCd, CrryCd, Arn, Odometer,            
  BillMethod, PlanId, PrcsId, InputSrc, SrcTxnId, RefTxnId, AuthTxnId,            
  WithheldUnsettleId, OnlineTxnId, OnlineInd, UserId, Sts, SubsidizedAmt,            
--2015/02/15B            
  VATNo, VATAmt)            
--2015/02/15E            
 select b.BatchId, b.Ids, b.AcqNo, b.TxnCd, null, b.CardNo, b.TxnDate, b.TxnDate,            
  b.Amt, b.Amt, isnull(b.BillingAmt,0), isnull(b.BillingPts,0), 0, b.Descp,   -- 2009-08-26 (Darren) Remove PromoPts and change Pts to BillingPts - Phase2            
  b.BusnLocation, null, b.TermId, b.Rrn, null, b.AuthNo, b.CrryCd, b.Arn, b.Odometer,            
--2003/07/28B            
  --null/*BillMethod*/, null/*PlanId*/, b.PrcsId, 'ACQ', 0, b.SrcIds, b.Ids,            
  null/*BillMethod*/, null/*PlanId*/, b.PrcsId, a.InputSrc, 0, b.SrcIds, b.Ids,            
--2003/07/28E            
  b.WithheldUnsettleId, null, null, b.UserId, b.Sts, b.SubsidizedAmt,            
  --2015/02/15B            
  b.VATNo, isnull(b.VATAmt,0)            
  --2015/02/15E             
 from atx_SourceSettlement a (nolock)            
 join atx_SourceTxn b (nolock) on a.AcqNo = b.AcqNo and a.Ids = b.SrcIds and a.PrcsId = b.PrcsId and a.Sts = b.Sts and a.BatchId = b.BatchId and a.BusnLocation = b.BusnLocation --2008/06/11            
 where a.AcqNo = @AcqNo and a.PrcsId = @PrcsId and a.Sts = @ActiveSts --and a.TxnInd <> @RedemptionTxnInd            
       
       
 if @@ERROR <> 0 return 70109 --Failed to insert into #SourceTxn            
 
 
 insert into #SourceTxnDetail            
  (BatchId, ParentSeq, TxnSeq, IssNo, RefTo, RefKey, LocalTxnAmt,            
  SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Qty, SrcTxnId, PlanId, Sts, SubsidizedAmt,            
--2015/02/15B            
  BaseAmt, VATAmt, VATCd, VATRate)            
--2015/02/15E            
 select c.BatchId, c.SrcIds, c.Seq, c.AcqNo, 'P', c.ProdCd, c.AmtPts,            
  c.AmtPts, 0, c.BillingPts, 0, c.Qty, null, c.PlanId/*null b.PlanId*/, c.Sts, c.SubsidizedAmt,   -- 2009-08-26 (Darren) Used BillingPts for atx_SourceTxnDetail instead of 0 & add Plan id for txn detail- Phase2            
--2015/02/15B            
  isnull(c.BaseAmt,0), isnull(c.VATAmt,0), ltrim(rtrim(c.VATCd)), isnull(c.VATRate,0)            
--2015/02/15E            
 from atx_SourceSettlement a (nolock)    
 join atx_SourceTxn b (nolock) on a.AcqNo = b.AcqNo and a.Ids = b.SrcIds and a.PrcsId = b.PrcsId and a.BatchId = b.BatchId and a.BusnLocation = b.BusnLocation --2008/06/11            
 join atx_SourceTxnDetail c (nolock) on b.AcqNo = c.AcqNo and b.Ids = c.SrcIds and b.Sts = c.Sts and b.BatchId = c.BatchId            
 where a.AcqNo = @AcqNo and a.PrcsId = @PrcsId and a.Sts = @ActiveSts --and a.TxnInd <> @RedemptionTxnInd            
          
 if @@ERROR <> 0 return 70266 --Failed to insert into #SourceTxnDetail            
         
      
 --Creating index for temporary table             
 --20170731            
 CREATE NONCLUSTERED INDEX IX_mbtp_SourceTxn_BatchIdPrcsId            
 ON #SourceTxn(BatchId,PrcsId)            
 INCLUDE (TxnSeq,SettleTxnAmt,BillingTxnAmt,Pts,BillMethod,PlanId,SubsidizedAmt);            
            
 --20170712            
 CREATE NONCLUSTERED INDEX IX_mbtp_SourceTxn_PrcsId ON #SourceTxn(PrcsId)            
 INCLUDE (BatchId,TxnSeq,SettleTxnAmt,BillingTxnAmt,Pts,BillMethod,PlanId,SubsidizedAmt,RefTxnId,BusnLocation,TermId);            
            
 --20170710            
 CREATE INDEX IX_mbtp_SourceTxnDetail_ParentSeqRefTo ON #SourceTxnDetail(ParentSeq,RefTo)            
 INCLUDE (SettleTxnAmt,BillingTxnAmt,Pts);            
 CREATE INDEX IX_mbtp_SourceTxn_BillMethod ON #SourceTxn(BillMethod)            
 INCLUDE (TxnCd,SettleTxnAmt,PlanId,TxnDate,TxnSeq);            
            
 --20170707            
 CREATE INDEX IX_mbtp_SourceTxn_TxnCd ON #SourceTxn(TxnCd)            
 INCLUDE (SettleTxnAmt,BillingTxnAmt,Pts,BusnLocation,TermId,TxnSeq);            
 CREATE INDEX IX_mbtp_SourceTxnDetail_RefTo ON #SourceTxnDetail(RefTo)            
 INCLUDE (ParentSeq,RefKey,SettleTxnAmt,BillingTxnAmt,Pts);            
            
 --20170706            
 --CREATE INDEX IX_mbtp_SourceTxn_PrcsId ON #SourceTxn(PrcsId);            
 CREATE INDEX IX_mbtp_SourceTxn_RefTxnId ON #SourceTxn(RefTxnId);            
 --20170705            
 CREATE INDEX IX_mbtp_SourceTxn_BusnLocation ON #SourceTxn(BusnLocation);            
 CREATE INDEX IX_mbtp_SourceTxn_TxnDate ON #SourceTxn(TxnDate);            
 CREATE INDEX IX_mbtp_SourceTxn_TxnSeq ON #SourceTxn(TxnSeq);            
      
 ----------------------------------------            
 SAVE TRANSACTION MerchBatchTxnProcessing            
 ----------------------------------------            
           
 ---------------------------------------------------------------------------------            
 -- Call TxnBilling to calculate the actual transaction amount and bonus points --            
 ---------------------------------------------------------------------------------            
            
 EXEC @Rc = dbo.MerchTxnBilling @AcqNo            
            
 if @@ERROR <> 0 or dbo.CheckRC(@Rc) <> 0            
 begin            
  rollback transaction MerchTxnProcessing           
  return @Rc            
 end            
            
 ---------------------------------------            
 -- Main Transaction Processing Logic --            
 ---------------------------------------            
 EXEC @Rc = dbo.MerchTxnProcessing @AcqNo, @PrcsId            
            
 if @@ERROR <> 0 or (dbo.CheckRC(@Rc) <> 0 and @Rc <> 95159)            
begin            
  rollback transaction MerchTxnProcessing           
  return @Rc            
 end        
            
 EXEC TraceProcess @AcqNo, @PrcsName, 'Dropping merch temporary tables'            
            
 drop table #SourceTxn            
 drop index #SourceTxnDetail.IX_SourceTxnDetail            
 drop table #SourceTxnDetail            
            
 if @@ERROR <> 0            
 begin            
  rollback transaction MerchTxnProcessing           
  return 70267 -- Failed to drop temporary table            
 end            
            
 return @Rc      
end
GO
