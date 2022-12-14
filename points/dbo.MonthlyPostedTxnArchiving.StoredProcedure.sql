USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MonthlyPostedTxnArchiving]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/*************************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: To transfer posted transaction from main database to archive database and delete it from itx_Txn & itx_TxnDetail table (main database). 
       		  One Cycle Id at at time. This sp will always take minimum Cycle Id in Demo_lms..itx_Txn  table to be processed.

SP Level	: Primary

Calling By	: -

--------------------------------------------------------------------------------------------------------------------------
When	   Who		CRN		Desc
--------------------------------------------------------------------------------------------------------------------------
2014/10/15	Humairah		Initial Development
2015/12/08	Humairah		update error @ cmn_MainBackup
**************************************************************************************************************************/
--exec MonthlyPostedTxnArchiving 1

CREATE PROCEDURE [dbo].[MonthlyPostedTxnArchiving]
	@IssNo uIssNo
as
--with encryption as
begin

declare @CycId int , @FromPrcsId uPrcsId, @ToPrcsId uPrcsId,
		@TxnRowCnt bigint, @TxnDetailRowCnt bigint, @PrcsName varchar(20),
		@DelTxnRowCnt bigint,  @DelTxnDetailRowCnt bigint


	SET NOCOUNT ON

	select @PrcsName = 'MonthlyPostedTxnArchiving'

	exec TraceProcess @IssNo, @PrcsName, 'Start'
	--------------------------------------------------------------------------------------------------------------------
	--------------------------------- RETRIEVES NECESSARY INFORMATION FOR PROCESSING -----------------------------------
	--------------------------------------------------------------------------------------------------------------------

	select @CycId= min(cycid) from itx_txn(nolock) where cycid >0

	select @FromPrcsId= min(PrcsId)+1, @ToPrcsId = max(PrcsId)from iac_AgeingCycle where CycId in( @CycId,@CycId-1)
 
	--------------------------------------------------------------------------------------------------------------------
	-------------------------------------------- TEMPORARY TABLES -----------------------------------------------
	--------------------------------------------------------------------------------------------------------------------
	insert Demo_lms_archive..cmn_MainBackup (IssNo, CycleId, FromPrcsId, ToPrcsId, StartDate,Sts)
	select 1, @CycId, @FromPrcsId, @ToPrcsId, getdate(),'L'

	/*Tmp Txn    */	select * into #tempTxn from itx_txn(nolock) where prcsid between  @FromPrcsId and @ToPrcsId 
					create index IX_TxnId on #tempTxn (TxnId)
					select @TxnRowCnt= count(*) from #tempTxn

	/*Tmp TxnDet */ select * into #tempTxn_det from itx_txndetail(nolock) where txnid in (select TxnId from #tempTxn)
					create index IX_TxnId on #tempTxn_det (TxnId)
					select @TxnDetailRowCnt = count(*) from #tempTxn_det
	--------------------------------------------------------------------------------------------------------------------
	------------------------------------ DATA EXTRACTION && VALIDATION -------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------

	update Demo_lms_archive..cmn_MainBackup 
	set TxnCnt = @TxnRowCnt,  
		TxnDetailCnt = @TxnDetailRowCnt,
		Sts = 'P',--Progressing
		EndDate = getdate()
	where CycleId = @CycId
	

	/*check Cycle*/	select  cycid into #TmpCycId from itx_txn(nolock)
					select distinct cycid from #TmpCycId (nolock) where cycid <> 0
					if @@Rowcount <= 6 
					begin
						return 90 -- No deletion; maintain latest 6 month in main database
					end


					select distinct CycId from itx_Txn(nolock) where PrcsId between @FromPrcsId and @ToPrcsId
					if @@rowcount > 1 
						begin
							return 91 --- more than 1 Cycle Id
						end
					

	/*Insert Txn */	insert into Demo_lms_archive..itx_Txn 
					select * from #tempTxn


	/*InsertTxnDet*/insert into Demo_lms_archive..itx_TxnDetail
					select * from #tempTxn_det


	/*checking   */ select TxnId into #tmpTxnId from Demo_lms_archive..itx_Txn (nolock) where prcsid between @FromPrcsId and @ToPrcsId
					if @@rowcount <> @TxnRowCnt
						begin

								update Demo_lms_archive..cmn_MainBackup 
									set Sts = 'F', 
										Descp = 'transaction count unmatched',
										EndDate = getdate()
								where CycleId = @CycId

							return 92--transaction count unmatched
						end

					select TxnId into #tmpTxnIdDet from Demo_lms_archive..itx_TxnDetail (nolock) where TxnId in (select * from #tmpTxnId)
					if @@rowcount <> @TxnDetailRowCnt
						begin
							update Demo_lms_archive..cmn_MainBackup 
									set Sts = 'F', 
										Descp = 'transaction detail count unmatched',
										EndDate = getdate()
							where CycleId = @CycId

							return 93 --transaction detail count unmatched
						end


	--------------------------------------------------------------------------------------------------------------------
	BEGIN TRANSACTION
	--------------------------------------------------------------------------------------------------------------------
					
	/*Delete     */		delete  from itx_Txn  where  Txnid in ( select * from #tmpTxnId)
							if @@Error <> 0
							begin
								rollback transaction

								update Demo_lms_archive..cmn_MainBackup 
									set Sts = 'F', 
										Descp = 'fail to delete transaction',
										EndDate = getdate()
								where CycleId = @CycId

								return 94--fail to delete transaction
							end	
							
						delete  from itx_TxnDetail  where  Txnid in (select * from #tmpTxnIdDet)
							if @@Error <> 0
							begin
								rollback transaction

								update Demo_lms_archive..cmn_MainBackup 
									set Sts = 'F', 
										Descp = 'fail to delete transaction details',
										EndDate = getdate()
								where CycleId = @CycId

								return 95--fail to delete transaction details
							end	

	update Demo_lms_archive..cmn_MainBackup 
	set Sts = 'S',--Success
		DelTxnCnt = (select count(*) from #tmpTxnId),  
		DelTxnDetailCnt = (select count(*) from #tmpTxnIdDet),
		EndDate = getdate()
	where CycleId = @CycId
	------------------------------------------------------------------------------------------------------------------
	COMMIT TRANSACTION
	--------------------------------------------------------------------------------------------------------------------

	drop table #tempTxn
	drop table #tempTxn_det
	drop table #tmpTxnId
	drop table #tmpTxnIdDet
	
	return 0

end
GO
