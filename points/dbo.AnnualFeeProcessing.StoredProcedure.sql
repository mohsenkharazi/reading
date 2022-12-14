USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AnnualFeeProcessing]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure is to generate the annual fee processing.

		(1)	Initiate by every 1st of the month.
		(2)	Check member since not equal to today's date because application processing
			already posted the annual fee charge.
		(3)	It must be executed before the cycle-cut process run.
		(4)	It must be executed before the Application process run.
-------------------------------------------------------------------------------
When	   Who		CRN		Desc
-------------------------------------------------------------------------------
2003/01/10 Sam			  	Initial development
2003/12/10 Aeris			change get batchId from NextRunNo instead of 0;
							Get unique TxnSeq instead of 0
2004/07/20 Chew Pei			Re-code
							Process Annual Fee everyday
2005/11/25 Chew Pei			Tag BatchId = 0 in iac_AnnualFee 
******************************************************************************************************************/
CREATE procedure [dbo].[AnnualFeeProcessing]
	@IssNo uIssNo
  as
begin
	declare	@PrcsName varchar(50),
		@PrcsId uPrcsId,
		@PrcsDate datetime,
		@rc int,
		@CardCenterBusnLocation uMerch,
		@CardCenterTermId uTermId,
		@IssCrryCd uRefCd,
		@Year int,
		@Mth tinyint,
		@Day tinyint,
		@Date char(8),
		@BatchId int,
		@RecCnt int

	
	--2003/12/10B
	/*Create Table #AnnualFee
	(
		RecId int IDENTITY (1,1) NOT NULL,
		IssNo int,
		AcctNo varchar(19),
		CardNo varchar(19), 
		FeeCd varchar(12)
	)*/
	--2003/12/10E

	select @PrcsName = 'Annual Fee Processing'

	exec TraceProcess @IssNo, @PrcsName, 'Beginning of Annual Fee Processing'

	if isnull(@IssNo,0) < 0 return 60027	-- Issuer not found

	if not exists (select 1 from iss_Issuer where IssNo = @IssNo) return 60027

	-- Obtain Process Info
	select @PrcsId = CtrlNo, 
		@PrcsDate = CtrlDate, 
		@Year = datepart(yyyy, CtrlDate),
		@Mth = replicate('0', 2 - len(convert(varchar(2), datepart(mm, CtrlDate)))) + cast(datepart(mm, CtrlDate) as varchar),
		@Day = datepart(dd, CtrlDate),
		@Date = convert(char(8), CtrlDate, 112)
	from iss_Control 
	where CtrlId = 'PrcsId' and @IssNo = IssNo 

--	if isnull(@Day, 0) <> 1 return 54029 -- Annual fee processing completed successfully

	-------------------------------
	-- Creating Temporary Tables --
	-------------------------------
/*	select * into #SourceTxn
	from itx_SourceTxn
	where BatchId = -1
	delete #SourceTxn

	select * into #SourceTxnDetail
	from itx_SourceTxnDetail
	where BatchId = -1
	delete #SourceTxnDetail

	-- Creating index for temporary table
	create	unique index IX_SourceTxnDetail on #SourceTxnDetail (
		BatchId,
		ParentSeq,
		TxnSeq )*/

	/*select a.IssNo, a.AcctNo, a.CardNo, a.AnnlFeeCd into #AnnualFee
	from iac_Card a
	join iss_RefLib b on a.Sts = b.RefCd and a.IssNo = b.IssNo and b.RefType = 'CardSts' and b.RefInd in (0,1)
	where a.IssNo = @IssNo and datepart(mm, a.MemSince) = @Mth 
	and convert(char(8), a.MemSince, 112) <> @Date and a.AnnlFeeCd is not null*/

