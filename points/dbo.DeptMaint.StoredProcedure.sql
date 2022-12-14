USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[DeptMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Department maintenance.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2001/12/28 Sam			   Initial development
2005/03/29 Alex			   Add The return Code Descp & recorrect The error return code

*******************************************************************************/
	
CREATE procedure [dbo].[DeptMaint]
	@Func varchar(8),
	@IssNo uIssNo,
	@Dept uRefCd,
	@Descp uDescp50
  as
begin
	if @Descp is null return 55017 --Description is a compulsory field
	if @Dept is null return 55062 --Department is a compulsory field

	if @Func = 'Add'
	begin
		insert iss_RefLib (IssNo, RefType, RefCd, RefNo, RefInd, Descp)
		select @IssNo, 'Dept', @Dept, 0, 0, @Descp
		if @@rowcount = 0 or @@error <> 0 return 70408 --Failed to update Department
		return 50274 --Department Id has been inserted successfully
	end
	else
	if @Func = 'Save'
	begin
		update iss_RefLib
		set Descp = @Descp
		where IssNo = @IssNo and RefType = 'Dept' and RefCd = @Dept 
		if @@rowcount = 0 or @@error <> 0 return 70408 --Failed to delete Department
		return 50275 --Department Id has been updated successfully
	end

	delete iss_RefLib
	where IssNo = @IssNo and RefType = 'Dept' and RefCd = @Dept
	if @@rowcount = 0 or @@error <> 0 return 70410 --Failed to update Resources
	return 50276 --Department Id has been deleted successfully

end
GO
