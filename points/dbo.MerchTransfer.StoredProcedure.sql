USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchTransfer]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:Cardtrend Systems Sdn. Bhd.
Modular		:Cardtrend Card Management System (CCMS)- Acquiring Module

Objective	:Merch transfer
-------------------------------------------------------------------------------
When	   Who		CRN		Description
2003/11/27 Sam				Populate txn cd mapping to in-hse & general by merch category.
2003/12/03 Sam				Fixes.
-------------------------------------------------------------------------------
*******************************************************************************/

CREATE  procedure [dbo].[MerchTransfer]
	@AcqNo uAcqNo
as
begin
	declare @Seq smallint, @AcctNo uAcctNo, @SysDate datetime, @EntityId uEntityId,
			@AcctCnt int, @BusnCnt int, @AcctAddr int, @BusnAddr int, @TaxId nvarchar(15),
			@AcctCont int, @BusnCont int,  @TxnCdCnt int, @CardRangeCnt int, @Acct uAcctNo,
			@BusnLocation varchar(15)

	set nocount on

	create table #Acct
	(
		HQTaxId varchar(15) not null,
		TxnSeq int null,
		AcctNo bigint null,
		EntityId int null
	)

	create table #AcctCreate
	(
		AcctNo bigint null,
		BusnLocation varchar(15) null,
		EntityId int null
	)

	create table #AcctEntity
	(
		AcctNo bigint,
		EntityId int null
	)

	create table #CardRange
	(
		AcctNo int,
		BusnLocation varchar(15),
		CardRangeId varchar(15),
		CardCategory varchar(5),
		Sic varchar(5) null,
		MsgType smallint null,
		PrcsCd int null	
	)

	create table #TxnCdMapping
	(
		AcctNo int,
		BusnLocation varchar(15),
		MsgType smallint,
		PrcsCd int,
		CardRangeId varchar(15) null,
		TxnCd int null,
		CardCategory varchar(15) null,
		Sic varchar(5) null
	)

	select @SysDate = getdate()
	select @AcqNo = isnull(@AcqNo, 1)

	update x_Merch
	set BankAcctType = null
	where BankAcctType = '00'

	update x_Merch
	set xCorpCd = case when CorpCd = 'PT' then 'PTT'
					when CorpCd = 'BG' then 'BCP'
					else null
				  end

	update x_Merch
	set WithholdingTaxInd = 'N'
	where WithholdingTaxInd is null

	update x_Merch
	set ContactName = ltrim(DBAName)
	where ContactName is null

	update x_Merch
	set xAutoDebit = case when BranchCd = '00000' then 'N'
						else 'Y'
					 end

	update x_Merch
	set BranchCd = replicate('0',5 - len(BranchCd)) + BranchCd
	where BranchCd is not null and isnumeric(BranchCd) = 1 and len(BranchCd) < 5

	update x_Merch
	set DirectDebitAcct = replicate('0',15 - len(DirectDebitAcct)) + DirectDebitAcct
	where DirectDebitAcct is not null and isnumeric(DirectDebitAcct) = 1 and len(DirectDebitAcct) < 10

	--2003/12/03B
	update x_MerchAddr
	--set MailingInd = case when AddrType = '22' then 'Y'
	set MailingInd = case when AddrType = '21' then 'Y'
						else 'N'
					 end
	--2003/12/03E

	update a
	set xDBACity = RefCd
	from x_Merch a
	join iss_RefLib b on a.DBACity = b.Descp and RefType = 'City' and RefNo = 764

	select @Seq = min(TxnSeq) from x_Merch where HQTaxId = '000000000000000' and TaxId = '000000000000000'
	while @Seq is not null
	begin
		exec GetMerchAccountNo @AcqNo, @AcctNo output
		if @@error <> 0 
		begin
			select 'check txnseq ', @Seq
			return 1
		end

		exec GetEntity @AcqNo, null, @EntityId output
		if @@error <> 0
		begin
			select 'failed to gen. entity'
			return 1
		end

		update x_Merch
		set xEntityId = @EntityId, AcctNo = @AcctNo where TxnSeq = @Seq

		if @@error <> 0
		begin
			select 'check txnseq ', @Seq
			return 1
		end

		select @Seq = min(TxnSeq) from x_Merch where TxnSeq > @Seq and HQTaxId = '000000000000000' and TaxId = '000000000000000'
	end

	select TaxId, convert(int, null) 'AcctNo' into #TaxIdAcct
	from x_Merch where TaxId <> '000000000000000' and AcctNo is null
	group by TaxId
	order by TaxId

	if @@rowcount = 0 or @@error <> 0
	begin
		select '0 count for #TaxIdAcct'
		return 1
	end

	select @TaxId = min(TaxId) from #TaxIdAcct
	while @TaxId is not null
	begin
		exec GetMerchAccountNo @AcqNo, @AcctNo output
		if @@error <> 0 
		begin
			select 'check txnseq ', @Seq
			return 1
		end	

		update #TaxIdAcct
		set AcctNo = @AcctNo where TaxId = @TaxId

		if @@error <> 0
		begin
			select 'check txnseq ', @Seq
			return 1
		end

		select @TaxId = min(TaxId) from #TaxIdAcct where TaxId > @TaxId
	end

	update a
	set AcctNo = b.AcctNo
	from x_Merch a
	join #TaxIdAcct b on a.TaxId = b.TaxId

	if @@error <> 0
	begin
		select 'update x_merch acctno failed'
		return 1
	end

	update a
	set AcctNo = b.AcctNo
	from x_Merch a
	join (select BusnLocation, AcctNo from x_Merch where HQTaxId = '000000000000000') b on a.HQTaxId = b.BusnLocation
	where a.HQTaxId <> '000000000000000'

	if @@error <> 0
	begin
		select 'update x_Merch err'
		return 1
	end

	select @Seq = min(TxnSeq) from x_Merch where HQTaxId <> '000000000000000'
	while @Seq is not null
	begin
		exec GetEntity @AcqNo, null, @EntityId output
		if @@error <> 0
		begin
			select 'failed to gen. entity'
			return 1
		end

		update x_Merch
		set xEntityId = @EntityId where TxnSeq = @Seq

		if @@error <> 0
		begin
			select 'check txnseq ', @Seq
			return 1
		end

		select @Seq = min(TxnSeq) from x_Merch where HQTaxId <> '000000000000000' and TxnSeq > @Seq
	end

	select @Seq = null
	select @Seq = min(TxnSeq) from x_Merch where AcctNo is not null
	while @Seq is not null
	begin
		if not exists (select 1 from #AcctCreate a join (select AcctNo, BusnLocation from x_Merch where TxnSeq = @Seq) b on a.AcctNo = b.AcctNo)
		begin
			insert #AcctCreate
			(AcctNo, BusnLocation)
			select AcctNo, BusnLocation
			from x_Merch where TxnSeq = @Seq

			if @@error <> 0
			begin
				select 'write #acctcreate failed'
				return 1
			end
		end

		select @Seq = min(TxnSeq) from x_Merch where TxnSeq > @Seq and AcctNo is not null
	end

	select @Acct = null
	select @Acct = min(AcctNo) from #AcctCreate
	while @Acct is not null
	begin
		exec GetEntity @AcqNo, null, @EntityId output
		if @@error <> 0
		begin
			select 'failed to gen. entity'
			return 1
		end

		update #AcctCreate
		set EntityId = @EntityId where AcctNo = @Acct
		if @@error <> 0
		begin
			select 'check entity in #AcctCreate'
			return 1
		end

		select @Acct = min(AcctNo) from #AcctCreate where AcctNo > @Acct
	end

	select BusnLocation, convert(int, null) 'EntityId' into #Ent 
	from x_Merch where AcctNo is not null and xEntityId is null
	order by BusnLocation

	if @@error = 0
	begin
		select @BusnLocation = min(BusnLocation) from #Ent
		while @BusnLocation is not null
		begin
			exec GetEntity @AcqNo, null, @EntityId output
			if @@error <> 0
			begin
				select 'failed to gen. entity'
				return 1
			end

			update #Ent
			set EntityId = @EntityId where BusnLocation = @BusnLocation
			if @@error <> 0
			begin
				select 'check entity in #Ent'
				return 1
			end

			select @BusnLocation = min(BusnLocation) from #Ent where BusnLocation > @BusnLocation
		end

		update a
		set xEntityId = EntityId
		from x_Merch a
		join #Ent b on a.BusnLocation = b.BusnLocation
		where xEntityId is null
	end

/*	insert #Acct
	(HQTaxId)
	select HQTaxId
	from x_Merch where HQTaxId <> '000000000000000'
	group by HQTaxId

	if @@error <> 0
	begin
		select 'insert err #acct'
		return 1
	end

	insert #AcctEntity
	(AcctNo)
	select a.AcctNo from x_Merch a where a.HQTaxId = '000000000000000'
	group by a.AcctNo

	if @@error <> 0
	begin
		select 'insert err #acctentity'
		return 1
	end

	select @Acct = min(AcctNo) from #AcctEntity
	while @Acct is not null
	begin
		exec GetEntity @AcqNo, null, @EntityId output
		if @@error <> 0
		begin
			select 'failed to gen. entity'
			return 1
		end

		update #AcctEntity
		set EntityId = @EntityId where AcctNo = @Acct
		if @@error <> 0
		begin
			select 'check txnseq ', @Seq
			return 1
		end

		select @Acct = min(AcctNo) from #AcctEntity where AcctNo > @Acct
	end

	update a
	set TxnSeq = b.TxnSeq
	from #Acct a
	join (select min(TxnSeq) 'TxnSeq', HQTaxId from x_Merch where HQTaxId <> '000000000000000' group by HQTaxId) b on a.HQTaxId = b.HQTaxId

	if @@error <> 0
	begin
		select 'update err #Acct on TxnSeq'
		return 1
	end

	select @Seq = min(TxnSeq) from #Acct
	while @Seq is not null
	begin
		exec GetMerchAccountNo @AcqNo, @AcctNo output
		if @@error <> 0 
		begin
			select 'check txnseq', @Seq
			return 1
		end

		exec GetEntity @AcqNo, null, @EntityId output
		if @@error <> 0
		begin
			select 'failed to gen. entity'
			return 1
		end

		update #Acct
		set AcctNo = @AcctNo, EntityId = @EntityId where TxnSeq = @Seq
		if @@error <> 0
		begin
			select 'check txnseq ', @Seq
			return 1
		end

		select @Seq = min(TxnSeq) from #Acct where TxnSeq > @Seq
	end

	update a
	set AcctNo = b.AcctNo
	from x_Merch a
	join #Acct b on a.HQTaxId = b.HQTaxId

	if @@error <> 0
	begin
		select 'update err x_Merch from #Acct'
		return 1
	end
*/
	----------
	begin tran
	----------
select 'phase1...'
/*	insert aac_Account
	( AcqNo, AcctNo, CorpCd, BusnName, CoRegNo, AgreementNo, AgreementDate,
	CreationDate, CreatedBy, ReasonCd, AutoDebitInd, BankName, BankAcctNo, PayeeName,
	PersonInCharge, EntityId, Ownership, Mcc, Sic, BusnSize, Sts, CoRegName, TaxId, BranchCd,
	WithholdingTaxInd, WithholdingTaxRate, BankAcctType, MerchType )
	select
	@AcqNo, a.AcctNo, xCorpCd, DBAName, null, null, @SysDate,
	@SysDate, system_user, null, xAutoDebit, 'KTB', DirectDebitAcct, ltrim(ContactName),
	ltrim(ContactName), b.EntityId, null, Mcc, null, 'S', '1', TaxRegName, cast(TaxId as bigint), BranchCd,
	WithholdingTaxInd, 3.00, BankAcctType, MerchType
	from x_Merch a
	join #AcctEntity b on a.AcctNo = b.AcctNo
	where HQTaxId = '000000000000000'

	if @@error <> 0
	begin
		select 'insert err aac_Account'
		rollback tran
		return 1
	end

	insert aac_Account
	( AcqNo, AcctNo, CorpCd, BusnName, CoRegNo, AgreementNo, AgreementDate,
	CreationDate, CreatedBy, ReasonCd, AutoDebitInd, BankName, BankAcctNo, PayeeName,
	PersonInCharge, EntityId, Ownership, Mcc, Sic, BusnSize, Sts, CoRegName, TaxId, BranchCd,
	WithholdingTaxInd, WithholdingTaxRate, BankAcctType, MerchType )
	select
	@AcqNo, b.AcctNo, b.xCorpCd, b.DBAName, null, null, @SysDate,
	@SysDate, system_user, null, b.xAutoDebit, 'KTB', b.DirectDebitAcct, ltrim(b.ContactName),
	ltrim(b.ContactName), a.EntityId, null, b.Mcc, null, 'S', '1', b.TaxRegName, cast(b.TaxId as bigint), b.BranchCd,
	b.WithholdingTaxInd, 3.00, b.BankAcctType, b.MerchType
	from #Acct a
	join x_Merch b on a.TxnSeq = b.TxnSeq

	if @@error <> 0
	begin
		select 'insert err aac_Account from #Acct'
		rollback tran
		return 1
	end
*/
	insert aac_Account
	( AcqNo, AcctNo, CorpCd, BusnName, CoRegNo, AgreementNo, AgreementDate,
	CreationDate, CreatedBy, ReasonCd, AutoDebitInd, BankName, BankAcctNo, PayeeName,
	PersonInCharge, EntityId, Ownership, Mcc, Sic, BusnSize, Sts, CoRegName, TaxId, BranchCd,
	WithholdingTaxInd, WithholdingTaxRate, BankAcctType, MerchType, UserId, LastUpdDate )
	select
	@AcqNo, a.AcctNo, b.xCorpCd, b.DBAName, null, null, @SysDate,
	@SysDate, system_user, null, b.xAutoDebit, 'KTB', b.DirectDebitAcct, ltrim(b.ContactName),
	ltrim(b.ContactName), a.EntityId, null, b.Mcc, null, 'S', '1', b.TaxRegName, cast(b.TaxId as bigint), b.BranchCd,
	b.WithholdingTaxInd, 3.00, b.BankAcctType, b.MerchType, system_user, getdate()
	from #AcctCreate a
	join x_Merch b on a.BusnLocation = b.BusnLocation and b.AcctNo is not null
	where a.AcctNo is not null

	if @@error <> 0
	begin
		select 'insert err aac_Account from #Acct'
		rollback tran
		return 1
	end

	update aac_Account 
	set WithholdingTaxInd = 'N',
		WithholdingTaxRate = 0.00
	where WithholdingTaxInd <> 'Y'

	if @@error <> 0
	begin
		select 'update err aac_Account'
		rollback tran
		return 1
	end
	
	-- BEGIN : CP 20031104 -- update WithholdingTaxRate
	update aac_Account
	set WithholdingTaxRate = 0.00
	where TaxId = 0 or left(TaxId,1) = 1 or left(TaxId,1) = 2

	update aac_Account
	set WithholdingTaxRate = 3.00
	where left(TaxId, 1) = 3

	update aac_Account
	set WithholdingTaxRate = 1.00
	where left(TaxId, 1) = 4
	-- END

	update aac_Account
	set AutoDebitInd = 'Y'
	where BankAcctType is not null

	if @@error <> 0
	begin
		select 'update err aac_Account'
		rollback tran
		return 1
	end

	update aac_Account
	set AutoDebitInd = 'N'
	where BankAcctType is null

	if @@error <> 0
	begin
		select 'update err aac_Account'
		rollback tran
		return 1
	end
select 'phase2...'
	insert aac_BusnLocation
	( BusnLocation, AcqNo, AcctNo, BusnName, CoRegNo, AgreementNo, 
	AgreementDate, PartnerRefNo, CreationDate, CreatedBy, CancelDate,
	AutoDebitInd, BankName, BankAcctNo, PayeeName, PersonInCharge, EntityId,
	StmtPrintInd, Ownership, Mcc, Sic, BranchCd, DBAName, DBACity, DBAState, Sts, CoRegName, TaxId, BankAcctType, UserId, LastUpdDate )
	select
	'000001' + substring(BusnLocation, 7,9), @AcqNo, AcctNo, DBAName, null, null, 
	null, convert(nvarchar(15), TxnSeq), getdate(), system_user, null,
	'Y', 'KTB', DirectDebitAcct, ltrim(ContactName), ltrim(ContactName), xEntityId,
	'Y', null, Mcc, null, BranchCd, DBAName, xDBACity, State, '1', TaxRegName, cast(TaxId as bigint), BankAcctType, system_user, getdate()
	from x_Merch where AcctNo is not null

	if @@error <> 0
	begin
		select 'insert err aac_BusnLocation'
		rollback tran
		return 1
	end

	update aac_BusnLocation
	set BusnSize = case when Mcc = '5541' then 'C'
					when Mcc = '5542' then 'C'
					else 'S'
			       end

	if @@error <> 0
	begin
		select 'update err aac_BusnLocation'
		rollback tran
		return 1
	end

	update aac_BusnLocation
	set Sic = case when Mcc = '5541' then 'G'
					when Mcc = '5542' then 'G'
					else 'I'
			  end

	if @@error <> 0
	begin
		select 'update err aac_BusnLocation'
		rollback tran
		return 1
	end

	update a
	set TaxId = b.TaxId
	from aac_BusnLocation a
	join aac_Account b on a.AcqNo = b.AcqNo and a.AcctNo = b.AcctNo and isnull(b.TaxId,0) > 0
	where isnull(a.TaxId,0) = 0

	if @@error <> 0
	begin
		select 'update err aac_BusnLocation TaxId'
		rollback tran
		return 1
	end

	update a
	set CoRegName = b.CoRegName
	from aac_BusnLocation a
	join aac_Account b on a.AcqNo = b.AcqNo and a.AcctNo = b.AcctNo and isnull(b.CoRegName,'') <> ''
	where isnull(a.CoRegName,'') = ''

	if @@error <> 0
	begin
		select 'update err aac_BusnLocation RegName'
		rollback tran
		return 1
	end

select 'phase3...'
	insert aac_BusnLocationFinInfo
	( BusnLocation, LastUpdDate, FloorLimit)
	select '000001' + substring(BusnLocation, 7,9), @SysDate, isnull(cast(FloorLimit as money), 9999999.99) / 100.00
	from x_Merch where AcctNo is not null

	if @@error <> 0
	begin
		select 'insert err aac_BusnLocationFinInfo'
		rollback tran
		return 1
	end

	update aac_BusnLocationFinInfo
	set FloorLimit = 9999999.99 where isnull(FloorLimit,0) = 0

	if @@error <> 0
	begin
		select 'insert err aac_BusnLocationFinInfo flr lmt'
		rollback tran
		return 1
	end

select 'phase4...'
/*	insert iss_Address
	( IssNo, RefTo, RefKey, RefType, RefCd, Street1, Street2, Street3, State, ZipCd, Ctry, MailingInd )
	select
	@AcqNo, 'BUSN', '000001' + substring(MerchNo, 7,9), 'ADDRESS', AddrType, Addr1, Addr2, Addr3, 'TH', ZipCd, '764', case when AddrType = '21' then 'Y' else 'N' end
	from x_Merch a
	join x_MerchAddr b on a.BusnLocation = b.MerchNo
	where a.HQTaxId = '000000000000000'

	if @@error <> 0
	begin
		select 'insert err iss_Address'
		rollback tran
		return 1
	end */

	insert iss_Address
	( IssNo, RefTo, RefKey, RefType, RefCd, Street1, Street2, Street3, State, ZipCd, Ctry, MailingInd )
	select
	@AcqNo, 'BUSN', '000001' + substring(MerchNo, 7,9), 'ADDRESS', AddrType, Addr1, Addr2, Addr3, 'TH', ZipCd, '764', case when AddrType = '21' then 'Y' else 'N' end
	from x_MerchAddr a
	join x_Merch b on a.MerchNo = b.BusnLocation and b.AcctNo is not null

	if @@error <> 0
	begin
		select 'insert err iss_Address for busn'
		rollback tran
		return 1
	end

/*	insert iss_Address
	( IssNo, RefTo, RefKey, RefType, RefCd, Street1, Street2, Street3, State, ZipCd, Ctry, MailingInd )
	select
	@AcqNo, 'MERCH', convert(varchar(19), AcctNo), 'ADDRESS', AddrType, Addr1, Addr2, Addr3, 'TH', ZipCd, '764', case when AddrType = '21' then 'Y' else 'N' end
	from (select HQTaxId from x_Merch where HQTaxId <> '000000000000000' group by HQTaxId) c
	join x_Merch a on c.HQTaxId = a.HQTaxId
	join x_MerchAddr b on a.BusnLocation = b.MerchNo

	if @@error <> 0
	begin
		select 'insert err iss_Address'
		rollback tran
		return 1
	end */

	insert iss_Address
	( IssNo, RefTo, RefKey, RefType, RefCd, Street1, Street2, Street3, State, ZipCd, Ctry, MailingInd )
	select
	@AcqNo, 'MERCH', convert(varchar(19), AcctNo), 'ADDRESS', AddrType, Addr1, Addr2, Addr3, 'TH', ZipCd, '764', case when AddrType = '21' then 'Y' else 'N' end
	from x_MerchAddr a
	join #AcctCreate b on a.MerchNo = b.BusnLocation and b.AcctNo is not null

	if @@error <> 0
	begin
		select 'insert err iss_Address for merch'
		rollback tran
		return 1
	end

-- BEGIN - CP
	update b
	set Street1 = c.Street1, Street2 = c.Street2, Street3 = c.Street3, State = c.State, ZipCd = c.ZipCd, Ctry = c.Ctry, MailingInd = 'Y'
	from #AcctCreate a, iss_Address b, (select c1.RefKey, c1.RefCd, c1.Street1, c1.Street2, c1.Street3, c1.State, c1.ZipCd, c1.Ctry from iss_Address c1 where c1.RefTo = 'MERCH' and RefCd = 20) as  c
	where a.AcctNo = b.RefKey and b.RefKey = c.RefKey and b.RefTo = 'MERCH' and b.RefCd = 21 and isnull(b.Street1 , '') = ''

	update c
	set Street1 = d.Street1, Street2 = d.Street2, Street3 = d.Street3, State = d.State, ZipCd = d.ZipCd, Ctry = d.Ctry, MailingInd = 'Y'
	from #AcctCreate a, aac_BusnLocation b, iss_Address c, (select d1.RefKey, d1.RefCd, d1.Street1, d1.Street2, d1.Street3, d1.State, d1.ZipCd, d1.Ctry from iss_Address d1 where d1.RefTo = 'MERCH' and d1.RefCd = 21) as  d
	where a.AcctNo = b.AcctNo and b.BusnLocation = c.RefKey and c.RefTo = 'BUSN' and c.RefCd = 21 and a.AcctNo = d.RefKey
	and isnull(c.Street1, '') = ''


/*	update a
	set Street1 = c.Street1, Street2 = c.Street2, Street3 = c.Street3, State = c.State, ZipCd = c.ZipCd, Ctry = c.Ctry, MailingInd = 'Y'
	from iss_Address a, (select b.RefKey, b.RefCd, b.Street1, b.Street2, b.Street3, b.State, b.ZipCd, b.Ctry from iss_Address b where b.RefTo = 'MERCH' and RefCd = 20) as  c
	where a.RefKey = c.RefKey and a.REfTo = 'Merch' and a.RefType = 'ADDRESS' and a.RefCd = 21 and isnull(a.Street1, '') = ''

	update a
	set Street1 = c.Street1, Street2 = c.Street2, Street3 = c.Street3, State = c.State, ZipCd = c.ZipCd, Ctry = c.Ctry, MailingInd = 'Y'
	from iss_Address a, (select b.RefKey, b.RefCd, b.Street1, b.Street2, b.Street3, b.State, b.ZipCd, b.Ctry from iss_Address b where b.RefTo = 'BUSN' and RefCd = 20) as  c
	where a.RefKey = c.RefKey and a.REfTo = 'BUSN' and a.RefCd = 21 and isnull(a.Street1, '') = ''
*/
-- END

select 'phase5...'
	insert iss_Contact
	(IssNo, RefTo, RefKey, RefType, RefCd, ContactName, Occupation, ContactNo, Sts, EntityInd)
	select
	@AcqNo, 'BUSN', '000001' + substring(MerchNo, 7,9), 'CONTACT', ContactType, ltrim(b.ContactName), null, ContactNo, 'A', null
	from x_Merch a
	join x_MerchAddr b on a.BusnLocation = b.MerchNo
	where a.AcctNo is not null
--	where a.HQTaxId = '000000000000000' and a.AcctNo is not null

	if @@error <> 0
	begin
		select 'insert err iss_Contact'
		rollback tran
		return 1
	end

--********
--	insert into iss_Contact
--	(IssNo, RefTo, RefKey, RefType, RefCd, ContactName, Occupation, ContactNo, Sts, EntityInd)
--	select 
--	@AcqNo, 'BUSN', '000001' + substring(MerchNo, 7,9), 'CONTACT', ContactType, ltrim(b.ContactName), null, ContactNo, 'N', null
--	from x_Merch a
--	join x_MerchAddr b on a.BusnLocation = b.MerchNo
--	where a.HQTaxId <> '000000000000000' and a.AcctNo is not null

	insert into iss_Contact
	(IssNo, RefTo, RefKey, RefType, RefCd, ContactName, Occupation, ContactNo, Sts, EntityInd)
	select
	@AcqNo, 'MERCH', convert(varchar(19), AcctNo), 'CONTACT', ContactType, ltrim(a.ContactName), null, ContactNo, 'A', null
	from x_MerchAddr a
	join #AcctCreate b on a.MerchNo = b.BusnLocation and b.AcctNo is not null 



--*********
--	insert iss_Contact
--	(IssNo, RefTo, RefKey, RefType, RefCd, ContactName, Occupation, ContactNo, Sts, EntityInd)
--	select
--	@AcqNo, 'MERCH', convert(varchar(19), AcctNo), 'CONTACT', ContactType, ltrim(b.ContactName), null, ContactNo, 'N', null
--	from (select HQTaxId from x_Merch where HQTaxId <> '000000000000000' group by HQTaxId) c
--	join x_Merch a on c.HQTaxId = a.HQTaxId
--	join x_MerchAddr b on a.BusnLocation = b.MerchNo
--	where a.AcctNo is not null

	if @@error <> 0
	begin
		select 'insert err iss_Contact'
		rollback tran
		return 1
	end
select 'phase6...'
	insert atm_TerminalInventory
	( TermId, BusnLocation, AcqNo, DeviceType, Sts, DeployDate, PrinterInd, PinPadInd, LastBatchId, SrcCd, LastUpdDate, UserId)
	select
	convert(varchar(10), TermId + 3000000), BusnLocation, @AcqNo, 'E', 'A', @SysDate, 'N', 'N',  0, 'Owned', @SysDate, system_user
	from x_Term

	if @@error <> 0
	begin
		select 'insert err atm_TerminalInventory'
		rollback tran
		return 1
	end
select 'phase7...'
	insert into #CardRange
	(AcctNo, BusnLocation, CardRangeId, CardCategory, Sic)
	select a.AcctNo, BusnLocation, CardRangeId, CardCategory, a.Sic
	from aac_BusnLocation a
	join aac_Account b on a.AcctNo = b.AcctNo
	cross join iss_CardRange c
	where b.CorpCd = substring(c.CardRangeId,1,3) and a.Sic = 'G' and (a.Sic = c.CardCategory or c.CardCategory = 'B')

	if @@error <> 0
	begin
		select 'insert err temp CardRange1'
		rollback tran
		return 1
	end

	insert into #CardRange
	(AcctNo, BusnLocation, CardRangeId, CardCategory, Sic)
	select a.AcctNo, BusnLocation, CardRangeId, CardCategory, a.Sic
	from aac_BusnLocation a
	join aac_Account b on a.AcctNo = b.AcctNo
	cross join iss_CardRange c
	where b.CorpCd = substring(c.CardRangeId,1,3) and a.Sic = 'I' and a.Sic = c.CardCategory

	if @@error <> 0
	begin
		select 'insert err temp CardRange2'
		rollback tran
		return 1
	end

	insert into #CardRange
	(AcctNo, BusnLocation, CardRangeId, CardCategory, Sic)
	select a.AcctNo, BusnLocation, CardRangeId, CardCategory, a.Sic
	from aac_BusnLocation a
	join aac_Account b on a.AcctNo = b.AcctNo
	cross join iss_CardRange c
	where c.CardRangeId = 'KTC'

	if @@error <> 0
	begin
		select 'insert err temp CardRange3'
		rollback tran
		return 1
	end

	insert into #CardRange
	(AcctNo, BusnLocation, CardRangeId, CardCategory, Sic)
	select a.AcctNo, BusnLocation, CardRangeId, CardCategory, a.Sic
	from aac_BusnLocation a
	join aac_Account b on a.AcctNo = b.AcctNo
	cross join iss_CardRange c
	where a.Sic = 'G' and a.Sic = c.CardCategory and b.CorpCd = 'PTT' and rtrim(CardRangeId) = 'BCPCBGENE'

	if @@error <> 0
	begin
		select 'insert err temp CardRange4'
		rollback tran
		return 1
	end

	insert into #CardRange
	(AcctNo, BusnLocation, CardRangeId, CardCategory, Sic)
	select a.AcctNo, BusnLocation, CardRangeId, CardCategory, a.Sic
	from aac_BusnLocation a
	join aac_Account b on a.AcctNo = b.AcctNo
	cross join iss_CardRange c
	where a.Sic = 'G' and a.Sic = c.CardCategory and b.CorpCd = 'BCP' and rtrim(CardRangeId) = 'PTTCBGENE'

	if @@error <> 0
	begin
		select 'insert err temp CardRange5'
		rollback tran
		return 1
	end

	insert into #CardRange
	(AcctNo, BusnLocation, CardRangeId, CardCategory, Sic)
	select a.AcctNo, BusnLocation, CardRangeId, CardCategory, a.Sic
	from aac_BusnLocation a
	join aac_Account b on a.AcctNo = b.AcctNo
	cross join iss_CardRange c
	where a.Sic = 'I' and CardCategory = 'B' and b.CorpCd = 'PTT' and rtrim(CardRangeId) = 'BCPCB2IN1'

	if @@error <> 0
	begin
		select 'insert err temp CardRange6'
		rollback tran
		return 1
	end

	insert into #CardRange
	(AcctNo, BusnLocation, CardRangeId, CardCategory, Sic)
	select a.AcctNo, BusnLocation, CardRangeId, CardCategory, a.Sic
	from aac_BusnLocation a
	join aac_Account b on a.AcctNo = b.AcctNo
	cross join iss_CardRange c
	where a.Sic = 'I' and CardCategory = 'B' and b.CorpCd = 'BCP' and rtrim(CardRangeId) = 'PTTCB2IN1'

	if @@error <> 0
	begin
		select 'insert err temp CardRange7'
		rollback tran
		return 1
	end

	insert into #CardRange
	(AcctNo, BusnLocation, CardRangeId, CardCategory, Sic)
	select a.AcctNo, BusnLocation, CardRangeId, CardCategory, a.Sic
	from aac_BusnLocation a
	join aac_Account b on a.AcctNo = b.AcctNo
	cross join iss_CardRange c
	where a.Sic = 'G' and c.CardCategory = 'B' and b.CorpCd = 'PTT' and rtrim(CardRangeId) = 'BCPCB2IN1'

	if @@error <> 0
	begin
		select 'insert err temp CardRange8'
		rollback tran
		return 1
	end

	insert into #CardRange
	(AcctNo, BusnLocation, CardRangeId, CardCategory, Sic)
	select a.AcctNo, BusnLocation, CardRangeId, CardCategory, a.Sic
	from aac_BusnLocation a
	join aac_Account b on a.AcctNo = b.AcctNo
	cross join iss_CardRange c
	where a.Sic = 'G' and c.CardCategory = 'B' and b.CorpCd = 'BCP' and rtrim(CardRangeId) = 'PTTCB2IN1'

	if @@error <> 0
	begin
		select 'insert err temp CardRange9'
		rollback tran
		return 1
	end

	insert acq_CardRangeAcceptance
	(AcqNo, BusnLocation, CardRangeId, UserId, LastUpdDate)
	select 1, BusnLocation, CardRangeId, system_user, getdate()
	from #CardRange
	order by BusnLocation, CardRangeId

	if @@error <> 0
	begin
		select 'insert err acq_CardRangeAcceptance'
		rollback tran
		return 1
	end

select 'phase8...'
--call: OnlineMessage0200

--postpaid (200,0)
--prepaid (200,3800)
--upload offline postpaid, upload postpaid, upload prepaid (320)
--offline postpaid (220,100000)
	insert #TxnCdMapping
	(AcctNo, BusnLocation, CardRangeId, MsgType, PrcsCd)
	select AcctNo, BusnLocation, CardRangeId, b.MsgType, b.PrcsCd
	from #CardRange a
	cross join acq_MessageHandle b
	where (b.MsgType = 200 and b.PrcsCd in (0,3800)) or (b.MsgType = 320) or (a.MsgType = 220 and b.PrcsCd = 100000)
	order by BusnLocation, a.CardRangeId, b.MsgType, b.PrcsCd

	if @@error <> 0
	begin
		select 'insert err temp TxnCdMapping'
		rollback tran
		return 1
	end

	--2003/11/27B
	--update #TxnCdMapping
	--set TxnCd = 200
	update a
	set TxnCd = case when a.Sic = 'I' then 205 else 200 end
	from #TxnCdMapping a
	join aac_BusnLocation b on a.BusnLocation = b.BusnLocation

	if @@error <> 0
	begin
		select 'update txn 200/205 cd err'
		rollback tran
		return 1
	end
	--2003/11/27E

--call: OnlineMessage0220VO

--void offline postpaid sales (0). (220,0) e.g. record purposes.
--void offline postpaid sales. 
	insert #TxnCdMapping
	(AcctNo, BusnLocation, CardRangeId, MsgType, PrcsCd, TxnCd)
	select AcctNo, BusnLocation, CardRangeId, b.MsgType, b.PrcsCd, 400
	from #CardRange a
	cross join acq_MessageHandle b
	where b.MsgType = 220 and (b.PrcsCd <> 100000)
	order by BusnLocation, a.CardRangeId, b.MsgType, b.PrcsCd

	if @@error <> 0
	begin
		select 'insert err temp TxnCdMapping for offline'
		rollback tran
		return 1
	end

--call: OnlineMessage0200V

--void postpaid sales (200,200000)
--void prepaid sales (200, 203800)

--call: OnlineMessage0400RV
--reversal (400, 200000/ 400, 203800)

--call: OnlineMessage0400
--reversal (400, 0/ 400, 3800)
	insert #TxnCdMapping
	(AcctNo, BusnLocation, CardRangeId, MsgType, PrcsCd, TxnCd)
	select AcctNo, BusnLocation, CardRangeId, b.MsgType, b.PrcsCd, 400
	from #CardRange a
	cross join acq_MessageHandle b
	where (b.MsgType = 200 and b.PrcsCd in (200000,203800)) or (b.MsgType = 400)
	order by BusnLocation, a.CardRangeId, b.MsgType, b.PrcsCd

	if @@error <> 0
	begin
		select 'insert err temp TxnCdMapping for void/reversal txn'
		rollback tran
		return 1
	end

	--2003/11/27B
	update a
	set TxnCd = case when a.Sic = 'I' then 405 else 400 end
	from #TxnCdMapping a
	join aac_BusnLocation b on a.BusnLocation = b.BusnLocation
	where a.TxnCd = 400

	if @@error <> 0
	begin
		select 'update txn 400/405 cd err'
		rollback tran
		return 1
	end
	--2003/11/27E

--normal settlement
	insert #TxnCdMapping
	(AcctNo, BusnLocation, MsgType, PrcsCd)
	select AcctNo, BusnLocation, 500, 920000
	from #TxnCdMapping
	group by AcctNo, BusnLocation

	if @@error <> 0
	begin
		select 'insert err 500, 920000'
		rollback tran
		return 1
	end

--batch uploading settlement
	insert #TxnCdMapping
	(AcctNo, BusnLocation, MsgType, PrcsCd)
	select AcctNo, BusnLocation, 500, 960000
	from #TxnCdMapping
	group by AcctNo, BusnLocation

	if @@error <> 0
	begin
		select 'insert err 500, 960000'
		rollback tran
		return 1
	end

	insert acq_TxnCodeMapping
	(AcqNo, AcctNo, BusnLocation, MsgType, PrcsCd, CardRangeId, TxnCd, UserId, LastUpdDate, Sts)
	select @AcqNo, AcctNo, BusnLocation, MsgType, PrcsCd, CardRangeId, TxnCd, system_user, @SysDate, 'A'
	from #TxnCdMapping 

	if @@error <> 0
	begin
		select 'insert err acq_TxnCodeMapping'
		rollback tran
		return 1
	end
select 'end...'
	-----------
	commit tran
	-----------
/*
select @AcctCnt = count(*) from aac_Account
select @BusnCnt = count(*) from aac_BusnLocation
select @AcctAddr = count(*) from iss_Address where RefTo = 'MERCH'
select @BusnAddr = count(*) from iss_Address where RefTo = 'BUSN'
select @AcctCont = count(*) from iss_Contact where RefTo = 'MERCH'
select @BusnCont = count(*) from iss_Contact where RefTo = 'BUSN'
select @TxnCdCnt = count(*) from acq_TxnCodeMapping
select @CardRangeCnt = count(*) from acq_CardRangeAcceptance

select 'Total acct:		', @AcctCnt
select 'Total merch:	', @BusnCnt
select 'Total acctaddr:	', @AcctAddr
select 'Total merchaddr:', @BusnAddr
select 'Total acctcont:	', @AcctCont
select 'Total merchcont:', @BusnCont
select 'Total mapping:	', @TxnCdCnt
select 'Total cardrange:', @CardRangeCnt */
select 'Job completed'
	return 0
end
GO
