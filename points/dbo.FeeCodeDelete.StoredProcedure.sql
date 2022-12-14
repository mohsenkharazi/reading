USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[FeeCodeDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To insert new or update existing fee code.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2001/12/20 Sam			   Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[FeeCodeDelete]
	@IssNo uIssNo,
	@FeeCd uRefCd
  as
begin
	if @FeeCd is null return 55022

	if not exists (select 1 from iss_FeeCode where IssNo = @IssNo and FeeCd = @FeeCd)
		return 60050	-- Fee Code not found

--	if exists (select 1 from iss_FeeCode a, itx_TxnCode b where a.IssNo = @IssNo
--	and a.FeeCd = @FeeCd and b.IssNo = @IssNo and b.TxnCd = a.TxnCd)
--	begin
--		return 95000	-- Unable to delete record because data is being used
--	end

	delete iss_FeeCode
	where IssNo = @IssNo and FeeCd = @FeeCd

	if @@error <> 0
	begin
		return 70020	-- Failed to delete Fee Code
	end

	return 50015	-- Fee Code has been deleted successfully
end
GO
