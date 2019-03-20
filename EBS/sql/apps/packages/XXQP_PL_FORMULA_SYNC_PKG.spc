create or replace package XXQP_PL_FORMULA_SYNC_PKG AUTHID CURRENT_USER AS
  ----------------------------------------------------------------------------
  --  name:            XXQP_PL_FORMULA_SYNC_PKG
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   07/13/2018
  ----------------------------------------------------------------------------
  --  purpose :        CHG0043433 - Package to handle interfacing formula based PLs
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  07/13/2018  Diptasurjya Chatterjee(TCS)  CHG0043433 - initial build
  ----------------------------------------------------------------------------


  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0043433
  --          This Procedure is used to generate prices of relevant items for a formula based PL
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  13/07/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE populate_pl_formula_events(errbuf  OUT VARCHAR2,
                                       retcode OUT NUMBER,
                                       p_target_name IN varchar2,
                                       p_list_header_id IN NUMBER);

end XXQP_PL_FORMULA_SYNC_PKG;
/
