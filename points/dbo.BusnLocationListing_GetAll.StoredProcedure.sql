USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BusnLocationListing_GetAll]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--exec [BusnLocationListing_GetAll]1
CREATE procedure [dbo].[BusnLocationListing_GetAll]

@AcqNo uAcqNo

AS BEGIN

IF exists (select 1 from aac_BusnLocation where AcqNo = @AcqNo)
	BEGIN
		SELECT BusnLocation,BusnName +' - '+ BusnLocation
		FROM dbo.[aac_BusnLocation]  (nolock)
		Where AcqNo = @AcqNo
		order by BusnLocation
	END
Return 55211 /*Acq Table Ref is a compulsory field*/
END
GO
