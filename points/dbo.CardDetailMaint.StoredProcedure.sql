USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardDetailMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	:To update existing card details.
-------------------------------------------------------------------------------
When	   Who		CRN	  	Description
-------------------------------------------------------------------------------
2002/01/28 Wendy			Initial development
2004/02/19 Chew Pei			Change data type of cost centre from uRefCd to uCostCentre
2004/07/14 Chew Pei			Add LastUpdDate
2004/07/21 Chew Pei			Insert record into iac_AnnualFee for Auto Renewal
2004/11/23 Alex 			Add StaffNo
2004/11/26 Alex				Add GovernmentLevy
2008/03/06 Peggy			Add PhotographerType, JoinDate
2009/03/18 Barnett			Add Card Type
*******************************************************************************/

CREATE procedure [dbo].[CardDetailMaint]
	@CardNo varchar(19),
	@EmbName nvarchar(26),
	@Cvc varchar(3),
	@XrefCardNo uCardNo,
	@ProdGroup uProdGroup,
	@CostCentre uCostCentre,
	@PartnerRefNo varchar(19),
	@AnnlFeeCd uRefCd,
	@TerminationDate datetime,
	@RenewalInd char(1),
	@LastUpdDate varchar(30),
	@StaffNo uRefCd,
	@GovernmentLevyFeeCd uRefCd,
	@JoinDate datetime,
	@PhotographerType uRefCd,
	@CardTypeId uCardType,
	@CardChkInd uRefCd
   as
begin
	declare @LatestUpdDate datetime
	declare @Sts char(1)

--	if @EmbName is null return 55059
	if @CardTypeId is null return 55048 -- Card Type is a compulsory field
--	if @AnnlFeeCd is null return 55050
	-----------------
	BEGIN TRANSACTION
	-----------------
	
	-- Annual fee update [B]
/*	if @RenewalInd is not null
	begin
		-- Sts is null means annual fee has not been charged
		if not exists (select 1 from iac_AnnualFee where CardNo = @CardNo)
		begin
			insert into iac_AnnualFee (IssNo, AcctNo, CardNo, ExpiryDate, FeeCd, Sts)
			--select IssNo, AcctNo, CardNo, replicate('0', 2 - len(convert(varchar(2), datepart(mm, ExpiryDate))))+ cast(datepart(mm, ExpiryDate) as varchar) + '/' + cast(datepart(yyyy, ExpiryDate) as varchar), AnnlFeeCd, null
			select IssNo, AcctNo, CardNo, null, AnnlFeeCd, null -- insert Expiry Date with value during Annual Fee Processing
			from iac_Card where CardNo = @CardNo
			if @@error <> 0
			begin
				return 95217 -- Failed to generate AnnualFee
			end
		end
		else
		begin
			select @Sts = Sts from iac_AnnualFee where CardNo = @CardNo
			if @Sts is null
			begin
				update a
				set FeeCd = b.AnnlFeeCd
				from iac_AnnualFee a, iac_Card b
				where a.CardNo = b.CardNo and b.CardNo = @CardNo

				if @@error <> 0
				begin
					rollback transaction
					return 70870 -- Failed to update annual fee
				end
			end
		end
	end	
	-- Annual Fee update [E]*/
	
	-- LastUpdDate validation [B]
	if @LastUpdDate is null
		select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

	select @LatestUpdDate = LastUpdDate from iac_Card where CardNo = convert(bigint,@CardNo)
	if @LatestUpdDate is null
		select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

	-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
	-- it means that record has been updated by someone else, and screen need to be refreshed
	-- before the next update.
	if @LatestUpdDate = convert(datetime, @LastUpdDate)
	begin
		update iac_Card 
		set EmbName = @EmbName, 
			Cvc = @Cvc, 
			XrefCardNo = @XrefCardNo,
			ProdGroup = @ProdGroup, 
			CostCentre = @CostCentre, 
			PartnerRefNo = @PartnerRefNo,
			AnnlFeeCd = @AnnlFeeCd, 
			TerminationDate = @TerminationDate,
			RenewalInd = @RenewalInd,
			LastUpdDate = getdate(),
			StaffNo = @StaffNo,
			GovernmentLevyFeeCd = @GovernmentLevyFeeCd,
			JoinDate = @JoinDate,
			PhotographerType = @PhotographerType,
			CardType = @CardTypeId,
			CardChkInd = @CardChkInd
		where CardNo=convert(bigint,@CardNo)
		
		if @@rowcount = 0 
		begin
			rollback transaction
			return 70132 -- Failed to update Card Detail
		end
	end
	else
	begin
		rollback transaction
		return 95307 -- Session Expired
	end
	-- LastUpdDate validation [E]
	
	------------------
	COMMIT TRANSACTION
	------------------

	return 50103 -- Card Detail has been updated successfully

end
GO
