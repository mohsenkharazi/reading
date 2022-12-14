USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GetObject]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Search Object and return to the front-end program.

-------------------------------------------------------------------------------
When	   Who		CRN	   Desc
-------------------------------------------------------------------------------
2001/11/12 Jacky		   Initial development
2009/04/03 Barnett		   Add Rowcoutn return to determinde the record count
******************************************************************************************************************/

CREATE procedure [dbo].[GetObject]
	@IssNo uIssNo,
	@Val nvarchar(40),
	@Obj varchar(20)
  as
begin
	declare @WildCard int
	
	select @WildCard = isnull(charindex(N'%', @Val), 0)

	if (@Obj is null)
	begin
		if (@WildCard > 0)
		begin
--			select a.Val+' ('+a.Obj+')', 'Source- '+a.Src+' ('+a.LinkNo+')', b.Obj+' - '+b.Val
			select a.Val+' ('+c.Descp+')', d.VarcharVal+'- '+f.Descp+' ('+a.LinkNo+')', e.Descp+' - '+b.Val
			from iss_Object a (nolock), iss_Object b (nolock), iss_RefLib c (nolock), iss_Default d (nolock), iss_RefLib e (nolock), iss_RefLib f (nolock)
			where a.IssNo in (@IssNo) and a.Val like @Val
			and b.IssNo = a.IssNo and b.Src = a.Src and b.LinkNo = a.LinkNo-- and b.obj <> a.obj
			and c.IssNo = @IssNo and c.RefType = 'Object' and c.RefCd = a.Obj
			and d.IssNo = @IssNo and d.Deft = 'ObjSrcName'
			and e.IssNo = @IssNo and e.RefType = 'Object' and e.RefCd = b.Obj
			and f.IssNo = @IssNo and f.RefType = 'ObjectSrc' and f.RefCd = a.Src
			order by a.Val, a.Obj, a.Src, a.LinkNo, b.Obj
		end
		else
		begin
			select a.Val+' ('+c.Descp+')', d.VarcharVal+'- '+f.Descp+' ('+a.LinkNo+')', e.Descp+' - '+b.Val
			from iss_Object a (nolock), iss_Object b (nolock), iss_RefLib c (nolock), iss_Default d (nolock), iss_RefLib e (nolock), iss_RefLib f (nolock)
			where a.IssNo in (@IssNo) and a.Val = @Val
			and b.IssNo = a.IssNo and b.Src = a.Src and b.LinkNo = a.LinkNo-- and b.obj <> a.obj
			and c.IssNo = @IssNo and c.RefType = 'Object' and c.RefCd = a.Obj
			and d.IssNo = @IssNo and d.Deft = 'ObjSrcName'
			and e.IssNo = @IssNo and e.RefType = 'Object' and e.RefCd = b.Obj
			and f.IssNo = @IssNo and f.RefType = 'ObjectSrc' and f.RefCd = a.Src
			order by a.Val, a.Obj, a.Src, a.LinkNo, b.Obj
		end
	end
	else
	begin
		if (@WildCard > 0)
		begin
			select a.Val+' ('+c.Descp+')', d.VarcharVal+'- '+f.Descp+' ('+a.LinkNo+')', e.Descp+' - '+b.Val
			from iss_Object a (nolock), iss_Object b (nolock), iss_RefLib c (nolock), iss_Default d (nolock), iss_RefLib e (nolock), iss_RefLib f (nolock)
			where a.IssNo in (@IssNo) and a.Val like @Val and a.Obj = @Obj
			and b.IssNo = a.IssNo and b.Src = a.Src and b.LinkNo = a.LinkNo-- and b.obj <> a.obj
			and c.IssNo = @IssNo and c.RefType = 'Object' and c.RefCd = a.Obj
			and d.IssNo = @IssNo and d.Deft = 'ObjSrcName'
			and e.IssNo = @IssNo and e.RefType = 'Object' and e.RefCd = b.Obj
			and f.IssNo = @IssNo and f.RefType = 'ObjectSrc' and f.RefCd = a.Src
			order by a.Val, a.Obj, a.Src, a.LinkNo, b.Obj
		end
		else
		begin
			select a.Val+' ('+c.Descp+')', d.VarcharVal+'- '+f.Descp+' ('+a.LinkNo+')', e.Descp+' - '+b.Val
			from iss_Object a (nolock), iss_Object b (nolock), iss_RefLib c (nolock), iss_Default d (nolock), iss_RefLib e (nolock), iss_RefLib f (nolock)
			where a.IssNo in (@IssNo) and a.Val = @Val and a.Obj = @Obj
			and b.IssNo = a.IssNo and b.Src = a.Src and b.LinkNo = a.LinkNo-- and b.obj <> a.obj
			and c.IssNo = @IssNo and c.RefType = 'Object' and c.RefCd = a.Obj
			and d.IssNo = @IssNo and d.Deft = 'ObjSrcName'
			and e.IssNo = @IssNo and e.RefType = 'Object' and e.RefCd = b.Obj
			and f.IssNo = @IssNo and f.RefType = 'ObjectSrc' and f.RefCd = a.Src
			order by a.Val, a.Obj, a.Src, a.LinkNo, b.Obj
		end
	end
	
	return @@rowcount
end
GO
