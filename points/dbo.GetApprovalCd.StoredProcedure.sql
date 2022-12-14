USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GetApprovalCd]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:GetApprovalCd

		To generate an random approval code for an authorised transaction.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/10/15 Sam			   Initial development
2007/04/09 Chew Pei		Add @Seed
*******************************************************************************/

create	procedure [dbo].[GetApprovalCd]
	@AuthNo char(6) output
--with encryption 
as
begin
	declare @tAppv bigint, @TS varchar(15), @seed int

	select @TS = convert(varchar(12), getdate(), 114)
	select @seed = cast ((substring(@TS, 10, 3)+substring(@TS, 7, 2)+substring(@TS, 4, 2)+substring(@TS, 1, 2)) as bigint)

	select @tAppv = rand(@seed) * 10000000000
	select @AuthNo = substring(convert(varchar(10),@tAppv),1,6)
	return 0

end
GO
