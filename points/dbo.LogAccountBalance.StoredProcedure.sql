USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[LogAccountBalance]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:Cardtrend Systems Sdn. Bhd.
Modular		:Cardtrend Card Management System (CCMS)- OLTP Module

Objective	:To log the account balance in a temporary table after eod
-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2009/08/25	Darren				Initial development
*******************************************************************************/

CREATE procedure [dbo].[LogAccountBalance]
	@MileStone varchar(35),
	@PrcsId int = null

  as
begin

	declare @WithheldInd char(1)
/*	
	select @WithheldInd = 'N'
	select @MileStone = isnull(@MileStone, '-')

	if isnull(@PrcsId, 0) = 0
	begin
		select @PrcsId = CtrlNo 
		from iss_Control (nolock)
		where CtrlId = 'PrcsId'	
	end

	begin try

		if @WithheldInd = 'N'
		begin
			insert into log_AccountBalance(AcctNo, PrcsId, MileStone, AvailBal, OnlineWithheldPts, AccumAgeingPts, WithheldPts, CreationDate)
			select a.AcctNo, @PrcsId, @MileStone, 
				isnull(b.AccumAgeingPts,0) + isnull(b.WithheldPts,0) + isnull(c.WithheldPts,0),
				isnull(c.WithheldPts,0),
				isnull(b.AccumAgeingPts,0), isnull(b.WithheldPts,0),
				getdate()
			from (select b.AcctNo
					from atx_OnlineTxn a (nolock)
					join iac_Card b (nolock) on b.CardNo = a.CardNo
					where a.PrcsId = @PrcsId
					group by b.AcctNo ) a
			join iac_AccountFinInfo b (nolock) on b.AcctNo = a.AcctNo
			left outer join iac_OnlineFinInfo c (nolock) on c.AcctNo = a.AcctNo

			print 'Successfully log account balance (OnlineTxn) - ' + @Milestone + ' at ' + convert(varchar(25),getdate(), 120)
		end
		else
		begin
			insert into log_AccountBalance(AcctNo, PrcsId, MileStone, AvailBal, OnlineWithheldPts, AccumAgeingPts, WithheldPts, CreationDate)
			select a.AcctNo, @PrcsId, @MileStone, 
				isnull(b.AccumAgeingPts,0) + isnull(b.WithheldPts,0) + isnull(c.WithheldPts,0),
				isnull(c.WithheldPts,0),
				isnull(b.AccumAgeingPts,0), isnull(b.WithheldPts,0),
				getdate()
			from (select b.AcctNo
					from itx_WithheldUnsettleTxn a (nolock)
					join iac_Card b (nolock) on b.CardNo = a.CardNo					
					group by b.AcctNo ) a
			join iac_AccountFinInfo b (nolock) on b.AcctNo = a.AcctNo
			left outer join iac_OnlineFinInfo c (nolock) on c.AcctNo = a.AcctNo

			print 'Successfully log account balance (Withheld) - ' + @Milestone + ' at ' + convert(varchar(25),getdate(), 120)
		end
		
	end try
	begin catch
		print 'Fail to log account balance - ' + @Milestone + ' at ' + convert(varchar(25),getdate(), 120) + ' (' + ERROR_MESSAGE() + ')'		 
	end catch;
*/

end
GO
