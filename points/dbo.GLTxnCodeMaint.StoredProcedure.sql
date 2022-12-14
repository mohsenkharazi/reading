USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GLTxnCodeMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)

Objective	:Maintaince The GLTxnCode

-------------------------------------------------------------------------------
When		Who		CRN	Description
-------------------------------------------------------------------------------
2005/10/05	Alex			Initial Development
2005/11/18	Chew Pei		Added 
2009/03/16	Chew Pei		Make changes according to PDB requirement:-
2009/06/10	Chew Pei		Added GLTxnDescp, ExtInd, PromoInd
2012/09/12	Barnett			Added Profit Center for PDB ver						
*******************************************************************************/
--exec GLTxnCodeMaint 'Save', 100,'adssd','asdads','C'
CREATE procedure [dbo].[GLTxnCodeMaint]
	@Func varchar(5),
	@TxnCd uTxnCd,	
	@AcctTxnCd varchar(11),
	@AcctName nvarchar(60),
	@TxnType varchar(10),
	@OldGLTxnCd varchar(11),
	@SlipSeq varchar(10), -- PDB-SAP Doc Type,
	@RcCd varchar(10),
	@GLTxnDescp nvarchar(60),
	@ExtInd uRefCd,
	@PromoInd char(1),
	@ProfitCenter varchar(10)
  as
begin
	declare @Descp nvarchar(40)

	--Validation Checking--
	if @AcctTxnCd is null return 55225 --GL Transaction Code a compulsory field
	if @TxnType is null return 55226 -- Transaction Type is a compulsory field
	if @TxnCd is null return 55227 --Fleet Transaction Code is a compulsory field
	if @AcctName is null return 55017 --Description is a compulsory field
	if @GLTxnDescp is null return 55017 

	if (select len(@AcctTxnCd)) > 11  
		return 95330 -- GL AcctNo Cannot Greater then 11 Numbers

	if (select len(@AcctName)) >40
		return 95331 -- Description Canoot more then 40 character

	
	if @Func = 'Add'
	begin

		if exists (select 1 from iss_GLCode where TxnCd = @TxnCd and AcctTxnCd = @AcctTxnCd)
			return 65063 -- GL Transaction Code already exists

		select @Descp = Descp from itx_TxnCode where TxnCd = @TxnCd
		-----------------
		Begin Transaction
		-----------------

		insert iss_GLCode(TxnCd, RcCd, SlipSeq, TxnType, AcctTxnCd, Descp, AcctName, GLTxnDescp, ExtInd, PromoInd, ProfitCenter)
		values(@TxnCd, @RcCd, @SlipSeq, @TxnType, @AcctTxnCd, @Descp, @AcctName, @GLTxnDescp, @ExtInd, @PromoInd, @ProfitCenter)
		
		
		if @@error <> 0
		begin
			--------------------
			rollback transaction
			--------------------   
			return 70910 -- Failed to insert GL Code

		end

		------------------
		Commit Transaction
		-----------------
		return 50342 -- GL Code has been added successfully
	end

	if @Func ='Save'
	begin
		if exists (select 1 where @OldGLTxnCd <> @AcctTxnCd ) -- got change AcctTxnCd  
		begin
	--		if exists(select 1 from udiE_GLTxn where TxnCd = @TxnCd and AcctTxnCd = @OldGLTxnCd)
	--			return 95332 -- Unable to Update GL Code because data is being used

			if exists (select 1 from iss_GLCode where TxnCd = @TxnCd and AcctTxnCd = @AcctTxnCd)
				return 65063 -- GL Transaction Code already exists
		end

		-----------------
		Begin Transaction
		-----------------
		
		update iss_GLCode
			set AcctTxnCd = @AcctTxnCd,
				TxnType = @TxnType,
				AcctName = @AcctName,
				RcCd = @RcCd,
				SlipSeq = @SlipSeq,
				GLTxnDescp = @GLTxnDescp,
				ExtInd = @ExtInd,
				PromoInd = @PromoInd,
				ProfitCenter = @ProfitCenter
		where TxnCd = @TxnCd and AcctTxnCd = @OldGLTxnCd
		
		if @@error <> 0
		begin
			--------------------
			rollback transaction
			--------------------   
			return 70909 -- Failed to update GL Code
		end
		
		------------------
		Commit Transaction
		------------------
		return 50340 -- GL Code has been update successfully
	end

	
end
GO
