USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GetHostErrorCd]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Get host error code and map the response code according to CardPro
			 ISO Response Code.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2009/04/06 Darren			Initial development
*******************************************************************************/

CREATE procedure [dbo].[GetHostErrorCd]	
	@Mti smallint = 0,
	@PrcsCd int = 0,
	@RespCd char(2) output,
	@HostErrCd char(2) output

  as
begin

	declare @SysRespCd char(2)

	-- Only get for host error code if respcd is invalid	
	if @RespCd <> '00'
	begin

		select @HostErrCd = @RespCd

		-- Check if msg type and prcs cd has specified respcd
		-- Due to Provenco expect us to always return 00 on reversal msg
		select @SysRespCd = RespCd
		from acq_HostErrorCdMapping (nolock)
		where MsgType = @Mti and PrcsCd = @PrcsCd and HostErrCd = @HostErrCd

		-- Check if msg type and prcs cd has specified global respcd
		-- Due to Provenco expect us to always return 00 on reversal msg
		if isnull(@SysRespCd,'') = ''
		begin			
			select @SysRespCd = RespCd
			from acq_HostErrorCdMapping (nolock)
			where MsgType = @Mti and PrcsCd = @PrcsCd and HostErrCd = '00'
		end

		-- Check if has global respcd
		if isnull(@SysRespCd,'') = ''
		begin			
			select @SysRespCd = RespCd
			from acq_HostErrorCdMapping (nolock)
			where MsgType = 0 and PrcsCd = 0 and HostErrCd = @HostErrCd
		end

		select @RespCd = isnull(@SysRespCd, @RespCd)

	end

end
GO
