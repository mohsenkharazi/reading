USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GetRrn]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:Cardtrend Systems Sdn. Bhd.
Modular		:Cardtrend Card Management System (CCMS)- Acquiring Module

Objective	:Generate Retrieval Ref No.

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2009/03/02 Sam			   Initial development.
*******************************************************************************/
create	procedure [dbo].[GetRrn]
	@Rrn char(12) output

--with encryption 
as
begin
	set nocount on
	declare @SysDate datetime
	select @SysDate = getdate()
	select @Rrn = substring(convert(varchar(10),@SysDate,112),4,5) + left(replace(convert(varchar(20),@SysDate,114),':',''),7)
	return 0
end
GO
