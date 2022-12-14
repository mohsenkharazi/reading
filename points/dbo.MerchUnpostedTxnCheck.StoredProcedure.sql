USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchUnpostedTxnCheck]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Update merchant unposted transaction. Cnt and Amt in atx_SourceTxn must 
			tally with total cnt and amt in atx_SourceSettlement. 
			Update atx_SourceSettlement..PrcsId and atx_SourceTxn..PrcsId for further 
			processing

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2004/06/10 Chew Pei			   Initial development
*******************************************************************************/
	
CREATE procedure [dbo].[MerchUnpostedTxnCheck]
	@IssNo smallint,
	@Ids int -- atx_SourceSettlement
  as
begin
	declare @PrcsId uPrcsId
	declare @Cnt int, @Amt money

	select @PrcsId = CtrlNo
	from iss_Control 
	where CtrlId = 'PrcsId' and IssNo = @IssNo

	-----------------
	BEGIN TRANSACTION
	-----------------
	
	select @Cnt = Cnt, @Amt = Amt
	from atx_SourceSettlement
	where Ids = @Ids

	if @Cnt = (select count(*) from atx_SourceTxn where SrcIds = @Ids) and @Amt = (select sum(Amt) from atx_SourceTxn where SrcIds = @Ids)
	begin
		if (select sum(Amt) from atx_SourceTxn where SrcIds = @Ids) = (select sum(AmtPts) from atx_SourceTxnDetail where ParentIds = @Ids)
		begin
			-- Cnt & Amt in atx_SourceTxn tally with atx_SourceSettlement
			-- update atx_SourceSettlement & atx_SourceTxn PrcsId = Today's PrcsId for further processing
			update atx_SourceSettlement set PrcsId = @PrcsId where Ids = @Ids
			if @@error <> 0
			begin
				rollback transaction
				return 70486
			end
			update atx_SourceTxn set PrcsId = @PrcsId where SrcIds = @Ids
			if @@error <> 0
			begin
				rollback transaction
				return 95202
			end
		end
		else 
		begin
			-- Total SourceSettlement = Total SourceTxn but Total SourceTxn <> Total SourceTxnDetails
			rollback transaction
			return 95304
		end
	end
	else
	begin
		-- Total SourceTxn <> Total SourceTxnDetails
		rollback transaction
		return 95303	
	end
	
	------------------
	COMMIT TRANSACTION
	------------------
	return 50263

end
GO
