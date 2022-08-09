USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AsciiCode]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create proc [dbo].[AsciiCode] @StartNo tinyint, @EndNo tinyint as
begin
	while (@StartNo <= @EndNo)
	begin
		select @StartNo, char(@StartNo)
		select @StartNo = @StartNo + 1
	end
end
GO
