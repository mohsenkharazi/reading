USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BatchApplicationImport]    Script Date: 9/6/2021 10:33:55 AM ******/
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
20017/02/21 Jasmine   Initial Development  
*******************************************************************************/  
  
--exec BatchApplicationImport 1  
CREATE procedure [dbo].[BatchApplicationImport]  
 @IssNo uIssNo  
as  
BEGIN  
  
  
DECLARE   
@ReturnValue varchar(2),  
@BatchId uBatchId,   
@CBBatchId uBatchId,  
@CBFileName varchar(80),  
  
@RecCnt int,  
@Direction char(1),  
@PrcsId int,  
@HeaderRecStr varchar(MAX)  
   
  
DECLARE batch_cursor CURSOR FOR   
  
select a.BatchId, b.FileName, a.RecCnt, a.Direction, b.RecStr  
from cbf_Batch a (nolock)   
left outer join cbf_Record b (nolock)  on a.FileName = b.FileName AND a.FileId = b.FileId   
where a.sts in ( 'L') AND a.fileId='Application' AND b.RecSeq = 1 AND SUBSTRING(b.RecStr, 1, 1) = 'H';  
  
OPEN batch_cursor  
FETCH NEXT FROM batch_cursor   
INTO @CBBatchId,@CBFileName,@RecCnt,@Direction,@HeaderRecStr;  
WHILE @@FETCH_STATUS = 0  
BEGIN   
      
 exec @BatchId = NextRunNo '1', 'BatchId'  
  
 select @PrcsId = CtrlNo  
 from iss_Control (nolock)   
 where IssNo = @IssNo and CtrlId = 'PrcsId';  
  
 BEGIN TRANSACTION insert_trx_udi_Batch;  
 BEGIN TRY  
  INSERT udi_Batch (  
  IssNo, BatchId, PhyFileName,   
  SrcName,FileName,   
  FileSeq,  
  DestName, FileDate,  
  OrigBatchId, LoadedRec,   
  RecCnt, PrcsRec, Direction, PrcsId,   
  RefNo1, RefNo2, RefNo3, RefNo4, Sts,  
  PlasticType, OperationMode,  
  RefNo5, CardPlan  
  )  
  VAlUES(  
  @IssNo,  
  @BatchId, @CBFileName,   
  'SCANNEW','APPLICATION',  
  RTRIM(SUBSTRING(@HeaderRecStr, 30, 12)), -- 'FileSeq', -- ?  
  RTRIM(SUBSTRING(@HeaderRecStr, 42, 8)), -- 'DestName', -- ?  
  RTRIM(SUBSTRING(@HeaderRecStr, 50, 8)), -- 'FileDate',  
  NULL, @RecCnt,   
  0, NULL, @Direction,@PrcsId,   
  @CBBatchId,   
  NULL, NULL,   
  NULL, 'L',  
  RTRIM(SUBSTRING(@HeaderRecStr, 58, 8)), -- 'PlasticType',   
  RTRIM(SUBSTRING(@HeaderRecStr, 74, 1)), -- 'OperationMode',  
  NULL, RTRIM(SUBSTRING(@HeaderRecStr, 66, 8)) --  'CardPlan'  
  );  
  
  COMMIT TRANSACTION insert_trx_udi_Batch;    
  --select 'OK'  
    
 END TRY  
 BEGIN CATCH  
  SET @ReturnValue = '01'  
  ROLLBACK TRANSACTION insert_trx_udi_Batch;  
  
  --select 'fail'  
 END CATCH  
    
   
   
   
 if @ReturnValue is null   
 BEGIN  
 -- Start Import Record ---------------------------------------------------  
  DECLARE @RecordRecStr varchar(MAX)  
  DECLARE @RecID int  
  
  DECLARE record_cursor CURSOR FOR     
  SELECT b.RecStr, b.Id  
  from cbf_Batch a (nolock)   
  left outer join cbf_Record b(nolock)  on a.FileName = b.FileName AND a.FileId = b.FileId   
  WHERE a.Sts = 'L'  AND a.fileId='Application' AND b.RecSeq <> 1 AND SUBSTRING(b.RecStr, 1, 1) = 'D'  
  AND a.BatchId = @CBBatchId  
  AND a.Filename = @CBFileName   
  ORDER BY b.RecSeq;  
  
  OPEN record_cursor    
  FETCH NEXT FROM record_cursor   
  INTO @RecordRecStr, @RecID;  
    
  WHILE @@FETCH_STATUS = 0    
  BEGIN  
   declare @ReturnValueApp varchar(1)  
  
   BEGIN TRANSACTION insert_trx_udii_Application;  
   BEGIN TRY  
    INSERT udii_Application (  
     BatchId,CardNo,Title,Nationality, NationalityInp,  
     FullName,NewIc,OldIc,  
     Address1,Address2,Address3,  
     City,State,ZipCd,  
     MobileNo,HomeNo,OfficeNo,  
     EmailAddr,DOB,Gender,  
     Race,Language,Communication,  
     Interest,InterestInp,  
     Television,TelevisionInp,  
     Radio,RadioInp,  
     Newspaper,NewspaperInp,  
     OldCardNo,SignDate,Sts, AcctNo, Cvc, EntityId, WebPw, [Option],  
     RdmpItm1, RdmpOty1, RdmpPts1,   
     RdmpItm2, RdmpQty2, RdmpPts2,   
     RdmpItm3, RdmpOty3, RdmpPts3,  
     CardNoChk, NameChk, NationalICChk,   
     GenderChk, EmailChk, AddressChk, ContactChk,   
     IssNo, OriFamilyName, OriNewIc, OriPassportNo , RefNo  
    )  
    Values(  
     @BatchId, RTRIM(SUBSTRING(@RecordRecStr, 12, 17)), -- 'CardNo',   
     RTRIM(SUBSTRING(@RecordRecStr, 29, 20)) , -- 'Title',  
     RTRIM(SUBSTRING(@RecordRecStr, 49, 2)) , -- 'Nationality',   
     RTRIM(SUBSTRING(@RecordRecStr, 51, 25)) , -- 'NationalityInp',  
     RTRIM(SUBSTRING(@RecordRecStr, 76, 50)) , -- 'FullName',  
     RTRIM(SUBSTRING(@RecordRecStr, 126, 14)) , -- 'NewIc',   
     RTRIM(SUBSTRING(@RecordRecStr, 140, 11)) , -- 'OldIc',  
     RTRIM(SUBSTRING(@RecordRecStr, 151, 25)) , -- 'Address1',   
     RTRIM(SUBSTRING(@RecordRecStr, 176, 25)) , -- 'Address2',   
     RTRIM(SUBSTRING(@RecordRecStr, 201, 25)) , -- 'Address3',  
     RTRIM(SUBSTRING(@RecordRecStr, 226, 33)) , -- 'City',   
     RTRIM(SUBSTRING(@RecordRecStr, 259, 2)) , -- 'State',   
     RTRIM(SUBSTRING(@RecordRecStr, 261, 5)) , -- 'ZipCd',  
     RTRIM(SUBSTRING(@RecordRecStr, 266, 15)) , -- 'MobileNo',   
     RTRIM(SUBSTRING(@RecordRecStr, 281, 15)) , -- 'HomeNo',   
     RTRIM(SUBSTRING(@RecordRecStr, 296, 15)) , -- 'OfficeNo',  
     RTRIM(SUBSTRING(@RecordRecStr, 311, 66)) , -- 'EmailAddr',   
     RTRIM(SUBSTRING(@RecordRecStr, 377, 10)) , -- 'DOB',   
     RTRIM(SUBSTRING(@RecordRecStr, 387, 1)) , -- 'Gender',  
     RTRIM(SUBSTRING(@RecordRecStr, 388, 2)) , -- 'Race',   
     RTRIM(SUBSTRING(@RecordRecStr, 390, 14)) , -- 'Language',   
     RTRIM(SUBSTRING(@RecordRecStr, 404, 14)) , -- 'Communication',  
     RTRIM(SUBSTRING(@RecordRecStr, 418, 35)) , -- 'Interest',   
     RTRIM(SUBSTRING(@RecordRecStr, 453, 25)) , -- 'InterestInp',  
     RTRIM(SUBSTRING(@RecordRecStr, 478, 35)) , -- 'Television',   
     RTRIM(SUBSTRING(@RecordRecStr, 513, 25)) , -- 'TelevisionInp',  
     RTRIM(SUBSTRING(@RecordRecStr, 538, 35)) , -- 'Radio',   
     RTRIM(SUBSTRING(@RecordRecStr, 573, 25)) , -- 'RadioInp',  
     RTRIM(SUBSTRING(@RecordRecStr, 598, 35)) , -- 'Newspaper',   
     RTRIM(SUBSTRING(@RecordRecStr, 633, 25)) , -- 'NewspaperInp',  
     NULL,   
     RTRIM(SUBSTRING(@RecordRecStr, 658, 10)) , -- 'SignDate',   
     'L', --Sts  
     NULL, NULL, NULL, NULL, NULL,  
     NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,  
     NULL, NULL, NULL, NULL, NULL, NULL, NULL,   
     @IssNo,   
     NULL, NULL, NULL, @RecID  
    );  
  
  
      
    COMMIT TRANSACTION insert_trx_udii_Application;    
  
    SET @ReturnValueApp ='S';  
    --select 'S'  
   END TRY  
   BEGIN CATCH  
    ROLLBACK TRANSACTION insert_trx_udii_Application;  
  
    SET @ReturnValueApp ='F';  
    SET @ReturnValue = '02'  
    --select 'F'  
   END CATCH;  
  
   if @ReturnValueApp='S'  
   BEGIN  
    UPDATE cbf_Record set Sts ='P' where id= @RecID;  
   END  
   else  
   BEGIN  
    UPDATE cbf_Record set Sts ='F' where id= @RecID;  
   END  
  
  
   FETCH NEXT FROM record_cursor   
   INTO @RecordRecStr,@RecID  
  END  
    
  
  CLOSE record_cursor    
  DEALLOCATE record_cursor    
  -- Finish Import Record ---------------------------------------------------  
  
    
  IF @ReturnValue is null   
  BEGIN   
   update cbf_Batch set Sts = 'P'  
   where BatchId = @CBBatchId AND Filename = @CBFileName ;  
  END   
  ELSE  
  BEGIN  
   update cbf_Batch set Sts = 'F'   
   where BatchId = @CBBatchId AND Filename = @CBFileName  ;  
  END  
    
  
  
 END  
   
   
   
 FETCH NEXT FROM batch_cursor   
 INTO @CBBatchId,@CBFileName,@RecCnt,@Direction,@HeaderRecStr;  
  
END   
  
  
CLOSE batch_cursor  
DEALLOCATE batch_cursor  
  
  
END
GO
