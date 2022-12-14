USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[FraudTxnAcctControl]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
  
/******************************************************************************  
Copyright :CardTrend Systems Sdn. Bhd.  
Modular  :  
  
Objective :  
  
-------------------------------------------------------------------------------  
When  Who  CRN  Description  
-------------------------------------------------------------------------------  
2007/06/01 Barnett   Initial Development  
2010/08/01 Barnett   Daily Change Card From active / Block to Suspend  
       where 5/Same PSS/ Same Card/ same day/ same Amount  
2019/07/26  Azan   Perform fraud checking on issued cards in aswell   
2019/08/16  Azan    Rework on SP for CR : MYPDBLCR-43   
2019/09/03  Azan   Exclude Points Conversion from daily total sales checking      
*******************************************************************************/  
/*  
declare @rc int   
exec @rc = FraudTxnAcctControl 1,3631,'D'  
select @rc  
*/  
  
CREATE PROCEDURE [dbo].[FraudTxnAcctControl]   
  @IssNo uIssNo,  
  @PrcsId uPrcsId = null,  
  @CheckMode varchar(1)  
as  
begin   
    declare @PurchTxnCategory int, @CheckVal int, @CheckTxnCnt int,  
   @MaxIds int, @PrcsDate datetime  
  
 create table #FinalList(CardNo bigint, Cnt int, Amt money, Rule1 int,Rule2 int,Rule3 int, AcctNo bigint, PrevCardSts nvarchar(50))  
 create table #OverCnt(CardNo bigint, Cnt int, Amt money, Rule1 int,Rule2 int,Rule3 int, PrevCardSts nvarchar(50))  
 create table #OverAmt(CardNo bigint, Cnt int, Amt money, Rule1 int,Rule2 int,Rule3 int, PrevCardSts nvarchar(50))  
  
 select @PurchTxnCategory = IntVal   
 from iss_Default   
 where DEft ='PurchTxnCategory'  
  
 select @CheckVal = IntVal   
 from iss_Default (nolock)  
 where Deft = 'DailyCheckVal' and IssNo = @IssNo  
   
 select @CheckTxnCnt = IntVal   
 from iss_Default (nolock)  
 where Deft = 'DailyCheckTxnCnt' and IssNo = @IssNo  
  
 if @Prcsid is null  
 begin   
  select  
   @Prcsid = CtrlNo,   
   @PrcsDate = CtrlDate   
  from iss_control (nolock)   
  where CtrlId = 'PrcsId'   
 end  
 else  
 begin   
  select   
   @PrcsDate = CtrlDate   
  from iss_control (nolock)   
  where CtrlId = 'PrcsId'   
 end  
  
 -----------------  
 BEGIN TRANSACTION   
 -----------------  
   
 if @CheckMode ='D' -- Daily Process.  
 begin   
  -- Begin Exclude Smartpay Account  
  
  insert into iac_Event (IssNo, EventType, AcctNo, CardNo, ReasonCd, Descp,   
   Priority, CreatedBy, AssignTo, XRefDoc, CreationDate, SysInd, Sts)  
  select distinct @IssNo, 'ChgSts', c.AcctNo, c.CardNo, 'FCMI', 'Card Change Status To Active: Smartpay Customer',  
   'L', system_user, null, null, getdate(), 'Y', 'C'  
  from itx_Txn a (nolock)  
  join iss_PaymentCardPrefix b (nolock) on b.CardPrefix = substring(PaymtCardPrefix, 1, 6) and b.FraudCtrlInd ='N' and b.IssNo = @IssNo  
  join iac_Card c (nolock) on c.CardNo = a.CardNo and c.IssNo = @IssNo   
  join iac_Entity d (nolock) on d.EntityId = c.EntityId and len(isnull(d.FamilyName, '')) > 2 and ( (isnumeric(isnull(d.NewIC,''))>0 and len(isnull(d.NewIc,'')) = 12) or (len(isnull(d.PassportNo,0))>5 ))  
  where a.PrcsId = @PrcsId and ((c.STs ='A' and c.CardChkInd =1) or (c.STs ='F' and c.CardChkInd =1) or (c.STs ='F' and c.CardChkInd =0))  
     
  if @@error <>0  
  begin  
    Rollback Transaction  
    return 70194 -- Failed to create event  
  end   
  
  insert iss_TxnCardWithPaymtCardList (CardNo, PrcsId, PaymtCardPrefix, PrcsDate)  
  select distinct c.CardNo, @PrcsId, b.CardPrefix, @PrcsDate  
  from itx_Txn a (nolock)  
  join iss_PaymentCardPrefix b (nolock) on b.CardPrefix = substring(PaymtCardPrefix, 1, 6) and b.FraudCtrlInd ='N' and b.IssNo = @IssNo  
  join iac_Card c (nolock) on c.CardNo = a.CardNo and c.IssNo = @IssNo   
  join iac_Entity d (nolock) on d.EntityId = c.EntityId   
  where a.PrcsId = @PrcsId and ((c.STs ='A' and c.CardChkInd =1) or (c.STs ='F' and c.CardChkInd =1) or (c.STs ='F' and c.CardChkInd =0))  
     
  if @@error <> 0  
  begin  
    Rollback Transaction  
    return 70194 -- Failed to create event  
  end   
   
  update c  
  set CardChkInd = Case  
       when c.CardChkInd > 0 and c.Sts in('A','B','F') then 0  
       else c.CardChkInd  
      end,  
   Sts = Case   
      when c.Sts ='F' and len(isnull(d.FamilyName, '')) > 2 and ( (isnumeric(isnull(d.NewIC,''))>0 and len(isnull(d.NewIc,'')) = 12) or (len(isnull(d.PassportNo,0))>5 )) then 'A'  
      else c.Sts  
     end  
  from itx_Txn a (nolock)  
  join iss_PaymentCardPrefix b (nolock) on b.CardPrefix = substring(PaymtCardPrefix, 1, 6) and b.FraudCtrlInd ='N' and b.IssNo = @IssNo  
  join iac_card c (nolock) on c.CardNo = a.CardNo and c.IssNo = @IssNo   
  join iac_Entity d (nolock) on d.EntityId = c.EntityId  
  where a.PrcsId = @PrcsId  
       
  if @@error <> 0  
  begin  
    Rollback Transaction  
    return 70363 -- Failed to update Card Status  
  end   
  
  --End Exclude Smartpay Account  
  
  --Begin daily check for Rule 1 and 2  
   
  select @CheckVal = IntVal   
  from iss_Default (nolock)  
  where Deft = 'DailyCheckVal' and IssNo = @IssNo  
    
  select @CheckTxnCnt = IntVal   
  from iss_Default (nolock)  
  where Deft = 'DailyCheckTxnCnt' and IssNo = @IssNo  
  
  insert #OverCnt (CardnO, Cnt, Amt, Rule1, Rule2, Rule3, PrevCardSts)  
  select a.CardNo, Count(a.CardNo)'Count', 0 as 'Amt', 1 as 'Rule1', 0 as 'Rule2', 0 as 'Rule3', e.Descp  
  from Itx_Txn a (nolock)  
  join itx_TxnCode b (nolock) on b.TxnCd = a.TxnCd and b.TxnCd not in (214,215,217,218)  
  join itx_TxnCategory c (nolock) on  c.Category = b.Category and c.Category = @PurchTxnCategory  
  join iac_card d (nolock) on d.CardNo = a.CardNo  and d.CardChkInd = 1  
  join iss_Reflib e (nolock) on e.RefType='CardSts' and e.RefCd = d.Sts and e.RefCd in ('A','P')  
  where a.Prcsid=@Prcsid  
  group by a.CardNo,  Convert(varchar(10), a.TxnDate, 112), e.Descp  
  having Count(a.CardNo)> @CheckTxnCnt  
  
  insert #OverAmt (CardnO, Cnt, Amt, Rule1, Rule2, Rule3, PrevCardSts)  
  select a.CardNo, 0 as 'Count', SettleTxnAmt 'Amt', 0 as 'Rule1', 1 as 'Rule2', 0 as 'Rule3', e.Descp  
  from Itx_Txn a (nolock)  
  join itx_TxnCode b (nolock) on b.TxnCd = a.TxnCd and b.TxnCd not in (214,215,217,218)  
  join itx_TxnCategory c (nolock) on c.Category = b.Category and c.Category =  @PurchTxnCategory  
  join iac_card d (nolock) on d.CardNo = a.CardNo  and d.CardChkInd = 1  
  join iss_Reflib e (nolock) on e.RefType='CardSts' and e.RefCd = d.Sts and e.RefCd in ('A','P')  
  where a.SettleTxnAmt > @CheckVal and a.PrcsId = @PrcsId   
  
  insert #FinalList (CardnO, Cnt, Amt, Rule1, Rule2, Rule3, AcctNo, PrevCardSts)  
  select a.CardnO, sum(a.Cnt), sum(a.Amt), sum(a.Rule1), sum(a.Rule2), 0, b.AcctNo, a.PrevCardSts from  
  (  
   select * from  #OverCnt  
   union  
   select * from #OverAmt   
  ) a  
  join iac_card b on a.CardNo = b.CardNo  
  group by a.CardNo, b.AcctNo,a.PrevCardSts   
  
  --End daily check for Rule 1 and 2  
 end  
  
 if @CheckMode ='M' -- Monthly  
 begin  
  declare @Year int, @Month int  
  
  select @CheckVal = IntVal   
  from iss_Default (nolock)  
  where Deft = 'MonthlyCheckVal' and IssNo = @IssNo  
  
  select  @Year = datepart(yy, PrcsDate), @Month = datepart(mm, PrcsDate)    
  from cmnv_Processlog where PrcsId = @PrcsId  
  
  insert #FinalList (CardnO, Cnt, Amt, Rule1, Rule2, Rule3, AcctNo, PrevCardSts)  
  select a.CardNo, null, sum(SettleTxnAmt) 'Amt', 0 , 0 , 1 , d.AcctNo, e.Descp   
  from Itx_Txn a (nolock)  
  join itx_TxnCode b (nolock) on b.TxnCd = a.TxnCd and b.TxnCd not in (214,215,217,218)  
  join itx_TxnCategory c (nolock) on c.Category = b.Category and c.Category =  @PurchTxnCategory  
  join iac_card d (nolock) on d.CardNo = a.CardNo  and d.CardChkInd = 1  
  join iss_Reflib e (nolock) on e.RefType='CardSts' and e.RefCd = d.Sts and e.RefCd in ('A','P')  
  where datepart(mm, a.TxnDate) = @Month and  datepart(yy, a.TxnDate) = @Year  
  group by a.CArdNo, d.AcctNo, e.Descp  
  having Sum(SettleTxnAmt)>@CheckVal  
 end  
  
 insert udii_FraudCardList (CardNo, PrcsId, Rule1, Rule2, Rule3, CheckMode, PrevCardSts)  
 select distinct CardNo, @PrcsId,   
    case   
     when Rule1>0 then 1   
     else Rule1   
    end,   
    case   
     when Rule2>0 then 1   
     else Rule2   
    end,  
    case   
     when Rule3>0 then 1   
     else Rule3   
    end,  
   @CHeckMode, PrevCardSts  
 from #FinalList a  
  
   
 select b.AcctNo, a.CardNo, sum(isnull(Rule1, 0)) 'Rule1', sum(isnull(Rule2, 0)) 'Rule2', sum(isnull(Rule3, 0))'Rule3', a.PrevCardSts  
 into #FraudCardList   
 from udii_FraudCardList a (nolock)  
 join iac_card b (nolock) on b.cardno = a.CardNo and b.CardChkInd =1  
 join iss_Reflib c (nolock) on c.RefType='CardSts' and c.RefCd = b.Sts and c.RefCd in ('A','P')  
 where a.PrcsId = @PrcsId  
 group by b.AcctNo, a.CardNo, a.PrevCardSts  
  
 if @@error <>0  
 begin  
   Rollback Transaction  
   return 70194 -- Failed to create event  
 end   
  
 update a   
  set a.Sts = 'F'  
 from iac_Card a (nolock)   
 join #FraudCardList b (nolock) on a.CardNo = b.CardNo   
  
 if @@error <>0  
 begin  
   Rollback Transaction  
   return 70363 -- Failed to update Card Status  
 end   
  
 insert into iac_Event (IssNo, EventType, AcctNo, CardNo, ReasonCd, Descp, Priority, CreatedBy, AssignTo, XRefDoc, CreationDate, SysInd, Sts)  
 select @IssNo, 'ChgSts', a.AcctNo, a.CardNo, 'FRUD', 'Card Change Status from '+a.PrevCardSts+' to Fraud Block : Suspicious Fraud'+ CASE WHEN a.Rule1 > 0 THEN ' R1' WHEN a.Rule2 > 0 THEN ' R2' WHEN a.Rule3 > 0 THEN ' R3' END,  
 'L', system_user, null, null, getdate(), 'Y', 'C'  
 from #FraudCardList a (nolock)   
  
 if @@error <>0  
 begin  
   Rollback Transaction  
   return 70194 -- Failed to create event  
 end   
   
 drop table #FinalList  
 drop table #OverAmt  
 drop table #OverCnt  
 drop table #FraudCardList  
   
 ------------------  
 COMMIT TRANSACTION  
 ------------------   
end
GO
