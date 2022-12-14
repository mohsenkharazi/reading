USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GetReplacementCardNoIDBB]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Card replacement.

-------------------------------------------------------------------------------
When	   Who		CRN			Desc
-------------------------------------------------------------------------------
2002/11/18 Chew Pei		  		Initial development
2003/08/11 Sam					Changes.
2004/09/28 Chew Pei				Change from @CurrNo to @LatestCard 
2005/09/26 Chew Pei				Validate against iap_ReservedCardNo
******************************************************************************************************************/

CREATE procedure [dbo].[GetReplacementCardNoIDBB]
	@OrigCardNo uCardNo,
	@NewCardNo uCardNo output
  as
begin
	declare @Rc tinyint, @StartNo uCardNo, @EndNo uCardNo, 
			@CurrNo uCardNo, @CardRangeId nvarchar(20), @NextCardNo uCardNo,
			@Error int, @Rowcount int

	set nocount on

	select @StartNo = c.StartNo,
			@EndNo = c.EndNo,
			@CurrNo = c.CurrNo,
			@CardRangeId = c.CardRangeId
	from iac_Card a
	join iss_CardType b on a.CardLogo = b.CardLogo and a.CardType = b.CardType
	join iss_CardRange c on b.CardRangeId = c.CardRangeId
	where a.CardNo = @OrigCardNo

	if @@rowcount = 0 or @@error <> 0 return 60003	--Card Number not found

	select @NextCardNo = @CurrNo + 1
	
--****
	while 1 = 1
	begin
		if exists (select 1 from iap_ReservedCardNo 
					where substring(cast(CardNo as varchar(19)), 1, 15) = @NextCardNo) -- unused reserved card
		begin
			update iss_CardRange
			set CurrNo = @NextCardNo
			where CardRangeId = @CardRangeId 

			select @NextCardNo = CurrNo + 1 from iss_CardRange where CardRangeId = @CardRangeId
		end
		else
		break
	end
--****
--	while 1 = 1
--	begin
--		select @LatestCard = @CurrNo + 1
		if @NextCardNo < @StartNo or @NextCardNo > @EndNo return 95046	--Card Prefix already exist in the available range

		-- Get Check Digit (@rc = @CheckDigit)
		exec @Rc = GetCheckDigit @NextCardNo
		
		update iss_CardRange
		set CurrNo = @NextCardNo
		where CardRangeId = @CardRangeId

--		select @Rowcount = @@rowcount, @Error = @@error

		if @Error <> 0 return 70133  --Failed to replace card

--		if @Rowcount = 0
--		begin
--			select @StartNo = c.StartNo,
--					@EndNo = c.EndNo,
--					@CurrNo = c.CurrNo,
--					@CardRangeId = c.CardRangeId
--			from iac_Card a
--			join iss_CardType b on a.CardLogo = b.CardLogo and a.CardType = b.CardType
--			join iss_CardRange c on b.CardRangeId = c.CardRangeId
--			where a.CardNo = @OrigCardNo
--
--			if @@rowcount = 0 or @@error <> 0 return 60003	--Card Number not found
--		end
--		else
--		begin
			-- CP : 20040928 - Change from @CurrNo to @LatestCard 
			select @NewCardNo = cast(convert(varchar(19), @NextCardNo) + cast(@Rc as char(1)) as bigint)
			return 50105	--Card has been replaced successfully
--		end
--	end
end
GO
