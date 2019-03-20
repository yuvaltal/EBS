CREATE OR REPLACE VIEW XXOM_LINE_FSL_DTL_V
  AS
select
--------------------------------------------------------------------
--  name:     XXOM_LINE_FSL_DTL_V
--  Description:     strataforce  project order line  Interface initial build
--                  used by soa
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   10.07.18      Lingaraj        CHG0042734[CTASK0037508] - Create Order interface for FSL
-------------------------------------------------------------------------------------------------------------
LINE_ID
,HEADER_ID
,SF_FSL_SO_HEADER_ID
--,SF_PRICE_ENTRY_ID
,ORG_ID
,LINE_NUMBER
,ORDERED_ITEM
,SF_ORDERED_ITEM
,UOM
,ORDERED_QUANTITY
,UNIT_SELLING_PRICE
,UNIT_LIST_PRICE
,FLOW_STATUS_CODE
,LINE_STATUS
,STATUS
,MAINTENANCE_START_DATE
,MAINTENANCE_END_DATE
,SERVICE_START_DATE
,SERVICE_END_DATE
,INVOICE_NUMBER
,HOLD_REASON
,IS_ON_HOLD
,TRACKING_NUMBER
,DELIVERIES4LINE
,DELIVERY_STATUS
,(Case
    when DELIVERIES4LINE is not null and DELIVERY_STATUS is not null Then
       DELIVERIES4LINE || '(' || DELIVERY_STATUS || ')'
    else ''
    end
  )   delivery_num_with_status
,ACTUAL_FULFILLMENT_DATE
/*,LINE_TYPE
,DIST_FUNCTIONAL_AMOUNT
,SF_SERVICE_ASSET_ID
,SBQQ__ASSET*/
,Item_description
FROM
  (Select  ol.line_id,
           ol.header_id,
           xxssys_oa2sf_util_pkg.get_sf_fsl_so_header_id( ol.header_id ) sf_fsl_so_header_id,
           --xxssys_oa2sf_util_pkg.get_sf_price_line_id(ol.PRICE_LIST_ID,ol.ordered_item,oh.transactional_curr_code) sf_price_entry_id,
           ol.org_id,
           (ol.line_number || DECODE(ol.shipment_number,NULL,'',('.'||ol.shipment_number))) line_number,
           ol.ordered_item,
           xxssys_oa2sf_util_pkg.get_sf_product_id(ol.ordered_item) sf_ordered_item,
           xxssys_oa2sf_util_pkg.get_item_uom_code(ol.inventory_item_id) UOM,
           (case when ol.line_category_code = 'RETURN' then
                     ol.ordered_quantity * -1
                else
                     ol.ordered_quantity
           end)                                                                              ordered_quantity,
           ol.unit_selling_price,
           ol.unit_list_price,
           ol.flow_status_code,
           oe_line_status_pub.get_line_status(ol.line_id, ol.flow_status_code)                 line_status,
           initcap(ol.flow_status_code)                                                     status,
           dfv.maintenance_start_date                                                  maintenance_start_date,
           dfv.maintenance_end_date                                                    maintenance_end_date,
           ol.service_start_date,
           ol.service_end_date,
           xxssys_oa2sf_util_pkg.get_invoice4so_line(ol.line_id)                       invoice_number,
           xxssys_oa2sf_util_pkg.get_order_line_hold(ol.header_id, ol.line_id)         hold_reason,
           xxssys_oa2sf_util_pkg.is_order_line_on_hold(ol.header_id, ol.line_id)       is_on_hold,
           xxwsh_general_pkg.get_tracking_number(ol.line_id)                           tracking_number,
           xxoe_utils_pkg.get_so_line_delivery(ol.line_id)                             deliveries4line,
           xxssys_oa2sf_util_pkg.get_so_line_delivery_status(ol.line_id)               delivery_Status,
           ol.actual_fulfillment_date,
           /*(
           SELECT ottl.name
              FROM   oe_transaction_types_all ott,
                     oe_transaction_types_tl  ottl
              WHERE  ott.transaction_type_id = ottl.transaction_type_id
              AND    ottl.language           = 'US'
              AND    ott.transaction_type_id = ol.line_type_id
           )                                                                              Line_Type,
           xxssys_oa2sf_util_pkg.get_Dist_Functional_Amount(ol.line_id)                   Dist_Functional_Amount,
           xxssys_oa2sf_util_pkg.get_sf_service_asset_id(ol.line_id ,
                                                         ol.inventory_item_id,
                                                         ol.attribute1,
                                                         ol.attribute14,
                                                         ol.service_reference_type_code,
                                                         ol.service_reference_line_id,
                                                         dfv.serial_number
                                                         )   sf_service_asset_id,
           xxssys_oa2sf_util_pkg.get_sf_asset_id(ol.attribute1) SBQQ__Asset,*/
           msib.description Item_description
    FROM   oe_order_lines_all     ol,
           oe_order_lines_all_dfv dfv,
           oe_order_headers_all    oh,
           mtl_system_items_b      msib
   WHERE   dfv.row_id             = ol.rowid
   and     oh.header_id           = ol.header_id
   and     msib.organization_id = 91
   and     msib.inventory_item_id = ol.inventory_item_id
   );
