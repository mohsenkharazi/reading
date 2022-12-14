USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[IssuerCorpCodeMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Corporate code insertion.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/01/23 Wendy		   Initial development
2002/10/04 Sam			   To cater for the corporate industry code.
2007/07/24 Chew Pei		   Put CorpCd at WebLogonId field
2008/02/25 Peggy		   Change fields
*******************************************************************************/
CREATE procedure [dbo].[IssuerCorpCodeMaint]
	@Func varchar(6),
	@IssNo  uIssNo,
	@CorpCd uRefCd,
	@Descp uDescp50,
	@IndustryCd uRefCd,
	@BankName uRefCd,
	@BankAcct varchar(20),
	@PIC uDescp50,
	@PayeeName uDescp50,
	@AdminFee money
	
  as
begin
	set nocount on

	if @Descp is null return 55017
	if @CorpCd is null return 55009
	--if @IndustryCd is null return 55134
	--if isnumeric(@IndustryCd) <> 1 return 95162
	--if @PayeeName is null select @PayeeName = @PIC
	--if @BankName is null return 55154
	--if @BankAcct is null return 55066


	if @Func='Add'
	begin

		if exists(select 1 from iac_CorporateAccount where IssNo = @IssNo and CorpCd = @CorpCd)
			return 70111 --Failed to insert Corporate Code

		insert iac_CorporateAccount
			(IssNo, CorpCd, IndustryCd, Descp, MaxPwAttempt, BankName, BankAcctNo, PersonInCharge, PayeeName, AdminFee, LastUpdDate, UserId)
		values (@IssNo, @CorpCd, @IndustryCd, @Descp, 3, @BankName, @BankAcct, @PIC, @PayeeName, @AdminFee, getdate(), system_user)
		if @@rowcount = 0 or @@error <> 0 return 70111
		return 50078
	end

	if @Func='Save'
	begin
		if not exists(select 1 from iac_CorporateAccount where IssNo = @IssNo and CorpCd = @CorpCd)
			return 70112 --Failed to update Corporate Code

		update iac_CorporateAccount
		set Descp = @Descp,
			IndustryCd = @IndustryCd,
			BankName = @BankName,
			BankAcctNo = @BankAcct,
			PersonInCharge = @PIC,
			PayeeName = @PayeeName,
			AdminFee = isnull(@AdminFee, 0),
			LastUpdDate = getdate()
		where IssNO = @IssNo and CorpCd = @CorpCd
		if @@rowcount = 0 or @@error <> 0 return 70112
		return 50079
	end
end
GO
