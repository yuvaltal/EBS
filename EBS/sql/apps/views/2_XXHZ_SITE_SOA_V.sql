CREATE OR REPLACE VIEW XXHZ_SITE_SOA_V
  AS
SELECT
----------------------------------------------------------------------------------
-- Ver      When        Who      Desc
-- -------  ----------  -------  -------------------------------------------------
--  1.0     27-03-2018  Roman.W  CHG0042560 : Sites - Locations oa2sf interface
----------------------------------------------------------------------------------
        xe.event_id,
        xe.status,
        xsdv.Location_Name,
        xsdv.cust_account_id,
        xsdv.sf_account_id,
        xsdv.oracle_site_id,
        xsdv.oracle_site_number,
        xsdv.org_id,
        xsdv.sf_operating_unit_id,
        xsdv.price_list_id,
        xsdv.sf_price_list_id,
        xsdv.payment_term_id,
        xsdv.sf_payment_term_id,
        xsdv.freight_term,
        xsdv.sf_freight_term_id,
        xsdv.shipping_method,
        xsdv.location_type,
        xsdv.site_usage,
        xsdv.primary_bill_to,
        xsdv.primary_ship_to,
        xsdv.site_status,
        xsdv.bill_site_use_id,
        xsdv.ship_site_use_id,
        xsdv.site_address,
        xsdv.site_city,
        xsdv.site_postal_code,
        xsdv.site_county,
        xsdv.province,
        xsdv.site_state,
        xsdv.site_country,
        xsdv.location,
        xsdv.location_id
from    xxssys_events xe,
        xxhz_site_dtl_v xsdv
where   xe.entity_name = 'SITE'
and     xe.status      = 'NEW'
and     xe.target_name = 'STRATAFORCE'
and     xe.entity_ID = xsdv.oracle_site_id
and     xsdv.sf_account_id IS NOT NULL
;
