﻿create or replace view xxokc_srv_contarct_soa_v as
select
--------------------------------------------------------------------
--  name:     XXOKC_SRV_CONTARCT_SOA_V
--  Description:  Any Service Contract line that its status change should be interface to salesforce
--                    except status �Entered� and �Hold�.
--                  This View will be Used by soa
--------------------------------------------------------------------
--  ver   date          name           Desc
--  1.0   03.May.18     Lingaraj       CHG0042873 - Service Contract interface - Oracle 2 SFDC
--  1.1   18.Dec.18     Lingaraj       CHG0042873 - CTASK0039732
--                                     Add 2 fields to Contract Interface (Order , Contract Type)
-- 1.2   15.1.2019    yuval            CHG0044910  modify sf_so_order_id logic 
--------------------------------------------------------------------
        e.event_id
       ,e.status
       ,dtl.sf_account_id
       ,to_char(dtl.external_key) external_key
       ,dtl.sf_asset_id
       ,dtl.sf_product_id service_contract_product
       ,dtl.Status     okc_status
       ,dtl.start_date contract_line_start_date
       ,dtl.end_date   contract_line_end_date
       ,dtl.Oracle_Contract_number contract_number
       ,dtl.Contract_name
       ,decode (dtl.sf_so_order_id,'NOVALUE',null ,dtl.sf_so_order_id) sf_so_order_id --CHG0042873 - CTASK0039732
       ,dtl.contract_type  --CHG0042873 - CTASK0039732
from
     xxssys_events e,
     xxokc_srv_contarct_dtl_v dtl
where e.entity_name  = 'OKC_SERVICE_CONTRACT'
  and e.status       = 'NEW'
  and e.target_name  = 'STRATAFORCE'
  and e.entity_code    = dtl.external_key -- okc_k_lines_b.id
  and dtl.sf_asset_id != 'NOVALUE'
;
