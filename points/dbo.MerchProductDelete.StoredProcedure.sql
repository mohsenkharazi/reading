USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchProductDelete]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To delete merchant product.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2005/04/07 Esther			Initial Development
*******************************************************************************/
	
CREATE procedure [dbo].[MerchProductDelete]
	@AcqNo uAcqNo,
	@ProdCd uProdCd
  as
begin
	delete aac_Product
	where AcqNo = @AcqNo and ProdCd = @ProdCd
	if @@error <> 0
	begin
		return 70023
	end
	return 50018
end
GO
