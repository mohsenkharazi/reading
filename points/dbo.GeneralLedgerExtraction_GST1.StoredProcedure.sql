USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GeneralLedgerExtraction_GST1]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*************************************************************************************************************************
Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure is to 

SP Level	: Primary

Calling By	: 

--------------------------------------------------------------------------------------------------------------------------
When	   Who		CRN		Desc
--------------------------------------------------------------------------------------------------------------------------
2009/03/16 Chew Pei			Initial Development
2009/08/25 Chew Pei			Enhancement. All parameter can be set front end. 
							And extraction will be based on the parameter set.
2009/10/05 Chew Pei			Added @Rc count to put in udi_Batch..RecCnt
2013/03/26 Barnett			Excluded the Pts Conversion Txn from Settlement summary -- Tune Big Digital
2015/02/25 Humairah			Add Busn Location in UdiE_GLTxn and UdiE_GLTxnSummary for GST 
2015/03/23 Humairah			GST : Self Billing 
2015/05/11 Humairah			GST : Fix VAT Amount calculation
2015/05/25 Humairah			Fix Amount of Pts Issuance (Calculation) and remove -ve sign
2015/05/27 Humairah			GST enhancement : TxnCd 402 not to locate at post GST GL File
2015/06/30 Humairah			Include transaction for Replacement Fee,Pts Cancellation & Pts Expiry
2017/01/13 Humairah			GL extraction enhancement ( for SAP Backlog activity) 
2018/01/11 Humairah			remove @Out from sp parameter
2018/11/26 Humairah			NULL SAP No Handling
**************************************************************************************************************************/
  
CREATE   PROCEDURE [dbo].[GeneralLedgerExtraction_GST1]  
 @IssNo uIssNo,  
 @PrcsId int,  
 @Date varchar(6) null--, yyyymm  
