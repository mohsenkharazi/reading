USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ObjectTypeListingSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE	procedure [dbo].[ObjectTypeListingSelect]

AS BEGIN

select obj , descp from [dbo].[ObjectType] order by obj
--Rina :20210329 below need to handle in fontend!
/*union
select NULL obj ,'Select All' as decp*/
END



GO
