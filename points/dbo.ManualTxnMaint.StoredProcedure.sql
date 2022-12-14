USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ManualTxnMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Manual transaction maintenance.
-------------------------------------------------------------------------------
When	   Who		CRN	    Description
-------------------------------------------------------------------------------
2002/06/21 Sam			    Initial development
2003/03/10 Sam			    Fixes.
2003/06/24 Aeris		    Check condition on CardCategory (General, 
							In-House, Both) of card against the SIC.
2003/08/14 Sam				Checking card range against merchant card range acceptance.
2004/12/01 Chew Pei			Add Dual Card Checking
							- Reject if both cards entered are not from the same account
							- Reject if both cards entered are the same
2005/03/17 Kenny			Add validation on card and account status
*******************************************************************************/

CREATE procedure [dbo].[ManualTxnMaint]
	@Func varchar(5),
	@AcqNo uAcqNo,
	@SrcIds uTxnId,
	@Ids uTxnId output,
	@tCardNo varchar(19),
	@CardExpiry char(4),
	@tAuthCardNo varchar(19),
	@AuthCardExpiry char(4),
	@TxnDate datetime,
	@Amt money,
	@Odometer int,
	@Descp uDescp50,
	@AppvCd char(6),
	@PtsIssued money,
	@InvoiceNo int
  as
begin
	declare @PrcsId uPrcsId,
		@SettleDate datetime,
		@CardNo uCardNo,
		@Descps uDescp50,
		@BatchId uBatchId,
		@TxnCd uTxnCd,
		@CancelDate datetime,
		@SettleAmt money,
		@TxnInd uRefCd,
		@BusnLocation uMerch,
		@TermId uTermId,
		@CtryCd uRefCd,
		@CrryCd uRefCd,
		@TerminateDate datetime,
		@Rrn char(12),
		@ExpiryDate datetime,
		@OldExpiry datetime,
		@Rc int,
		@Rcd int,
		@AuthCardNo uCardNo,
		--2003/06/24B
		@Sic uRefCd,
		@CardCategory uRefCd,
		@AcctNo uAcctNo,
		@Error int,
		@CardRangeId nvarchar(20),
		--2003/06/24E
		@WithheldUnsettleId int,
		@Attribute int,
		@GdAcctSts uRefCd, 
		@GdCardSts uRefCd,
		@AcctSts uRefCd

	set nocount on

	select @CardNo = cast(@tCardNo as bigint)
	select @AuthCardNo = cast(@tAuthCardNo as bigint)

	if @CardNo is null return 55060
	-- Commented by CP 20041201
	--if len(@tCardNo) <> 16 return 95149	--Check Cardholder No or it Card Expiry Date
	if (@AuthCardNo is not null and @AuthCardExpiry is null) or
		(@AuthCardNo is null and @AuthCardExpiry is not null) return 95177
	if isdate(@TxnDate) = 0 return 55122
	if @Amt is null return 55123
	if @AppvCd is null return 55126
	if @InvoiceNo is null return 55125
	
	select @CtryCd = CtryCd,
		@CrryCd = CrryCd
	from acq_Acquirer where AcqNo = @AcqNo

	if @@rowcount = 0 or @@error <> 0 return 60000	--Account not found

	select @PrcsId = CtrlNo
	from iss_Control where IssNo = @AcqNo and CtrlId = 'PrcsId'

	if @@error <> 0
		return 95098	--Unable to retrieve information from iss_Control table

	select @BatchId = BatchId,
--		@PrcsId = PrcsId,
		@TxnCd = TxnCd,
		@SettleDate = SettleDate,
		@SettleAmt = Amt,
		@TxnInd = TxnInd,
		@BusnLocation = a.BusnLocation,
		@TermId = TermId,
		@CancelDate = b.CancelDate
	from atx_SourceSettlement a, aac_BusnLocation b
