USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AuditTrailUpdateMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	: Audit Trail Maintenance (For UPDATE) Procedure

SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN		Description
-------------------------------------------------------------------------------
2004/06/05 Chew Pei			Initial development

*******************************************************************************/
CREATE procedure [dbo].[AuditTrailUpdateMaint]
	@TableName varchar(100),
	@SqlSelect varchar(255),
	@SqlJoin varchar(255),
	@ColName varchar(50)
  
as
begin
	declare @Sql varchar(4000), @Action char(1)
	select @Action = 'U'
	select @Sql = 'insert iss_MaintAudit(TableName, Field, PriKey, SubKey1, SubKey2, SubKey3, SubKey4, SubKey5, Action, OldVal, NewVal, UserId, CreationDate) select ''' + @TableName + ''' , ''' + @colname + ''', ' + @SqlSelect + ', ''' + @Action + ''' , cast(d.' + @Colname + ' as varchar),  cast(i.' + @Colname + ' as varchar),  system_user, getdate() from #Inserted i, #Deleted d where ' + @SqlJoin + ' and d.' + @ColName + ' <> i.' +@ColName
	exec (@Sql)		
end
GO
