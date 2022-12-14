USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchTypeSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)-Acquiring Module

Objective	:Merchant category code (MCC) or standard industry code (SIC) search.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/05/29 Sam			   Initial development
2004/07/22 Alex				Add LastUpdDate
2005/09/28 Alex				Add Code
*******************************************************************************/

CREATE procedure [dbo].[MerchTypeSelect]
	@Type char(1),
	@CategoryCd varchar(5),
	@Descp uDescp50
  as
begin
--	declare @WildCard int

--	select @WildCard = isnull(charindex('%', @Descp), 0)

	if @CategoryCd is not null
	begin
		select CategoryCd, Descp 'Description', Code, Type, convert(varchar(30), LastUpdDate, 13) 'LastUpdDate'
		from cmn_MerchantType where CategoryCd >= @CategoryCd and Type = @Type
	end
	else
	begin
		select CategoryCd, Descp 'Description', Code, Type, convert(varchar(30), LastUpdDate, 13) 'LastUpdDate'
		from cmn_MerchantType where Type = @Type
	end
	return 0
end
GO