--	where Ids = @SrcIds and isnull(PrcsId, 0) = 0 and a.BusnLocation = b.BusnLocation
--	Jacky 2002 Nov 30 - PrcsId should have a value
	where Ids = @SrcIds and a.BusnLocation = b.BusnLocation

	if @@rowcount = 0 or @@error <> 0 return 95092

	if @TxnDate > @SettleDate return 95179

	if isdate(@CancelDate) = 1 and @TxnDate > @CancelDate return 95145

	if isdate(@ExpiryDate) = 1
	begin
		if substring(convert(char(10), isnull(@ExpiryDate, getdate()), 112),3,4) <> @CardExpiry return 95178
	end

	-- ***** CP : 20041201 [B] Dual Card Validation ******
	-- Check if CardNo is Dual Card
	if @CardNo is not null
	begin
		select @Attribute = b.Attribute 
		from iac_Card a
		join iss_CardType b on b.CardType = a.CardType
		where a.IssNo = @AcqNo and a.CardNo = @CardNo 
	
		if @Attribute & 1 = 1
		begin
			if @AuthCardNo is null
			begin
				return 95177 -- Check Authorization Card
			end
		end
	end

	-- Check if the AuthExpiryDate is valid 
	if isdate(@AuthCardExpiry) = 1
	begin
		if substring(convert(char(10), isnull(@ExpiryDate, getdate()), 112),3,4) <> @AuthCardExpiry 
		return 95178 -- Invalid Card Expiry Date
	end

	-- Check if Auth Card No is valid
	if @AuthCardNo is not null
	begin
		if not exists (select 1 from iac_Card where CardNo = @AuthCardNo) 
		return 60011 -- Auth Card No Found
	end

	-- Check if Card No and Auth Card No not from the same account
	if @AuthCardNo is not null 
	begin
		if (select AcctNo from iac_Card where CardNo = @CardNo) <>
			 (select AcctNo from iac_Card where CardNo = @AuthCardNo)
		return 95312 -- Invalid Dual Card
	end
	
	if @CardNo is not null and @AuthCardNo is not null
	begin
		-- Check if Card No and Auth Card No has same value
		if @CardNo = @AuthCardNo
			return 95312 -- Invalid Dual Card

		-- Check if Card No and Auth Card No card type the same
		if (select CardType from iac_Card where CardNo = @CardNo) =
			(select CardType from iac_Card where CardNo = @AuthCardNo)
			return 95312 -- Invalid Dual Card

		select @Attribute = b.Attribute from iac_Card a, iss_CardType b 
			where a.IssNo = @AcqNo and a.CardNo = @CardNo and a.CardType = b.CardType 
		-- Check if @CardNo is a dual Card
		-- If yes (bit 1 ON), then continue to validate @AuthCardNo
		if @Attribute & 1 = 1
		begin -- Recode 
			select @Attribute = b.Attribute from iac_Card a, iss_CardType b 
			where a.IssNo = @AcqNo and a.CardNo = @AuthCardNo and a.CardType = b.CardType 
			--if @Attribute & 1  > 0
			--	return 95312 -- Invalid Dual Card
		end
		else
			return 95312 -- Invalid Dual Card

		if (select VehInd from iac_Card a, iss_CardType b
			 where a.CardNo = @CardNo and a.CardType = b.CardType) = 'Y'
			return 95313 -- Invalid Driver Card
	end
	-- ***** CP : 20041201 [E] *******
	
	-- ***** Kenny 20050317 [B] ******
	-- Check account status and card status
	select @GdAcctSts = RefCd from iss_Reflib where RefType = 'AcctSts' and RefInd = 0
	select @GdCardSts = RefCd from iss_Reflib where RefType = 'CardSts' and RefInd = 0

	if @CardNo is not null
	begin
		if (select Sts from iac_Card where CardNo = @CardNo) <> @GdCardSts 
		 return 95064 -- Check on Card Status

		--if (select AcctNo from iac_Card where CardNo = @CardNo ) <> @GdAcctSts

		select @AcctSts = b.Sts from iac_Card a
		join iac_Account b on b.AcctNo = a.AcctNo
		where a.CardNo = @CardNo

		if @AcctSts <> @GdAcctSts return 95267 -- Check Account Status
	end

	if @AuthCardNo is not null
	begin
		if (select Sts from iac_Card where CardNo = @AuthCardNo) <> @GdCardSts 
		 return 95064 -- Check on Card Status

		--if (select AcctNo from iac_Card where CardNo = @AuthCardNo ) <> @GdAcctSts

		select @AcctSts = b.Sts from iac_Card a
		join iac_Account b on b.AcctNo = a.AcctNo
		where a.CardNo = @CardNo

		if @AcctSts <> @GdAcctSts return 95267 -- Check Account Status
	end
	-- ***** Kenny 20050317 [E] ******


	select @ExpiryDate = ExpiryDate, @OldExpiry = OldExpiryDate, @TerminateDate = TerminationDate
	from iac_Card where CardNo = @CardNo

	if @@rowcount = 0 return 60003	-- Card Number not found

	if convert(char(10), isnull(@TxnDate, getdate()), 112) > convert(char(10), isnull(@TerminateDate, getdate()), 112)
		return 95147

	if convert(char(10), isnull(@TxnDate, getdate()), 112) > convert(char(10), isnull(@SettleDate, getdate()), 112)
		return 95179

	--Add Sic 2003/06/24B
	select @Descps = substring(rtrim(DBAName),1,30) + ', ' + substring(ltrim(DBACity),1,18), @Sic= Sic from aac_BusnLocation where AcqNo = @AcqNo and BusnLocation = @BusnLocation

	if @@rowcount = 0 or @@error <> 0 return 60010	--Merchant not found

	--Add Sic 2003/06/24E
	
	--2003/06/24B
	select @CardCategory = CardCategory, @AcctNo = AcctNo, @CardRangeId = CardRangeId
	from iss_CardType a , iac_Card b
	where b.cardNo = @CardNo and a.CardType = b.CardType 

	if @CardCategory <> 'B' and @Sic is not null
	begin
		if @CardCategory <> @Sic return 95253	--Card category not match with the merchant id
	end

	--2003/08/14B
	if not exists (select 1 from acq_CardRangeAcceptance where BusnLocation = @BusnLocation and CardRangeId = @CardRangeId)
		return 95266	--Check Merchant acceptance list
	--2003/08/14E

	if exists (select 1 from iac_CardAcceptance where CardNo = @CardNo )
	begin
		if not exists (select 1 from iac_CardAcceptance where CardNo = @CardNo and BusnLocation = @BusnLocation)
			return 95266	--Check Merchant acceptance list
	end

	if exists (select 1 from iac_AccountAcceptance where AcctNo = @AcctNo)
	begin
		if not exists (select 1 from iac_AccountAcceptance where AcctNo = @AcctNo and BusnLocation = @BusnLocation)
			return 95266	--Check Merchant acceptance list
	end 
	--2003/06/24E

	exec GetRrn @Rrn output

	--2003/11/13B
	select @WithheldUnsettleId = WithheldUnsettleId
	from atx_VAETxn 
	where BusnLocation = @BusnLocation and TermId = @TermId and CardNo = @CardNo and convert(varchar(8),TxnDate,112) = convert(varchar(8),@TxnDate,112) and AuthNo = @AppvCd and Amt = @Amt and Sts = 'A'
	--2003/11/13E

	----------
	begin TRAN
	----------
	if isnull(@Ids,0) > 0 and @Func = 'Save'
	begin
		update atx_SourceTxn
		set CardNo = @CardNo,
			CardExpiry = @CardExpiry,
			AuthCardNo = @AuthCardNo,
			AuthCardExpiry = @AuthCardExpiry,
			TxnDate = @TxnDate,
			Amt = @Amt,
			Odometer = @Odometer,
			Descp = isnull(@Descp, @Descps),
			AuthNo = @AppvCd,
			BillingPts = @PtsIssued,
			InvoiceNo = @InvoiceNo,
			LastUpdDate = getdate(),
			UserId = system_user,
			CtryCd = @CtryCd,
			CrryCd = @CrryCd,
			--2003/03/10B
			PrcsId = @PrcsId,
			--2003/03/10E
			--2003/11/13B
			WithheldUnsettleId = @WithheldUnsettleId
			--2003/11/13E
		where Ids = @Ids

		if @@rowcount = 0 or @@error <> 0
		begin
			rollback tran
		 	return 70229
		end

		select @Rc = 50188
	end
	else
	begin
		insert atx_SourceTxn
		(SrcIds, TxnCd, CardNo, CardExpiry, AuthCardNo, AuthCardExpiry, TxnDate,
		ArrayCnt, Qty, Amt, Pts, BillingAmt, BillingPts, CrryCd, CtryCd,
		LocalDate, LocalTime, Odometer, Rrn, AuthNo, InvoiceNo, DriverCd, Descp,
		Sts, BatchId, PrcsId, LinkIds, TxnInd, LastUpdDate, AcqNo, BusnLocation,
		TermId, UserId, Arn, IssBillingAmt, IssBillingPts, WithheldUnsettleId )
		values
		( @SrcIds, @TxnCd, @CardNo, @CardExpiry, @AuthCardNo, @AuthCardExpiry, @TxnDate,
		0, null, @Amt, 0, 0, 0, @CrryCd, @CtryCd, 
		null, null, @Odometer, @Rrn, @AppvCd, @InvoiceNo, null, isnull(@Descp, @Descps),
		null, @BatchId, @PrcsId, null, @TxnInd, getdate(), @AcqNo, @BusnLocation,
		@TermId, system_user, null, 0, 0, @WithheldUnsettleId )

		select @Ids = @@identity, @Error = @@error

		if @Error <> 0 or isnull(@Ids,0) = 0
		begin
			rollback tran
			return 70228
		end

		select @Rc = 50187
	end

	exec @Rcd = ManualSettlementValidate @AcqNo, @SrcIds

	if @@error <> 0 or @Rcd <> 0
	begin
		rollback transaction
		return 70226 --Failed to update Manual Batch
	end

	-----------
	COMMIT TRAN
	-----------
	return @Rc
end
GO