/*	--2003/12/10B
	insert into #AnnualFee (IssNo, AcctNo, CardNo, AnnualFeeCd)
	select a.IssNo, a.AcctNo, a.CardNo, a.AnnlFeeCd 
	from iac_Card a
	join iss_RefLib b on a.Sts = b.RefCd and a.IssNo = b.IssNo and b.RefType = 'CardSts' and b.RefInd in (0,1)
	where a.IssNo = @IssNo and datepart(mm, a.MemSince) = @Mth 
	and convert(char(8), a.MemSince, 112) <> @Date and a.AnnlFeeCd is not null
	--2003/12/10E
*/
	-- CP 2004/07/20 [B]
	------------------
	BEGIN TRANSACTION
	------------------
	if isnull(@Day, 0) = 1 -- Do an insert on every 1st of the month
	begin
	/*	update a
		set a.ExpiryDate =  replicate('0', 2 - len(convert(varchar(2), datepart(mm, b.ExpiryDate))))+ cast(datepart(mm, b.ExpiryDate) as varchar) + '/' + cast(datepart(yyyy, b.ExpiryDate) as varchar)
		from iac_AnnualFee a, iac_Card b
		where a.IssNo = b.IssNo and a.CardNo = b.CardNo and a.ExpiryDate is null and b.RenewalInd = 'Y'
		if @@error <> 0
		begin
			rollback transaction
			return 70870 -- Failed to update Annual Fee
		end
	*/
		insert into iac_AnnualFee (IssNo, BatchId, AcctNo, CardNo, ExpiryDate, FeeCd, Sts)
		select @IssNo, 0, a.AcctNo, a.CardNo, replicate('0', 2 - len(convert(varchar(2), datepart(mm, a.ExpiryDate))))+ cast(datepart(mm, a.ExpiryDate) as varchar) + '/' + cast(@Year as varchar), case a.RenewalInd when 'Y' then a.AnnlFeeCd else null end, null
		from iac_Card a
		where a.IssNo = @IssNo and datepart(mm, ExpiryDate) = @Mth and a.AnnlFeeCd is not null
		-- and convert(char(8), a.ExpiryDate, 112) <> @Date and a.AnnlFeeCd is not null
		--and not exists (select 1 from iac_Card c where isnull(datepart(mm, c.Terminationdate), 0) = @Mth and isnull(datepart(yyyy, c.TerminationDate), 0) = @Year and a.CardNo = c.CardNo) -- exclude those cards which have the termination month and year as the processing date, as these cards shd not be charged with annual fee
		--and not exists (select 1 from iac_Card d where isnull(datepart(mm, d.ExpiryDate), 0) = @Mth and isnull(datepart(yyyy, d.ExpiryDate), 0) = @Year and a.CardNo = d.CardNo) -- exclude those cards which have the expiry month and year as the processing date, as these cards shd not be charged annual fee
	--	and not exists (select 1 from iac_AnnualFee b where a.IssNo = b.IssNo and a.AcctNo = b.AcctNo and a.CardNo = b.CardNo)
		if @@error <> 0
		begin
			rollback transaction
			return 95217 --Failed to generate Annual Fee
		end

		-- update expirydate and feecd to null if the termination month is the same as annualprocessing month
		update a
		set ExpiryDate = null, FeeCd = null
		from iac_AnnualFee a
		where exists (select 1 from iac_Card c where isnull(datepart(mm, c.Terminationdate), 0) = @Mth and isnull(datepart(yyyy, c.TerminationDate), 0) = @Year and a.CardNo = c.CardNo) -- exclude those cards which have the termination month and year as the processing date, as these cards shd not be charged with annual fee
		and left(a.ExpiryDate, 2) = @Mth and right(a.ExpiryDate, 4) = @Year and a.Sts is null

		if @@error <> 0
		begin
			rollback transaction
			return 70870 -- Failed to update Annual Fee
		end
		
		-- update expirydate and feecd to null if card expired this month
		update a
		set ExpiryDate = null, FeeCd = null
		from iac_AnnualFee a
		where exists (select 1 from iac_Card d where isnull(datepart(mm, d.ExpiryDate), 0) = @Mth and isnull(datepart(yyyy, d.ExpiryDate), 0) = @Year and a.CardNo = d.CardNo) -- exclude those cards which have the expiry month and year as the processing date, as these cards shd not be charged annual fee
		and left(a.ExpiryDate, 2) = @Mth and right(a.ExpiryDate, 4) = @Year and a.Sts is null

		if @@error <> 0
		begin
			rollback transaction
			return 70870 -- Failed to update Annual Fee
		end

