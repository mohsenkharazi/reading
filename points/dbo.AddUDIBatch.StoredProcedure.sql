USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AddUDIBatch]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Add new batch

SP Level	: Primary
------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2001/11/21 Jacky		   Initial development

******************************************************************************************************************/

CREATE  procedure [dbo].[AddUDIBatch]
	@IssNo uIssNo,
	@BatchId uBatchId,
	@PhyFileName varchar(50),
	@SrcName varchar(8),
	@FileName varchar(15),
	@FileSeq int
  as
begin
	set nocount on

	insert udi_Batch (IssNo, BatchId, PhyFileName, SrcName, FileName, FileSeq, LoadedRec, Sts)
	values (@IssNo, @BatchId, @PhyFileName, @SrcName, @FileName, @FileSeq, 0, 'L')
end
GO
