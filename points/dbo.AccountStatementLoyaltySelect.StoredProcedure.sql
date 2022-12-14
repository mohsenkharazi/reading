USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AccountStatementLoyaltySelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
/*****************************************************************************************************************
 
Copyright : CardTrend Systems Sdn. Bhd.
Modular  : CardTrend Card Management System (CCMS)- Issuing Module
 
Objective : Select Statement info
 
SP Level : Primary
------------------------------------------------------------------------------------------------------------------
When    Who  CRN    Desc
------------------------------------------------------------------------------------------------------------------
2002/01/07 Jacky     Initial development
2009/04/20 Barnett   Abs the Redem Amt, only for PDB
******************************************************************************************************************/
 
CREATE procedure [dbo].[AccountStatementLoyaltySelect]
 @AcctNo uAcctNo,
 @StmtId int
  as
begin
 declare @PrcsName varchar(50),
  @Msg nvarchar(80),
  @IssNo uIssNo,
  @PtsIssueTxnCategory int,
  @RdmpTxnCategory int,
  @AdjustTxnCategory int,
  @ExpiredTxnCategory int,
  @PtsIssued money,
  @PtsRdm money,
  @PtsAdj money,
  @PtsExpired money
 
 select @PrcsName = 'AccountStatementLoyaltySelect'
 
 if @StmtId = 0
 begin
  select @IssNo = IssNo from iac_Account (nolock) where AcctNo = @AcctNo
 
  select @PtsIssueTxnCategory = IntVal
  from iss_Default (nolock)
  where IssNo = @IssNo and Deft = 'PtsIssueTxnCategory'
 
  select @RdmpTxnCategory = IntVal
  from iss_Default (nolock)
  where IssNo = @IssNo and Deft = 'RdmpTxnCategory'
 
  select @AdjustTxnCategory = IntVal
  from iss_Default (nolock)
  where IssNo = @IssNo and Deft = 'AdjustTxnCategory'
 
  select @ExpiredTxnCategory = IntVal
  from iss_Default (nolock)
  where IssNo = @IssNo and Deft = 'ExpiredTxnCategory'
 
  -- Points Issued
  select @PtsIssued = b.DebitPts + b.VoidDebitPts + b.CreditPts + b.VoidCreditPts
  from iac_Points b (nolock)
  where b.AcctNo = @AcctNo and b.CycId = @StmtId and b.Category = @PtsIssueTxnCategory
 
  -- Points Redeemed
  select @PtsRdm = b.CreditPts
  from iac_Points b (nolock)
  where b.AcctNo = @AcctNo and b.CycId = @StmtId and b.Category = @RdmpTxnCategory
 
  -- Points Adjusted
  select @PtsAdj = b.DebitPts + b.VoidDebitPts + b.CreditPts + b.VoidCreditPts
  from iac_Points b (nolock)
  where b.AcctNo = @AcctNo and b.CycId = @StmtId and b.Category = @AdjustTxnCategory
 
  -- Update Total Points Expired
  select @PtsExpired = b.DebitPts + b.VoidDebitPts + b.CreditPts + b.VoidCreditPts
  from iac_Points b (nolock)
  where b.AcctNo = @AcctNo and b.CycId = @StmtId and b.Category = @ExpiredTxnCategory
 
  if exists (select 1 from iac_AccountStatement where AcctNo = @AcctNo)
  begin
   select a.ClsPts 'OpnPts', b.AccumAgeingPts 'ClsPts',
    @PtsIssued 'PtsIssued', abs(@PtsRdm) 'PtsRdm', @PtsAdj 'PtsAdj', @PtsExpired 'PtsExpired'
   from iac_AccountStatement a (nolock)
   join (
     select b1.* from iac_AccountFinInfo b1 (nolock)
     where b1.AcctNo = @AcctNo) b on a.AcctNo = b.AcctNo
   where a.AcctNo = @AcctNo and a.StmtId = isnull((select max(StmtId)
         from iac_AccountStatement (nolock)
         where AcctNo = @AcctNo), 0)
   and b.AcctNo = a.AcctNo
  end
  else
  begin
   select cast(0 as money) 'OpnPts', AccumAgeingPts 'ClsPts',
    @PtsIssued 'PtsIssued', abs(@PtsRdm) 'PtsRdm', @PtsAdj 'PtsAdj', @PtsExpired 'PtsExpired'
   from iac_AccountFinInfo (nolock)
   where AcctNo = @AcctNo
  end
 end
 else
 begin
  select OpnPts, ClsPts, PtsIssued, PtsRdm, PtsAdj, PtsExpired
  from iac_AccountStatement (nolock)
  where AcctNo = @AcctNo and StmtId = @StmtId
 end
 
end
GO
