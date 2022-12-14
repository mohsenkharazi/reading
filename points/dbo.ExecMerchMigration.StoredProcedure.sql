USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ExecMerchMigration]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [dbo].[ExecMerchMigration]
	
  as
begin
	
	declare @BusnLocation varchar(25), @rc int

	---------------------------------------
	-- Merchant Account Declaration
	---------------------------------------

	declare @AcqNo int, 
			@AcctNo uAcctNo,
			@AgreeNo varchar(10),
			@AgreeDate datetime,	--Agreement No
			@BankName uRefCd,
			@CorpCd uRefCd, 
			@ReasonCd uRefCd,
			@PersonInChrg nvarchar(50),
			@Ownership uRefCd,
			@Establishment uRefCd,
			@Sic uRefCd,
			@Mcc uRefCd,
			@CreatedBy uUserId,
			@CreateDate varchar(10), 
			@CoRegNo nvarchar(15),
			@BankAcctNo uBankAcctNo,
			@PayeeName uPayeeName,
			@MerchAutoDebit uYesNo,
			@AutoDebit uYesNo,
			@Sts uRefCd,
			@EntityId uEntityId,
			@CoRegName nvarchar(50),
			@TaxId nvarchar(20),
			@BranchCd varchar(15),
			@WithholdInd uYesNo,
			@WithholdRate money,
			@AcctType uRefCd,
			@AcctSts uRefCd
		
	-- Busnlocation 
	declare @BusnName uBusnName

	-- Contact Detail
	declare @ContactNo varchar(15),
			@ContactPerson varchar(50),
			@MobileNo varchar(25),
			@EmailAddr varchar(100)

	-- Adress Detail
	declare @Street1 varchar(150), @State uRefCd
	
	-- Busn Location
	declare @StmtPrint char(1),
			@SiteId nvarchar(15), 
			@DBAName nvarchar(50), @DBACity uRefCd, @DBAState uRefCd, @DBARegion uRefCd, @DealerAcctNo uAcctNo

	-------------------------------
	-- Default Value
	-------------------------------

	select @AcqNo = 1, @AgreeNo = null, @AgreeDate = null, @CorpCd = 'PDB', @SIC = 'G' /* General */, @MCC = '5541', /*Service Station*/
			@MerchAutoDebit = 'Y' , @TaxId = 0
	-- select top 10 * From udii_BUsnLOcation		

	declare @Counter integer

	select @Counter = 0

	while(1=1)
	begin
		
		--------------------------------------
		-- Create Merchant Account
		--------------------------------------
-- select * from iss_RefLib where reftype like '%sts%'

		select top 1 
				@BusnLocation = SXMID, @BusnName = SiteName, @CoRegName = SiteTradingName, @SiteId = SiteId,
				@AcctSts = case 
							when ACTIVATE = '11' then 'A'
							when ACTIVATE = '21' then 'A'
							when ACTIVATE = '99' then 'A'
							end,  
				@BankName = case 
							when upper(PayeeBankName) = 'MAYBANK' then 'MBB'
							when upper(PayeeBankName) = 'MBB' then 'MBB'							 
							when upper(PayeeBankName) = 'PBB' then 'PBB'
							when upper(PayeeBankName) = 'NA' then 'NA'
						end,
				@BranchCd = PayeeBankBranchCode,@BankAcctNo = PayeeBankAcctNum,
				@PersonInChrg = ContactPerson, @ContactPerson = ContactPerson, @ContactNo = ContactPhone, @MobileNo = SiteHandPhone, @EmailAddr = SiteEmail,
				@Street1 = SiteAddr, 				
				@State = case 
							when upper(SiteStateCode) = 'JHR' then '01'
							when upper(SiteStateCode) = 'KDH' then '02'						
							when upper(SiteStateCode) = 'KEL' then '03'
							when upper(SiteStateCode) = 'MLK' then '04'						
							when upper(SiteStateCode) = 'NS'  then '05'
							when upper(SiteStateCode) = 'PER' then '06'						
							when upper(SiteStateCode) = 'PHG' then '07'
							when upper(SiteStateCode) = 'PNG' then '08'						
							when upper(SiteStateCode) = 'PRK' then '09'
							when upper(SiteStateCode) = 'SBH' then '10'						
							when upper(SiteStateCode) = 'SGR' then '11'
							when upper(SiteStateCode) = 'SWK' then '12'						
							when upper(SiteStateCode) = 'TRG' then '13'
							when upper(SiteStateCode) = 'WP'  then '14'						
							when upper(SiteStateCode) = 'WPL' then '15'
							when upper(SiteStateCode) = 'WPP' then '16'
						end									
		from udii_BusnLocation where PrcsSts is null --and SXMID = '890070087333686' -- and SXMID = '888888888888888'

		if @@rowcount <= 0
			break

