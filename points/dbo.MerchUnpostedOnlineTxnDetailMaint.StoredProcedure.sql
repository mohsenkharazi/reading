USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchUnpostedOnlineTxnDetailMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	: Cardtrend Systems Sdn. Bhd.
Modular		: Cardtrend Card Management System (CCMS)- Acquiring Module

Objective	: To select the unposted online settlement transactions 
		  for further rectification

SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/12/10 Sam		           Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[MerchUnpostedOnlineTxnDetailMaint]
	@func varchar(6),
	@AcqNo uAcqNo,
	@Ids uTxnId,
	@Qty money,
	@Amt money, 
	@FastTrack money
  as
begin
	set nocount on

	if @Qty is null or @Amt is null return 95125 --Check counter/ litre or amount

	update atx_SourceTxnDetail
	set Qty = @Qty, AmtPts = @Amt, FastTrack = @FastTrack, UserId = system_user, LastUpdDate = getdate()
	where Ids = @Ids
	if @@rowcount = 0 or @@error <> 0 return 70396 --Failed to update Transaction Detail
	return 50263 --Transaction Detail has been updated successfully
end
GO
