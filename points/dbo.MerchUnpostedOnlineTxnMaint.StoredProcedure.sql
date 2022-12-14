USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchUnpostedOnlineTxnMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
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
	
CREATE procedure [dbo].[MerchUnpostedOnlineTxnMaint]
	@func varchar(6),
	@AcqNo uAcqNo,
	@Qty money,
	@Amt money, 
	@ArrayCnt tinyint,
	@Ids uTxnId
  as
begin
	declare @PrcsId uPrcsId
	set nocount on

	if @Qty is null or @Amt is null return 95125 --Check counter/ litre or amount

	select @PrcsId = CtrlNo from iss_Control where IssNo = @AcqNo and CtrlId = 'PrcsId'
	if @@rowcount = 0 or @@error <> 0 return 95098 --Unable to retrieve information from iss_Control table

	update atx_SourceTxn
	set Qty = @Qty, Amt = @Amt, PrcsId = @PrcsId, ArrayCnt = @ArrayCnt, UserId = system_user, LastUpdDate = getdate()
	where Ids = @Ids
	if @@rowcount = 0 or @@error <> 0 return 70278
	return 50262 --Settlement transaction has been updated successfully
end
GO
