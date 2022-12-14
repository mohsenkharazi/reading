USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BatchTxnProcessing]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/*****************************************************************************************************************        
        
Copyright : CardTrend Systems Sdn. Bhd.        
Modular  : CardTrend Card Management System (CCMS)- Issuing Module        
        
Objective : This stored procedure process transaction in batch and call TxnProcessing to finish the rest        
    of the processing.        
        
SP Level : Secondary        
        
-------------------------------------------------------------------------------        
When  Who  CRN			Desc        
-------------------------------------------------------------------------------        
2001/10/02 Jacky		Initial development        
2003/03/10 Sam			Fixes.        
2003/07/11 Jacky		Reverse Unbilled Transaction.        
2004/08/17 Chew Pei		Added AuthCardNo into #SourceTxn        
2008/06/26 Peggy		Added Status checking on CardSts and AcctSts        
2009/03/10 Darren		Removed status checking        
2009/03/16 Chew Pei           
2009/07/15 Darren		Added nolock statement        
2009/08/14 Darren		Added CashAmt, VoucherAmt, PaymtCardPrefix into transaction table        
2009/09/02 Darren		Due to split payment the parent detail and the child detail will always unbalance        
						Remove the validation between parent detail and child detail if billmethod is 'T'        
2015/02/10 SAM			Cater for GST.        
2019/05/21 Azan			Add IAuthSourceTransactionId and IAuthReferenceTransactionId 
2020/06/24 Chui         Add SourceId      
******************************************************************************************************************/        
        
CREATE procedure [dbo].[BatchTxnProcessing]        
 @IssNo uIssNo,        
 @BatchId int        
--with encryption         
as        
begin        
 declare @rc int,        
  @Cnt int,        
  @PrcsId int,        
  @PrcsDate datetime,        
  @PrcsName varchar(50),        
  @CardCenterBusnLocation uMerchNo,        
  @PurchTxnCategory int,        
  @RdmpTxnCategory int        
        
 EXEC @rc = dbo.InitProcess        
 if @@ERROR <> 0 or @rc <> 0 return 99999        
        
 select @PrcsName = 'BatchTxnProcessing'        
        
 EXEC dbo.TraceProcess @IssNo, @PrcsName, 'Start'        
        
 -- Validate batch id        
        
 select @Cnt = count(*)    from itx_SourceTxn (nolock) where IssNo = @IssNo and BatchId = @BatchId        
        
 if @Cnt is null        
 begin        
--  raiserror ('Invalid Batch ID', 16, 1)        
  return 60046 -- Batch not found        
 end        
        
 if @Cnt = 0        
 begin        
  return 54022 -- Batch contain no record        
 end        
        
 -- Initialize all the status code to null        
        
 select @PrcsId = CtrlNo, @PrcsDate = CtrlDate        
 from iss_Control (nolock)        
 where IssNo = @IssNo and CtrlId = 'PrcsId'        
        
 select @CardCenterBusnLocation = cast(VarCharVal as bigint)  from iss_Default (nolock) where IssNo = @IssNo and Deft = 'CardCenterBusnLocation'        
 select @PurchTxnCategory = IntVal        from iss_Default (nolock) where IssNo = @IssNo and Deft = 'PurchTxnCategory'        
 select @RdmpTxnCategory = IntVal        from iss_Default (nolock) where IssNo = @IssNo and Deft = 'RdmpTxnCategory'        
        
 update itx_SourceTxn        
 set PrcsId = @PrcsId,         
  Sts = 'A'        
 where IssNo = @IssNo and BatchId = @BatchId        
        
 update itx_SourceTxnDetail        
 set Sts = 'A'        
 where IssNo = @IssNo and BatchId = @BatchId        
        
 -- Rejects errorous records        
        
 -- Invalid Account Number        
 update a         
 set Sts = 'N'        
 from itx_SourceTxn a        
 where IssNo = @IssNo and BatchId = @BatchId and Sts = 'A'        
 and a.AcctNo is not null and not exists (select 1 from iac_Account b (nolock) where b.AcctNo = a.AcctNo)        
        
 -- Invalid Card Number        
 update a         
 set Sts = 'C'        
 from itx_SourceTxn a        
 where IssNo = @IssNo and BatchId = @BatchId and Sts = 'A'        
 and isnull(a.CardNo,0) <> 0 and not exists (select 1 from iac_Card b (nolock) where a.CardNo = b.CardNo)        
        
 --2003/03/10B        
 -- Revert negative amount to postive.        
 update itx_SourceTxn        
 set SettleTxnAmt = SettleTxnAmt * -1        
 where SettleTxnAmt < 0 and IssNo = @IssNo and BatchId = @BatchId and Sts = 'A'        
 --2003/03/10E        
         
 -- Invalid Original Transaction Amount        
