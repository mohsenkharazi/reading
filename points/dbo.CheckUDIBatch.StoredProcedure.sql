USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CheckUDIBatch]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Check batch

------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2001/11/21 Jacky		   Initial development

******************************************************************************************************************/

CREATE procedure [dbo].[CheckUDIBatch]
	@IssNo uIssNo,
	@SrcName varchar(8),
	@FileName varchar(20),
	@FileSeq int
   as
begin

	--if @FileName = 'CTRSRVC' return 0
	if exists (	select 1
			from udi_Batch
			where IssNo = @IssNo and SrcName = @SrcName and FileName = @FileName
			and FileSeq = @FileSeq )
	begin
		return 1
	end

	return 0
end
GO
