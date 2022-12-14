USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AccountStatementLoyaltyDetailSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************

Copyright	: CardTrend Systems Sdn. Bhd.
Modular		: CardTrend Card Management System (CCMS)- Issuing Module

Objective	: Select Statement info

SP Level	: Primary
------------------------------------------------------------------------------------------------------------------
When	   Who		CRN	   Desc
------------------------------------------------------------------------------------------------------------------
2002/01/07 Barnett		   Initial development
******************************************************************************************************************/

CREATE	procedure [dbo].[AccountStatementLoyaltyDetailSelect]
	@AcctNo uAcctNo,
	@StmtId int
  as
begin
	
		
		declare	@Cmd varchar(max),
				@ArchiveDB varchar(50),
				@ArchiveDBSts char(1),
				@DataRestoreDB varchar(50),
				@DataRestoreDBSts char(1),
				@MultiConnection char(1)



		select @ArchiveDB = VarcharVal from iss_Default where Deft ='CCMSARCHIVEDB' 

		--Check DataMine DB Status
		SELECT @ArchiveDBSts = 1 FROM sys.databases where Name = @ArchiveDB and State = 0

		select @DataRestoreDB = VarcharVal from iss_Default where Deft ='CCMSDATARESTOREDB' 

		--Check Restoring DB Status
		SELECT @DataRestoreDBSts = 1 FROM sys.databases where Name = @DataRestoreDB and State = 0


		select @Cmd = 'select a.CardNo, a.TxnDate, convert(varchar(10), a.PrcsDate, 120) ''' +'PrcsDate' + ''' 
						, a.BusnLocation, a.Descp ''' + 'MerchantName' + ''' 
						, a.SettleTxnAmt ''' + 'SettleAmt' + ''' , a.Pts, a.PrcsId, a.CashAmt, a.VoucherAmt, 
						a.StmtId, a.PaymtCardPrefix 
		into #temp from itx_Txn a (nolock) 
		where a.AcctNo = ' + Convert(varchar(19), @AcctNo )  
			
		
		if isnull(@ArchiveDBSts,0) = 1
		begin
				select @Cmd = @Cmd + ' union select a.CardNo, a.TxnDate, convert(varchar(10), a.PrcsDate, 120) ''' +'PrcsDate' + ''' 
								, a.BusnLocation, a.Descp ''' + 'MerchantName' + ''' 
								, a.SettleTxnAmt ''' + 'SettleAmt' + ''' , a.Pts, a.PrcsId, a.CashAmt, a.VoucherAmt, 
								a.StmtId, a.PaymtCardPrefix from ' + @ArchiveDB + '..itx_Txn a (nolock) 
				where a.AcctNo = ' + Convert(varchar(19), @AcctNo ) 

		end

		if isnull(@DataRestoreDBSts,0) = 1
		begin
				select @Cmd = @Cmd + ' union select a.CardNo, a.TxnDate, convert(varchar(10), a.PrcsDate, 120) ''' +'PrcsDate' + ''' 
								, a.BusnLocation, a.Descp ''' + 'MerchantName' + ''' 
								, a.SettleTxnAmt ''' + 'SettleAmt' + ''' , a.Pts, a.PrcsId, a.CashAmt, a.VoucherAmt, 
								a.StmtId, a.PaymtCardPrefix from ' + @DataRestoreDB + '..itx_Txn a (nolock) 
				where a.AcctNo = ' + Convert(varchar(19), @AcctNo ) 

		end

		select @Cmd = @Cmd + ' select * from #Temp where StmtId =' + convert(varchar(5),  @StmtId) + 'drop table #Temp '
		
		--select @cmd
		exec (@cmd)
end
GO