-- update itx_SourceTxn        
-- set Sts = 'Z'        
-- where IssNo = @IssNo and BatchId = @BatchId and Sts = 'A'        
-- and SettleTxnAmt < 0        
        
 -- Transaction date out of range        
 update itx_SourceTxn        
 set Sts = 'D'        
 where IssNo = @IssNo and BatchId = @BatchId and Sts = 'A'        
 and TxnDate < dateadd(yy, -1, getdate())        
        
 -- Transaction date greater than process date        
 update itx_SourceTxn        
 set Sts = 'G'        
 where IssNo = @IssNo and BatchId = @BatchId and Sts = 'A'        
 and cast(convert(varchar(10),TxnDate,120) as datetime) > @PrcsDate        
        
 -- Invalid Transaction Code        
 update a set Sts = 'T'        
 from itx_SourceTxn a        
 where IssNo = @IssNo and BatchId = @BatchId and Sts = 'A'        
 and not exists (select 1 from itx_TxnCode b (nolock) where a.TxnCd = b.TxnCd)        
        
 -- Total detail transaction does not tally with parent transaction        
-- update a set Sts = 'U'        
-- from itx_SourceTxn a        
-- join        
--  (select c.ParentSeq, sum(c.SettleTxnAmt) 'SettleTxnAmt', sum(c.BillingTxnAmt) 'BillingTxnAmt',        
--  sum(c.Pts) 'Pts', sum(c.PromoPts) 'PromoPts'        
--  from itx_SourceTxn b (nolock), itx_SourceTxnDetail c (nolock), itx_TxnCode d (nolock)        
--  where b.IssNo = @IssNo and b.BatchId = @BatchId and d.TxnCd = b.TxnCd and d.BillMethod = 'P' -- 20090902 (Darren) Only check for tally if its a product method calculation cater for split payment redemption         
--  and c.IssNo = @IssNo and c.BatchId = @BatchId and c.ParentSeq = b.TxnSeq         
--  group by c.ParentSeq) d        
-- on a.IssNo = @IssNo and a.BatchId = @BatchId and Sts = 'A'        
-- and d.ParentSeq = a.TxnSeq and (a.SettleTxnAmt != d.SettleTxnAmt        
-- or (a.BillingTxnAmt != d.BillingTxnAmt and d.BillingTxnAmt <> 0) or a.Pts != d.Pts        
-- or a.PromoPts != d.PromoPts)        
        
 -- Invalid Product Code        
 update a         
 set Sts = 'P'        
 from itxv_SourceTxnProductDetail a, itx_SourceTxn c, itx_TxnCode d (nolock)        
 where a.IssNo = @IssNo and a.BatchId = @BatchId and a.Sts = 'A'        
 and c.IssNo = @IssNo and c.BatchId = @BatchId and c.TxnSeq = a.ParentSeq        
 and d.IssNo = @IssNo and d.TxnCd = c.TxnCd and d.Category <> @RdmpTxnCategory        
 and not exists (select 1 from iss_Product b where b.IssNo = @IssNo and b.ProdCd = a.ProdCd)        
        
 -- Updating parent transaction with invalid Product Code status        
 update a         
 set Sts = 'P'        
 from itx_SourceTxn a        
 where a.IssNo = @IssNo and a.BatchId = @BatchId and a.Sts = 'A'        
 and exists (select 1 from itxv_SourceTxnProductDetail b (nolock)        
   where b.IssNo = @IssNo and b.BatchId = @BatchId and b.ParentSeq = a.TxnSeq        
   and b.Sts = 'P')        
        
