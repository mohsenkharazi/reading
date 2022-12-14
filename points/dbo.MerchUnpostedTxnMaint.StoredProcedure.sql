USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchUnpostedTxnMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Update merchant unposted transaction. Cnt and Amt in atx_SourceTxn must 
			tally with total cnt and amt in atx_SourceSettlement. 
			Update atx_SourceSettlement..PrcsId and atx_SourceTxn..PrcsId for further 
			processing

-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2004/05/18 Chew Pei			   Initial development
								Parameter :-
								atx_SourceSettlement 
								Ids, BatchId
								atx_SourceTxn (P)
								Ids, SrcIds, TxnDate, Qty, Amt, Odometer
*******************************************************************************/
	
CREATE procedure [dbo].[MerchUnpostedTxnMaint]
	@Func varchar(5),
	@IssNo smallint,
	@Ids uTxnId, -- atx_SourceTxn
	@SrcIds int, -- atx_SourceSettlement
	@TxnDate datetime,
	@Qty money,
	@Amt money,
	@Odometer int
  as
begin
	declare @TableName varchar(50)
	declare @PrcsId uPrcsId
	declare @Cnt int	
	declare @OldTxnDate datetime,
			@OldQty money,
			@OldAmt money,
			@OldOdometer int,
			@TodayPrcsId uPrcsId



	select @PrcsId = CtrlNo
	from iss_Control 
	where CtrlId = 'PrcsId' and IssNo = @IssNo

	-----------------
	BEGIN TRANSACTION
	-----------------

	select @TableName = 'atx_SourceTxn'
	select @OldTxnDate = TxnDate, @OldQty = Qty, @OldAmt = Amt, @OldOdometer = Odometer
	from atx_SourceTxn
	where Ids = @Ids and SrcIds = @SrcIds

	if @Func = 'Save'
	begin

		if @TxnDate <> @OldTxnDate
		begin
			insert into atx_MaintAudit
			(TableName, Field, PriKey, Action, OldVal, NewVal, UserId, CreationDate)
			values 
			(@TableName, 'TxnDate', @Ids, 'A', convert(varchar(20), @OldTxnDate, 120), convert(varchar(20), @TxnDate, 120), system_user, getdate())
			if @@error <> 0
			begin
				rollback transaction
				return 70201
			end
		end

		if @Qty <> @OldQty
		begin
			insert into atx_MaintAudit
			(TableName, Field, PriKey, Action, OldVal, NewVal, UserId, CreationDate)
			values 
			(@TableName, 'Qty', @Ids, 'A', convert(varchar(10), @OldQty), convert(varchar(10), @Qty), system_user, getdate())
			if @@error <> 0
			begin
				rollback transaction
				return 70201
			end
		end

		if @Amt <> @OldAmt
		begin
			insert into atx_MaintAudit
			(TableName, Field, PriKey, Action, OldVal, NewVal, UserId, CreationDate)
			values 
			(@TableName, 'Amt', @Ids, 'A', convert(varchar(10), @OldAmt), convert(varchar(10), @Amt), system_user, getdate())
			if @@error <> 0
			begin
				rollback transaction
				return 70201
			end
		end

		if @Odometer <> @OldOdometer
		begin
			insert into atx_MaintAudit
			(TableName, Field, PriKey, Action, OldVal, NewVal, UserId, CreationDate)
			values 
			(@TableName, 'Odometer', @Ids, 'A', convert(varchar(10), @OldOdometer), convert(varchar(10), @Odometer), system_user, getdate())
			if @@error <> 0
			begin
				rollback transaction
				return 70201
			end
		end
		
		update a
		set TxnDate = @TxnDate, Qty = @Qty, Amt = @Amt, Odometer = @Odometer, PrcsId = @PrcsId
		from atx_SourceTxn a
		where Ids = @Ids and SrcIds = @SrcIds
		if @@error <> 0
		begin
			rollback transaction
			return 70396
		end
	end
	------------------
	COMMIT TRANSACTION
	------------------
	return 50263

end
GO
