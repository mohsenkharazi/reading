USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchTypeDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module

Objective	:MCC and SIC deletion.
		
SP Level	:Primary

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/05/30 Sam			   Initial development
2005/04/11 Alex			   Change @CategoryCd to varchar data type
*******************************************************************************/

CREATE procedure [dbo].[MerchTypeDelete]
	@Type char(1),
	@CategoryCd varchar(5)
  as
begin
	if @Type = 'M'
	begin
		if (select count(*) from aac_BusnLocation where Mcc = @CategoryCd) > 0 return 95000
	end
	else
		if (select count(*) from aac_BusnLocation where Sic = @CategoryCd) > 0 return 95000

	delete cmn_MerchantType
	where Type = @Type and CategoryCd = @CategoryCd
	if @@rowcount = 0 or @@error <> 0 return 70029
	return 50195
end
GO
