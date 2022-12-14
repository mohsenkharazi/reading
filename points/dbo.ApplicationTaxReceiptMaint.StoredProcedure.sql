USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ApplicationTaxReceiptMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: To insert new or update existing tax receipt.

-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2003/06/23	KY		1103303	Initial development
2003/08/21	Chew Pei		Changed Receipt TaxId to Fax
							Remark off Province and ZipCd
2003/09/21	Chew Pei		Make Tax Receipt Fax to be optional
*******************************************************************************/
	
CREATE procedure [dbo].[ApplicationTaxReceiptMaint]
	@Func varchar(5),
	@IssNo uIssNo,
	@ApplId uApplId,
	@RcptName uCmpyName,
	@Street1 uStreet,
	@Street2 uStreet,
	@Street3 uStreet,
--	@Province uRefCd,
--	@ZipCd uZipCd,
	@RcptTel uContactNo,
	@RcptFax uContactNo
  as
begin
	declare @RefCd uRefCd,
			@Ctry uRefCd,
			@Province uRefCd,
			@ZipCd uZipCd
			
	
	select @RefCd = RefCd from iss_RefLib 
	where IssNo = @IssNo and RefType = 'Address' and (RefNo & 8) > 0

	select @Ctry = RefCd from iss_RefLib
	where IssNo = @IssNo and RefType = 'Country' and Descp = 'Thailand'

	if isnull(@IssNo,0) = 0
	return 0	-- Mandatory Field IssNo

	if isnull(@ApplId,'') = ''
	return 0	-- Mandatory Field ApplId

	if isnull(@RcptName,'') = ''
	return 55141	-- Name is a compulsory field 

	if isnull(@Street1,'') = ''
	return 55083	-- Address 1 is a compulsory field

	--if isnull(@Province,'') = ''
	--return 55160	-- Province is a compulsory field

	--if isnull(@ZipCd,'') = ''
	--return 55161	-- Postal Code is a compulsory field

	if isnull(@RcptTel,'') = ''
	return 55177	--Telephone Number is a compulsory field

	--if isnull(@RcptTaxId,'') = ''
	--return 55162	-- Tax Id is a compulsory field

--	if isnull (@RcptFax,'') = ''
--	return 55178 -- Fax Number is a compulsory field

	if @Func = 'Save'
	begin
		if not exists (select 1 from iap_Application where IssNo = @IssNo and ApplId = @ApplId)
		return 60022	-- Application not found

		-----------------
		begin transaction
		-----------------
		update iap_Application
		set 	RcptName = @RcptName,
				RcptTel = @RcptTel,
				RcptFax = @RcptFax
				--RcptTaxId = @RcptTaxId
		where IssNo = @IssNo and ApplId = @ApplId

		if @@error <> 0	
		begin
			rollback transaction
			return 70438	-- Failed to update Application Tax Receipt
		end

		if not exists (select 1 from iss_Address where IssNo = @IssNo and RefTo = 'APPL' and RefKey = @ApplId and RefType = 'ADDRESS' and RefCd = @RefCd)
		begin			
			insert into iss_Address (IssNo, RefTo, RefKey, RefType, RefCd, Street1, Street2, Street3, State, ZipCd, Ctry)
			values			(@IssNo, 'APPL', @ApplId, 'ADDRESS', @RefCd, @Street1, @Street2, @Street3, @Province, @ZipCd, @Ctry)

			if @@error <> 0	
			begin
				rollback transaction
				return 70438	-- Failed to update Application Tax Receipt
			end
		end 
		else
		begin
			update iss_Address
			set 	Street1 = @Street1,
					Street2 = @Street2,
					Street3 = @Street3,
					State = @Province,
					ZipCd = @ZipCd
			where IssNo = @IssNo and RefTo = 'APPL' and RefKey = @ApplId and RefType = 'ADDRESS' and RefCd = @RefCd

			if @@error <> 0	
			begin
				rollback transaction
				return 70438	-- Failed to update Application Tax Receipt
			end
		end
		------------------
		commit transaction
		------------------

		return 50169	-- Application has been updated successfully
	end

end
GO
