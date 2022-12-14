USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchCardRangeMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:Cardtrend Systems Sdn. Bhd.
Modular		:Cardtrend Card Management System (CCMS)- Acquiring Module

Objective	:To maintain card range for business location.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/07/31 Sam			   Initial development
*******************************************************************************/

CREATE procedure [dbo].[MerchCardRangeMaint]
	@Func varchar(8),
	@AcqNo uAcqNo,
	@BusnLocation uMerch,
	@CardRangeId nvarchar(10)
  as
begin
	set nocount on

	--if @CardRangeId is null return 55149 --Card Range Id is a compulsory field

	if not exists (select 1 from aac_BusnLocation a join iss_RefLib b on a.AcqNo = b.IssNo and a.Sts = b.RefCd and b.RefType = 'MerchAcctSts' and b.RefInd = 0 where a.AcqNo = @AcqNo and a.BusnLocation = @BusnLocation)
		return 95132 --Check Business Location status

	if @Func = 'Add'
	begin
		if isnull(@CardRangeId,'') <> ''
		begin
			if exists (select 1 from acq_CardRangeAcceptance where AcqNo = @AcqNo and BusnLocation = @BusnLocation and CardRangeId = @CardRangeId)
				return 65031 --Merchant Card Acceptance already exists
	
			insert acq_CardRangeAcceptance
			( AcqNo, BusnLocation, CardRangeId, UserId, LastUpdDate )
			values ( @AcqNo, @BusnLocation, @CardRangeId, system_user, getdate() )
	
			if @@rowcount = 0 or @@error <> 0 return 70256 --Failed to insert Merchant Card Acceptance
		end
		else
		begin
			insert acq_CardRangeAcceptance
			( AcqNo, BusnLocation, CardRangeId, UserId, LastUpdDate )
			select @AcqNo, @BusnLocation, a.CardRangeId, system_user, getdate()
			from iss_CardRange a
			where a.CardRangeId not in (select b.CardRangeId from acq_CardRangeAcceptance b where b.AcqNo = @AcqNo and b.BusnLocation = @BusnLocation)

			if @@rowcount = 0 or @@error <> 0 return 70256 --Failed to insert Merchant Card Acceptance
		end
		return 50214 --Merchant Card Acceptance has been inserted successfully
	end
end
GO
