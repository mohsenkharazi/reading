USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[InitProcess]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Security Module

Objective	:

SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/01/24 Admin		   Initial development

*******************************************************************************/

CREATE procedure [dbo].[InitProcess]
  as
begin
	declare @Rem char(20), @SysDate datetime, @RemDate datetime,
		@iVal1 smallint, @iVal2 smallint, @iVal3 smallint, @iVal4 smallint,
		@Val1 char(2), @Val2 char(2), @Val3 char(2), @Val4 char(2), @cVal char(5),
		@vResult1 smallint, @vResult2 smallint, @vResult3 smallint, @vResult4 smallint,
		@iResult1 smallint, @iResult2 smallint, @iResult3 smallint, @iResult4 smallint

	select @SysDate = getdate()

	select @Rem = Remarks from acq_Acquirer where AcqNo = 1
	if @@error <> 0 return 99991

	if (select len(@Rem)) <> 20 return 99993

	select @Val1 = substring(@Rem, 4,2),
		@Val2 = substring(@Rem, 9,2),
		@Val3 = substring(@Rem, 14,2),
		@Val4 = substring(@Rem, 19,2)

--	substring(convert(char(20), cast((rand(@Val2) * 1000000000000000000) as bigint)),7,3)
	select @vResult1 = cast(substring(convert(char(20), cast((rand(@Val1) * 10000000000000000) as bigint)),1,3) as smallint)
	select @vResult2 = cast(substring(convert(char(20), cast((rand(@Val2) * 10000000000000000) as bigint)),4,3) as smallint)
	select @vResult3 = cast(substring(convert(char(20), cast((rand(@Val3) * 10000000000000000) as bigint)),7,3) as smallint)
	select @vResult4 = cast(substring(convert(char(20), cast((rand(@Val4) * 10000000000000000) as bigint)),10,3) as smallint)

	select @iResult1 = cast(substring(@Rem, 1,3) as smallint),
		@iResult2 = cast(substring(@Rem, 6,3) as smallint),
		@iResult3 = cast(substring(@Rem, 11,3) as smallint),
		@iResult4 = cast(substring(@Rem, 16,3) as smallint)

	if (@iResult1 <> @vResult1) or (@iResult2 <> @vResult2) or (@iResult3 <> @vResult3) or (@iResult4 <> @vResult4) 
		return 99994

	select @cVal =
	case @Val3 
		when '01' then ' Jan '
		when '02' then ' Feb '
		when '03' then ' Mar '
		when '04' then ' Apr '
		when '05' then ' May '
		when '06' then ' Jun '
		when '07' then ' Jul '
		when '08' then ' Aug '
		when '09' then ' Sep '
		when '10' then ' Oct '
		when '11' then ' Nov '
		else ' Dec '
	end

	select @RemDate = cast(@Val1 + @Val2 + @cVal + @Val4 as datetime)
	if isdate(@RemDate) != 1 return 99992

	if convert(char(8), @SysDate, 112) > convert(char(8),@RemDate, 112)
	begin
		return 99999
	end
	return 0
end
GO
