USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[DecryptPIN]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Decrypt ISO Format-0 PIN Block and return the clear PIN
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/11/12 Jacky		   Initial development
2004/08/05 Aeris		   change the sequence of parameter in xp_Decrypt
2004/10/22 Aeris		   use the new xp_Cryptor
2004/11/18 Aeris		   add in checking isnumeric on @Len 
2005/11/16 Darren		   Add function to clear DLL cache	
*******************************************************************************/

CREATE procedure [dbo].[DecryptPIN]
	@PEK varchar(20),
	@CardNo varchar(19),
	@PINBlock varchar(16),
	@PIN varchar(16) output
  as
begin
	declare	@C1 varchar(16),
		@C2 varchar(16),
		@V varchar(16),
		@SLen char(2),
		@Len int,
		@Pos int,
		@rc int

	set nocount on

	select @rc = 0

	exec @rc = master..xp_Decrypt  @PINBlock, @PEK, @V output --20041022

	if @@error <> 0 return 70463	-- Failed to update Pin Block

	if @rc <> 0 return @rc	-- Error occurs during the PIN decryption

	select @Len = len(@CardNo)

	if @Len > 12
		select @Pos = @Len - 12
	else
		select @Pos = 1

	select @C1 = '0000'+replicate('0', 12-(@Len-@Pos))+substring((cast(@CardNo as varchar(19))), @Pos, @Len-@Pos)

	exec XOR @C1, @V, @C2 output

	--20041118B
	select @SLen = substring(@C2, 1, 2)

	if isnumeric(@SLen) = 0 return 1

	select @Len = cast(@SLen as int)
	--20041118E

	select @PIN = substring(@C2, 3, @Len)

	if isnumeric(@PIN) = 0 return 1 --20041118
	
	dbcc xp_Cryptor(free)

	return 0
end
GO
