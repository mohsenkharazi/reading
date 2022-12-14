USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchDataExport]    Script Date: 9/6/2021 10:33:55 AM ******/
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
2007/06/01 Barnett    Initial Development  
2014/04/21 Humairah   Change Filename format  
*******************************************************************************/  
/*  
DECLARE @OUT varchar(200)   
EXEC MerchDataExport 1008820, @OUT output  
select @OUT  
*/  
CREATE Procedure[dbo].[MerchDataExport]  
 @BatchId uBatchId    
as  
begin  
 truncate table temp_DataExtraction  
  
 declare @TSql varchar(1000), @Path varchar(50), @Sts varchar(2),  
   @Min bigint, @PrevSeqNo bigint, @Plastic varchar(30), @PrcsDate varchar(10),  
   @OperationMode char(10), @FileSeq int, @FileName varchar(50), @FileExt varchar(10),  
   @PlasticType uPlasticType, @CardPlan varchar(10), @RecCnt int, @Max bigint, @SrcName varchar(50),  
   @SrcFileName varchar(20), @FileDate datetime, @DestName varchar(20), @RowCount bigint  
     
 declare @CreateTable varchar(300), @Header varchar(100), @MySpecialTempTable varchar(100),  
   @Detail varchar(MAX), @Trailer varchar(100), @Command varchar(500), @Unicode int, @RESULT int  
  
 set nocount on  
 set dateformat ymd  
  
 select  @Unicode=0, @MySpecialTempTable ='temp_DataExtraction'  
  
 select @PrcsDate = convert(varchar(10),getdate(),112)  
 select @RecCnt = 0  
  
 select @Path = VarcharVal  
 from iss_Default   
 where Deft = 'DeftDataExtractFilePath'  
  
  
 if @Path is null   
  select @Path = 'D:\'   
  
  
 select @Min = min(SeqNo), @Max = Max(SeqNo) + 1  
 from udiE_merch (nolock)  
 where BatchId = @BatchId   
  
  
 select @BatchId = cast(BatchId as varchar(8))  
 from udiE_merch (nolock)  
 where BatchId = @BatchId and SeqNo = @Min  
  
   
 -- Contruct file name  
 select @FileSeq = FileSeq, @OperationMode = cast(isnull(OperationMode, 'N') as char(1)), -- Default set to status New = (GhostCardGen)  
   @RecCnt = RecCnt +1, @SrcName = SrcName, @SrcFileName = FileName, @FileDate = FileDate, @DestName = DestName  
 from udi_Batch (nolock)   
 where BatchId = @BatchId   
  
   
  
 -- Create Header Record  
 select @TSql = 'H' +  -- Header (1)  
      dbo.PadRight(' ', 8, @SrcName) +  
      dbo.PadRight(' ', 20, @SrcFileName) +  
      dbo.PadLeft('0', 12, @FileSeq) +  
      dbo.PadRight(' ', 8, @DestName) +  
      dbo.PadLeft(' ', 8, convert(varchar(8), @FileDate, 112))   
   
 insert temp_DataExtraction (String)  
 select @TSql  
  
 -- insert Detail  
 insert Temp_DataExtraction (String)  
 select 'D'+  -- Detail(1)  
  dbo.PadLeft('0', 8, SeqNo) + --RecSeq(8),  
  dbo.PadLeft(' ', 15, BusnLocation) + -- BusnLocation (15)  
  dbo.PadRight(' ', 50, substring(BusnName, 1, len(BusnName))) + -- BusnName(50),  
  dbo.PadRight(' ', 16, substring(PartnerRefNo, 1, len(PartnerRefNo))) + -- SiteId (16)  
  dbo.PadRight(' ', 100, substring(Street1, 1, len(Street1))) + -- Street1 (100)  
  dbo.PadRight(' ', 50, substring(Street2, 1, len(Street2))) + -- Street2 (50)  
  dbo.PadRight(' ', 50, substring(Street3, 1, len(Street3))) + -- Street3 (50)  
  dbo.PadRight(' ', 50, isnull(State, '')) + -- State (50)  
  dbo.PadRight(' ', 5, substring(ZipCd, 1, len(ZipCd))) + -- ZipCd (5)  
  dbo.PadRight(' ', 1, Sts) -- Sts (2)  
 from udiE_merch  
 order by SeqNo  
     
  
 select @RowCount = count(String) from temp_DataExtraction  
  
 --insert trailer  
 select @TSql = 'T' + -- Trailer (1)  
     dbo.PadLeft('0', 6, @RowCount)  
 from temp_DataExtraction  
   
  
 insert temp_DataExtraction (String)  
 select @TSql  
   
  
  
 select String from  temp_DataExtraction order by SeqNo  
  
   
  
end
GO
