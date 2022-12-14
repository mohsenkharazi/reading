USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CreateWebAccount]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[CreateWebAccount] 
	@IssNo int 
AS
BEGIN 
	SET NOCOUNT ON 

	DECLARE 
		@Id int,
		@MaxId int,
		@IdentityNumber varchar(10),
		@EncryptedPw varchar(20),
		@ApplicationName nvarchar(10),
		@Rolename nvarchar(10),
		@RoleId uniqueidentifier

	select @ApplicationName = 'PDBWeb'
	select @Rolename = 'CARD'

	CREATE TABLE #CustInfo
	(
	Id int identity(1,1),
	AcctNo bigint,
	CardNo bigint, 
	Name varchar(50),
	IdentityType varchar(10),
	IdentityNumber varchar(100), 
	MobileNumber varchar(15),
	EmailAddress varchar(100),
	Password varchar(128)
	)

	CREATE INDEX IDX_ID ON #CustInfo(Id)
	CREATE INDEX IDX_CARDNO ON #CustInfo(CardNo)

	SELECT a.AcctNo,a.CardNo,b.FamilyName,b.NewIc,b.OldIc,b.PassportNo,c.ContactNo,d.EmailAddr
	INTO #Entity
	FROM iac_Card a (nolock) 
	JOIN iac_Entity b (nolock) on a.EntityId = b.EntityId 
	JOIN iss_Contact c (nolock) on c.Refkey = cast(b.EntityId as varchar) and c.RefTo = 'ENTT' and  c.RefType = 'CONTACT' and c.RefCd = 11
	LEFT JOIN iss_Contact d (nolock) on d.Refkey = cast(b.EntityId as varchar) and d.RefTo = 'ENTT' and d.RefType = 'CONTACT' and d.RefCd = 13
	LEFT JOIN [Demo_lms_web]..web_membership e (nolock) on e.Refkey = cast(a.CardNo as varchar(17)) 
	WHERE a.Sts = 'A' and isnull(e.Refkey,'') = ''

	DELETE FROM #Entity WHERE ISNULL(NewIc,'') = '' and ISNULL(OldIc,'') = '' and ISNULL(PassportNo,'') = '' 

	INSERT INTO #CustInfo (AcctNo,CardNo,Name,IdentityType,IdentityNumber,MobileNumber,EmailAddress)
	SELECT	AcctNo,
			CardNo, 
			FamilyName,
			CASE WHEN ISNULL(NewIc,'') <> '' THEN 1 WHEN ISNULL(OldIc,'')<>'' THEN 2 WHEN ISNULL(PassportNo,'')<> '' THEN 3 END,
			CASE WHEN ISNULL(NewIc,'') <> '' THEN NewIc WHEN ISNULL(OldIc,'')<>'' THEN OldIc WHEN ISNULL(PassportNo,'')<> '' THEN PassportNo END,
			ContactNo,
			EmailAddr
	FROM #Entity

	------------------
	BEGIN TRANSACTION 
	-------------------

	SELECT @Id = min(Id) FROM #CustInfo
	SELECT @MaxId = max(Id) from #CustInfo

	WHILE @Id <= @MaxId
	BEGIN 
		SELECT @IdentityNumber = IdentityNumber FROM #CustInfo where Id = @Id
		SELECT @IdentityNumber = RIGHT(@IdentityNumber,6)

		EXEC [EncryptPassword] @IdentityNumber,@EncryptedPw output

		if @@ERROR <> 0
		BEGIN 
			ROLLBACK TRANSACTION 
			RETURN 99990
		END

		UPDATE #CustInfo SET Password = @EncryptedPw WHERE Id = @Id

		if @@ERROR <> 0
		BEGIN 
			ROLLBACK TRANSACTION 
			RETURN 99991
		END
	
		SELECT @Id = @Id + 1
	END

	INSERT INTO [Demo_lms_web]..web_Membership(UserName, ApplicationName, Email, Password, IsApproved, CreationDate, AcctNo, RefKey, Name,IdentityNumber,IdentityType,SecureWord)
	SELECT '', @ApplicationName, isnull(EmailAddress,''), [Password], 0, getdate(), AcctNo, CardNo, Name, IdentityNumber,IdentityType,NULL from #CustInfo				

	if @@ERROR <> 0
	BEGIN 
		ROLLBACK TRANSACTION 
		RETURN 99992
	END

	SELECT @RoleId = RoleId
	FROM [Demo_lms_web]..web_Roles (NOLOCK)
	WHERE RoleName = @RoleName

	INSERT INTO [Demo_lms_web]..web_UsersInRoles(RoleId, Username, RefKey, Rolename, ApplicationName)
	SELECT @RoleId,'',CardNo, @RoleName, @ApplicationName from #CustInfo						

	if @@ERROR <> 0
	BEGIN 
		ROLLBACK TRANSACTION 
		RETURN 99993
	END

	------------------
	COMMIT TRANSACTION 
	-------------------

	DROP TABLE #Entity
	DROP TABLE #CustInfo

	RETURN 0
END
GO