as  
begin  
 declare @Rc int, @err int, @BatchId uBatchId,  @TxnDate varchar(10),@PtsIssueTxnCategory int, @PtsPerUnitPrice money, @PrcsName varchar (50),  
   @PrcsDate datetime, @FileSeq int,@RdmpTxnCategory int, @SeqNo tinyint, @PrvSeqNo tinyint, @TCd uTxnCd, @PrvTCd uTxnCd,  
   @GLTxnSeqNo int, @GLTxnSummarySeqNo int, @AcctNo bigint, @TxnCd int,@AdjustTxnCategory int, @IssAcqInd char(1),  
   @BusnLocation uMerchNo, @RefNoCheck int, @a varchar(300),@SlipSeq varchar(3),@Ind tinyint, @MaxNo int, @RefNo int,  
   @GSTStartDate datetime , @NoDetailsTxnCd int , @Header varchar(2000),  @Path varchar(50), @MySpecialTempTable varchar(100),  
   @Detail varchar(MAX), @Trailer varchar(2000), @Command varchar(500), @Unicode int, @RESULT int,@RecCnt int, @FileExt varchar(10),  
   @TSql varchar(Max), @FileName varchar(50),  @EndPrcsId int--@Date varchar(8),  
   
 SET NOCOUNT ON  
  
 select @PrcsName = 'GeneralLedgerExtraction_GST1'  
  
 --------------------------------------------------------------------------------------------------------------------  
 --------------------------------- RETRIEVES NECESSARY INFORMATION FOR PROCESSING -----------------------------------  
 --------------------------------------------------------------------------------------------------------------------  
   
 select @Ind = 0, @MaxNo = 0, @RefNo = 1, @GSTStartDate = '2015-04-01 00:00:00.000'  
  
  -- Retrieve Billing Settings --------------------------------------------------------------------------------------      
  if @Date is NULL    
    select @EndPrcsId = PrcsId,      
  @PrcsDate = PrcsDate    
   from cmnv_ProcessLog (nolock)       
   where PrcsId = @PrcsId    
      
   else     
    
   select @PrcsId = min(PrcsId) ,       
  @EndPrcsId = max(PrcsId),      
  @PrcsDate = max(PrcsDate)      
   from cmnv_ProcessLog (nolock)       
   where convert(varchar(6), PrcsDate, 112) = @Date      
  
 -- Get the latest file sequence --------------------------------------------------------------------------------------  
 select @FileSeq = max(FileSeq)   from udi_Batch   (nolock) where IssNo = @IssNo and SrcName = 'HOST' and FileName = 'GLTXN'  
 if @@ERROR <> 0 return 3  
  
 -- Get default data ---------------------------------------------------------------------------------------------------  
 select @PtsIssueTxnCategory = IntVal from iss_Default (nolock) where IssNo = @IssNo and Deft = 'PtsIssueTxnCategory'   
 select @AdjustTxnCategory = IntVal  from iss_Default (nolock) where IssNo = @IssNo and Deft = 'AdjustTxnCategory'   
 select @RdmpTxnCategory = IntVal  from iss_Default (nolock) where IssNo = @IssNo and Deft = 'RdmpTxnCategory'   
 select @PtsPerUnitPrice = MoneyVal  from iss_Default (nolock) where IssNo = @IssNo and Deft = 'PtsPerUnitPrice'  
 select @NoDetailsTxnCd = TxnCd   from itx_txncode (nolock) where IssNo = @IssNo and Descp = 'Redemption (Pts Conversion)'---- Normal Redemption Transaction(no txn detail)  
  
  
 --Get data for export purpose --------------------------------------------------------------------------------------  
 select  @Unicode=0, @MySpecialTempTable ='temp_GLFile', @RecCnt = 0  
  
 select @Path = VarcharVal  
  from iss_Default   
  where Deft = 'DeftGLFilePath'  
  
 if @Path is null   
  select @Path = 'D:\'   
  
 select @FileExt = VarcharVal  
  from iss_Default   
  where Deft = 'DeftGLFileExt'  
  
 if @FileExt is null  
  select @FileExt = '.txt'  
  
    
 select @FileName = 'LMS_SAP_' +   
      substring(convert(varchar (8),@PrcsDate,112), 3,2)  +   
      substring(convert(varchar (8),@PrcsDate,112), 5,2)  +   
      substring(convert(varchar (8),@PrcsDate,112), 7,2)  
  
 --select @Out = @Path + @FileName + @FileExt  
 --------------------------------------------------------------------------------------------------------------------  
 -------------------------------------------- CREATE TEMPORARY TABLES -----------------------------------------------  
 --------------------------------------------------------------------------------------------------------------------  
 if object_id('temp_GLFile','U') is not null    
 drop table temp_GLFile  
  
 create table temp_GLFile (SeqNo int IDENTITY (1,1), String varchar (500))  
  
  
 create table #Txn  
 (  
  RecId int IDENTITY (1,1),  
  AcctNo bigint,  
  BusnLocation varchar(15),  
  TxnCd int,  
  TxnAmt money,  
  RedeemPts money,  
  LiabilityPts money,  
  ProdCd varchar(15),  
  VATCd varchar(15),  
  VATAmt money  
 )  
 create index #IX_Txn_AcctNo on #Txn (AcctNo)  
 create index #IX_Txn_TxnCd on #Txn (TxnCd)  
 create index #IX_Txn_VATCd on #Txn (VATCd)  
 create index #IX_Txn_RecId on #Txn (RecId)  
  
 create table #udie_GLTxn  
 (  
  IssNo tinyint null,  
  BatchId bigint null,  
  SeqNo bigint null,  
  RcCd varchar(20) null,   
  TxnDate varchar(10) null,  
  SlipSeq varchar(5) null,  
  AcctTxnCd varchar(20) null,  
  BusnLocation varchar(15) null,  
  TxnType varchar(10) null,  
  TxnAmt money null,  
  RefNo varchar(20) null,  
  Descp1 varchar(100) null,  
  Descp2 varchar(200) null,  
  PrcsId int,   
  AcctNo bigint null,   
  TxnCd int null,  
  IssAcqInd varchar(5) null,  
  PromoInd char null,   
  ExtInd varchar(10) null,   
  VATCd char(5) null,   
  VATAmt money,  
  ProdCd varchar(15) null,   
  ProfitCenter varchar(20) null  
 )  
  
  
 create table #udie_GLTxnSummary  
 (  
  RecId int IDENTITY (1,1),  
  IssNo tinyint null,  
  SeqNo int null,  
  RefNo int null,  
  BatchId bigint null,  
  RcCd varchar(20) null,  
  TxnDate varchar(10) null,  
  SlipSeq varchar(5) null,  
  AcctTxnCd varchar(20) null,  
  BusnLocation varchar(15) null,  
  TxnType varchar(10) null,  
  TxnAmt money null,  
  Descp1 varchar(100) null,  
  Descp2 varchar(200) null,  
  PrcsId int,  
  TxnCd int null,  
  IssAcqInd varchar(5) null,  
  ProfitCenter varchar(20) null,  
  ProdCd varchar(15) null,   
  ProdDescp varchar(100) null,   
  VATCd char(5),   
  VATAmt money  
 )  
  
 CREATE INDEX #udie_GLTxnSummary_MID on #udie_GLTxnSummary(BusnLocation)  
 CREATE INDEX #udie_GLTxnSummary_RecId on #udie_GLTxnSummary(RecId)  
 CREATE INDEX #udie_GLTxnSummary_SeqNo on #udie_GLTxnSummary(SeqNo)  
 CREATE INDEX #udie_GLTxnSummary_AcctTxnCd on #udie_GLTxnSummary(AcctTxnCd)  
 CREATE INDEX #udie_GLTxnSummary_SlipSeq on #udie_GLTxnSummary(SlipSeq)  
  
 create table #udie_GLTxnSummary_final  
 (  
  RecId int IDENTITY (1,1),  
  IssNo tinyint null,  
  SeqNo int null,  
  RefNo int null,  
  BatchId bigint null,  
  RcCd varchar(20) null,  
  TxnDate varchar(10) null,  
  SlipSeq varchar(5) null,  
  AcctTxnCd varchar(20) null,  
  BusnLocation varchar(15) null,  
  TxnType varchar(10) null,  
  TxnAmt money null,  
  Descp1 varchar(100) null,  
  Descp2 varchar(200) null,  
  PrcsId int,  
  TxnCd int null,  
  IssAcqInd varchar(5) null,  
  ProfitCenter varchar(20) null,  
  ProdCd varchar(15) null,   
  ProdDescp varchar(100) null,   
  VATCd char(5),   
  VATAmt money  
 )  
 CREATE INDEX #udie_GLTxnSummary_GST_final_RecId on #udie_GLTxnSummary_final(RecId)  
 CREATE INDEX #udie_GLTxnSummary_GST_final_RefNo on #udie_GLTxnSummary_final(RefNo)  
  
 --------------------------------------------------------------------------------------------------------------------  
 ------------------------------------------- POPULATE TEMPORARY TABLES ----------------------------------------------  
 --------------------------------------------------------------------------------------------------------------------  
 ---- Normal Transaction( other than adjustment / redemption) ---------------------------------------------------------  
 --insert into #Txn (AcctNo, TxnCd, TxnAmt)  
 --select NULL, a.TxnCd, sum(a.Pts)*@PtsPerUnitPrice as 'TxnAmt'  
 --from itx_Txn a (nolock)  
 --join itx_TxnCode b (nolock) on b.TxnCd = a.TxnCd and b.Category not in (@AdjustTxnCategory,@RdmpTxnCategory) and b.IssNo = @IssNo   
 --where (a.PrcsId between @PrcsId and @EndPrcsId ) and  convert(varchar,a.TxnDate,112) >= @GSTStartDate  
 --group by a.TxnCd  
  
 --IF @@ERROR <> 0 return 4  
   
  
 ---- Adjustment Transaction-------------------------------------------------------------------------------------------  
 --insert into #Txn (AcctNo, BusnLocation,TxnCd, TxnAmt)  
 --select NULL, NULL, a.TxnCd, sum(a.Pts)*@PtsPerUnitPrice as 'TxnAmt'  
 --from itx_Txn a (nolock)  
 --join itx_TxnCode b (nolock) on b.TxnCd = a.TxnCd and b.IssNo = @IssNo and b.TxnCd not in(402,403) --[2015/05/27 ]  
 --join itx_TxnCategory c (nolock) on c.Category = b.Category and c.IssNo = @IssNo and C.category = @AdjustTxnCategory  
 --where (a.PrcsId between @PrcsId  and @EndPrcsId ) and convert(varchar,a.TxnDate,112) >= @GSTStartDate  and a.PromoPts = 0   
 --group by  a.TxnCd  
  
  
 --IF @@ERROR <> 0 return 5  
  
 -- Redemption Transaction--------------------------------------------------------------------------------------------  
 insert into #Txn (AcctNo, BusnLocation,TxnCd, TxnAmt, ProdCd, VATCd, VATAmt)  
 select NULL as 'AcctNo', a.BusnLocation, a.TxnCd,   
   case a.TxnCd when @NoDetailsTxnCd then abs(sum(a.SettleTxnAmt)) else  abs(sum(a1.SettleTxnAmt)) end  'TxnAmt',   
   case a.TxnCd when @NoDetailsTxnCd then NULL else a1.RefKey end 'ProdCd',   
   case a.TxnCd when @NoDetailsTxnCd then NULL else a1.VATCd end 'VATCd',   
      case a.TxnCd when @NoDetailsTxnCd then NULL else abs(sum(a1.VATAmt)) end 'VATAmt'  
 from itx_Txn a (nolock)  
 left join itx_TxnDetail a1(nolock) on a1.TxnId  = a.TxnId  
 join itx_TxnCode b (nolock) on b.TxnCd = a.TxnCd and b.Category = @RdmpTxnCategory and b.IssNo = @IssNo  
 where (a.PrcsId between @PrcsId and @EndPrcsId ) and convert(varchar,a.TxnDate,112) >= @GSTStartDate  and a.PromoPts = 0 
 group by a.BusnLocation, a.TxnCd, a1.RefKey, a1.VATCd, a1.VATAmt  
  
  
 IF @@ERROR <> 0 return 6  
  
 -- Redemption Promo---------------------------------------------------------------------------------------------------  
 insert into #Txn (AcctNo,BusnLocation, TxnCd, TxnAmt, RedeemPts, LiabilityPts, ProdCd, VATCd, VATAmt)  
 select NULL as 'AcctNo', a.BusnLocation, a.TxnCd, abs(sum(a1.SettleTxnAmt)) 'TxnAmt', abs(sum(a.Pts)) 'RedeemPts',   
   abs((sum(a.SettleTxnAmt * 100) - sum(a.Pts))) 'LiabilityPts',a1.RefKey,a1.VATCd,a1.VATAmt  
 from itx_Txn a (nolock)  
 left join itx_TxnDetail a1(nolock) on a1.TxnId  = a.TxnId  
 join itx_TxnCode b (nolock) on b.TxnCd = a.TxnCd and b.IssNo = @IssNo and b.Category = @RdmpTxnCategory  
 --join itx_TxnCategory c (nolock) on c.Category = b.Category and c.IssNo = @IssNo  
 --join iss_Default d (nolock) on d.Deft = 'RdmpTxnCategory' and d.IntVal = c.Category and d.IssNo = @IssNo  
 where (a.PrcsId between @PrcsId  and @EndPrcsId ) and a.PromoPts > 0  and convert(varchar,a.TxnDate,112) >= '20150401' 
 group by  a.BusnLocation, a.TxnCd,a1.RefKey,a1.VATCd,a1.VATAmt  
  
 IF @@ERROR <> 0 return 7  
  