/*        
 -- For PDB, for a redemption transaction, do not need to check reward because redemption comes        
 -- in like a sales transaction        
 -- Invalid Reward ID        
 update a set Sts = 'R'        
 from itxv_SourceTxnProductDetail a, itx_SourceTxn c, itx_TxnCode d        
 where a.IssNo = @IssNo and a.BatchId = @BatchId and a.Sts = 'A'        
 and c.IssNo = @IssNo and c.BatchId = @BatchId and c.TxnSeq = a.ParentSeq        
 and d.IssNo = @IssNo and d.TxnCd = c.TxnCd and d.Category = @RdmpTxnCategory        
 and not exists (select 1 from ird_Rewards b where b.IssNo = @IssNo and b.RewardId = a.ProdCd)        
        
 -- Updating parent transaction with invalid Reward ID status        
 update a set Sts = 'R'        
 from itx_SourceTxn a    
 where a.IssNo = @IssNo and a.BatchId = @BatchId and a.Sts = 'A'        
 and exists (select 1 from itxv_SourceTxnProductDetail b        
   where b.IssNo = @IssNo and b.BatchId = @BatchId and b.ParentSeq = a.TxnSeq        
   and b.Sts = 'R')        
*/        
 -- Card spent at prohibited business location        
 update a set Sts = 'B'        
 from itx_SourceTxn a       where a.IssNo = @IssNo and a.BatchId = @Batchid and a.Sts = 'A'        
 and a.BusnLocation <> @CardCenterBusnLocation        
 and a.CardNo is not null and exists (select 1 from iac_CardAcceptance b (nolock) where b.CardNo = a.CardNo)        
 and not exists (select 1 from iac_CardAcceptance c (nolock) where c.CardNo = a.CardNo and c.BusnLocation = a.BusnLocation)        
        
 update a       
 set Sts = 'B'        
 from itx_SourceTxn a, iac_Card b (nolock)        
 where a.IssNo = @IssNo and a.BatchId = @BatchId and a.Sts = 'A'        
 and a.BusnLocation <> @CardCenterBusnLocation        
 and a.CardNo is not null and b.CardNo = a.CardNo        
 and not exists (select 1 from iac_CardAcceptance c (nolock) where c.CardNo = a.CardNo)        
 and exists (select 1 from iac_AccountAcceptance d (nolock) where d.AcctNo = b.AcctNo)        
 and not exists (select 1 from iac_AccountAcceptance e (nolock) where e.AcctNo = b.AcctNo and e.BusnLocation = a.BusnLocation)        
        
 -- Online transaction not found (Issuer)        
 update a         
 set Sts = 'O'        
 from itx_SourceTxn a        
 where a.IssNo = @IssNo and a.BatchId = @BatchId and a.Sts = 'A' and a.OnlineTxnId is not null        
 and not exists (select 1 from itx_HeldTxn b (nolock) where b.TxnId = a.OnlineTxnId)        
        
 -- Online transaction already tagged (Issuer)        
 update a         
 set Sts = 'W'        
 from itx_SourceTxn a, itx_HeldTxn b (nolock)        
 where a.IssNo = @IssNo and a.BatchId = @BatchId and a.Sts = 'A' and a.OnlineTxnId is not null        
 and b.TxnId = a.OnlineTxnId and b.LinkTxnId > 0        
        
 -- Online transaction not found (Acquirer)        
 update a         
 set Sts = 'O'        
 from itx_SourceTxn a, itx_TxnCode c (nolock)        
 where a.IssNo = @IssNo and a.BatchId = @BatchId and a.Sts ='A' and a.AuthTxnId is not null        
 and c.IssNo = @IssNo and c.TxnCd = a.TxnCd and c.Category <> @RdmpTxnCategory        
 and not exists (select 1 from atx_Txn b (nolock) where b.Ids = a.AuthTxnId)        
        
 -- Online transaction already tagged (Acquirer)        
 update a         
 set Sts = 'W'        
 from itx_SourceTxn a, atx_Txn b (nolock)        
 where a.IssNo = @IssNo and a.BatchId = @BatchId and a.Sts = 'A' and a.AuthTxnId is not null        
 and b.Ids = a.AuthTxnId and b.IssLinkIds is not null        
        
 EXEC dbo.TraceProcess @IssNo, @PrcsName, 'Creating temporary tables'        
        
 -- Create temporary tables to store all transactions are going to be process        
        
 select * into #SourceTxn  from itx_SourceTxn (nolock) where BatchId = -1        
 select * into #SourceTxnDetail from itx_SourceTxnDetail (nolock) where BatchId = -1        
        
 delete #SourceTxn        
 delete #SourceTxnDetail        
 
        
 insert into #SourceTxn         
  (BatchId, TxnSeq, IssNo, TxnCd, AcctNo, CardNo, AuthCardNo, LocalTxnDate, TxnDate,        
  LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Descp,        
  BusnLocation, Mcc, TermId, Rrn, Stan, AppvCd, CrryCd, Arn, Odometer,        
  BillMethod, PlanId, PrcsId, InputSrc, SrcTxnId, RefTxnId, AuthTxnId,        
  OnlineTxnId, WithheldUnsettleId, OnlineInd, UserId, Sts , DealerCd, CashAmt, VoucherAmt, PaymtCardPrefix,        
--2015/02/10B        
  VATNO, VATAmt, ExternalTransactionId, IAuthSourceTransactionId, IAuthReferenceTransactionId, SourceId)     