--		select @AcqNo '@AcqNo', @BusnLocation '@BusnLocation', @BusnName '@BusnName', @CoRegName 'CoRegName',
--			@AcctNo '@AcctNo', @AgreeNo '@AgreeNo', @AgreeDate '@AgreeDate', 
--			@BankName '@BankName', @BranchCd '@BranchCd', @BankAcctNo '@BankAcctNo',
--			@ContactPerson '@ContactPerson', @ContactNo '@ContactNo', @MobileNo '@MobileNo', 
--			@Street1 '@Street1', @State '@State' 

		exec @rc = MerchAcctMigrationInsert 
					@AcqNo,
					@AcctNo output,					
					@CoRegName,	-- @BusnName	-- Requested by 
					@AgreeNo,
					@AgreeDate,
					@BankName,
					@CorpCd, 
					@ReasonCd,
					@PersonInChrg,
					@Ownership,
					@Establishment,
					@Sic,
					@Mcc,
					@CreatedBy,
					@CreateDate, 
					@CoRegNo,
					@BankAcctNo,
					@PayeeName,
					@AutoDebit,
					@AcctSts,
					@EntityId output,
					@CoRegName,
					@TaxId,
					@BranchCd, --uBranchCd
					@WithholdInd,
					@WithholdRate,
					@AcctType,
					@ContactNo,					
					@MobileNo,
					@EmailAddr,
					@Street1, 
					@State

 -- select @Rc 'RC', @BusnLocation 'BusnLocation', @EntityId 'EntityId'
					
		-- Update Process
		update udii_BusnLocation set 
			PrcsSts = 'M', 
			MsgCd = @rc
		where SXMID = @BusnLocation

		----------------------------------------------
		-- Create BusnLocation
		----------------------------------------------
		select @DBAName = @BusnName, @DBACity = @State, @TaxId = isnull(@TaxId, 0)

-- select @DBAName '@DBAName', @DBACity '@DBACity', @AcctSts '@Sts'


			exec @rc = BusnLocationMigrationInsert	
					@AcqNo,	
					@BusnLocation,
					@AcctNo output,
					@BusnName,
					@AgreeNo,
					@AgreeDate,
					@BankName,
					@ReasonCd,
					@PersonInChrg,
					@Ownership,
					@Sic,
					@Mcc,
					@CreatedBy,
					@CreateDate, 
					@CoRegNo, 
					@BankAcctNo,
					@PayeeName,
					@MerchAutoDebit,
					@StmtPrint,
					@SiteId,
					@EntityId output,
					@BranchCd,
					@DBAName,
					@DBACity,
					@DBAState,
					@DBARegion,
					@CoRegName,
					@TaxId,
					@AcctType,
					@DealerAcctNo,

					@ContactNo,	
					@MobileNo,
					@EmailAddr,

					@Street1, 
					@State,
					@AcctSts

-- select @Rc 'BUSNLOCATION', @EntityId 'EntityId'

		-- Update Process
		update udii_BusnLocation set 
				PrcsSts = 'A',
				MsgCd = @rc
		where SXMID = @BusnLocation
		
		-- Reset variable
		select @AcctNo = null
		
