USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchPlanMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:Business Location plan maintenance.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/07/01 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[MerchPlanMaint]
	@Func varchar(5),
	@AcqNo uAcqNo,
	@PlanId uPlanId,
	@Descp uDescp50
  as
begin
	if @PlanId is null return 55019
	if @Descp is null return 55017

	if @Func = 'Add'
	begin
		if exists (select 1 from atx_Plan where AcqNo = @AcqNo and PlanId = @PlanId) return 65014

		insert into atx_Plan
			(AcqNo,
			PlanId,
			Descp,
			LastUpdDate)
		values (@AcqNo,	@PlanId, @Descp, getdate())
		if @@rowcount = 0 or @@error <> 0 return 70009
		return 50065
	end

	if not exists (select 1 from atx_Plan where AcqNo = @AcqNo and PlanId = @PlanId) return 60012

	update atx_Plan
	set Descp = @Descp,
		LastUpdDate = getdate()
	where AcqNo = @AcqNo and PlanId = @PlanId
	if @@rowcount = 0 or @@error <> 0 return 70010
	return 50066
end
GO
