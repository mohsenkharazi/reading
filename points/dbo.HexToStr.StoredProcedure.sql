USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[HexToStr]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Acquiring Module
Objective	:Convert Hexadecimal to String
-------------------------------------------------------------------------------
When	   Who		CRN		Description
-------------------------------------------------------------------------------
2007/01/08 Darren			Initial Development
*******************************************************************************/

create procedure [dbo].[HexToStr]
	@StrIn varchar(max) output
as
begin	
	declare @sql nvarchar(max)
	declare @BinOut varbinary(max)
	
	set @StrIn = '0x' + @StrIn
	set @sql = N'set @b = ' + @StrIn
	exec sp_executesql @sql, N'@b varbinary(max) out', @binOut out
	
	select @StrIn = ltrim(rtrim(cast(@BinOut as varchar(max))))
	
end
GO
