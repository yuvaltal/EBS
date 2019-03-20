create or replace view xxinv_product_soa_v as
select
--------------------------------------------------------------------
--  name:     XXINV_PRODUCT_SOA_V
--  Description:     fob list
--                  used by soa
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   9.11.17       yuval tal       CHG0041504 - strataforce  project PRODUCTS Interface initial build
--  1.1   4.Sep.18      Lingaraj        CHG0043701 - Product Interface - Add new fields "End of Service"
--------------------------------------------------------------------
DTL.concatenated_segments,
e.event_id,                   --[API name New SFDC] Event_ID__c
e.status,
--------------------------------------
dtl.inventory_item_id,
dtl.active,                       --[API name New SFDC] IsActive
dtl.product_code,                 --[API name New SFDC] ProductCode and External_Key__c
dtl.product_name,                 --[API name New SFDC] Name
dtl.product_name_jpn,             --[API name New SFDC] Product_Name_Japan__c
dtl.primary_unit_of_measure,      --[API name New SFDC] Unit_of_Measure__c
dtl.volume_uom_code,              --[API name New SFDC] Volume_Unit_of_Measure__c
dtl.weight_uom_code,              --[API name New SFDC] Weight_Unit_of_Measure__c
dtl.unit_weight,                  --[API name New SFDC] Unit_Weight__c
dtl.item_type,                    --[API name New SFDC] Item_Type__c
dtl.customer_order_flag,          --[API name New SFDC] Customer_Ordered__c
dtl.customer_order_enabled_flag,  --[API name New SFDC] Customer_Orders_Enabled__c
dtl.returnable_flag,              --[API name New SFDC] Returnable__c
dtl.unit_volume,                  --[API name New SFDC] Unit_Volume__c
dtl.is_fdm_item,                  --[API name New SFDC] FDM_Item__c
dtl.product_status,               --[API name New SFDC] Status__c
dtl.relatedtosystems,             --[API name New SFDC] RelatedToSystems__c
dtl.relatedtosystems2,            --[API name New SFDC] RelatedToSystems2__c
dtl.relatedtosystems3,            --[API name New SFDC] RelatedToSystems3__c
dtl.relatedtosystems4,            --[API name New SFDC] RelatedToSystems4__c
dtl.relatedtosystems5,            --[API name New SFDC] RelatedToSystems5__c
dtl.relatedtoproductfamilies,     --[API name New SFDC] RelatedToProductFamilies__c
dtl.Billing_Type,                 --[API name New SFDC] Oracle_Billing_Type__c
dtl.sf_substitute_product_id ,     --[API name New SFDC] Substitute_Item__c,
dtl.cpq_feature                   ,-- CPQ_Feature_Mapping__c
dtl.long_description,                -- description
Decode(Upper(Activity_Analysis) ,'SYSTEMS (NET)' ,'Allowed', 'SYSTEMS-USED','Allowed', NULL) SBQQ_ConfigurationType,       --[API name New SFDC] SBQQ__ConfigurationType__c
Decode(Upper(Activity_Analysis) ,'SYSTEMS (NET)' ,'Always', 'SYSTEMS-USED','Always', NULL) SBQQ_ConfigurationEvent,       --[API name New SFDC] SBQQ__ConfigurationEvent__c
decode(dtl.is_bom_valid,'Y','True','Flase') is_bom_valid, --PTO_KIT_Model__c
decode(dtl.is_Visible_in_PB,'Y','True','Flase')is_Visible_in_PB,
decode(dtl.is_Exclude_from_CPQ,'Y','True','Flase')   is_Exclude_from_CPQ,
decode(dtl.is_Internal_use_only,'Y','True','Flase')  is_Internal_use_only,
--Below fields added on 2nd May 2018
decode(dtl.cs_return_to_hq ,'Y','True','Flase')     cs_return_to_hq__c,
decode(dtl.cs_return_defective ,'Y','True','Flase') cs_return_defective__c,
sf_related_product_id                               related_item__c,
sf_superseded_product_id                            Superseded_Item__c,
sf_servicecontract_id                               contract_template__C,
dtl.brand,
dtl.Product_Hierarchy,
dtl.Activity_Analysis,
dtl.End_of_Service_date -- CHG0043701 #04.sep.2018
-------------------------------------------------
from
     xxssys_events e,
     xxinv_product_dtl_v dtl
where e.entity_name = 'PRODUCT'
 and e.status      = 'NEW'
  and e.target_name   = 'STRATAFORCE'
  and e.entity_id = dtl.inventory_item_id
;
