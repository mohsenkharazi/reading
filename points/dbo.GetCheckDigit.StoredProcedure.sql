USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GetCheckDigit]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure will return the check digit for the input card no

-------------------------------------------------------------------------------
When	   Who		CRN		Desc
-------------------------------------------------------------------------------
2001/11/21 Jac			  	Initial development
					All remarks follow by ** is for further rework/recode.

******************************************************************************************************************/
--exec GetCheckDigit 876543100000002
CREATE procedure [dbo].[GetCheckDigit]
	@CardNo uCardNo	
  as
begin
	declare	@CheckDigit int,
		@Length int,
		@CharCount int,
		@Value int

	select @CheckDigit = 0
	select @Length = datalength(ltrim(rtrim(@CardNo)))
	select @CharCount = 1

	-- Summing the even digits, starts from the right
	while @Length > 0
	begin
		select @Value = ( cast(substring(cast(@CardNo as varchar(20)),@Length,1) as int) * (1+@CharCount))
		select @CharCount = 1 - @CharCount
		select @Length = @Length - 1

		if @Value > 9
		begin
			select @CheckDigit = @CheckDigit + (@Value/10) + (@Value%10)
		end
		else
		begin
			select @CheckDigit = @CheckDigit + @Value
		end
	end

	-- Generating the check digit
	if (@CheckDigit % 10) = 0
		select @CheckDigit = 0
	else
		select @CheckDigit = 10 - (@CheckDigit % 10)


	-- Intergrate with card number

	select @CardNo = cast((cast(@CardNo as varchar(19)) + cast(@CheckDigit as char(1))) as bigint)
	--select @CheckDigit as 'CheckDigit'
	return @CheckDigit
end
GO
