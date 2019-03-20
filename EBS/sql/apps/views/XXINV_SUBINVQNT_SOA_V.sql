CREATE OR REPLACE VIEW XXINV_SUBINVQNT_SOA_V
  AS
SELECT
---------------------------------------------------------------------------------
--  customization code: CHG0042877 - CAR stock onhand quantity interface - Oracle to salesforce
--  name:               XXINV_SUBINVQNT_SOA_V
--  create by:          Lingaraj
--  creation date:      31.May.18
--  Description:        Used By SOA Composite to Sync Subinventory Onhand Quantity
--
---------------------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   29.May.18     Lingaraj        CHG0042877 - initial build
---------------------------------------------------------------------------------
 event_id ,status ,  sf_location_Id,sf_product_Id  , QuantityOnHand , Quantity_uom , external_key,
 nvl(is_update,'N') is_update
from
(
select
  xe.event_id,
  xe.status,
  xxssys_oa2sf_util_pkg.get_sf_location_id((xe.attribute2 ||'|' ||xe.attribute1)) sf_location_Id,
  xxssys_oa2sf_util_pkg.get_sf_product_id(xe.entity_code) sf_product_Id,
  xe.attribute4 Quantity_uom,
  (xe.attribute2 || '|'
    || xe.attribute1 || '|'
    || xe.entity_code
  ) external_key,
  xxinv_utils_pkg.get_avail_to_reserve(p_inventory_item_id => xe.Entity_id,
                                     p_organization_id     => xe.attribute3,
                                     p_subinventory        => xe.Attribute1
                                    ) QuantityOnHand,
  (
    select 'Y'
    from xxssys_events xe1
    where xe1.entity_name  = 'SUBINVQNT'
    and xe1.target_name    = 'STRATAFORCE'
    and xe1.entity_code  = xe.entity_code
    and xe1.attribute1 = xe.attribute1
    and xe1.attribute2 = xe.attribute2
    and xe1.status  = 'SUCCESS'
    and rownum = 1
  )  is_update
from xxssys_events xe
where xe.target_name = 'STRATAFORCE'
  and xe.ENTITY_NAME = 'SUBINVQNT'
  and xe.status      = 'NEW'
)
where
      sf_product_Id  != 'NOVALUE'
  and sf_location_Id != 'NOVALUE';
