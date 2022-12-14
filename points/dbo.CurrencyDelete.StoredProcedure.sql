USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CurrencyDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Currency code deletion.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2001/12/19 Sam			   Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[CurrencyDelete]
	@IssNo smallint,
	@CrryCd uRefCd,
	@Descp uDescp50
   as
begin
	if @Descp is null return 55017
	if @CrryCd is null return 55077

	if exists (select 1 from iss_PlasticType where IssNo = @IssNo and CrryCd = @CrryCd)
		return 95000

	if exists (select 1 from itx_Txn where CrryCd = @CrryCd)
		return 95000

	delete iss_Currency
	where IssNo = @IssNo and CrryCd = @CrryCd

	if @@rowcount = 0
	begin
		return 70108
	end
	return 50064
end
GO
