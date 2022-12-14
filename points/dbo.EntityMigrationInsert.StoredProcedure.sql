USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[EntityMigrationInsert]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)-Acquiring Module

Objective	:Generate Entity Identity.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/06/03 Sam			   Initial development

*******************************************************************************/

CREATE procedure [dbo].[EntityMigrationInsert]
	@AcqNo uAcqNo,
	@FamilyName nvarchar(100),
	@EntityId uEntityId output

  as
begin
	declare @SysDate datetime, @Error int

	select @SysDate = getdate()

		insert aac_Entity
		( AcqNo, FamilyName, GivenName, Gender, Marital, Dob, OldIc, NewIc, Passport,
		LicNo, Dept, Occupation, Income, BankName, BankAcctNo, CreationDate, Sts )
		values
		( @AcqNo, @FamilyName, null, null, null, null, null, null, null,
		null, null, null, null, null, null, @SysDate, 'A' )

		select @Error = @@error, @EntityId = @@identity
		if @Error <> 0 or @EntityId is null
		begin
			return 1
		end
	return 0
end
GO
