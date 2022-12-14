USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardReEmboss]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	:To update existing card financial information.
-------------------------------------------------------------------------------
When	   Who		CRN	   Description
-------------------------------------------------------------------------------
2003/05/19 Kenny  9903004  Enable re-embossing of card
2003/12/04 Aeris 	   Change the msg to 50105
*******************************************************************************/

CREATE procedure [dbo].[CardReEmboss]
	@IssNo uIssNo,
	@CardNo varchar(19),
	@CardNo1 varchar(19) output,
	@ExpiryDate datetime,
	@FeeCd uRefCd,
	@ReasonCd uRefCd,
	@Narrative nvarchar(400)
   as
begin
	declare	@PrcsName varchar(50),
		@PrcsId uPrcsId,
		@PrcsDate datetime,
		@PlasticType uPlasticType,
		@CardLogo uCardLogo,
		@EventType uRefCd,
		@AcctNo uAcctNo,
		@Msg nvarchar(80),
		@EventId int,
		@Descp uDescp50,
		@TxnCd uTxnCd,
		@TxnAmt money,
		@Pts money,
		@RetCd int,
		@rc int

	exec @rc = InitProcess
	if @@error <> 0 or @rc <> 0 return 99999

	exec TraceProcess @IssNo, @PrcsName, 'Start'

	select @PrcsName = 'CardReEmboss'

	select @EventType = VarcharVal from iss_Default where Deft='EventTypeReEmboss'

	select @PrcsId = CtrlNo, @PrcsDate = CtrlDate
	from iss_Control where IssNo = IssNo and CtrlId = 'PrcsId'
	
	select @PlasticType=PlasticType, @CardLogo=CardLogo, @AcctNo=AcctNo
	from iac_Card where CardNo=@CardNo

	if @ReasonCd is null return 55055

	-- Creating Temporary Tables --
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

	if exists (select 1 from iac_PlasticCard where CardNo = @CardNo and BatchId is null )
	begin
		return 65017
	end
	-------------------
	BEGIN TRANSACTION
	-------------------	

	-- Insert new record in Plastic Card for embossing
	insert iac_PlasticCard (IssNo, BatchId, CardLogo, PlasticType, AcctNo, CardNo,
		EmbName, ExpiryDate, InputSrc, CreationDate, Sts)
	select	@IssNo, null, CardLogo, PlasticType, AcctNo, CardNo,
		EmbName, ExpiryDate, 'REMB', getdate(), null
	from iac_Card where CardNo = @CardNo

	if @@error <> 0
	begin
		rollback transaction
		return 70352	-- Failed to create Plastic Card
	end
	
	-- Creating an event for the old card 
	select @Msg = 'Card Reemboss - (Re-Embossed CardNo : ' + @CardNo + ')'

	insert into iac_Event (IssNo, EventType, AcctNo, CardNo, ReasonCd, Descp,
		Priority, CreatedBy, CreationDate, SysInd, Sts)
	values (@IssNo, @EventType, @AcctNo, @CardNo, @ReasonCd, @Msg,
		'L', system_user, getdate(), 'Y', 'C')

	if @@error <> 0
	begin
		rollback transaction
		return 70194	-- Failed to create event
	end

	select @EventId = @@identity

	if (@Narrative is not null)
	begin
		insert into iac_EventDetail (EventId, Seq, Descp, CreationDate, CreatedBy)
		values (@EventId, 1, @Narrative, getdate(), system_user) 

		if @@error <> 0
		begin
			rollback transaction
			return 70196	-- Failed to insert event detail
		end
	end

	if @FeeCd is null
	begin
		------------------
		COMMIT TRANSACTION
		------------------
		--return 50303	-- Card has been re-embossed successfully
		--2003/12/04B
		return 50105	-- Card has been replaced successfully
		--2003/12/04E
	end

	------------------------
	-- Create transaction --
	------------------------
	select @Descp = Descp, @TxnCd = TxnCd, @TxnAmt = Fee, @Pts = Pts
	from iss_FeeCode
	where IssNo = @IssNo and FeeCd = @FeeCd

	exec @RetCd = ManualTransactionInsert
			@IssNo=@IssNo, @TxnCd=@TxnCd, @TxnDate=null, @TxnAmt=@TxnAmt, @Pts=@Pts,
			@Descp=@Descp, @AppvCd=null, @AcctNo=@AcctNo, @CardNo=@CardNo,
			@DeftBusnLocation='CardCenterBusnLocation', @DeftTermId='CardCenterTermId',
			@BusnLocation=null, @Arn=null, @SrcTxnId=null,
			-- 2003/05/02 9903001 Added @RcptNo, @CheqNo
			--Added new parameter @RefTxnId 2003/07/17
			@RefTxnId=null, @RcptNo=null, @ChqNo=null

	if @@error <> 0 or dbo.CheckRC(@RetCd) <> 0
	begin
		rollback transaction
		return 70109	-- Failed to insert into itx_SourceTxn
	end

	-- Process transaction
	exec @RetCd = OnlineTxnProcessing @IssNo

	if @@error <> 0 or dbo.CheckRC(@RetCd) <> 0
	begin
		rollback transaction
		return 70109	-- Failed to insert
	end

	--------------------
	COMMIT TRANSACTION
	--------------------
	--return 50303	-- Card has been re-embossed successfully
	--2003/12/04B
	return 50105	-- Card has been replaced successfully
	--2003/12/04E
end
GO
