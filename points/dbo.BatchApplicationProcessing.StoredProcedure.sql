USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[BatchApplicationProcessing]    Script Date: 9/6/2021 10:33:55 AM ******/
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
2007/06/01	Humairah			Initial Development
*******************************************************************************/

/*
Declare @RC int
exec BatchApplicationProcessing 1, 3111658, 'N'
select @RC
*/


CREATE procedure [dbo].[BatchApplicationProcessing]
		@IssNo uIssNo,
		@BatchId uBatchId,
		@OperationMode char(1)
--with encryption 
as
begin
	declare	@MaxApplId bigint,
			@MinApplId bigint,
			@cnt int,
			@Devide int,
			@Qty bigint,
			@EMBBatchId int,
			@Err int, @OutPhyFileName varchar(80),
			@CardType uCardType, @CardLogo uCardLogo, @PlasticType uPlasticType, @CardRangeId nVarchar(10),
			@CardExp datetime, @NoAcct int, @rc int, @ApplTrsfSts char(1)

	if @OperationMode in( 'U')
	begin
			-----------------
			Begin Transaction
			-----------------
			
			exec @rc = PDBBatchCardInfoUpdateProcessingU @IssNo,  @BatchId, @OperationMode
	
			
			if @rc <> 0 
			begin
			
					rollback transaction
					return @rc
			end
			else
			begin
					update udi_batch
					set Sts = 'P'
					where BatchId = @BatchId
			end
			
			commit Transaction

			return 0

	end

	if @OperationMode in ('T', 'N' ,'R')
	begin

			-----------------
			Begin Transaction
			-----------------
			exec @rc = PDBBatchCardInfoUpdateProcessing	@IssNo,  @BatchId, @OperationMode
			
		
			if @rc <> 0 
			begin
					rollback transaction
					return @rc
			end
			else
			begin
					update udi_batch
					set Sts = 'P'
					where BatchId = @BatchId
			end

			commit Transaction	
			
			return 0
			
	end

end
GO
