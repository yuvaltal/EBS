CREATE OR REPLACE VIEW XXOM_ORDER_HEADER_INTERFACE_V
  AS
SELECT
--------------------------------------------------------------------
--  name:           xxom_order_header_interface_v
--  create by:      Michal Tzvik
--  Revision:       1.0
--  creation date:  04-Jan-15
--------------------------------------------------------------------
--  purpose :        CHG0034083– Monitor form for Orders Interface from SF
--                                -> OA and Purge process for log
--------------------------------------------------------------------
--  Verion  Date        Name              Desc
--------------------------------------------------------------------
--  1.0     04-JAN-15   Michal Tzvik      Initial build
--  2.0     04/30/2018  Diptasurjya       CHG0042734 - STRATAFORCE new field addition
--------------------------------------------------------------------
 xohi.rowid row_id,
 xohi.interface_header_id,
 xohi.bpel_instance_id,
 xohi.operation,
 xohi.status_code,
 xohi.status_message,
 xohi.orig_sys_document_ref,
 xohi.header_id,
 ooha.order_number,
 TRUNC(xohi.ordered_date) ordered_date,
 xohi.currency_code,
 xohi.order_status,
 xohi.org_id,
 xxhz_util.get_operating_unit_name(xohi.org_id) ou_name,
 (SELECT oot1a.name
  FROM   oe_order_types_115_all oot1a
  WHERE  oot1a.order_type_id = xohi.order_type_id) so_type_name,
 xohi.sold_to_org_id,
 (SELECT hp.party_name || ' (AC# ' || hca.account_number || ')'
  FROM   hz_cust_accounts hca,
         hz_parties       hp
  WHERE  hp.party_id = hca.party_id
  AND    hca.cust_account_id = xohi.sold_to_org_id) account_name,
 xohi.ship_to_org_id, --site_id
 xohi.ship_to_site_id, --site_use_id
 xosdv_ship.site_ddress || ' ' || xosdv_ship.site_city || ' ' ||
 xosdv_ship.site_postal_code || ' ' || xosdv_ship.site_county || ' ' ||
 xosdv_ship.site_state || ' ' || xosdv_ship.site_country ship_to_address,
 xosdv_ship.party_site_number || ' (' || hou_ship.name || ')' ship_to_site_number,
 xohi.invoice_to_org_id, --site_id
 xohi.invoice_to_site_id, --site_use_id
 xosdv_bill.site_ddress || ' ' || xosdv_bill.site_city || ' ' ||
 xosdv_bill.site_postal_code || ' ' || xosdv_bill.site_county || ' ' ||
 xosdv_bill.site_state || ' ' || xosdv_bill.site_country bill_to_address,
 xosdv_bill.party_site_number || ' (' || hou_bill.name || ')' bill_to_site_number,
 xohi.ship_from_org_id,
 (SELECT mp.organization_code
  FROM   mtl_parameters mp
  WHERE  mp.organization_id = xohi.ship_from_org_id) warehouse,
 xohi.contact_id,
 xxom_order_interface_pkg.get_contact_name(xohi.contact_id) contact_name,
 xohi.invoice_to_contact_id,
 xxom_order_interface_pkg.get_contact_name(xohi.invoice_to_contact_id) bill_to_contact_name,
 xohi.ship_to_contact_id,
 xxom_order_interface_pkg.get_contact_name(xohi.ship_to_contact_id) ship_to_contact_name,
 xohi.freight_terms_code,
 xohi.shipping_method_code,
 xohi.cust_po,
 xohi.external_reference_id,
 xohi.price_list_id,
 (SELECT qlht.name
  FROM   qp_list_headers_tl qlht
  WHERE  qlht.language = 'US'
  AND    qlht.list_header_id = xohi.price_list_id) price_list_name,
 xohi.salesrep_id,
 (SELECT res.resource_name
  FROM   jtf_rs_salesreps         jrs,
         jtf_rs_resource_extns_vl res
  WHERE  jrs.resource_id = res.resource_id
  AND    jrs.salesrep_id = xohi.salesrep_id
  AND    jrs.org_id = xohi.org_id
  AND    res.category IN
         ('EMPLOYEE', 'OTHER', 'PARTY', 'PARTNER', 'SUPPLIER_CONTACT')) salesperson_name,
 xohi.packing_instructions,
 xohi.shipping_comments,
 xohi.payment_term_id,
 xohi.email,
 (SELECT fu.user_name
  FROM   fnd_user fu
  WHERE  fu.email_address = xohi.email
  AND    rownum = 1) user_name,
 xohi.order_source_id,
 xohi.resp_id,
 xohi.resp_appl_id,
 xohi.created_by,
 xohi.creation_date,
 xohi.last_updated_by,
 xohi.last_update_date,
 xohi.last_update_login,
 xohi.check_source,
 xohi.user_id interface_user_id,
 (SELECT fu.user_name
  FROM   fnd_user fu
  WHERE  fu.user_id = xohi.last_updated_by) interface_user_name,
 xohi.attribute1,
 xohi.attribute2,
 xohi.attribute3,
 xohi.attribute4,
 xohi.attribute5,
 xohi.attribute6,
 xohi.attribute7,
 xohi.attribute8,
 xohi.attribute9,
 xohi.attribute10,
 xohi.attribute11,
 xohi.attribute12,
 xohi.attribute13,
 xohi.attribute14,
 xohi.attribute15,
 xohi.attribute19,  -- CHG0042734
 xohi.attribute20,  -- CHG0042734
 xohi.order_source_name,  -- CHG0042734
 xohi.change_reason_meaning, -- CHG0042734
 xohi.change_reason_code, -- CHG0042734
 xohi.change_comments -- CHG0042734
FROM   xxom_order_header_interface        xohi,
       oe_order_headers_all               ooha,
       xxobjt_oa2sf_site_details_v        xosdv_ship,
       hr_operating_units                 hou_ship,
       xxobjt_oa2sf_site_details_v        xosdv_bill,
       hr_operating_units                 hou_bill
WHERE  ooha.header_id(+) = xohi.header_id
AND    xosdv_ship.ship_site_use_id(+) = xohi.ship_to_org_id
AND    hou_ship.organization_id(+) = xosdv_ship.org_id
AND    xosdv_bill.bill_site_use_id(+) = xohi.invoice_to_org_id
AND    hou_bill.organization_id(+) = xosdv_bill.org_id
;
