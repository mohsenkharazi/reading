USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CheckSPORcpFile]    Script Date: 9/6/2021 10:33:55 AM ******/
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
-- exec CheckSPORcpFile 1, '001'

CREATE procedure [dbo].[CheckSPORcpFile]
	@IssNo smallint,		
	@RunNo varchar(3)

   as
begin	

	set nocount on
	declare @Sts uRefCd, @PrcsId uPrcsId, @BatchPrcsId uPrcsId

	select @PrcsId = CtrlNo
	from iss_Control (nolock) 
	where CtrlId = 'PrcsId'

	-- Get last loaded record with the same RunNo
	select top 1 @Sts = Sts, @BatchPrcsId = PrcsId
	from udi_Batch (nolock)
	where SrcName = 'BANK' and FileName = 'DRCD' and RefNo1 = @RunNo
	order by BatchId desc

	-- No duplicate record found
	if @@rowcount = 0
	begin
		return 0
	end
	
	----------------------------------------------------------------------------------------------
	-- Check if recently loaded ass the current logic the SeqNo will restarted if it hits 999
	----------------------------------------------------------------------------------------------

	-- Same run no detected for last 100 days, return duplicate error
	if @PrcsId - @BatchPrcsId < 100 and @Sts in ('L', 'P', 'E')
	begin
		return 400031	-- Batch already loaded to the host		
	end
	
	return 0
	
	set nocount off

end
SET QUOTED_IDENTIFIER OFF
GO
