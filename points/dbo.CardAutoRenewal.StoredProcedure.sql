USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardAutoRenewal]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure is to part of the End-Of-Day process, use for Auto-Renewal of membership
		or Card.


-------------------------------------------------------------------------------
When	   Who		CRN		Desc
-------------------------------------------------------------------------------
2001/02/25 CK			  	Initial development
					All remarks follow by ** is for further rework/recode.
2004/05/11 Chew Pei			Re-developed
2006/03/14 Alex				Update The Expiry Date base on each Plastic Type
2008/06/26 Peggy			Add AcctSts checking
******************************************************************************************************************/
-- exec CardAutoRenewal 1
CREATE procedure [dbo].[CardAutoRenewal]
	@IssNo uIssNo
   as
begin
	declare @RenewalPeriod tinyint,
		@CtrlId varchar(20),
		@RefCd uRefCd,
		@RefType varchar(8),
		@Descp nvarchar(8),
		@PrcsDate datetime,
		@Count int,
		@RenewalCardSts varchar(2),
		@Year int

	select @RenewalPeriod = IntVal
	from iss_Default
	where Deft = 'RenewalPeriod'
	and IssNo = @IssNo

	select @PrcsDate = CtrlDate,	
			@Year = datepart(yyyy, CtrlDate)		
	from iss_Control
	where IssNo = @IssNo and CtrlId = 'PrcsId'


	select a.*
	into #iac_Card
	from iac_Card a
	join iss_PlasticType b on a.CardLogo = b.CardLogo and a.PlasticType = b.PlasticType 
	join iss_Reflib c on a.IssNo = c.IssNo and a.Sts = c.RefCd and c.RefType = 'CardSts'and (c.MapInd & 1) > 0
	join iac_Account d on d.AcctNo = a.AcctNo and d.IssNo = a.IssNo
	join iss_RefLib e on e.IssNo = a.IssNo and e.RefCd = d.Sts and e.RefType = 'AcctSts' and e.RefInd = 0 
	where a.IssNo = @IssNo and a.RenewalInd = 'Y' and a.TerminationDate is null
	      and datediff(mm, @PrcsDate, a.ExpiryDate) <= b.AutoRenewalMth
	      and datediff(mm, @PrcsDate, a.ExpiryDate) >= 0 and @PrcsDate <= a.ExpiryDate



	-- Selecting the values into #iac_Card table
	-- *Business Date + Renewal Period should exceed card expiry date for renewal
	
	select @Count = count(*)
	from #iac_Card
	
	if isnull(@Count,0) > 0	-- If records are found
	begin
		BEGIN TRANSACTION

		-- Porting the Expiry date to the Old Expiry date field
		update #iac_Card
		set OldExpiryDate = ExpiryDate
		
		-- Update a new expiry period
		update a
		--set a.ExpiryDate = convert(char(8),dateadd(month, b.CardExpiryPeriod + @RenewalPeriod, @PrcsDate),112)
		set a.ExpiryDate = convert(char(8),dateadd(month, b.CardExpiryPeriod, ExpiryDate),112)
		from #iac_Card a
		inner join iss_PlasticType b
		on a.PlasticType = b.PlasticType
		and a.CardLogo = b.CardLogo
		and a.IssNo = b.IssNo
		if @@error <> 0
		begin
			rollback transaction
			return 70132
		end

		-- Updating the iac_Card table
		update a
		set a.ExpiryDate = b.ExpiryDate,
			a.OldExpiryDate = b.OldExpiryDate
		from iac_Card a
		inner join #iac_Card b
		on a.CardNo = b.CardNo
		and a.AcctNo = b.AcctNo
		and a.IssNo = b.IssNo
		and a.PlasticType = b.PlasticType

		if @@error <> 0
		begin
			rollback transaction
			return 70132
		end

		-- Update ExpiryDate at Account Level
		update a
		set ExpiryDate = b.ExpiryDate
		from iac_Account a, #iac_Card b
		where a.AcctNo = b.AcctNo and a.IssNo = b.IssNo

		if @@error <> 0
		begin
			rollback transaction
			return 70124 -- Failed to update account
		end

		-- Update iac_AnnualFee if AnnualFee is not charged earlier
		update a
		set a.ExpiryDate = replicate('0', 2 - len(convert(varchar(2), datepart(mm, b.ExpiryDate))))+ cast(datepart(mm, b.ExpiryDate) as varchar) + '/' + cast(@Year as varchar),
			a.FeeCd = b.AnnlFeeCd		
		from iac_AnnualFee a, iac_Card b
		where a.CardNo = b.CardNo and a.FeeCd is null and a.Sts is null
		and (a.ExpiryDate is null or right(a.ExpiryDate,4) <> @Year)
		and a.BatchId is null

		-- Insert new record in Plastic Card for embossing
		insert iac_PlasticCard (IssNo, BatchId, CardLogo, PlasticType, AcctNo, CardNo,
			EmbName, ExpiryDate, InputSrc, CreationDate, Sts)
		select	@IssNo, null, CardLogo, PlasticType, AcctNo, CardNo,
			EmbName, ExpiryDate, 'RNW', getdate(), null
		from #iac_Card

		if @@error <> 0
		begin
			rollback transaction
			return 70352	-- Failed to create Plastic Card
		end

		drop table #iac_Card

		COMMIT TRANSACTION
	end
	else
	begin
		return 54022
	end
end
GO
