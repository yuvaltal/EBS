create or replace package body xxobjt_custom_events_pkg AS

  -- ---------------------------------------------------------------------------------
  -- Name:       XXOBJT_CUSTOM_EVENTS_PKG
  -- Created By: MMAZANET
  -- Revision:   1.0
  -- ---------------------------------------------------------------------------------
  -- Purpose: This package will be multi-purpose:
  --          1) It will be used for handling custom events from Oracle applications
  --          2) This can also be used for error logging by calling the insert_error_event
  --             procedure.  This can be called from any code unit.  An alert called
  --             'XXOBJT_ERROR_RPT' has been built on this table to report any errors.
  --
  --          This package also contains a procedure called delete_event_tbl.  This
  --          can be used to clear records from this table periodically.
  -- ---------------------------------------------------------------------------------
  -- Ver  Date        Performer       Comments
  -- ...  ..........  ..........      ....................................................
  -- 1.0  03/14/2014  MMAZANET        Initial Creation for CHG0031323.
  -- 1.1  06.04.14    yuval tal       CUST776 - Customer support SF-OA interfaces\CR 1215
  --                                  add handle_events/om_events/ar_events
  -- 1.2  12/03/2015  Dalit A. Raviv  CHG0034735 proc cs_events - add upgrade kit transfer to SF
  -- 1.3  21/07/2015  Michal Tzvik    CHG0035439 -  PROCEDURE cs_events: change cursor to insert rows with upgrade_kit only
  -- 1.4  04.Jun.18   Lingaraj        CHG0041829 - Strataforce Event Generation
  -- 1.5  03-Oct-2018 Lingaraj        CHG0043859 - Install base interface changes from Oracle to salesforce
  -- 1.6  25/01/2019  Roman W.        INC0145246 - 
  -- ---------------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Inserts error events into event table
  -- --------------------------------------------------------------------------------------------
  PROCEDURE insert_error_event(p_error_msg    IN VARCHAR2,
                               p_calling_prog IN VARCHAR2,
                               p_attribute5   IN VARCHAR2 DEFAULT NULL,
                               p_attribute6   IN VARCHAR2 DEFAULT NULL,
                               p_attribute7   IN VARCHAR2 DEFAULT NULL,
                               p_attribute8   IN VARCHAR2 DEFAULT NULL,
                               p_attribute9   IN VARCHAR2 DEFAULT NULL,
                               p_attribute10  IN VARCHAR2 DEFAULT NULL,
                               p_attribute11  IN VARCHAR2 DEFAULT NULL,
                               p_attribute12  IN VARCHAR2 DEFAULT NULL,
                               p_attribute13  IN VARCHAR2 DEFAULT NULL,
                               p_attribute14  IN VARCHAR2 DEFAULT NULL,
                               p_attribute15  IN VARCHAR2 DEFAULT NULL) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_rec xxobjt_custom_events%ROWTYPE;
  BEGIN
    l_rec.event_key   := 'ERROR';
    l_rec.event_name  := 'ERROR';
    l_rec.event_table := 'ERROR';

    l_rec.event_id          := xxobjt_custom_events_s.nextval;
    l_rec.attribute1        := substr(p_calling_prog, 1, 240);
    l_rec.attribute2        := substr(p_error_msg, 1, 240);
    l_rec.attribute3        := userenv('SESSIONID');
    l_rec.attribute4        := fnd_global.conc_request_id;
    l_rec.event_id          := xxobjt.xxobjt_custom_events_s.nextval;
    l_rec.created_by        := to_number(fnd_profile.value('USER_ID'));
    l_rec.creation_date     := SYSDATE;
    l_rec.last_updated_by   := to_number(fnd_profile.value('USER_ID'));
    l_rec.last_update_date  := SYSDATE;
    l_rec.last_update_login := to_number(fnd_profile.value('LOGIN_ID'));

    INSERT INTO xxobjt_custom_events
    VALUES l_rec;
    COMMIT;
  END insert_error_event;

  -- --------------------------------------------------------------------------------------------
  -- Inserts custom events into event table
  -- --------------------------------------------------------------------------------------------
  PROCEDURE insert_event(p_rec IN xxobjt_custom_events%ROWTYPE) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_rec xxobjt_custom_events%ROWTYPE;
  BEGIN
    l_rec                   := p_rec;
    l_rec.event_id          := xxobjt_custom_events_s.nextval;
    l_rec.created_by        := to_number(fnd_profile.value('USER_ID'));
    l_rec.creation_date     := SYSDATE;
    l_rec.last_updated_by   := to_number(fnd_profile.value('USER_ID'));
    l_rec.last_update_date  := SYSDATE;
    l_rec.last_update_login := to_number(fnd_profile.value('LOGIN_ID'));

    INSERT INTO xxobjt_custom_events
    VALUES l_rec;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      insert_error_event('XXOBJT_CUSTOM_EVENTS_PKG.INSERT_EVENT', 'Error occurred in insert_event for' ||
                          ' event_name ' ||
                          p_rec.event_name ||
                          ' event_table ' ||
                          p_rec.event_table ||
                          ' event_key ' ||
                          p_rec.event_key ||
                          ' : ' ||
                          SQLERRM);
  END insert_event;

  -- --------------------------------------------------------------------------------------------
  -- Used to clean event table
  -- --------------------------------------------------------------------------------------------
  PROCEDURE delete_event_tbl(errbuff       OUT VARCHAR2,
                             retcode       OUT NUMBER,
                             p_event_id    IN NUMBER,
                             p_event_name  IN VARCHAR2,
                             p_event_table IN VARCHAR2,
                             p_event_key   IN VARCHAR2,
                             p_date_from   IN VARCHAR2,
                             p_date_to     IN VARCHAR2,
                             p_truncate    IN VARCHAR2) IS
    l_message VARCHAR2(255);
    e_error EXCEPTION;
  BEGIN
    fnd_file.put_line(fnd_file.output, 'Report Output');
    fnd_file.put_line(fnd_file.output, '************************************');
    IF p_event_id IS NULL AND p_event_name IS NULL AND
       p_event_table IS NULL AND p_date_from IS NULL AND p_date_to IS NULL AND
       p_truncate IS NULL THEN
      l_message := 'Error: At least one parameter must be populated.';
      RAISE e_error;
    END IF;

    IF (p_date_from IS NOT NULL AND p_date_to IS NULL) OR
       (p_date_from IS NULL AND p_date_to IS NOT NULL) THEN
      l_message := 'Error: both date parameters must be populated.';
      RAISE e_error;
    END IF;

    IF p_truncate = 'Y' THEN
      EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt_custom_events';
      fnd_file.put_line(fnd_file.output, 'Table Truncated');
    ELSE

      DELETE FROM xxobjt_custom_events
      WHERE  event_id = nvl(p_event_id, event_id)
      AND    event_name = nvl(p_event_name, event_name)
      AND    event_table = nvl(p_event_table, event_table)
      AND    creation_date BETWEEN
             nvl(fnd_date.canonical_to_date(p_date_from), to_date('01011889', 'DDMMYYYY')) AND
             nvl(fnd_date.canonical_to_date(p_date_to), to_date('31124792', 'DDMMYYYY'));

      fnd_file.put_line(fnd_file.output, 'Total Records Deleted: ' ||
                         SQL%ROWCOUNT);
    END IF;
    retcode := 0;
  EXCEPTION
    WHEN e_error THEN
      fnd_file.put_line(fnd_file.output, l_message);
      retcode := 2;
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.output, 'Error occurred ' || SQLERRM);
      retcode := 2;
  END delete_event_tbl;

  --------------------------------------------------------------------
  --  name:            xxobjt_event_pkg
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   4.3.14
  --------------------------------------------------------------------
  --  purpose :        global account pricing
  --------------------------------------------------------------------
  --  ver    date          name             desc
  --  1.0    4.3.14    yuval tal        Initial Build

  FUNCTION get_last_fetch_date(p_source_name VARCHAR2) RETURN DATE IS
    l_date VARCHAR2(100);

  BEGIN

    l_date := xxobjt_general_utils_pkg.get_valueset_desc('XXOBJT_EVENT_TABLE_NAME', p_source_name);
    RETURN nvl(to_date(l_date, 'DDMMYYYY HH24MISS'), SYSDATE);
    -- RETURN SYSDATE - 180;
  END;

  --------------------------------------------------------------------
  -- handle_events
  -------------------------------------------
  --  purpose :  FUTURE USE : WILL RAISE CUSTOM EVENT
  --
  --------------------------------------------------------------------
  --  ver    date          name             desc
  --  1.0    4.3.14     yuval tal           CUST776 CR 1215 intial build , Customer support SF-OA interfaces
  -------------------------------------------
  PROCEDURE handle_events(errbuf  OUT VARCHAR2,
                          retcode OUT VARCHAR2) IS

    /* CURSOR c_event IS
    SELECT *
    FROM   xxobjt_custom_events;*/

  BEGIN
    NULL;
  END;

  --------------------------------------------------------------------
  -- om_events
  --------------------------------------------------------------------
  --  purpose : audit om changes
  --------------------------------------------------------------------
  --  ver    date          name             desc
  --  1.0    4.3.14     yuval tal           CUST776 CR 1215 intial build , Customer support SF-OA interfaces
  --  1.1    04.Jun.18  Lingaraj            CHG0041829 - Strataforce Event Generation
  -------------------------------------------------------------------------

  PROCEDURE om_events(errbuf            OUT VARCHAR2,
                      retcode           OUT VARCHAR2,
                      p_last_date_check VARCHAR2) IS

    l_last_query_date    DATE;
    l_current_query_date DATE := SYSDATE;
    l_rec                xxobjt_custom_events%ROWTYPE;
    l_out                VARCHAR2(50);
    CURSOR c_ord(c_last_query_date DATE) IS
      SELECT *
      FROM   oe_order_headers_all t
      WHERE  t.last_update_date > c_last_query_date
      ORDER  BY t.last_update_date;

    CURSOR c_ord_line(c_last_query_date DATE) IS
      SELECT *
      FROM   oe_order_lines_all t
      WHERE  t.last_update_date > c_last_query_date
      ORDER  BY t.last_update_date;

    CURSOR c_ord_hold(c_last_query_date DATE) IS
      SELECT *
      FROM   oe_order_holds_all t
      WHERE  t.last_update_date > c_last_query_date
      ORDER  BY t.last_update_date;

    --
    CURSOR c_wsh_line(c_last_query_date DATE) IS
      SELECT *
      FROM   wsh_delivery_details t
      WHERE  t.last_update_date > c_last_query_date
      ORDER  BY t.last_update_date;

  BEGIN
    --  get last_update_date for event_name
    --  last_update_date := get_last_update_date

    -- order  header events

    BEGIN

      fnd_file.put_line(fnd_file.log, 'Start oe_order_header_all events ');

      l_current_query_date := SYSDATE;
      l_rec.source_name    := 'xxobjt_event_pkg.om_events';
      l_rec.event_table    := 'OE_ORDER_HEADERS_ALL';
      IF p_last_date_check IS NOT NULL THEN

        l_last_query_date := fnd_date.canonical_to_date(p_last_date_check);
      ELSE

        l_last_query_date := get_last_fetch_date(l_rec.event_table);
      END IF;

      FOR i IN c_ord(l_last_query_date) LOOP
        l_rec.event_key := i.header_id;
        IF i.creation_date > l_last_query_date THEN
          -- insert event
          l_rec.event_name := 'SO_HEADER_CREATE';
          insert_event(l_rec);
        ELSIF i.last_update_date > l_last_query_date THEN
          -- update event
          l_rec.event_name := 'SO_HEADER_UPDATE';
          insert_event(l_rec);
        END IF;

      END LOOP;
      COMMIT;
      fnd_flex_val_api.update_independent_vset_value(p_flex_value_set_name => 'XXOBJT_EVENT_TABLE_NAME', p_flex_value => l_rec.event_table, p_description => to_char(l_current_query_date, 'DDMMYYYY HH24MISS'), x_storage_value => l_out);

      COMMIT;

    EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        errbuf  := 'Failed oe_order_header_all events - ' ||
                   substr(SQLERRM, 1, 240);
        retcode := 2;

    END;

    -- order  line  events

    BEGIN

      fnd_file.put_line(fnd_file.log, 'Start oe_order_line_all events ');
      l_rec.event_table := 'OE_ORDER_LINES_ALL';
      IF p_last_date_check IS NOT NULL THEN

        l_last_query_date := fnd_date.canonical_to_date(p_last_date_check);
      ELSE

        l_last_query_date := get_last_fetch_date(l_rec.event_table);
      END IF;
      l_current_query_date := SYSDATE;
      FOR i IN c_ord_line(l_last_query_date) LOOP
        l_rec.event_key := i.line_id;
        IF i.creation_date > l_last_query_date THEN
          -- insert event
          l_rec.event_name := 'SO_LINE_CREATE';
          insert_event(l_rec);
        ELSIF i.last_update_date > l_last_query_date THEN
          -- update event
          l_rec.event_name := 'SO_LINE_UPDATE';
          insert_event(l_rec);
        END IF;

      END LOOP;

      COMMIT;
      fnd_flex_val_api.update_independent_vset_value(p_flex_value_set_name => 'XXOBJT_EVENT_TABLE_NAME', p_flex_value => l_rec.event_table, p_description => to_char(l_current_query_date, 'DDMMYYYY HH24MISS'), x_storage_value => l_out);
      COMMIT;

    EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        errbuf  := 'Failed oe_order_line_all events - ' ||
                   substr(SQLERRM, 1, 240);
        retcode := 2;

    END;

    -- hold  events  ---------------------
    BEGIN

      fnd_file.put_line(fnd_file.log, 'Start oe_order_holds_all events ');
      l_current_query_date := SYSDATE;
      l_rec.event_table    := 'OE_ORDER_HOLDS_ALL';
      IF p_last_date_check IS NOT NULL THEN

        l_last_query_date := fnd_date.canonical_to_date(p_last_date_check);
      ELSE

        l_last_query_date := get_last_fetch_date(l_rec.event_table);
      END IF;
      FOR i IN c_ord_hold(l_last_query_date) LOOP
        l_rec.event_key := i.order_hold_id;
        IF i.creation_date > l_last_query_date THEN
          -- insert event
          l_rec.event_name := 'SO_HOLD_CREATE';
          insert_event(l_rec);
        ELSIF i.last_update_date > l_last_query_date THEN
          -- update event
          l_rec.event_name := 'SO_HOLD_UPDATE';
          insert_event(l_rec);
        END IF;

      END LOOP;
      COMMIT;
      fnd_flex_val_api.update_independent_vset_value(p_flex_value_set_name => 'XXOBJT_EVENT_TABLE_NAME', p_flex_value => l_rec.event_table, p_description => to_char(l_current_query_date, 'DDMMYYYY HH24MISS'), x_storage_value => l_out);
      COMMIT;

    EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        errbuf  := 'Failed  oe_order_holds_all events - ' ||
                   substr(SQLERRM, 1, 240);
        retcode := 2;

    END;

    --Begin CHG0041829
    -- WSH Delivery Details  line  events
    BEGIN

      fnd_file.put_line(fnd_file.log, 'Start WSH_DELIVERY_DETAILS events ');
      l_rec.event_table := 'WSH_DELIVERY_DETAILS';

      IF p_last_date_check IS NOT NULL THEN
        l_last_query_date := fnd_date.canonical_to_date(p_last_date_check);
      ELSE
        l_last_query_date := get_last_fetch_date(l_rec.event_table);
      END IF;

      l_current_query_date := SYSDATE;

      FOR i IN c_wsh_line(l_last_query_date) LOOP
        l_rec.event_key := i.source_line_id;
        IF i.creation_date > l_last_query_date THEN
          -- insert event
          l_rec.event_name := 'WSH_LINE_CREATE';
          insert_event(l_rec);
        ELSIF i.last_update_date > l_last_query_date THEN
          -- update event
          l_rec.event_name := 'WSH_LINE_UPDATE';
          insert_event(l_rec);
        END IF;

      END LOOP;

      COMMIT;
      fnd_flex_val_api.update_independent_vset_value(p_flex_value_set_name => 'XXOBJT_EVENT_TABLE_NAME', p_flex_value => l_rec.event_table, p_description => to_char(l_current_query_date, 'DDMMYYYY HH24MISS'), x_storage_value => l_out);
      COMMIT;

    EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        errbuf  := 'Failed WSH_DELIVERY_DETAILS events - ' ||
                   substr(SQLERRM, 1, 240);
        retcode := 2;
    END;
    --End CHG0041829
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Failed xxobjt_event_pkg.om_events - ' ||
                 substr(SQLERRM, 1, 240);
      retcode := 2;
  END;

  --------------------------------------------------------------------
  -- ar_events
  --------------------------------------------------------------------
  --  purpose :  audit new ar events
  --
  --------------------------------------------------------------------
  --  ver    date          name             desc
  --  1.0    4.3.14     yuval tal           CUST776 CR 1215 intial build , Customer support SF-OA interfaces
  ---------------------------------------------------------------------
  PROCEDURE ar_events(errbuf            OUT VARCHAR2,
                      retcode           OUT VARCHAR2,
                      p_last_date_check VARCHAR2) IS

    l_last_query_date    DATE;
    l_rec                xxobjt_custom_events%ROWTYPE;
    l_current_query_date DATE;
    CURSOR c_ar_trx(c_last_query_date DATE) IS
      SELECT *
      FROM   ra_customer_trx_lines_all t
      WHERE  t.creation_date > c_last_query_date
      AND    t.line_type = 'LINE'
      ORDER  BY t.last_update_date;

    l_out VARCHAR2(50);
  BEGIN
    --  get last_update_date for event_name
    --  last_update_date := get_last_update_date

    -- order  header events

    l_current_query_date := SYSDATE;
    l_rec.source_name    := 'xxobjt_event_pkg.ar_events';
    l_rec.event_table    := 'RA_CUSTOMER_TRX_LINES_ALL';
    IF p_last_date_check IS NOT NULL THEN

      l_last_query_date := fnd_date.canonical_to_date(p_last_date_check);
    ELSE

      l_last_query_date := get_last_fetch_date(l_rec.event_table);
    END IF;

    FOR i IN c_ar_trx(l_last_query_date) LOOP
      l_rec.event_key := i.customer_trx_line_id;
      -- insert event
      l_rec.event_name := 'RA_TRX_CREATE';
      insert_event(l_rec);

    END LOOP;

    fnd_flex_val_api.update_independent_vset_value(p_flex_value_set_name => 'XXOBJT_EVENT_TABLE_NAME', p_flex_value => l_rec.event_table, p_description => to_char(l_current_query_date, 'DDMMYYYY HH24MISS'), x_storage_value => l_out);
    COMMIT;

  EXCEPTION

    WHEN OTHERS THEN
      ROLLBACK;
      errbuf  := 'Failed ar_events - ' || substr(SQLERRM, 1, 240);
      retcode := 2;

  END;

  --------------------------------------------------------------------
  -- cs_events
  --------------------------------------------------------------------
  --  purpose :  audit new cs  events
  --  monitor MACHINE_UPGRADE/ HASP_UPGRADE events
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    4.3.14      yuval tal        CUST776 CR 1215 intial build , Customer support SF-OA interfaces
  --  1.1    12/03/2015  Dalit A. Raviv   CHG0034735 add upgrade kit transfer to SF
  --  1.2    21/07/2015  Michal Tzvik     CHG0035439 - change cursor to insert rows with upgrade_kit only
  --  1.3    03-Oct-2018 Lingaraj         CHG0043859- Install base interface changes from Oracle to salesforce
  --  1.4    25/01/2019  Roman W          INC0145246 - bug fix , add to_char( i.upgrade_date, 'DD-MON-YYYY') 
  ---------------------------------------------------------------------
  PROCEDURE cs_events(errbuf            OUT VARCHAR2,
                      retcode           OUT VARCHAR2,
                      p_last_date_check VARCHAR2) IS

    l_last_query_date    DATE;
    --l_rec                xxobjt_custom_events%ROWTYPE;--#CHG0043859
    l_current_query_date DATE;

    CURSOR c_get_upg_instance_id(c_last_query_date    DATE,
                                 c_current_query_date DATE) IS
      SELECT xpi.system_sn,
             xpi.hasp_sn,
             cii_sn.instance_id   machine_oe_id,
             cii_hasp.instance_id hasp_oe_id,
             xpi.upgrade_kit      upgrade_kit, -- 1.1 12/03/2015 Dalit A. Raviv CHG0034735
             (SELECT max(xhh.order_number)
               FROM   XXCS_HASP_HEADERS xhh,
                      mtl_system_items_b msi
               WHERE  xhh.printer_sn = xpi.system_sn
               AND    xhh.upgrade_kit = msi.segment1
               AND    msi.inventory_item_id = xpi.upgrade_kit
               AND    msi.organization_id = 91) so_Number, -- Added on 3Oct2018 for #CHG0043859
             (xpi.creation_date + (fnd_profile.value('XXCS_UPGRADE_SHIPP_DAYS')))  upgrade_date, -- Added on 3Oct2018 for #CHG0043859
               cii_sn.PN_DESCRIPTION item_code   -- Added on 3Oct2018 for #CHG0043859
      FROM   xxsf_csi_item_instances cii_sn,
             xxsf_csi_item_instances cii_hasp,
             xxcs_pz2oa_intf         xpi
      WHERE  cii_hasp.parent_instance_id = cii_sn.instance_id
      AND    xpi.system_sn = cii_sn.serial_number
      AND    xpi.upgrade_kit IS NOT NULL --  1.2    21/07/2015 Michal Tzvik     CHG0035439
      AND    (xpi.creation_date BETWEEN c_last_query_date - 7 AND
            c_current_query_date - 7)
      --  1.2    21/07/2015 Michal Tzvik CHG0035439: add historical records that do not exist
      -- in xxobjt_custom_events, for case when upgrade_kit was populated after dates delta
      UNION ALL
      SELECT xpi.system_sn,
             xpi.hasp_sn,
             cii_sn.instance_id   machine_oe_id,
             cii_hasp.instance_id hasp_oe_id,
             xpi.upgrade_kit      upgrade_kit, -- 1.1 12/03/2015 Dalit A. Raviv CHG0034735
             (SELECT max(xhh.order_number)
               FROM   XXCS_HASP_HEADERS xhh,
                      mtl_system_items_b msi
               WHERE  xhh.printer_sn = xpi.system_sn
               AND    xhh.upgrade_kit = msi.segment1
               AND    msi.inventory_item_id = xpi.upgrade_kit
               AND    msi.organization_id = 91) so_Number, -- Added on 3Oct2018 for #CHG0043859
               xpi.creation_date + (fnd_profile.value('XXCS_UPGRADE_SHIPP_DAYS'))  upgrade_date, -- Added on 3Oct2018 for #CHG0043859
               cii_sn.PN_DESCRIPTION item_code   -- Added on 3Oct2018 for #CHG0043859
      FROM   xxsf_csi_item_instances cii_sn,
             xxsf_csi_item_instances cii_hasp,
             xxcs_pz2oa_intf         xpi
      WHERE  cii_hasp.parent_instance_id = cii_sn.instance_id
      AND    xpi.system_sn = cii_sn.serial_number
      AND    xpi.upgrade_kit IS NOT NULL --  1.2    21/07/2015 Michal Tzvik     CHG0035439
      AND    (xpi.creation_date < c_last_query_date - 7 AND NOT EXISTS
             (SELECT 1
               FROM   xxobjt_custom_events xce
               WHERE  to_nchar(xce.event_key) = cii_sn.instance_id
               AND    xce.event_name = 'MACHINE_UPGRADE'
               AND    xce.attribute1 = to_char(xpi.upgrade_kit)));

    l_out VARCHAR2(50);
    l_xxssys_event_rec xxssys_events%ROWTYPE; --#CHG0043859
    l_source_name      VARCHAR2(30);          --#CHG0043859
    l_event_table      VARCHAR2(30);          --#CHG0043859
  BEGIN
    --  get last_update_date for event_name
    --  last_update_date := get_last_update_date
    l_current_query_date := SYSDATE;
    --l_rec.source_name    := 'xxobjt_event_pkg.cs_events';  --#CHG0043859
    --l_rec.event_table    := 'XXCS_PZ2OA_INTF';     --#CHG0043859

    l_source_name    := 'xxobjt_event_pkg.cs_events';  --#CHG0043859
    l_event_table    := 'XXCS_PZ2OA_INTF';     --#CHG0043859

    IF p_last_date_check IS NOT NULL THEN
      l_last_query_date := fnd_date.canonical_to_date(p_last_date_check);
    ELSE
      l_last_query_date := get_last_fetch_date(l_event_table); --l_rec.event_table);--#CHG0043859
    END IF;

    -- query new records

    FOR i IN c_get_upg_instance_id(l_last_query_date, l_current_query_date) LOOP
      -- insert MAchine  instance_id
      -- 1.1 12/03/2015 Dalit A. Raviv CHG0034735
     /* l_rec.event_key  := i.machine_oe_id;
      l_rec.event_name := 'MACHINE_UPGRADE';
      l_rec.attribute1 := i.upgrade_kit; -- 1.1 12/03/2015 Dalit A. Raviv CHG0034735
      insert_event(l_rec);

      --Begin Added for #CHG0043859
      -- insert hasp upgarde instance_id
      l_rec.event_key  := i.hasp_oe_id;
      l_rec.event_name := 'HASP_UPGRADE';
      insert_event(l_rec);
      --
      */   -- Commented for #CHG0043859

      --Begin Added for #CHG0043859
      l_xxssys_event_rec             := NULL;
      l_xxssys_event_rec.target_name := 'STRATAFORCE';
      l_xxssys_event_rec.entity_name := 'ASSET';
      l_xxssys_event_rec.entity_id   := i.machine_oe_id;
      l_xxssys_event_rec.event_name  := l_source_name;
      l_xxssys_event_rec.attribute1  := 'INSTALL_BASE_UPGRADE';
      l_xxssys_event_rec.attribute2  := i.item_code;
      l_xxssys_event_rec.attribute3  := i.so_Number;
      -- l_xxssys_event_rec.attribute4  := i.upgrade_date; rem by Roman W 25/01/2019 INC0145246
      l_xxssys_event_rec.attribute4  := to_char(i.upgrade_date,'DD-MON-YYYY');

      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');

      l_xxssys_event_rec.entity_id   := i.hasp_oe_id;
      l_xxssys_event_rec.event_name  := 'HASP_UPGRADE';
      l_xxssys_event_rec.attribute1  := 'HASP_UPGRADE';
      l_xxssys_event_rec.attribute2  := '';
      l_xxssys_event_rec.attribute3  := '';
      l_xxssys_event_rec.attribute4  := '';

      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');

      --End #CHG0043859
    END LOOP;
    fnd_flex_val_api.update_independent_vset_value(p_flex_value_set_name => 'XXOBJT_EVENT_TABLE_NAME', p_flex_value => l_event_table /*#CHG0043859 l_rec.event_table*/, p_description => to_char(l_current_query_date, 'DDMMYYYY HH24MISS'), x_storage_value => l_out);
    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      errbuf  := 'Failed cs_events - ' || substr(SQLERRM, 1, 240);
      retcode := 2;
  END;
END xxobjt_custom_events_pkg;
/
