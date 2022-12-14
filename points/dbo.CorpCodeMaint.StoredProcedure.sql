USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CorpCodeMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
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
CREATE procedure [dbo].[CorpCodeMaint]
	@Func varchar(6),
	@AcqNo  uAcqNo,
	@CorpCd uRefCd,
	@Descp uDescp50,
	@IndustryCd uRefCd,
	@WebLogonId uWebLogonId,
	@WebPw uPw,
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
	if @IndustryCd is null return 55134
	if isnumeric(@IndustryCd) <> 1 return 95162
	if @PayeeName is null select @PayeeName = @PIC
	if @BankName is null return 55154
	if @BankAcct is null return 55066
	
	if @WebPw is null
		select @WebPw = dbo.GenPassword(rand())


	if @Func='Add'
	begin

		if exists(select 1 from aac_CorporateAccount where AcqNo = @AcqNo and CorpCd = @CorpCd)
			return 70111 --Failed to insert Corporate Code

		if exists (select 1 from aac_CorporateAccount where AcqNo = @AcqNo and WebLogonId = @WebLogonId)
			return 65066 -- Web Logon already exist

		insert aac_CorporateAccount
			(AcqNo, CorpCd, IndustryCd, WebLogonId, WebPw, Descp, MaxPwAttempt, BankName, BankAcctNo, PersonInCharge, PayeeName, AdminFee, LastUpdDate, UserId)
		values (@AcqNo, @CorpCd, @IndustryCd, @CorpCd, @WebPw, @Descp, 3, @BankName, @BankAcct, @PIC, @PayeeName, @AdminFee, getdate(), system_user)
		if @@rowcount = 0 or @@error <> 0 return 70111
		return 50078
	end

	if @Func='Save'
	begin
		if not exists(select 1 from aac_CorporateAccount where AcqNo = @AcqNo and CorpCd = @CorpCd)
			return 70112 --Failed to update Corporate Code

		update aac_CorporateAccount
		set Descp = @Descp,
			IndustryCd = @IndustryCd,
			WebLogonId = @CorpCd,
			WebPw = @WebPw,
			BankName = @BankName,
			BankAcctNo = @BankAcct,
			PersonInCharge = @PIC,
			PayeeName = @PayeeName,
			AdminFee = isnull(@AdminFee, 0),
			LastUpdDate = getdate()
		where AcqNo = @AcqNo and CorpCd = @CorpCd
		if @@rowcount = 0 or @@error <> 0 return 70112
		return 50079
	end
end
GO
