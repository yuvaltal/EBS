create or replace type xxobjt.xxhz_site_match_resp_rec FORCE AS OBJECT
(
---------------------------------------------------------------------------------
--  Name:            xxhz_site_match_resp_rec
--  Created by:      Somnath Dawn
--  Revision:        1.0
-----------------------------------------------------------------------------------
-- Date:               Version         Name                  Remarks
------------------------------------------------------------------------------------
-- 12-DEC-2016          1.0            Somnath Dawn          GAP-297 - Record Type for Response of searching Site
-- 30-JAN-2017          1.1            Adi Safin             CHG0040057 - Change xxcust --> xxobjt
-- 12-Nov-2018          1.2            Lingaraj              CHG0042632 - SFDC2OA - Location - Sites  interface ( upsert and find)
-- 27-Dec-2018          1.3            LLingaraj             CHG0042632- CTASK0039867 - ORG_ID Added
------------------------------------------------------------------------------------
  account_id           NUMBER,
  account_number       VARCHAR2(255),
  account_name         VARCHAR2(100),
  org_id               NUMBER, --CHG0042632- CTASK0039867 - ORG_ID Added
  org_name             VARCHAR2(50), -- CHG0042632 added by R.W
  site_id              NUMBER,
  site_address         VARCHAR2(240),
  site_city            VARCHAR2(50),
  site_county          VARCHAR2(50),
  state                VARCHAR2(50),
  site_country         VARCHAR2(100),
  site_postal_code     VARCHAR2(50),
  site_number          VARCHAR2(255),
  location_name        VARCHAR2(255),
  site_usage     	   VARCHAR2(100),
  site_status	       VARCHAR2(10),
  shipping_method	   VARCHAR2(200),
  oe_bill_site_use_id  NUMBER,
  oe_ship_site_use_id  NUMBER,
  oe_location_id       NUMBER,
  match_percentage     NUMBER,
  message			   VARCHAR2(1000)
)
/
CREATE OR REPLACE TYPE XXOBJT.XXHZ_SITE_MATCH_RESP_TAB is
table of XXOBJT.XXHZ_SITE_MATCH_RESP_REC
/