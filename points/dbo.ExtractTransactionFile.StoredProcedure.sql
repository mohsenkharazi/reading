USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ExtractTransactionFile]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*************************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure is to extract LMS_TRXN file (this file monitored by Datamart)  

SP Level	: Primary

Calling By	: 

--------------------------------------------------------------------------------------------------------------------------
When	   Who		CRN		Desc
--------------------------------------------------------------------------------------------------------------------------
2017/04/11 Humairah		Initial development
2017/07/04 Humairah		Handle 0 card no for points expiry
2017/11/08 Jasmine		Fix error for length 11 in point 
**************************************************************************************************************************/
--exec ExtractTransactionFile 1, 3008 
CREATE PROCEDURE [dbo].[ExtractTransactionFile]
	@IssNo uIssNo,
	@PrcsId uPrcsId
as
--with encryption as
begin
	declare 
		@BatchId uBatchId, 
		@SrcName nvarchar(5), 
		@FileType  nvarchar(10), 
		@DestName  nvarchar(5), 
		@FileSeq varchar(10),
		@PrcsName varchar(50)

	SET NOCOUNT ON

	select @PrcsName = 'ExtractTransactionFile'

	exec TraceProcess @IssNo, @PrcsName, 'Start'

	--------------------------------------------------------------------------------------------------------------------
	--------------------------------- RETRIEVES NECESSARY INFORMATION FOR PROCESSING -----------------------------------
	--------------------------------------------------------------------------------------------------------------------

	-- Retrieve Billing Settings --------------------------------------------------------------------------------------

	select  @BatchId = BatchId, 
			@SrcName  = SrcName, 
			@FileSeq = FileSeq , 
			@DestName = DestName, 
			@FileType = [FileName]
	from udi_batch( nolock) 
	where IssNo = @IssNo and PrcsId = @PrcsId  and [FileName] = 'CARDTXN' and SrcName = 'HOST'

	--------------------------------------------------------------------------------------------------------------------
	-------------------------------------------- CREATE TEMPORARY TABLES -----------------------------------------------
	--------------------------------------------------------------------------------------------------------------------
	
	create table #Trxn  ( 
				--Id int identity(1,1),
				Ind int,  
				TxnId bigint,  
				ParentSeqNo bigint,  
				SeqNo bigint, 
				TxnSeq bigint,   
				String nvarchar (500)) 

	if @@ERROR <> 0 return 70270	-- Failed to create temporary table

	create index  ix_Ind on #Trxn(Ind)
	create index  ix_Parent on #Trxn(ParentSeqNo)
	create index  ix_SeqNo on #Trxn(SeqNo)
	create index  ix_TxnId on #Trxn(TxnId)


	create table #result (Id int identity(1,1), string nvarchar(500))

	if @@ERROR <> 0 return 70270	-- Failed to create temporary table

	create index  ix_Id on #result(Id)

	--------------------------------------------------------------------------------------------------------------------
	------------------------------------------- POPULATE TEMPORARY TABLES ----------------------------------------------
	--------------------------------------------------------------------------------------------------------------------
	
	-- Construct File Header
	insert into #Trxn (Ind, String) 
	select	1 , 
			'H' + dbo.PadRight(char (32), 8,  @SrcName ) 
			+ dbo.PadRight(char(32), 20, @FileType) 
			+ dbo.PadLeft('0', 12, @FileSeq) 
			+ dbo.PadRight(char (32), 8,  @DestName ) 
			+ dbo.PadRight(char(32), 8,  CONVERT( varchar (8), getdate(), 112)   )

	-- Construct Body Record 
	insert into #Trxn (Ind, TxnId, String) 
	select	2,a.TxnId,
			'D' + dbo.PadLeft( '0', 10,cast(a.SeqNo as nvarchar (10)) )
			+ dbo.PadRight(char(32), 12, cast(a.TxnId as nvarchar (10)))
			+ cast(a.TxnCd as nvarchar (10))
			+ cast(a.AcctNo as nvarchar (10))
			+ dbo.PadLeft( '0', 17, cast(a.CardNo as nvarchar (17)))									--2017/07/04 Humairah	
			+ dbo.PadRight(char(32), 16, cast(a.TxnDate as nvarchar (16)))
			+ dbo.PadRight(char(32), 10, convert(varchar(8),a.PrcsDate, 112))
			+ dbo.PadLeft( '0', 11,replace(cast(a.SettleTxnAmt as nvarchar(11)), '.', ''))
			+ dbo.PadLeft( '0', 11,replace(cast(a.BillingTxnAmt as nvarchar(11)), '.', ''))
			-- + dbo.PadLeft( '0', 11,replace(cast(a.Pts as nvarchar(11)), '.', ''))						--2017/11/08 Jasmine
			+ dbo.PadLeft( '0', 11,replace(cast(cast((a.Pts *100)  as bigint )as nvarchar(11)), '.', ''))
			+ dbo.PadLeft( '0', 11,replace(cast(a.PromoPts as nvarchar(11)), '.', ''))
			+ dbo.PadRight(char(32), 50,a.TxnDescp)
			+ cast(a.BusnLocation  as nvarchar (15))
			+ dbo.PadRight(char(32), 8,cast(a.TermId as nvarchar (8)))
			+ dbo.PadLeft( '0', 12, cast(isnull(a.Rrn,0)  as nvarchar (15)))
			+ dbo.PadLeft( '0', 8, cast(a.PaymtCardPrefix as nvarchar (8)))
	from udiE_Txn a (nolock) 
	where a.IssNo = @IssNo and a.BatchId = @BatchId


	--Construct Product Record 	
	insert into #Trxn (Ind,TxnId, ParentSeqNo, SeqNo, String) 
	select	3, a.TxnId, a.ParentSeqNo, a.SeqNo, 
			'P'	+ dbo.PadLeft( '0', 10, a.SeqNo)
			+ dbo.PadLeft( '0', 10, a.ParentSeqNo)
			+ dbo.PadLeft( '0', 12, a.TxnId)
			+ dbo.PadLeft( '0', 12,a.TxnSeq)
			+ dbo.PadRight( char(32), 6,a.ProdCd)
			+ dbo.PadLeft( '0', 11, replace(cast(a.SettleTxnAmt as nvarchar(11)), '.', ''))
			+ dbo.PadLeft( '0', 11, replace(cast(a.Pts as nvarchar(11)), '.', ''))
			+ dbo.PadLeft( '0', 11, replace(cast(a.PromoPts as nvarchar(11)), '.', ''))
			+ dbo.PadLeft( '0', 11, replace(cast(a.Qty as nvarchar(11)), '.', ''))
	from udiE_TxnDetail a (nolock) 
	where a.IssNo = @IssNo and  a.BatchId = @BatchId 

	-- Construct Trailer Record 
	insert into #Trxn (Ind, String) 
	select 4 , 'T' + dbo.PadLeft( '0', 10, cast(count(*) as varchar(10))) from #Trxn


	-- Construct all file content
	insert into #result(string)
	select String from #Trxn where Ind = 1  
	insert into #result(string)
	select String from #Trxn where Ind in (2,3) order by  TxnId, Ind, ParentSeqNo, SeqNo
	insert into #result(string)
	select String from #Trxn where Ind = 4


	select string from #result order by Id

	exec TraceProcess @IssNo, @PrcsName, 'End'

	drop table #Trxn
	drop table #result

	return 0
end
GO
