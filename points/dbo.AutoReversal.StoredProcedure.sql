USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[AutoReversal]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
declare @rc int
Exec @rc = OnlineHostInterface '400',null,'300000','000000000100','254969','155350','0821',null,'021','096','06','70838155128415687D5905201234057382',
null,null,null,'00000002','420000026202710',null,null,null,'001918',null,'0100254959',null,null,null,null
select @rc

	select msg, * from atx_OnlineLog (nolock) where cardno = '70838155128415604' order by ids desc

declare @rc int
Exec @rc = OnlineHostInterface '400',null,'300000','000000080000','254709','154854','0821',null,
'021','096','06','70838155128415604D5905201926510846',null,null,null,'00000005','420000026202710',null,null,null,
'001896',null,'0100254689',null,null,null,null
select @rc
*/

CREATE procedure [dbo].[AutoReversal]
	@Ids bigint,
	@Key varchar(100)
  as
begin
	

	declare @rc int,
			@Mti smallint, @vCard varchar(19), @PrcsCd int, @iLocalTxnAmt bigint,
			@Stan uStan, @LocalTxnTime char(6), @LocalTxnDate char(4), @ExpDate char(4),
			@PaymtMode char(3), @Nii smallint, @POSCondCd int, @Track2 varchar(37),
			@Rrn uRrn, @AppvCd uAppvCd, @RespCd char(2), @TermId uTermId,
			@vBusnLocation uMerchNo, @BusnName varchar(40), @AddData varchar(200),
			@PinBlock char(16), @InvoiceNo int, @POSData varchar(4096), @INFData varchar(50),
			@PrivateData varchar(4096), @LogTxnId uTxnId, @OrigTxnId uTxnId, @HostErrCd char(2)

	select	@Mti = MsgType, @vCard = null, @PrcsCd = PrcsCd, @iLocalTxnAmt = Amt,
			@Stan = SysTraceAudit, @LocalTxnTime = LocalTime, @LocalTxnDate = LocalDate, @ExpDate = CardExpiry,
			@PaymtMode = POSEntry, @Nii = Nii, @POSCondCd = POSEntry, @Track2 = Track2,
			@Rrn = RRN, @AppvCd = AuthResp, @RespCd = null, @TermId = TermId,
			@vBusnLocation = BusnLocation, @BusnName = null, @AddData = null,
			@PinBlock = null, @InvoiceNo = InvoiceNo, @POSData = null, @INFData = Replicate('0', 4 - len(OrigMti)) + cast(OrigMti as varchar(3)) + Replicate('0', 6 - len(OrigStan)) + cast(OrigStan as varchar(6)),
			@PrivateData = null, @LogTxnId = null, @OrigTxnId = null, @HostErrCd = null
	from atx_OnlineLog (nolock)
	where Ids = @Ids

	
	select	@Mti '@Mti', @vCard '@vCard', @PrcsCd '@PrcsCd', @iLocalTxnAmt '@iLocalTxnAmt',
			@Stan '@Stan', @LocalTxnTime '@LocalTxnTime', @LocalTxnDate '@LocalTxnDate', @ExpDate '@ExpDate',
			@PaymtMode '@PaymtMode', @Nii '@Nii', @POSCondCd '@POSCondCd', @Track2 '@Track2',
			@Rrn '@Rrn', @AppvCd '@AppvCd', @RespCd '@RespCd', @TermId '@TermId',
			@vBusnLocation '@vBusnLocation', @BusnName '@BusnName', @AddData '@AddData',
			@PinBlock '@PinBlock', @InvoiceNo '@InvoiceNo', @POSData '@POSData', @INFData '@INFData',
			@PrivateData '@PrivateData', @LogTxnId '@LogTxnId', @OrigTxnId '@OrigTxnId', @HostErrCd '@HostErrCd'
	

	if @Key = '79608380#'
	begin
		exec @rc = OnlineHostInterface	@Mti, @vCard, @PrcsCd, @iLocalTxnAmt, 
									@Stan, @LocalTxnTime, @LocalTxnDate, @ExpDate,
									@PaymtMode, @Nii, @POSCondCd, @Track2,
									@Rrn, @AppvCd, @RespCd, @TermId,
									@vBusnLocation, @BusnName, @AddData,
									@PinBlock, @InvoiceNo, @POSData, @INFData,
									@PrivateData, @LogTxnId, @OrigTxnId, @HostErrCd

		select @rc 'RC'
	end
	else
	begin
		select 'Invalid key' 'RC'
	end
	
end
GO
