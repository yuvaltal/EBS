CREATE OR REPLACE VIEW XXINV_SUBINV_SOA_V
  AS
SELECT
--------------------------------------------------------------------
--  customization code: CHG0042878 - CAR stock Subinventory interface - Oracle to Salesforce
--  name:               XXINV_SUBINV_SOA_V
--  create by:          Lingaraj
--  creation date:      19.May.18
--  Description:        get subinventory data for oracle sf sync
--
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   29.May.18     Lingaraj        CHG0042878 - initial build
--------------------------------------------------------------------
e.event_id,
e.status,
(dtl.organization_code||'|'||dtl.secondary_inventory_name) External_Key__C,
dtl.secondary_inventory_name name,
dtl.sf_location_id ParentLocationId,
dtl.sf_operating_unit,
'Van' LocationType,
dtl.Description,
dtl.disable_date CloseDate,
'True' IsInventoryLocation,
'True' IsMobile

from xxssys_events e,
     xxinv_subinv_dtl_v dtl
Where e.entity_name = 'SUBINV'
AND   e.status      = 'NEW'
AND   e.target_name = 'STRATAFORCE'
AND   e.entity_code = (dtl.organization_code||'|'||dtl.secondary_inventory_name)
AND   dtl.sf_location_id <> 'NOVALUE';
