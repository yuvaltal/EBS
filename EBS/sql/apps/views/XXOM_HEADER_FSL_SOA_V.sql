CREATE OR REPLACE VIEW XXOM_HEADER_FSL_SOA_V
  AS
SELECT
--------------------------------------------------------------------
--  name        :     XXOM_HEADER_FSL_SOA_V
--  Description :
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   26.04.18       Lingaraj       CHG0042734 - FSL SO Order interface
--                                      (PRODUCT_REQUEST_HEADER OR QUOTE_HEADER)
--  1.1   03.Sep.18      Lingaraj       CTASK0038184 - Sf_header_id field Added
--------------------------------------------------------------------
event_id ,status , sync_destination_code , External_Key, sf_header_id,
Oracle_Status,On_Hold,hold_reason
From
(SELECT
       e.event_id,
       e.status,
       e.attribute2        sync_destination_code, -- PRODUCT_REQUEST_HEADER OR QUOTE_HEADER
       d.header_id         External_Key,
       xxssys_oa2sf_util_pkg.get_sf_fsl_header_id(d.header_id ,e.attribute2) sf_header_id,
       order_status_desc   Oracle_Status,
                           On_Hold,
                           hold_reason
FROM   xxssys_events           e,
       xxom_order_header_dtl_v d
WHERE  e.entity_name  = 'SO_HEADER_FSL'
AND    e.status       = 'NEW'
AND    e.target_name  = 'STRATAFORCE'
AND    d.header_id    = e.entity_id
And    sf_sold_to_account_id is not null
)
where sf_header_id != 'NOVALUE'
;
