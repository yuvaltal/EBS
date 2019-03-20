CREATE OR REPLACE VIEW XXINV_SUBINV_DTL_V
  AS
SELECT
--------------------------------------------------------------------
--  customization code: CHG0042878 - CAR stock Subinventory interface - Oracle to Salesforce
--  name:               XXINV_SUBINV_DTL_V
--  create by:          Lingaraj
--  creation date:      19.May.18
--  Description:        get subinventory data for oracle sf sync
--
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   29.May.18     Lingaraj        CHG0042878 - initial build
--------------------------------------------------------------------
ood.organization_code,
ood.organization_id,
ood.operating_unit,
xxssys_oa2sf_util_pkg.get_sf_operatingunit_id(ood.operating_unit) sf_operating_unit,
xxssys_oa2sf_util_pkg.get_sf_location_id(ood.organization_code)   sf_location_id,
msi.secondary_inventory_name,
msi.description,
msi.disable_date
from mtl_secondary_inventories msi,
     org_organization_definitions ood
where msi.organization_id = ood.organization_id
and   msi.organization_id         != 91
and   msi.secondary_inventory_name like '%CAR';
