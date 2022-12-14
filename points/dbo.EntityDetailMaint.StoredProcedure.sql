USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[EntityDetailMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:

Objective	:

-------------------------------------------------------------------------------
When		Who		CRN		Description
-------------------------------------------------------------------------------
2009/03/25	Barnett				Initial Development
*******************************************************************************/
	
CREATE procedure [dbo].[EntityDetailMaint]
	@EntityId uEntityId,
	@AppcId uAppcId,
	@PrefLanguage int,
	@PrefCommunication int,
	@Interest int,
	@NewsPaper int,
	@NewsPaperInp varchar(30),
	@Radio int,
	@RadioInp varchar(30),
	@Television int,
	@TelevisionInp varchar(30),
	@SignDate datetime
  
as
begin

	if @AppcId >0
	begin
	
			------------------
			begin transaction
			------------------
			
			update iap_applicant 
			set PrefLanguage = @PrefLanguage,
				PrefCommunication = @PrefCommunication,
				Interest = @Interest,
				NewsPaper = @NewsPaper,
				NewsPaperInp = @NewsPaperInp,
				Radio = @Radio,
				RadioInp = @RadioInp,
				Television = @Television,
				TelevisionInp = @TelevisionInp,
				SignDate =  @SignDate
			where AppcId = @AppcId
		
			
			if @@error <> 0 and @@rowcount = 0
			begin
					rollback transaction
					return 71065 --'Failed to update Entity Detail'
			end
	end

	if @EntityId >0
	begin
			------------------
			begin transaction
			------------------
			
			update iac_Entity 
			set PrefLanguage = @PrefLanguage,
				PrefCommunication = @PrefCommunication,
				Interest = @Interest,
				NewsPaper = @NewsPaper,
				NewsPaperInp = @NewsPaperInp,
				Radio = @Radio,
				RadioInp = @RadioInp,
				Television = @Television,
				TelevisionInp = @TelevisionInp,
				SignDate = @SignDate
			where EntityId = @EntityId
			
			if @@error <> 0 and @@rowcount = 0
			begin
					rollback transaction
					return 71065 --'Failed to update Entity Detail'
			end
			
	end

	------------------
	commit transaction
	------------------
	return 50536 -- 
end
GO
