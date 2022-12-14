USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[JobCBFFileValidation]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This stored procedure is call by DataImporter to validate the existence of the import file

------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2013/10/22 Jacky		   Initial development
******************************************************************************************************************/

CREATE PROCEDURE [dbo].[JobCBFFileValidation]
	@FileId varchar(50),
	@Filename varchar(200)
as
begin
	if exists (select 1 from cbf_Batch where FileId = @FileId and Filename = @Filename and Sts in ('L','P','T'))
		select 1 'Sts'
	else
		select 0 'Sts'
end
GO
