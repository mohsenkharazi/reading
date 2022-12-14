USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[OccupationMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Job insertion.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/01/23 Wendy		   Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[OccupationMaint]
	@Func varchar(5),
	@IssNo uIssNo,
	@OccupationCd uRefCd,
	@Descp uDescp50
  as
begin
	if @Descp is null return 55017
	if @OccupationCd is null return 55087

	if @Func='Add'
	begin	
		insert into iss_RefLib (IssNo, RefType, RefCd, RefNo, Descp)
		values (@IssNo,	'Occupation', @OccupationCd, 0, @Descp)

		if @@rowcount = 0
		begin
			return 70114
		end

		return 50087
	end
	
	if @Func='Save'
	begin
		update iss_RefLib
		set Descp=@Descp
		where IssNo=@IssNo and RefCd=@OccupationCd and RefType='Occupation'

		if @@rowcount = 0
		begin
			return 70115
		end

		return 50088
	end
end
GO
