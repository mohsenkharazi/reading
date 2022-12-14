USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CountryMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Insert or update Country code.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2001/12/19 Sam			   Initial development
2004/07/08 Chew Pei			Change to Standard Coding
*******************************************************************************/
	
CREATE procedure [dbo].[CountryMaint]
	@Func varchar(5),
	@IssNo smallint,
	@CtryCd uRefCd,
	@Descp uDescp50
   as
begin
	if @Descp is null return 55017
	if @CtryCd is null return 55076

	if @Func = 'Add'
	begin
		insert iss_RefLib (IssNo, RefType, RefCd, RefNo, RefInd, Descp)
		select @IssNo, 'Country', @CtryCd, 0, 0, @Descp
		if @@rowcount = 0
		begin
			return 70103
		end
		return 50059
	end

	if @Func = 'Save'
	begin
		update iss_RefLib
		set Descp = @Descp
		where IssNo = @IssNo and RefCd = @CtryCd and RefType = 'Country'
		if @@rowcount = 0
		begin
			return 70104
		end
		return 50060
	end
	
end
GO
