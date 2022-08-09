USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AuditFileEntityExtraction]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/******************************************************************************
Copyright	: Cardtrend System Sdn Bhd
Modular		: Cardtrend Card Management System (CCMS)- Issuing Module

Objective	: sp_cmdshell output embossing file.

SP Level	: Primary
-------------------------------------------------------------------------------
When		Who		CRN	   Description
-------------------------------------------------------------------------------
2011/12/12	Barnett			   Initial development.
*******************************************************************************/
/*

update iac_plasticCard set Sts = 'E' where Batchid = 166


declare @rc varchar(200), @rt int, @cnt int
SET @Cnt = 1

while @Cnt <=1
begin

	exec @rt = AuditFileEntityExtraction 1,null, @rc

	select @Cnt = @Cnt + 1
--	select @rt, @rc

end



165
166

 

exec  AuditFileEntityExtraction 1, 3031488, NULL
exec  AuditFileEntityExtraction 1, 3031656, NULL
exec  AuditFileEntityExtraction 1, 3031669, NULL
exec  AuditFileEntityExtraction 1, 3031716, NULL
exec  AuditFileEntityExtraction 1, 3031717, NULL
exec  AuditFileEntityExtraction 1, 3031718, NULL
exec  AuditFileEntityExtraction 1, 3031719, NULL
exec  AuditFileEntityExtraction 1, 3031720, NULL
exec  AuditFileEntityExtraction 1, 3031721, NULL
exec  AuditFileEntityExtraction 1, 3031722, NULL
exec  AuditFileEntityExtraction 1, 3031723, NULL
exec  AuditFileEntityExtraction 1, 3031724, NULL
exec  AuditFileEntityExtraction 1, 3031725, NULL
exec  AuditFileEntityExtraction 1, 3031726, NULL
exec  AuditFileEntityExtraction 1, 3031727, NULL
exec  AuditFileEntityExtraction 1, 3031728, NULL
exec  AuditFileEntityExtraction 1, 3031729, NULL
exec  AuditFileEntityExtraction 1, 3031732, NULL
exec  AuditFileEntityExtraction 1, 3031733, NULL
exec  AuditFileEntityExtraction 1, 3031734, NULL
exec  AuditFileEntityExtraction 1, 3031735, NULL
exec  AuditFileEntityExtraction 1, 3031737, NULL
exec  AuditFileEntityExtraction 1, 3031738, NULL
exec  AuditFileEntityExtraction 1, 3031739, NULL
exec  AuditFileEntityExtraction 1, 3031740, NULL
exec  AuditFileEntityExtraction 1, 3031741, NULL
exec  AuditFileEntityExtraction 1, 3031742, NULL
exec  AuditFileEntityExtraction 1, 3031743, NULL
exec  AuditFileEntityExtraction 1, 3031744, NULL
exec  AuditFileEntityExtraction 1, 3031817, NULL
exec  AuditFileEntityExtraction 1, 3031828, NULL
exec  AuditFileEntityExtraction 1, 3031829, NULL
exec  AuditFileEntityExtraction 1, 3031830, NULL
exec  AuditFileEntityExtraction 1, 3031831, NULL
exec  AuditFileEntityExtraction 1, 3031834, NULL



select * from udi_Batch where srcname = 'audit' and FileName = 'ENTITY'
 

	exec  AuditFileEntityExtraction 1, 3031716, null
	exec  AuditFileEntityExtraction 1, 3031724, null
	exec  AuditFileEntityExtraction 1, 3031729, null






*/
CREATE procedure [dbo].[AuditFileEntityExtraction]
	@IssNo uIssNo,
	@BatchId int, 
	@Out varchar(200) output

  as
