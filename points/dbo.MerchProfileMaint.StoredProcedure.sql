USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchProfileMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Company Profile maintenance.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/11 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[MerchProfileMaint]
	@AcqNo uAcqNo,
	@AcctNo uAcctNo,
	@Descp nvarchar(500)
  as
begin
	if not exists (select 1 from aac_CompanyProfile where AcctNo = @AcctNo)
	begin
		if @Descp is null return 55017
		insert aac_CompanyProfile
		( AcqNo, AcctNo, Descp )
		values
		( @AcqNo, @AcctNo, @Descp )
		if @@rowcount = 0 or @@error <> 0 return 70260
		return 50221
	end

	update aac_CompanyProfile
	set Descp = @Descp
	where AcctNo = @AcctNo
	return 50220
end
GO
