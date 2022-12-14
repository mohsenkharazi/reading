USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CardTransfer]    Script Date: 9/6/2021 10:33:55 AM ******/
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
2002/03/11 Pei Shan	       Initial development
2009/04/04 Chew Pei			Do not update card status if original card status is not active
2009/09/09 Barnett			Convert the Pts to Money Unit first before transfer
2009/09/09 Barnett		   roll back this changes -- Do not update card status if original card status is not active
2010/11/25 Barnett			Add @XLastPurchasedDate for update the Card LastPurchasedDate from old card.
*******************************************************************************/
/*



declare @rc int
exec @rc = CardTransfer 1,'70838155100004012','70838155000003741','5100003741'

select @rc

*/
CREATE	procedure [dbo].[CardTransfer]
	@IssNo uIssNo,
	@CardNo varchar(19),  
	@TrfCardNo varchar(19), 
	@TrfAcctNo varchar(20)
	
  as
begin
	declare @AcctNo uAcctNo, @Sts char(1), @EntityId int, @SysDate datetime, @CreditAdjTxnCode int, 
			@DebitAdjTxnCode int, @RcptNo int, @ClosedCardSts uRefCd, @Pts money, @RefCd nvarchar(1), @rc int,
			@AcctSts uRefCd, @ClosedAcctSts uRefCd, @RetCd int, @RefInd int,
			@DebitAdjTxnCodeDescp uDescp50, @CreditAdjTxnCodeDescp uDescp50, @XRefCardNo varchar(20),
			@XLastPurchasedDate datetime, @NewCardNRIC uNewIc, @OldCardNRIC uNewIc

	set nocount on 

	select @SysDate = convert(varchar(15), getdate(),112)

	if exists (select 1 from iac_Card where CardNo = @CardNo)
	begin	

		select @AcctNo = AcctNo
		from iac_Card
		where CardNo = @CardNo
		
		if @AcctNo is null return 60000 -- Account not found
	end

	------------------------
	-- CardTransfer Checking
	------------------------

	-- Check Old Account Closed
	if exists (select 1 from iac_Account where AcctNo = @TrfAcctNo and Sts ='C')
		return 95090	--	Account not active
	
	-- Check New Account Closed
	if exists (select 1 from iac_Account where AcctNo = @AcctNo and Sts ='C')
		return 95090	-- Account not active-- --

	
	
	-- Same old and new AcctNo no.
	if @AcctNo = @TrfAcctNo return 95558 -- Card transfer at same account are not allow


	-- Check if Card got any Txn stuck in WIthHeld
	if exists (select 1 from itx_WithheldUnsettleTxn a (nolock) where a.AcctNo = @AcctNo)
		return 95559 -- 'Withheld Unsettle txn has been found in the list, Card Transfer are not allow.'


	-- Check both Card NRIC
	select @NewCardNRIC = b.NewIc
	from iac_card a (nolock)
	join iac_Entity b (nolock) on b.EntityId = a.EntityId
	where a.CardNo = @CardNo


	select @OldCardNRIC = b.NewIc
	from iac_card a (nolock)
	join iac_Entity b (nolock) on b.EntityId = a.EntityId
	where a.CardNo = @TrfCardNO

	if @NewCardNRIC <> @OldCardNRIC return 95503 -- NIRC not matched
	 
	



	
	select @ClosedCardSts = RefCd 
	from iss_RefLib where RefType = 'CardSts' and RefNo = 0 and (RefId & 8) > 0

	select @ClosedAcctSts = RefCd 
	from iss_RefLib where  RefType= 'AcctSts' and RefInd = 3 and (MapInd & 4 )> 0
	
	select @CreditAdjTxnCode = IntVal from iss_Default where Deft = 'CreditAdjTxnCode'
	select @CreditAdjTxnCodeDescp = Descp from itx_TxnCode where TxnCd = @CreditAdjTxnCode

	select @DebitAdjTxnCode = IntVal from iss_Default where Deft = 'DebitAdjTxnCode'
	select @DebitAdjTxnCodeDescp = Descp from itx_TxnCode where TxnCd = @DebitAdjTxnCode

	
	select @Pts = (a.AccumAgeingPts + isnull(a.WithheldPts,0) + b.WithheldPts) / 100 -- divide 100 to convert time RM unit
	from iac_AccountFinInfo a (nolock)
	join iac_OnlineFinInfo b (nolock) on b.AcctNo = a.AcctNo
	where a.AcctNo = @AcctNo
	
	select @CreditAdjTxnCodeDescp = Descp + ' '+ convert(varchar(20), @CardNo) from itx_TxnCode where TxnCd = @CreditAdjTxnCode
	select @DebitAdjTxnCodeDescp = Descp + ' '+ convert(varchar(20), @TrfCardNo) from itx_TxnCode where TxnCd = @DebitAdjTxnCode
		
	
	if @Pts > 0
	begin
			
		
		exec @rc = PaymentAdjustment @IssNo, @CreditAdjTxnCode, @SysDate, @Pts, @Pts, @CreditAdjTxnCodeDescp, null, @AcctNo, @CardNo, 
							   'CardCenterBusnLocation', 'CardCenterTermId', null, @RcptNo output, @RetCd output 

		/*
		if @rc <> 50104 
		begin
			return @rc	
		end*/
		
		exec @rc = PaymentAdjustment @IssNo, @DebitAdjTxnCode, @SysDate, @Pts, @Pts, @DebitAdjTxnCodeDescp, null, @TrfAcctNo, @TrfCardNo, 
							   'CardCenterBusnLocation', 'CardCenterTermId', null, @RcptNo output, @RetCd output 
	
							 /*
		if @rc <> 50104 
		begin
			return @rc	
		end*/
		
	end
	
	
	-----------------
	begin transaction
	-----------------

	select @RefInd = RefInd, @XRefCardNo = XRefCardNo, @XLastPurchasedDate = LastPurchasedDate
	from iac_Card a
	join iss_Reflib b on b.RefType = 'CardSts' and b.RefCd = a.Sts and b.IssNo = @IssNo
	where CardNo = @TrfCardNo
		
		
	update iac_Card
	set XrefAcctNo = @AcctNo,	
		AcctNo = @TrfAcctNo,
		XRefCardNo = @XRefCardNo,
		LastPurchasedDate = case
								when @XLastPurchasedDate > LastPurchasedDate then @XLastPurchasedDate
								else LastPurchasedDate
							end		
	where CardNo = @CardNo

	if @@error <> 0
	begin
		rollback transaction
		return 70132  -- Failed to update card detail
	end

	-- Tag the Account Sts to closed
	update iac_account 
		set Sts = @ClosedAcctSts
	where AcctNo = @AcctNo 
		
	if @@error <> 0
	begin
		rollback transaction
		return 95172  -- Failed to change account status
	end
	
	if @@rowcount >0
	begin
		
			insert into iac_Event (IssNo, EventType, AcctNo, CardNo, ReasonCd, Descp, 
				Priority, CreatedBy, AssignTo, XRefDoc, CreationDate, SysInd, Sts)
			values (@IssNo, 'ChgSts', @AcctNo, @CardNo, 'RPLC', 'Old card replace with new card',
				'L', system_user, null, null, getdate(), 'Y', 'C')
				
			if @@error <> 0
			begin
				rollback transaction
				return 70194	-- Failed to create event
			end
	end
	
	-- set TrfCardNo Sts to closed
	
	update iac_Card
	set Sts = @ClosedCardSts
	where CardNo = @TrfCardNo and AcctNo= @TrfAcctNo and @RefInd <= 4

	if @@error <> 0
	begin
		rollback transaction
		return 70363  -- Failed to update Card Status
	end
	
	if @RefInd <= 4
	begin
			
			insert into iac_Event (IssNo, EventType, AcctNo, CardNo, ReasonCd, Descp, 
				Priority, CreatedBy, AssignTo, XRefDoc, CreationDate, SysInd, Sts)
			values (@IssNo, 'ChgSts', @TrfAcctNo, @TrfCardNo, 'RPLC', 'Old card replace with new card',
				'L', system_user, null, null, getdate(), 'Y', 'C')
				
			if @@error <> 0
			begin
				rollback transaction
				return 70194	-- Failed to create event
			end
	
	end
	
	------------------
	commit transaction
	------------------
		 
	return 50303  -- Card has been transferred successfully

end
GO
