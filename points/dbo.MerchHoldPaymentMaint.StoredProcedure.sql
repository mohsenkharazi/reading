USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchHoldPaymentMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	: Cardtrend Systems Sdn. Bhd.
Modular		: Cardtrend Card Management System (CCMS)- Acquiring Module

Objective	: To withhold merchant payment by end-user. 
SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2007/08/16 Sam		           Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[MerchHoldPaymentMaint]
	@Func varchar(10),
	@AcqNo uAcqNo,
	@PrcsId uPrcsId,
	@Ids uTxnId,
	@BusnLocation uMerchNo,
	@InputSrc varchar(10)

  as
begin
--	declare 
	set nocount on

	if not exists (select 1 from atx_SourceSettlement where AcqNo = @AcqNo and Ids = @Ids and PrcsId = @PrcsId and BusnLocation = @BusnLocation)
		return 70486 --Failed to update settlement

	----------
	begin tran
	----------

	update atx_SourceSettlement
	set InputSrc = @InputSrc
	where Ids = @Ids and PrcsId = @PrcsId and BusnLocation = @BusnLocation

	if @@error <> 0 
	begin
		rollback tran
		return 70278 --Failed to update settled balance
	end

	-----------
	commit tran
	-----------
	return 50262 --Settlement transaction has been updated successfully
end
GO
