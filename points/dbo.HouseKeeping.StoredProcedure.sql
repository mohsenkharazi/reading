USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[HouseKeeping]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*****************************************************************************************************
Copyright	:Cardtrend Systems Sdn. Bhd.

Modular		:Cardtrend Card Management System (CCMS).

Objective	:To house keep data.
			Every first of the month.

			Description			Length of month(s)
			------------------	------------------
			Online txn log		~14 days
			Online txn			3
			VAE					1
			Merch txn			12
			Merch event			3
			Merch MTD			24
			Appl/ appc			12
			Card txn			12
			Card event			12



------------------------------------------------------------------------------------------------------
When	   	Who		CRN		Description
------------------------------------------------------------------------------------------------------
2003/06/01	Sam				Initial development.
2004/01/14	Chew Pei		Change iap_CostCentre to iaa_CostCentre
********************************************************************************************************/

CREATE	procedure [dbo].[HouseKeeping]
	@IssNo uIssNo,
	@PrcsId uPrcsId = null
  as
begin
	declare @Mth24 varchar(6), @Mth13 varchar(6), @Mth12 varchar(6), @Mth6 varchar(6), @Mth3 varchar(6),
		@Mth varchar(6), @Day14 smallint, @CycDate datetime, @PrcsDate datetime, @PrcsIdMth3 int

	set nocount on

	if @PrcsId is null
	begin
		select @PrcsId = CtrlNo,
				@PrcsDate = CtrlDate
		from iss_Control
		where IssNo = @IssNo and CtrlId = 'PrcsId'
	end
	else
	begin
		select @PrcsDate = PrcsDate
		from cmnv_ProcessLog
		where IssNo = @IssNo and PrcsId = @PrcsId
	end

	if @@error <> 0 return 1

	if substring((convert(varchar(8), @PrcsDate,112)),7,2) <> '01' 
		return 0

	select @Mth6 = convert(varchar(6), dateadd(mm, -6, @PrcsDate), 112)
	select @Mth3 = convert(varchar(6), dateadd(mm, -3, @PrcsDate), 112)
	select @Mth = convert(varchar(6), dateadd(mm, -1, @PrcsDate), 112)
	select @Mth12 = convert(varchar(6), dateadd(mm, -12, @PrcsDate), 112)
	select @Mth13 = convert(varchar(6), dateadd(mm, -13, @PrcsDate), 112)
	select @Mth24 = convert(varchar(6), dateadd(mm, -24, @PrcsDate), 112)
	select @Day14 = 14

	select @CycDate = max(PrcsDate)
	from iac_StatementCycle 
	where convert(varchar(6),PrcsDate,112) < @Mth13

	if isdate(@CycDate) <> 1 return 0

	select @PrcsIdMth3 = isnull(@PrcsId,0) - 90
	if @PrcsIdMth3 <= 0 select @PrcsIdMth3 = 0

	----------
	begin tran
	----------

	----------
	--Acquirer
	----------
	delete atx_OnlineLog where datediff(day,LastUpdDate,@PrcsDate) > 14

	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete a
	from atx_VAETxnDetail a
	join atx_VAETxn b on a.SrcIds = b.Ids and convert(varchar(6),b.LastUpdDate, 112) < @Mth3
	where a.AcqNo = @IssNo

	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete atx_VAETxn where AcqNo = @IssNo and convert(varchar(6),LastUpdDate, 112) < @Mth3

	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete a
	from atx_OnlineTxnDetail a
	join atx_OnlineTxn b on a.SrcIds = b.Ids and convert(varchar(6),b.LastUpdDate, 112) < @Mth3 and isnull(b.ForcePrcsId,0) > 0 and b.AcqNo = @IssNo

	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete atx_OnlineTxn where AcqNo = @IssNo and convert(varchar(6),LastUpdDate, 112) < @Mth3 and isnull(ForcePrcsId,0) > 0 

	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete atx_OnlineSettlement where AcqNo = @IssNo and convert(varchar(6),LastUpdDate, 112) < @Mth3

	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete a
	from atx_TxnDetail a
	join atx_Txn b on a.SrcIds = b.Ids and convert(varchar(6),b.LastUpdDate,112) < @Mth13
 
 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete atx_Txn where convert(varchar(6),LastUpdDate,112) < @Mth13

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end
	
	delete atx_Settlement where convert(varchar(6),LastUpdDate,112) < @Mth13 and AcqNo = @IssNo

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete a
	from aac_EventDetail a
	join aac_Event b on b.AcqNo = @IssNo and b.Sts = 'C' and a.EventId = b.EventId and convert(varchar(6),b.ClsDate,112) < @Mth12

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete aac_Event where AcqNo = @IssNo and Sts = 'C' and convert(varchar(6),ClsDate,112) < @Mth12

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete acq_MTDProdCd where AcqNo = @IssNo and PrcsDate < @Mth24

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete acq_MTDTxnCd where AcqNo = @IssNo and PrcsDate < @Mth24

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete acq_MTDSettlement where AcqNo = @IssNo and convert(varchar(6),LastUpdDate,112) < @Mth24

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete acq_MerchSalesByCardRange
	where AcqNo = @IssNo and convert(varchar(6),PrcsDate,112) < @Mth24

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete acq_MerchSalesByTerminal
	where AcqNo = @IssNo and convert(varchar(6),PrcsDate,112) < @Mth24

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete a
	from acq_MerchTaxInvoiceMisc a
	where exists (select 1 from acq_MerchTaxInvoice b where b.AcqNo = @IssNo and a.TaxInvoiceNo = b.TaxInvoiceNo and convert(varchar(6),PrcsDate,112) < @Mth24)

	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete acq_MerchTaxInvoice
	where AcqNo = @IssNo and convert(varchar(6),PrcsDate,112) < @Mth24

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	--------
	--Issuer
	--------
	select ApplId into #Appl
	from iap_Application
	where IssNo = @IssNo and ((ApplSts = 'C' and convert(varchar(6), CreationDate,112) < @Mth6)
	or (ApplSts = 'T' and convert(varchar(6), CreationDate,112) < @Mth12))

	delete a
	from iap_ApplicationVelocityLimit a
	join #Appl b on a.ApplId = b.ApplId

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete a
	from iap_ApplicationAcceptance a
	join #Appl b on a.ApplId = b.ApplId
	where a.IssNo = @IssNo

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete a
	from iaa_CostCentre a
	join #Appl b on a.ApplId = b.ApplId
	where a.IssNo = @IssNo

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete a
	from iap_Application a
	join #Appl b on a.ApplId = b.ApplId
	where a.IssNo = @IssNo

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete a
	from iap_ApplicantVelocityLimit a
	join iap_Applicant b on a.AppcId = b.AppcId
	join #Appl c on b.ApplId = c.ApplId

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete a
	from iap_ApplicantSubLimit a
	join iap_Applicant b on a.AppcId = b.AppcId
	join #Appl c on b.ApplId = c.ApplId
	where a.IssNo = @IssNo

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete a
	from iap_Applicant a
	join #Appl b on a.ApplId = b.ApplId
	where a.IssNo = @IssNo and 
	((a.AppcSts = 'C' and convert(varchar(6), a.PrcsDate,112) < @Mth6) or
	(a.AppcSts = 'T' and convert(varchar(6), a.PrcsDate,112) < @Mth12))

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete a
	from itxv_TxnProductDetail a
	join itx_Txn b on a.TxnId = b.TxnId and b.PrcsDate < @CycDate

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete itx_Txn where PrcsDate < @CycDate

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete iac_MTDProduct where StmtDate < @CycDate

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete iac_MTDProduct where StmtDate < @CycDate

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete iac_MTDTxnCategory where StmtDate < @CycDate

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete iac_MTDTxnCode where StmtDate < @CycDate

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete iac_MTDCardInfo where StmtDate < @CycDate

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete iac_AccountStatement where StmtDate < @CycDate

	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete iac_StatementCycle where StmtDate < @CycDate

	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete a
	from itxv_HeldTxnProductDetail a
	join itx_HeldTxn b on a.TxnId = b.TxnId and PrcsId < @PrcsIdMth3 and Sts = 'E'
	
	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete itx_HeldTxn where PrcsId < @PrcsIdMth3 and Sts = 'E'

	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete a
	from iac_EventDetail a
	join iac_Event b on convert(varchar(6),b.ClsDate,112) < @Mth24 and Sts = 'C' and b.IssNo = @IssNo

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete iac_Event where convert(varchar(6),ClsDate,112) < @Mth24 and Sts = 'C' and IssNo = @IssNo

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	select * into #StmtAcct
	from udiE_StatementAccount where convert(varchar(6),StmtDate,112) < @Mth3

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete a
	from udiE_StatementCardTxn a	
	join udiE_StatementCard b on a.IssNo = b.IssNo and a.ParentSeqNo = b.SeqNo and a.BatchId = b.BatchId and a.AcctNo = b.AcctNo
	join #StmtAcct c on b.IssNo = c.IssNo and b.ParentSeqNo = c.SeqNo and b.BatchId = c.BatchId and b.AcctNo = c.AcctNo

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete a
	from udiE_StatementCard a	
	join #StmtAcct b on a.IssNo = b.IssNo and a.ParentSeqNo = b.SeqNo and a.BatchId = b.BatchId and a.AcctNo = b.AcctNo

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete a
	from udiE_StatementMessage a	
	join #StmtAcct b on a.IssNo = b.IssNo and a.ParentSeqNo = b.SeqNo and a.BatchId = b.BatchId and a.AcctNo = b.AcctNo

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete a
	from udiE_StatementAccount a
	join #StmtAcct b on a.IssNo = b.IssNo and a.SeqNo = b.SeqNo and a.BatchId = b.BatchId and a.AcctNo = b.AcctNo

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete udiE_TCBTxn where IssNo = @IssNo and convert(varchar(6),CreationDate,112) = @Mth3

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete udii_CounterService where IssNo = @IssNo and convert(varchar(6),TxnDate,112) = @Mth3 and Sts = 'E'

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete udii_TellerPayment where IssNo = @IssNo and convert(varchar(6),TxnDate,112) = @Mth3 and Sts = 'E'

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete udii_DirectDebit where IssNo = @IssNo and convert(varchar(6),TxnDate,112) = @Mth6

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	delete udii_DirectCredit where IssNo = @IssNo and convert(varchar(6),PostDate,112) = @Mth6

 	if @@error <> 0 
	begin
		rollback tran
		return 1
	end

	drop table #Appl
	drop table #StmtAcct

	commit tran
	return 50104	--Transaction has been processed successfully

end
GO
