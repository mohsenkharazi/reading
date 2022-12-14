USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[ApplicationShareholderMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*****************************************************************************************************************
Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Update application Shareholder Info.

-------------------------------------------------------------------------------
When		Who			CRN		Desc
-------------------------------------------------------------------------------
2003/07/03 	KY			1103003	Initial development
2003/09/12  Chew Pei			Make Tel and Fax to be optional.
2004/07/13	Chew Pei			Add LastUpdDate
								This is to ensure that user refresh one screen before 
								record is being updated. This is to avoid user updating a
								record while Batch Processing is running / users accessing 
								the same screen and update record concurrently.
******************************************************************************************************************/

CREATE procedure [dbo].[ApplicationShareholderMaint]
	@Func varchar(10),
	@IssNo uIssNo,
	@ApplId uApplId,
	@Name uFamilyName,
	@Tel uContactNo,
	@Fax uContactNo,
	@ShareholderId uApplId,
	@LastUpdDate varchar(30)
  as
begin
	declare @LatestUpdDate datetime

	if isnull(@IssNo,0) = 0
	return 0	--Mandatory Field IssNo

	if isnull(@ApplId,'') = ''
	return 0	--Mandatory Field ApplId

	if isnull(@Name,'') = ''
	return 55151	--Shareholder Name is compulsory field

--	if isnull(@Tel,'') = ''
--	return 55177	--Telephone Number is a compulsory field

--	if isnull(@Fax,'') = ''
--	return 55178 	--Fax Number is a compulsory field

	if @Func = 'Add'
	begin
		if exists (select 1 from iaa_ShareHolder where IssNo = @IssNo and ApplId = @ApplId and Name = @Name and Tel = @Tel and Fax = @Fax)
		return 65047 	-- Authorised Person already exist

		-----------------
		begin transaction
		-----------------
		insert into iaa_ShareHolder (IssNo, ApplId, Name, Tel, Fax, LastUpdDate)
		values	(@IssNo, @ApplId, @Name, @Tel, @Fax, getdate())

		if @@error <> 0	
		begin
			rollback transaction
			return 70433	-- Failed to create Authorized Person
		end
		------------------
		commit transaction
		------------------

		return 50298	-- Authorized Person has been inserted successfully
	end

	if @Func = 'Save'
	begin
		if not exists (select 1 from iaa_Shareholder where IssNo = @IssNo and ApplId = @ApplId and Id = @ShareholderId)
		return 60072	-- Shareholder not found


		if @LastUpdDate is null
			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 13))

		select @LatestUpdDate = LastUpdDate from iaa_ShareHolder where IssNo = @IssNo and ApplId = @ApplId and Id = @ShareholderId
		if @LatestUpdDate is null
			select @LatestUpdDate = isnull(@LatestUpdDate, getdate())

		-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
		-- it means that record has been updated by someone else, and screen need to be refreshed
		-- before the next update.
		if @LatestUpdDate = convert(datetime, @LastUpdDate)
		begin
			-----------------
			begin transaction
			-----------------

			update iaa_ShareHolder
			set	Name = @Name,
				Tel = @Tel,
				Fax = @Fax,
				LastUpdDate = getdate()
			where IssNo = @IssNo and ApplId = @ApplId and Id = @ShareholderId

			if @@error <> 0
			begin
				rollback transaction
				return 70434	-- Failed to update Shareholder
			end
			------------------
			commit transaction
			------------------

			return 50299	-- Shareholder has been updated successfully
		end
		else
		begin
			return 95307
		end
	end

end
GO
