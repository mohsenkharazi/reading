USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[FileValidation]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE proc [dbo].[FileValidation]
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
