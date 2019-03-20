CREATE OR REPLACE PACKAGE xxssys_sync_ship_doc_pkg AS

  ----------------------------------------------------------------------------
  --  name:          xxssys_sync_ship_doc
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 08/07/2018
  ----------------------------------------------------------------------------
  --  purpose :      CHG0043434: Sales Order and shipping documents needs to be
  --                 interfaced to Strataforce
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  08/07/2018  Diptasurjya Chatterjee  CHG0043434 - initial build
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0043434
  --          This function will be used as Rule function for custom business event registered
  --          for order booking stage
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  08/07/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION book_event_process(p_subscription_guid IN RAW,
                              p_event             IN OUT NOCOPY wf_event_t)
    RETURN VARCHAR2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0043434
  --          This function will be used as Rule function for business event
  --          for order ship confirm stage
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  08/07/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION shipconfirm_event_process(p_subscription_guid IN RAW,
                                     p_event             IN OUT NOCOPY wf_event_t)
    RETURN VARCHAR2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0043434
  --          This function will check if order is eligible for document generation call
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  08/07/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  function chk_order_eligibility(p_header_id number) return varchar2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0043434
  --          This function will check if delivery is eligible for document generation call
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  08/07/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  function chk_delivery_eligibility(p_delivery_id number) return varchar2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0043434
  --          This procedure will handle generation of order booking stage documents
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  08/07/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  procedure handle_order_book_docs(p_header_id      in number,
                                   p_org_id         in number,
                                   p_doc_set_code   in varchar2,
                                   x_status         out varchar2,
                                   x_status_message out varchar2);

END xxssys_sync_ship_doc_pkg;
/
