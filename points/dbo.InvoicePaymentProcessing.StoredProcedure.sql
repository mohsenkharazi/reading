USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[InvoicePaymentProcessing]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************
Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Invoice Payment Processing

------------------------------------------------------------------------------------------------
When		Who		CRN	Desc
------------------------------------------------------------------------------------------------
2005/11/07	Esther	Initial Development
2005/11/14	Jacky	Revamp
******************************************************************************************************************/
-- exec InvoicePaymentProcessing 1

CREATE procedure [dbo].[InvoicePaymentProcessing]
	@IssNo uIssNo,
	@PrcsId uPrcsId
  as
begin

	declare @BillingAmt money,
		@Acct bigint,
		@AmtPaid money

	-----------------------------------------
	SAVE TRANSACTION InvoicePaymentProcessing
	-----------------------------------------

	-- Create summary table to support multiple payment to same invoice
	-- None existance invoice will be eliminate from the #InvoicePayment

	select a.ParentSeq, a.TxnSeq, a.InvoiceNo, a.BillingTxnAmt,	sum(b.BillingTxnAmt) 'AccumAmt'
	into #InvoicePayment
	from #InvoicePaymentTxnDetail a
	join #InvoicePaymentTxnDetail b
		on (b.ParentSeq < a.ParentSeq or (b.ParentSeq = a.ParentSeq and b.TxnSeq <= a.TxnSeq))
		and b.InvoiceNo = a.InvoiceNo
	join #InvoicePaymentTxn c on c.TxnSeq = a.ParentSeq
	join iac_Invoice d on d.AcctNo = c.AcctNo and d.InvoiceNo = a.InvoiceNo
	join #InvoicePaymentTxn e on e.TxnSeq = b.ParentSeq
	join iac_Invoice f on f.AcctNo = e.AcctNo and f.InvoiceNo = b.InvoiceNo
	group by a.ParentSeq, a.TxnSeq, a.InvoiceNo, a.BillingTxnAmt

	if @@error <> 0
	begin
		rollback transaction InvoicePaymentProcessing
		return 70270	-- Failed to create temporary table
	end

	-- Normalization on the same Txn having more than 1 same invoice number

	select a.ParentSeq, a.InvoiceNo, sum(a.BillingTxnAmt) 'BillingTxnAmt', max(AccumAmt) 'AccumAmt'
	into #InvoicePaymentSummary
	from #InvoicePayment a
	group by a.ParentSeq, a.InvoiceNo

	if @@error <> 0
	begin
		rollback transaction InvoicePaymentProcessing
		return 70270	-- Failed to create temporary table
	end

--select * from #invoicepaymentsummary order by parentseq
	-- Create Invoice Payment from the summary table
	-- If for some reason the BillingTxnAmt in Txn Detail is > then the remaining amount of
	-- the invoice then only use the invoice remaining amount to create Invoice Payment

	insert into iac_InvoicePayment (TxnId, AcctNo, InvoiceNo, AmtPaid, PrcsId, Sts)
	select a.TxnId, a.AcctNo, b.InvoiceNo,
		case when b.AccumAmt > (c.InvoiceAmt - c.AmtPaid) then
			case when b.BillingTxnAmt > (b.AccumAmt - (c.InvoiceAmt - c.AmtPaid)) then
				b.BillingTxnAmt - (b.AccumAmt - (c.InvoiceAmt - c.AmtPaid))
			else
				0
			end
		else
			b.BillingTxnAmt
		end,
		@PrcsId, 'C'
	from #InvoicePaymentTxn a
	join #InvoicePaymentSummary b on b.ParentSeq = a.TxnSeq
	join iac_Invoice c on c.AcctNo = a.AcctNo and c.InvoiceNo = b.InvoiceNo and c.Sts = 'A'

	if @@error <> 0
	begin
		rollback transaction InvoicePaymentProcessing
		return 70920	-- Failed to create Invoice Payment
	end

	-- Create Open Credit only if there is balance in the Txn (check against Invoice Payment)

	insert into iac_OpenCredit (TxnId, AcctNo, OpenCredit, Sts)
	select a.TxnId, a.AcctNo, (a.BillingTxnAmt - isnull(sum(b.AmtPaid), 0)), 'A'
	from #InvoicePaymentTxn a
	left outer join iac_InvoicePayment b on b.TxnId = a.TxnId and b.PrcsId = @PrcsId
	group by a.TxnId, a.AcctNo, a.BillingTxnAmt
	having (a.BillingTxnAmt - isnull(sum(b.AmtPaid), 0)) > 0

	if @@error <> 0
	begin
		rollback transaction InvoicePaymentProcessing
		return 70921	-- Failed to create Open Credit
	end

	-- Update Invoice AmtPaid and Status

	update a set
		AmtPaid = a.AmtPaid + b.AmtPaid,
		Sts = case when a.AmtPaid + b.AmtPaid < a.InvoiceAmt then a.Sts else 'C' end
	from iac_Invoice a
	join (select a.InvoiceNo, sum(a.AmtPaid) 'AmtPaid'
			from iac_InvoicePayment a
			join #InvoicePaymentTxn b on b.TxnId = a.TxnId
			where a.PrcsId = @PrcsId
			group by a.InvoiceNo) as b on b.InvoiceNo = a.InvoiceNo

	if @@error <> 0
	begin
		rollback transaction InvoicePaymentProcessing
		return 70917	-- Failed to update Invoice
	end

end
GO
