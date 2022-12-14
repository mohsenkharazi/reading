USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GeneratePIN]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Generate cardholder PIN
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/11/12 Jacky		   Initial development
2007/03/02 Darren		   Add new parameter when calling xp_Encrypt
				   (Support new xp_Cryptor.dll)
*******************************************************************************/

CREATE procedure [dbo].[GeneratePIN]
	@CardNo uCardNo,
	@PINBlock varchar(16) output
  as
begin
	declare	@C1 varchar(16),
		@C2 varchar(16),
		@V varchar(16),
		@rc bigint,
		@TS varchar(15),
		@seed int,
		@rn int,
		@HostPIN varchar(16)

	while 1 = 1
	begin
		select @TS = convert(varchar(12), getdate(), 114)
	
		select @seed = cast ((substring(@TS, 10, 3)+substring(@TS, 7, 2)+substring(@TS, 4, 2)+substring(@TS, 1, 2)) as bigint)
	
		select @seed = @seed + cast(substring(cast(@CardNo as char(18)), 15, 4) as int)
	
		select @C1 = '0000'+substring((cast(@CardNo as varchar(19))), 5, 12)
	
		select @rn = substring(cast(cast(rand(@seed)*10000000000 as bigint) as char(10)), 6, 4)
	
		select @C2 = '04'+replicate('0', 4-len(@rn))+cast(@rn as varchar(4))+'FFFFFFFFFF'
	
		exec XOR @C1, @C2, @V output
	
		exec master..xp_Encrypt @V, '2', @PINBlock output

		exec TranslatePIN @CardNo, @PINBlock, @HostPIN output

		if isnumeric(@HostPIN) > 0 break		
	end
end
GO
