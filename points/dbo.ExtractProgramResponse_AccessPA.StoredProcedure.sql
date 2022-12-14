USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ExtractProgramResponse_AccessPA]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
      
/*************************************************************************************************************************          
          
Copyright : CardTrend Systems Sdn. Bhd.          
Modular  : CardTrend Card Management System (CCMS)- Issuing Module          
          
Objective : This stored procedure is to extract Progra response       
          
SP Level : Primary          
          
Calling By :           
          
--------------------------------------------------------------------------------------------------------------------------          
When    Who  CRN  Desc          
--------------------------------------------------------------------------------------------------------------------------          
2018/10/07 Humairah			Initial development        
**************************************************************************************************************************/          
--declare @RC int           
--exec @Rc =  ExtractProgramResponse_AccessPA 1,NULL          
--select @RC          
CREATE PROCEDURE [dbo].[ExtractProgramResponse_AccessPA]          
 @IssNo uIssNo,          
 @PrcsId uPrcsId          
as          
--with encryption as          
begin          
 declare          
  @rc int,          
  @Cnt int,          
  @PrcsDate datetime,          
  @PrcsName varchar(50),          
  @FileSeq int,          
  @ContentSts urefcd,          
  @ContentType urefcd,          
  @LangInd uRefcd          
          
 SET NOCOUNT ON          
           
 --------------------------------------------------------------------------------------------------------------------          
 --------------------------------- RETRIEVES NECESSARY INFORMATION FOR PROCESSING -----------------------------------          
 --------------------------------------------------------------------------------------------------------------------          
          
 -- Retrieve Billing Settings --------------------------------------------------------------------------------------          
          
 if @PrcsId is null          
 begin          
  select @PrcsId = CtrlNo, @PrcsDate = CtrlDate          
  from iss_Control (nolock)          
  where IssNo = @IssNo and CtrlId = 'PrcsId'          
 end          
 else           
 begin          
  select @PrcsDate = PrcsDate from cmnv_ProcessLog (nolock) where PrcsId = @PrcsId          
 end          
           
 if not exists (select top 1 1 from udi_Batch (nolock)           
     where FileName = 'PROGRAM' and PrcsId=  @PrcsId and RefNo3 = 2 and Sts in ('P','D'))           
  begin          
   return 60086--No Record Found          
  end          
  else          
  begin          
   select @FileSeq = max(fileseq)  + 1 from udi_Batch (nolock) where FileName = 'PROGRAM'           
  end           
           
 select @ContentSts = RefCd  from iss_reflib (nolock) where RefType = 'ContentSts' and Descp = 'Active'            
 select @ContentType = RefCd  from iss_reflib (nolock) where RefType = 'ContentType' and Descp = 'SMS'            
 select @LangInd = RefCd   from iss_reflib (nolock) where reftype  = 'Language'  and RefNo = 2           
          
 truncate table udie_ProgramSpendingExtraction          
 --------------------------------------------------------------------------------------------------------------------          
 -------------------------------------------- CREATE TEMPORARY TABLES -----------------------------------------------          
 --------------------------------------------------------------------------------------------------------------------          
 select 'H,Result,PETRONAS,'+ cast(format (@PrcsDate,'yyyy') as varchar(4)) + cast( format (@PrcsDate,'MM') as varchar(2))          
          
 union all          
          
 select 'D'           
   +',' + cast( ROW_NUMBER() over (order by a.AcctNo) as varchar(4))       
   +','+ isnull(a.Name,'')              
   +','+ isnull(cast(a.CardNo as nvarchar),'')   
   +','+ cast(a.IdType as nvarchar(4))          
   +','+ cast(isnull(a.IdNumber,'') as nvarchar(30))          
   +','+ a.Eligibility        
   +','+ a.SubscriptionDate        
 from udie_ProgramTxnSummary a (nolock)    
 where a.PrcsId = @PrcsId            
           
 union all          
          
 select 'T,' + cast( dbo.PadLeft(0,10, count(1)) as varchar(10)) from udie_ProgramTxnSummary a (nolock)    where a.PrcsId = @PrcsId                 
          
end
GO