--2015/02/10E          
 select BatchId, TxnSeq, IssNo, TxnCd, AcctNo, CardNo, AuthCardNo, LocalTxnDate, TxnDate,        
  LocalTxnAmt, SettleTxnAmt, isnull(BillingTxnAmt,0), isnull(Pts,0), isnull(PromoPts,0), Descp,        
  BusnLocation, Mcc, TermId, Rrn, Stan, AppvCd, CrryCd, Arn, Odometer,        
  null/*BillMethod*/, null/*PlanId*/, PrcsId, InputSrc, TxnId, RefTxnId, AuthTxnId,        
  OnlineTxnId, WithheldUnsettleId, OnlineInd, UserId, Sts, DealerCd, CashAmt, VoucherAmt, PaymtCardPrefix,        
--2015/02/10B        
  VATNO, isnull(VATAmt,0), ExternalTransactionId, IAuthSourceTransactionId, IAuthReferenceTransactionId, SourceId     
--2015/02/10E        
 from itx_SourceTxn (nolock)        
 where IssNo = @IssNo and BatchId = @BatchId and Sts = 'A'        
        
 if @@ERROR <> 0 return 70109 -- Failed to insert into #SourceTxn        
     
       
 insert into #SourceTxnDetail         
  (BatchId, ParentSeq, TxnSeq, IssNo, RefTo, RefKey, LocalTxnAmt,        
  SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Qty, SrcTxnId, PlanId, PricePerUnit, Sts,        
--2015/02/10B        
  BaseAmt, VATAmt, VATCd, VATRate)        
--2015/02/10E          
 select b.BatchId, b.ParentSeq, b.TxnSeq, b.IssNo, b.RefTo, b.RefKey, b.LocalTxnAmt,        
  b.SettleTxnAmt, isnull(b.BillingTxnAmt,0), isnull(b.Pts,0), isnull(b.PromoPts,0), b.Qty, a.TxnId, b.PlanId /*null*/, b.PricePerUnit, b.Sts, -- (Darren) changes the planid from null to value        
--2015/02/10B        
  isnull(b.BaseAmt,0), isnull(b.VATAmt,0), ltrim(rtrim(b.VATCd)), isnull(b.VATRate,0)        
