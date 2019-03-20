CREATE OR REPLACE VIEW XXOM_ORDER_HEADER_DTL_V
  AS
SELECT
----------------------------------------------------------------------------------------------------------------
--  name:     XXOM_ORDER_HEADER_DTL_V
--  Description:     CHG0042041 - strataforce  project order header  Interface initial build
--                  used by soa
----------------------------------------------------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   9.11.17       yuval tal       CHG0042041 - strataforce  project order header  Interface initial build
--  1.1   29.05.18      Lingaraj        CHG0042041[CTASK0036894] - Added 2 new fields - Shipping Country and Shipping state
--  1.2   07.08.18      Lingaraj        CHG0043669  - need word replacment in SFDC inteface for Canada States same as done in US
--                                                    change logic of end customer_id
--  1.3   12/09/2018    Diptasurjya     CHG0043691 - Send value of Opportunity Notes attachment and calculate status value
--  1.4   14/11/2018    Lingaraj        CHG0044334 - Change in SO header interface -
--                                      Update "Complete Order Shipped Date" and "Systems Shipped Date"
----------------------------------------------------------------------------------------------------------------
 oh.header_id,
 xxssys_oa2sf_util_pkg.get_sf_so_header_id(oh.header_id) sf_header_id,
 oh.org_id,
 xxssys_oa2sf_util_pkg.get_sf_operatingunit_id(oh.org_id) sf_ou_id,
 oh.order_number order_number,
 REGEXP_REPLACE (oh.cust_po_number,'[[:cntrl:]]') cust_po_number,
 --flow_status_code, -- CHG0043691 commented and added below
 xxoe_utils_pkg.get_order_status_for_sforce(oh.header_id) flow_status_code, -- CHG0043691 added
 xxobjt_general_utils_pkg.get_lookup_meaning('FLOW_STATUS',
                     xxoe_utils_pkg.get_order_status_for_sforce(oh.header_id)/*flow_status_code - CHG0043691 commented*/)               order_status_desc,
 xxssys_oa2sf_util_pkg.get_sf_pricebook_id(
    (xxssys_oa2sf_util_pkg.get_PL_transalation(oh.price_list_id)))                 sf_price_book_id,
 hca.account_number                                                          sold_to_account_number,
 xxssys_oa2sf_util_pkg.get_sf_account_id( hca.account_number)                sf_SOLD_TO_account_id,
 nvl(hca_end_cust.account_number  ,(select t.account_number from hz_cust_accounts t where t.cust_account_id=ship_cas.cust_account_id))      end_cust_account_number,-- CHG0043669 yuval

  xxssys_oa2sf_util_pkg.get_sf_account_id( nvl(hca_end_cust.account_number,(select t.account_number from hz_cust_accounts t where t.cust_account_id=ship_cas.cust_account_id) )  )   sf_end_cust_account_id, -- CHG0043669 yuval
 ship_ps.party_site_number                                                   shipping_site_num,
 --ship_cas.attribute1                                                         sf_ship_site,----??????
 bill_ps.party_site_number                                                   billing_site_num,
-- bill_cas.attribute1                                                         sf_bill_site, ----??????
 oh.ordered_date                                                             order_date,
 oh.transactional_curr_code                                                  currency_code,
 OH.CONVERSION_RATE,
 REGEXP_REPLACE (oh.shipping_instructions,'[[:cntrl:]]') shipping_instructions,
  REGEXP_REPLACE (oh.packing_instructions,'[[:cntrl:]]')   packing_instructions,
 CASE
   WHEN xxobjt_oa2sf_interface_pkg.get_order_hold(oh.header_id) IS NOT NULL THEN
    'True'
   ELSE
    'False'
 END on_hold,
 xxobjt_oa2sf_interface_pkg.get_order_hold(oh.header_id) hold_reason,
 oh.freight_terms_code,
 oh.shipping_method_code,
 oh.order_source_id,
 oh.order_type_id,
 ott.name order_type_name,
 oh_dfv.period_end_date,
 oh_dfv.quote_no,
 xxssys_oa2sf_util_pkg.get_sf_opportunity_id(oh_dfv.quote_no)  sf_opportunity_id,
 oh.sales_channel_code sales_channel,
 oh.pricing_date pricing_date,
 xxssys_oa2sf_util_pkg.get_sf_pay_term_id(oh.payment_term_id) sf_payment_term_id,
  xxssys_oa2sf_util_pkg.get_sf_quote_id(oh_dfv.quote_no) sf_quote_id,
 oh.booked_date,
 oh.creation_date,
 oh_dfv.sys_booking_date,
 hca.cust_account_id,
 ship_ftv.territory_short_name shipping_country_name,
 ship_loc.country              shipping_country,
 ship_loc.state                shipping_state,
    (Case When ship_ftv.territory_short_name in ( 'China', 'India', 'Australia','Japan') Then
              ship_loc.state
              When ship_ftv.territory_short_name = 'Canada' Then
                 xxssys_oa2sf_util_pkg.get_state_name(ship_ftv.territory_code,
                                                     ship_loc.state) --CHG0043669
              When ship_ftv.territory_short_name = 'United States' Then
              xxobjt_general_utils_pkg.get_lookup_meaning('US_STATE',
                                                          ship_loc.state,
                                                          'N')
              Else ship_loc.state
        end) shipping_state_name,
 -- CHG0043691 added below column derivation
 (select fs.short_text
    from FND_ATTACHED_DOCS_FORM_VL fa,
         fnd_documents_short_text fs
    where category_description = 'Opportunity Notes'
      and fs.media_id = fa.media_id
      and fa.pk1_value = to_char(oh.header_id)) Oppurtunity_Notes  -- CHG0043691 end
	,(Case oh.flow_status_code
       When 'CLOSED' Then
        xxssys_oa2sf_util_pkg.get_order_complete_ship_date(oh.header_id)  --CHG0044334 14Nov18
        Else
         NULL
     End )complete_order_shipped_date
    ,xxssys_oa2sf_util_pkg.get_systems_ship_date(oh.header_id) systems_shipped_date        --CHG0044334 14NNov18
FROM   oe_order_headers_all oh,
       hz_cust_accounts     hca,
        hz_cust_accounts     hca_end_cust,
       --Shipping site details
       hz_cust_site_uses_all  ship_su,
       hz_cust_acct_sites_all ship_cas,
       hz_party_sites         ship_ps,
       hz_locations           ship_loc,
       fnd_territories_vl     ship_ftv,
       --Billing site details
       hz_cust_site_uses_all    bill_su,
       hz_cust_acct_sites_all   bill_cas,
       hz_party_sites           bill_ps,
       oe_transaction_types_tl  ott,
       oe_order_headers_all_dfv oh_dfv
WHERE
--customer details
 oh.sold_to_org_id                = hca.cust_account_id
 and oh.end_customer_id           = hca_end_cust.cust_account_id(+)
--Shipping site details
 AND    oh.ship_to_org_id         = ship_su.site_use_id
 AND    ship_su.cust_acct_site_id = ship_cas.cust_acct_site_id
 AND    ship_cas.party_site_id    = ship_ps.party_site_id
 AND    ship_loc.location_id      = ship_ps.location_id
 AND    ship_ftv.territory_code   = ship_loc.country
--Billing site details
 AND    oh.invoice_to_org_id      = bill_su.site_use_id
 AND    bill_su.cust_acct_site_id = bill_cas.cust_acct_site_id
 AND    bill_cas.party_site_id    = bill_ps.party_site_id
 AND    oh.order_type_id          = ott.transaction_type_id
 AND    ott.language              = 'US'
 AND    oh_dfv.row_id             = oh.rowid
;
