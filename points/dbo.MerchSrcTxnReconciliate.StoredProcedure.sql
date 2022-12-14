USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchSrcTxnReconciliate]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
--exec MerchSrcTxnReconciliate 1
CREATE	procedure [dbo].[MerchSrcTxnReconciliate] 
	@AcqNo uAcqNo,
	@PrcsId uPrcsId = null

as
begin
	set nocount on

	declare @xPrcsId int
	select @PrcsId = ctrlno from iss_control (nolock) where ctrlid = 'prcsid'
	select @xPrcsId = (select top 1 PrcsId from cmnv_processlog (nolock) order by PrcsId desc)
	select @PrcsId, @xPrcsId

	insert tmp_atx_sourcesettlement
	select * from atx_sourcesettlement (nolock) where prcsid = @xPrcsId

	insert tmp_atx_sourcetxn
	select * from atx_sourcetxn (nolock) where prcsid = @xPrcsId

	insert tmp_atx_sourcetxndetail
	select a.* from atx_sourcetxndetail a
	join atx_sourcetxn b on a.srcids = b.ids and b.prcsid = @xprcsid

	delete a
	from atx_sourcetxndetail a
	join atx_sourcetxn b (nolock) on a.SrcIds = b.Ids and b.Sts = 'P' and b.PrcsId = @xPrcsId 

	delete a
	from atx_sourcetxn a
	where a.Sts = 'P' and a.PrcsId = @xPrcsId 

	update a
	set arraycnt = b.cnt,
		amt = b.amt,
		pts = b.billingpts,
		billingpts = b.billingpts,
		issbillingpts = b.billingpts,
		prcsid = @PrcsId
	from atx_sourcetxn a
	join (select batchid, srcids, count(*) 'cnt', sum(amtpts) 'amt', sum(billingpts) 'billingpts'
			from atx_sourcetxndetail (nolock)
			group by batchid, srcids) b on a.ids = b.srcids and a.batchid = b.batchid
	where a.prcsid = @xPrcsId

	update a
	set cnt = b.cnt,
		amt = b.amt,
		pts = b.pts,
		billingpts = b.billingpts,
		prcsid = @PrcsId
	from atx_sourcesettlement a
	join (select BatchId, count(*) 'cnt', sum(amt) 'amt', sum(pts) 'pts', sum(billingpts) 'billingpts'
			from atx_sourcetxn (nolock)
			where prcsid = @PrcsId
			group by BatchId) b on a.BatchId = b.BatchId
	where a.prcsid = @xPrcsId

	----------------
	--check balance
	----------------
--	select * from atx_sourcesettlement (nolock) where prcsid = @prcsid
--	select prcsid, batchid, count(*) 'cnt', sum(amt) 'amt', sum(pts) 'pts' from atx_sourcetxn (nolock) where prcsid = @prcsid group by prcsid,batchid
--
--	select b.batchid,count(*),sum(a.amtpts),sum(a.billingpts)
--	from atx_sourcetxndetail a
--	join atx_sourcetxn b on a.srcids = b.ids and b.prcsid = @prcsid
--	group by b.batchid

	return 0
end
GO