--2015/02/10E        
  from itx_SourceTxn a (nolock), itx_SourceTxnDetail b (nolock)        
 where a.IssNo = @IssNo and a.BatchId = @BatchId and a.Sts = 'A'        
 and b.IssNo = @IssNo and b.BatchId = @BatchId and b.ParentSeq = a.TxnSeq        
        
 if @@ERROR <> 0 return 70266 -- Failed to insert into #SourceTxnProductDetail        
        
 -- Create Transaction Fee        
 insert into #SourceTxn (        
  BatchId, TxnSeq, IssNo, TxnCd, AcctNo, CardNo, LocalTxnDate, TxnDate,        
  LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Descp,        
  BusnLocation, Mcc, TermId, Rrn, Stan, AppvCd, CrryCd, Arn, Odometer,        
  BillMethod, PlanId, PrcsId, InputSrc, SrcTxnId, RefTxnId, AuthTxnId,        
  OnlineTxnId, WithheldUnsettleId, OnlineInd, UserId, Sts,        
--2015/02/10B        
  VATNo, VATAmt)        
--2015/02/10E        
 select 0, TxnSeq, a.IssNo, c.TxnCd, a.AcctNo, a.CardNo, a.LocalTxnDate, @PrcsDate,        
  a.LocalTxnAmt, a.SettleTxnAmt, 0, 0, 0, c.Descp,        
  a.BusnLocation, a.Mcc, a.TermId, a.Rrn, a.Stan, null, a.CrryCd, null, null,        
  null, null, a.PrcsId, 'SYS', a.SrcTxnId, -1, null, null,        
  c.OnlineInd, null, null, a.Sts,        
--2015/02/10B        
  a.VATNo, isnull(a.VATAmt,0)        
--2015/02/10E        
 from #SourceTxn a, itx_TxnCode b (nolock), itx_TxnCode c (nolock)        
 where b.IssNo = @IssNo and b.TxnCd = a.TxnCd and isnull(b.FeeTxnCd, 0) > 0        
 and c.IssNo = @IssNo and c.TxnCd = b.FeeTxnCd        
        
 if @@ERROR <> 0 return 70109 -- Failed to insert into #SourceTxn        
        
 -- Creating index for temporary table        
 create unique index IX_SourceTxn on #SourceTxn (TxnSeq)        
 create index IX_WithHeldUnSettleId on #SourceTxn (WithHeldUnSettleId)        
 create unique index IX_SourceTxnDetail on #SourceTxnDetail (        
