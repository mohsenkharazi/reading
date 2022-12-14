USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ExportDatamartFile]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*****************************************************************************************************************
Copyright	:	CardTrend Systems Sdn. Bhd.
Modular		:	CardTrend Card Management System (CCMS)

Objective	:	Genarate Datamart File
------------------------------------------------------------------------------------------------------------------
When	   	Who			Desc
------------------------------------------------------------------------------------------------------------------
2014/04/15 	Humairah	Initial development
******************************************************************************************************************/
--exec ExportDatamartFile 1
CREATE procedure [dbo].[ExportDatamartFile]
	@IssNo uIssNo
  as
begin

	declare @PrcsId uPrcsId , 
			@CardBatchId uBatchId,
			@AcctBatchId uBatchId,
			@MerchBatchId uBatchId,
			@OUT_Card varchar(200) ,
			@OUT_Acct varchar(200) ,
			@OUT_Merch varchar(200) 

	--Get day - 1 Process 
	select  @PrcsId = CtrlNo -1  from Iss_control  where ctrlid = 'PrcsId'

	--Get the Batch Id
	select @MerchBatchId = BatchId from udi_batch where prcsid = @PrcsId and SrcName = 'host' and FileName = 'MERCH'

	EXEC MerchDataExport @MerchBatchId, @OUT_Merch output
	select @OUT_Merch 

	if  dateName(dw,getdate()) = 'Wednesday'

		begin
		
		select @CardBatchId = BatchId from udi_batch where prcsid = @PrcsId and SrcName = 'host' and FileName = 'CARDDATA'
		select @AcctBatchId = BatchId from udi_batch where prcsid = @PrcsId and SrcName = 'host' and FileName = 'ACCTDATA'

		EXEC CardDataExport @CardBatchId, @OUT_Card output
		select @OUT_Card
		                                                   
		EXEC AccountDataExport @AcctBatchId, @OUT_Acct output
		select @OUT_Acct

		end
 

end
GO
