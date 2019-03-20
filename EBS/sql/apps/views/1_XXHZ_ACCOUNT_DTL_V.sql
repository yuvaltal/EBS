CREATE OR REPLACE VIEW XXHZ_ACCOUNT_DTL_V AS
WITH person_rt_id AS
 (SELECT
  ----------------------------------------------------------------------------------------------------------------------------------
  --  name:     XXHZ_ACCOUNT_DTL_V
  --  Description:
  --                  used by soa
  ----------------------------------------------------------------------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   9.11.17       yuval tal       CHG0041982 - Account otacle2sfdc
  --  1.1   19.06.18      Lingaraj        CTASK0037192 - fetched value from Loopkup 'CUSTOMER_CATEGORY'
  --  1.2   22.06.18      Lingaraj        CTASK0037132 - Fetching Ship to / Bill to state logic modified
  --  1.3   28.06.18      Lingaraj        CTASK0037324  - New Fields Added to the Interface
  --  1.4   07.08.18      Lingaraj        CHG0043669  - need word replacment in SFDC inteface for Canada States same as done in US
  --  1.5   16.08.2018    Lingaraj        CHG0043760 - Remove the \KAM\ mapping from Oracle to SFDC
  --  1.6   08.11.2018    LLingaraj       CHG0044390 - Oracle to Strataforce interface
  --                                      remove the update of the parent account field in Strataforce
  --  1.7   27/12/2018    Roman W.        CHG0044757-CTASK0039860 : Development - Account interface: Oracle
  --                                            --> Salesforce - add logic to choose relevant shipping
  --                                                  information and billing information
  ----------------------------------------------------------------------------------------------------------------------------------
   id  PERSON_RT_ID from 
recordtype@source_sf2 rt
where rt.sobjecttype='Account' and developername='Person' )
SELECT hp.party_id,
       hp.party_name account_name,
       hp.attribute3 customer_operating_unit,
       hp.party_number,
       hp.category_code,
       hca.price_list_id,
       xxssys_oa2sf_util_pkg.get_sf_operatingunit_id(hp.attribute3) sf_customer_operating_unit,
       xxssys_oa2sf_util_pkg.get_sf_pricebook_id(hca.price_list_id) sf_price_list_id,
       hp.attribute11 basket_level,
       hp.duns_number_c,    
       hca.attribute19 cross_industry,
       hca.attribute16 sub_industry,
       hca.attribute14 department,
       hca.cust_account_id cust_account_id,
       hca.account_number,
       hca.status status,
       decode(xxhz_util.get_customer_industry(hp.party_id),
              'Distributor',
              'Other',
              xxhz_util.get_customer_industry(hp.party_id)) industry,
       hp.organization_name_phonetic,
       hp.party_type,
       hp.sic_code,
       contact.web, --Added CTASK0037324
       rtrim(ltrim(contact.fax_area_code ||
                   decode(contact.fax_country_code,
                          NULL,
                          NULL,
                          '-' || contact.fax_country_code) ||
                   decode(contact.fax_number,
                          NULL,
                          NULL,
                          '-' || contact.fax_number) ||
                   decode(contact.fax_extension,
                          NULL,
                          NULL,
                          '-' || contact.fax_extension),
                   '-'),
             '-') fax,--Added CTASK0037324
        rtrim(ltrim(contact.phone_area_code ||
                   decode(contact.phone_country_code,
                          NULL,
                          NULL,
                          '-' || contact.phone_country_code) ||
                   decode(contact.phone_number, NULL, NULL, '-' || contact.phone_number) ||
                   decode(contact.phone_extension, NULL, NULL, '-' || contact.phone_extension),
                   '-'),
             '-') phone,     --Added CTASK0037324
             contact.phone_contact_point_id, --Added CTASK0037324
             contact.fax_contact_point_id, --Added CTASK0037324
             contact.web_contact_point_id, --Added CTASK0037324
       xxssys_oa2sf_util_pkg.get_sf_pay_term_id((SELECT standard_terms
                                                FROM   hz_customer_profiles
                                                WHERE  cust_account_id =
                                                       hca.cust_account_id
                                                AND    site_use_id IS NULL
                                                AND    rownum = 1)) sf_payment_term_id,
       1 payment_terms,
       (SELECT hca1.account_number
        FROM   xxhz_party_ga_v  ga,
               hz_cust_accounts hca1
        WHERE  ga.cust_account_id = hca.cust_account_id
        AND    hca1.party_id = ga.parent_party_id
        AND    hca1.status = 'A'
        AND    ga.parent_party_id != ga.party_id
        AND    rownum = 1) parent_account_number,
       (SELECT attribute4
        FROM   hz_customer_profiles
        WHERE  cust_account_id = hca.cust_account_id
        AND    site_use_id IS NULL
        AND    rownum = 1) exempt_type,
       null /*o.id */ sf_owner_id,
       --CTASK0037192 - CUSTOMER_CATEGORY Fetched from Lookup -- CHG0044757 support person record type
       decode (hp.party_type,'PERSON',RT.PERSON_RT_ID  ,xxssys_oa2sf_util_pkg.get_sf_record_type_id('Account',
                                                    NVL(  XXOBJT_GENERAL_UTILS_PKG.get_lookup_attribute
                                                                    ('CUSTOMER_CATEGORY',hp.category_code,'','ATTRIBUTE2')
                                                    ,'End_Customer' )
                                                  ) ) sf_record_type_id,
       decode(
              NVL(  XXOBJT_GENERAL_UTILS_PKG.get_lookup_attribute
                        ('CUSTOMER_CATEGORY',hp.category_code,'','ATTRIBUTE2')
                         ,'End_Customer' ),
              'Channel',
              'Channel',
              'Customer') sf_type,
       ship_to_site.concatinated_address shipping_address,
       ship_to_site.city shipping_city,
       ship_to_site.country shipping_country,
       --CTASK0037132
       (Case When ship_to_site.country in ('China', 'India', 'Australia','Japan') Then
              ship_to_site.state
              When ship_to_site.country = 'Canada' Then
                   xxssys_oa2sf_util_pkg.get_state_name(ship_to_site.territory_code,
                                                     ship_to_site.state) --CHG0043669
              When ship_to_site.country = 'United States' Then
              xxobjt_general_utils_pkg.get_lookup_meaning('US_STATE',
                                                          ship_to_site.state,
                                                          'N')
              Else ship_to_site.state
        end) shipping_state,
       ship_to_site.postal_code shipping_zipcode_postal_code,
       bill_to_site.concatinated_address billing_address,
       bill_to_site.city billing_city,
       bill_to_site.country billing_country,
       --CTASK0037132
       (case when bill_to_site.country in ('China', 'India', 'Australia','Japan') Then
               bill_to_site.state
              When bill_to_site.country = 'Canada' Then
                   xxssys_oa2sf_util_pkg.get_state_name(bill_to_site.territory_code,
                                                      bill_to_site.state) --CHG0043669
              when bill_to_site.country = 'United States' Then
                xxobjt_general_utils_pkg.get_lookup_meaning('US_STATE',
                                                            bill_to_site.state,
                                                            'N')
              Else bill_to_site.state
        End) billing_state,
       bill_to_site.postal_code billing_zipcode_postal_code,
              (CASE
         WHEN hca.attribute7 IS NOT NULL THEN
          (SELECT xxssys_oa2sf_util_pkg.get_sf_pay_term_id(term_id)
           FROM   xxar_pay_term_dtl_v
           WHERE  NAME = hca.attribute7)
         ELSE
          ''
       END) hw_payment_terms_c,
       hca.attribute7 hw_default_payterm,
       hca.customer_type,
       Decode(hca.customer_type,'I','TRUE','FALSE')  internal_customer,      
       bill_to_site.site_use_id Bill_to_Site_UseID,--CTASK0037324
       bill_to_site.location_id Bill_to_LocationID,--CTASK0037324
       bill_to_site.cust_acct_site_id bill_to_cust_acct_site_id,--CTASK0037324
          --
       ship_to_site.site_use_id Ship_to_Site_UseID,--CTASK0037324
       ship_to_site.location_id Ship_to_LocationID,--CTASK0037324
       ship_to_site.cust_acct_site_id ship_to_cust_acct_site_id,--CTASK0037324
       Decode(hcp.Credit_Checking,'Y','true','false') Credit_Checking, -- CTASK0039860 addedby R.W. 27/12/2018
       Decode(hcp.credit_hold,'Y','true','false') credit_hold,         -- CTASK0039860 addedby R.W. 27/12/2018
       hcpa.overall_credit_limit, -- CTASK0039860 addedby R.W. 27/12/2018
       hcpa.trx_credit_limit      -- CTASK0039860 addedby R.W. 27/12/2018
