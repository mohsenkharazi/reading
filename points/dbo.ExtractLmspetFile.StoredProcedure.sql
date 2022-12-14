USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ExtractLmspetFile]    Script Date: 9/6/2021 10:33:55 AM ******/
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
2016/10/30	Humairah		Initial Development
**************************************************************************************************************************/
--exec ExtractLmspetFile 1,NULL, NULL
---begin--
		--select * from aaaaa_UserData
		--select * from aaaaa_TerminatedDealer
--		drop table  #udiE_DirectCredit
--		drop table  tmp_udiE_DirectCredit
----
--		alter table aaaaa_UserData add Remarks nVarchar(500)
--		alter table aaaaa_UserData add BusnLocation nVarchar(20)
--		alter table aaaaa_UserData add BankAcctNo nVarchar(20)
--		alter table aaaaa_UserData add HandoverDate nVarchar(50)

		--update a 
		--	set a.BusnLocation = b.BusnLocation,
		--		a.BankAcctNo = b.BankAcctNo
		--from aaaaa_UserData a 
		--left outer join aac_busnlocation b (nolock) on b.SapNo = a.SapNo 

		--update a set a.HandoverDate  = b.HandoverDate
		--from aaaaa_UserData a 
		--join aaaaa_TerminatedDealer b (nolock) on b.MID = a.BusnLocation 

		--update  aaaaa_UserData set Remarks = 'OK' where BusnLocation is not null and HandoverDate is NULL
		--update  aaaaa_UserData set Remarks = 'Station Terminated' where HandoverDate is not NULL 
		--update  aaaaa_UserData set Remarks = 'Unable to identify MID based on given SAP No' where BusnLocation is null

		--select a.Station, a.SAPNo, a.RM, a.BusnLocation, a.BankAcctNo , '|' as '|', b.MID, b.DealerName, b.BankAcctNo'BankAcctNo2', b.HandoverDate, 
		--		case when a.Remarks is not null then a.Remarks else 'MID unmatch' end 'Remarks'
		--into #report
		--from aaaaa_UserData a full outer  join aaaaa_TerminatedDealer b on  b.MID = a.BusnLocation 

		--select Remarks, count(*) from #report group by remarks 

		--select 1'IssNo', 999'BatchId', '50'as 'TxnId', b.AcctNo, a.BusnLocation, a.RM'Amt', a.RM'BillingAmt', a.Station'BusnName', 
		--		convert(varchar, getdate(), 112)'PrcsDate',	convert(varchar, getdate(), 112)'TxnDate', a.BankAcctNo, b.BankName, NULL'RefNo1', NULL'RefNo2', 
		--		999'PrcsId', '00' as 'RespCd'
		--into #udiE_DirectCredit
		--from aaaaa_UserData a 
		--join aac_busnLocation  b (nolock) on b.BusnLocation = a.BusnLocation 
		--where a.HandoverDate is null

		--insert into #udiE_DirectCredit
		--select IssNo,BatchId,'10' as'TxnId',AcctNo,BusnLocation,Amt,BillingAmt,BusnName,PrcsDate,TxnDate,'514495128875' as'BankAcctNo',BankName,RefNo1,RefNo2,PrcsId,RespCd
		--from #udiE_DirectCredit
	
		--select * from #udiE_DirectCredit  order by  BusnLocation

		--select identity(int,1,1) as 'SeqNo', * into tmp_udiE_DirectCredit from #udiE_DirectCredit order by  BusnLocation, TxnId

		--select * from tmp_udiE_DirectCredit order by seqno

--	-end--

CREATE PROCEDURE [dbo].[ExtractLmspetFile]
		@IssNo uIssNo,
		@PrcsId uPrcsId,
		@Out varchar(200) output
