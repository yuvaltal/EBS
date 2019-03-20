create or replace view xxinv_product_dtl_v as
Select
----------------------------------------------------------------------------------------------------------
--  name       :     XXINV_PRODUCT_DTL_V
--  Description:     product detail view
--                  used by soa
----------------------------------------------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   9.11.17       yuval tal       CHG0041504 - strataforce  project PRODUCT Interface initial build
--  1.1   23.4.18       yuval tal       CHG0041504/CTASK0036308 change status logic
--  1.2   4.Sep.18      Lingaraj        CHG0043701 - Product Interface - Add new fields "End of Service"
----------------------------------------------------------------------------------------------------------
   msib.inventory_item_id inventory_item_id,
   decode (   mis.inventory_item_status_code_tl||msib.returnable_flag , 'DiscontinuedN'  , 'False' , 'True' )  active,

   msib.segment1          product_code,
   msib.description       product_name,
   xxinv_utils_pkg.get_item_desc_tl(msib.inventory_item_id, 732) product_name_jpn,
   msib.primary_uom_code                primary_unit_of_measure,
   msib.volume_uom_code,
   msib.weight_uom_code,
   msib.unit_weight,
   xxobjt_general_utils_pkg.get_lookup_meaning('ITEM_TYPE', msib.item_type,'N') item_type,
   decode(msib.customer_order_flag, 'Y', 'True', 'False')         customer_order_flag,
   decode(msib.customer_order_enabled_flag, 'Y', 'True', 'False') customer_order_enabled_flag,
   decode(msib.returnable_flag, 'Y', 'True', 'False')             returnable_flag,
   msib.unit_volume,
   decode(xxinv_utils_pkg.is_fdm_item(msib.inventory_item_id),
                                                              'Y',
                                                              'True',
                                                              'False') is_fdm_item,

   mis.inventory_item_status_code_tl    product_status,
  xxssys_oa2sf_util_pkg.get_concatenated_segments(msib.inventory_item_id)  concatenated_segments,
  xxssys_oa2sf_util_pkg.get_RelatedToSystem_Value(1)  RelatedToSystems,
  xxssys_oa2sf_util_pkg.get_RelatedToSystem_Value(2) RelatedToSystems2,
  xxssys_oa2sf_util_pkg.get_RelatedToSystem_Value(3) RelatedToSystems3,
  xxssys_oa2sf_util_pkg.get_RelatedToSystem_Value(4) RelatedToSystems4,
  xxssys_oa2sf_util_pkg.get_RelatedToSystem_Value(5) RelatedToSystems5,

  (mc.segment1 || '.' || mc.segment2 || '.' || mc.segment3)  product_category,
   --
  ipv.family family,

  xxssys_oa2sf_util_pkg.get_RelatedToSystem_Value(6) RelatedToProductFamilies,

  xxobjt_general_utils_pkg.get_lookup_meaning('MTL_SERVICE_BILLABLE_FLAG',
                                             msib.material_billable_flag) Billing_Type,

   xxssys_oa2sf_util_pkg.get_sf_related_item_product_id(msib.segment1, 'Substitute')sf_substitute_product_id,
   xxssys_oa2sf_util_pkg.get_cpq_feature( msib.segment1 ) cpq_feature,
   msit.long_description,
   xxssys_oa2sf_util_pkg.get_category_value('Activity Analysis' ,msib.inventory_item_id ) Activity_Analysis,
   xxssys_strataforce_events_pkg.is_bom_valid(p_inventory_item_id => msib.inventory_item_id,
                                              p_organization_id   => msib.organization_id)  is_bom_valid,
   xxssys_oa2sf_util_pkg.get_category_value('Visible in PB' ,msib.inventory_item_id ) is_Visible_in_PB,
   xxssys_oa2sf_util_pkg.get_category_value('Exclude from CPQ' ,msib.inventory_item_id ) is_Exclude_from_CPQ,
   xxssys_oa2sf_util_pkg.get_category_value('Internal use only' ,msib.inventory_item_id ) is_Internal_use_only,
   msib.attribute11 cs_return_to_hq,
   msib.attribute12 cs_return_defective,
   xxssys_oa2sf_util_pkg.get_sf_related_item_product_id(msib.segment1, 'Related')    sf_related_product_id,
   xxssys_oa2sf_util_pkg.get_sf_related_item_product_id(msib.segment1, 'Superseded') sf_superseded_product_id,
   xxssys_oa2sf_util_pkg.get_sf_servicecontract_id(msib.coverage_schedule_id)        sf_servicecontract_id,

   xxssys_oa2sf_util_pkg.get_category_value('Brand' ,msib.inventory_item_id ) brand,   -- SSYS CoreBrand__c
   xxssys_oa2sf_util_pkg.get_category_value('Product Hierarchy' ,msib.inventory_item_id ) Product_Hierarchy
   ,(select min(mpi.effective_date)
    from   mtl_pending_item_status mpi
    where  mpi.organization_id = 91
    and    mpi.status_code = 'XX_END_SRV'
    and    mpi.inventory_item_id = msib.inventory_item_id
    ) End_of_Service_date -- CHG0043701 #04.sep.2018
  -------------------------------------------------
  FROM mtl_system_items_b    msib,
  mtl_system_items_tl msit,
       mtl_item_status       mis,
       mtl_item_status_dfv   misd,
       xxcs_items_printers_v ipv,
       mtl_item_categories   mic,
       mtl_categories        mc
 WHERE msib.organization_id           = xxinv_utils_pkg.get_master_organization_id
 and msit.inventory_item_id=msib.inventory_item_id
 and msit.language='US'
 and msit.organization_id=msib.organization_id
    AND mis.inventory_item_status_code = msib.inventory_item_status_code
   AND mis.rowid                      = misd.row_id
   AND ipv.inventory_item_id(+)       = msib.inventory_item_id
   AND mic.inventory_item_id(+)       = msib.inventory_item_id
   AND mic.organization_id(+)         = msib.organization_id
   AND mc.category_id(+)              = mic.category_id
   AND mic.category_set_id(+)         = 1100000041
;
