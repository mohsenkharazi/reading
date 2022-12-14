USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ChangePassword]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Change User Password

Required files  : 

------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2001/12/26 Jacky		   Initial development
2003/09/09 Kenny		   OldPw cannot be the same as NewPw	   
2003/09/10 Kenny		   To enable everyone to change password: parameter @loginname = null
2003/09/23 Kenny		   Password cannot be empty
2003/09/23 Kenny		   Enable Administrator to change other user's password
2003/12/10 Kenny		   Check department. Diff department cannt change pwd
2009/05/04 Barnett		   Change Password will increase the expirydate 30 days (for PDB)
2009/05/04 Barnett		   bypass the password Policy Checking.
*****************************************************************************************************************/

CREATE	procedure [dbo].[ChangePassword]
 	@UserId uUserId,
	@OldPw varchar(18),
	@NewPw varchar(18)
  as
begin
	declare @PrcsName varchar(50),
		@Msg nvarchar(80),
		@RC int,
		@systemuser varchar(50),
		@PrivilegeCd char(1),
		@dept1 varchar(10),
		@dept2 varchar(10),
		@Length int,
		@Counter int,
		@exec_stmt Varchar(4000)
		

	set nocount on
	select @PrcsName = 'ChangePassword'

	if @OldPw = @NewPw return 70068	-- Failed to change password
	if @NewPw is null return 95280	-- Password cannot be empty

	/*
	---------------------------------------------------
	force the password must contain a Special Character
	---------------------------------------------------
	select @Length = len(@NewPw), @Counter = 1
					
	while @Counter <= @Length
	begin
			
			if not exists(select 1 where (select ascii (substring(@NewPw, @Counter, 1))) between 48 and 57 or
						   (select ascii (substring(@NewPw, @Counter, 1))) between 97 and 122 or
						   (select ascii (substring(@NewPw, @Counter, 1))) between 65 and 90)
			begin
					break
			end
			else if @Counter = @Length
			begin
					return 70069-- Must Contain at least one Special Character
			end
			
			select @Counter = @Counter +1
	end
	*/

--	exec @RC = sp_helpuser @name_in_db = @UserId
--	if @RC = 0
	--begin

	select @systemuser = system_user
--	exec traceprocess 1, @PrcsName, @Systemuser
--	exec traceprocess 1, @PrcsName, @userid

	select @PrivilegeCd = PrivilegeCd from iss_User where UserId = @systemuser

	if @PrivilegeCd <> '1' 
	begin
		if @systemuser <> @UserId return 95281	-- Only Administrator can change password for other user	
	end

	/*if @PrivilegeCd = '1'
	begin
		if @systemuser <> @UserId
		begin
			-- if supervisor, then check if they are in same department
			select @dept1 = DeptId from iss_User where UserId = @systemuser
			select @dept2 = DeptId from iss_User where UserId = @UserId
			if @dept1 <> @dept2 return 95297 -- User is not from same department. Not allowed to change password
		end
	end

	if @PrivilegeCd = '1'	
	begin
		if @UserId <> @systemuser
			exec @RC = sp_password @old = null, @new = @NewPw, @loginame = @UserId	
		else
			exec @RC = sp_password @old = @OldPw, @new = @NewPw, @loginame = @UserId	
	end
	else	
		--exec @RC = sp_password @old = @OldPw, @new = @NewPw, @loginame = null	
	*/
	if @UserId <> @systemuser
		set @exec_stmt = 'alter login ' + quotename(@UserId) +
			' with password = ' + quotename(@NewPw, '''') + ', CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF'
	else
		set @exec_stmt = 'alter login ' + quotename(@UserId) +
			' with password = ' + quotename(@NewPw, '''') + ' old_password = ' + quotename(@OldPw, '''') + ', CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF'

	exec  (@exec_stmt)	

	if @@error = 0 
	begin
			------------------
			begin transaction
			------------------
			update iss_user set ExpiryDate = getdate()+30 where UserId = @UserId

			if @@error <>0
			begin 
					rollback Transaction
					return 70068	-- Failed to change password
			end
	
			commit transaction
			return 50025	-- Successful changed
	end
	else
	begin
			return 70068	-- Failed to change password
	end
end
GO
