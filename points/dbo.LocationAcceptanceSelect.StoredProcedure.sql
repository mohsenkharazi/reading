USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[LocationAcceptanceSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:Cardtrend Systems Sdn. Bhd.
Modular		:Cardtrend Card Management System (CCMS)- Acquiring Module

Objective	:Business Location select.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/01/21 Wendy		   Initial development

*******************************************************************************/

CREATE procedure [dbo].[LocationAcceptanceSelect]
	@AcqNo uAcqNo,
	@CardNo uCardNo
  as
begin
	declare @CardCategory uRefCd

	set nocount on

	select @CardCategory = CardCategory
	from iac_Card a
	join iss_CardType b on a.CardLogo = b.CardLogo and a.CardType = b.CardType
	where CardNo = @CardNo

	if @CardCategory = 'B'
	begin
		select isnull(b.BusnLocation, a.BusnLocation) 'MerchantNo', a.BusnName 'MerchantName'
		from aac_BusnLocation a
		left outer join iac_CardAcceptance b on a.BusnLocation = b.BusnLocation and b.CardNo = @CardNo
		join iss_Default c on a.Sts = c.VarcharVal and a.AcqNo = c.IssNo and c.Deft = 'ActiveSts'
		where a.AcqNo = @AcqNo and b.BusnLocation is null
	end
	else
	begin
		select isnull(b.BusnLocation, a.BusnLocation) 'MerchantNo', a.BusnName 'MerchantName'
		from aac_BusnLocation a
		left outer join iac_CardAcceptance b on a.BusnLocation = b.BusnLocation and b.CardNo = @CardNo
		join iss_Default c on a.Sts = c.VarcharVal and a.AcqNo = c.IssNo and c.Deft = 'ActiveSts'
		where a.AcqNo = @AcqNo and a.Sic = @CardCategory and b.BusnLocation is null
	end
	return 0
end
GO