as
--with encryption as
begin
	
	declare @Path varchar(50), @RunNo int, @BatchId uBatchId, @RecCnt int, @PrcsDate varchar(10),@FileName varchar(50),@FileExt varchar(10),@MySpecialTempTable varchar(100), 
			@Detail varchar(MAX),@Trailer varchar(100),@Command varchar(500),@Unicode int, @DestName int, @TotDrAmt money,@TotCrAmt money,@TotDrItem int,@TotCrItem int,
			@RedmpID  varchar(19),@SeqNo  int,@UserRef bigint,@Count int,@RESULT int

	create table #OddEven (BankAcctNo varchar(12),SeqNo int,TxnId int, Amount money,OddPart int, EvenPart int)
	create table temp_lmspetFile (Seq int identity(1,1), String varchar(max))
	
	SET NOCOUNT ON

	select	@BatchId = 999, 
			@Unicode = NULL, 
			@RunNo = 999, 
			@RecCnt = 0,
			@FileExt = '.txt',
			@Path = 'E:\' 

	select top 1  @PrcsDate = PrcsDate from tmp_udiE_DirectCredit
	select @FileName = 'lmspet_' + @PrcsDate 	
	select @Out = @Path + @FileName + @FileExt


	select @TotDrItem = count(*) , @TotDrAmt = Sum(cast(BillingAmt as numeric(18,2)))
	from  tmp_udiE_DirectCredit a (nolock) 
	where a.BatchId = @BatchId and TxnId = 50

	select @TotCrItem  = count(*), @TotCrAmt = Sum(cast(BillingAmt as numeric(18,2)))
	from tmp_udiE_DirectCredit a (nolock) 
	where a.BatchId = @BatchId and TxnId = 10

	--select a.BillingAmt,replace(a.BillingAmt,'.','')'AMOUNT', cast (a.BillingAmt as numeric(18,2))from tmp_udiE_DirectCredit a

	Insert #OddEven ---  SeqNo 
	select 	BankAcctNo as 'BankAcctNo',cast(SeqNo as int) as 'SeqNo' ,TxnId as 'TxnId',cast(BillingAmt as numeric(18,2)) as 'Amount',
			convert(int,substring (cast(BankAcctNo as varchar),1,1)) + convert(int,substring (cast(BankAcctNo as varchar),3,1)) + convert(int,substring (cast(BankAcctNo as varchar),5,1)) + 
			convert(int,substring (cast(BankAcctNo as varchar),7,1)) + convert(int,substring (cast(BankAcctNo as varchar),9,1)) + convert(int,substring (cast(BankAcctNo as varchar),11,1)) as 'OddPart',
			convert(int,substring (cast(BankAcctNo as varchar),2,1)) + convert(int,substring (cast(BankAcctNo as varchar),4,1)) + convert(int,substring (cast(BankAcctNo as varchar),6,1)) + 
			convert(int,substring (cast(BankAcctNo as varchar),8,1)) + convert(int,substring (cast(BankAcctNo as varchar),10,1)) + convert(int,substring (cast(BankAcctNo as varchar),12,1)) as 'EvenPart'
	from tmp_udiE_DirectCredit  order by cast(SeqNo as int)
	
	-----------------
	begin transaction
	-----------------
	 
	--Create Header
		insert into temp_lmspetFile (String)
			select	'04' --HEADER ID 
			+ dbo.padleft(0,3,cast(@RunNo as varchar)) --RUNNING NUMBER
			+ convert(varchar,@PrcsDate,112) --POSTING DATE, Format YYYYMMDD. 
			+cast('514495128875' as varchar) --PETRONAS MAIN ACCOUNT
			+replicate(' ',55)
			as String

		if @@error <> 0 
		begin
			rollback transaction
			return 1000
		end

	--Create Details
		select distinct	cast(a.TxnId as varchar) 'TRANSACTION_ID'
				,a.BankAcctNo'ACCOUNT_NUMBER'
				,cast(a.SeqNo as int) as 'SEQUENCE_NUMBER'  
				,replace(cast(a.BillingAmt as numeric(18,2)) ,'.','')'AMOUNT'
				,(((b.OddPart * 3) + (b.EvenPart * 5) + b.TxnId) + ((b.Amount*100 + b.SeqNo) * 7 + (b.OddPart * 3))) 'CONTROL_VALUE'
				,a.BusnLocation 'USER_REFERENCE'
			into #temp_file
			from tmp_udiE_DirectCredit a (nolock) 
			join #OddEven b (nolock) on b.BankAcctNo = a.BankAcctNo and b.SeqNo = a.SeqNo
			where a.BatchId = @BatchId 
			order by cast(a.SeqNo as int)

		if @@error <> 0 
		begin
			rollback transaction
			return 1001
		end

		alter table #temp_file alter column SEQUENCE_NUMBER int 
		create index ix_SeqNo on  #temp_file(SEQUENCE_NUMBER)
	
		insert into temp_lmspetFile(String)
			select  cast (a1.String as text)
				from (			
					select
							cast(TRANSACTION_ID as varchar) --TRANSACTION ID
							+ dbo.padleft(0,12,cast(ACCOUNT_NUMBER as varchar))--ACCOUNT NUMBER  
							+ dbo.padleft(0,6,cast(SEQUENCE_NUMBER as varchar))--SEQUENCE NUMBER  
							+ dbo.padleft(0,12,cast(replace(AMOUNT,'.','') as varchar)) --AMOUNT 
							+ dbo.padleft(0,12,cast(replace(CONTROL_VALUE,'.00','') as varchar))--CONTROL VALUE
							+ dbo.padright(' ',30,cast(USER_REFERENCE as varchar))--USER REFERENCE 
							+'00' --RESPONSE CODE 
							+ replicate(' ',4)	--SPACES (x4)		
							as 'String', SEQUENCE_NUMBER
					from #temp_file )a1  order by  a1.SEQUENCE_NUMBER
		if @@error <> 0 
		begin
			rollback transaction
			return 1003
		end
		
	--Create Trailer
		insert into temp_lmspetFile (String)
		select '92' --TRAILER ID 
			+ dbo.padleft(0,6,cast(@TotDrItem as varchar)) --TOTAL DEBIT ITEM 
			+ dbo.padleft(0,6,cast(@TotCrItem  as varchar)) --TOTAL CREDIT ITEM 
			+ dbo.padleft(0,12,cast(replace(@TotDrAmt,'.','')  as varchar)) --TOTAL DEBIT AMOUNT 
			+ dbo.padleft(0,12,cast(replace(@TotCrAmt,'.','')  as varchar)) --TOTAL CREDIT AMOUNT
			+ dbo.padleft(0,12,sum(cast(CONTROL_VALUE as bigint))) --TRAILER CONTROL VALUE 
			+ replicate(' ',30)
		from #temp_file
	
		if @@error <> 0 
		begin
			rollback transaction
			return 1004
		end
		
	--------------	
	commit Transaction
	----------------
		
	select String from temp_lmspetFile order by Seq

	select * from tmp_udiE_DirectCredit where seqno = 137

	drop table #temp_file
	drop table temp_lmspetFile
	drop table #OddEven
	
	return 99
end
GO