--  BatchId,        
  ParentSeq,        
  TxnSeq )        


 -- Creating index for temporary table     
 --20170706    
 CREATE INDEX IX_btp_SourceTxn_AcctNo ON #SourceTxn(AcctNo);    
 --20170705    
 CREATE INDEX IX_btp_SourceTxnDetail_RefTo ON #SourceTxnDetail(RefTo);    
 CREATE INDEX IX_btp_SourceTxnDetail_SrcTxnId ON #SourceTxnDetail(SrcTxnId);    
 --20170704    
 --CREATE INDEX IX_btp_SourceTxn_TxnDate ON #SourceTxn(TxnDate);    
 --CREATE INDEX IX_btp_SourceTxn_TxnCd ON #SourceTxn(TxnCd); 


        
 ---------------------------        
 -- Update Exception Code --        
 ---------------------------        
        
 EXEC dbo.TraceProcess @IssNo, @PrcsName, 'Update Exception Code'        
        
 -- Update exception code Weekend        
 update #SourceTxn         
 set ExceptionCd = isnull(ExceptionCd,0) | 4        
 where datepart(dw, TxnDate) in (1, 7)        
        
 -- Update exception code Lube        
 update a         
 set ExceptionCd = isnull(ExceptionCd,0) | 16        
 from #SourceTxn a        
 join #SourceTxnDetail b on b.ParentSeq = a.TxnSeq and b.RefTo = 'P'        
 join iss_Product c on c.IssNo = @IssNo and c.ProdCd = b.RefKey        
 join iss_RefLib d on d.IssNo = @IssNo and d.RefType = 'ProdType' and d.RefCd = c.ProdType        
  and d.RefNo = 2        
        
 -- Update exception code Weekend        
 update a         
 set ExceptionCd = isnull(ExceptionCd,0) | 32        
 from #SourceTxn a        
 join #SourceTxnDetail b on b.ParentSeq = a.TxnSeq and b.RefTo = 'P'        
 join iss_Product c (nolock) on c.IssNo = @IssNo and c.ProdCd = b.RefKey        
 join iss_RefLib d (nolock) on d.IssNo = @IssNo and d.RefType = 'ProdType' and d.RefCd = c.ProdType        
  and d.RefNo > 2        
        
 EXEC dbo.TraceProcess @IssNo, @PrcsName, 'End Validation'        
        
 ---------------------------------------------------------------------------------        
 -- Call TxnBilling to calculate the actual transaction amount and bonus points --        
 ---------------------------------------------------------------------------------        
        
 EXEC @rc = dbo.TxnBilling @IssNo, @AmtInd = 2, @PtsInd = 2        
        
 if @@ERROR <> 0 or dbo.CheckRC(@rc) <> 0        
 begin        
  rollback transaction BatchTxnProcessing        
  return @rc        
 end        
        
 ------------------------------------------------------------------------------        
 -- Extra Validation after TxnBilling has populated value into BillingTxnAmt --           -        
 ------------------------------------------------------------------------------        
        
 -- Reverse Unsettle transaction only        
 update a         
 set Sts = 'K'        
 from #SourceTxn a        
 join itx_TxnCode b on b.IssNo = @IssNo and b.TxnCd = a.TxnCd and b.ReverseUnbilledInd = 'Y'        
 join (select a.AcctNo, b.Category 'Category', sum(isnull(abs(a.BillingTxnAmt), 0)) 'BillingTxnAmt'        
  from #SourceTxn a        
  join itx_TxnCode b (nolock) on b.IssNo = @IssNo and b.TxnCd = a.TxnCd and b.ReverseUnbilledInd = 'Y'        
  where a.Sts = 'A'        
  group by a.AcctNo, b.Category) as c        
  on c.AcctNo = a.AcctNo and c.Category = b.Category        
 left outer join iac_AgeingBalance d (nolock) on d.AcctNo = c.AcctNo and d.CycId = 0        
  and d.AgeingInd = 0 and d.Category = c.Category        
 where a.Sts = 'A' and isnull(d.Amt, 0) < c.BillingTxnAmt        
        
 if @@ERROR <> 0 return 70268 -- Failed to update #SourceTxn        
        
 -- Update rejected transaction status to itx_SourceTxn        
 update a         
 set Sts = b.Sts        
 from itx_SourceTxn a        
 join #SourceTxn b on b.Sts <> 'A' and b.SrcTxnId = a.TxnId        
        
 if @@ERROR <> 0 return 95265 -- Failed to update Status in SourceTxn        
        
 -- Delete rejected transaction from #SourceTxnProductDetail        
 delete a        
 from #SourceTxnDetail a        
 join #SourceTxn b on b.Sts <> 'A' and b.BatchId = a.BatchId and b.TxnSeq = a.ParentSeq        
        
 if @@ERROR <> 0 return 70321 -- Failed to delete SourceTxnDetail        
        
 -- Delete rejected transaction from #SourceTxn        
 delete #SourceTxn where Sts <> 'A'        
        
 if @@ERROR <> 0 return 70320 -- Failed to delete SourceTxn        
        
 -------------------------------------------        
 SAVE TRANSACTION BatchTxnProcessing        
 -------------------------------------------        
        
 ---------------------------------------        
 -- Main Transaction Processing Logic --        
 ---------------------------------------        
        
 EXEC @rc = dbo.TxnProcessing @IssNo, @BatchId        
        
 if @@ERROR <> 0 or (dbo.CheckRC(@rc) <> 0 and @rc <> 95159)        
 begin        
  rollback transaction BatchTxnProcessing        
  return @rc        
 end        
        
 EXEC dbo.TraceProcess @IssNo, @PrcsName, 'Dropping temporary tables'        
        
 drop table #SourceTxn        
 drop index #SourceTxnDetail.IX_SourceTxnDetail        
 drop table #SourceTxnDetail        
        
 if @@ERROR <> 0        
 begin        
  rollback transaction BatchTxnProcessing        
  return 70267 -- Failed to drop temporary table        
 end        
        
 return @rc        
end
GO
