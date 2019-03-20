CREATE OR REPLACE VIEW XXHZ_SITE_DTL_V AS
SELECT
---------------------------------------------------------------------------------
-- Ver      When        Who      Desc
-- -------  ----------  -------  ------------------------------------------------
--  1.0     27-03-2018  Roman.W  CHG0042560 : Sites - Locations oa2sf interface
--  1.1     13.Nov.2018 Lingaraj CHG0042632 - SFDC2OA - Location - Sites  interface
--                               New field Added Site_Name
--  1.2    10.1.19    yuval tal  CHG0042632 - change state logic 
---------------------------------------------------------------------------------
     Substr(site_usage || ' - ' || site_address ,1 ,255) Location_Name,
     cust_account_id,
     account_number,--CHG0042632
     sf_account_id,
     oracle_site_id,
     oracle_site_number,
     org_id,
     sf_operating_unit_id,
     price_list_id,
     decode(xxssys_oa2sf_util_pkg.get_sf_pricebook_id(price_list_id), 'NOVALUE', null, xxssys_oa2sf_util_pkg.get_sf_pricebook_id(price_list_id)) sf_price_list_id,
     payment_term_id,
     xxssys_oa2sf_util_pkg.get_sf_pay_term_id(payment_term_id) sf_payment_term_id,
     freight_term,
     xxssys_oa2sf_util_pkg.get_sf_freight_term_id(freight_term) sf_freight_term_id,
     shipping_method,
     location_type,
     site_usage,
     primary_bill_to,
     primary_ship_to,
     site_status,
     bill_site_use_id,
     ship_site_use_id,
     site_address,
     site_city,
     site_postal_code,
     site_county,
     province,
     site_state,
     site_country,
     location,
     location_id,
     party_name, --CHG0042632
     party_site_id, --CHG0042632
     party_type     --CHG0042632
FROM (SELECT hca.cust_account_id,
             hca.account_number,--CHG0042632
             xxssys_oa2sf_util_pkg.get_sf_account_id(hca.Account_Number) sf_account_id,
             hcasa.cust_acct_site_id oracle_site_id,
             hps.party_site_number oracle_site_number,
             hp.party_name, --CHG0042632
             hps.party_site_id,--CHG0042632
             hp.party_type, --CHG0042632
             hcasa.org_id,
             xxssys_oa2sf_util_pkg.get_sf_operatingunit_id(hcasa.org_id) sf_operating_unit_id,
             nvl(nvl(bill_to.price_list_id, hca.price_list_id),
                 ship_to.price_list_id) price_list_id,
             nvl(nvl(bill_to.payment_term_id,
                     (SELECT hcp.standard_terms
             FROM   hz_customer_profiles hcp
             WHERE  hcp.site_use_id IS NULL
             AND    hcp.cust_account_id = hca.cust_account_id)),
                 ship_to.payment_term_id) payment_term_id,
             nvl(bill_to.freight_term, ship_to.freight_term) freight_term,
             (SELECT WCSV.SHIP_METHOD_MEANING
                FROM WSH_CARRIER_SERVICES_V WCSV, WSH_ORG_CARRIER_SERVICES_V WOCSV
               WHERE WCSV.CARRIER_SERVICE_ID = WOCSV.CARRIER_SERVICE_ID
                 AND WCSV.ENABLED_FLAG = 'Y'
                 AND WOCSV.ENABLED_FLAG = 'Y'
                 AND  WCSV.SHIP_METHOD_CODE = ship_to.ship_via
                 AND ROWNUM = 1
             ) shipping_method,
             'Site' location_type,
             CASE
               WHEN bill_to.site_use_code IS NOT NULL AND
                    ship_to.site_use_code IS NOT NULL THEN
                'Bill To/Ship To'
               WHEN bill_to.site_use_code IS NOT NULL AND
                    ship_to.site_use_code IS NULL THEN
                'Bill To'
               ELSE
                'Ship To'
             END site_usage,
             decode(bill_to.primary_flag, 'Y', 'True', 'False') primary_bill_to,
             decode(ship_to.primary_flag, 'Y', 'True', 'False') primary_ship_to,
             decode(hcasa.status, 'A', 'Active', 'I', 'Inactive') site_status,
             bill_to.site_use_id bill_site_use_id,
             ship_to.site_use_id ship_site_use_id,
             regexp_replace(hl.address1 ||
                  nvl2(hl.address2, (', ' || hl.address2), NULL) ||
                  nvl2(hl.address3, (', ' || hl.address3), NULL) ||
                  nvl2(hl.address4, (', ' || hl.address4), NULL),
                  '[[:cntrl:]]',
                  '') site_address,
             hl.city site_city,
             hl.postal_code site_postal_code,
             hl.county site_county,
             hl.province,
             case  when ftt.territory_short_name in ( 'Japan','China','Canada','India','Australia')  then 
                      ( select gg.geography_name
                        from apps.hz_hierarchy_nodes nd, apps.hz_geographies gg,apps.hz_geographies g
                       where parent_table_name = 'HZ_GEOGRAPHIES'
                         and nd.parent_object_type = 'COUNTRY'
                         and nd.child_object_type = 'STATE'
                         and nd.parent_id = g.geography_id
                         and gg.geography_id = nd.child_id
                         and (gg.geography_code=hl.state or gg.geography_name=hl.state)
                         and g.geography_name =ftt.territory_short_name)            
                   when ftt.territory_short_name= 'United States'  then 
                    xxobjt_general_utils_pkg.get_lookup_meaning('US_STATE', hl.state,'N')
                   else  hl.state end  site_state, -- yuval state logic changed 
             ftt.territory_short_name site_country,
             CASE
               WHEN bill_to.site_use_code IS NOT NULL AND
                    ship_to.site_use_code IS NOT NULL THEN
                bill_to.location
               WHEN bill_to.site_use_code IS NOT NULL AND
                    ship_to.site_use_code IS NULL THEN
                bill_to.location
               ELSE
                ship_to.location
             END location,
             hl.location_id
     FROM  hz_cust_accounts       hca,
           hz_parties             hp,
           hz_locations           hl,
           hz_party_sites         hps,
           hz_cust_acct_sites_all hcasa,
           hz_cust_site_uses_all  bill_to,
           hz_cust_site_uses_all  ship_to,
           fnd_territories_tl     ftt
    WHERE  hca.party_id = hp.party_id
    AND    hca.cust_account_id = hcasa.cust_account_id
    AND    hps.location_id = hl.location_id
    AND    hps.party_site_id = hcasa.party_site_id
    AND    ftt.territory_code = hl.country
    AND    ftt.language = 'US'
    AND    hcasa.org_id = bill_to.org_id(+) --hp.attribute3
    AND    hcasa.org_id = ship_to.org_id(+)
    AND    hcasa.cust_acct_site_id = bill_to.cust_acct_site_id(+)
    AND    bill_to.site_use_code(+) = 'BILL_TO'
    AND    bill_to.status(+) = 'A'
    AND    hcasa.cust_acct_site_id = ship_to.cust_acct_site_id(+)
    AND    ship_to.site_use_code(+) = 'SHIP_TO'
    AND    ship_to.status(+) = 'A'
    AND    hcasa.org_id != 89) a
;
