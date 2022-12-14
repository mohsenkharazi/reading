USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AcctBusnLocationSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:AcctBusnLocationSelect
		
		Enable to select details of account or the business location.

Called by	:

SP Level	:Primary

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/05/20 Sam			   Initial development

*******************************************************************************/
CREATE procedure [dbo].[AcctBusnLocationSelect]
	@AcqNo uAcqNo,
	@AcctNo uAcctNo,
	@BusnLocation uMerch,
	@AppvInd uYesNo
  as
begin

	set nocount on
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	if @AcctNo is null and @BusnLocation is null
		return 95088

	if @BusnLocation is null
	begin
		select CorpCd, CoRegNo, CreationDate, AgreementDate, BusnName, a.CoRegName, a.TaxId,
			AgreementNo, ReasonCd, AutoDebitInd, BankName, BankAcctNo, PersonInCharge,
			Mcc, Sic, BusnSize, Sts, AcctNo, PayeeName, Ownership, CancelDate, CycNo, b.Descp, c.Descp 'ReasonCdDescp',
			BranchCd, WithholdingTaxInd, WithholdingTaxRate, BankAcctType, convert(varchar(30), LastUpdDate, 13) 'LastUpdDate'
		from aac_Account a (nolock) 
		join iss_RefLib b  (nolock)  on a.AcqNo = b.IssNo and a.Sts = b.RefCd and b.RefType = 'MerchAcctSts' and b.RefNo <> 1
		left outer join iss_RefLib c (nolock)  on a.AcqNo = c.IssNo and a.Sts = c.RefCd and c.RefType = 'MerchReasonCd'
		where a.AcqNo = @AcqNo and a.AcctNo = @AcctNo
		if @@rowcount = 0 or @@error <> 0
		begin
			return 95089
		end
		return 0
	end

	select BusnName, AcctNo, CoRegNo, AgreementDate, AgreementNo, CreationDate, a.CoRegName, a.TaxId,
		AutoDebitInd, BankName, BankAcctNo, BusnLocation, PersonInCharge, Mcc, Sic, ReasonCd,
		BusnSize, Sts, StmtPrintInd, Ownership, CancelDate, PayeeName, CycNo, b.Descp, c.Descp 'ReasonCdDescp',
		BankAcctType
--		BranchCd, WithholdingTaxInd, WithholdingTaxRate
	from aac_BusnLocation a (nolock) 
	join iss_RefLib b  (nolock)  on a.AcqNo = b.IssNo and a.Sts = b.RefCd and b.RefType = 'MerchAcctSts' and b.RefNo <> 1
	left outer join iss_RefLib c (nolock)  on a.AcqNo = c.IssNo and a.Sts = c.RefCd and c.RefType = 'MerchReasonCd'
	where a.AcqNo = @AcqNo and a.BusnLocation = @BusnLocation

	if @@rowcount = 0 or @@error <> 0
	begin
		return 95090
	end
	return 0
end
GO
