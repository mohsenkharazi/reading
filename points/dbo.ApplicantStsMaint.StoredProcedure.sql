USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ApplicantStsMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This is the Application Online Processing stored procedure, for capturing and processing
		of Applicant via front-end for existing Application/Card/Account

SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN		Desc
-------------------------------------------------------------------------------
2002/11/02 Jac			  	Initial development
2003/03/12 Sam				None approval for secondary card if primary does not exists or approved.
2003/08/27 Kenny			To disallow applicant to be approved if application status is NOT EQUAL to 'A' or 'T'
2003/09/23 Sam				Enable user to capture some remarks.
2003/10/17 Chew Pei			If account status is not good, do not allow to approve new applicant
2003/12/15 Aeris			AppvDate = getdate() instead AppvDate = @CreationDate follow sp ApplicationOnlineInsertUpdate
2004/07/16 Chew Pei			Added LastUpdDate
2004/07/28 Chew Pei			Comment Off LastUpdDate
******************************************************************************************************************/
CREATE  procedure [dbo].[ApplicantStsMaint]
	@IssNo uIssNo,
	@Func varchar(10),
	@AppcId uAppcId,
	@AppcSts char(1),
	@ReasonCd uRefCd,
	@Remarks nvarchar(80)
--	@LastUpdDate varchar(30)
  as
begin
	declare @PrcsName varchar(50),
		@CreationDate datetime,
		@AppcInd tinyint,
		@OrigAppcSts char(1),
		@OrigAppcInd tinyint,
		@rc int,
		@Msg varchar(80),
		@PriSec char(1),
		@PriAppcId uAppcId,
		@Sts char(1),
		@AcctSts char(2),
		@PriCardNo uCardNo,
		@AcctNo uAcctNo,
		@RefInd int,
		@LatestUpdDate datetime

	set nocount on
	select @PrcsName = 'ApplicantStsMaint'

	exec TraceProcess @IssNo, @PrcsName, 'Start'
	----------------------------
	----- DATA VALIDATION ------
	----------------------------

	if isnull(@IssNo,0) = 0 return 55015		-- Mandatory field IssNo

	if isnull(@AppcSts,'') = '' return 55068

	select @AppcInd = RefInd
	from iss_RefLib
	where IssNo = @IssNo and RefType = 'AppcSts' and RefCd = @AppcSts

	if @AppcInd = 2
	begin
		if @ReasonCd is null return 55055
	end

	select @CreationDate = CtrlDate
	from iss_Control 
	where CtrlId = 'PrcsId' and @IssNo = IssNo 

	select @OrigAppcSts = AppcSts
	--2003/03/12B
	, @PriSec = PriSec, @PriAppcId = PriAppcId
	--2003/03/12E
	, @PriCardNo = PriCardNo
	from iap_Applicant
	where IssNo = @IssNo and AppcId = @AppcId

	if @@rowcount = 0
	begin
		return 60023	-- 'Applicant not found'
	end

	select @OrigAppcInd = RefInd
	from iss_RefLib
	where IssNo = @IssNo and RefType = 'AppcSts' and RefCd = @OrigAppcSts

	--2003/03/12B
	if @PriSec = 'S' and @AppcSts = 'A'
	begin
		if not exists (select 1 from iap_Applicant where AppcId = @PriAppcId and AppcSts in ('A', 'T'))
		begin
			if not exists (select 1 from iac_Card where CardNo = @PriCardNo and Sts = 'A' and PriSec = 'P')
				return 95229 --Primary Card Applicant not yet approved
		end
	end
	--2003/03/12E

	--2003/08/27B
	if @AppcSts = 'A'
	begin
		select @Sts = a.ApplSts
		from iap_Application a, iap_Applicant b 
		where a.ApplId = b.ApplId and b.AppcId = @AppcId

		if @Sts <> 'A' and @Sts <> 'T' return 95277	--Check application status
	end
	--2003/08/27E

	--2003/10/17B
	if @AppcSts = 'A'
	begin
		select @AcctNo = AcctNo from iap_Applicant where AppcId = @AppcId
		if @AcctNo is not null
		begin
			select @AcctSts = Sts from iac_Account where AcctNo = @AcctNo
			select @RefInd = RefInd from iss_Reflib where RefType = 'AcctSts' and RefCd = @AcctSts and IssNo = @IssNo 
			if @RefInd > 0 -- Acct Sts not good
			begin
				return 95267 -- Check Account Status	
			end
		end
	end
	--2003/10/17E

/*	if @LastUpdDate is null
		select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

	select @LatestUpdDate = LastUpdDate from iap_Applicant where IssNo = @IssNo and AppcId = @AppcId
	if @LatestUpdDate is null
		select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

	-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
	-- it means that record has been updated by someone else, and screen need to be refreshed
	-- before the next update.
	if @LatestUpdDate = convert(datetime, @LastUpdDate)
	begin
*/
		update iap_Applicant
	--	set	AppvDate = case when @OrigAppcInd <> 0 and @AppcInd = 0 then @CreationDate when @AppcInd <> 0 then null else AppvDate end,
		set	AppvDate = case when @OrigAppcInd <> 0 and @AppcInd = 0 then getdate() 
							when @AppcInd <> 0 then null else AppvDate end, --2003/12/15
			AppcSts = @AppcSts, 
			ReasonCd = @ReasonCd, 
			Remarks = @Remarks
			--LastUpdDate = getdate()
		where IssNo = @IssNo and AppcId = @AppcId

		if @@error <> 0
		begin
	--		rollback transaction
			return 70144	-- 'Failed to update Applicant'
		end
/*	end
	else
	begin
		return 95307 -- Session Expired
	end
*/
	if @PriSec = 'P' and @AppcSts <> 'A'
	begin
		update iap_Applicant
		set AppcSts = @AppcSts
		where IssNo = @IssNo and PriAppcId = @AppcId and PriSec = 'S'

		if @@error <> 0
		begin
--			rollback transaction
			return 70144	-- 'Failed to update Applicant'
		end
	end

	return 50171
end
GO
