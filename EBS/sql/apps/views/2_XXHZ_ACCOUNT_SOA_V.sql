CREATE OR REPLACE VIEW XXHZ_ACCOUNT_SOA_V
  AS
SELECT
--------------------------------------------------------------------
--  name:     XXHZ_ACCOUNT_soa_v
--  Description:
--                  used by soa
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   9.11.17       yuval tal
--  1.1   28.06.18      Lingaraj        CTASK0037324  - New Fields Added to the Interface
--  1.2   16.08.2018    Lingaraj        CHG0043760 - Remove the \KAM\ mapping from Oracle to SFDC
--  1.3   08.11.2018    Lingaraj       CHG0044390 - Oracle to Strataforce interface
--                                      remove the update of the parent account field in Strataforce
--  1.4   27/12/2018    yuval tal        CHG0044757-CTASK0039860  add new fields
--------------------------------------------------------------------
 party_id,
 party_number,
 account_name,
 customer_operating_unit,
 sf_customer_operating_unit,
 decode(sf_price_list_id, 'NOVALUE', NULL, sf_price_list_id) sf_price_list_id,
 sf_payment_term_id,
 --sf_parent_account_id,--Commented on 8NOV2018 for CHG0044390
 basket_level,
 duns_number_c,
 --kam_customer,--CHG0043760
 cross_industry,
 sub_industry,
 department,
 cust_account_id,
 account_number,
 e.status,
 decode(d.status, 'A', 'Active', 'Inactive') account_status,
 industry,
 organization_name_phonetic,
 party_type,
 sic_code,
 web url,
 xxssys_oa2sf_util_pkg.get_sf_pay_term_id(payment_terms) payment_terms,
 xxssys_oa2sf_util_pkg.get_sf_account_id(parent_account_number) parent_account_number,
 phone phone_number,
 fax,
 e.event_id,
 exempt_type,
 sf_owner_id,
 sf_record_type_id,
 sf_type,
 (Case when replace((shipping_address||
                    shipping_city||
                    shipping_country||
                    shipping_state||
                    shipping_zipcode_postal_code
                    ),' ','')  is null
      Then
           billing_address
      Else
         shipping_address
  End) shipping_address,
  (Case when replace((shipping_address||
                    shipping_city||
                    shipping_country||
                    shipping_state||
                    shipping_zipcode_postal_code
                    ),' ','')  is null
      Then
           billing_city
      Else
         shipping_city
  End) shipping_city,
  (Case when replace((shipping_address||
                    shipping_city||
                    shipping_country||
                    shipping_state||
                    shipping_zipcode_postal_code
                    ),' ','')  is null
      Then
           billing_country
      Else
         shipping_country
  End) shipping_country,
  (Case When replace((shipping_address||
                    shipping_city||
                    shipping_country||
                    shipping_state||
                    shipping_zipcode_postal_code
                    ),' ','')  is null
      Then
           billing_state
      Else
         shipping_state
  End) shipping_state,
  (Case when replace((shipping_address||
                    shipping_city||
                    shipping_country||
                    shipping_state||
                    shipping_zipcode_postal_code
                    ),' ','')  is null
      Then
           billing_zipcode_postal_code
      Else
         shipping_zipcode_postal_code
  End) shipping_zipcode_postal_code,
 billing_address,
 billing_city,
 billing_country,
 billing_state,
 billing_zipcode_postal_code,
 d.HW_Payment_terms_c,
 d.internal_customer,
 --d.KAM_Manager_sf_id   KAM_Manager__c,--CHG0043760
 --Added on CTASK0037324
 phone_contact_point_id ExtPhoneContactPointID,
 web_contact_point_id   ExtWebContactPointID,
 fax_contact_point_id   ExtFaxContactPointID,
 --
 Bill_to_Site_UseID ExtBillSiteUseID,
 Bill_to_LocationID ExtBillLocationID,
 bill_to_cust_acct_site_id ExtBillSiteID,
 --
 Ship_to_Site_UseID ExtShipSiteUseID,
 Ship_to_LocationID ExtShipLocationID,
 ship_to_cust_acct_site_id ExtShipSiteID,
 --CTASK0037324
 Credit_Checking,       -- CTASK0039860 addedby R.W. 27/12/2018
 credit_hold,           -- CTASK0039860 addedby R.W. 27/12/2018
 overall_credit_limit, -- CTASK0039860 addedby R.W. 27/12/2018
 trx_credit_limit     -- CTASK0039860 addedby R.W. 27/12/2018
FROM   xxssys_events      e,
       xxhz_account_dtl_v d
WHERE  e.entity_name = 'ACCOUNT'
AND    e.status = 'NEW'
AND    target_name = 'STRATAFORCE'
AND    e.entity_id = d.cust_account_id;

