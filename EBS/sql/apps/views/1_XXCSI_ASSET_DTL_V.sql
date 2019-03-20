CREATE OR REPLACE VIEW XXCSI_ASSET_DTL_V AS
select
-----------------------------------------------------------------------------------------------
-- Ver     When         Who           Description
-- ------  -----------  -----------  ----------------------------------------------------------
-- 1.0     02/03/2018   Roman.W      Init Version
--                                   CHG0042619 - Install base interface from Oracle to salesforce
-- 1.1     05/06/2018   Roman W.     CHG0042619 - CTASK0037023 change Serial Number Logic
-- 1.2     24/07/2018   Lingaraj     CTASK0037633  - Adittional Fields to Strataforce
-----------------------------------------------------------------------------------------------
      Account_Number,
      cust_account_id,
      sub_tbl.sf_account_id,                                                               -- 1
      sub_tbl.instance_id,                                                                 -- 2
      sub_tbl.serial_number,                                                               -- 3
      sub_tbl.sf_product_id,                                                               -- 4
      sub_tbl.creation_date,                                                               -- 5
      sub_tbl.embedded_sw_version,                                                         -- 6
      sub_tbl.objet_studio_sw_version,                                                     -- 7
      sub_tbl.ship_date ,                                                                  -- 8
      parent_instance_id,                                                                  -- 9
      xxssys_oa2sf_util_pkg.get_sf_asset_id(parent_instance_id) sf_parent_instance_id  ,   -- 9
      xxssys_oa2sf_util_pkg.get_sf_so_header_id( LAST_HEADER_ID )  sf_so_order_id   ,      -- 10
      xxssys_oa2sf_util_pkg.get_sf_so_line_id (LAST_OE_ORDER_LINE_ID ) sf_so_line_id  ,    -- 11
      sub_tbl.ato_flag,                                                                    -- 12
      sub_tbl.gmn_flag,                                                                    -- 13
      sub_tbl.status,                                                                      -- 14
      sub_tbl.sf_end_customer,                                                             -- 15
      sub_tbl.sf_current_location,                                                         -- 16
      sub_tbl.sf_install_location,                                                         -- 17
      xxssys_oa2sf_util_pkg.get_sf_site_id( bill_to) sf_bill_to ,                                                                      -- 18
       xxssys_oa2sf_util_pkg.get_sf_site_id( ship_to) sf_ship_to,
      ship_to,
      bill_to,                                                                 -- 19
      sub_tbl.asset_type,                                                       -- 20
      item_description,
      COI_Date,
      Contract_Type,
      install_date,
      Install_Site
