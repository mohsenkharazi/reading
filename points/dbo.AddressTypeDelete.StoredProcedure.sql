USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AddressTypeDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	: CarDtrend Systems Sdn. Bhd.
Modular		: CarDtrend Card Management System (CCMS)- Issuing Module

Objective	: Address Type Code deletion.

SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/01/23 Wendy		   Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[AddressTypeDelete]
	@IssNo  uIssNo,
	@AddrTypeCd uRefCd,
	@Descp uDescp50
  as
begin
	if @Descp is null return 55017
	if @AddrTypeCd is null return 55088
	
	delete iss_RefLib
	where IssNo = @IssNo and RefCd = @AddrTypeCd and RefType = 'Address'
	
	if @@error != 0 or @@rowcount = 0
		return 70119

	return 50083
end
GO
