USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BankMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Insert or update Bank code.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/05/16 Jac			   Initial development
2004/07/08 Chew Pei			Change to Standard Coding
*******************************************************************************/
	
CREATE procedure [dbo].[BankMaint]
	@Func varchar(5),
	@IssNo smallint,
	@BankCd uRefCd,
	@Descp nvarchar(50)
   as
begin
	if @Descp is null return 55017
	if @BankCd is null return 55065

	if @Func = 'Add'
	begin
		insert iss_RefLib (IssNo, RefType, RefCd, RefNo, RefInd, Descp)
		select @IssNo, 'Bank', @BankCd, 0, 0, @Descp

		if @@rowcount = 0
		begin
			return 70186
		end

		return 50166
	end

	if @Func = 'Save'
	begin
		update iss_RefLib
		set Descp = @Descp
		where IssNo = @IssNo and RefType = 'Bank' and RefCd = @BankCd

		if @@rowcount = 0
		begin
			return 70185
		end

		return 50167
	end
end
GO
