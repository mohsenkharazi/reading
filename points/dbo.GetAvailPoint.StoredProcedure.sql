USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GetAvailPoint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:

Objective	:allow SP call to Check Acct Avail Balance.

-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2009/04/03	Barnett				Initial Development
2018/11/14 Frank	Get the balance from iAuth via API first
*******************************************************************************/
	
CREATE procedure [dbo].[GetAvailPoint]
	@AcctNo uAcctNo,
	@AvailPts money output
  
as
begin
	set nocount on
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	declare @ApiUrl nvarchar(100) = ''
	declare @ApiTimeout int
	declare @LoyaltyAccountStatus nvarchar(100)
	declare @PointBalance decimal
	declare @PointRedeemBalance decimal 
	declare @ErrMsg nvarchar(1000) = ''

	select	@ApiUrl = isnull(VarcharVal, '')
	from	iss_Default
	where	IssNo = 1
	and		Deft = 'iAuthAPIUrl'

	if @ApiUrl = ''
	begin
		set @ErrMsg = 'API Url missing'
	end
	else
	begin
		set @ApiUrl = @ApiUrl + cast(@AcctNo as varchar(50)) +'/acctbalanceinquiry?sourceId=ZAP'
		set @ApiTimeout = 30

		begin try
			exec usp_ApiClrCallApiBalanceInquiryByAccount @ApiUrl, @ApiTimeout, @LoyaltyAccountStatus output, @PointBalance output, @PointRedeemBalance output, @ErrMsg output
		end try
		begin catch
			set @ErrMsg = 'Error'
		end catch

		set @AvailPts = @PointRedeemBalance
	end

	if @ErrMsg <> ''
	begin
		select @AvailPts = a.AccumAgeingPts + a.WithheldPts + b.WithheldPts  -- + isnull(c.UnsettlePts,0)
		from iac_AccountFinInfo a (nolock)
		join iac_OnlineFinInfo b (nolock) on a.AcctNo = b.AcctNo
		where a.AcctNo = @AcctNo
	end
end
GO
