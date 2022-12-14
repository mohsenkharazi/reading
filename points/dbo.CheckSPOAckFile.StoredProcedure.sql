USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CheckSPOAckFile]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CCMS

Objective	:Select duplicate process
------------------------------------------------------------------------------------------
When		Who		CRN	Description
------------------------------------------------------------------------------------------
2009/04/12	Darren		   	Initial development
*****************************************************************************************/
-- exec CheckSPOAckFile 1, 'HOST', 'DRCD'

CREATE procedure [dbo].[CheckSPOAckFile]
	@IssNo smallint,	
	@CreationDate varchar(15),
	@RunNo varchar(3)

   as
begin	

	set nocount on
	
	if exists(select top 1 1 from udii_DirectCreditAck (nolock) where CreationDate = @CreationDate and RunNo = @RunNo)
	begin
		return 400031	-- Batch already loaded to the host
	end

	return 0

	set nocount off

end
SET QUOTED_IDENTIFIER OFF
GO
