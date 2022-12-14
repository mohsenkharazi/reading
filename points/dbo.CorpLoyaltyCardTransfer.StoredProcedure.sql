USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[CorpLoyaltyCardTransfer]    Script Date: 9/6/2021 10:33:55 AM ******/
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
2010/06/01	Barnett				Initial Development
*******************************************************************************/
	
CREATE procedure [dbo].[CorpLoyaltyCardTransfer]
	@IssNo uIssNo,
	@PriCardNo uCardNo,
	@PriAcctNo uAcctNo,
	@CardNo uCardNo
   
as
begin
		declare @Pts money, @rc int, @ClosedAcctSts uRefCd, @SysDate datetime,
				@AcctNo uAcctNo, @RcptNo int, @RetCd int,
				@CreditAdjTxnCode int, @DebitAdjTxnCode int,
				@DebitAdjTxnCodeDescp uDescp50, @CreditAdjTxnCodeDescp uDescp50

		select @SysDate = convert(varchar(15), getdate(),112)

		Select @AcctNo = a.AcctNo from iac_card a where a.CardNo = @CardNo
		
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
	

		
		if @Pts > 0
		begin
				
			
			exec @rc = PaymentAdjustment @IssNo, @CreditAdjTxnCode, @SysDate, @Pts, @Pts, @CreditAdjTxnCodeDescp, null, @AcctNo, @CardNo, 
								   'CardCenterBusnLocation', 'CardCenterTermId', null, @RcptNo output, @RetCd output 

			/*
			if @rc <> 50104 
			begin
				return @rc	
			end*/
			
			exec @rc = PaymentAdjustment @IssNo, @DebitAdjTxnCode, @SysDate, @Pts, @Pts, @DebitAdjTxnCodeDescp, null, @PriAcctNo, @PriCardNo, 
								   'CardCenterBusnLocation', 'CardCenterTermId', null, @RcptNo output, @RetCd output 
		
								 /*
			if @rc <> 50104 
			begin
				return @rc	
			end*/
			
		end

	
		------------------
		begin transaction
		------------------
	
--		update a
--		Set CorpCd = @CorpCd
--		from iac_Account b 
--		where a.AcctNo = @AcctNo


		-- set TrfCardNo Sts to Corperate Loyalty
		update iac_Card
		set XrefAcctNo = @AcctNo,	
			AcctNo = @PriAcctNo,
			Sts = 'L', 
			PriSec ='S' --sub card
		where CardNo = @CardNo

		if @@error <> 0
		begin
			rollback transaction
			return 70132  -- Failed to update card detail
		end
		
			
		insert into iac_Event (IssNo, EventType, AcctNo, CardNo, ReasonCd, Descp, 
			Priority, CreatedBy, AssignTo, XRefDoc, CreationDate, SysInd, Sts)
		values (@IssNo, 'ChgSts', @AcctNo, @CardNo, 'COTH', 'Corperate Loyalty Transfer',
			'L', system_user, null, null, getdate(), 'Y', 'C')
			
		if @@error <> 0
		begin
			rollback transaction
			return 70194	-- Failed to create event
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
		
	

	------------------
	commit transaction
	------------------
		 
	return 50303  -- Card has been transferred successfully
end
GO