-- --------------------------------------------------------------------------------------------------------------------  
-- ------------------------------------------------ DATA VALIDATION ---------------------------------------------------  
-- --------------------------------------------------------------------------------------------------------------------  
  
  
-- --------------------------------------------------------------------------------------------------------------------  
-- ---------------------------------------------------- PROCESS -------------------------------------------------------  
-- --------------------------------------------------------------------------------------------------------------------  
  
   
 -- Input to GLTxn for ALL Transaction where it is not a promo txn---------------------------------------------------  
 insert #udiE_GLTxn  
   (IssNo, BatchId, RcCd,   
    TxnDate,   
    SlipSeq, AcctTxnCd, TxnType, TxnAmt, RefNo,  
    Descp1, Descp2, PrcsId, AcctNo, TxnCd, IssAcqInd, PromoInd, ExtInd , BusnLocation, ProdCd,  
    VATCd,VATAmt, ProfitCenter)  
 select @IssNo, @BatchId, b.RcCd,    
   left( convert(varchar(10), @PrcsDate, 103), 2) +   
     substring(convert(varchar(10), @PrcsDate, 103), 4,2) +   
     right(convert(varchar(10), @PrcsDate, 103), 2),  
   b.SlipSeq, b.AcctTxnCd, b.TxnType, a.TxnAmt, a.RecId, b.AcctName as 'Descp1', b.GLTxnDescp,   
   @PrcsId, a.AcctNo, b.TxnCd, 'I',  b.PromoInd, ExtInd,a.BusnLocation, a.ProdCd,  
   c.RefId,a.VATAmt, b.ProfitCenter  
  from #Txn a  
  join iss_GLCode_GST b (nolock) on b.TxnCd = a.TxnCd and b.PromoInd <> 'Y'  --and b.SlipSeq = 'RE'  
  left join iss_reflib c (nolock) on c.RefCd = a.VATCd and c.Reftype = 'VATCd'  
  join itx_TxnCode d (nolock) on d.TxnCd = b.TxnCd and d.Category <> @RdmpTxnCategory  
  order by a.RecId, a.AcctNo  
    
 if @@ERROR <> 0  
 begin  
  ROLLBACK TRANSACTION   
  return 8  
 end   
   
  
