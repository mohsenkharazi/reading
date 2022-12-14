USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CipherPIN]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Cipher cardholder NEW PIN
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2005/11/16 Darren		   Initial development
2007/03/02 Darren		   Add new parameter when calling xp_Encrypt
				   (Support new xp_Cryptor.dll)
*******************************************************************************/

CREATE procedure [dbo].[CipherPIN]
	@CardNo uCardNo,
	@NewPINBlock varchar(16),
	@PINBlock varchar(16) output
   as
begin
	declare	@C1 varchar(16),
		@C2 varchar(16),
		@V varchar(16),		
		@rn int	

	select @C1 = '0000'+substring((cast(@CardNo as varchar(19))), 5, 12)
	
	select @rn = @NewPINBlock

	select @C2 = '04'+replicate('0', 4-len(@rn))+cast(@rn as varchar(4))+'FFFFFFFFFF'
	

	exec XOR @C1, @C2, @V output
	
	exec master..xp_Encrypt @V, '2', @PINBlock output

end
GO
