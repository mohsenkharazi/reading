USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchDataExtraction]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure will extract merchant data (for PDB data mining)

------------------------------------------------------------------------------------------------------------------
When	   Who		CRN		Desc
------------------------------------------------------------------------------------------------------------------
2009/07/27 Chew Pei	  Initial Development
2019/03/04 Humairah   Set max character for Site Id limited to 16 as per file spec
******************************************************************************************************************/
/*
exec MerchDataExtraction 1,211
select * from cmnv_Processlog
*/
CREATE procedure [dbo].[MerchDataExtraction] 
	@IssNo uIssNo,
	@PrcsId uPrcsId = null
  as
begin
	declare @Rc int, @BatchId uBatchId
	declare @PrcsDate datetime, @FileSeq int

	set nocount on
	
	if @PrcsId is null 
	begin
		select @PrcsId = CtrlNo,
				@PrcsDate = CtrlDate
		from iss_Control
		where IssNo = @IssNo and CtrlId = 'PrcsId'

		if @@rowcount = 0 or @@error <> 0 return 1
	end
	else
	begin
		select @PrcsDate = PrcsDate
		from cmnv_ProcessLog
		where IssNo = @IssNo and PrcsId = @PrcsId		
	end


	if @@error <> 0 return 2

	if exists (select 1 from udi_Batch where PrcsId = @PrcsId and SrcName ='HOST' and [FileName] ='MERCH')
	begin
		return 2
	end

	if (select count(*) from udiE_Merch) > 0
	begin
		truncate table udiE_Merch
		if @@error <> 0 return 2
	end

	select @FileSeq = isnull(max(FileSeq), 0)	-- Get the last file sequence
	from udi_Batch
	where IssNo = @IssNo and SrcName = 'HOST' and FileName = 'MERCH'

	exec @BatchId = NextRunNo @IssNo, 'INSBatchId'

	-- Normal Transaction (Pts Issuance, Adjustment)

	-----------------
	BEGIN TRANSACTION
	-----------------

	insert udiE_Merch 
			(IssNo, BatchId, BusnLocation, BusnName, PartnerRefNo, Street1, Street2, Street3, State, ZipCd, Sts)
	select @IssNo, @BatchId, a.BusnLocation, a.BusnName, substring(a.PartnerRefNo,1,16), b.Street1, b.Street2, b.Street3, b.State, b.ZipCd, a.Sts
	from aac_BusnLocation a (nolock)
	join (	select b1.RefKey, b1.Street1, b1.Street2, b1.Street3, b1.ZipCd, b2.Descp 'State'
			from iss_Address b1 (nolock)
			left outer join iss_State b2 (nolock) on b2.CtryCd = b1.Ctry and b2.StateCd = b1.State and b2.IssNo = @IssNo
			where b1.RefTo = 'BUSN' and b1.MailingInd = 'Y' and b1.IssNo = @IssNo) b on b.RefKey = a.BusnLocation
--	where convert(varchar(8), a.CreationDate, 112) = convert(varchar(8), @PrcsDate, 112) and a.AcqNo = @IssNo

	if @@error <> 0
	begin
		rollback transaction
		return 3
	end

	select @Rc = @@rowcount

	insert udi_Batch (IssNo, BatchId, SrcName, FileName, FileSeq, DestName, FileDate,
			RecCnt, Direction, Sts, PrcsId, PrcsDate)
	select @IssNo, @BatchId, 'HOST', 'MERCH', isnull(@FileSeq,0)+1, @IssNo, getdate(),
		@Rc, 'E', 'L', @PrcsId, @PrcsDate

	if @@error <> 0
	begin
		rollback transaction
		return 70265 -- Failed to update Batch
	end

	------------------
	COMMIT TRANSACTION
	------------------

	return 0
end
GO
