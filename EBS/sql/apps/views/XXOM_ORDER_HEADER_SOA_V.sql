CREATE OR REPLACE VIEW XXOM_ORDER_HEADER_SOA_V
  AS
SELECT
--------------------------------------------------------------------
--  name:     XXOM_ORDER_HEADER_SOA_V
--  Description:    order header interface list for strataforce system
--                  used by soa
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   9.11.17       yuval tal       CHG0042041 - strataforce  project order header  Interface initial build
--  1.1   12.09.2018    Diptasurjya     CHG0043691 - Add new field for Opportunity Notes attachment
--  1.2   11.10.2018    Lingaraj        CHG0044177 - remove decoding of opp id from SO header when status is cancelled.
--  1.3   14/11/2018    Lingaraj        CHG0044334 - Change in SO header interface -
--                                      Update "Complete Order Shipped Date" and "Systems Shipped Date"
--------------------------------------------------------------------
       e.event_id,
       e.status,
       e.attribute1 DML_MODE,
       header_id,
       decode(sf_header_id,'NOVALUE' ,null,sf_header_id) sf_header_id,
       org_id,
       sf_ou_id,
       order_number,
       cust_po_number,
       order_status_desc,
       decode (sf_price_book_id,'NOVALUE' ,null,sf_price_book_id) sf_price_book_id,
       sf_end_cust_account_id,
       sf_SOLD_TO_account_id,
       sold_to_account_number,
       shipping_site_num,
      -- sf_ship_site,
       billing_site_num,
     --  sf_bill_site,
       order_date,
       currency_code,
       CONVERSION_RATE,
       shipping_instructions,
       packing_instructions,
       on_hold,
       hold_reason,
       freight_terms_code,
       shipping_method_code,
       order_source_id,
       order_type_id,
       order_type_name,
       period_end_date,
       quote_no,
       sales_channel,
       pricing_date,
       --decode (order_status_desc ,'Cancelled','',sf_opportunity_id) sf_opportunity_id,----CHG0044177
       sf_opportunity_id,--CHG0044177
       sf_payment_term_id,
       booked_date,
       sf_quote_id,
       sys_booking_date,
       d.shipping_state_name,
       d.shipping_country_name,
       d.Oppurtunity_Notes  -- CHG0043691 new column added
       ,d.complete_order_shipped_date --CHG0044177
       ,d.systems_shipped_date        --CHG0044177
FROM   xxssys_events           e,
       xxom_order_header_dtl_v d
WHERE  e.entity_name = 'SO_HEADER'
AND    e.status = 'NEW'
AND    e.target_name = 'STRATAFORCE'
AND    d.header_id = e.entity_id
and    sf_SOLD_TO_account_id is not null
and exists (select 1 from oe_order_lines_all l
where l.header_id=d.header_id /*and nvl(l.cancelled_flag,'N')!='Y'*/)

UNION ALL

 Select
       e.event_id,
       e.status,
       'DELETED' DML_MODE,
       e.entity_id header_id,
       xxssys_oa2sf_util_pkg.get_sf_so_header_id(e.entity_id) sf_header_id,
       0 org_id,
       '' sf_ou_id,
       0 order_number,
       '' cust_po_number,
       'Deleted' order_status_desc,
       '' sf_price_book_id,
       '' sf_end_cust_account_id,
       '' sf_SOLD_TO_account_id,
       null sold_to_account_number,
       '' shipping_site_num,
      -- sf_ship_site,
       '' billing_site_num,
     --  sf_bill_site,
       NULL order_date,
       '' currency_code,
       0 CONVERSION_RATE,
       '' shipping_instructions,
       '' packing_instructions,
       '0' on_hold,
       '' hold_reason,
       '' freight_terms_code,
       '' shipping_method_code,
       0 order_source_id,
       0 order_type_id,
       '' order_type_name,
       NULL period_end_date,
       '' quote_no,
       '' sales_channel,
       NULL pricing_date,
       '' sf_opportunity_id,
       '' sf_payment_term_id,
       NULL booked_date,
       NULL sf_quote_id,
       NULL sys_booking_date,
       NULL shipping_state_name,
       NULL shipping_country_name,
       NULL Oppurtunity_Notes -- CHG0043691 new column added
       ,NULL complete_order_shipped_date --CHG0044177
       ,NULL systems_shipped_date        --CHG0044177
FROM   xxssys_events           e
WHERE  e.entity_name = 'SO_HEADER'
AND    e.status      = 'NEW'
AND    e.target_name = 'STRATAFORCE'
and    e.attribute1   = 'DELETE'
;
