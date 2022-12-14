USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[MaintAuditSelect]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************************************************
Copyright	:CardTrend Systems Sdn. Bhd.
Modular		:CardTrend Card Management System (CCMS)- Issuing Module

Objective	:View The MaintAudit Data To List

----------------------------------------------------------------------------------------------------
When		Who		CRN		Description
---------------------------------------------------------------------------------------------------
09/09/2004	Alex			Initial Development
2005/05/10	Chew Pei		Added CmpyName1 and CmpyName2	
2009/04/22	Chew Pei		Added iac_Card..Card Type maint audit
*******************************************************************************/
	
CREATE procedure [dbo].[MaintAuditSelect]
	@TableName varchar(50),
	@Key varchar(30),
	@Field	nvarchar(30),
	@FromDate datetime,
	@ToDate datetime
	
	
  as
begin

	declare @RefType nvarchar(20),
		@Case int

	--------------------------------------------------------------------------------------------
	--Checking The TableName And FieldName To assign The Case
	--------------------------------------------------------------------------------------------

	if @TableName ='iac_Account'  and @Field = 'AgeingInd'
	begin
		if @Key is Null
		begin
			select a.AuditId, a.Oldval , c.Descp 'OldDescp', a.NewVal , b.Descp as 'NewDescp' ,a.Action, a.UserId , a.Creationdate 
			from iss_MaintAudit a, iss_PlasticTypeDelinquency b, iss_PlasticTypeDelinquency c, iac_Account d
			where a.NewVal = convert(varchar(80) ,b.AgeingInd ) and a.OldVal = convert(varchar(80), c.AgeingInd ) and  a.TableName=@TableName and a.Field ='AgeingInd' and  a.PriKey = d.AcctNo  and  b.PlasticType = d.PlasticType and c.PlasticType = d.PlasticType and  (a.CreationDate between @FromDate and @ToDate)
			order by a.AuditId
		end
		else
		begin
			select a.AuditId, a.Prikey, a.Oldval , c.Descp 'OldDescp' , a.NewVal , b.Descp as 'NewDescp' ,a.Action, a.UserId , a.Creationdate 
			from iss_MaintAudit a, iss_PlasticTypeDelinquency b, iss_PlasticTypeDelinquency c, iac_Account d
			where a.NewVal = convert(varchar(80) ,b.AgeingInd ) and a.OldVal = convert(varchar(80), c.AgeingInd ) and  a.TableName='iac_Account' and a.Field ='AgeingInd' and a.PriKey= @Key and   a.PriKey = d.AcctNo  and  b.PlasticType = d.PlasticType and c.PlasticType = d.PlasticType and  (a.CreationDate between @FromDate and @ToDate)
			order by a.AuditId
		end
	end

	if @TableName ='iac_Account'  and ( @Field = 'CmpyRegsName1' or @Field = 'CmpyRegsName2' or @Field = 'CmpyName1' or @Field = 'CmpyName2' or @Field = 'RcptTel' or @Field = 'AutoReinstate') 
		set @Case = 2			
	
	if @TableName ='iac_Account'  and @Field = 'CycNo'
	begin
		if @Key is null
		begin
			select a.AuditId, a.Oldval , c.Descp 'OldDescp' ,a.NewVal , b.Descp as 'NewDescp' ,a.Action, a.UserId , a.Creationdate 
			from iss_MaintAudit a, iss_CycleControl b, iss_CycleControl c, iac_Account d
			where  a.TableName= @TableName and a.Field ='CycNo' and a.NewVal = b.CycNO and a.OldVal = c.CycNo and a.Prikey = d.AcctNo and  (a.CreationDate between @FromDate and @ToDate)
			order by a.AuditId
		end
		else
		begin
			select a.AuditId, a.Oldval , c.Descp 'OldDescp' ,a.NewVal , b.Descp as 'NewDescp' ,a.Action, a.UserId , a.Creationdate 
			from iss_MaintAudit a, iss_CycleControl b, iss_CycleControl c, iac_Account d
			where  a.TableName= @TableName and a.Field ='CycNo' and a.NewVal = b.CycNO and a.OldVal = c.CycNo and a.Prikey = @Key and a.Prikey = d.AcctNo and  (a.CreationDate between @FromDate and @ToDate)
			order by a.AuditId
		end
	end
	
	if @TableName ='iac_Account'  and @Field = 'Sts'
	begin
		set @RefType ='AcctSts'
		set @Case =1
	end	
	
	if @TableName ='iac_Account'  and @Field = 'SendingCd'
	begin
		if @Key is null
		begin	
			select a.AuditId, a.Oldval, b.Descp 'OldDescp' , a.NewVal , b.Descp as 'NewDescp' ,a.Action, a.UserId , a.Creationdate  
			from iss_MaintAudit a
			join iss_RefLib b on b.refcd=a.NewVal  and b.RefType in ('HandDelivery','MailDelivery')
			where a.Tablename ='iac_Account' and a.field = 'SendingCd' and  (a.CreationDate between @FromDate and @ToDate)
		end 
		else
		begin
			select a.AuditId, a.Oldval , b.Descp 'OldDescp' ,a.NewVal , b.Descp as 'NewDescp' ,a.Action, a.UserId , a.Creationdate  
			from iss_MaintAudit a
			join iss_RefLib b on b.refcd=a.NewVal  and b.RefType in ('HandDelivery','MailDelivery')
			where a.Tablename ='iac_Account' and a.field = 'SendingCd' and  (a.CreationDate between @FromDate and @ToDate)
		end
	end	

	if @TableName = 'iac_Account'  and @Field = 'SrcRefNo'
		set @Case =2

	if @TableName = 'iac_AccountFininfo' and @Field = 'LitLimit'
		set @Case =2

	if @TableName  = 'iac_AccountFininfo' and @Field = 'AllowanceFactor'
		set @Case = 2

	if @TableName  ='iac_Card'  --and( @Field = 'CardNo' or @Field = 'EmbName' or @Field = 'ExpiryDate' or @Field = 'PinBlock' or @Field ='PinInd')
		set @Case =2

	/*if @TableName = 'iac_Card' and @Field = 'Sts'
	begin
		set @RefType ='CardSts'
		set @Case = 1
	end*/

	if @TableName = 'iac_Entity'  --and @Field ='FamilyName'
		set @Case =2

	if @TableName = 'iac_AccountVelocityLimit' and @Field = 'VelocityCnt'
		set @Case = 2

	if @TableName = 'iac_AccountVelocityLimit' and @Field = 'VelocityLimit'
		set @Case = 2
	
	if @TableName = 'iap_Application' and @Field = 'ApplRef'
		set @Case = 2

	if @TableName = 'iap_Application' and @Field = 'ApplSts'
	begin
		set @RefType ='ApplSts'
		set @Case = 1
	end

	if @TableName = 'iap_Application' and ( @Field = 'Cmpyname1' or @Field = 'SrcCd' or @Field = 'RcptTel' or @Field = 'RcptName' or @Field = 'CmpyRegsName2' or @Field = 'Cmpyname2' or @Field = 'CmpyRegsName1')
		set @Case = 2

	if @TableName = 'iac_CardVelocityLimit' and @Field = 'VelocityCnt'
		set @Case =2

	if @TableName ='aac_Account' --and @Field ='TaxId'
		set @Case = 2

	if @TableName = 'aac_BusnLocation' and @Field = 'BankAcctType'
	begin 
		set @RefType = 'BankAcctType'

		if @Key is null
		begin
			select a.AuditId, a.OldVal, c.Descp 'OldDescp' , a.NewVal, b.Descp as 'NewDescp' , a.Action, a.UserId , a.Creationdate 
			from iss_MaintAudit a, iss_RefLib b, iss_RefLib c
			where a.NewVal = b.RefNo and a.OldVal = c.RefNo and a.TableName = @TableName and a.Field = @Field and b.RefType=@RefType and c.RefType=@RefType  and  (a.CreationDate between @FromDate and @ToDate)
			order by a.AuditId
		end
		else
		begin
			select a.AuditId,  a.OldVal, c.Descp 'OldDescp' , a.NewVal, b.Descp as 'NewDescp' ,a.Action, a.UserId , a.Creationdate 
			from iss_MaintAudit a, iss_RefLib b, iss_RefLib c
			where a.NewVal = b.RefNo and a.OldVal = c.RefNo and a.TableName = @TableName and a.Field = @Field and Prikey = @Key and b.RefType=@RefType and c.RefType=@RefType and  (a.CreationDate between @FromDate and @ToDate)
			order by a.AuditId
		end
	end

	if @TableName = 'aac_BusnLocation' and @Field = 'Sts'
	begin
		set @RefType = 'MerchAcctSts'
		set @Case = 1
	end

	if @TableName = 'aac_BusnLocation' and @Field = 'Sic'
	begin
		set @RefType = 'MerchCategory'
		set @Case = 1
	end


	if @TableName = 'iac_Card' and @Field = 'CardType'
	begin
		if @Key is null
		begin
			select a.AuditId, a.Oldval, c.Descp 'OldDescp', a.NewVal, b.Descp as 'NewDescp', a.Action, a.UserId, a.Creationdate 
			from iss_MaintAudit a
			join iss_CardType b on b.CardType = a.OldVal
			join iss_CardType c on c.CardType = a.NewVal
			join iac_Card d on d.CardNo = a.PriKey
			where a.TableName= @TableName and a.Field = 'CardType' and (a.CreationDate between @FromDate and @ToDate)
			order by a.AuditId
		end
		else
		begin
			select a.AuditId, a.Oldval, c.Descp 'OldDescp', a.NewVal, b.Descp as 'NewDescp', a.Action, a.UserId, a.Creationdate 
			from iss_MaintAudit a
			join iss_CardType b on b.CardType = a.OldVal
			join iss_CardType c on c.CardType = a.NewVal
			join iac_Card d on d.CardNo = a.PriKey
			where a.TableName = @TableName and a.Field = 'CardType' and a.PriKey = @Key and (a.CreationDate between @FromDate and @ToDate)
			order by a.AuditId
		end
	end

	if @TableName = 'aac_BusnLocation'  and ( @Field = 'CoRegName' or @Field ='PayeeName' or @Field = 'TaxId') 
		set @Case =2

	if @TableName ='aac_Entity' 
		set @Case =2

	if @TableName ='aac_CompanyProfile' 
		set @Case =2

	if @TableName ='aac_BusnLocationFinInfo' 
		set @Case =2

	if @TableName ='aac_Event' and @Field='Sts'
	Begin 
		set @RefTYpe ='EventSts'
		set @Case =1
	end

	if @TableName = 'acq_Acquirer'
		set @Case =2

	if @TableName = 'acq_CardRangeAcceptance'
		set @Case = 2
	
	if @TableName = 'acq_TxnCodeMapping'
		set @Case = 2

	if @TableName ='acq_MessageHandle'
		set @Case = 2
	
	if @TableName = 'atm_DeviceType' and ( @Field='Descp' or @Field ='TotalUnit' or @Field='PurchDate' or @Field ='ManufacturerDate')
		set @Case = 2

	if @TableName = 'atm_DeviceType' and @Field ='DeviceType'
	begin
		set @RefType = 'TermType'
		set @Case = 1 
	end
	
	if @TableName = 'atm_TerminalInventory'  
		set @Case = 2
	
	
	if @TableName ='atx_BillingPlan'
		set @Case = 2
	
	if @TableName ='atx_Plan'
		set @Case = 2	

	if @TableName = 'atx_TxnCode'
		set @Case = 2


	if @TableName = 'cmn_MerchantType' and ( @Field ='Descp' or @Field = 'CategoryCd')
		set @Case = 2
	

	if @TableName = 'cmn_PublicHoliday' 
		set @Case =2

	

	if @TableName = 'iaa_BankAccount'
		set @Case = 2

	if @TableName = 'iaa_BankAccount' and @Field ='AcctType'
	begin
		set @Case = 1	
		set @RefType ='BankAcctType'
	end

	if @TableName = 'iaa_CostCentre'
		set @Case = 2

	if  @TableName = 'iaa_CostCentreVelocityLimit'
		set @Case = 2

	if  @TableName = 'iaa_Guarantor'
		set @Case = 2

	if @TableName = 'iaa_ProductUtilization'
		set @Case = 2
 
	if @TableName = 'iaa_ShareHolder'
		set @Case = 2

	if @TableName = 'iac_AccountAcceptance'
		set @Case = 2

	if @TableName = 'iac_CardAcceptance'
		set @Case = 2

	if @TableName = 'iac_CardFinInfo'
		set @Case = 2

	if @TableName = 'iac_Event'
		set @Case = 2

	if @TableName = 'iac_TempCreditLimit'
		set @Case = 2

	if @TableName = 'iac_Vehicle'
		set @Case = 2

	if @TableName = 'iap_Applicant' and ( @Field ='VehRegsNo' or @Field = 'VehRegsNoPrefix' or @Field = 'Remarks' or @Field ='Manufacturer' or @Field ='RoadTaxPeriod' or @Field = 'FamilyName' )
		set @Case = 2

	if @TableName = 'iap_Applicant' and @Field ='AppcSts'
	Begin
		set @RefType ='AppcSts'
		set @Case = 1
	end

	if @TableName = 'iss_Address'  and ( @Field = 'Street1' or @Field = 'Street2' or @Field = 'Street3' or @Field='MailingInd')
		set @Case = 2

	if @TableName = 'iss_Address'  and @Field = 'RefCd'
	begin
		set @RefType ='Address'
		set @Case = 1
	end

	if @TableName = 'iss_CardLogo' and @Field ='Descp'
		set @Case = 2

	
	if @TableName = 'iss_CardRange' 
		set @Case = 2
	
	if @TableName = 'iss_CardType' and @Field = 'VehInd'
		set @Case = 2	


	if @TableName = 'iss_CardType' and @Field = 'CardCategory'
	Begin
		set @RefType = 'CardCategory'
		set @Case = 1	
	end

	if @TableName = 'iss_Contact' and @Field = 'RefCd'
	begin
		set @RefType ='Contact'
		set @Case = 1
	end

	
	if @TableName = 'iss_Contact' and ( @Field = 'ContactName' or @Field= 'EmailAddr' or @Field = 'ContactNo' )
		set @Case = 2
	
	if @TableName = 'iss_Currency'
		set @Case =2

	if @TableName = 'iss_CycleControl'
		set @Case = 2

	if @TableName = 'iss_CycleDate'
		set @Case = 2

	if @TableName = 'iss_FeeCode'
		set @Case = 2

	if @TableName = 'iss_Issuer'
		set @Case = 2

	if @TableName = 'iss_PlasticType' 
		set @Case = 2

	if @TableName = 'iss_PlasticTypeCycle' 
		set @Case = 2
	

	if @TableName = 'iss_PlasticTypeDelinquency' 
		set @Case = 2

	
	if @TableName = 'iss_PlasticTypeInterest' 
		set @Case = 2

	if @TableName = 'iss_Product' 
		set @Case = 2

	
	if @TableName = 'iss_ProductGroup' 
		set @Case = 2
	
	if @TableName = 'iss_ProductRebate' 
		set @Case = 2


	if @TableName = 'iss_State' 
		set @Case = 2

	if @TableName = 'iss_StatementMessage' 
		set @Case = 2

	if @TableName ='iss_User'
		set @Case = 2

	if @TableName ='iss_VehicleModel'
		set @Case = 2

	if @TableName ='itx_BillingPlan'
		set @Case = 2

	if @TableName ='itx_Plan'
		set @Case = 2

	if @TableName ='itx_TxnCategory'
		set @Case = 2	

	if @TableName ='itx_TxnCode'
		set @Case = 2

	----------------------------------------------------------------------
	-- Retrieve From DataBase Follow The Case
	----------------------------------------------------------------------	
	if  @Case = 1 
	begin
		if @Key is NULL
		begin
			select a.AuditId, a.OldVal, c.Descp 'OldDescp', a.NewVal, b.Descp as 'NewDescp' , a.Action, a.UserId , a.Creationdate 
			from iss_MaintAudit a, iss_RefLib b, iss_RefLib c
			where a.NewVal = b.RefCd and a.OldVal = c.RefCd and a.TableName = @TableName and a.Field = @Field and b.RefType=@RefType and c.RefType=@RefType
			order by a.AuditId
		end
		else
		begin
			select a.AuditId,  a.OldVal, c.Descp 'OldDescp', a.NewVal, b.Descp as 'NewDescp' ,a.Action, a.UserId , a.Creationdate 
			from iss_MaintAudit a, iss_RefLib b, iss_RefLib c
			where a.NewVal = b.RefCd and a.OldVal = c.RefCd and a.TableName = @TableName and a.PriKey=@Key and a.Field = @Field and b.RefType=@RefType and c.RefType=@RefType
			order by a.AuditId
		end
	end
	if  @Case = 2
	begin
		if @Key is NULL
		begin
			select AuditId, OldVal, NewVal, Action, UserId, CreationDate from iss_MaintAudit where TableName = @TableName and Field = @Field and  (CreationDate between @FromDate and @ToDate)
			order by AuditId
		end
		else
		begin
			select AuditId, OldVal, NewVal, Action, UserId, CreationDate from iss_MaintAudit where TableName = @TableName and Field = @Field and PriKey = @Key and  (CreationDate between @FromDate and @ToDate)
			order by AuditId
		end
	end 

end
GO
