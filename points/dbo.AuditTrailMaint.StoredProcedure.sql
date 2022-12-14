USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AuditTrailMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	: Audit Trail Maintenance Procedure

SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN		Description
-------------------------------------------------------------------------------
2004/05/25 Chew Pei			Initial development
							When Ind = 'Y' means it is adding of new record
							When Ind = null means it is for update and delete of record
2013/12/19 Humairah			Due to Limited Character string for UserId field can stored in the Table, 
							we truncate the system_user to 8 character 
*******************************************************************************/
	
CREATE procedure [dbo].[AuditTrailMaint]
	@TableName varchar(100),
	@SqlSelect varchar(255),
	@SqlJoin varchar(255),
	@Ind char(1) = null  
  
as
begin
-- ******** Use ColId in syscolumns
	declare @Col int, @Id int, @Sql varchar(4000), @SqlStr nvarchar(4000), @ColName varchar(50),  @Action char(1)
	
	-- Retrieve @Action value
	--select @SqlStr= N'if exists (select 1 from #inserted i, #deleted d where ' + @SqlJoin + ') select  @Action  = ''U'' else if exists (select 1 from #deleted d where not exists (select 1 from #inserted i where ' + @SqlJoin + ')) select  @Action = ''D'''
	select @SqlStr= N'if exists (select 1 from #inserted i where not exists (select 1 from #deleted d where ' + @SqlJoin + ')) select @Action = ''A'' else if exists (select 1 from #inserted i, #deleted d where ' + @SqlJoin + ') select  @Action  = ''U'' else if exists (select 1 from #deleted d where not exists (select 1 from #inserted i where ' + @SqlJoin + ')) select  @Action = ''D'''
	execute sp_ExecuteSql @SqlStr,N'@Action char(1) out', @Action out

	if @Ind = 'Y' and @Action = 'A'
	begin
		select @Sql = 'insert into iss_MaintAudit (TableName, Field, PriKey, SubKey1, SubKey2, SubKey3, SubKey4, SubKey5, Action, OldVal, NewVal, UserId, CreationDate) select ''' + @TableName + ''',  ''NEW'', ' + @SqlSelect + ',''' + @Action + ''', null,null, substring(system_user,1,8), getdate() from #inserted d'
		exec (@Sql)
	end

	-- Retrive Table Id 
	select @Id = Id from sysobjects where Name = @TableName

	-- Get MIN ColId
	select @Col = min(ColId) from syscolumns where Id = @Id
	while @Col is not null
	begin
		select @ColName = cast(col_name(@Id, @Col) as varchar)
		if @ColName <> 'LastUpdDate'
		begin
			if @Action = 'U'
				select @Sql = 'insert iss_MaintAudit(TableName, Field, PriKey, SubKey1, SubKey2, SubKey3, SubKey4, SubKey5, Action, OldVal, NewVal, UserId, CreationDate) select ''' + @TableName + ''' , ''' + @colname + ''', ' + @SqlSelect + ', ''' + @Action + ''' , cast(d.' + @colname + ' as varchar),  cast(i.' + @colname + ' as varchar),  substring(system_user,1,8), getdate() from #Inserted i, #Deleted d where ' + @SqlJoin + ' and d.' + @ColName + ' <> i.' +@ColName
			else -- @Action = 'D'
				select @Sql = 'insert iss_MaintAudit(TableName, Field, PriKey, SubKey1, SubKey2, SubKey3, SubKey4, SubKey5, Action, OldVal, NewVal, UserId, CreationDate) select ''' + @TableName + ''' , ''' + @colname + ''', ' + @SqlSelect + ', ''' + @Action + ''' , cast(d.' + @colname + ' as varchar), '' '' ,  substring(system_user,1,8), getdate() from #Deleted d'
			exec (@Sql)
		end
		select @Col = min(ColId) from syscolumns where Id = @Id and ColId > @Col
	end

--********** Use of Total Column Count to retrieve ColName
/*	declare @TotalCol int, @CurrCol int, @Id int, @Sql varchar(4000), @SqlStr nvarchar(4000), @ColName varchar(50),  @Action char(1)


	-- Retrieve @Action value
	--select @SqlStr= N'if exists (select 1 from #inserted i, #deleted d where ' + @SqlJoin + ') select  @Action  = ''U'' else if exists (select 1 from #deleted d where not exists (select 1 from #inserted i where ' + @SqlJoin + ')) select  @Action = ''D'''
	select @SqlStr= N'if exists (select 1 from #inserted i where not exists (select 1 from #deleted d where ' + @SqlJoin + ')) select @Action = ''A'' else if exists (select 1 from #inserted i, #deleted d where ' + @SqlJoin + ') select  @Action  = ''U'' else if exists (select 1 from #deleted d where not exists (select 1 from #inserted i where ' + @SqlJoin + ')) select  @Action = ''D'''
	execute sp_ExecuteSql @SqlStr,N'@Action char(1) out', @Action out

	if @Ind = 'Y' and @Action = 'A'
	begin
		select @Sql = 'insert into iss_MaintAudit (TableName, Field, PriKey, SubKey1, SubKey2, SubKey3, SubKey4, SubKey5, Action, OldVal, NewVal, UserId, CreationDate) select ''' + @TableName + ''',  ''NEW'', ' + @SqlSelect + ',''' + @Action + ''', null,null, system_user, getdate() from #inserted d'
		exec (@Sql)
	end

	-- Retrive Table Id 
	select @Id = Id from sysobjects where Name = @TableName

	-- Get total number of column in the table
	select @TotalCol = count(*) from syscolumns where Id = @Id

	select @CurrCol = 1
	while @CurrCol <= @TotalCol
	begin
		select @ColName = cast(col_name(@Id, @CurrCol) as varchar)
		if @ColName <> 'LastUpdDate'
			begin
			if @Action = 'U'
				select @Sql = 'insert iss_MaintAudit(TableName, Field, PriKey, SubKey1, SubKey2, SubKey3, SubKey4, SubKey5, Action, OldVal, NewVal, UserId, CreationDate) select ''' + @TableName + ''' , ''' + @colname + ''', ' + @SqlSelect + ', ''' + @Action + ''' , cast(d.' + @colname + ' as varchar),  cast(i.' + @colname + ' as varchar),  system_user, getdate() from #Inserted i, #Deleted d where ' + @SqlJoin + ' and d.' + @ColName + ' <> i.' +@ColName
			else -- @Action = 'D'
				select @Sql = 'insert iss_MaintAudit(TableName, Field, PriKey, SubKey1, SubKey2, SubKey3, SubKey4, SubKey5, Action, OldVal, NewVal, UserId, CreationDate) select ''' + @TableName + ''' , ''' + @colname + ''', ' + @SqlSelect + ', ''' + @Action + ''' , cast(d.' + @colname + ' as varchar), '' '' ,  system_user, getdate() from #Deleted d'
			exec (@Sql)
		end
 		select @CurrCol = @CurrCol + 1
	end
*/
end
GO
