USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardTypeVelocityLimitMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
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
2009/03/26	Barnett				Initial Development
*******************************************************************************/
	--exec CardTypeVelocityLimitMaint 'Save',1,1,'DEMOLTY','D','9999',222.0000,2,NULL,'Amt','26 Mar 2009 16:22:34:670'
CREATE procedure [dbo].[CardTypeVelocityLimitMaint]
		@Func varchar(10),
		@IssNo uIssNo, 
		@CardType uCardType,
		@CardLogo uCardLogo,
		@VelocityInd char(1), 
		@ProdCd uProdCd,
		@VelocityLimit money,
		@VelocityCnt int,
		@VelocityLitre money, 
		@Indicator varchar(10),
		@LastUpdDate varchar(30)
		
   
as
begin

		declare @Rc int,
				@LatestUpdDate datetime


		if @VelocityInd is null return 55031

		if @Indicator is null return 55187 --Contorl Type is a compulsory field

		-- CP : 20040514 [B]
		--if @Indicator = 'Amt' and isnull(@VelocityLimit, 0) = 0 return 55175
		--if @Indicator = 'Litre' and isnull(@VelocityLitre, 0) = 0 return 55176
		if @Indicator = 'Amt' and isnull(@VelocityLimit, 0) = 0 
			select @VelocityLimit = 99999999.99
		if isnull(@VelocityCnt, 0) = 0
			select @VelocityCnt = 9999999
			
	if @Func = 'Add'	
	begin
			-----------------
			begin transaction
			-----------------
			
			if exists (select 1 from iss_CardTypeVelocityLimit where CardType = @CardType and CardLogo = @CardLogo and
			VelocityInd  = @VelocityInd  and ProdCd=isnull(@ProdCd,0)) RETURN --
			
			insert into  iss_CardTypeVelocityLimit
				(CardType, CardLogo, VelocityInd, ProdCd, VelocityLimit,
				VelocityCnt, SpentLimit, SpentLitre, SpentCnt, VelocityLitre, LastUpdDate)
			values (@CardType, @CardLogo, @VelocityInd, isnull(@ProdCd, 0), isnull(@VelocityLimit,0),
				isnull(@VelocityCnt,0), 0, 0, 0, isnull(@VelocityLitre,0), getdate())
	
			if @@error <> 0
			begin
				--------------------
				rollback transaction
				--------------------
				return 70072
			end
				
			------------------
			commit transaction
			------------------
			return 50240 --Velocity Limit has been added successfully
			
	end 

			
	if @Func = 'Save'	
	begin
			begin transaction
			
			update iss_CardTypeVelocityLimit
				set VelocityLimit = isnull(@VelocityLimit, 0),
					VelocityCnt = isnull(@VelocityCnt,0),
					VelocityLitre = isnull(@VelocityLitre, 0)
			where CardType = @CardType and CardLogo = @CardLogo and VelocityInd  = @VelocityInd  and ProdCd=isnull(@ProdCd,0)
			
			if @@error <>0
			begin
					rollback transaction
					return
			end
			
			commit transaction
			return 50241
	end		
	
	if @Func ='Del'
	begin
	
			delete iss_CardTypeVelocityLimit 
			where CardType = @CardType and CardLogo = @CardLogo and VelocityInd  = @VelocityInd  and ProdCd=isnull(@ProdCd,0)
	end
		
		

end
GO
