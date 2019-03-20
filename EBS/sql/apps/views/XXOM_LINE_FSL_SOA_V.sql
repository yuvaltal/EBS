CREATE OR REPLACE VIEW XXOM_LINE_FSL_SOA_V
  AS
select
--------------------------------------------------------------------
--  name:     XXOM_LINE_FSL_DTL_V
--  Description:     strataforce  project order line  Interface initial build
--                  used by soa
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   10.07.18      Lingaraj        CHG0042734[CTASK0037508] - Create Order interface for FSL
-------------------------------------------------------------------------------------------------------------
event_id
,status
,sync_destination_code
,External_Key
,On_Hold_c
,Hold_Reason_c
,Oracle_Status__c
,Invoice_Number__c
,Tracking_Number__c
,Deliveries_Number__c
,sf_fsl_so_header_id
,sf_ordered_item
,Qnty_UOM
,quantity_requested
,oracle_line_number
from
(
select  e.event_id
       ,e.status
       ,e.attribute2                sync_destination_code --PRODUCT_REQUEST_LINE OR QUOTE_LINE
       ,dtl.line_id                 External_Key
       ,Decode(is_on_hold , 'Y',
                'True', 'False')    On_Hold_c
       ,dtl.hold_reason             Hold_Reason_c
       ,dtl.line_status             Oracle_Status__c
       ,dtl.invoice_number          Invoice_Number__c
       ,dtl.tracking_number         Tracking_Number__c
       ,dtl.delivery_num_with_status  Deliveries_Number__c
       ,dtl.sf_fsl_so_header_id
       ,dtl.line_number              oracle_line_number
       ,dtl.ordered_quantity         quantity_requested
       ,dtl.UOM                      Qnty_UOM
       , DTL.sf_ordered_item
from
     xxssys_events e,
     XXOM_LINE_FSL_DTL_V dtl
where e.entity_name  = 'SO_LINE_FSL'
  and e.status       = 'NEW'
  and e.target_name  = 'STRATAFORCE'
  and e.entity_id    = dtl.line_id
)
where sf_fsl_so_header_id   != 'NOVALUE';
