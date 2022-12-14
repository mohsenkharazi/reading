USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[InvoiceControlDetailMaint]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
Copyright	:CarDtrend Systems Sdn. Bhd.
Modular		:CarDtrend Card Management System (CCMS)- Issuing Module

Objective	:Reserved Card Maint
-------------------------------------------------------------------------------
When	   Who		CRN		Description
-------------------------------------------------------------------------------
2005/09/29 Esther			Initial development
*******************************************************************************/
--exec InvoiceControlDetailMaint 1,3,'01','12/2/2005','12/3/2005'
CREATE	procedure [dbo].[InvoiceControlDetailMaint]	
	@Func varchar(10),
	@IssNo uIssNo,
	@OldWeek varchar(2),	
	@CycNo uCycNo,
	@Week char(2),
	@InvoiceDate Datetime,
	@InvoiceDueDate Datetime	
as
begin		
	if @Week is null return 55222 -- Week is a compulsory field
	if @InvoiceDate is null return 55223 -- Invoice Date is a compulsory field
	if @InvoiceDueDate is null return 55224 -- Invoice Due Date is a compulsory field	
	if @InvoiceDate < GETDATE() return 95327 -- System date greater than invoice date
	if @InvoiceDueDate  <  @InvoiceDate return 95328 --Invoice due date greater than invoice date	
	
	if @Func = 'Add'
	begin
		if exists(select 1 from iss_InvoiceDate where IssNo = @IssNo and CycNo = @CycNo and Week = @Week) return 65062 -- Invoice Date already exists
		-----------------
		BEGIN TRANSACTION
		-----------------
		insert into iss_InvoiceDate (IssNo, CycNo, Week, InvoiceDate, DueDate, LastInvoiceDate, LastUpdDate)
		values (@IssNo, @CycNo, @Week, @InvoiceDate, @InvoiceDueDate, null, getdate())
		
		if @@error <> 0
		begin			
			return 70905  -- Failed to insert invoice date
		end	
		------------------
		COMMIT TRANSACTION
		------------------
		return 54081 -- Invoice date has been created successfully
	end
	else if @Func = 'Save'
	begin
		-----------------
		begin transaction
		-----------------		
		begin
			update iss_InvoiceDate
			set	Week = @Week,
				InvoiceDate = @InvoiceDate,
				DueDate = @InvoiceDueDate ,
				LastUpdDate = getdate()
			where IssNo = @IssNo and CycNo = @CycNo and Week = @OldWeek

			if @@error <> 0
			begin
				return 70906	-- Failed to update Invoice Date
			end	
		end	
		------------------
		commit transaction
		------------------
		return 54082	-- Invoice Date has been updated successfully
	end 
end


if exists (select 1 from sysusers where name = 'db_execonly')
begin
	grant exec on InvoiceControlDetailMaint to db_execonly
end
GO
