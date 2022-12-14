USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[IssuerCorpCodeDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Issuer Corporate code deletion.

-------------------------------------------------------------------------------
When	     Who		CRN	   Description
-------------------------------------------------------------------------------
2010/08/07  Barnett			   Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[IssuerCorpCodeDelete]
	@IssNo  uIssNo,
	@CorpCd uRefCd,
	@Descp uDescp50
  as
begin
	if @Descp is null return 55017
	if @CorpCd is null return 55077

	begin transaction
	
	delete iac_CorporateAccount
	where IssNo = @IssNo and CorpCd = @CorpCd and Descp = @Descp

	if @@rowcount = 0
	begin
		return 70113
	end

	delete iss_Address
	where IssNo = @IssNo and RefTo = 'CORP' and RefKey = @CorpCd

	if @@error != 0
	begin
		return 70113
	end

	delete iss_Contact
	where IssNo = @IssNo and RefTo = 'CORP' and RefKey = @CorpCd

	if @@error != 0
	begin
		return 70113
	end

	commit transaction

	return 50080
end
GO
