USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GenerateCVC]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*****************************************************************************************************************

Copyright	: Cardtrend Systems Sdn. Bhd.
Modular		: Cardtrend Card Management System (CCMS)- Issuing Module

Objective	: Generate a CVV

-------------------------------------------------------------------------------
When	   Who		CRN		Desc
-------------------------------------------------------------------------------
2004/07/28 Chew Pei			Initial development.
2004/12/01 Chew Pei			Add Seed.
2009/02/12 Sam				Re-code CVV. 					
******************************************************************************************************************/
CREATE procedure [dbo].[GenerateCVC]
	@AcctNo uAcctNo,
	@CardNo uCardNo,
	@SysDate datetime,
	@Cvc varchar(3) output
 
as 
Begin
	set nocount on
	declare @seed int, @TS varchar(15), @V bigint

	--select @TS = convert(varchar(12), getdate(), 114)
	--select @seed = cast ((substring(@TS, 10, 3)+substring(@TS, 7, 2)+substring(@TS, 4, 2)+substring(@TS, 1, 2)) as bigint)
	--select @Cvc = substring(cast(cast((rand(@seed) * 100000000000000) as bigint) as char(15)), 3,3)

	select @TS = convert(varchar(12), @SysDate,112)
	select @V = cast(convert(varchar(30), @SysDate,112) as bigint) + cast(right(cast(@AcctNo as varchar(19)),5) as bigint) + cast(right(cast(@CardNo as varchar(19)),5) as bigint)
	select @Cvc = substring(cast(cast(rand(@V) * 10000000000000 as numeric) as varchar(30)),6,3)
End
GO
