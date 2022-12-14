USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[DealerCodeMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
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
2009/03/10	Barnett				Initial Development
*******************************************************************************/
	
CREATE procedure [dbo].[DealerCodeMaint]
	@Func varchar(6),
	@AcqNo uAcqNo,
	@DealerCd uRefCd,
	@Descp uDescp50,
	@PersonInCharge uDescp50,
	@NewIC uNewIC,
	@LastUpdDate varchar(30)
  
as
begin

	declare @LatestUpdDate datetime

	if @Func ='Add'
	begin
	
			if exists(select 1 from aac_DealerCode where AcqNo = @AcqNo and DealerCd = @DealerCd)
			return 65092 -- Dealer Code Already Exists.
	
			------------------
			begin transaction
			------------------

			insert aac_DealerCode(AcqNo,DealerCd, Descp, PersonInCharge, NewIC)
			select @AcqNo, @DealerCd, @Descp, @PersonInCharge, @NewIC
			
			if @@error <> 0
			begin
				
				 ---------------------
				 rollback Transaction
				 ---------------------
				 return 71058 -- Fail tp Insert Dealer Code
			
			end	
			
			
			-----------------------
			Commit Transaction
			-----------------------
			Return 50358 -- Insert Dealer Code successfully
			
	end
	
	
		
		
	if @Func ='Save'
	begin

			if @LastUpdDate is null
			select @LastUpdDate = isnull(@LastUpdDate, convert(varchar(30), getdate(), 120))
	
			select @LatestUpdDate = LastUpdDate 
			from aac_DealerCode (nolock) where AcqNo = @AcqNo and DealerCd = @DealerCd

			if @LatestUpdDate is null
				select @LatestUpdDate = convert(varchar(30), isnull(@LatestUpdDate, getdate()), 120)

			-- Only allow update is @LatestUpdDate = @LastUpdDate, if @LatestUpdDate > @LastUpdDate
			-- it means that record has been updated by someone else, and screen need to be refreshed
			-- before the next update.
			if @LatestUpdDate = convert(datetime, @LastUpdDate)
			begin
					------------------
					begin transaction
					------------------
				
					update aac_DealerCode
					set  Descp = @Descp,
						PersonInCharge = @PersonInCharge,
						NewIC = @NewIC
					where AcqNo = @AcqNo and DealerCd = @DealerCd
					
					if @@error <> 0 or @@rowcount =0
					begin
						 ---------------------
						 rollback Transaction
						 ---------------------
						 return  71059 -- Fail To Update Dealer Code
					end
					
					-----------------------
					Commit Transaction
					-----------------------
					Return  50359 -- Update Dealer Code successfully
			end
			else
			begin
					return 95307	-- Session Expired
			end				
	end
	
	
	if @Func='Delete'
	begin
			------------------
			begin transaction
			------------------
		
			delete aac_DealerCode
			where AcqNo = @AcqNo and DealerCd = @DealerCd
		
			if @@error <> 0 or @@rowcount =0
			begin
				 ---------------------
				 rollback Transaction
				 ---------------------
				 return 71060 -- Fail To Delete Dealer Code
			end
			-----------------------
			Commit Transaction
			-----------------------
			Return 50360 -- Delete Dealer Code successfully
			
	end

end
GO
