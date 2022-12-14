USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[InvoiceReport]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*****************************************************************************************************************
Copyright	:	CardTrend Systems Sdn. Bhd.
Modular		:	CardTrend Card Management System (CCMS)- Issuing Module

Objective	:	This stored procedure will print all monthly report.
			Output Report Name : Crystal Report Name + Date
					eg : NewAcctApplMthlySts20021231 (27 char in length)
			Length for Output Report Name should not more than 30 char.
------------------------------------------------------------------------------------------------------------------
When	   	Who		Desc
------------------------------------------------------------------------------------------------------------------
2005/11/14 	Chew Pei	Initial development
					
******************************************************************************************************************/

CREATE procedure [dbo].[InvoiceReport]
	@IssNo uIssNo,
	@PrcsId uPrcsId = null
  as
begin
		declare @rc int,
		@PrcsName varchar(50),
		@PrcsDate datetime,
		@CCMSDb nvarchar(50),
		@SPName varchar(50),
		@CycNo tinyint,
		@Ind char(1),
		@FromDate datetime,
		@ToDate datetime,
		@RptName varchar(50)
		

	select @PrcsName = 'InvoiceReport'

	if @PrcsId is null
	begin
		select @PrcsId = CtrlNo, @PrcsDate = CtrlDate
		from issv_Control
		where IssNo = @IssNo and CtrlId = 'PrcsId'
	end
	else
	begin
		select @PrcsDate = PrcsDate
		from cmn_ProcessLog
		where IssNo = @IssNo and PrcsId = @PrcsId
	end

	select @Ind = 'I'  -- By Invoice
	select @FromDate = null, @ToDate = null

	select @CCMSDb = VarCharVal
	from issv_Default where IssNo = @IssNo and Deft = 'CCMSDb'

	if exists (select 1 from iacv_InvoiceCycle where PrcsId = @PrcsId)
	begin

		-----------------------------------------------------
		-- Invoice
		-----------------------------------------------------
		select @PrcsName = 'Invoice'
		select @RptName = 'Invoice'

		exec PrintReport @IssNo, @PrcsId, @PrcsName, @RptName, @Ind, @FromDate, @ToDate

		-------------------------------------------------------
		-- Merchant Invoice
		-------------------------------------------------------
		select @PrcsName = 'Merchant Invoice'
		select @RptName = 'MerchInvoice'

		exec PrintReport @IssNo, @PrcsId, @PrcsName, @RptName, @Ind, @FromDate, @ToDate

	end
end
GO
