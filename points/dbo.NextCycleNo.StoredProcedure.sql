USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[NextCycleNo]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This is the Cycle Card No allocation, allocation sequence number for valid applicant only


-------------------------------------------------------------------------------
When	   Who		CRN		Desc
-------------------------------------------------------------------------------
2001/06/06 Jacky		  	Initial development
					All remarks follow by ** is for further rework/recode.

******************************************************************************************************************/

CREATE procedure [dbo].[NextCycleNo]
	@IssNo uIssNo,
	@CardLogo uCardLogo,
	@PlasticType uPlasticType
  as
begin
	declare @CycNo tinyint

	select @CycNo = a.CycNo
	from iss_CycleControl a, iss_PlasticTypeCycle b
	where a.IssNo = @IssNo and b.IssNo = a.IssNo and b.CycNo = a.CycNo
	and b.CardLogo = @CardLogo and b.PlasticType = @PlasticType and b.LastUsed = 'Y'

	if @@rowcount > 0
	begin
		select @CycNo = min(a.CycNo)
		from iss_CycleControl a, iss_PlasticTypeCycle b
		where a.IssNo = @IssNo and a.CycNo > @CycNo and a.Sts = 'A'
		and b.IssNo = a.IssNo and b.CycNo = a.CycNo
		and b.CardLogo = @CardLogo and b.PlasticType = @PlasticType
	end

	if @CycNo is null
	begin
		select @CycNo = min(a.CycNo)
		from iss_CycleControl a, iss_PlasticTypeCycle b
		where a.IssNo = @IssNo and a.Sts = 'A' and b.IssNo = a.IssNo and b.CycNo = a.CycNo
		and b.CardLogo = @CardLogo and b.PlasticType = @PlasticType
	end

	update iss_PlasticTypeCycle set LastUsed = null
	where IssNo = @IssNo and CardLogo = @CardLogo and PlasticType = @PlasticType

	update iss_PlasticTypeCycle set LastUsed = 'Y'
	where IssNo = @IssNo and CardLogo = @CardLogo and PlasticType = @PlasticType
	and CycNo = @CycNo

	return isnull(@CycNo, 0)
end
GO
