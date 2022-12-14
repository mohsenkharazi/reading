USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[Logon]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: User Logon

Required files  : 

------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2001/12/27 Jacky		   Initial development
2003/09/10 Kenny		   Check if user has already been logging in and tag the CheckIn status
2015/09/29 Sam			   Security module enhancement.
2018/11/01 Fahmi		   Functionality to force CCMS client update
******************************************************************************************************************/

CREATE	procedure [dbo].[Logon]
	@UserId uUserId,
	@Pw varchar(50),
	@IssNo uIssNo output,
	@Issuer nvarchar(50) output,
	@Program char(1) output,
	@Remark char(9) output

--with encryption 
as
begin
	declare @PrcsName varchar(50),
		@Msg nvarchar(80),
		@Sts char(1),
		@ExpiryDate datetime,
		@LastLoginDate datetime,
		@ValidForDays smallint,
		@SysDate datetime,
		@ChkSts char(1),
		@LatestCCMSVersion nvarchar(30),
		@UserCCMSVersion nvarchar(30),
		@ForceCCMSUpgrade int,

		@LatestCCMSVersionNo bigint,
		@UserCCMSVersionNo bigint,

		@DIG1 as varchar(1), @DIG2 as varchar(1), @DIG3 as varchar(1), @DIG4 as varchar(1),
		@TENPOW9 as bigint = 1000000000, @TENPOW6 as bigint = 1000000, @TENPOW3 as bigint = 1000

	set nocount on

	select @PrcsName = 'Logon',
		@SysDate = GETDATE()

--insert cmn_TraceLog (RefType, Val6, Val7) select 'spLogon', @UserId, @Pw

	exec TraceProcess 0, @PrcsName, @UserId

	if not exists (select 1 from iss_User (nolock) where UserId = @UserId) return 95007	-- Invalid User ID

	select @ForceCCMSUpgrade = IntVal, @LatestCCMSVersion = VarcharVal from iss_Default (nolock) where Deft = 'ForceCCMSUpgrade' and IssNo = 1

	if (@ForceCCMSUpgrade = '1')
	begin

		set @DIG1 = dbo.StringSpliter(@LatestCCMSVersion, '.', 0)

		set @DIG2 = dbo.StringSpliter(@LatestCCMSVersion, '.', 1)

		set @DIG3 = dbo.StringSpliter(@LatestCCMSVersion, '.', 2)

		set @DIG4 = dbo.StringSpliter(@LatestCCMSVersion, '.', 3)

		set @LatestCCMSVersionNo = (@DIG1 * @TENPOW9) + (@DIG2 * @TENPOW6) + (@DIG3 * @TENPOW3) + (@DIG4 * 1)

		select @UserCCMSVersion = VersionStr from iss_User (nolock)
		where IssNo = 1 and UserId = @UserId

		if (@UserCCMSVersion is not null)
		begin
			if (len(@UserCCMSVersion) > 6)
			begin
				
					set @DIG1 = dbo.StringSpliter(@UserCCMSVersion, '.', 0)

					set @DIG2 = dbo.StringSpliter(@UserCCMSVersion, '.', 1)

					set @DIG3 = dbo.StringSpliter(@UserCCMSVersion, '.', 2)

					set @DIG4 = dbo.StringSpliter(@UserCCMSVersion, '.', 3)

					set @UserCCMSVersionNo = (@DIG1 * @TENPOW9) + (@DIG2 * @TENPOW6) + (@DIG3 * @TENPOW3) + (@DIG4 * 1)


					if (@UserCCMSVersionNo < @LatestCCMSVersionNo)
					begin
						return 95999
					end
					else
					begin
						exec dbo.UpdateCCMSClientVersion 1, @UserId, ''
					end
			end
			else
			begin 
				return 95999
			end
		end
		else
		begin 
			return 95999
		end

	end

	select @IssNo = a.IssNo, 
		@ExpiryDate = a.ExpiryDate, 
		@Sts = a.Sts,
		@ChkSts = a.CheckIn,
		@Issuer = b.ShortName, 
		@Program = b.Program, 
		@Remark = b.Remark,
		@LastLoginDate = a.LastLogonDate,
		@ValidForDays = a.ValidForDays
	from iss_User a (nolock)
	join iss_Issuer b (nolock) on b.IssNo = a.IssNo
	where a.UserId = @UserId

	if @@rowcount = 0 return 95007	-- Invalid User ID

	if @ChkSts = 'Y' return 95279    -- User has already logged on currently

	if exists (select 1 
		from iss_User a (nolock) 
		join iss_RefLib b (nolock) on b.IssNo = @IssNo and b.RefType = 'UserSts' and b.RefCd = a.Sts and b.RefInd <> 0 
		where a.UserId = @UserId) return 95008	-- User Account disabled

	if @ExpiryDate is not null
	begin
		if convert(varchar(8),@ExpiryDate,112) < convert(varchar(8),@SysDate, 112)
		return 95009	-- User Account expired
	end

	IF @LastLoginDate is not null and @ValidForDays is not null
	BEGIN
		IF datediff(dd,@SysDate,@LastLoginDate) > @ValidForDays
		return 95514
	END

	return 0
end
GO
