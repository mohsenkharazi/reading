USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchProductMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To insert new or update existing product code.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2005/04/07 Esther		   Initial Development
*******************************************************************************/

CREATE procedure [dbo].[MerchProductMaint]
	@Func varchar(5),
	@AcqNo uAcqNo,
	@BusnLocation uMerchNo,
	@ProdCd uProdCd,
	@PricePerUnit money,	
	@PlanId uPlanId,	
	@DownloadInd char(1)
	
  as
begin
	if @ProdCd is null return 55023	
	if @PlanId is null return 55019		

	if @Func = 'Add'
	begin
		if exists (select 1 from aac_Product where BusnLocation=@BusnLocation and ProdCd=@ProdCd and AcqNo=@AcqNo)
		return 65007 	-- Product Code already exists

		insert aac_Product(AcqNo, BusnLocation, ProdCd, PricePerUnit, PlanId, DownloadInd, Seq, LastUpdDate)
		values (@AcqNo,@BusnLocation, @ProdCd, isnull(@PricePerUnit,0), @PlanId, @DownloadInd, null, getdate())		
		if @@error <> 0
		begin
			return 70021
		end
		return 50016
	end

	if @Func = 'Save'
	begin			
		
			update a
			set AcqNo=@AcqNo, 
				BusnLocation=@BusnLocation, 
				ProdCd=@ProdCd, 
				PricePerUnit=@PricePerUnit,
				PlanId=@PlanId,
				DownloadInd=@DownloadInd, 
				Seq=null,
				LastUpdDate=getdate()
			from aac_Product a
			where BusnLocation=@BusnLocation and ProdCd=@ProdCd and AcqNo=@AcqNo
			if @@error <> 0
			begin
				return 70022
			end
			return 50017
			
	end
	
end
GO
