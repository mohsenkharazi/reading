USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchantSourceTransactionProcessId_Update]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*************************************************************************************************************************  
  
Copyright : CardTrend Systems Sdn. Bhd.  
Modular  : CardTrend Card Management System (CCMS)- Issuing Module  
  
Objective : This stored procedure is to update the Process Id  for the leftover transaction (transaction sync from iAuth to LMS after EOD executed).   
  
SP Level : Primary  
  
Calling By :   
  
--------------------------------------------------------------------------------------------------------------------------  
When    Who  CRN  Desc  
--------------------------------------------------------------------------------------------------------------------------  
2017/11/08 Chui  Initial development  
**************************************************************************************************************************/  
--exec MerchantSourceTransactionProcessId_Update 1  
  
CREATE  procedure [dbo].[MerchantSourceTransactionProcessId_Update]  
 @AcqNo INT  
AS   
BEGIN  
  
 SET @AcqNo = ISNULL(@AcqNo,1);  
  
 DECLARE @CurrentProcessId BIGINT;  
 DECLARE @PreviousProcessId BIGINT;  
 DECLARE @ActiveSts VARCHAR(2) = 'A';  
 DECLARE @UserId VARCHAR(8) =  'lmsiAuth';  
 DECLARE @Threshold INT = 2000;  
  
 SELECT @CurrentProcessId = CAST (CtrlNo AS BIGINT),  
  @PreviousProcessId = CAST (CtrlNo AS BIGINT) - 1  
 FROM iss_Control (NOLOCK) WHERE CtrlId = 'PrcsId'  
  
  
 SELECT Ids, BatchId  
 INTO #BatchSettlement  
 FROM atx_SourceSettlement  
  WHERE UserId = @UserId  
   AND PrcsId in ( @PreviousProcessId, 0)
   AND AcqNo = @AcqNo  
   AND Sts = @ActiveSts  
  
  
 DELETE b   
 FROM atx_SourceTxn a (NOLOCK)  
   INNER JOIN #BatchSettlement b  
  ON a.BatchId = b.BatchId  
   AND a.SrcIds = b.Ids  
  WHERE a.UserId = @UserId  
   AND a.PrcsId in (@PreviousProcessId, 0) 
   AND a.AcqNo = @AcqNo  
   AND a.Sts <> @ActiveSts  
   
 BEGIN  
  UPDATE a  
   SET PrcsId = @CurrentProcessId  
   FROM atx_SourceTxn a  
    INNER JOIN #BatchSettlement b  
     ON a.BatchId = b.BatchId  
      AND a.SrcIds = b.Ids  
   
  UPDATE  atx_SourceSettlement   
   SET PrcsId = @CurrentProcessId  
    WHERE UserId = @UserId  
    AND PrcsId = @PreviousProcessId  
    AND AcqNo = @AcqNo  
    AND Sts = @ActiveSts  
 END  
  
END  
GO
