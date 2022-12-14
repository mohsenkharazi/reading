USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BatchCLPImport]    Script Date: 9/6/2021 10:33:55 AM ******/
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

--exec BatchCLPImport '1';
CREATE	procedure [dbo].[BatchCLPImport]
	@IssNo uIssNo
  as
BEGIN


DECLARE 

@CBBatchId uBatchId,
@CBFileName varchar(80),
@CBRecCnt int,

@RecID int,
@RecStr varchar(MAX)
	

TRUNCATE TABLE ld_CLPTxn;


DECLARE batch_cursor CURSOR FOR 
select a.BatchId, b.FileName, a.RecCnt, b.Id, b.RecStr
From cbf_Batch a (nolock) 
left outer join cbf_Record b (nolock)  on a.FileName = b.FileName AND a.FileId = b.FileId 
where a.sts in ( 'L') AND a.fileId='CLP' AND RecStr like 'D%' and RecStr <> '';


OPEN batch_cursor
FETCH NEXT FROM batch_cursor 
INTO @CBBatchId,@CBFileName,@CBRecCnt, @RecID, @RecStr;
WHILE @@FETCH_STATUS = 0
BEGIN 
   	
	

	
	BEGIN TRANSACTION insert_trx;
	BEGIN TRY
		INSERT ld_CLPTxn (
		Str
		)
		VAlUES(
		@RecStr
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
where FileId ='CLP'  AND sts ='L' ;




CLOSE batch_cursor
DEALLOCATE batch_cursor



END
GO
