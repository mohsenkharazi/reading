USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AccountDataExtraction]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure will extract account data (for PDB data mining)

------------------------------------------------------------------------------------------------------------------
When	   Who		CRN		Desc
------------------------------------------------------------------------------------------------------------------
2009/07/27 Chew Pei			Initial Development
2009/11/03 Chew Pei			Amended script for extraction of transaction 
2014/07/12 Humairah			Segregate insert statement
******************************************************************************************************************/
/*
declare @rc int
exec @rc = AccountDataExtraction 1, 304
select @rc
*/

CREATE	procedure [dbo].[AccountDataExtraction] 
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

		if @@rowcount = 0 or @@error <> 0 return 9
	end
	else
	begin
		select @PrcsDate = PrcsDate
		from cmnv_ProcessLog
		where IssNo = @IssNo and PrcsId = @PrcsId		
	end


--	if exists (select 1 from udi_Batch where PrcsId = @PrcsId and SrcName ='HOST' and [FileName] ='ACCTDATA')
--	begin
--		return 10
--	end

	if (select count(*) from udiE_Account) > 0
	begin
		truncate table udiE_Account
		if @@error <> 0 return 11
	end

	select @FileSeq = isnull(max(FileSeq), 0)	-- Get the last file sequence
	from udi_Batch
	where IssNo = @IssNo and SrcName = 'HOST' and FileName = 'ACCTDATA'
	
		if @@error <> 0 return 12

	exec @BatchId = NextRunNo @IssNo, 'INSBatchId'

	-- Normal Transaction (Pts Issuance, Adjustment)


	-----------------
	BEGIN TRANSACTION
	-----------------
	/*
	insert udiE_Account 
			(IssNo, BatchId, AcctNo, AccumAgeingPts, PtsIssued, PtsRedeemed, PtsAdjusted, PtsCancelled, PtsExpired, FeePts, 
			Street1, Street2, Street3, City, State, ZipCd, MobileNo, HomeNo, OfficeNo, Email, Sts)
	select distinct @IssNo, @BatchId, a.AcctNo, b.AccumAgeingPts, z.PtsIssued, z.PtsRedeemed, z.PtsAdjusted, z.PtsCancelled, z.PtsExpired, 
	z.FeePts, c.Street1, c.Street2, c.Street3, c.City, c.State, c.ZipCd, m.MobileNo, k.HomeNo, n.OfficeNo, p.Email, a.Sts
	from iac_Account a (nolock)
	join iac_AccountFinInfo b (nolock) on b.AcctNo = a.AcctNo	
	left outer join (select  c1.RefKey 'EntityId', c1.Street1, c1.Street2, c1.Street3, c1.City, c1.State, c1.ZipCd
						from iss_Address c1 (nolock)
						join iss_State c2 (nolock) on c2.StateCd = c1.State and c2.CtryCd = c1.Ctry and c2.IssNo = @IssNo
						where c1.RefTo = 'ENTT' and c1.RefType = 'ADDRESS' and c1.MailingInd = 'Y') 
					c on c.EntityId = a.EntityId
	left outer join (select k1.RefKey 'EntityId', k1.ContactNo 'HomeNo'
						from iss_Contact k1 (nolock)
						join iss_Reflib k2 (nolock) on k2.RefType = 'CONTACT' and k2.RefCd = k1.RefCd and (k2.RefNo & 2) > 0 and (k2.RefInd & 1) > 0 and k2.IssNo = @IssNo
						where k1.RefTo = 'ENTT' and k1.IssNo = @IssNo) -- HomeNo
					k on k.EntityId = a.EntityId
	left outer join (select m1.RefKey 'EntityId', isnull(m1.ContactNo, '') 'MobileNo'
						from iss_Contact m1 (nolock)
						join iss_Reflib m2 (nolock) on m2.RefType = 'CONTACT' and m2.RefCd = m1.RefCd and (m2.RefNo & 2) > 0 and (m2.MapInd & 1) > 0 and m2.IssNo = @IssNo
						where m1.RefTo = 'ENTT' and m1.IssNo = @IssNo) -- MobileNo
					m on m.EntityId = a.EntityId
	left outer join (select n1.RefKey 'EntityId', n1.ContactNo 'OfficeNo'
						from iss_Contact n1 (nolock)
						join iss_Reflib n2 (nolock) on n2.RefType = 'CONTACT' and n2.RefCd = n1.RefCd and (n2.RefNo & 2) > 0 and (n2.RefInd & 2) > 0 and n2.IssNo = @IssNo
						where n1.RefTo = 'ENTT' and n1.IssNo = @IssNo) -- OfficeNo
					n on n.EntityId = a.EntityId
	left outer join (select p1.RefKey 'EntityId', p1.EmailAddr 'Email'
						from iss_Contact p1
						join iss_Reflib p2 on p2.RefType = 'CONTACT' and p2.RefCd = p1.RefCd and (p2.RefNo & 2) > 0 and (p2.MapInd & 2) > 0 and p2.IssNo = @IssNo
						where p1.RefTo = 'ENTT' and p1.IssNo = @IssNo) -- Email
					p on p.EntityId = a.EntityId
	left outer join (select z1.AcctNo, 
							sum(case when z3.Category = 1 then z1.Pts end) 'PtsIssued',
							sum(case when z3.Category = 20 then z1.Pts end) 'PtsRedeemed',
							sum(case when z3.Category = 4 then z1.Pts end) 'FeePts',
							sum(case when z1.TxnCd = 902 then z1.Pts end) 'PtsCancelled',
							sum(case when z1.TxnCd = 900 then z1.Pts end) 'PtsExpired',
							--sum(case when z1.TxnCd in (401, 403, 405, 400, 402, 404, 406, 407) then z1.Pts end) 'PtsAdjusted' -- both debit and credit adj
							sum(case when z3.Category = 2 and z1.TxnCd not in (900, 902, 903) then z1.Pts end) 'PtsAdjusted'	
						from itx_Txn z1 (nolock)
						join itx_TxnCode z2 (nolock) on z2.TxnCd = z1.TxnCd and z2.IssNo = @IssNo
						join itx_TxnCategory z3 (nolock) on z3.Category = z2.Category and z3.IssNo = @IssNo
						where z1.PrcsId = @PrcsId
						group by z1.AcctNo) 
					z on z.AcctNo = a.AcctNo

	if @@error <> 0
	begin
		rollback transaction
		return 4
	end
	*/
	
	insert udiE_Account (IssNo,  AcctNo, AccumAgeingPts, Sts,EntityId)
	select @IssNo,  a.AcctNo, b.AccumAgeingPts, a.Sts,a.EntityId
	from iac_Account a (nolock)
	join iac_AccountFinInfo b (nolock) on b.AcctNo = a.AcctNo
	
		if @@error <> 0
		begin
			rollback transaction
			return 1
		end
	
	update x 
		set x.Street1 = c.Street1, 
			x.Street2 = c.Street2, 
			x.Street3 = c.Street3,
			x.City = c.City, 
			x.State = c.State, 
			x.ZipCd = c.ZipCd
	from udiE_Account x (nolock) 
	left outer join (select  c1.RefKey 'EntityId', c1.Street1, c1.Street2, c1.Street3, c1.City, c1.State, c1.ZipCd
						from iss_Address c1 (nolock)
						join iss_State c2 (nolock) on c2.StateCd = c1.State and c2.CtryCd = c1.Ctry and c2.IssNo = @IssNo
						where c1.RefTo = 'ENTT' and c1.RefType = 'ADDRESS' and c1.MailingInd = 'Y') 
					c on c.EntityId = x.EntityId 
	
		if @@error <> 0
		begin
			rollback transaction
			return 2
		end
	
	update x 
		set x.HomeNo = k.HomeNo
	from udiE_Account x (nolock)
	left outer join (select k1.RefKey 'EntityId', k1.ContactNo 'HomeNo'
						from iss_Contact k1 (nolock)
						join iss_Reflib k2 (nolock) on k2.RefType = 'CONTACT' and k2.RefCd = k1.RefCd and (k2.RefNo & 2) > 0 and (k2.RefInd & 1) > 0 and k2.IssNo = @IssNo
						where k1.RefTo = 'ENTT' and k1.IssNo = @IssNo) -- HomeNo
					k on k.EntityId = x.EntityId
					
		if @@error <>0
		begin
			rollback transaction
			return 3
		end
				
	update x
		set x.MobileNo = m.MobileNo	
	from udiE_Account x(nolock)
	left outer join (select m1.RefKey 'EntityId', isnull(m1.ContactNo, '') 'MobileNo'
						from iss_Contact m1 (nolock)
						join iss_Reflib m2 (nolock) on m2.RefType = 'CONTACT' and m2.RefCd = m1.RefCd and (m2.RefNo & 2) > 0 and (m2.MapInd & 1) > 0 and m2.IssNo = @IssNo
						where m1.RefTo = 'ENTT' and m1.IssNo = @IssNo) -- MobileNo
					m on m.EntityId = x.EntityId
					
		if @@error <> 0
		begin
			rollback transaction
			return 4
		end

	update x 
		set x.OfficeNo = n.OfficeNo
	from udiE_Account x(nolock)		
	left outer join (select n1.RefKey 'EntityId', n1.ContactNo 'OfficeNo'
						from iss_Contact n1 (nolock)
						join iss_Reflib n2 (nolock) on n2.RefType = 'CONTACT' and n2.RefCd = n1.RefCd and (n2.RefNo & 2) > 0 and (n2.RefInd & 2) > 0 and n2.IssNo = @IssNo
						where n1.RefTo = 'ENTT' and n1.IssNo = @IssNo) -- OfficeNo
					n on n.EntityId = x.EntityId
					
		if @@error <> 0
		begin
			rollback transaction
			return 5
		end

	update x
		set x.Email = p.Email
	from udiE_Account x(nolock)		
	left outer join (select p1.RefKey 'EntityId', p1.EmailAddr 'Email'
						from iss_Contact p1
						join iss_Reflib p2 on p2.RefType = 'CONTACT' and p2.RefCd = p1.RefCd and (p2.RefNo & 2) > 0 and (p2.MapInd & 2) > 0 and p2.IssNo = @IssNo
						where p1.RefTo = 'ENTT' and p1.IssNo = @IssNo) -- Email
					p on p.EntityId = x.EntityId
								
		if @@error <> 0
		begin
			rollback transaction
			return 6
		end

	update x
		set x.PtsIssued =z.PtsIssued, 
			x.PtsRedeemed = z.PtsRedeemed, 
			x.PtsAdjusted = z.PtsAdjusted, 
			x.PtsCancelled = z.PtsCancelled, 
			x.PtsExpired = z.PtsExpired, 
			x.FeePts = z.FeePts
	from udiE_Account x(nolock)		
	left outer join (select z1.AcctNo, 
							sum(case when z3.Category = 1 then z1.Pts end) 'PtsIssued',
							sum(case when z3.Category = 20 then z1.Pts end) 'PtsRedeemed',
							sum(case when z3.Category = 4 then z1.Pts end) 'FeePts',
							sum(case when z1.TxnCd = 902 then z1.Pts end) 'PtsCancelled',
							sum(case when z1.TxnCd = 900 then z1.Pts end) 'PtsExpired',
							sum(case when z3.Category = 2 and z1.TxnCd not in (900, 902, 903) then z1.Pts end) 'PtsAdjusted'	
						from itx_Txn z1 (nolock)
						join itx_TxnCode z2 (nolock) on z2.TxnCd = z1.TxnCd and z2.IssNo = @IssNo
						join itx_TxnCategory z3 (nolock) on z3.Category = z2.Category and z3.IssNo = @IssNo
						where z1.PrcsId = @PrcsId
						group by z1.AcctNo) 
					z on z.AcctNo = x.AcctNo
				
		if @@error <> 0
		begin
			rollback transaction
			return 7
		end
	
	update udiE_Account set BatchId = @BatchId	

		if @@error <> 0
		begin
			rollback transaction
			return 8
		end

	select @Rc = count(*) from udiE_Account
--	select @Rc = @@rowcount

	insert udi_Batch (IssNo, BatchId, SrcName, FileName, FileSeq, DestName, FileDate,
			RecCnt, Direction, Sts, PrcsId, PrcsDate)
	select @IssNo, @BatchId, 'HOST', 'ACCTDATA', isnull(@FileSeq,0)+1, @IssNo, getdate(),
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