begin
	declare @TSql varchar(Max), @Path varchar(50), @Sts varchar(2),
			@Min bigint, @PrevSeqNo bigint, @Plastic varchar(30), @PrcsDate varchar(10),
			@OperationMode char(10), @FileSeq int, @FileName varchar(50), @FileExt varchar(10),
			@PlasticType uPlasticType, @CardPlan varchar(10), @RecCnt Bigint, @Max bigint
			
	declare @CreateTable varchar(300), @Header varchar(200), @MySpecialTempTable varchar(100),
			@Detail varchar(MAX), @Trailer varchar(100), @Command varchar(500), @Unicode int, @RESULT int,
			@AuditFileEntityAuditId varchar(20), @MaxAuditId varchar(20), @PrcsId uPrcsid, @RerunFlag tinyint
	

	set nocount on
	set dateformat ymd

	truncate table temp_AuditFile

	select 	@Unicode=0, @MySpecialTempTable ='Demo_lms..temp_AuditFile'

			
	select @PrcsId = CtrlNo, @PrcsDate = convert(varchar(10), CtrlDate, 112)
	from iss_control 
	where Ctrlid = 'PrcsId'

	select @RecCnt = 0
	select @RerunFlag =0

	select @Path = VarcharVal
	from iss_Default 
	where Deft = 'DeftAuditFilePath'

	if @Path is null 
		select @Path = 'D:\' 

	select @FileExt = VarcharVal
	from iss_Default 
	where Deft = 'DeftAuditFileExt'

	if @FileExt is null
		select @FileExt = '.txt'

	-----------------
	Begin Transaction
	-----------------


	if @BatchId is null 
	begin
				exec @BatchId = NextRunNo @IssNo, 'UDIBatchId'
				
				---- Contruct file name
				select	@FileSeq = isnull(FileSeq, 0)+ 1, 
						@AuditFileEntityAuditId = isnull(RefNo2,'0')
				from udi_Batch (nolock) 
				where batchId = (select	top 1 Batchid from udi_Batch (nolock) where BatchId < @BatchId and SrcName ='AUDIT' and Filename = 'ENTITY' order by batchid desc)

				select @MaxAuditId = Max(AuditId) from iss_MaintAudit (nolock)
				

	end
	else
	begin  
				-- Re-Generate the audit file
				select	@FileSeq = FileSeq,
						@AuditFileEntityAuditId = RefNo1,
						@MaxAuditId = RefNo2,
						@PrcsDate = convert(varchar(10), PrcsDate,112),
						@RerunFlag =1
				from udi_Batch (nolock) 
				where batchId = @BatchId
	end
	


	select @FileName = 'AuditFile_Entity_' + @PrcsDate + '_' + dbo.PadLeft('0', '5', cast(@FileSeq as varchar(5)))

	select @Out = @Path + @FileName + @FileExt


		-- Create Header Record
		select @TSql =	'H' +	-- Header (1)
						dbo.PadRight(' ', 8, 'HOST') + -- SourceName
						dbo.PadRight(' ', 20, 'AUDITLOG1') + -- FileType
						dbo.PadLeft(0, 12, isnull(@FileSeq, 1)) + -- File Sequence
						dbo.PadRight(' ', 8, 'Out') + -- Destination Name
						@PrcsDate -- File Date
						

		select @Header = 'insert '+ @MySpecialTempTable+' (SeqNo, String)'+ ' select 1,''' + @TSql +''''
--		select @Header
		exec (@Header)

		if @@error <> 0 return 1

		insert temp_AuditFile (SeqNo, String) 
		select row_number() OVER (order by a1.String) + 1, 'D' + dbo.PadLeft(0, 8, convert(varchar(8), row_number() OVER (order by a1.String))) + String    
		from ( 
		select  dbo.PadRight(' ', 30, Case when a.TableName = 'iac_Entity' then 'ENTITY'
											when a.TableName = 'iss_Contact' then 'CONTACT'        
											when a.TableName = 'iss_Address' then 'ADDRESS'     
									 end) + 
				dbo.PadRight(' ' , 30, a.Field)  +
				dbo.PadRight(' ' , 15, b.AcctNo) +
				dbo.PadRight(' ' , 19, a.Prikey) + 
				[Action] + 
				dbo.PadRight(' ' , 100, rtrim(a.OldVal)) +
				dbo.PadRight(' ' , 100, rtrim(a.NewVal)) +
				dbo.PadRight(' ' , 8, a.UserId) + 
				substring( convert(varchar(8), a.CreationDate, 112), 1, 8) +
				space(1) +
				substring( convert(varchar(8), a.CreationDate, 114), 1, 8) as String       
		from iss_MaintAudit a (nolock)      
		join iac_card b (nolock) on b.CardNo = a.Prikey      
		where a.TableName in ('Iss_Contact') and a.AuditId > @AuditFileEntityAuditId and a.AuditId <= @MaxAuditId         
		union       
		select  dbo.PadRight(' ', 30, Case  when a.TableName = 'iac_Entity' then 'ENTITY'
									        when a.TableName = 'iss_Contact' then 'CONTACT'
											when a.TableName = 'iss_Address' then 'ADDRESS'
								      end) +
				dbo.PadRight(' ' , 30, a.Field) +
				dbo.PadRight(' ' , 15, b.AcctNo) +
				dbo.PadRight(' ' , 19, a.Prikey)  +
				[Action] + 
				dbo.PadRight(' ' , 100, rtrim(a.OldVal)) +
				dbo.PadRight(' ' , 100, rtrim(a.NewVal)) +
				dbo.PadRight(' ' , 8, a.UserId) +
				substring( convert(varchar(8), a.CreationDate, 112), 1, 8) +
				space(1) +
				substring( convert(varchar(8), a.CreationDate, 114), 1, 8) as String
				from iss_MaintAudit a (nolock)      
				join iac_Entity b1 (nolock) on b1.EntityId = a.Prikey
				join iac_Account b (nolock) on b.EntityId = b1.EntityId
				join iac_card c (nolock) on c.AcctNo = b.AcctNo
				where a.TableName in ('iac_Entity' , 'iss_Address') and a.AuditId >@AuditFileEntityAuditId and a.AuditId <= @MaxAuditId and len(a.Prikey) < 11
		)a1


	
		select @RecCnt = @@rowcount
				

		-- Create Detail Record
		select @TSql =	'T' +	-- Header (1)
						dbo.PadLeft('0', 10, cast(@RecCnt+1 as varchar(10))) -- FileName (20)

		select @Trailer = 'insert '+ @MySpecialTempTable+' (SeqNo, String)'+ 'select ''' + convert(varchar(20), @RecCnt+2 )+ ''',''' + @TSql+ ''''
		--select @Trailer
		exec (@Trailer)
		 
		if @@error <> 0 return 1

		-- Create Batch record first before Extraction.
		if @RerunFlag = 0
		begin

				insert udi_Batch(IssNo, BatchId, PhyFileName,SrcName,FileName,FileSeq,DestName,FileDate,LoadedRec,
							RecCnt,PrcsRec,Direction,PrcsId,PrcsDate, RefNo1,RefNo2, Sts)
				select @IssNo, @BatchId, @Out, 'AUDIT', 'ENTITY', @FileSeq, 'HOST',getdate(), 0,
							@RecCnt, @RecCnt, 'E', @PrcsId, cast(@PrcsDate as datetime), cast(@AuditFileEntityAuditId as nvarchar(30)), cast(@MaxAuditId as nvarchar(30)), 'P' 

				if @@error <> 0
				begin
						Rollback Transaction
						return 99
				end
		end
		else
		begin
				update udi_batch 
				set RecCnt = @RecCnt,
					PrcsRec = @RecCnt
				where BatchId = @BatchId

				if @@error <> 0
				begin
						Rollback Transaction
						return 99
				end
		end

		------------------
		Commit Transaction
		------------------

		SELECT  @Command = 'bcp "select String from '
			  + @MySpecialTempTable + ' order by SeqNo'
			  + '" queryout '
			  + @Out + ' '
			 + CASE WHEN @Unicode=0 THEN '-c' ELSE '-w' END
			  + ' -T -S' + @@servername
	 
		--select @Command

		EXECUTE @RESULT= MASTER..xp_cmdshell @command, NO_OUTPUT
		
	

		return 0
end
GO
