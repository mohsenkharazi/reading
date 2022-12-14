USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchSalesSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Merchant sales info.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/08/23 Sam			   Initial development
2009/12/18 Barnett		   Add Nolock
*******************************************************************************/

CREATE	procedure [dbo].[MerchSalesSelect]
	@AcqNo uAcqNo,
	@Ind char(1),
	@AcctNo uMerch,
	@BusnLocation uMerch,
	@vSettleDay nvarchar(20),
	@SettleYear int,
	@SettleMth int
  as
begin
	declare @SysDate datetime, @PrcsDate datetime, @Year int, @Mth int, @StartPrcsId int, @EndPrcsId int,
			@YearMth varchar(6), @SettleDay datetime

	set nocount on

	select @SettleDay = convert(datetime, @vSettleDay)
	select @SysDate = getdate()
	select @Year = datepart(yy, @SysDate)
	select @Mth = datepart(mm, @SysDate)

	select @PrcsDate = CtrlDate
	from iss_Control where IssNo = @AcqNo and CtrlId = 'PrcsId'

	if @Ind = 'M'
	begin
		if isnull(@SettleYear, 0) > @Year or len(convert(varchar(10), isnull(@SettleYear, 0))) <> 4
			return 95127	--Invalid Settle Date

		if isnull(@SettleMth, 0) < 0 or isnull(@SettleMth, 0) > 12
			return 95127	--Invalid Settle Date

		select @YearMth = convert(varchar(4), @SettleYear) + replicate('0', 2 - len(convert(varchar(2), @SettleMth))) + convert(varchar(2), @SettleMth)
		if isnull(@YearMth, 0) > convert(varchar(6), @PrcsDate, 112)
			return 95127	--Invalid Settle Date
	end
	else
	begin
		if @SettleDay > @SysDate or @SettleDay > @PrcsDate return 95127	--Invalid Settle Date

		if @SettleDay <> @PrcsDate
		begin
			select @StartPrcsId = PrcsId,
					@EndPrcsId = PrcsId
			from cmnv_ProcessLog where IssNo = @AcqNo and day(PrcsDate) = day(@SettleDay) and month(PrcsDate) = month(@SettleDay) and year(PrcsDate) = year(@SettleDay)

			if @@rowcount = 0 or @@error <> 0 return 95127	--Invalid Settle Date
		end
		else
		begin
			select @StartPrcsId = CtrlNo,
				@EndPrcsId = CtrlNo
			from iss_Control (nolock) where IssNo = @AcqNo and CtrlId = 'PrcsId'
	
			if @@rowcount = 0 or @@error <> 0 return 95127	--Invalid Settle Date
		end
	end

	if @BusnLocation is not null
	begin
		if @Ind = 'M'
		begin
			select b.Descp, Cnt, SettleAmt, BillingAmt, MDRAmt, VATAmt,WithholdingTaxAmt, SubsidizedAmt, PrcsDate
			from acq_MerchTaxInvoice a (nolock)
			join iss_RefLib b (nolock) on a.AcqNo = b.IssNo and a.TxnInd = b.RefCd and b.RefType = 'TxnInd'
			where BusnLocation = @BusnLocation and month(PrcsDate) = @SettleMth and year(PrcsDate) = @SettleYear

			if @@error <> 0 return 95127	--Invalid Settle Date
			return 0
		end

		select b.Descp, Cnt, SettleAmt, BillingAmt, MDRAmt, VATAmt,WithholdingTaxAmt, SubsidizedAmt
		from acq_MerchTaxInvoice a (nolock)
		join iss_RefLib b (nolock) on a.AcqNo = b.IssNo and a.TxnInd = b.RefCd and b.RefType = 'TxnInd'
		where BusnLocation = @BusnLocation and PrcsId = @EndPrcsId

		if @@error <> 0 return 95127	--Invalid Settle Date
		return 0
	end

	if @Ind = 'M'
	begin
		select a.BusnLocation 'MerchantNo', b.Descp, Cnt, SettleAmt, BillingAmt, MDRAmt, VATAmt,WithholdingTaxAmt, SubsidizedAmt, a.PrcsDate
		from acq_MerchTaxInvoice a (nolock)
		join iss_RefLib b (nolock) on a.AcqNo = b.IssNo and a.TxnInd = b.RefCd and b.RefType = 'TxnInd'
		join aac_BusnLocation c (nolock) on a.BusnLocation = c.BusnLocation and c.AcctNo = @AcctNo
		where month(a.PrcsDate) = @SettleMth and year(a.PrcsDate) = @SettleYear

		if @@error <> 0 return 95127	--Invalid Settle Date
		return 0
	end

	select a.BusnLocation 'MerchantNo', Cnt, SettleAmt, BillingAmt, MDRAmt, VATAmt,WithholdingTaxAmt, SubsidizedAmt
	from acq_MerchTaxInvoice a (nolock)
	join aac_BusnLocation b (nolock) on a.BusnLocation = b.BusnLocation and b.AcctNo = @AcctNo
	join iss_RefLib c (nolock) on a.AcqNo = c.IssNo and a.TxnInd = c.RefCd and c.RefType = 'TxnInd'
	where PrcsId = @EndPrcsId

	if @@error <> 0 return 95127	--Invalid Settle Date
	return 0
end
GO
