USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchEntitySelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Merchant/ Business Location entity select.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/01/21 Wendy		   Initial development
2004/07/21 Alex			   Add LastUpdDate
*******************************************************************************/

CREATE procedure [dbo].[MerchEntitySelect]
	@AcqNo uAcqNo,
	@EntityId uEntityId
  as
begin
	select EntityId, AcqNo, FamilyName, GivenName, Gender, Marital, Dob, OldIc, NewIc,  
		Passport, LicNo, Dept, Occupation, Income, BankName, BankAcctNo, CreationDate, 
		Blood, Title, Sts, convert(varchar(30), LastUpdDate, 13) 'LastUpdDate'
	from aac_Entity 
	where AcqNo = @AcqNo and EntityId = @EntityId
	if @@rowcount = 0 or @@error <> 0 return 65013
	return 0
end
GO
