USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[LayAwayMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:To insert new or update lay away records
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2002/03/01 Wendy		   Initial development

*******************************************************************************/
	
CREATE procedure [dbo].[LayAwayMaint]
	@Func varchar(5),
	@IssNo uIssNo,
	@CardNo varchar(19),
	@StartDate datetime,
	@Descp uDescp50,
	@TxnCd uRefCd,
	@BusnLocation uMerch, 
	@GrossAmt money,
	@AnnualInterest tinyint,
	@InstallmentType tinyint,
	@NoInstallment smallint,
	@InstallmentAmt money,
	@LastInstallmentAmt money,
	@DocRefNo varchar(19),
	@InstallmentPaid smallint,
	@AmtPaid money,
	@UserId uUserId,
	@RefId int
  as
begin
	declare @Sts char(1)

	if @Func = 'Add'	
	begin

		if @Descp is null return 55017
		if @StartDate is null return 55093
		if @TxnCd is null return 55069
		if @BusnLocation is null return 55094

		select @InstallmentPaid = 0
		select @AmtPaid = 0
		select @Sts = RefCd from iss_RefLib where RefType = 'LayAwaySts' and RefInd = 0 and IssNo = @IssNo 

		insert into iac_LayAway (CardNo, StartDate, Descp, GrossAmt, AnnualInterest, TxnCd,
		BusnLocation, InstallmentType, NoOfInstallment, InstallmentAmt, LastInstallmentAmt, DocRefNo,
		UserId, CreationDate, Sts, InstallmentPaid, AmtPaid)
		values (convert(bigint,@CardNo), @StartDate, @Descp, @GrossAmt, isnull(@AnnualInterest,0), @TxnCd, @BusnLocation,
		@InstallmentType,  isnull(@NoInstallment,0), isnull(@InstallmentAmt,0),  isnull(@LastInstallmentAmt,0), @DocRefNo, @UserId, getdate(), @Sts, @InstallmentPaid, @AmtPaid)  

		return 50118	-- Successfully added 
	end 

	if @Func = 'Save'	
	begin
	
		if @Descp is null return 55017
		if @StartDate is null return 55093
		if @TxnCd is null return 55069
		if @BusnLocation is null return 55094

		select @Sts = RefCd from iss_RefLib where RefType = 'LayAwaySts' and RefInd = 1 and IssNo = @IssNo

			update iac_LayAway set	
		  	Sts=@Sts where RefId = @RefId
		
			return 50119	-- Successfully updated

	end 
end
GO
