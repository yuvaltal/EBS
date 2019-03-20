CREATE OR REPLACE VIEW XXOKC_SRV_CONTARCT_DTL_V AS
select
--------------------------------------------------------------------
--  name:     XXOKC_SRV_CONTARCT_SOA_V
--  Description:  Any Service Contract line that its status change should be interface to salesforce
--                    except status ¿Entered¿ and Hold.
--                  This View will be Used by soa
--------------------------------------------------------------------
--  ver   date          name           Desc
--  1.0   03.May.18     Lingaraj       CHG0042873 - Service Contract interface - Oracle 2 SFDC
--  1.1   18.Dec.18     Adi Safin      CHG0042873 - CTASK0039732
--                                     Add 2 fields to Contract Interface (Order , Contract Type)
-- 1.2   27/01/2019    YUVAL TAL       INC0145322 -  change logic for  sf_so_order_id
--------------------------------------------------------------------
       h.contract_number Oracle_Contract_number,
       xxssys_oa2sf_util_pkg.get_sf_account_id(hca.account_number) sf_account_id, -- Need to send the SF ID of the account
       hca.account_number,
       hca.account_name,
       to_char(l1.id) External_Key,
       cii.serial_number Asset_SN,
       cii.instance_id Asset_External_Key, -- Need to send the SF ID of the install base
       xxssys_oa2sf_util_pkg.get_sf_asset_id(cii.instance_id) sf_asset_id,
       msib.segment1 Service_Contract_Product, -- Need to send the SF ID of the part
       xxssys_oa2sf_util_pkg.get_sf_product_id(msib.segment1) sf_product_id,
       l1.sts_code ,
       osv.MEANING Status,
       l1.start_date,
       l1.end_date,
       cii.serial_number,
       cii.instance_id,
       msib.segment1,
       msib.description,
       l1.upg_orig_system_ref Contract_Source,
       l1.upg_orig_system_ref_id Order_Line_Id,
       h.id okc_header_id,
       (SELECT ocv.name||' - '||hca.account_name||' - '||cii.serial_number
        FROM   OKS_COVERAGES_V ocv
        WHERE  ocv.id = msib.coverage_schedule_id
       ) Contract_name
       ,(select  decode (xxssys_oa2sf_util_pkg.get_sf_so_header_id(oola.header_id),'NOVALUE',xxssys_oa2sf_util_pkg.get_sf_FSL_so_header_id(oola.header_id),xxssys_oa2sf_util_pkg.get_sf_so_header_id(oola.header_id))
        from oe_order_lines_all oola
        where oola.line_id = l1.upg_orig_system_ref_id
        )  sf_so_order_id--CHG0042873 - CTASK0039732 -- INC0145322
        ,decode(oki2.jtot_object1_code,'OKX_WARRANTY','Warranty','Service Contract') Contract_Type  --CHG0042873 - CTASK0039732
  from okc_k_headers_all_b h,
       okc_k_lines_b       l1,
       okc_k_lines_b       l2,
       okc_k_items         oki1, --IB
       okc_k_items         oki2, --Contract
       csi_item_instances  cii,
       mtl_system_items_b  msib,
       okc_statuses_v osv,
       okc_k_party_roles_b okpr,
       hz_cust_accounts hca
where h.id = l1.dnz_chr_id
   AND oki1.object1_id1 = cii.instance_id
   AND oki1.cle_id = l1.id
   --AND oki1.object1_id1 = cii.instance_id
   AND oki2.cle_id = l2.id
   AND l2.chr_id = h.id
   AND osv.DEFAULT_YN = 'Y'
   AND osv.STE_CODE = l1.sts_code
   AND okpr.chr_id (+) = h.id
   AND okpr.rle_code   = 'CUSTOMER'
   AND hca.party_id    = okpr.object1_id1
   AND hca.status = 'A'
   AND msib.inventory_item_id = oki2.object1_id1
   AND msib.organization_id = 91
   AND l1.sts_code NOT IN ('ENTERED','HOLD')
   AND oki1.jtot_object1_code in ('OKX_CUSTPROD' ,'OKX_WARRANTY')
   and to_char(l1.id)='215964703217230586399455432791611457018'
;
