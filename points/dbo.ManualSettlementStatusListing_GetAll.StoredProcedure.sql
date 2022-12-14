USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ManualSettlementStatusListing_GetAll]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
  
CREATE procedure [dbo].[ManualSettlementStatusListing_GetAll]  
  
@IssNo uIssNo 
  
AS BEGIN  
  
IF exists (select 1 from dbo.iss_RefLib (nolock) where RefType in ('MerchBatchSts') AND IssNo = @IssNo)  
 BEGIN  
  SELECT refCd As code,Descp    
  from dbo.iss_RefLib (nolock) 
  where RefType in ('MerchBatchSts') 
  AND IssNo = @IssNo
    
 END  
Return 60027 /*Issuer not found */  
END  

GO
