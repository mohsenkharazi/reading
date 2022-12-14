USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchGLTxnCodeMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
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
2009/06/09	Chew Pei		Added GLTxnDescp, ExtInd, SlipSeq (or Doc Type)
2012/09/12	Barnett			Added Profit Center for PDB ver
*******************************************************************************/

CREATE procedure [dbo].[MerchGLTxnCodeMaint]
	@Func varchar(5),
	@AcqNo uAcqNo,
	@TxnCd uTxnCd,	
	@GLAcctNo varchar(11),
	@AcctName nvarchar(60),
	@TxnType varchar(10),
	@OldGLTxnCd varchar(11),
	@SrvcInd char(1),
	@SlipSeq varchar(10),
	@GLTxnDescp nvarchar(60),
	@ExtInd uRefCd,
	@ProfitCenter varchar(10)
  as
begin
	declare @RcCd varchar(3),
		@Descp nvarchar(40)

	--Validation Checking--
	if @GLAcctNo is null return 55225 --GL Transaction Code a compulsory field
	if @TxnType is null return 55226 -- Transaction Type is a compulsory field
	if @TxnCd is null return 55227 --Fleet Transaction Code is a compulsory field
	if @AcctName is null return 55017 --Description is a compulsory field

	if (select len(@GLAcctNo)) > 11  
		return 95330 -- GL AcctNo Cannot Greater then 11 Numbers

	if (select len(@AcctName)) >40
		return 95331 -- Description Cannot more then 40 character

	

	select @RcCd = RefId from iss_Reflib where RefType ='GLTxnType' and RefCd = @TxnType
	if @Func = 'Add'
	begin

		if exists (select 1 from acq_GLCode where TxnCd = @TxnCd and GLAcctNo = @GLAcctNo)
			return 65063 -- GL Transaction Code already exists

		select @Descp = Descp from atx_TxnCode where TxnCd = @TxnCd
		-----------------
		Begin Transaction
		-----------------

		insert acq_GLCode(AcqNo, TxnCd, RcCd, SlipSeq, TxnType, GLAcctNo, Descp, AcctName, SrvcInd, GLTxnDescp, ExtInd, ProfitCenter)
		values(@AcqNo,@TxnCd, @RcCd, @SlipSeq, @TxnType, @GLAcctNo, @Descp, @AcctName, @SrvcInd, @GLTxnDescp, @ExtInd, @ProfitCenter)
		
		
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
		if exists (select 1 where @OldGLTxnCd <> @GLAcctNo ) -- got change AcctTxnCd  
		begin
	--		if exists(select 1 from udiE_GLTxn where AcctTxnCd = @OldGLTxnCd)
	--			return 95332 -- Unable to Update GL Code because data is being used

			if exists (select 1 from acq_GLCode where TxnCd = @TxnCd and GLAcctNo = @GLAcctNo)
				return 65063 -- GL Transaction Code already exists
		end

		-----------------
		Begin Transaction
		-----------------
		
		update acq_GLCode
			set GLAcctNo = @GLAcctNo,
				TxnType = @TxnType,
				AcctName = @AcctName,
				RcCd = @RcCd,
				SrvcInd = @SrvcInd,
				ExtInd = @ExtInd,
				GLTxnDescp = @GLTxnDescp,
				SlipSeq = @SlipSeq,
				ProfitCenter = @ProfitCenter
		where TxnCd = @TxnCd and GLAcctNo = @OldGLTxnCd and AcqNo = @AcqNo
		
		if @@error <> 0
		begin
			--------------------
			rollback transaction
			--------------------   
			return 70912 -- Failed to update GL Code
		end
		
		------------------
		Commit Transaction
		------------------
		return 50340 -- GL Code has been update successfully
	end
	
end
GO
