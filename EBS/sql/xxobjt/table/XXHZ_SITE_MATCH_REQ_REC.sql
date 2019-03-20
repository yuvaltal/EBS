create or replace type xxobjt.xxhz_site_match_req_rec FORCE AS OBJECT
(
---------------------------------------------------------------------------------
--  Name:            xxhz_site_match_req_rec
--  Created by:      Somnath Dawn
--  Revision:        1.0
-----------------------------------------------------------------------------------
-- Date:               Version         Name                  Remarks
------------------------------------------------------------------------------------
-- 12-DEC-2016          1.0            Somnath Dawn          GAP-297 - Record Type for Searching Site
-- 30-JAN-2017          1.1            Adi Safin             CHG0040057 - Change xxcust --> xxobjt
-- 12-Nov-2018          1.2            Lingaraj              CHG0042632 - SFDC2OA - Location - Sites  interface ( upsert and find)
-- 27-Dec-2018          1.3            Lingaraj              CHG0042632-CTASK0039867 - ORG_ID Added
------------------------------------------------------------------------------------
  account_id           NUMBER,
  account_number       VARCHAR2(30), --CHG0042632
  site_name            VARCHAR2(255),--CHG0042632
  site_address         VARCHAR2(255),
  site_city            VARCHAR2(50),
  site_county          VARCHAR2(200),
  site_postal_code     VARCHAR2(50),
  site_country         VARCHAR2(100),
  state                VARCHAR2(50),
  org_id               NUMBER        --CTASK0039867 ORG_ID Added
)
/