/*		select @IssNo, a.AcctNo, a.CardNo, replicate('0', 2 - len(convert(varchar(2), datepart(mm, a.ExpiryDate))))+ cast(datepart(mm, a.ExpiryDate) as varchar) + '/' + cast(datepart(yyyy, a.ExpiryDate) as varchar), a.AnnlFeeCd, null
		from iac_Card a
		join iss_RefLib b on a.Sts = b.RefCd and a.IssNo = b.IssNo and b.RefType = 'CardSts' and b.RefInd in (0,1) -- Active and Suspended
		where a.IssNo = @IssNo and datepart(mm, MemSince) = @Mth
		and convert(char(8), a.MemSince, 112) <> @Date --and a.AnnlFeeCd is not null
		and not exists (select 1 from iac_Card c where isnull(datepart(mm, c.Terminationdate), 0) = @Mth and isnull(datepart(yyyy, c.TerminationDate), 0) = @Year and a.CardNo = c.CardNo) -- exclude those cards which have the termination month and year as the processing date, as these cards shd not be charged with annual fee
		and not exists (select 1 from iac_Card d where isnull(datepart(mm, d.ExpiryDate), 0) = @Mth and isnull(datepart(yyyy, d.ExpiryDate), 0) = @Year and a.CardNo = d.CardNo) -- exclude those cards which have the expiry month and year as the processing date, as these cards shd not be charged annual fee
*/
		if @@error <> 0
		begin
			rollback transaction
			return 95217 --Failed to generate Annual Fee
		end


	end
	-- CP 2004/07/20 [E]
	
	--select @Rowcount = @@rowcount, @Err = @@error 

	--if @Err <> 0 return 95217 --Failed to generate Annual Fee

	--if @Rowcount = 0 return 54029 --Annual Fee Processing completed successfully
	
	--------------------------------------
	-- Creating Annual Fees --
	--------------------------------------

	select @CardCenterBusnLocation = VarcharVal
	from iss_Default
	where IssNo = @IssNo and Deft = 'CardCenterBusnLocation'

	select @CardCenterTermId = IntVal
	from iss_Default
	where IssNo = @IssNo and Deft = 'CardCenterTermId'

	select @IssCrryCd = CrryCd
	from iss_Issuer
	where IssNo = @IssNo

	--2003/12/10B
	exec @BatchId = NextRunNo @IssNo, 'BatchId'
	if @@error <> 0 
	begin 
		rollback transaction
		return 95174 -- Failed to generate new batch ID
	end
	
	-- Create Annual Fee
	/*insert into #SourceTxn (
		BatchId, TxnSeq, IssNo, TxnCd, AcctNo, CardNo, LocalTxnDate, TxnDate,
		LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Descp,
		BusnLocation, Mcc, TermId, Rrn, Stan, AppvCd, CrryCd, Arn, BillMethod,
		PlanId, PrcsId, InputSrc, SrcTxnId, RefTxnId, AuthTxnId, OnlineInd,
		UserId, Sts )
	select	0, 0, @IssNo, c.TxnCd, a.AcctNo, a.CardNo, @PrcsDate, @PrcsDate,
		b.Fee, b.Fee, 0, 0, 0, b.Descp,
		@CardCenterBusnLocation, null, @CardCenterTermId, null, null, null, @IssCrryCd, null, null,
		null, @PrcsId, 'SYS', null, 0, null, c.OnlineInd,
		system_user, null
	from #AnnualFee a 
	join iss_FeeCode b on a.AnnlFeeCd = b.FeeCd and a.IssNo = b.IssNo
	join itx_TxnCode c on b.TxnCd = c.TxnCd and c.IssNo = @IssNo*/