FROM   hz_cust_accounts         hca,
       hz_parties               hp,
       person_rt_id                rt,
       xxhz_site_use_location_v bill_to_site,
       xxhz_site_use_location_v ship_to_site,
       xxhz_party_contacts_v    contact, --Added CTASK0037324
       hz_customer_profiles     hcp, -- CTASK0039860 addedby R.W. 27/12/2018
       hz_cust_profile_amts     hcpa -- CTASK0039860 addedby R.W. 27/12/2018
WHERE  bill_to_site.cust_account_id(+) = hca.cust_account_id
AND    bill_to_site.site_use_code(+) = 'BILL_TO'
AND    ship_to_site.cust_account_id(+) = hca.cust_account_id
AND    ship_to_site.site_use_code(+) = 'SHIP_TO'
AND    hp.party_type in ('PERSON','ORGANIZATION')
AND    hca.party_id = hp.party_id
AND    contact.oracle_account_id = hca.cust_account_id -- Added CTASK0037324
and    hcp.cust_account_id = hca.cust_account_id     -- CTASK0039860 addedby R.W. 27/12/2018
and    hcp.party_id = hp.party_id                    -- CTASK0039860 addedby R.W. 27/12/2018
and    hcpa.cust_account_id(+) = hcp.cust_account_id -- CTASK0039860 addedby R.W. 27/12/2018
and    hcp.site_use_id is null                       -- CTASK0039860 addedby R.W. 27/12/2018
--AND    hca.status = 'A'
and    hcpa.site_use_id(+) is null                   -- CTASK0039860 addedby R.W. 27/12/2018
;

