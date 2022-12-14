USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MerchUnpostedTxnDetailMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
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
								atx_SourceTxnDetail
								Ids, SrcIds, ParentIds, ProdCd, Descp, Qty, Amt
*******************************************************************************/
	
CREATE procedure [dbo].[MerchUnpostedTxnDetailMaint]
	@Func varchar(5),
	@IssNo smallint,
	@Ids int, -- atx_SourceTxnDetail
	@SrcIds int, -- atx_SourceTxn
	@ParentIds int, -- atx_SourceSettlement
	@Seq int, 
	@ProdCd uProdCd,
	@Descp uDescp50,
	@Qty money,
	@Amt money
	
  as
begin
	declare @TableName varchar(50)
	declare @PrcsId uPrcsId
	declare @Cnt int, @ParentAmt money
	declare @OldProdCd uProdCd,
			@OldDescp uDescp50,
			@OldQty money,
			@OldAmt money

	select @PrcsId = CtrlNo
	from iss_Control 
	where CtrlId = 'PrcsId' and IssNo = @IssNo

	-----------------
	BEGIN TRANSACTION
	-----------------
	select @TableName = 'atx_SourceTxnDetail'

	select @OldProdCd = ProdCd, @OldDescp = Descp, @OldQty = Qty, @OldAmt = AmtPts
	from atx_SourceTxnDetail
	where Ids = @Ids and SrcIds = @SrcIds and ParentIds = @ParentIds

	if @Func = 'Save'
	begin
		if @ProdCd <> @OldProdCd
		begin
			insert into atx_MaintAudit
			(TableName, Field, PriKey, Action, OldVal, NewVal, UserId, CreationDate)
			values 
			(@TableName, 'ProdCd', @Ids, 'A', @OldProdCd, @ProdCd, system_user, getdate())
			if @@error <> 0
			begin
				rollback transaction
				return 70201
			end
		end

		if @Descp <> @OldDescp
		begin
			insert into atx_MaintAudit
			(TableName, Field, PriKey, Action, OldVal, NewVal, UserId, CreationDate)
			values 
			(@TableName, 'Descp', @Ids, 'A', @OldDescp, @Descp, system_user, getdate())
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

		update a
		set ProdCd = @ProdCd, Descp = @Descp, Qty = @Qty, AmtPts = @Amt
		from atx_SourceTxnDetail a
		where Ids = @Ids and SrcIds = @SrcIds and ParentIds = @ParentIds and Seq = @Seq
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
