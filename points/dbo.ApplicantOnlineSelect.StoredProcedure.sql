USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ApplicantOnlineSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This procedure is used to validate the Applicant adding to
		an existing Account by referring to either the Account number or Primary card.


-------------------------------------------------------------------------------
When	   Who		CRN		Desc
-------------------------------------------------------------------------------
2001/11/21 CK			  	Initial development
					All remarks follow by ** is for further rework/recode.

2003/10/21 Sam				Add'l condition checking.					

******************************************************************************************************************/
CREATE procedure [dbo].[ApplicantOnlineSelect]
	@IssNo uIssNo,
	@PriInd tinyint,
	@AcctNo uAcctNo,
	@tCardNo varchar(19)
  as
begin
	declare @PriSec uPriSec,
		@AcctInd tinyint,
		@PrcsName varchar(50),
		@Debug char(1),
		@CardNo uCardNo,
		@tAcctNo uAcctNo

--	select @PrcsName = 'ApplicantOnlineSelect'
--	exec TraceProcess @IssNo, @PrcsName, 'Beginning Applicant Online Validation Process'
	select @CardNo = cast(@tCardNo as bigint)

	if @PriInd = 1 and @AcctNo is null return 55036
	if @PriInd = 0 and @AcctNo is null and @CardNo is null return 95091

	if @AcctNo is not null and @CardNo is not null
	begin
		if not exists (select 1 from iac_Card a, iac_Account b where a.IssNo = @IssNo and a.CardNo = @CardNo and b.IssNo = a.IssNo and b.AcctNo = a.AcctNo)
			return 95088	-- Reference card number not match account number
	end

	if isnull(@CardNo,0) <> 0
	begin
		select @PriSec = PriSec, @AcctInd = b.RefInd, @AcctNo = AcctNo from iac_Card a join iss_RefLib b on CardNo = @CardNo and a.IssNo = b.IssNo and b.RefType = 'CardSts' and a.Sts = b.RefCd where a.IssNo = @IssNo
		if @@rowcount = 0 return 60001	--- Card Number not found
		if @PriSec <> 'P' return 95089	-- Must be primary card
		if @AcctInd <> 0 return 95064	--Check on the Card Status
	end

	if isnull(@AcctNo,0) <> 0
	begin 
		select @AcctInd = b.RefInd from iac_Account a, iss_RefLib b where a.AcctNo = @AcctNo and a.IssNo = @IssNo and b.IssNo = a.IssNo and b.RefType = 'AcctSts' and b.RefCd = a.Sts
		if @@rowcount = 0 return 60000	-- Account not found
		if @AcctInd <> 0 return 95090	-- Account not active
	end

	return 0
end
GO