-- -- For Promo Ind 'Y' Txn--------------------------------------------------------------------------------------------  
 insert #udiE_GLTxn  
   (IssNo, BatchId, RcCd, TxnDate, SlipSeq, AcctTxnCd, TxnType, TxnAmt, RefNo,  
    Descp1, Descp2,PrcsId, AcctNo, TxnCd, IssAcqInd, PromoInd, ExtInd, BusnLocation,ProdCd,  
    VATCd,VATAmt, ProfitCenter)  
 select @IssNo, @BatchId, b.RcCd,    
   left( convert(varchar(10), @PrcsDate, 103), 2) +   
     substring(convert(varchar(10), @PrcsDate, 103), 4,2) +   
     right(convert(varchar(10), @PrcsDate, 103), 2),  
   b.SlipSeq, b.AcctTxnCd, b.TxnType,   
   case when TxnType = 50 and PromoInd = 'N' then a.TxnAmt  
      when TxnType = 40 and PromoInd = 'Y' then a.RedeemPts  
      when TxnType = 40 and PromoInd = 'N' then a.LiabilityPts   
   end, a.RecId, b.AcctName as 'Descp1',   
    CASE    
     WHEN (BusnLocation is not null ) THEN substring(a.BusnLocation + ' ' + rtrim(ltrim(b.GLTxnDescp)), 1, 80)  
     ELSE rtrim(ltrim(b.GLTxnDescp))  
     END as 'Descp2',    
   @PrcsId, a.AcctNo, b.TxnCd, 'I', PromoInd, ExtInd,a.BusnLocation,a.ProdCd,  
   c.RefId,a.VATAmt, b.ProfitCenter  
  from #Txn a  
  join iss_GLCode_GST b (nolock) on b.TxnCd = a.TxnCd  and b.PromoInd = 'Y'  
  join iss_reflib c (nolock) on c.RefCd = a.VATCd and c.Reftype = 'VATCd'  
  order by a.AcctNo  
    
 if @@ERROR <> 0  
 begin  
  ROLLBACK TRANSACTION   
  return 9  
 end   
  
 -- all redemption GL--------------------------------------------------------------------------------------------  
 insert #udiE_GLTxn  
   (IssNo, BatchId, RcCd, TxnDate, SlipSeq, AcctTxnCd, TxnType, TxnAmt, RefNo, Descp1, Descp2, PrcsId, AcctNo,   
   TxnCd, IssAcqInd, PromoInd, ExtInd , BusnLocation, ProdCd, VATCd,VATAmt, ProfitCenter)  
 select * from (  
     select @IssNo'IssNo', @BatchId'BatchId', b.RcCd,    
       left( convert(varchar(10), @PrcsDate, 103), 2) +   
         substring(convert(varchar(10), @PrcsDate, 103), 4,2) +  
         right(convert(varchar(10), @PrcsDate, 103), 2)'TxnDate',  
       b.SlipSeq, b.AcctTxnCd, b.TxnType, a.TxnAmt, a.RecId, b.AcctName as 'Descp1', b.GLTxnDescp,   
       @PrcsId'PrcsId', a.AcctNo, b.TxnCd, 'I' as 'IssAcqInd',  b.PromoInd, ExtInd,a.BusnLocation, a.ProdCd,  
       c.RefId,a.VATAmt, b.ProfitCenter  
      from #Txn a  
      join iss_GLCode_GST b (nolock) on b.TxnCd = a.TxnCd and b.PromoInd <> 'Y' and b.AcctTxnCd <> 99 and b.SlipSeq = 'RE'  
      left join iss_reflib c (nolock) on c.RefCd = a.VATCd and c.Reftype = 'VATCd'  
      join itx_TxnCode d (nolock) on d.TxnCd = b.TxnCd and d.Category =  @RdmpTxnCategory  
     union all  
     select @IssNo'IssNo', @BatchId'BatchId', b.RcCd,    
       left( convert(varchar(10), @PrcsDate, 103), 2) +   
         substring(convert(varchar(10), @PrcsDate, 103), 4,2) +   
         right(convert(varchar(10), @PrcsDate, 103), 2)'TxnDate',  
       b.SlipSeq, b.AcctTxnCd, b.TxnType, sum(a.TxnAmt)- sum(a.VATAmt)'TxnAmt', null as 'RecId' , b.AcctName as 'Descp1', cast(a.BusnLocation as varchar)+ ' ' + b.GLTxnDescp,   
       @PrcsId'PrcsId', a.AcctNo, b.TxnCd, 'I' as 'IssAcqInd',  b.PromoInd, ExtInd,a.BusnLocation, null as 'ProdCd',  
       NULL as 'RefId', NULL as 'VATAmt', b.ProfitCenter  
      from #Txn a  
      join iss_GLCode_GST b (nolock) on b.TxnCd = a.TxnCd and b.PromoInd <> 'Y' and b.SlipSeq = 'DA'  
      left join iss_reflib c (nolock) on c.RefCd = a.VATCd and c.Reftype = 'VATCd'  
      join itx_TxnCode d (nolock) on d.TxnCd = b.TxnCd and d.Category =  @RdmpTxnCategory  
      join aac_BusnLocation e (nolock) on e.BusnLocation = a.BusnLocation   
      group by  b.RcCd, b.SlipSeq, b.AcctTxnCd, b.TxnType,b.AcctName, cast(a.BusnLocation as varchar)+ ' ' + b.GLTxnDescp, a.AcctNo, b.TxnCd,    
          b.PromoInd, ExtInd,a.BusnLocation, b.ProfitCenter  
     )x order by RecId, AcctNo  
  
 if @@ERROR <> 0  
 begin  
  ROLLBACK TRANSACTION   
  return 10  
 end   
   
 --redemption summary per merchant  
 insert #udiE_GLTxn  
   (IssNo, BatchId, RcCd, TxnDate, SlipSeq, AcctTxnCd, TxnType, TxnAmt,  Descp1, Descp2, PrcsId, AcctNo,   
   TxnCd, IssAcqInd, PromoInd, ExtInd , BusnLocation, ProdCd, VATCd,VATAmt, ProfitCenter)  
 select @IssNo'IssNo', @BatchId'BatchId', b.RcCd,    
       left( convert(varchar(10), @PrcsDate, 103), 2) +   
         substring(convert(varchar(10), @PrcsDate, 103), 4,2) +  
         right(convert(varchar(10), @PrcsDate, 103), 2)'TxnDate',  
   b.SlipSeq, isnull(e.SAPNo,'') , b.TxnType, sum(a.TxnAmt) ,e.DBAName, cast(a.BusnLocation as varchar)+ ' ' + b.GLTxnDescp,   
   @PrcsId'PrcsId', a.AcctNo, b.TxnCd, 'I' as 'IssAcqInd',  b.PromoInd, ExtInd,a.BusnLocation, NULL,  
   NULL ,NULL, b.ProfitCenter  
  from #Txn a  
  join iss_GLCode_GST b (nolock) on b.TxnCd = a.TxnCd and b.PromoInd <> 'Y' and b.AcctTxnCd = 99 and b.SlipSeq = 'RE'  
  left join iss_reflib c (nolock) on c.RefCd = a.VATCd and c.Reftype = 'VATCd'  
  join itx_TxnCode d (nolock) on d.TxnCd = b.TxnCd and d.Category =  @RdmpTxnCategory  
  join aac_BusnLocation e (nolock) on e.BusnLocation = a.BusnLocation   
  group by  b.RcCd, b.SlipSeq, e.SAPNo , b.TxnType, e.DBAName, cast(a.BusnLocation as varchar)+ ' ' + b.GLTxnDescp,   
   a.AcctNo, b.TxnCd, b.PromoInd, ExtInd,a.BusnLocation, b.ProfitCenter  
 if @@ERROR <> 0  
 begin  
  ROLLBACK TRANSACTION   
  return 13  
 end   
 -- to check back with finance abt the GL setting. Maybe got confusion between itx and atx transaction code  
 --Redemption summary (settlement entry )-------------------------------------------------------------------------------  
 insert #udie_GLTxnSummary(IssNo, BatchId, RcCd, TxnDate, SlipSeq, AcctTxnCd, BusnLocation, TxnType, TxnAmt,  
   Descp1, Descp2, PrcsId,  TxnCd, IssAcqInd, SeqNo, ProfitCenter)  
 select  @IssNo , @BatchId, b.RcCd,   
   left( convert(varchar(10), @PrcsDate, 103), 2) +   
     substring(convert(varchar(10), @PrcsDate, 103), 4,2) +   
     right(convert(varchar(10), @PrcsDate, 103), 2)'TxnDate',   
   b.SlipSeq,   
   case b.GLAcctNo   
    when '99' then isnull(c.SAPNo,'')  
    else b.GLAcctNo   
    end 'AcctTxnCd',   
   a.BusnLocation , b.TxnType , abs(sum(a.TxnAmt)),  
   b.AcctName, cast(a.BusnLocation as varchar) + ' ' + cast(isnull(b.GLTxnDescp,'') as varchar), @PrcsId, a.TxnCd, 'A', 3,  
   b.ProfitCenter  
 from #Txn a (nolock)  
 join acq_GLCode_GST b (nolock) on b.TxnCd = a.TxnCd   
 join aac_busnLocation c(nolock) on c.BusnLocation = a.busnLocation  
 join itx_txnCode d (nolock) on d.TxnCd = a.TxnCd and d.Category = @RdmpTxnCategory -- should be atx_TxnCode  
 group by b.RcCd, b.SlipSeq, a.BusnLocation, b.TxnType, a.TxnCd, c.SAPNo,  b.GLAcctNo, b.AcctName, b.GLTxnDescp, b.ProfitCenter  
   
 if @@ERROR <> 0  
 begin  
  ROLLBACK TRANSACTION   
  return 11  
 end   
   
   
 --all kind of txn (Summary)--------------------------------------------------------------------------------------------  
 insert #udie_GLTxnSummary (IssNo, BatchId, RcCd, TxnDate, SlipSeq, AcctTxnCd, BusnLocation, TxnType, TxnAmt,  
   Descp1, Descp2, PrcsId,  TxnCd, IssAcqInd, ProdCd, ProdDescp, VATCd, VATAmt, SeqNo, ProfitCenter)  
 select  a.IssNo, a.BatchId, a.RcCd, a.TxnDate, a.SlipSeq,   
   a.AcctTxnCd,  
   a.BusnLocation, a.TxnType, sum(a.TxnAmt),a.Descp1,   
   case a.VATCd   
     when 'I1' then 'REDEEMED '+ substring(rtrim(isnull(c.Descp,'')),1,12) + ' (6%)'   
     when 'I0' then 'REDEEMED '+ substring(rtrim(isnull(c.Descp,'')),1,12) + ' (0%)'   
     else  replace (a.Descp2 , 'MID ', '')  
     end 'Descp2',  
   a.PrcsId, a.TxnCd, a.IssAcqInd, a.ProdCd, c.Descp, a.VATCd, sum(isnull(a.VATAmt,0)),   
   case when len(a.VatCd) = 2 then 2   
     when a.SlipSeq = 'RE' then 1   
     else 0   
     end 'SeqNo',  
   a.ProfitCenter  
 from #udiE_GLTxn a  
 join iss_Reflib b (nolock) on b.RefType = 'GLExtractionInd' and b.RefCd = a.ExtInd and b.RefNo = 0 and b.IssNo = @IssNo -- Summary  
 left outer join iss_Product c (nolock) on c.ProdCd = a.ProdCd  
 left join aac_busnLocation d (nolock) on d.BusnLocation = a.BusnLocation   
 where a.PrcsId = @PrcsId and a.AcctTxnCd <> 99  
 group by a.IssAcqInd, a.IssNo, a.BatchId, a.RcCd, a.TxnDate, a.SlipSeq, a.AcctTxnCd, a.BusnLocation, a.TxnType, a.Descp1, a.Descp2,   
   a.PrcsId, a.TxnCd, a.ProdCd, c.Descp, a.VATCd, d.SapNo, a.ProfitCenter  
 having sum(isnull(a.TxnAmt,0))<> 0  
  
 if @@ERROR <> 0  
 begin  
  ROLLBACK TRANSACTION   
  return 12  
 end   
  
 --Creating Document No ---------------------------------------------------------------------------------------------  
 insert into #udie_GLTxnSummary_final (IssNo,SeqNo,RefNo,BatchId,RcCd,TxnDate,SlipSeq,AcctTxnCd,BusnLocation,TxnType,  
    TxnAmt,Descp1,Descp2,PrcsId,TxnCd,IssAcqInd,ProdCd,ProdDescp,VATCd,VATAmt,ProfitCenter)  
 select IssNo,SeqNo,RefNo,BatchId,RcCd,TxnDate,SlipSeq,AcctTxnCd,BusnLocation,TxnType,abs(TxnAmt),Descp1,Descp2,PrcsId,  
    TxnCd,IssAcqInd,ProdCd,ProdDescp,VATCd,abs(VATAmt),ProfitCenter  
 from #udie_GLTxnSummary   
  where TxnCd between 500 and 599  
 order by busnLocation, cast(SeqNo as int), TxnCd , SlipSEq  
    
 if @@ERROR <> 0  
 begin  
  ROLLBACK TRANSACTION   
  return 14  
 end   
  
 select identity (int,1,1) 'Id',  SlipSeq, isnull(BusnLocation, 0)'BusnLocation', TxnCd into #RefNo   
 from #udie_GLTxnSummary_final   
 group by  SeqNo, SlipSeq, BusnLocation, TxnCd     
 order by  BusnLocation, SeqNo,  TxnCd  
   
 update a  
   set a.RefNo = b.Id   
   from #udie_GLTxnSummary_final a  
   join #RefNo b on b.SlipSeq = a.SlipSeq and b.BusnLocation = isnull(a.BusnLocation, 0) and b.TxnCd = a.TxnCd  
     
 if @@ERROR <> 0  
 begin  
  ROLLBACK TRANSACTION   
  return 15  
 end   
  
 -- Arrange data into SAP structure----------------------------------------------------------------------------------  
 -- Create Header Record  
 select top 1 @TSql =  'HEADER' +     -- Header (6)  
     substring( TxnDate, 1,2) + -- DAY(2)  
     '.' +  
     substring( TxnDate, 3,2) + -- MONTH(2)  
     '.' +  
     substring( TxnDate, 5,2) + -- YEAR(2)  
     space(240)       -- Filler(240)  
  from #udie_GLTxnSummary_final  
   
 select @Header = 'insert '+ @MySpecialTempTable+' ( String)'+ ' select ''' + @TSql +''''  
  
 exec (@Header)  
  
 if @@error <> 0   
 begin  
   rollback transaction  
   return 16  
 end  
    
 -- Contruct Detail  
 select @TSql = 'select TxnDate' + --Transaction Date  
    '+ dbo.Padleft(0, 6, a.RefNo )' + -- Record  
    '+ ''' +'0002' +  '''' +  -- Company Code  
    '+ a.SlipSeq' +     --  Slip Sequence  
    '+ TxnDate' + -- Transaction Date  
    '+ ''' +'MYR' +  '''' +  -- Currency  
    '+ dbo.PadRight('' '', 25, rtrim(substring(a.Descp1, 1, 25)))' +       -- Transaction Type  
    '+ dbo.PadLeft('''',2,convert(varchar(2), a.TxnType)) ' +    -- Post Key  
    '+ dbo.PadRight('' '', 10, a.AcctTxnCd) ' +  
    '+ dbo.PadLeft(''0'', 13, convert(varchar(20), a.TxnAmt)) ' +  
    '+ dbo.PadLeft('' '', 10, isnull(a.ProfitCenter,'' ''))' +  
    '+ dbo.PadLeft('' '', 10, isnull(a.RcCd,'' ''))' +  
    '+ dbo.PadRight('' '', 24, space(0))' + -- Assignment no (12 x 2)   
    '+ dbo.PadRight('' '', 50, substring(a.Descp2,1,50)) '+   
    '+ dbo.PadRight('''', 2, isnull(rtrim(a.VATCd),''''))'+   
    '+ dbo.PadLeft(''0'', 13, isnull(a.VATAmt,'' ''))'+    
  ' from #udie_GLTxnSummary_final a (nolock) order by cast(RefNo as int)'  
  
  -- Create Detail Record  
  select @Detail = 'insert '+ @MySpecialTempTable+' (String) ' +@TSql  
  exec (@Detail)    
  
  if @@error <> 0   
  begin  
    rollback transaction  
    return 17  
  end  
  
  -- Contruct Trailer Record  
  select @TSql ='select ''TRAILER''' + -- Header (7)  
    '+ dbo.PadLeft(''0'', 14, Max(RefNo))' +  
    '+ dbo.PadLeft(''0'', 14, count(RefNo))' +  
    '+ dbo.PadRight('' '', 219, space(0))' +  
    ' from  #udie_GLTxnSummary_final a (nolock)'   
  
  
  -- Create Trailer Record     
  select @Trailer = 'insert '+ @MySpecialTempTable+' (String) '+  @TSql+ ''  
  exec (@Trailer)  
    
  
  if @@error <> 0   
  begin  
    rollback transaction  
    return 18  
  end  
  
 select String from temp_GLFile  order by SeqNo  
   
 drop table temp_GLFile  
 return 0  
end
GO
