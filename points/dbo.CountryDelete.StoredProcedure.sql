USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CountryDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Country code deletion.

-------------------------------------------------------------------------------
When	   Who		CRN		Description
-------------------------------------------------------------------------------
2001/12/19 Sam				Initial development
2003/06/30 Jacky			Commented checking on itx_Txn

*******************************************************************************/
	
CREATE procedure [dbo].[CountryDelete]
	@IssNo smallint,
	@CtryCd uRefCd,
	@Descp uDescp50
   as
begin
	if @Descp is null
	begin
		return 55017
	end

	if @CtryCd is null
	begin
		return 55076
	end

	-- 2003/06/30 Jacky - Table is to slow for checking
--	if exists (select 1 from itx_Txn where CtryCd = @CtryCd) return 95000
	if exists (select 1 from iss_PlasticType where IssNo = @IssNo and CtryCd = @CtryCd)	return 95000
	if exists (select 1 from iss_Address where IssNo = @IssNo and Ctry = @CtryCd) return 95000

	begin transaction

	delete iss_RefLib
	where IssNo = @IssNo and RefCd = @CtryCd and RefType = 'Country'

	if @@rowcount = 0
	begin
		rollback transaction
		return 70105
	end

	delete iss_State
	where IssNo = @IssNo and CtryCd = @CtryCd

	if @@error != 0
	begin
		rollback transaction
		return 70105
	end

	commit transaction
	return 50061
end
GO
