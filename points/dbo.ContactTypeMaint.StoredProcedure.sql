USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ContactTypeMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Contact Type Code insertion.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/01/23 Wendy		   Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[ContactTypeMaint]
	@Func varchar(5),
	@IssNo  uIssNo,
	@ContactTypeCd uRefCd,
	@Descp uDescp50
   as
begin
	if @Descp is null return 55017
	if @ContactTypeCd is null return 55089

	if @Func='Add'
	begin
		insert into iss_RefLib (IssNo, RefType, RefCd, RefNo, Descp)
		values (@IssNo,	'Contact', @ContactTypeCd, 0, @Descp)

		if @@rowcount = 0
		begin
			return 70120
		end

		return 50084

	end

	if @Func='Save'
	begin

		update iss_RefLib set Descp=@Descp where IssNo=@IssNo and RefCd=@ContactTypeCd and RefType='Contact'

		if @@rowcount = 0
		begin
			return 70121
		end

		return 50085
	end
end
GO
