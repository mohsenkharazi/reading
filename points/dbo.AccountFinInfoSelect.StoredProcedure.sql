USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AccountFinInfoSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	: CarDtrend Systems Sdn. Bhd.
Modular		: CarDtrend Card Management System (CCMS)- Issuing Module

Objective	: To retrieve up-to-date credit available.

SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN		Description
-------------------------------------------------------------------------------
2003/09/10 Sam				Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[AccountFinInfoSelect]
	@IssNo uIssNo,
	@AcctNo uAcctNo,
	@AvailCreditLimit varchar(12) output
  as
begin
	declare @tAvailCreditLimit money

	set nocount on

	select @tAvailCreditLimit = case when PrepaidInd = 'Y' then (isnull(a.AccumAgeingAmt,0) * -1) - ((isnull(WithheldAmt, 0) + isnull(UnsettleAmt, 0))) else (isnull(a.CreditLimit, 0) + isnull(b.CreditLimit, 0)) - (isnull(AccumAgeingAmt, 0) + isnull(WithheldAmt, 0) + isnull(UnsettleAmt, 0)) end
	from iac_AccountFinInfo a
	left outer join iac_TempCreditLimit b on a.IssNo = b.IssNo and a.AcctNo = b.AcctNo and convert(varchar(8),getdate(),112) between convert(varchar(8),EffDateFrom,112) and convert(varchar(8),EffDateTo,112)
	join iac_Account c on a.IssNo = c.IssNo and a.AcctNo = c.AcctNo
	join iss_PlasticType d on c.IssNo = d.IssNo and c.CardLogo = d.CardLogo and c.PlasticType = d.PlasticType
	where a.IssNo = @IssNo and a.AcctNo = @AcctNo

	select @AvailCreditLimit = cast(@tAvailCreditLimit as varchar(12))
	return 0	
end
GO
