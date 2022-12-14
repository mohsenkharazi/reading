USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ManualTxnDetailValidate]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Manual transaction detail validation.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/26 Sam			   Initial development
2004/06/08 Chew Pei			Change parameter @Seq datatype from smallint to int
*******************************************************************************/

CREATE procedure [dbo].[ManualTxnDetailValidate]
	@SrcIds uTxnId,
	@IssNo uIssNo,
	@BatchId uBatchId,
	@Seq int,
	@vCardNo varchar(19),
	@Ids uTxnId,
	@ProdCd uProdCd,
	@AmtPts money,
	@Qty money,
	@UnitPrice money,
	@BusnLocation uMerch
  as
begin
	declare @ePricePerUnit money, @ProdGroup uRefCd, @ActiveSts uRefCd, @CardNo uCardNo,
		@AcctNo uAcctNo, @CardAcctInd char(1), @VelInd char(1),
		@Limit money, @LimitCnt int, @Spent money, @SpentCnt int, @LastUpdDate datetime,
		@Amt money, @Rc int, @CostCentre uCostCentre, @Litre money, @SpentLitre money,
		@SysDate datetime

	set nocount on

	select @CardNo = cast(@vCardNo as bigint)
	select @SysDate = getdate()

	if isnull(@ProdCd, '0') = '0' return 55023	--Product Code is a compulsory field
	if isnull(@AmtPts, 0) = 0 return 55119	--Amount is a compulsory field

	select @AcctNo = AcctNo, @CostCentre = CostCentre
	from iac_Card where CardNo = @CardNo

	if @@rowcount = 0 or @@error <> 0 return 60003 --Card Number not found

	if exists (select 1 from iaa_ProductUtilization where IssNo = @IssNo and CardNo = @CardNo)
	begin
		if not exists (select 1 from iaa_ProductUtilization where IssNo = @IssNo and CardNo = @CardNo and ProdCd = @ProdCd)
			return 95058 --Product Code is not applicable to this card
	end

	if exists (select 1 from iaa_ProductUtilization where IssNo = @IssNo and AcctNo = @AcctNo)
	begin
		if not exists (select 1 from iaa_ProductUtilization where IssNo = @IssNo and AcctNo = @AcctNo and ProdCd = @ProdCd)	
			return 95268 --Product Code is not applicable to this account
	end

	select @ProdCd = isnull(@ProdCd,'0')
	select @Qty = isnull(@Qty,0)
	select @AmtPts = isnull(@AmtPts,0)

	if exists (select 1 from iac_CardVelocityLimit where CardNo = @CardNo and isnull(ProdCd, '0') > '0')
	begin
		select @CardAcctInd = 'C', @VelInd = 'D'
		if @ProdCd > '0'
		begin
			select @Amt = @AmtPts, @Qty = @Qty, @ProdCd = @ProdCd

			select @Limit = isnull(VelocityLimit, 0),
				@LimitCnt = isnull(VelocityCnt, 0),
				@Spent = isnull(SpentLimit, 0),
				@SpentCnt = isnull(SpentCnt, 0),
				@LastUpdDate = LastUpdDate
			from iac_CardVelocityLimit where CardNo = @CardNo and VelocityInd = @VelInd and ProdCd = @ProdCd

			if @@rowcount > 0 and @@error = 0
			begin
				exec @Rc = OnlineLimitCheck @CardAcctInd, @VelInd, @Amt, @Qty, @Limit, @LimitCnt, @Spent, @SpentCnt, @Litre, @SpentLitre, @LastUpdDate, @SysDate, @ProdCd

				if @@error <> 0 or dbo.CheckRC(@Rc) <> 0 return @Rc
			end
		end

		select @VelInd = 'M'
		if @ProdCd > '0'
		begin
			select @Amt = @AmtPts, @Qty = @Qty, @ProdCd = @ProdCd

			select @Limit = isnull(VelocityLimit, 0),
				@LimitCnt = isnull(VelocityCnt, 0),
				@Spent = isnull(SpentLimit, 0),
				@SpentCnt = isnull(SpentCnt, 0),
				@LastUpdDate = LastUpdDate
			from iac_CardVelocityLimit where CardNo = @CardNo and VelocityInd = @VelInd and ProdCd = @ProdCd

			if @@rowcount > 0 and @@error = 0
			begin
				exec @Rc = OnlineLimitCheck @CardAcctInd, @VelInd, @Amt, @Qty, @Limit, @LimitCnt, @Spent, @SpentCnt, @Litre, @SpentLitre, @LastUpdDate, @SysDate, @ProdCd
				
				if @@error <> 0 or dbo.CheckRC(@Rc) <> 0 return @Rc
			end
		end

		select @VelInd = 'W'
		if @ProdCd > '0'
		begin
			select @Amt = @AmtPts, @Qty = @Qty, @ProdCd = @ProdCd

			select @Limit = isnull(VelocityLimit, 0),
				@LimitCnt = isnull(VelocityCnt, 0),
				@Spent = isnull(SpentLimit, 0),
				@SpentCnt = isnull(SpentCnt, 0),
				@LastUpdDate = LastUpdDate
			from iac_CardVelocityLimit where CardNo = @CardNo and VelocityInd = @VelInd and ProdCd = @ProdCd

			if @@rowcount > 0 and @@error = 0
			begin
				exec @Rc = OnlineLimitCheck @CardAcctInd, @VelInd, @Amt, @Qty, @Limit, @LimitCnt, @Spent, @SpentCnt, @Litre, @SpentLitre, @LastUpdDate, @SysDate, @ProdCd

				if @@error <> 0 or dbo.CheckRC(@Rc) <> 0 return @Rc
			end
		end

		select @VelInd = 'Y'
		if @ProdCd > '0'
		begin
			select @Amt = @AmtPts, @Qty = @Qty, @ProdCd = @ProdCd

			select @Limit = isnull(VelocityLimit, 0),
				@LimitCnt = isnull(VelocityCnt, 0),
				@Spent = isnull(SpentLimit, 0),
				@SpentCnt = isnull(SpentCnt, 0),
				@LastUpdDate = LastUpdDate
			from iac_CardVelocityLimit where CardNo = @CardNo and VelocityInd = @VelInd and ProdCd = @ProdCd

			if @@rowcount > 0 and @@error = 0
			begin
				exec @Rc = OnlineLimitCheck @CardAcctInd, @VelInd, @Amt, @Qty, @Limit, @LimitCnt, @Spent, @SpentCnt, @Litre, @SpentLitre, @LastUpdDate, @SysDate, @ProdCd

				if @@error <> 0 or dbo.CheckRC(@Rc) <> 0 return @Rc
			end
		end
	end

	----
	--CC
	----
	if exists (select 1 from iaa_CostCentreVelocityLimit where AcctNo = @AcctNo and CostCentre = @CostCentre and isnull(ProdCd, '0') > '0')
	begin
		select @CardAcctInd = 'D', @VelInd = 'D'
		if @ProdCd > '0'
		begin
			select @Amt = @AmtPts, @Qty = @Qty, @ProdCd = @ProdCd

			select @Limit = isnull(VelocityLimit, 0),
				@LimitCnt = isnull(VelocityCnt, 0),
				@Spent = isnull(SpentLimit, 0),
				@SpentCnt = isnull(SpentCnt, 0),
				@LastUpdDate = LastUpdDate
			from iaa_CostCentreVelocityLimit where AcctNo = @AcctNo and CostCentre = @CostCentre and VelocityInd = @VelInd and ProdCd = @ProdCd

			if @@rowcount > 0 and @@error = 0
			begin
				exec @Rc = OnlineLimitCheck @CardAcctInd, @VelInd, @Amt, @Qty, @Limit, @LimitCnt, @Spent, @SpentCnt, @Litre, @SpentLitre, @LastUpdDate, @SysDate, @ProdCd

				if @@error <> 0 or dbo.CheckRC(@Rc) <> 0 return @Rc
			end
		end

		select @VelInd = 'M'
		if @ProdCd > '0'
		begin
			select @Amt = @AmtPts, @Qty = @Qty, @ProdCd = @ProdCd

			select @Limit = isnull(VelocityLimit, 0),
				@LimitCnt = isnull(VelocityCnt, 0),
				@Spent = isnull(SpentLimit, 0),
				@SpentCnt = isnull(SpentCnt, 0),
				@LastUpdDate = LastUpdDate
			from iaa_CostCentreVelocityLimit where AcctNo = @AcctNo and CostCentre = @CostCentre and VelocityInd = @VelInd and ProdCd = @ProdCd

			if @@rowcount > 0 and @@error = 0
			begin
				exec @Rc = OnlineLimitCheck @CardAcctInd, @VelInd, @Amt, @Qty, @Limit, @LimitCnt, @Spent, @SpentCnt, @Litre, @SpentLitre, @LastUpdDate, @SysDate, @ProdCd

				if @@error <> 0 or dbo.CheckRC(@Rc) <> 0 return @Rc
			end
		end

		select @VelInd = 'W'
		if @ProdCd > '0'
		begin
			select @Amt = @AmtPts, @Qty = @Qty, @ProdCd = @ProdCd

			select @Limit = isnull(VelocityLimit, 0),
				@LimitCnt = isnull(VelocityCnt, 0),
				@Spent = isnull(SpentLimit, 0),
				@SpentCnt = isnull(SpentCnt, 0),
				@LastUpdDate = LastUpdDate
			from iaa_CostCentreVelocityLimit where AcctNo = @AcctNo and CostCentre = @CostCentre and VelocityInd = @VelInd and ProdCd = @ProdCd

			if @@rowcount > 0 and @@error = 0
			begin
				exec @Rc = OnlineLimitCheck @CardAcctInd, @VelInd, @Amt, @Qty, @Limit, @LimitCnt, @Spent, @SpentCnt, @Litre, @SpentLitre, @LastUpdDate, @SysDate, @ProdCd

				if @@error <> 0 or dbo.CheckRC(@Rc) <> 0 return @Rc
			end
		end

		select @VelInd = 'Y'
		if @ProdCd > '0'
		begin
			select @Amt = @AmtPts, @Qty = @Qty, @ProdCd = @ProdCd

			select @Limit = isnull(VelocityLimit, 0),
				@LimitCnt = isnull(VelocityCnt, 0),
				@Spent = isnull(SpentLimit, 0),
				@SpentCnt = isnull(SpentCnt, 0),
				@LastUpdDate = LastUpdDate
			from iaa_CostCentreVelocityLimit where AcctNo = @AcctNo and CostCentre = @CostCentre and VelocityInd = @VelInd and ProdCd = @ProdCd

			if @@rowcount > 0 and @@error = 0
			begin
				exec @Rc = OnlineLimitCheck @CardAcctInd, @VelInd, @Amt, @Qty, @Limit, @LimitCnt, @Spent, @SpentCnt, @Litre, @SpentLitre, @LastUpdDate, @SysDate, @ProdCd

				if @@error <> 0 or dbo.CheckRC(@Rc) <> 0 return @Rc
			end
		end
	end

	---------
	--Account
	---------
	if exists (select 1 from iac_AccountVelocityLimit where AcctNo = @AcctNo and ProdCd > '0')
	begin
		select @CardAcctInd = 'A', @VelInd = 'D'
		if @ProdCd > '0'
		begin
			select @Amt = @AmtPts, @Qty = @Qty, @ProdCd = @ProdCd

			select @Limit = isnull(VelocityLimit, 0),
				@LimitCnt = isnull(VelocityCnt, 0),
				@Spent = isnull(SpentLimit, 0),
				@SpentCnt = isnull(SpentCnt, 0),
				@LastUpdDate = LastUpdDate
			from iac_AccountVelocityLimit where AcctNo = @AcctNo and VelocityInd = @VelInd and ProdCd = @ProdCd

			if @@rowcount > 0 and @@error = 0
			begin
				exec @Rc = OnlineLimitCheck @CardAcctInd, @VelInd, @Amt, @Qty, @Limit, @LimitCnt, @Spent, @SpentCnt, @Litre, @SpentLitre, @LastUpdDate, @SysDate, @ProdCd

				if @@error <> 0 or dbo.CheckRC(@Rc) <> 0 return @Rc
			end
		end

		select @VelInd = 'M'
		if @ProdCd > '0'
		begin
			select @Amt = @AmtPts, @Qty = @Qty, @ProdCd = @ProdCd

			select @Limit = isnull(VelocityLimit, 0),
				@LimitCnt = isnull(VelocityCnt, 0),
				@Spent = isnull(SpentLimit, 0),
				@SpentCnt = isnull(SpentCnt, 0),
				@LastUpdDate = LastUpdDate
			from iac_AccountVelocityLimit where AcctNo = @AcctNo and VelocityInd = @VelInd and ProdCd = @ProdCd

			if @@rowcount > 0 and @@error = 0
			begin
				exec @Rc = OnlineLimitCheck @CardAcctInd, @VelInd, @Amt, @Qty, @Limit, @LimitCnt, @Spent, @SpentCnt, @Litre, @SpentLitre, @LastUpdDate, @SysDate, @ProdCd

				if @@error <> 0 or dbo.CheckRC(@Rc) <> 0 return @Rc
			end
		end

		select @VelInd = 'W'
		if @ProdCd > '0'
		begin
			select @Amt = @AmtPts, @Qty = @Qty, @ProdCd = @ProdCd

			select @Limit = isnull(VelocityLimit, 0),
				@LimitCnt = isnull(VelocityCnt, 0),
				@Spent = isnull(SpentLimit, 0),
				@SpentCnt = isnull(SpentCnt, 0),
				@LastUpdDate = LastUpdDate
			from iac_AccountVelocityLimit where AcctNo = @AcctNo and VelocityInd = @VelInd and ProdCd = @ProdCd

			if @@rowcount > 0 and @@error = 0
			begin
				exec @Rc = OnlineLimitCheck @CardAcctInd, @VelInd, @Amt, @Qty, @Limit, @LimitCnt, @Spent, @SpentCnt, @Litre, @SpentLitre, @LastUpdDate, @SysDate, @ProdCd

				if @@error <> 0 or dbo.CheckRC(@Rc) <> 0 return @Rc
			end
		end

		select @VelInd = 'Y'
		if @ProdCd > '0'
		begin
			select @Amt = @AmtPts, @Qty = @Qty, @ProdCd = @ProdCd

			select @Limit = isnull(VelocityLimit, 0),
				@LimitCnt = isnull(VelocityCnt, 0),
				@Spent = isnull(SpentLimit, 0),
				@SpentCnt = isnull(SpentCnt, 0),
				@LastUpdDate = LastUpdDate
			from iac_AccountVelocityLimit where AcctNo = @AcctNo and VelocityInd = @VelInd and ProdCd = @ProdCd

			if @@rowcount > 0 and @@error = 0
			begin
				exec @Rc = OnlineLimitCheck @CardAcctInd, @VelInd, @Amt, @Qty, @Limit, @LimitCnt, @Spent, @SpentCnt, @Litre, @SpentLitre, @LastUpdDate, @SysDate, @ProdCd

				if @@error <> 0 or dbo.CheckRC(@Rc) <> 0 return @Rc
			end
		end
	end

	return 0
end
GO