from (SELECT msi.description item_description ,
     hcao.account_number,
     hcao.cust_account_id,
       xxssys_oa2sf_util_pkg.get_sf_account_id(hcao.Account_Number) sf_account_id,                   -- 1 --
       cii.instance_id,                                                                              -- 2 --
       cii.instance_number,
       CASE
         WHEN xxinv_unified_platform_utl_pkg.is_general_platform(cii.inventory_item_id,
                                                                 735) = 'Y' THEN
          NULL
         WHEN (instr(cii.serial_number, '-') > 0 AND
              cii.inventory_item_id IN (762604, 762598)) THEN
          substr(cii.serial_number, 1, instr(cii.serial_number, '-') - 1)
         ELSE
          REPLACE(cii.serial_number, ' ', '_')
       END serial_number,                                                                           -- 3 --
       xxssys_oa2sf_util_pkg.get_sf_product_id( msi.segment1) sf_product_id, -- 4 -- ---?????????????????????
       cii.creation_date,                                                                           -- 5 --
       cii.attribute4 embedded_sw_version,                                                          -- 6 --
       cii.attribute5 objet_studio_sw_version,                                                      -- 7 --
       cidv.shipped_date ship_date,                                                                 -- 8 --
      nvl( (SELECT cii_printer.instance_id
          FROM csi_item_instances cii_printer, csi_ii_relationships cir
         WHERE cir.object_id = cii_printer.instance_id
           AND cir.subject_id = cii.instance_id
           AND nvl(cir.active_end_date, SYSDATE) > SYSDATE - 1),-1) parent_instance_id,                    ---???? create sf_parent_instance_id


       nvl((SELECT decode(oola.ato_line_id, NULL, 'False', 'True')
             FROM oe_order_lines_all oola
            WHERE cidv.last_line_id = oola.line_id),
           'False') ato_flag,                                                                        -- 12
       -----------------------------------------------------------
   (SELECT DECODE(count(*),0,'False','True')
          FROM WSH.WSH_NEW_DELIVERIES       WND,
               WSH.WSH_DELIVERY_ASSIGNMENTS WDA,
               WSH.WSH_DELIVERY_DETAILS     WDD,
               WSH_SERIAL_NUMBERS           WSN,
               XXCS_ITEMS_PRINTERS_V        PR,
               OE_ORDER_HEADERS_ALL         OOHA,
               OE_ORDER_LINES_ALL           OOLA,
               CSI_ITEM_INSTANCES           CII,
               HZ_CUST_ACCOUNTS             HCA,
               HZ_PARTIES                   HP,
                OE_TRANSACTION_TYPES_TL otl
         WHERE WND.DELIVERY_ID = WDA.DELIVERY_ID
           AND WDA.DELIVERY_DETAIL_ID = WDD.DELIVERY_DETAIL_ID
           AND WSN.DELIVERY_DETAIL_ID = WDD.DELIVERY_DETAIL_ID
           AND WDD.INVENTORY_ITEM_ID = PR.INVENTORY_ITEM_ID
           AND WDD.SOURCE_HEADER_ID = OOHA.HEADER_ID
           AND WDD.SOURCE_LINE_ID = OOLA.LINE_ID
           AND OOLA.HEADER_ID = OOHA.HEADER_ID
           AND CII.SERIAL_NUMBER = WSN.FM_SERIAL_NUMBER
           AND HCA.CUST_ACCOUNT_ID = OOHA.SOLD_TO_ORG_ID
           AND HCA.PARTY_ID = HP.PARTY_ID
           AND CII.ATTRIBUTE12 IS NOT NULL
            AND OOLA.LINE_TYPE_ID = OTL.TRANSACTION_TYPE_ID
                                    and OTL.LANGUAGE = 'US'
                                    AND OTL.NAME LIKE '%GMN%'
           AND HCA.Cust_Account_Id = hcao.cust_account_id
           and PR.INVENTORY_ITEM_ID = cii.inventory_item_id
           and rownum=1)  gmn_flag,                                -- 13

       -----------------------------------------------------------
       cis.name status,                                                                              -- 14
       (SELECT xxssys_oa2sf_util_pkg.get_sf_account_id(hca.Account_Number)
          FROM csi_hzca_site_uses_v chsu_inst,
               hz_cust_acct_sites_all hcas,
               hz_cust_accounts       hca
         WHERE hcas.cust_acct_site_id = chsu_inst.cust_acct_site_id
           AND hcas.party_site_id = cidv.install_location_id
           AND chsu_inst.site_use_code = 'SHIP_TO'
           AND chsu_inst.site_org_id = hzpo.attribute3 --IN(hzpo.attribute3,81)-- 1.3 15.02.2015 Adi Safin CHG0034398
           AND hcas.status = 'A'
           AND chsu_inst.status = 'A'
           AND hca.status = 'A'
           AND chsu_inst.cust_account_id = hca.cust_account_id
        ) sf_end_customer,                           -- Added CTASK0037633
       (SELECT xxssys_oa2sf_util_pkg.get_sf_site_id(hcas.cust_acct_site_id)
          FROM csi_hzca_site_uses_v chsu_inst,
               hz_cust_acct_sites_all hcas,
                hz_cust_accounts       hca
         WHERE hcas.cust_acct_site_id = chsu_inst.cust_acct_site_id
           AND hcas.party_site_id = cii.location_id
           AND chsu_inst.site_use_code = 'SHIP_TO'
           AND chsu_inst.site_org_id = hzpo.attribute3 --IN(hzpo.attribute3,81)-- 1.3 15.02.2015 Adi Safin CHG0034398
           AND hcas.status = 'A'
           AND chsu_inst.status = 'A'
           AND hca.status = 'A'
           AND chsu_inst.cust_account_id = hca.cust_account_id) sf_current_location, ---???????????????         -- 16
       (SELECT xxssys_oa2sf_util_pkg.get_sf_site_id(chsu_inst.cust_acct_site_id)
          FROM csi_hzca_site_uses_v chsu_inst,
               hz_cust_acct_sites_all hcas,
                hz_cust_accounts       hca
         WHERE hcas.cust_acct_site_id = chsu_inst.cust_acct_site_id
           AND hcas.party_site_id = cidv.install_location_id
           AND chsu_inst.site_use_code = 'SHIP_TO'
           AND chsu_inst.site_org_id = hzpo.attribute3 --IN(hzpo.attribute3,81)-- 1.3 15.02.2015 Adi Safin CHG0034398
           AND hcas.status = 'A'
           AND chsu_inst.status = 'A'
           AND hca.status = 'A'
           AND chsu_inst.cust_account_id = hca.cust_account_id) sf_install_location,                                -- 17
       (SELECT chsu_inst.PARTY_ADDRESS
          FROM csi_hzca_site_uses_v chsu_inst,
               hz_cust_acct_sites_all hcas,
                hz_cust_accounts       hca
         WHERE hcas.cust_acct_site_id = chsu_inst.cust_acct_site_id
           AND hcas.party_site_id = cidv.install_location_id
           AND chsu_inst.site_use_code = 'SHIP_TO'
           AND chsu_inst.site_org_id = hzpo.attribute3 --IN(hzpo.attribute3,81)-- 1.3 15.02.2015 Adi Safin CHG0034398
           AND hcas.status = 'A'
           AND chsu_inst.status = 'A'
           AND hca.status = 'A'
           AND chsu_inst.cust_account_id = hca.cust_account_id) install_site,
       (SELECT ( chsu_bill.cust_acct_site_id)
         FROM csi_hzca_site_uses_v chsu_bill
        WHERE chsu_bill.site_use_id = (SELECT cipv1.bill_to_address
                                         FROM csi_instance_party_v cipv1
                                        WHERE cipv1.instance_id = cii.instance_id)) bill_to,
       (SELECT  chsu_ship.cust_acct_site_id
          FROM csi_hzca_site_uses_v chsu_ship
         WHERE chsu_ship.site_use_id =
               (SELECT cipv1.ship_to_address
                  FROM csi_instance_party_v cipv1
                 WHERE cipv1.instance_id = cii.instance_id)) ship_to, -----?????????????????                         -- 19
       (   SELECT FFV.ATTRIBUTE2 Asset_type
        FROM FND_FLEX_VALUE_SETS FFVS,
             FND_FLEX_VALUES     FFV,
             FND_FLEX_VALUES_TL  FFVT
       WHERE FFVS.FLEX_VALUE_SET_NAME = 'XXCS_IB_TYPE'
         AND FFVS.FLEX_VALUE_SET_ID = FFV.FLEX_VALUE_SET_ID
         AND FFVT.FLEX_VALUE_ID = FFV.FLEX_VALUE_ID
         AND FFVT.LANGUAGE = 'US'
         AND FFV.ENABLED_FLAG = 'Y'
         AND FFVT.DESCRIPTION =  xxssys_oa2sf_util_pkg.get_category_value('Activity Analysis',cii.inventory_item_id) ) Asset_type,                                                                                                       -- 20  !!!!!!!!
      -- cii.attribute12     sf_asset_id, ----?????????????????????
     --  cii.location_id,
      -- cii.owner_party_account_id,
       msi.description,
       msi.segment1 product,
       cidv.install_location_id,
       cidv.last_line_number order_line_number,
       cidv.last_order_number sales_order_number,
        cidv.LAST_OE_ORDER_LINE_ID,
               cidv.LAST_HEADER_ID,
       csi_dfv.XXCSI_COI_DATE COI_Date, --CTASK0037633
       cii.Attribute17 Contract_Type,--CTASK0037633
       cii.install_date --CTASK0037633
  FROM csi_item_instances     cii,
       csi_instance_details_v cidv,
       mtl_system_items_b     msi,
       hz_parties             hzpo,
       hz_cust_accounts       hcao,
       csi_instance_statuses  cis,
       csi_item_instances_dfv csi_dfv
 WHERE msi.organization_id = 91
   AND msi.inventory_item_id = cii.inventory_item_id
   AND cii.owner_party_id = hzpo.party_id
   AND cidv.instance_id = cii.instance_id
   AND hzpo.party_id = hcao.party_id
   AND hcao.status = 'A'
   AND csi_dfv.rowid = cii.rowid
 --  AND (cii.instance_status_id != 510 OR (cii.instance_status_id = 510 AND cii.attribute16 = 'Y')) ----??????
   AND cii.instance_status_id = cis.instance_status_id
   AND nvl(cii.owner_party_account_id,hcao.cust_account_id) = hcao.cust_account_id
   ) sub_tbl
;
