USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardTypeProductPlanMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
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
2009/03/05 Barnett   Initial Development  
2019/03/18 Humairah  Amend Effective date checking for SAVE function
2020/03/09 Chui      Update/Delete based on primary key
2020/03/09 Chui      Mandatory field checking
2020/03/09 Chui      Fix validation and wrong message
*******************************************************************************/  
   
CREATE procedure [dbo].[CardTypeProductPlanMaint]  
	@Func varchar(6),  
	@IssNo uIssNo,  
	@CardType varchar(20),  
	@ProdCd uProdCd,  
	@EffDateFrom datetime,  
	@EffDateTo datetime,  
	@PlanId uPlanId  
    
as  
begin  
  
 declare @PrcsDate datetime
 declare @MaxDate datetime = cast ('2080-12-31' as dateTime) -- default max date time value
     
 select @PrcsDate = CtrlDate from iss_control where CtrlID ='PrcsId'

 if @CardType is null 
	return 55048 -- Card Type is a compulsory field     
	
 if @PlanId is null 
	return 55019 -- Plan Id is a compulsory field
	
 if @EffDateFrom is null 
	return 55091 -- Effective date is a compulsory field

 if @EffDateTo < @EffDateFrom 
	return 95073 -- Wrong entry on effective Starting and Ending Date
    
 if @Func ='Add'  
 begin  
   if @EffDateFrom < convert(varchar(10), @PrcsDate, 112) return 95449 -- Effective Start Date Must Equal to System Process Date 

   if exists (select 1 from itx_CardTypeProductPlan where IssNo = @IssNo and  CardType = @CardType and ProdCd = @ProdCd and EffDateTo is null and EffDateFrom < @EffDateFrom)  
   return 95834  -- Effective From Date Overlapping with another CardType Product Plan
     
   if exists (select 1 from itx_CardTypeProductPlan where IssNo = @IssNo and  CardType = @CardType and ProdCd = @ProdCd and @EffDateFrom between EffDateFrom and EffDateTo)  
   return 95835 -- Effective To Date Overlapping with another CardType Product Plan  

   if exists(select 1 from itx_CardTypeProductPlan where IssNo = @IssNo and  CardType = @CardType and ProdCd = @ProdCd and EffDateFrom = @EffDateFrom)  
   return 65091 -- CardType Product Plan Already Exists.  
     
   ------------------  
   begin transaction  
   ------------------  
   insert itx_CardTypeProductPlan(IssNo,CardType, ProdCd,EffDateFrom,EffDateTo,PlanId)  
   select @IssNo, @CardType, @ProdCd, @EffDateFrom, @EffDateTo, @PlanId  
     
   if @@error <> 0  
   begin  
      
     ---------------------  
     rollback Transaction  
     ---------------------  
     return 71055 -- Fail tp Insert CardType Product Plan  
     
   end

   -----------------------  
   Commit Transaction  
   -----------------------  
   Return 50355 -- Insert CardType Product Plan successfully  
     
 end  
   
   
 if @Func ='Save'  
 begin  
   
   ---- if update effective date, the date must at least = process date   
   --if @EffDateFrom < convert(varchar(10), @PrcsDate, 112)
   --return 95449 -- Effective Start Date Must Equal to System Process Date

   if @EffDateFrom <= convert(varchar(10), @PrcsDate, 112)
   begin 
		if exists(select 1 from itx_CardTypeProductPlan
			where IssNo = @IssNo and  CardType = @CardType and ProdCd = @ProdCd and EffDateFrom = @EffDateFrom
				and PlanId <> @PlanId)
		begin
			return 95836 -- Plan Id Not Allowed to Change. Effective From Date Must More Than System Process Date
		end
   end

   if not exists(select 1 from itx_CardTypeProductPlan
		where IssNo = @IssNo and  CardType = @CardType and ProdCd = @ProdCd and Convert(varchar(8),EffDateFrom,112) = Convert(varchar(8),@EffDateFrom,112))
	return 95838 -- Effective From Date Not Allowed to Change While Updating CardType Product Plan

   if exists (select 1 from itx_CardTypeProductPlan 
		where IssNo = @IssNo and  CardType = @CardType and ProdCd = @ProdCd and Convert(varchar(8),EffDateFrom,112) <> Convert(varchar(8),@EffDateFrom,112)
			and @EffDateTo between EffDateFrom and isnull(EffDateTo,@MaxDate))  
   return 95835 -- Effective To Date Overlapping with another CardType Product Plan

   ------------------  
   begin transaction  
   ------------------  
   update itx_CardTypeProductPlan  
   set  PlanId = @PlanId,  
    EffDateFrom = @EffDateFrom,  
    EffDateTo = isnull(@EffDateTo, @MaxDate)
   where IssNo = @IssNo and  CardType = @CardType and ProdCd = @ProdCd and Convert(varchar(8),EffDateFrom,112) = Convert(varchar(8),@EffDateFrom,112)
    
   if @@error <> 0 or @@rowcount =0  
   begin  
     ---------------------  
     rollback Transaction  
     ---------------------  
     return  71056 -- Fail tp update CardType Product Plan  
   end  
   -----------------------  
   Commit Transaction  
   -----------------------  
   Return  50356 -- Update CardType Product Plan successfully  
 end  
   
 if @Func='Delete'  
 begin 
   
   if not exists(select 1 from itx_CardTypeProductPlan
		where IssNo = @IssNo and  CardType = @CardType and ProdCd = @ProdCd and EffDateFrom = @EffDateFrom)
   return 95839 -- Check invalid effective date

   if @EffDateFrom <= convert(varchar(10), @PrcsDate, 112)
   begin
	return 95837 -- CardType Product Plan Not Allowed To Delete. Effective From Date Must More Than System Process Date
   end 

   ------------------  
   begin transaction  
   ------------------  
    
   delete itx_CardTypeProductPlan  
		where IssNo = @IssNo and CardType = @CardType and ProdCd = @ProdCd and  Convert(varchar(8),EffDateFrom,112) =  Convert(varchar(8),@EffDateFrom,112)
    
   if @@error <> 0 or @@rowcount =0  
   begin  
     ---------------------  
     rollback Transaction  
     ---------------------  
     return 71057 -- Fail tp update CardType Product Plan  
   end  
   -----------------------  
   Commit Transaction  
   -----------------------  
   Return 50357 -- Delete CardType Product Plan successfully  
     
 end  

end
GO
