USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BatchLPGImport]    Script Date: 9/6/2021 10:33:55 AM ******/
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
20017/05/09	Jasmine			Initial Development
*******************************************************************************/

--exec BatchLPGImport '1';
CREATE	procedure [dbo].[BatchLPGImport]
	@IssNo uIssNo
  as
BEGIN


DECLARE 

@CBBatchId uBatchId,
@CBFileName varchar(80),
@CBRecCnt int,

@RecID int,
@RecStr varchar(MAX)
	

TRUNCATE TABLE ld_LPGTxn;


DECLARE batch_cursor CURSOR FOR 
select a.BatchId, b.FileName, a.RecCnt, b.Id, b.RecStr
From cbf_Batch a (nolock) 
left outer join cbf_Record b (nolock)  on a.FileName = b.FileName AND a.FileId = b.FileId 
where a.sts in ( 'L') AND a.fileId='LPG' AND b.RecSeq <> 1;

OPEN batch_cursor
FETCH NEXT FROM batch_cursor 
INTO @CBBatchId,@CBFileName,@CBRecCnt, @RecID, @RecStr;
WHILE @@FETCH_STATUS = 0
BEGIN 
   	
	

	DECLARE @SeqNo varchar(20);
	DECLARE @InputSrc varchar(20);
	DECLARE @BatchDate varchar(10);
	DECLARE @BatchTime varchar(10);
	DECLARE @LocalDate varchar(10);
	DECLARE @LocalTime varchar(10);
	DECLARE @TxnAmt varchar(15);
	DECLARE @CardNo varchar(30);
	DECLARE @ProdCd varchar(15);
	DECLARE @Qty varchar(10);

	SELECT @SeqNo = Data FROM dbo.split(@RecStr, N',') where ID ='1';
	SELECT @InputSrc = Data FROM dbo.split(@RecStr, N',') where ID ='2';
	SELECT @BatchDate = Data FROM dbo.split(@RecStr, N',') where ID ='3';
	SELECT @BatchTime = Data FROM dbo.split(@RecStr, N',') where ID ='4';
	SELECT @LocalDate = Data FROM dbo.split(@RecStr, N',') where ID ='5';
	SELECT @LocalTime = Data FROM dbo.split(@RecStr, N',') where ID ='6';
	SELECT @TxnAmt = Data FROM dbo.split(@RecStr, N',') where ID ='7';
	SELECT @CardNo = Data FROM dbo.split(@RecStr, N',') where ID ='8';
	SELECT @ProdCd = Data FROM dbo.split(@RecStr, N',') where ID ='9';
	SELECT @Qty = Data FROM dbo.split(@RecStr, N',') where ID ='10';


	BEGIN TRANSACTION insert_trx;
	BEGIN TRY
		INSERT ld_LPGTxn (
		SeqNo, InputSrc,  
		BatchDate,BatchTime,
		LocalDate,LocalTime, 
		TxnAmt,CardNo,
		ProdCd, Qty
		)
		VAlUES(
		@SeqNo, @InputSrc,  
		@BatchDate,@BatchTime,
		@LocalDate,@LocalTime, 
		@TxnAmt,@CardNo,
		@ProdCd, @Qty
		);

		UPDATE cbf_Record set Sts ='P' where id= @RecID;

		COMMIT TRANSACTION insert_trx;  


	END TRY
	BEGIN CATCH
		UPDATE cbf_Record set Sts ='F' where id= @RecID;

		ROLLBACK TRANSACTION insert_trx;

	END CATCH;
		
	
	FETCH NEXT FROM batch_cursor 
	INTO @CBBatchId,@CBFileName,@CBRecCnt, @RecID, @RecStr;

END 



update cbf_Batch set Sts = 'P'
where FileId ='LPG' AND sts ='L';




CLOSE batch_cursor
DEALLOCATE batch_cursor



END
GO
