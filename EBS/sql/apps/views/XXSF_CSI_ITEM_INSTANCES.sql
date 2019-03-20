CREATE OR REPLACE VIEW XXSF_CSI_ITEM_INSTANCES AS
SELECT
--------------------------------------------------------------------
--  name:            XXSF_CSI_ITEM_INSTANCES2
--  create by:       Adi Safin
--  Revision:        1.0
--  creation date:   13/07/2014
--------------------------------------------------------------------
--  purpose :        For Reports,Packages - Replace Oracle Table CSI_ITEM_INSTANCES
--                   Do not change the Alias of the fields
--------------------------------------------------------------------
--  ver  date        name           desc
--  1.0  22/11/2018  Adi Safin      initial build
--------------------------------------------------------------------
       CSI.SerialNumber SERIAL_NUMBER,
       CSI.External_Key__c INSTANCE_ID,
       CSI.External_Key__c INSTANCE_NUMBER,
       CSI.Status Status_description,
       (SELECT cis.instance_status_id
        FROM   csi_instance_statuses cis
        WHERE  cis.name =  CSI.Status) instance_status_id,
        (SELECT hca.cust_account_id
         FROM hz_cust_accounts hca
         WHERE  hca.account_number = sf_acc1.external_key__c ) OWNER_ACCOUNT_ID,
       1 quantity,
       'EA' UNIT_OF_MEASURE,
       (SELECT cii.inventory_revision
        FROM csi_item_instances cii
        WHERE cii.instance_number =  CSI.External_Key__c)INVENTORY_REVISION,
       sf_acc1.Name Account_name,
       to_char(Shipping_Date__c,'DD-MON-YYYY') Shippment_date,
       (SELECT msi.inventory_item_id
        FROM mtl_system_items_b msi
        WHERE msi.segment1 = sf_prd.External_Key__c
        AND   msi.organization_id = 91) Inventory_item_id,
        sf_prd.External_Key__c PN_Description,
        sf_acc1.id ATTRIBUTE12,
        csi.Embedded_SW_Version__c ATTRIBUTE4,
        csi.Studio_SW_Version__c ATTRIBUTE5,
        csi.CS_Region__c ATTRIBUTE8,
        csi.COI_Date__c ATTRIBUTE7,
        decode(csi.COI__c,'0','N','1','Y') ATTRIBUTE3,
        to_char(csi.InstallDate,'DD-MON-YYYY') Install_date,
        ship_to.External_Key__c ship_to_site_id,
        bill_to.External_Key__c bill_to_site_id,
        install_to.External_Key__c install_site_id,
        install_to.External_Key__c current_site_id,
        Srv_cont.Status      Contract_status,
        Srv_cont.startDate   Contract_start_date,
        Srv_cont.EndDate     Contract_end_date,
        csi.Service_Contract_Warranty__c  Contract_sf_id,
       (SELECT sc_temp.Name
        FROM   XXSF2_PRODUCT2 cnt_pn,
               XXSF2_SERVICECONTRACT sc_temp
        WHERE  cnt_pn.Contract_Template__c = sc_temp.id
        AND    cnt_pn.id = Srv_cont.Service_Contract_Product__c) Contract_type,
        DECODE( Terminate_service_contracts__c,'True','Yes','False','No',NULL) Terminate_Service_Contract,
        decode(CSI.Status,'Terminated',csi.lastmodifieddate,null) Status_change_date,
        (SELECT external_Key__c
         FROM   XXSF2_ASSET csi_par
         WHERE  csi_par.id= csi.ParentId) Parent_instance_id,
         TO_CHAR(csi.createddate,'DD-MON-YYYY') attribute6,
         (SELECT ooha.order_number
          FROM   csi_instance_details_v cidv,
                 oe_order_headers_all ooha
          WHERE  cidv.LAST_HEADER_ID = ooha.header_id
          AND    to_char(cidv.instance_id) = csi.External_Key__c) Sales_SO_Number,
          TO_CHAR(csi.createddate,'DD-MON-YYYY') creation_date,
          csi.lastmodifieddate  Last_update_date,
          csi.Lastmodifiedbyid  Last_update_by,
          party.party_id        owner_party_id,
          party.cust_account_id owner_party_account_id,
          csi.Total_printing_time__c TPT,
         (SELECT hca.cust_account_id
          FROM hz_cust_accounts hca
          WHERE  hca.account_number = sf_acc2.external_key__c ) account_end_customer_id,
          (select hou.organization_id
           from hr_operating_units hou
           where hou.name = csi.Account_Operating_Unit__c) ship_to_ou_id,
           Sold_By__c                                      Sold_by_account_id,
           Supported_By_On_Site__c                         Supported_by_account_id
FROM   XXSF2_ASSET    csi,
       XXSF2_PRODUCT2 sf_prd,
       XXSF2_ACCOUNT  sf_acc1,
       XXSF2_ACCOUNT  sf_acc2,
       XXSF2_LOCATIONS bill_to,
       XXSF2_LOCATIONS ship_to,
       XXSF2_LOCATIONS install_to,
       (SELECT sc.Status, sc.StartDate, sc.endDate,Asset__c,Service_Contract_Product__c
        FROM   XXSF2_SERVICECONTRACT sc
        WHERE  SYSDATE BETWEEN sc.StartDate AND sc.endDate) Srv_cont,
       hz_cust_accounts party
where sf_prd.id = csi.Product2Id
and   sf_acc1.id=csi.AccountId
and   sf_acc2.id(+)=csi.end_customer__c
AND   csi.Bill_To_Location__c = bill_to.id(+)
AND   csi.LocationId = ship_to.id(+)
AND   csi.Install_Location__c = install_to.id(+) 
AND   csi.id = Srv_cont.Asset__c (+)
and   party.account_number = sf_acc1.External_Key__c
;