-----------
 -- break
--		select @Counter = @Counter + 1
--			if @Counter = 1 break
-----------

	end

	---------------------------------------------
	-- Update Test Merchant Auto Debit Ind
	---------------------------------------------

	update aac_BusnLocation set AutoDebitInd = 'N' where BusnLocation = '888888888888888'			

	---------------------------------------------
	-- Update Merch Acct Status
	---------------------------------------------

	update a set
		Sts =	case when ACTIVATE = '11' then 'A'
							when ACTIVATE = '21' then 'I'
							when ACTIVATE = '99' then 'D'
				end
--	select busnlocation, case when ACTIVATE = '11' then 'A' when ACTIVATE = '21' then 'A' when ACTIVATE = '99' then 'A' end 
	from aac_BusnLocation a 
	join udii_BusnLocation b on b.SXMID = a.BusnLocation
		
	----------------------------------------------
	-- Update Merch Acct Status
	----------------------------------------------

	update c set
		Sts =	case when ACTIVATE = '11' then 'A'
							when ACTIVATE = '21' then 'I'
							when ACTIVATE = '99' then 'D'
				end
--	select c.acctno, busnlocation, case when ACTIVATE = '11' then 'A' when ACTIVATE = '21' then 'A' when ACTIVATE = '99' then 'A' end 
	from aac_BusnLocation a 
	join udii_BusnLocation b on b.SXMID = a.BusnLocation
	join aac_Account c on c.AcctNo = a.AcctNo
	
	
	----------------------------------------------
	-- Create Merchant Terminal
	----------------------------------------------
-- select * from iss_Reflib where reftype like '%sts%'	

	insert into atm_TerminalInventory(TermId, BusnLocation, DeviceType, AcqNo, Sts, TermSrc)
	select SXTID, SXMID, b.TxnSource, @AcqNo, case when b.ACTIVATE = '11' then 'A'
							when b.ACTIVATE = '21' then 'S'
							when b.ACTIVATE = '99' then 'T'
				end, b.TxnSource
	from aac_BusnLocation a 
	join udii_Terminal b on b.SXMID = a.BusnLocation
	
	------------------------------------------------
	-- Create Merchant Card Acceptance
	-------------------------------------------------

	create table #CardRange
	(
		CardRangeId nvarchar(10)				
	)

	insert into #CardRange select 'PDBMLG'
	insert into #CardRange select 'PDBMLF'
	insert into #CardRange select 'PDBMLS'
	insert into #CardRange select 'PDBMLT'

	truncate table acq_CardRangeAcceptance

	insert into acq_CardRangeAcceptance(AcqNo, BusnLocation, CardRangeId, UserId, LastUpdDate)
	select @AcqNo, a.BusnLocation, b.CardRangeId, system_user, getdate()
	from aac_BusnLocation a
	join #CardRange b on 1=1
	order by a.BusnLocation

	
	----------------------------------------------
	-- Create Merchant Txn Code Mapping
	----------------------------------------------
	declare @TempBusnLocation uMerchNo

	select top 1 @TempBusnLocation = BusnLocation 
	from aac_BusnLocation (nolock)

	create table #TxnCdMap
	(
		AcctNo bigint,
		BusnLocation varchar(15),
		MsgType smallint,
		PrcsCd int,
		CardRangeId nvarchar(10) null,
		TxnCd int null
	)

	if @@error <> 0 return 70270	--Failed to create temporary table
	
	insert #TxnCdMap
	( AcctNo, BusnLocation, MsgType, PrcsCd, CardRangeId )
	select c.AcctNo, c.BusnLocation, c.MsgType, PrcsCd, d.CardRangeId
	from (select a.AcctNo, a.BusnLocation, b.MsgType, b.PrcsCd
		from aac_BusnLocation a 
		cross join acq_MessageHandle b
		where a.AcqNo = b.AcqNo and a.BusnLocation = @TempBusnLocation ) c
	cross join acq_CardRangeAcceptance d
	where c.BusnLocation = d.BusnLocation

	if @@error <> 0 return 70271	--Failed to insert into temporary table

	-- Default setting for balance enquiry
	update #TxnCdMap
	set TxnCd = 102
	where (MsgType = 100 and PrcsCd = 100000)

	if @@error <> 0 return 70281	--Failed to update temporary table

	-- Default setting for pre-auth
	update #TxnCdMap
	set TxnCd = 100
	where (MsgType = 100 and PrcsCd = 300000)

	if @@error <> 0 return 70281	--Failed to update temporary table

	-- Default setting for pre-auth completion
	update #TxnCdMap
	set TxnCd = 220
	where (MsgType in (220, 221) and PrcsCd = 0)

	if @@error <> 0 return 70281	--Failed to update temporary table

	-- Default setting for sales
	update #TxnCdMap
	set TxnCd = 200
	where (MsgType = 200 and PrcsCd = 400000) or (MsgType in (320,321) and PrcsCd = 400000) or (MsgType in (320,321) and PrcsCd = 400001) 

	-- Default setting for redemption
	update #TxnCdMap
	set TxnCd = 700
	where (MsgType = 200 and PrcsCd = 0) or (MsgType in (320,321) and PrcsCd = 0) or (MsgType in (320,321) and PrcsCd = 1) 

	if @@error <> 0 return 70281	--Failed to update temporary table

	-- Default setting for settlement
	update #TxnCdMap
	set TxnCd = 500
	where (MsgType in (500, 501) and PrcsCd in (920000)) or (MsgType in (500, 501) and PrcsCd in (960000))

	if @@error <> 0 return 70281	--Failed to update temporary table

	-- Default setting for sales contra
