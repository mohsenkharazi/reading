USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CreditAdviceMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: This is to issue credit advice note to customer. It's applied  
			  for those transaction passed cycle process only.

			- Get credit note sequence number from iss_Control.CtrlId = ‘CreditNoteNo’
			- Credit Note Number Format
			  XX-XX-XXXXXX
			  Year + Month + Credit Note Number (to be initialized every month)
			
			Store Credit Note number in itx_HeldTxn..Arn. At the same time, concatenate StmtCycId with Credit Note number.
				itx_HeldTxn..Arn = Credit Note Number + StmtCycId

				

				Note: Do not include dash in credit note number when storing into table.


SP Level	: Primary
-------------------------------------------------------------------------------
When	   Who		CRN		Desc
-------------------------------------------------------------------------------
2003/08/05 Sam		1103017		Initial development.		
******************************************************************************************************************/
CREATE procedure [dbo].[CreditAdviceMaint]
	@IssNo uIssNo,
	@vAcctNo varchar(19),
	@StmtCycId int,
	@TxnCd uTxnCd,
	@TxnAmt money
   as
begin
	declare @AcctNo uAcctNo, @TxnDate datetime, @DeftTermId varchar(50), @DeftBusnLocation varchar(50),
			@Rc int, @CardNo uCardNo, @BusnLocation uMerch, @CreditNote varchar(20), @NoteNo int,
			@Error int, @Descp uDescp50, @Int tinyint, @NoteDate datetime

	set nocount on

	select @AcctNo = cast(@vAcctNo as bigint)

	if @AcctNo is null return 55036 --Account Number is a compulsory field
	if @TxnCd is null return 55069 --Transaction Code is a compulsory field
	if @StmtCycId is null return 55162 --Tax Id is a compulsory field
	if @TxnAmt is null return 55123 --Transaction Amount is a compulsory field

	select @TxnDate = CtrlDate from iss_Control where IssNo = @IssNo and CtrlId = 'PrcsId'

	if @@rowcount = 0 or @@error <> 0 return 95098 --Unable to retrieve information from iss_Control table

	select @DeftTermId = 'CardCenterTermId'

--	if @@rowcount = 0 or @@error <> 0 return 95160 --Unable to retrieve control or default values

	select @DeftBusnLocation = 'CardCenterBusnLocation'

--	if @@rowcount = 0 or @@error <> 0 return 95160 --Unable to retrieve control or default values

	select * into #SourceTxn
	from itx_SourceTxn
	where BatchId = -1
	delete #SourceTxn

	select * into #SourceTxnDetail
	from itx_SourceTxnDetail
	where BatchId = -1
	delete #SourceTxnDetail

	-- Creating index for temporary table
	create	unique index IX_SourceTxnDetail on #SourceTxnDetail (
		BatchId,
		ParentSeq,
		TxnSeq )

	select @Descp = Descp from itx_TxnCode where IssNo = @IssNo and TxnCd = @TxnCd

	if @@rowcount = 0 or @@error <> 0 return 95151 --Check invalid Transaction Code

	select @NoteNo = isnull(CtrlNo, 0),
			@NoteDate = isnull(CtrlDate, @TxnDate)
	from iss_Control
	where IssNo = @IssNo and CtrlId = 'CreditNoteNo'

	if @@rowcount = 0 or @@error <> 0 return 95098 --Unable to retrieve information from iss_Control table

	select @Int = 1
	while 1 = @Int
	begin
		if datepart(mm, @NoteDate) <> datepart(mm, @TxnDate)
		begin
			select @NoteNo = 0, @NoteDate = @TxnDate
		end

		update iss_Control
		set CtrlNo = isnull(@NoteNo, 0) + 1,
			CtrlDate = @TxnDate
		where CtrlId = 'CreditNoteNo' -- and CtrlNo = @NoteNo By CP 20031005 
			and IssNo = @IssNo

		if @Error <> 0 return 70331	--Failed to update Control

		if not exists (select 1 from iss_Control where IssNo = @IssNo and CtrlId = 'CreditNoteNo' and (CtrlNo = @NoteNo + 1))
			select @NoteNo = @NoteNo + 1
		else
			select @Int = 2
	end

	select @CreditNote = substring(convert(varchar(10), @TxnDate, 112), 3,4) + replicate('0', 6 - len(@NoteNo)) + convert(varchar(6), @NoteNo) + replicate('0', 7 - len(@StmtCycId)) + convert(varchar(7), @StmtCycId)

	exec @Rc = ManualTransactionInsert
		@IssNo, @TxnCd, @TxnDate, @TxnAmt, 0, @Descp, null, @AcctNo, null,
		@DeftBusnLocation, @DeftTermId, null, @CreditNote, null, null, null, null

	if @@error <> 0 or dbo.CheckRC(@Rc) <> 0
	begin
		return @Rc
	end

	--------------------
	BEGIN TRANSACTION
	--------------------

	exec @Rc = OnlineTxnProcessing @IssNo

	if @@error <> 0 or dbo.CheckRC(@Rc) <> 0
	begin
		rollback transaction
		return 70109 -- Failed to insert
	end

	--------------------
	COMMIT TRANSACTION
	--------------------
	return 50104

end
GO
