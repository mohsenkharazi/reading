USE [Demo_lms]
GO
/****** Object:  StoredProcedure [dbo].[GetQuickSearch]    Script Date: 9/6/2021 10:33:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



  
  
  
    
/*****************************************************************************************************************    
    
Copyright : CardTrend Systems Sdn. Bhd.    
Modular  : CardTrend Card Management System (CCMS)- Issuing Module    
    
Objective : Search Object and return to the front-end program.    
    
-------------------------------------------------------------------------------    
When    Who  CRN    Desc    
-------------------------------------------------------------------------------    
2001/11/12 Jacky     Initial development    
2009/04/03 Barnett     Add Rowcoutn return to determinde the record count    
******************************************************************************************************************/    
--exec [GetQuickSearch] 1,'1150',NULL
CREATE procedure [dbo].[GetQuickSearch] 
--DEclare
 @IssNo uIssNo ,    
 @Val nvarchar(40),  
 @Obj varchar(20)

AS BEGIN   
  
  IF len(@val) >= 4 AND @Val is NOT NULL
  BEGIN
	  IF (@Obj is null)  /*search all*/  
	  BEGIN    
		SELECT Category,LinkNo,src,
		AcctNo AS AccountNo
		, [Card Number], EntityId,Name As CardholderName,
		[NRIC Number],PassportNo,r.Descp AS [CardStatus]
		,MerchantNo AS 'Business Location No',[Merchant Name] AS BusinessName,MerchAcctNo As MerchantAccountNo ,SiteId As Station,Payee,[Merchant Company Name]
		,rr.Descp AS [Station Status]
		,CASE WHEN Category IN ('CUSTOMER') THEN CONCAT([Card Number],' | ',[Name],' | ',ISNULL(PassportNo,[NRIC Number]),' | ', r.Descp) 
		      WHEN Category IN ('Merchant') THEN CONCAT([MerchantNo],' | ',[Merchant Name],' | ',[Merchant Company Name],' | '+rr.Descp) END concatString

		FROM
			(select 
							CASE WHEN a.SRC in ('BusnLoc') then 'Merchant' 
								 WHEN a.SRC in ('Card') then 'Customer' END as Category
							,a.Src		
						    , e.Descp objDesc
							,b.val
							,b.LinkNo
							,a.Obj
						from iss_Object a (nolock), iss_Object b (nolock), iss_RefLib c (nolock), iss_Default d (nolock), iss_RefLib e (nolock), iss_RefLib f (nolock)    
						where a.IssNo in (@IssNo) and a.Val like '%'+@Val+'%'  
						and b.IssNo = a.IssNo and b.Src = a.Src and b.LinkNo = a.LinkNo-- and b.obj <> a.obj    
						and c.IssNo = @IssNo and c.RefType = 'Object' and c.RefCd = a.Obj    
						and d.IssNo = @IssNo and d.Deft = 'ObjSrcName'    
						and e.IssNo = @IssNo and e.RefType = 'Object' and e.RefCd = b.Obj    
						and f.IssNo = @IssNo and f.RefType = 'ObjectSrc' and f.RefCd = a.Src
						
						--order by a.Val, a.Obj, a.Src, a.LinkNo, b.Obj  
						)AS SourceTable
						pivot
			(
			  max(val)
			  for objDesc in (AcctNo, [Card Number], EntityId, Name, [NRIC Number],PassportNo,[Merchant Name],MerchAcctNo,MerchantNo,SiteId,payee,[Card Status],[Merchant Company Name],[station status])
			) pvt
			
			LEFT JOIN iss_RefLib r ON r.IssNo = @IssNo AND r.RefType = 'cardsts' AND r.RefCd = pvt.[Card Status]
			LEFT JOIN iss_RefLib rr ON rr.IssNo = @IssNo AND rr.RefType = 'MerchAcctSts' AND rr.RefCd= pvt.[Station Status]
			where category IS NOT NULL
	  end    
	  ELSE /* OBJ Type selected*/   
		  BEGIN    
	
		SELECT Category,LinkNo,src,
		AcctNo AS AccountNo
		, [Card Number], EntityId,Name As CardholderName,
		[NRIC Number],PassportNo,r.Descp AS [CardStatus]
		,MerchantNo AS 'Business Location No',[Merchant Name] AS BusinessName,MerchAcctNo As MerchantAccountNo ,SiteId As Station,Payee,[Merchant Company Name]
		,rr.Descp AS [Station Status]
		,CASE WHEN Category IN ('CUSTOMER') THEN CONCAT([Card Number],' | ',[Name],' | ',ISNULL(PassportNo,[NRIC Number]),' | ', r.Descp) 
		      WHEN Category IN ('Merchant') THEN CONCAT([MerchantNo],' | ',[Merchant Name],' | ',[Merchant Company Name],' | '+rr.Descp) END concatString
		FROM
					(select 
									CASE WHEN a.SRC in ('Merchant','BusnLoc') then 'Merchant' 
										 WHEN a.SRC in ('Card') then 'Customer' ELSE a.SRC END as Category
									,a.Src		
									--,a.Val+' ('+c.Descp+')' AS objValwitDesc
									--, d.VarcharVal+'- '+f.Descp+' ('+a.LinkNo+')' AS SrcwithLink
									--, e.Descp+' - '+b.Val 
									, e.Descp objDesc
									,b.val
									,b.LinkNo
								from iss_Object a (nolock), iss_Object b (nolock), iss_RefLib c (nolock), iss_Default d (nolock), iss_RefLib e (nolock), iss_RefLib f (nolock)    
								where a.IssNo in (@IssNo) and a.Val like '%'+@Val+'%'  and a.Obj = @Obj 
								and b.IssNo = a.IssNo and b.Src = a.Src and b.LinkNo = a.LinkNo-- and b.obj <> a.obj    
								and c.IssNo = @IssNo and c.RefType = 'Object' and c.RefCd = a.Obj    
								and d.IssNo = @IssNo and d.Deft = 'ObjSrcName'    
								and e.IssNo = @IssNo and e.RefType = 'Object' and e.RefCd = b.Obj    
								and f.IssNo = @IssNo and f.RefType = 'ObjectSrc' and f.RefCd = a.Src
								
								--order by a.Val, a.Obj, a.Src, a.LinkNo, b.Obj  
								)AS SourceTable
								pivot
								(
								  max(val)
									for objDesc in (AcctNo, [Card Number], EntityId, Name, [NRIC Number],PassportNo,[Merchant Name],MerchAcctNo,MerchantNo,SiteId,payee,[Card Status],[Merchant Company Name],[station status])
								) pvt
								   LEFT JOIN iss_RefLib r ON r.IssNo = @IssNo AND r.RefType = 'cardsts' AND r.RefCd = pvt.[Card Status]
								   LEFT JOIN iss_RefLib rr ON rr.IssNo = @IssNo AND rr.RefType = 'MerchAcctSts' AND rr.RefCd= pvt.[Station Status]
								   WHERE category IS NOT NULL
		  END    
	  return @@rowcount    
	END 
  ELSE 
    RETURN 95729 /*Atleast 4 characters require to search*/  
END
GO
