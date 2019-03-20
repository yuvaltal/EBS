create or replace package body xxcs_upgrade_ib_upon_shipp_pkg IS
  --------------------------------------------------------------------
  --  name:               XXCS_UPGRADE_IB_UPON_SHIPP_PKG
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      15.07.2015
  --  Purpose :           CHG0035439 ¿ Rule Advisor for Objet 1000 - upgrade IB upon Order shipping
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15.07.2015    Michal Tzvik    initial build
  --  1.1   08-Aug-2016 Lingaraj Sarangi  CHG0037320 - Objet studio SW update
  --                                      Modification in the Main Proc Cursor query
  --  1.2   19-Jun-2017 Lingaraj Sarangi  CHG0040890 - updated the upgrade advisor to support selling an upgrade in an initial sale
  --  1.3   03-Oct-2018 Lingaraj          CHG0043859- Install base interface changes from Oracle to salesforce
  -----------------------------------------------------------------------

  c_src_machine_upg CONSTANT VARCHAR2(30) := 'INSTALL_BASE_UPGRADE';--'MACHINE_UPGRADE';--CHG0043859

  --------------------------------------------------------------------
  --  name:            log_message
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   01/07/2015
  --------------------------------------------------------------------
  --  purpose :        Print message to log file or dbms output
  --  in params:
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  01/07/2015  Michal Tzvik      CHG0032501 - initial build
  --------------------------------------------------------------------
  PROCEDURE log_message(p_message VARCHAR2) IS
  BEGIN
    IF fnd_global.conc_request_id < 0 THEN
      dbms_output.put_line(p_message);
    ELSE
      fnd_file.put_line(fnd_file.log, p_message);
    END IF;

  END log_message;

  --------------------------------------------------------------------
  --  name:               insert_into_sf_interface
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      15.07.2015
  --------------------------------------------------------------------
  --  purpose :          insert data into interface table xxobjt_oa2sf_interface
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  15.07.2015    Michal Tzvik     CHG0035439 - initial build               
  --  1.1  03-Oct-2018 Lingaraj          CHG0043859- Install base interface changes from Oracle to salesforce
  --                                     Procedure not required any more.
  -------------------------------------------------------------------- 
  /*
  PROCEDURE insert_into_sf_interface(errbuf      OUT VARCHAR2,
                                     retcode     OUT VARCHAR2,
                                     p_oa2sf_rec IN t_oa2sf_rec) IS

    l_source_id_exist VARCHAR2(1) := 'N';
    l_user_id         NUMBER;
  BEGIN
    errbuf  := '';
    retcode := '0';

    -- check if there is allready row exists with this status, and source
    l_source_id_exist := xxobjt_oa2sf_interface_pkg.is_source_id_exist(p_source_id => p_oa2sf_rec.source_id, --
                                                                       p_source_name => p_oa2sf_rec.source_name);

    IF l_source_id_exist = 'N' THEN

      SELECT user_id
      INTO   l_user_id
      FROM   fnd_user
      WHERE  user_name = 'SALESFORCE';

      INSERT INTO xxobjt_oa2sf_interface
        (oracle_event_id,
         batch_id,
         bpel_instance_id,
         status,
         process_mode,
         source_id,
         source_id2,
         source_name,
         sf_id,
         sf_err_code,
         sf_err_msg,
         oa_err_code,
         oa_err_msg,
         last_update_date,
         last_updated_by,
         last_update_login,
         creation_date,
         created_by)
      VALUES
        (xxobjt_oa2sf_interface_id_s.nextval,
         NULL, -- p_oa2sf_rec.batch_id,
         NULL, -- p_oa2sf_rec.bpel_instance_id,
         p_oa2sf_rec.status, -- status
         p_oa2sf_rec.process_mode, -- process_mode
         p_oa2sf_rec.source_id, -- source_id
         p_oa2sf_rec.source_id2, -- source_id2
         p_oa2sf_rec.source_name, -- source_name
         NULL, -- p_oa2sf_rec.sf_id,
         NULL, -- p_oa2sf_rec.sf_err_code,
         NULL, -- p_oa2sf_rec.sf_err_msg,
         NULL, -- p_oa2sf_rec.oa_err_code,
         NULL, -- p_oa2sf_rec.oa_err_msg,
         SYSDATE, --last_update_date
         l_user_id, -- last_updated_by
         -1, -- last_update_login
         SYSDATE, -- creation_date
         l_user_id -- created_by
         );
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Unexpected error in xxcs_upgrade_ib_upon_shipp_pkg.insert_into_sf_interface: ' ||
                 SQLERRM;
      retcode := '1';
  END insert_into_sf_interface;
  */
  --------------------------------------------------------------------
  --  name:               update_ib
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      15.07.2015
  --------------------------------------------------------------------
  --  purpose :          update install base
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  15.07.2015    Michal Tzvik     CHG0035439 - initial build
  --------------------------------------------------------------------
  PROCEDURE update_ib(errbuf              OUT VARCHAR2,
                      retcode             OUT VARCHAR2,
                      p_instance_id       NUMBER,
                      p_inventory_item_id NUMBER) IS

    l_request_id  NUMBER;
    l_return_bool BOOLEAN;
    l_phase       VARCHAR2(20);
    l_status      VARCHAR2(20);
    l_dev_phase   VARCHAR2(20);
    l_dev_status  VARCHAR2(20);
    l_message     VARCHAR2(150);

    l_cmplt_flag BOOLEAN := FALSE;
  BEGIN

    l_request_id := fnd_request.submit_request(application => 'XXOBJT', --
                                               program => 'XXCSI_II_AUTO_UPGRADE', --
                                               argument1 => 'MANUAL' -- p_entity
                                              , argument2 => p_instance_id -- p_instance_id
                                              , argument3 => p_inventory_item_id -- p_inventory_item_id
                                              , argument4 => NULL -- p_hasp_sn
                                              , argument5 => NULL -- p_user_name
                                              , argument6 => 'HW' -- p_SW_HW
                                               );

    IF l_request_id = 0 THEN
      log_message('Failed to submit request of "XX: Automated upgrade in IB - Prog" ');
      retcode := '1';
    ELSE
      COMMIT;
      WHILE l_cmplt_flag = FALSE LOOP
        l_return_bool := fnd_concurrent.wait_for_request(request_id => l_request_id, --
                                                         INTERVAL => 1, --
                                                         phase => l_phase, --
                                                         status => l_status, --
                                                         dev_phase => l_dev_phase, --
                                                         dev_status => l_dev_status, --
                                                         message => l_message);

        IF l_dev_phase = 'COMPLETE' THEN
          l_cmplt_flag := TRUE;
        END IF; -- dev_phase
      END LOOP; -- l_cmplt_flag

      IF upper(l_dev_status) IN ('ERROR', 'WARNING') THEN
        errbuf  := 'Concurrent request of "XX: Automated upgrade in IB - Prog" completed with status ' ||
                   l_dev_status || ': ' || l_message || ' (request id: ' ||
                   l_request_id || ')';
        retcode := '1';

      END IF;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := 'Unexpected error in XXCS_UPGRADE_IB_UPON_SHIPP_PKG.update_ib: ' ||
                 SQLERRM;
  END update_ib;

  --------------------------------------------------------------------
  --  name:               main
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      15.07.2015
  --------------------------------------------------------------------
  --  purpose :          Used by concurrent executable: XXCS_UPGRADE_IB_UPON_SHIPP
  --                     to update install base and insert to SF
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  15.07.2015    Michal Tzvik     CHG0035439 - initial build
  --  1.1  08-Aug-2016  Lingaraj Sarangi  CHG0037320 - Objet studio SW update
  --                                      c_ship Cursor Query Modified
  --  1.2  19-Jun-2017 Lingaraj Sarangi  CHG0040890 - updated the upgrade advisor to support selling an upgrade in an initial sale
  --  1.3   03-Oct-2018 Lingaraj          CHG0043859- Install base interface changes from Oracle to salesforce
  --------------------------------------------------------------------
  PROCEDURE main(errbuf  OUT VARCHAR2,
                 retcode OUT VARCHAR2) IS
    l_errbuf  VARCHAR2(1500);
    l_retcode VARCHAR2(1);
    l_errbuf1  VARCHAR2(1500);--v1.2 Added on 19 Jun 2017 for CHG0040890
    l_retcode1 VARCHAR2(1) := '0';   --v1.2 Added on 19 Jun 2017 for CHG0040890

    CURSOR c_ship(p_days_back NUMBER) IS
      SELECT Distinct oola.ordered_item, --1.1 Distinct Added - 8th Aug 2016 - L.Sarangi  - CHG0037320
             oola.inventory_item_id, -- upgrade item
             oola.attribute1 instance_id,
             ooha.order_number so_Number,  -- Added on 03 OCT 18 for #CHG0043859
             to_char(oola.actual_shipment_date + p_days_back,'DD-MON-YYYY') Upgrade_date -- Added on 03 OCT 18 for #CHG0043859             
            /* oola.header_id,
             oola.line_id*/ --1.1 Commented - 8th Aug 2016 - L.Sarangi  - CHG0037320
      FROM   oe_order_lines_all oola,
             oe_order_headers_all ooha -- Added on 03 OCT 18 for #CHG0043859
      WHERE  oola.line_category_code = 'ORDER'
      AND    oola.header_id  = ooha.header_id  -- Added on 03 OCT 18 for #CHG0043859
      AND    oola.shipped_quantity > 0
      AND    (SYSDATE - p_days_back) > oola.actual_shipment_date
      AND    oola.attribute1 IS NOT NULL
      AND    oola.inventory_item_id IN
             (SELECT msi.inventory_item_id
               FROM   fnd_lookup_values_vl fl,
                      mtl_system_items_b   msi
               WHERE  fl.lookup_type = 'XXCSI_UPGRADE_TYPE'
               AND    msi.segment1 = fl.description
               AND    msi.organization_id =
                      xxinv_utils_pkg.get_master_organization_id
               AND    fl.attribute9 = 'SHIP')
      AND    NOT EXISTS  
      ( --#CHG0043859
        select 1 
        from   xxssys_events xe
        where  xe.target_name = 'STRATAFORCE'
        and    xe.entity_name = 'ASSET'   
        and    xe.attribute1  = c_src_machine_upg        
        and    xe.entity_id   = oola.attribute1  
        and    xe.attribute2  = oola.ordered_item
      ) ;
      /* (SELECT 1
              FROM   xxobjt_oa2sf_interface xoi
              WHERE  xoi.source_name =  c_src_machine_upg --'MACHINE_UPGRADE'
              AND    xoi.source_id = oola.attribute1 --Instance_ID
              AND    xoi.source_id2 = oola.inventory_item_id);*/ --commected for #CHG0043859

    l_days      NUMBER := 0;
    l_cnt       NUMBER := 0;
    l_err_cnt   NUMBER := 0;
    l_oa2sf_rec t_oa2sf_rec;
    process_data EXCEPTION;
    l_xxssys_event_rec xxssys_events%ROWTYPE;  --#CHG0043859
  BEGIN

    errbuf  := '';
    retcode := '0';
    l_days  := fnd_profile.value('XXCS_UPGRADE_SHIPP_DAYS');

    IF l_days IS NULL THEN
      retcode := '1';
      errbuf  := 'No value is assigned to profile XXCS_UPGRADE_SHIPP_DAYS';
      RETURN;
    END IF;

    --v1.2 Added on 19 Jun 2017 for CHG0040890
    xxcs_utils_pkg.update_upg_instance_id(l_errbuf1 , l_retcode1);
    If l_retcode1 != 0 Then
      log_message(l_errbuf1);
    End If;

    FOR r_ship IN c_ship(l_days) LOOP
      BEGIN
        l_errbuf  := '';
        l_retcode := '0';
        l_cnt     := l_cnt + 1;

        -- Update install base
        log_message('Update IB. instance_id=' || r_ship.instance_id ||
                    ', inventory_item_id:' || r_ship.inventory_item_id);
        update_ib(l_errbuf, --
                  l_retcode, --
                  r_ship.instance_id, --
                  r_ship.inventory_item_id);
        IF l_retcode != '0' THEN
          RAISE process_data;
        END IF;
        
        --#CHG0043859
        l_xxssys_event_rec             := NULL;
        l_xxssys_event_rec.target_name := 'STRATAFORCE';
        l_xxssys_event_rec.entity_name := 'ASSET';        
        l_xxssys_event_rec.entity_id   := r_ship.instance_id;
        l_xxssys_event_rec.event_name  := 'XXCS_UPGRADE_IB_UPON_SHIPP_PKG.MAIN';
        l_xxssys_event_rec.attribute1  := c_src_machine_upg;
        l_xxssys_event_rec.attribute2  := r_ship.ordered_item;
        l_xxssys_event_rec.attribute3  := r_ship.so_Number; 
        l_xxssys_event_rec.attribute4  := r_ship.Upgrade_date;                                                              
        
        xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');  
       /* Commented on 03 Oct 2018 for #CHG0043859
        -- Update sales force
        l_oa2sf_rec.status      := 'NEW';
        l_oa2sf_rec.source_id   := r_ship.instance_id;
        l_oa2sf_rec.source_id2  := r_ship.inventory_item_id;
        l_oa2sf_rec.source_name := c_src_machine_upg;

        insert_into_sf_interface(l_errbuf, --
                                 l_retcode, --
                                 l_oa2sf_rec);
        IF l_retcode != '0' THEN
          RAISE process_data;
        END IF;
       
        COMMIT;*/
      EXCEPTION
        WHEN OTHERS THEN
          log_message('Failed to process data for...' ||
                      nvl(l_errbuf, SQLERRM));
          retcode   := '1';
          l_err_cnt := l_err_cnt + 1;
      END;
    END LOOP;

    l_cnt := l_cnt - l_err_cnt;

    log_message(l_cnt || ' records where processed.');
    log_message(l_err_cnt || ' records had errors.');

    --v1.2 Added on 19 Jun 2017 for CHG0040890
    --If Any Error occurs during the Sales Order Line Updation , The Program will complete with Error
    If l_retcode1 != 0 Then
      errbuf := errbuf ||CHR(13)|| l_errbuf1;
      retcode := '2';
    End If;

  EXCEPTION
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := 'Unexpected error in XXCS_UPGRADE_IB_UPON_SHIPP_PKG.main: ' ||
                 SQLERRM;
  END main;

END xxcs_upgrade_ib_upon_shipp_pkg;
/