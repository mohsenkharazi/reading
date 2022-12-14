USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GetCardNo]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This is the Card No allocation stored procedure

-------------------------------------------------------------------------------
When	   Who		CRN		Desc
-------------------------------------------------------------------------------
2003/06/10 Aeris			Initial development
2005/09/23 Chew Pei			Validate against iap_ReservedCardNo			
******************************************************************************************************************/

CREATE procedure [dbo].[GetCardNo]
	@IssNo uIssNo,
	@CardLogo uCardLogo,
	--@PlasticType uPlasticType,
	--@CardPrefix varchar(19) = null,
	@CardType uCardType = null,
	@CardNo bigint output
 
as 
Begin
	declare @NextCardNo bigint, @EndNo bigint, @Increment int, @CheckDigit int, @Len int, @CharCount int,
		@Value int, @CardRangeId nvarchar(20)

	set nocount on

 	select @Increment = 1, @Len = 0
		
	--Generate the Card No
	select @NextCardNo = (case When isnull(c.CurrNo,0) = 0 Then c.StartNo-@Increment Else c.CurrNo End) + @Increment, 
			@EndNo = c.EndNo , @CardRangeId = c.CardRangeId
	from  iss_CardLogo a, iss_CardType b,  iss_CardRange c
	where a.IssNo = @IssNo and a.CardLogo = @CardLogo and a.CardLogo = b.CardLogo
			and b.CardType = @CardType and b.CardRangeId = c.CardRangeId 

	if @NextCardNo is null return 95164	-- Unable to select next card number

	if @EndNo > 0
		select @Len = len(cast(@EndNo as varchar(30)))
	else
		select @Len = len(cast(@NextCardNo as varchar(30)))

	-- CP 20050923[B]
	while 1 = 1
	begin
		if not exists (select 1 from iap_ReservedCardNo where substring(cast(CardNo as varchar(19)),1,@Len) = @NextCardNo)
			break

		update iss_CardRange
		set CurrNo = @NextCardNo
		where CardRangeId = @CardRangeId 

		select @NextCardNo = CurrNo + 1 
		from iss_CardRange (nolock) where CardRangeId = @CardRangeId
	end
	-- 20050923 [E]

	update iss_CardRange
	set CurrNo = @NextCardNo
	where CardRangeId = @CardRangeId
	
	if @NextCardNo <= @EndNo
	begin
		-- Generate the Check Digit
		select @CheckDigit = 0
		select @Len = datalength(ltrim(rtrim(@NextCardNo)))
		select @CharCount = 1
	end

	while @Len > 0
	begin
		select @Value = ( cast(substring(cast(@NextCardNo as varchar(20)),@Len,1) as int) * (1+@CharCount))
		select @CharCount = 1 - @CharCount
		select @Len = @Len - 1

		if @Value > 9
		begin
			select @CheckDigit = @CheckDigit + (@Value/10) + (@Value%10)
		end
		else
		begin
			select @CheckDigit = @CheckDigit + @Value
		end
	end


	if (@CheckDigit % 10) = 0
		select @CheckDigit = 0
	else
		select @CheckDigit = 10 - (@CheckDigit % 10)

	-- Intergrate card number with check digit
	select @CardNo = cast(cast(@NextCardNo as varchar(19)) + cast(@CheckDigit as char(1)) as bigint)

	return 0
end
GO
