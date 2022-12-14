USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AccountMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	: Update Account detail.
 
SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/01/24 Jacky		   Initial development
2003/07/14 Chew Pei			Add WriteOffDate
2004/01/20 Chew Pei			Change @Remarks datatype from varchar to nvarchar
2004/07/01 Chew Pei			Added LastUpdDate.
							This is to ensure that user refresh one screen before 
							record is being updated. This is to avoid user updating a
							record while Batch Processing is running / users accessing 
							the same screen and update record concurrently.
2004/07/28 Chew Pei			Comment off LastUpdDate validation
2004/11/05 Chew Pei			Added @CustSvcId
2005/07/25 Chew Pei			Added MDTCANo
2005/11/7  Esther			Added Billing Type
2005/11/24 Chew Pei			Deleted update of billing type

*******************************************************************************/
-- For Test Only	
CREATE procedure [dbo].[AccountMaint]
	@AcctNo uAcctNo,
	@CorpCd uRefCd,
	@CycNo uCycNo,
	@SrcRefNo varchar(19),
	@Remarks nvarchar(50),
	@PromptPaymtRebate money,
	@Check char(1),
	@WriteOffDate datetime,
	@CustSvcId uUserId,
	@GovernmentLevyFeeCd uRefCd,
	@MDTCANo varchar(15),
	@BillingType uRefCd
--	@LastUpdDate varchar(30)
  as
begin
	declare @PrcsName varchar(50),
		@IssNo uIssNo,
		@LatestUpdDate datetime

--	select @PrcsName = 'AccountMaint'
	
--	exec TraceProcess @IssNo, @PrcsName, 'Start'
	set nocount on
	
/*	if @LastUpdDate is null
		select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))
	
	select @LatestUpdDate = LastUpdDate from iac_Account where AcctNo = @AcctNo
	if @LatestUpdDate is null
		select @LatestUpdDate = isnull(@LatestUpdDate, getdate())
	
	-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
	-- it means that record has been updated by someone else, and screen need to be refreshed
	-- before the next update.

	--if convert(varchar(30), @LatestUpdDate, 21) = convert(varchar(30), @LastUpdDate, 21)
	if @LatestUpdDate = convert(datetime, @LastUpdDate)
	begin*/
		update iac_Account set CorpCd = @CorpCd, 
					CycNo = @CycNo, 
					SrcRefNo = @SrcRefNo,
					Remarks = @Remarks,
					PromptPaymtRebate = @PromptPaymtRebate, 
					PriceShieldInd = @Check, 
					WriteOffDate = @WriteOffDate, 
					CustSvcId = @CustSvcId, 
					GovernmentLevyFeeCd = @GovernmentLevyFeeCd, 
					MDTCANo = @MDTCANo
					--, LastUpdDate = getdate()
		where AcctNo = @AcctNo

		if @@rowcount = 0 return 70124
		
		return 50091
	/*end
	else
	begin
		return 95307 -- Session Expired
	end*/
end
GO