--	update #TxnCdMap
--	set TxnCd = 700
--	where (MsgType in (320, 321, 200) and PrcsCd = 0) or (MsgType = 400 and PrcsCd = 20000)
--
--	if @@error <> 0 return 70281	--Failed to update temporary table

	-- Default setting for void reversal redemption
	update #TxnCdMap
	set TxnCd = 700
	where (MsgType = 400 and PrcsCd = 20000)

	if @@error <> 0 return 70281	--Failed to update temporary table

	-- Default setting for redemption contra & void redemption
	update #TxnCdMap
	set TxnCd = 708
	where (MsgType = 200 and PrcsCd = 20000) 
	or (MsgType in (400, 401) and PrcsCd = 0) or (MsgType in (400, 401) and PrcsCd = 300000)

	if @@error <> 0 return 70281	--Failed to update temporary table	

	-- INSERT to Transaction Code Mapping
	insert into acq_TxnCodeMapping(AcqNo, AcctNo, BusnLocation, MsgType, PrcsCd, CardType, CardRangeId, TxnCd, UserId, LastUpdDate, Sts)
	select @AcqNo, c.AcctNo, b.BusnLocation, a.MsgType, a.PrcsCd, null, a.CardRangeId, a.TxnCd, system_user, getdate(), 'A'
	from #TxnCdMap a 
	join aac_BusnLocation b on 1=1
	join aac_Account c on c.AcctNo = b.AcctNo

--	insert #TxnCdMap
--	( AcctNo, BusnLocation, MsgType, PrcsCd )
--	select a.AcctNo, a.BusnLocation, b.MsgType, b.PrcsCd
--	from aac_BusnLocation a 
--	cross join acq_MessageHandle b
--	where a.AcqNo = b.AcqNo and b.MsgType in (500, 501)
--	order by a.BusnLocation

	if @@error <> 0 return 70271	--Failed to insert into temporary table
/**/

	-------------------------------------
	-- DROP ALL TEMP TABLE
	-------------------------------------
	
	drop table #CardRange
	drop table #TxnCdMap


end
GO
