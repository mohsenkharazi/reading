USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BusnCategoryMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To insert new or update existing business category
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2004/12/22 Alex			   Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[BusnCategoryMaint]
	@Func varchar(5),
	@IssNo uIssNo,
	@BusnCategory uRefCd,
	@Descp uDescp50	
   as
begin
	
	set nocount on


	if @Func = 'Add'
	begin
		if exists (select 1 from iss_RefLib where RefCd = @BusnCategory)
		return 65057 -- Business Category already exists.	

		insert iss_RefLib (IssNo, RefType, RefCd, RefNo, RefInd, MapInd, Descp)
		select @IssNo, 'BusnCategory', @BusnCategory, 0, 0, 0, @Descp
		if @@rowcount = 0
		begin
			return  70879 -- Failed to create Business Category
		end
		
		return 54070 -- Business Category has been created successfully
		
	end
	if @Func = 'Save'
	begin
		update iss_RefLib
		set Descp = @Descp
		where IssNo = @IssNo and RefCd = @BusnCategory and RefType = 'BusnCategory'
		if @@rowcount = 0
		begin
			return 70880 -- Failed to update Business Category
		end
		return 54071 -- Business Category has been updated successfully
	end
	
end
GO
