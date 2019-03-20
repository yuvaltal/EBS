create or replace view xxcsi_asset_soa_v as
with asset as (
select all
-----------------------------------------------------------------------------------------------
-- Ver     When         Who           Description
-- ------  -----------  -----------  ----------------------------------------------------------
-- 1.0     02/03/2018   Roman.W      Init Version
--                                   CHG0042619 - Install base interface from Oracle to salesforce
-- 1.1     24/07/2018   Lingaraj     CTASK0037633  - Adittional Fields to Strataforce
-- 1.2     6.Sep.2018   Lingaraj     CHG0043859 - Install base interface changes from Oracle to salesforce
-- 1.2     6.Sep.2018   Lingaraj     CHG0043859-CTASK0038761 - Install base interface changes from Oracle to salesforce
--                                   Instead of "OR" use "union all" , To improve performance.
-----------------------------------------------------------------------------------------------
       xe.event_id,
       xe.status event_status,
       XE.ATTRIBUTE1 event_name ,
       xadv.sf_account_id,                                                               -- 1
       xadv.instance_id,                                                                 -- 2
       xadv.serial_number,                                                               -- 3
       decode (xadv.sf_product_id,'NOVALUE',NULL,xadv.sf_product_id) sf_product_id,  --Modified on 25APR18    -- 4
       xadv.creation_date,                                                               -- 5
       xadv.embedded_sw_version,                                                         -- 6
       xadv.objet_studio_sw_version,                                                     -- 7
       xadv.ship_date ,                                                                  -- 8
       decode (xadv.sf_parent_instance_id,'NOVALUE',NULL,xadv.sf_parent_instance_id) sf_parent_instance_id,  --Modified on 25APR18                                                  -- 9
       decode (xadv.sf_so_order_id ,'NOVALUE',NULL,xadv.sf_so_order_id)  sf_so_order_id ,                                                           -- 10
       decode (xadv.sf_so_line_id, 'NOVALUE',NULL,xadv.sf_so_line_id)  sf_so_line_id   ,                                                             -- 11
       xadv.ato_flag,                                                                    -- 12
       xadv.gmn_flag,                                                                    -- 13
       xadv.status,                                                                      -- 14
       xadv.sf_end_customer,                                                             -- 15
       xadv.sf_current_location,                                                         -- 16
       xadv.sf_install_location,                                                         -- 17
       xadv.sf_bill_to,                                                                  -- 18
       xadv.sf_ship_to,                                                                  -- 19
       xadv.asset_type    ,                                                               -- 20
       parent_instance_id    ,
       substr(serial_number||'-'||item_description ,1,80) asset_name,
       xadv.COI_Date,
       xadv.Contract_Type,--CTASK0037633
       xadv.install_date,--CTASK0037633
       xadv.Install_Site--CTASK0037633
       ,NVL2(xe.Attribute2 ,
             xxssys_oa2sf_util_pkg.get_sf_product_id(xe.Attribute2)
             ,''
            )upgrade_product --Added on 6Sep@018 for #CHG0043859
       ,xe.Attribute3 upgrade_oracle_number     --Added on 6Sep@018 for #CHG0043859
       ,to_date(xe.Attribute4 , 'DD-MON-YYYY') upgrade_date--Added on 6Sep@018 for #CHG0043859
from   XXCSI_ASSET_DTL_V xadv
     , xxssys_events xe
where  xe.entity_id = xadv.instance_id
  and  xe.target_name = 'STRATAFORCE'
  and  xe.entity_name = 'ASSET'
  and  xe.status = 'NEW'
 )
 select "EVENT_ID","EVENT_STATUS","EVENT_NAME","SF_ACCOUNT_ID","INSTANCE_ID",
        "SERIAL_NUMBER","SF_PRODUCT_ID","CREATION_DATE","EMBEDDED_SW_VERSION",
        "OBJET_STUDIO_SW_VERSION","SHIP_DATE","SF_PARENT_INSTANCE_ID","SF_SO_ORDER_ID",
        "SF_SO_LINE_ID","ATO_FLAG","GMN_FLAG","STATUS","SF_END_CUSTOMER","SF_CURRENT_LOCATION",
        "SF_INSTALL_LOCATION","SF_BILL_TO","SF_SHIP_TO","ASSET_TYPE","PARENT_INSTANCE_ID",
        "ASSET_NAME","COI_DATE","CONTRACT_TYPE", "INSTALL_DATE","INSTALL_SITE",
        "UPGRADE_PRODUCT","UPGRADE_DATE","UPGRADE_ORACLE_NUMBER"
 from Asset
where
  parent_instance_id = -1
UNION ALL
 select "EVENT_ID","EVENT_STATUS","EVENT_NAME","SF_ACCOUNT_ID","INSTANCE_ID",
        "SERIAL_NUMBER","SF_PRODUCT_ID","CREATION_DATE","EMBEDDED_SW_VERSION",
        "OBJET_STUDIO_SW_VERSION","SHIP_DATE","SF_PARENT_INSTANCE_ID","SF_SO_ORDER_ID",
        "SF_SO_LINE_ID","ATO_FLAG","GMN_FLAG","STATUS","SF_END_CUSTOMER","SF_CURRENT_LOCATION",
        "SF_INSTALL_LOCATION","SF_BILL_TO","SF_SHIP_TO","ASSET_TYPE","PARENT_INSTANCE_ID",
        "ASSET_NAME","COI_DATE","CONTRACT_TYPE", "INSTALL_DATE","INSTALL_SITE",
        "UPGRADE_PRODUCT","UPGRADE_DATE","UPGRADE_ORACLE_NUMBER"
 from Asset
where
      parent_instance_id !=-1
   and sf_parent_instance_id != 'NOVALUE'
;