/*	insert into #SourceTxn (
		BatchId, TxnSeq, IssNo, TxnCd, AcctNo, CardNo, LocalTxnDate, TxnDate,
		LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Descp,
		BusnLocation, Mcc, TermId, Rrn, Stan, AppvCd, CrryCd, Arn, BillMethod,
		PlanId, PrcsId, InputSrc, SrcTxnId, RefTxnId, AuthTxnId, OnlineInd,
		UserId, Sts )
	select	@BatchId, a.RecId, @IssNo, c.TxnCd, a.AcctNo, a.CardNo, null, null,
		b.Fee, b.Fee, 0, 0, 0, b.Descp,
		@CardCenterBusnLocation, null, @CardCenterTermId, null, null, null, @IssCrryCd, null, null,
		null, @PrcsId, 'SYS', null, 0, null, c.OnlineInd,
		system_user, null
	from #AnnualFee a 
	join iss_FeeCode b on a.AnnualFeeCd = b.FeeCd and a.IssNo = b.IssNo
	join itx_TxnCode c on b.TxnCd = c.TxnCd and c.IssNo = @IssNo
*/	--2003/12/10E

	-- CP 2004/07/20 [B]
	insert itx_SourceTxn 
		(IssNo, BatchId, TxnSeq, TxnCd, AcctNo, CardNo, LocalTxnDate, TxnDate,
		LocalTxnAmt, SettleTxnAmt, BillingTxnAmt, Pts, PromoPts, Descp, BusnLocation,
		Mcc, TermId, Rrn, Stan, AppvCd, CrryCd, BillMethod, PlanId, 
		PrcsId, InputSrc, OnlineInd, UserId)
	select	@IssNo, @BatchId, a.RecId, c.TxnCd, a.AcctNo, a.CardNo, null, @PrcsDate,
		b.Fee, b.Fee, 0, 0, 0, b.Descp, @CardCenterBusnLocation, 
		null, @CardCenterTermId, null, null, null, @IssCrryCd, null, null,
		@PrcsId, 'SYS', c.OnlineInd, system_user
	from iac_AnnualFee a 
	join iss_FeeCode b on a.FeeCd = b.FeeCd and a.IssNo = b.IssNo
	join itx_TxnCode c on b.TxnCd = c.TxnCd and c.IssNo = @IssNo
	where a.Sts is null and left(a.ExpiryDate, 2) = @Mth and right(a.ExpiryDate, 4) = @Year
	-- CP 2004/07/20 [E]
 
	if @@error <> 0
	begin
		rollback transaction
		return 70109 -- Failed to insert into itx_SourceTxn
	end

	select @RecCnt = count(*) from itx_SourceTxn where BatchId = @BatchId
	if @RecCnt > 0
	begin
		insert udi_Batch (IssNo, BatchId, SrcName, FileName, FileSeq, DestName, FileDate,
			LoadedRec, RecCnt, Direction, PrcsId, PrcsDate, Sts)
		select @IssNo, @BatchId, 'HOST', 'TRANSACTION',
			(select isnull(max(FileSeq), 0)+1 from udi_Batch
				where IssNo = @IssNo and SrcName = 'HOST' and FileName = 'TRANSACTION'),
			'HOST', @PrcsDate, @RecCnt, 0, 'I', @PrcsId, null, 'L'
		if @@error <> 0
		begin
			rollback transaction
			return 70395	-- Failed to create new batch
		end
	end

	update a
	set BatchId = @BatchId, Sts = 'E' -- 'E'xtracted for processing
	from iac_AnnualFee a, itx_SourceTxn b
	where a.CardNo = b.CardNo and b.BatchId = @BatchId
	
	if @@error <> 0
	begin
		rollback transaction
		return 70870 -- Failed to update iac_AnnualFee
	end

/*	exec @rc = OnlineTxnProcessing @IssNo

	if @@error <> 0 or @rc <> 0
	begin
		rollback transaction
		return 70109 -- Failed to insert into itx_SourceTxn
	end
*/
	------------------
	COMMIT TRANSACTION
	------------------
	exec TraceProcess @IssNo, @PrcsName, 'End of Annual Fee Processing'

	return 54029 --Annual Fee Processing completed successfully
end
GO
