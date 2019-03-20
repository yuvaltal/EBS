create or replace package xxcs_upgrade_ib_upon_shipp_pkg IS
  --------------------------------------------------------------------
  --  name:               XXCS_UPGRADE_IB_UPON_SHIPP_PKG
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      15.07.2015
  --  Purpose :           CHG0035439 ¿ Rule Advisor for Objet 1000 - upgrade IB upon Order shipping
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15.07.2015    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  TYPE t_oa2sf_rec IS RECORD(
    status       VARCHAR2(50), -- NEW/IN-PROCESS/ERR/SUCCESS
    process_mode VARCHAR2(50), -- INSERT/UPDATE
    source_id    VARCHAR2(50), -- oracle_id
    source_id2   VARCHAR2(50),
    source_name  VARCHAR2(50), -- ACCOUNT/SITE/¿.
    sf_id        VARCHAR2(250)); --sf_id

  --------------------------------------------------------------------
  --  name:               main
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      15.07.2015
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  15.07.2015    Michal Tzvik     CHG0035439 - initial build
  --------------------------------------------------------------------
  PROCEDURE main(errbuf  OUT VARCHAR2,
                 retcode OUT VARCHAR2);

END xxcs_upgrade_ib_upon_shipp_pkg;
/