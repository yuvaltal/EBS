CREATE OR REPLACE VIEW XXOM_ORDER_LINES_INTERFACE_V
  AS
SELECT
--------------------------------------------------------------------
--  name:           xxom_order_lines_interface_v
--  create by:      Michal Tzvik
--  Revision:       1.0
--  creation date:  04-Jan-15
--------------------------------------------------------------------
--  purpose :        CHG0034083– Monitor form for Orders Interface from SF
--                                -> OA and Purge process for log
--  Verion  Date        Name              Desc
--  1.0     04-JAN-15   Michal Tzvik      Initial build
--  2.0     06-APR-15  Gubendran K      CHG0034734 – Order management interfaces from SFDC to OA Column addition
--  3.0     04/30/2018  Diptasurjya       CHG0042734 - STRATAFORCE new field addition
--------------------------------------------------------------------
 xoli.rowid row_id,
 xoli.interface_header_id,
 xoli.line_id,
 xoli.line_number,
 xoli.inventory_item_id,
 (SELECT msib.segment1 || ' (' || msib.description || ')'
  FROM   mtl_system_items_b msib
  WHERE  msib.organization_id = 91
  AND    msib.inventory_item_id = xoli.inventory_item_id) orderded_item,
 xoli.ordered_quantity,
 xoli.uom,
 xoli.unit_selling_price,
 xoli.ship_from_org_id,
 xoli.organization_code,
 xoli.line_type_id,
 (SELECT ottl.name
  FROM   oe_transaction_types_tl ottl
  WHERE  ottl.transaction_type_id = xoli.line_type_id
  AND    ottl.language = 'US') line_type,
 xoli.subinventory,
 xoli.return_reason_code,
 xoli.serial_number,
 xoli.maintenance_start_date,
 xoli.maintenance_end_date,
 xoli.service_start_date,
 xoli.service_end_date,
 xoli.accounting_rule_id,
 xoli.source_type_code,
 xoli.external_reference_id,
 xoli.shipping_instructions,
 xoli.packing_instructions,
 xoli.order_line_seq,
 xoli.creation_date,
 xoli.created_by,
 xoli.last_update_date,
 xoli.last_updated_by,
 xoli.reference_header_id,
 xoli.reference_line_id,
 xoli.line_operation,
 xoli.attribute1,
 xoli.attribute2,
 xoli.attribute3,
 xoli.attribute4,
 xoli.attribute5,
 xoli.attribute6,
 xoli.attribute7,
 xoli.attribute8,
 xoli.attribute9,
 xoli.attribute10,
 xoli.attribute11,
 xoli.attribute12,
 xoli.attribute13,
 xoli.attribute14,
 xoli.attribute15,
  --CHG0034734
 xoli.user_item_description,
 xoli.return_context,
 xoli.ship_set,
 xoli.return_attribute1,
 xoli.return_attribute2,
 xoli.return_attribute3,
 xoli.return_attribute4,
 xoli.return_attribute5,
 xoli.return_attribute6,
 xoli.return_attribute7,
 xoli.return_attribute8,
 xoli.return_attribute9,
 xoli.return_attribute10,
 xoli.return_attribute11,
 xoli.return_attribute12,
 xoli.return_attribute13,
 xoli.return_attribute14,
 xoli.return_attribute15
 --CHG0034734
 , xoli.unit_list_price -- CHG0042734
 , xoli.change_reason_meaning -- CHG0042734
 , xoli.change_reason_code -- CHG0042734
 , xoli.change_comments -- CHG0042734
FROM   xxom_order_lines_interface xoli
;
