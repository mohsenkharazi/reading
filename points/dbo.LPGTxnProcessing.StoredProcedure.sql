USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[LPGTxnProcessing]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:

Objective	:Handle LPG Pts issueing Batch File Process. 

-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2012/03/28	Barnett			Initial Development
2014/01/13  Humairah		Handle ASCII(0) from input file to avoid error converting varchar to bigint 
							during EOD process
*******************************************************************************/
	
CREATE	procedure [dbo].[LPGTxnProcessing]
	@IssNo uIssNo, 
	@PrcsId uPrcsId
  
as
begin

		declare @Rc int, @BatchId uBatchId, @PtsToAmt money, @ActiveSts uRefCd, @Cnt int,
				@CtryCd uRefCd, @CrryCd uRefCd, @Rrn uRrn, @AuthNo uAppvCd, @Ids bigint,
				@SettlementTxnCd uTxnCd, @BatchSalesTxnCd uTxncd, @TxnInd uRefCd,
				@TermId uTermId, @BusnLocation varchar(20), @BusnName varchar(100), @AcqBatchId uBatchId,
				@PrcsDate datetime, @IssTxnCd uTxnCd, @FileSeq int
	
		
		create table #Settle
		(
			IssNo smallint null,
			Ids bigint identity (1,1) not null,
			BusnLocation varchar(15) null,
			TermId varchar(10) null,
			TxnCd int null,
			TxnInd varchar(10) null,
			BatchId int null,
			OrgBatchId int null,
			Cnt int null,
			Amt money null
		)

		if @@error <> 0
		begin
			return 95278 --Check error on temp file
		end


		create table #Txn
		(
			IssNo smallint NULL,
			BatchId int NOT NULL,
			OrgBatchId int NOT NULL,
			TxnSeq bigint NOT NULL,
			TxnCd int,
			TxnInd varchar(15),
			TermId varchar(10) NULL,
			TxnDate DateTime NULL,
			CardNo bigint NULL,
			TxnAmt money NULL,
			Rrn varchar(12) NULL,
			AuthNo varchar(6) NULL,		
			BusnLocation varchar(15) NULL,
			PrcsId int NULL,
			Sts char(2) NULL,
			ExpiryDate varchar(4) NULL,
			TxnTime varchar(12) NULL,
			LtyPAN varchar(30) NULL,
			OfferCd varchar(5) NULL,
			UUID varchar(12) NULL,
			Stan varchar(10) NULL,
			Qty money NULL,
			ProdCd varchar(10) NULL
		)

		if @@error <> 0
		begin
			return 95278 --Check error on temp file
		end


		select @PrcsDate = CtrlDate, @PrcsId = CtrlNo
		from iss_Control (nolock) 
		where CtrlId = 'PrcsId' and IssNo = @IssNo

		select @SettlementTxnCd = IntVal
		from acq_default (nolock) where Deft = 'SettlementTxnCd'
		
		select @BatchSalesTxnCd = IntVal
		from acq_default (nolock) where Deft = 'BatchSalesTxnCd'

		select @BusnLocation = VarcharVal 
		from iss_default where IssNo = @IssNo and Deft = 'PetronasBusnLocation'
	
		select @TermId = IntVal 
		from iss_default where IssNo = @IssNo and  Deft = 'PetronasTermId'
	
		select @PtsToAmt = MoneyVal 
		from iss_Default where IssNo = @IssNo and  Deft = 'PtsToAmt'

		select @BusnName = BusnName
		from aac_BusnLocation (nolock) where BusnLocation = @BusnLocation

		select @TxnInd = TxnInd , @IssTxnCd = IssTxnCd
		from atx_Txncode where Txncd = @BatchSalesTxnCd

		select @FileSeq = Max(FileSeq) from udi_Batch where SrcName = 'PKMLPGBF' and [FileName] = 'TRANSACTION' and Direction = 'I'

		select @ActiveSts = RefCd 
		from iss_RefLib where IssNo = @IssNo and RefType = 'MerchBatchSts' and RefNo = 0
	
		select @CtryCd = RefCd 
		from iss_Reflib where IssNo = @IssNo and RefType = 'Country' and Descp = 'Malaysia'
		
		select @CrryCd = CrryCd from iss_Currency where IssNo = @IssNo and ShortDescp = 'MYR'

		
		-----------------
		BEGIN TRANSACTION
		-----------------		
		
		exec @BatchId = NextRunNo @IssNo, 'UDIBatchId'
		
		-- Begin DATA File Data Extraction
		insert udii_LPGTxn (IssNo, BatchId,TxnSeq, TermId, 
						TxnDate, 
						CardNo, TxnAmt, BusnName,BusnLocation, PrcsId, Sts, ProdCd, Qty)
		select  @IssNo, @Batchid, Convert (bigint, SeqNo), @TermId, 
				convert(datetime, LocalDate+' '+ substring(LocalTime, 1, 2) + ':' + substring(LocalTime, 3, 2) + ':'+ substring(localTime, 5, 2)),
				--CardNo, Cast( TxnAmt as money)/10000, @BusnName, @BusnLocation, @PrcsId ,null, ProdCd, cast(Qty as money)
				replace(CardNo,char(0),'')'CardNo', Cast( TxnAmt as money)/10000, @BusnName, @BusnLocation, @PrcsId ,null, ProdCd, cast(Qty as money)					--humairah - 20140113 
		from ld_LPGTxn



		insert into #Txn
		(IssNo, BatchId, OrgBatchId, TxnSeq, TxnCd, TxnInd, TermId, TxnDate, CardNo, TxnAmt, Rrn, AuthNo, BusnLocation, 
		PrcsId, Sts, ExpiryDate, TxnTime, OfferCd, Stan, Qty, ProdCd)
		select 
		IssNo, BatchId, BatchId, TxnSeq, @BatchSalesTxnCd, @TxnInd, @TermId, TxnDate, CardNo, TxnAmt, Rrn, AuthNo, BusnLocation, 
		PrcsId, null, ExpiryDate, TxnTime, OfferCd, Stan, Qty, ProdCd
		from udii_LPGTxn a
		where a.IssNo = @IssNo and a.BatchId = @BatchId and a.Sts is null

			

		insert udi_Batch (IssNo, BatchId, SrcName, FileName, FileSeq, DestName, FileDate, RecCnt, Direction, PrcsId, PrcsDate, Sts)
		select @IssNo, @BatchId, 'PKMLPGBF', 'TRANSACTION', isnull(@FileSeq,0)+1, 'HOST', getdate(), isnull(@Rc, 0), 'I', @PrcsId, @PrcsDate, 'L'
	


		--Check the CardNo
		Update a
		set Sts = 'C'	-- Invalid Card No
		from #Txn a
		where BatchId = @BatchId and a.IssNo = @IssNo and a.Sts is null 
		and not exists (select 1 from iac_Card b where b.CardNo = a.CardNo and b.IssNo = @IssNo)


		update a
		set a.Sts = 'N' -- Amt is negative
		from #Txn a
		where a.IssNo = @IssNo and a.BatchId = @BatchId and a.TxnAmt <= 0 and a.Sts is null
		

		update a 
		set a.Sts = 'R' -- Reject transaction that card is expired
		from #Txn a
		where a.IssNo = @IssNo and a.BatchId = @BatchId and a.Sts is null
		and not exists (select 1 from iac_Card b where cast(a.TxnDate as datetime) < b.ExpiryDate and 
				b.CardNo = a.CardNo and b.IssNo = @IssNo)


		update a
		set Sts = 'I' -- Invalid Product Code
		from #Txn a
		join iss_Product b (nolock) on b.ProdCd = a.Prodcd and b.ProdType <> '06' -- ProdType 06 is only for LPG
		where BatchId = @BatchId and a.PrcsId = @PrcsId and a.IssNo = @IssNo

				
		update a
		set a.Sts= 'B' -- Bad Card Status.
		from #Txn a
		join iac_Card b (nolock) on b.CardNo = a.CardNo 
		join iss_Reflib c (nolock) on c.RefType='CardSts' and c.RefInd > 2 and c.RefCd = b.Sts
		where a.IssNo = @IssNo and  a.BatchId = @BatchId and a.Sts is null

	
		update a
		set a.Sts= 'X' -- Bad Account Status.
		from #Txn a
		join iac_Card b (nolock) on b.CardNo = a.CardNo 
		join iac_Account c (nolock) on c.AcctNo = b.CardNo 
		join iss_Reflib d (nolock) on d.RefType='AcctSts' and d.RefInd > 0 and d.RefCd = c.Sts
		where a.IssNo = @IssNo and  a.BatchId = @BatchId and a.Sts is null

					
		-- Pass all the Validation and ready to proceed the Pts conversi$on
		update #Txn
		Set Sts = 'A'
		where BatchId = @BatchId and PrcsId = @PrcsId and IssNo = @IssNo and Sts is null


		-- create Settlement Batch
		insert into #Settle (IssNo, BusnLocation, TermId, TxnCd, TxnInd, Cnt, Amt, OrgBatchId)
		select @IssNo, BusnLocation, TermId, TxnCd, TxnInd, count(*), sum(TxnAmt), @BatchId
		from #Txn
		where Sts = 'A'
		group by IssNo, BusnLocation, TermId, TxnCd, TxnInd


		select @Ids = min(Ids) from #Settle
		
		while @Ids > 0
		begin
			exec @AcqBatchId = NextRunNo @IssNo, 'EDCBatchId'

			update #Settle set 
				BatchId = @AcqBatchId
			where Ids = @Ids

			if @@error <> 0
			begin
				rollback tran
				return 95278 --Check error on temp file
			end

			select @Ids = min(Ids) from #Settle where Ids > @Ids
			if @@rowcount = 0 break
		end

		update a
		set BatchId = b.BatchId
		from #Txn a
		join #Settle b on a.BusnLocation = b.BusnLocation and a.TermId = b.TermId and a.TxnCd = b.TxnCd and a.TxnInd = b.TxnInd

		if @@error <> 0
		begin
			rollback tran
			return 95278	--Check error on temp file
		end	

		
		-- Create RRN & Approval Code
		select row_number() over (order by TxnSeq)'Id', TxnSeq 
		into #Temp 
		from #Txn 
		where OrgBatchId = @BatchId and IssNo = @IssNo and Sts = 'A'
		
		select @Cnt = min(id) from #Temp
			
		while @Cnt <= (select max(id) from #Temp)
		begin
					-- Generate Rrn
					exec GetRrn @Rrn output
					
					-- Generate Approval Code
					exec GetApprovalCd @AuthNo output

					select @Ids = TxnSeq from #Temp where Id = @Cnt

					update #Txn
					set Rrn = @Rrn,
						AuthNo = @AuthNo
					where TxnSeq = @Ids and OrgBatchId = @BatchId and IssNo = @IssNo

					select @Cnt = min(Id) from #Temp where Id > @Cnt
					WAITFOR DELAY '00:00:01'


		end		

		select * into #SourceTxn
		from itx_SourceTxn (nolock) where BatchId = -1
		delete #SourceTxn

		select * into #SourceTxnDetail
		from itx_SourceTxnDetail (nolock) where BatchId = -1
		delete #SourceTxnDetail

		create unique index IX_SourceTxnDetail
		on #SourceTxnDetail ( BatchId, ParentSeq, TxnSeq )

		insert #SourceTxn 
			(BatchId, TxnSeq, IssNo, TxnCd, AcctNo, CardNo, LocalTxnDate, TxnDate,
			LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Descp,
			BusnLocation, Mcc, TermId, Rrn, Stan, AppvCd, CrryCd, Arn, Odometer,
			BillMethod, PlanId, PrcsId, InputSrc, SrcTxnId, RefTxnId, AuthTxnId,
			OnlineTxnId, OnlineInd, UserId, Sts)
		select 
			BatchId, TxnSeq, a.IssNo, 204, b.AcctNo, a.CardNo, TxnDate, TxnDate,
			TxnAmt, TxnAmt, 0, 0, 0, null,
			BusnLocation, null, TermId, null, null, null, null, null, null,
			null, null, 1, 'LPG', null, null, null,
			null, null, null, 'A'
		from #Txn a
		join iac_Card b (nolock) on b.CardNo = a.CardNo
		where a.Sts = 'A'

		
		insert #SourceTxnDetail
				(BatchId, ParentSeq, TxnSeq, IssNo, RefTo, RefKey, LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Qty, SrcTxnId, PlanId, Sts, PricePerUnit)
		select BatchId, TxnSeq, TxnSeq, a.IssNo, 'P', a.ProdCd, TxnAmt, TxnAmt, 0, 0, 0, round(b.PricePerUnit,3,1)* a.Qty, null, null, 'A', null
		from #Txn a		
		join iss_Product b (nolock) on b.ProdCd = a.ProdCd and a.IssNo = b.IssNo
		where a.Sts = 'A'

		
		-- Calculate the Points
		exec @Rc =  TxnBilling 1,  3,  2

		
		if @@error <> 0 or dbo.CheckRC(@Rc) <> 0
		begin
			
				Rollback Transaction
				return 1
		end


		-- Settlement
		insert into atx_SourceSettlement
			(AcqNo, BatchId, TxnCd, SettleDate, Cnt, Amt, Pts, BillingAmt, BillingPts, Descp, 
			BusnLocation, TermId, Stan, Rrn, InvoiceNo, OrigBatchNo, AcctNo, Mcc, PrcsId, TxnInd, 
			POSCondCd, ChequeNo, InputSrc, LinkIds, UserId, LastUpdDate, Sts , DealerCd)
		select a.IssNo, a.BatchId, 500, @PrcsDate, a.Cnt, a.Amt, sum(c.Pts), 0, sum(c.Pts), @BusnName, 
			a.BusnLocation, a.TermId, 0, @Rrn, 0, a.OrgBatchId, b.AcctNo, b.Mcc, @PrcsId, a.TxnInd, 
			0, null, 'BATCH', null, system_user, @PrcsDate, @ActiveSts, null
		from #Settle a
		join aac_BusnLocation b on a.IssNo = b.AcqNo and a.BusnLocation = b.BusnLocation
		join #Sourcetxn c (nolock) on c.BatchId = a.BatchId 
		group by a.IssNo, a.BatchId, a.Cnt, a.Amt, a.TxnInd, a.OrgBatchId, b.AcctNo, b.Mcc, a.BusnLocation, a.TermId

	

		if @@error <> 0
		begin
			rollback transaction
			return 95200 --Insert & update atx_SourceSettlement does not tally
		end

		-- Insert Transaction to Atx_SourceTxn
		insert atx_SourceTxn
			(SrcIds, AcqNo, BatchId, TxnCd, CardNo, CardExpiry, LocalDate, LocalTime, TxnDate, 
			ArrayCnt, Qty, Amt, Pts, BillingAmt, BillingPts, SrvcFee, VATAmt, SubsidizedAmt, 
			Descp, BusnLocation, TermId, CrryCd, CtryCd, InvoiceNo, Odometer, Rrn, AuthNo, 
			PrcsId, LinkIds, TxnInd, WithheldUnsettleId, IssBillingAmt,IssBillingPts, IssBatchId, 
			UserId, LastUpdDate, Sts, Stan, DealerCd)
		select c.Ids, a.IssNo, a.BatchId, a.TxnCd, a.CardNo, null /*a.CardExpiry*/, null /*a.LocalDate*/, null /*a.LocalTime*/, a.TxnDate,
				1, null, a.TxnAmt, d.Pts, 0, d.Pts, 0, 0, 0, 
				c.Descp, a.BusnLocation, a.TermId, null /*a.CrryCd*/, null /*a.CtryCd*/, null /*a.InvoiceNo*/, 0 /*a.Odometer*/, a.Rrn, a.AuthNo, 
				@PrcsId, a.TxnSeq, a.TxnInd, 0, 0, 0, 0, 
				system_user, getdate(), @ActiveSts, a.Stan, c.DealerCd
		from #Txn a
		join atx_SourceSettlement c on a.BusnLocation = c.BusnLocation and a.TermId = c.TermId and c.PrcsId = @PrcsId and a.TxnInd = c.TxnInd and a.BatchId = c.BatchId
		join #Sourcetxn d on d.BatchId = a.BatchId and d.TxnSeq = a.TxnSeq and a.TxnCd = d.TxnCd
		where a.IssNo = @IssNo and a.Sts = @ActiveSts

		if @@error <> 0
		begin
			rollback tran
			Return 95203 --Insert & update atx_SourceTxn does not tally
		end
		
		select * from #SourceTxnDetail
		-- Insert Trasaction Detail 
		insert atx_SourceTxnDetail
			(SrcIds, ParentIds, AcqNo, BatchId, Seq, ProdCd, Qty, AmtPts, FastTrack, BillingAmt, BillingPts, SubsidizedAmt, 
			Descp, BusnLocation, UnitPrice, PlanId, ProdType, LinkIds, LastUpdDate, UserId, Sts)
		select b.Ids, c.Ids, @IssNo, b.BatchId, 1, a.RefKey, a.Qty, a.SettleTxnAmt, 0, 0, 0, 0, 
			d.Descp, c.BusnLocation, d.PricePerUnit, 0, d.ProdType, a.TxnSeq, getdate(), system_user, @ActiveSts		
		from #SourceTxnDetail a
		join atx_SourceTxn b on a.TxnSeq = b.LinkIds and a.BatchId = b.BatchId 
		join atx_SourceSettlement c on b.BusnLocation = c.BusnLocation and b.TermId = c.TermId and b.PrcsId = c.PrcsId and b.SrcIds = c.Ids
		join iss_Product d (nolock) on d.ProdCd = a.RefKey and d.IssNo = @IssNo
		where b.PrcsId = @PrcsId and a.IssNo = @IssNo
	
		if @@error <> 0 
		begin
			rollback transaction
			return 95205 -- Insert error atx_SourceTxnDetail
		end
		

		-- Update Processed Record
		update a set 
			Sts = b.Sts,
			PrcsId = @PrcsId,
			AcqBatchId = b.BatchId
		from udii_LPGTxn a 
		join #Txn b on b.TxnSeq = a.TxnSeq and b.OrgBatchId = a.BatchId
		where a.IssNo = @IssNo and a.BatchId = @BatchId
	
		if @@error <> 0
		begin
			rollback transaction
			return 70199	-- Failed to update held transaction
		end

		update udii_LPGTxn 
		set Sts = 'E', 
		    PrcsId = @PrcsId -- Extracted
		where IssNo = @IssNo and BatchId = @BatchId and Sts = @ActiveSts
	
		if @@error <> 0
		begin
			rollback transaction
			return 70199	-- Failed to update held transaction
		end

		



		commit transaction
		
		truncate table ld_LPGTxn 
		drop table #Settle
		drop table #Txn
		drop table #Temp
		
		return 0		
		

end
GO
