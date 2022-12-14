USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AddressTypeMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Address Type Code insertion.

SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/01/23 Wendy		   Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[AddressTypeMaint]
	@Func varchar(5),
	@IssNo  uIssNo,
	@AddrTypeCd uRefCd,
	@Descp uDescp50
  as
begin
	if @Descp is null return 55017
	if @AddrTypeCd is null return 55088

	if @Func='Add'
	begin
		insert into iss_RefLib (IssNo, RefType, RefCd, RefNo, Descp)
		values (@IssNo,	'Address', @AddrTypeCd, 0, @Descp)

		if @@error != 0
			return 70117

		return 50081
	end

	if @Func='Save'
	begin
		update iss_RefLib
		set Descp=@Descp
		where IssNo=@IssNo and RefCd=@AddrTypeCd and RefType='Address'

		if @@error != 0
			return 70118

		return 50082
	end

end
GO
