CREATE OR REPLACE VIEW XXHZ_SITE_USE_LOCATION_V AS
SELECT      
-----------------------------------------------------------------------------------------------
--  name:     XXHZ_ACCOUNT_DTL_V
--  Description:
--                  used by soa
-----------------------------------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   9.11.17       yuval tal       CHG0041982 - Account otacle2sfdc
--  1.1   28.6.18       Lingaraj        CTASK0037324- New Field Added to Account Interface
--  1.2   27/12/2018    Roman W.        CHG0044757-CTASK0039860 Account interface: Oracle --> 
--                                          Salesforce - add logic to choose relevant shipping 
--                                               information and billing information
-----------------------------------------------------------------------------------------------
      hca.cust_account_id,
       HPS.PARTY_SITE_ID,
       hcasa1.cust_acct_site_id,
       hca.account_number       customer_number,
       hp.party_name            customer_name,
       hps.party_site_number    site_number,
       trim(hl.address1  || ' ' || hl.address2 || ' ' || hl.address3  || ' ' || hl.address4) concatinated_address,
       hl.address1              address1,
       hl.address2              address2,
       hl.address3              address3,
       hl.address4              address4,
       hl.city                  city,
       hl.postal_code           postal_code,
       hl.state                 state,
       hl.province,
       ftt.territory_code,
       ftt.territory_short_name country,
       hcsua1.primary_flag bill_primary_flag,
       hcsua1.location          bill_to_location ,
       hcsua1.site_use_code,
       hcsua1.site_use_id,        -- CTASK0037324
       hl.location_id            -- CTASK0037324
FROM   hz_parties               hp,
       hz_party_sites           hps,
       hz_cust_accounts         hca,
       hz_cust_acct_sites_all   hcasa1,
       hz_cust_site_uses_all    hcsua1,
       hz_locations             hl,
       fnd_territories_tl       ftt
WHERE  hp.party_id = hps.party_id
AND    hp.party_id = hca.party_id
AND    hca.cust_account_id = hcasa1.cust_account_id
AND    hcasa1.party_site_id = hps.party_site_id
AND    hcsua1.cust_acct_site_id = hcasa1.cust_acct_site_id
AND    hcsua1.site_use_code in ('SHIP_TO', 'BILL_TO')
AND    hcasa1.org_id=hcsua1.org_id
AND    hps.location_id = hl.location_id
AND    hl.country = ftt.territory_code
AND    ftt.language = 'US'
and    hcsua1.Primary_Flag='Y'
AND    hcsua1.Status='A'
and    hcasa1.status='A'
and    hps.status='A'
and    hca.status='A'
and    hp.attribute3=hcasa1.org_id -- CTASK0039860 addedby R.W. 27/12/2018 
