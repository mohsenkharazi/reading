USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardTypeTxnPlanMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:

Objective	:

-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2009/03/05	Barnett				Initial Development
*******************************************************************************/
	
CREATE procedure [dbo].[CardTypeTxnPlanMaint]
	@Func varchar(6),
	@IssNo uIssNo,
	@CardType varchar(20),
	@TxnCd uTxnCd,
	@EffDateFrom datetime,
	@EffDateTo datetime,
	@PlanId uPlanId
   
as
begin

	declare @PrcsDate datetime

	select @PrcsDate = CtrlDate from iss_control where CtrlID ='PrcsId'

	if @EffDateFrom < convert(varchar(10), @PrcsDate, 112) return 95449 -- Effective Start Date Must Equal to System Process Date


	if @Func ='Add'
	begin
	
			if exists (select 1 from itx_CardTypeTxnPlan where IssNo = @IssNo and  CardType = @CardType and TxnCd = @TxnCd and EffDateTo is null and EffDateFrom < @EffDateFrom)
			return 95448  -- Effective Date Overlapping with another CardType Product Plan
			
			if exists (select 1 from itx_CardTypeTxnPlan where IssNo = @IssNo and  CardType = @CardType and TxnCd = @TxnCd and @EffDateFrom between EffDateFrom and EffDateTo)
			return 95448 -- Effective Date Overlapping with another CardType Product Plan
		
	
			if exists(select 1 from itx_CardTypeTxnPlan where IssNo = @IssNo and  CardType = @CardType and TxnCd = @TxnCd and EffDateFrom = @EffDateFrom)
			return 65090 -- CardType Txn Plan Already Exists.
	
			------------------
			begin transaction
			------------------

			insert itx_CardTypeTxnPlan(IssNo,CardType,TxnCd,EffDateFrom,EffDateTo,PlanId)
			select @IssNo, @CardType, @TxnCd, @EffDateFrom, @EffDateTo, @PlanId
			
			if @@error <> 0
			begin
				
				 ---------------------
				 rollback Transaction
				 ---------------------
				 return 71052 -- Fail tp Insert CardType Txn Plan
			
			end	
			
			
			-----------------------
			Commit Transaction
			-----------------------
			Return 50352 -- Insert CardType Txn Plan successfully
			
	end
	
	
	if @Func ='Save'
	begin
	
			------------------
			begin transaction
			------------------
		
			update itx_CardTypeTxnPlan
			set  PlanId = @PlanId,
				EffDateFrom = @EffDateFrom,
				EffDateTo = @EffDateTo
			where IssNo = @IssNo and  CardType = @CardType and TxnCd = @TxnCd
		
			if @@error <> 0 or @@rowcount =0
			begin
				 ---------------------
				 rollback Transaction
				 ---------------------
				 return  71053 -- Fail tp update CardType Txn Plan
			end
			-----------------------
			Commit Transaction
			-----------------------
			Return  50353 -- Update CardType Txn Plan successfully
	end
	
	if @Func='Delete'
	begin
			------------------
			begin transaction
			------------------
		
			delete itx_CardTypeTxnPlan
			where IssNo = @IssNo and  CardType = @CardType and TxnCd = @TxnCd
		
			if @@error <> 0 or @@rowcount =0
			begin
				 ---------------------
				 rollback Transaction
				 ---------------------
				 return 71054 -- Fail tp update CardType Txn Plan
			end
			-----------------------
			Commit Transaction
			-----------------------
			Return 50354 -- Delete CardType Txn Plan successfully
			
	end
	

end
GO
