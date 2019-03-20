CREATE OR REPLACE PACKAGE BODY xxssys_sync_ship_doc_pkg AS
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
  --  1.1  11/10/2018  Roman W.                CHG0043434 added nvl(flv.start_date_active
  --                                                        and nvl(flv.end_date_active
  --                                                to xxssys_sync_ship_doc_pkg.chk_delivery_eligbility/chk_order_eligibility
  --  1.2  25/01/2019  Diptasurjya             INC0145264 - Fix write_log to read fnd debug profile for fnd user
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name            Description
  -- 1.0  08/08/2018  Diptasurjya     CHG0043434 - Initial Creation
  --                  Chatterjee
  -- 1.1  25/01/2019  Diptasurjya     INC0145264 - change fnd_profile.value('AFLOG_ENABLED') to fnd_profile.value_specific('AFLOG_ENABLED',fnd_global.USER_ID)
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE write_log(p_msg      IN VARCHAR2,
                      p_api_name IN varchar2 default null) IS
    l_log        VARCHAR2(1) := fnd_profile.value_specific('AFLOG_ENABLED',fnd_global.USER_ID); --fnd_profile.value('AFLOG_ENABLED'); -- INC0145264 commented

    l_log_module VARCHAR2(100) := fnd_profile.value('AFLOG_MODULE');
  BEGIN
    IF l_log = 'Y' THEN
      fnd_log.string(log_level => fnd_log.LEVEL_UNEXPECTED,
                     module    => 'xxssys.xxssys_sync_ship_doc_pkg.' ||
                                  p_api_name,
                     message   => p_msg);
    END IF;
  END write_log;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Call xxssys_event_pkg.insert_mail_event in autonomous transaction mode
  --          Commits from inside the insert mail process causes issues with business event system
  --          Error received by BE system: Commit happened while dispatching the event
  --          Autonomous transaction prevents such errors
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name            Description
  -- 1.0  08/08/2018  Diptasurjya     CHG0043434 - Initial Creation
  --                  Chatterjee
  -- ---------------------------------------------------------------------------------------------
  procedure autonomous_event_insert(lp_db_trigger_mode IN VARCHAR2,
                                    lp_target_name     IN VARCHAR2,
                                    lp_program_name_to IN VARCHAR2,
                                    lp_program_name_cc IN VARCHAR2,
                                    lp_operating_unit  IN NUMBER,
                                    lp_entity          IN VARCHAR2,
                                    lp_entity_id       IN NUMBER default null,
                                    lp_subject         IN VARCHAR2,
                                    lp_body            IN VARCHAR2,
                                    lp_event_name      IN VARCHAR2,
                                    lp_user_id         IN NUMBER) is
    pragma autonomous_transaction;
    l_status varchar2(20);

  begin
    xxssys_event_pkg.insert_mail_event(p_db_trigger_mode => lp_db_trigger_mode,
                                       p_target_name     => lp_target_name,
                                       p_event_name      => lp_event_name,
                                       p_user_id         => lp_user_id,
                                       p_program_name_to => lp_program_name_to,
                                       p_program_name_cc => lp_program_name_cc,
                                       p_operating_unit  => lp_operating_unit,
                                       p_entity          => lp_entity,
                                       p_entity_id       => lp_entity_id,
                                       p_subject         => lp_subject,
                                       p_body            => lp_body);
  end autonomous_event_insert;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0043434
  --          This function will check if order is eligible for document generation call
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  08/07/2018  Diptasurjya Chatterjee        Initial Build
  -- 1.1  11/10/2018  Roman W.                      CHG0043434 - added nvl(flv.start_date_active and nvl(flv.end_date_active
  -- --------------------------------------------------------------------------------------------
  function chk_order_eligibility(p_header_id number) return varchar2 is
    l_status varchar2(1);
  begin
    begin
      select 'Y'
        into l_status
        from oe_order_headers_all oh,
             oe_order_sources     oos,
             fnd_lookup_values_vl flv
       where oh.header_id = p_header_id
         and oos.order_source_id = oh.order_source_id
         and flv.LOOKUP_TYPE = 'XXOM_SFORCE_DOC_SYNC_SOURCES'
         and oos.name = flv.MEANING
         and flv.ENABLED_FLAG = 'Y'
         and trunc(sysdate) between
             trunc(nvl(flv.start_date_active, sysdate)) and
             trunc(nvl(flv.end_date_active, sysdate))
         and oos.enabled_flag = 'Y';

    exception
      when no_data_found then
        l_status := 'N';
    end;

    return l_status;
  end chk_order_eligibility;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0043434
  --          This function will check if delivery is eligible for document generation call
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  08/07/2018  Diptasurjya Chatterjee        Initial Build
  -- 1.1  11/10/2018  Roman W.                      added nvl(flv.start_date_active and nvl(flv.end_date_active
  -- --------------------------------------------------------------------------------------------
  function chk_delivery_eligibility(p_delivery_id number) return varchar2 is
    l_status varchar2(1);
  begin
    begin
      select 'Y'
        into l_status
        from oe_order_headers_all oh,
             oe_order_sources oos,
             fnd_lookup_values_vl flv,
             (select distinct wdd.source_header_id, wnd.delivery_id
                from wsh_delivery_details     wdd,
                     wsh_new_deliveries       wnd,
                     wsh_delivery_assignments wda
               where wnd.delivery_id = wda.delivery_id
                 and wda.delivery_detail_id = wdd.delivery_detail_id) shp
       where shp.delivery_id = p_delivery_id
         and oh.header_id = shp.source_header_id
         and oos.order_source_id = oh.order_source_id
         and flv.LOOKUP_TYPE = 'XXOM_SFORCE_DOC_SYNC_SOURCES'
         and oos.name = flv.MEANING
         and flv.ENABLED_FLAG = 'Y'
         and trunc(sysdate) between
             trunc(nvl(flv.start_date_active, sysdate)) and
             trunc(nvl(flv.end_date_active, sysdate))
         and oos.enabled_flag = 'Y';
    exception
      when no_data_found then
        l_status := 'N';
    end;

    return l_status;
  end chk_delivery_eligibility;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0043434
  --          This procedure will call the concurrent program XXCUSTDOCSUB to generate required reports
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  08/07/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  procedure submit_doc_generator(p_pkey           IN number,
                                 p_doc_set_code   IN varchar2,
                                 p_org_id         IN number default null,
                                 x_request_id     OUT number,
                                 x_status         OUT varchar2,
                                 x_status_message OUT varchar2) is
    --pragma autonomous_transaction;

    l_conc_id    number;
    v_phase      VARCHAR2(80) := NULL;
    v_status     VARCHAR2(80) := NULL;
    v_dev_phase  VARCHAR2(80) := NULL;
    v_dev_status VARCHAR2(80) := NULL;
    v_message    VARCHAR2(240) := NULL;
    v_req_st     BOOLEAN;

    l_status         varchar2(1);
    l_status_message varchar2(4000);
  begin
    write_log('xxssys_sync_ship_doc_pkg.submit_doc_generator : Inside document Generator program submit procedure');

    l_conc_id := fnd_request.submit_request(application => 'XXOBJT',
                                            program     => 'XXCUSTDOCSUB',
                                            description => NULL,
                                            start_time  => SYSDATE,
                                            sub_request => FALSE,
                                            argument1   => p_doc_set_code,
                                            -- rem By R.W. 08/10/20118 argument2   => p_org_id,
                                            argument2 => null,
                                            argument3 => p_pkey);

    write_log('xxssys_sync_ship_doc_pkg.submit_doc_generator : request id: ' ||
              l_conc_id);

    IF l_conc_id > 0 then
      COMMIT;
      write_log('xxssys_sync_ship_doc_pkg.submit_doc_generator : Waiting for request ' ||
                l_conc_id || ' to complete');
      LOOP
        v_req_st := APPS.FND_CONCURRENT.WAIT_FOR_REQUEST(request_id => l_conc_id,
                                                         interval   => 0,
                                                         max_wait   => 0,
                                                         phase      => v_phase,
                                                         status     => v_status,
                                                         dev_phase  => v_dev_phase,
                                                         dev_status => v_dev_status,
                                                         message    => v_message);
        EXIT WHEN v_dev_phase = 'COMPLETE';
      END LOOP;

      x_request_id := l_conc_id;

      if v_dev_status <> 'NORMAL' then
        l_status         := 'E';
        l_status_message := 'Document Generator program finished with errors.';
      else
        l_status := 'S';
      end if;

      write_log('xxssys_sync_ship_doc_pkg.submit_doc_generator : Completed program ' ||
                l_conc_id || ' with status ' || v_dev_status);

      COMMIT;
    ELSE
      l_status         := 'E';
      l_status_message := 'Document Generator program could not be submitted';

      write_log('xxssys_sync_ship_doc_pkg.submit_doc_generator : Program XXCUSTDOCSUB could not be submitted');
    END IF;

    x_status         := l_status;
    x_status_message := l_status_message;
  exception
    when others then
      x_status         := 'E';
      x_status_message := 'ERROR: While submitting Document Generator program: ' ||
                          substr(sqlerrm, 1, 4000);

      write_log('xxssys_sync_ship_doc_pkg.submit_doc_generator : UNEXPECTED ERROR: ' ||
                substr(sqlerrm, 1, 4000));
  end submit_doc_generator;

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
                                   x_status_message out varchar2) is
    l_status         varchar2(1);
    l_status_message varchar2(4000);
    l_request_id     number;
  begin
    write_log('xxssys_sync_ship_doc_pkg.handle_order_book_docs : INPUT: p_header_id: ' ||
              p_header_id);
    write_log('xxssys_sync_ship_doc_pkg.handle_order_book_docs : INPUT: p_org_id: ' ||
              p_org_id);
    write_log('xxssys_sync_ship_doc_pkg.handle_order_book_docs : INPUT: p_doc_set_code: ' ||
              p_doc_set_code);

    l_status := chk_order_eligibility(p_header_id);

    write_log('xxssys_sync_ship_doc_pkg.handle_order_book_docs : Eligibility status check: ' ||
              l_status);

    if l_status = 'Y' then
      write_log('xxssys_sync_ship_doc_pkg.handle_order_book_docs : before calling submit_doc_generator');

      submit_doc_generator(p_pkey           => p_header_id,
                           p_doc_set_code   => p_doc_set_code,
                           p_org_id         => p_org_id,
                           x_request_id     => l_request_id,
                           x_status         => l_status,
                           x_status_message => l_status_message);

      write_log('xxssys_sync_ship_doc_pkg.handle_order_book_docs : after calling submit_doc_generator');
      write_log('xxssys_sync_ship_doc_pkg.handle_order_book_docs : request_id: ' ||
                l_request_id);
    else
      l_status := 'S';
    end if;

    x_status         := l_status;
    x_status_message := l_status_message;
  exception
    when others then
      x_status         := 'E';
      x_status_message := substr(sqlerrm, 1, 4000);

      write_log('xxssys_sync_ship_doc_pkg.handle_order_book_docs : UNEXPECTED ERROR: ' ||
                substr(sqlerrm, 1, 4000));
  end handle_order_book_docs;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0043434
  --          This procedure will handle generation of order shipping stage documents
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  08/07/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  procedure handle_delivery_ship_docs(p_delivery_id    in number,
                                      p_org_id         in number,
                                      p_doc_set_code   in varchar2,
                                      x_status         out varchar2,
                                      x_status_message out varchar2) is
    l_status         varchar2(1);
    l_status_message varchar2(4000);
    l_request_id     number;
  begin
    write_log('xxssys_sync_ship_doc_pkg.handle_delivery_ship_docs : INPUT: p_delivery_id: ' ||
              p_delivery_id);
    write_log('xxssys_sync_ship_doc_pkg.handle_delivery_ship_docs : INPUT: p_org_id: ' ||
              p_org_id);
    write_log('xxssys_sync_ship_doc_pkg.handle_delivery_ship_docs : INPUT: p_doc_set_code: ' ||
              p_doc_set_code);

    l_status := chk_delivery_eligibility(p_delivery_id);

    write_log('xxssys_sync_ship_doc_pkg.handle_delivery_ship_docs : Eligibility status check: ' ||
              l_status);

    if l_status = 'Y' then
      write_log('xxssys_sync_ship_doc_pkg.handle_delivery_ship_docs : before calling submit_doc_generator');

      submit_doc_generator(p_pkey           => p_delivery_id,
                           p_doc_set_code   => p_doc_set_code, --'SSYS_BOOK',
                           p_org_id         => p_org_id,
                           x_request_id     => l_request_id,
                           x_status         => l_status,
                           x_status_message => l_status_message);

      write_log('xxssys_sync_ship_doc_pkg.handle_delivery_ship_docs : after calling submit_doc_generator');
      write_log('xxssys_sync_ship_doc_pkg.handle_delivery_ship_docs : request_id: ' ||
                l_request_id);
    else
      l_status := 'S';
    end if;

    x_status         := l_status;
    x_status_message := l_status_message;
  exception
    when others then
      x_status         := 'E';
      x_status_message := substr(sqlerrm, 1, 4000);

      write_log('xxssys_sync_ship_doc_pkg.handle_delivery_ship_docs : UNEXPECTED ERROR: ' ||
                substr(sqlerrm, 1, 4000));
  end handle_delivery_ship_docs;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0043434
  --          This function will be used as Rule function for custom business event registered
  --          for order booking stage
  -----------------------------------------------------------------------------------------------
  --          Event Name: xxssys.oracle.apps.ont.order.booked
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  08/07/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION book_event_process(p_subscription_guid IN RAW,
                              p_event             IN OUT NOCOPY wf_event_t)
    RETURN VARCHAR2 IS
    l_eventname VARCHAR2(200);
    l_user_id   NUMBER := 0;
    l_resp_id   NUMBER := 0;
    l_appl_id   NUMBER := 0;

    l_header_id    number;
    l_org_id       number;
    l_order_number number;
    l_book_doc_set varchar2(100) := 'SSYS_BOOK';

    l_status         varchar2(1);
    l_status_message varchar2(4000);
  BEGIN
    write_log('xxssys_sync_ship_doc_pkg.book_event_process : Starting order book event processor');

    l_eventname := p_event.geteventname();
    l_user_id   := p_event.getvalueforparameter('USER_ID');
    l_resp_id   := p_event.getvalueforparameter('RESP_ID');
    l_appl_id   := p_event.getvalueforparameter('RESP_APPL_ID');

    write_log('xxssys_sync_ship_doc_pkg.book_event_process: Event name: ' ||
              l_eventname);
    write_log('xxssys_sync_ship_doc_pkg.book_event_process: Starting apps initialize with user: ' ||
              l_user_id || ' resp: ' || l_resp_id || ' appl: ' ||
              l_appl_id);

    fnd_global.APPS_INITIALIZE(l_user_id, l_resp_id, l_appl_id);

    write_log('xxssys_sync_ship_doc_pkg.book_event_process: Apps initialized successfully');

    IF l_eventname = 'xxssys.oracle.apps.ont.order.booked' THEN
      l_header_id := p_event.getvalueforparameter('HEADER_ID');

      select org_id, order_number
        into l_org_id, l_order_number
        from oe_order_headers_all
       where header_id = l_header_id;

      handle_order_book_docs(l_header_id,
                             l_org_id,
                             l_book_doc_set,
                             l_status,
                             l_status_message);
    END IF;

    write_log('xxssys_sync_ship_doc_pkg.book_event_process : handle_order_book_docs status: ' ||
              l_status);
    write_log('xxssys_sync_ship_doc_pkg.book_event_process : handle_order_book_docs status message: ' ||
              l_status_message);

    --commit;

    if l_status = 'S' then
      RETURN 'SUCCESS';
    else
      write_log('xxssys_sync_ship_doc_pkg.book_event_process: before inserting NOTIF_EMAIL event for error encountered');

      autonomous_event_insert(lp_db_trigger_mode => 'N',
                              lp_target_name     => 'STRATAFORCE',
                              lp_event_name      => l_eventname,
                              lp_user_id         => l_user_id,
                              lp_program_name_to => 'XXOM_SFORCE_ORDER_BOOK_DOC_SYNC_ERROR_TO',
                              lp_program_name_cc => 'XXOM_SFORCE_ORDER_BOOK_DOC_SYNC_ERROR_CC',
                              lp_operating_unit  => l_org_id,
                              lp_entity          => 'ORDER_BOOK_DOCS',
                              lp_entity_id       => l_header_id,
                              lp_subject         => 'Strataforce - Error in Order Book document generator event processor',
                              lp_body            => 'Order Header ID: ' ||
                                                    l_header_id || chr(13) ||
                                                    chr(10) ||
                                                    'Order Number: ' ||
                                                    l_order_number ||
                                                    chr(13) || chr(10) ||
                                                    'Org ID: ' || l_org_id ||
                                                    chr(13) || chr(10) ||
                                                    substr(l_status_message,
                                                           1,
                                                           4000) || chr(13) ||
                                                    chr(10) ||
                                                    'Error Time: ' ||
                                                    SYSDATE);

      write_log('xxssys_sync_ship_doc_pkg.book_event_process: after inserting NOTIF_EMAIL event for error encountered');
      
      wf_core.context('xxssys_sync_ship_doc_pkg.book_event_process',
                      'function subscription',
                      p_event.geteventname(),
                      p_event.geteventkey());
      wf_event.seterrorinfo(p_event, 'ERROR: ' || l_status_message);
      
      RETURN 'ERROR';
    end if;

  EXCEPTION
    WHEN OTHERS THEN
      l_status_message := l_status_message || chr(13) ||
                          substr(sqlerrm, 1, 2000);

      write_log('xxssys_sync_ship_doc_pkg.book_event_process: UNEXPECTED ERROR: ' ||
                substr(sqlerrm, 1, 1000));
      write_log('xxssys_sync_ship_doc_pkg.book_event_process: before inserting NOTIF_EMAIL event for unexpected error');

      autonomous_event_insert(lp_db_trigger_mode => 'N',
                              lp_target_name     => 'STRATAFORCE',
                              lp_event_name      => l_eventname,
                              lp_user_id         => l_user_id,
                              lp_program_name_to => 'XXOM_SFORCE_ORDER_BOOK_DOC_SYNC_ERROR_TO',
                              lp_program_name_cc => 'XXOM_SFORCE_ORDER_BOOK_DOC_SYNC_ERROR_CC',
                              lp_operating_unit  => l_org_id,
                              lp_entity          => 'ORDER_BOOK_DOCS',
                              lp_entity_id       => l_header_id,
                              lp_subject         => 'Strataforce - Error in Order Book document generator event processor',
                              lp_body            => 'Order Header ID: ' ||
                                                    l_header_id || chr(13) ||
                                                    chr(10) ||
                                                    'Order Number: ' ||
                                                    l_order_number ||
                                                    chr(13) || chr(10) ||
                                                    'Org ID: ' || l_org_id ||
                                                    chr(13) || chr(10) ||
                                                    substr(sqlerrm, 1, 4000) ||
                                                    chr(13) || chr(10) ||
                                                    'Error Time: ' ||
                                                    SYSDATE);

      write_log('xxssys_sync_ship_doc_pkg.book_event_process: after inserting NOTIF_EMAIL event for unexpected error');
      
      wf_core.context('xxssys_sync_ship_doc_pkg.book_event_process',
                      'function subscription',
                      p_event.geteventname(),
                      p_event.geteventkey());
      wf_event.seterrorinfo(p_event, 'UNEXPECTED ERROR: ' || sqlerrm);
      
      RETURN 'ERROR';
  END book_event_process;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0043434
  --          This function will be used as Rule function for business event
  --          for order ship confirm stage
  -----------------------------------------------------------------------------------------------
  --          Event Name: xxssys.oracle.apps.wsh.delivery.shipconfirmed
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  08/07/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION shipconfirm_event_process(p_subscription_guid IN RAW,
                                     p_event             IN OUT NOCOPY wf_event_t)
    RETURN VARCHAR2 IS
    l_eventname VARCHAR2(200);
    l_user_id   NUMBER := 0;
    l_resp_id   NUMBER := 0;
    l_appl_id   NUMBER := 0;

    l_book_doc_set   varchar2(100) := 'SSYS_SHIPC';
    l_status         varchar2(1);
    l_status_message varchar2(4000);
    l_delivery_id    NUMBER;
    l_org_id         NUMBER;
  BEGIN
    write_log('xxssys_sync_ship_doc_pkg.shipconfirm_event_process : Starting delivery ship confirm event processor');

    l_eventname := p_event.geteventname();
    l_user_id   := p_event.getvalueforparameter('USER_ID');
    l_resp_id   := p_event.getvalueforparameter('RESP_ID');
    l_appl_id   := p_event.getvalueforparameter('RESP_APPL_ID');

    write_log('xxssys_sync_ship_doc_pkg.shipconfirm_event_process: Event name: ' ||
              l_eventname);
    write_log('xxssys_sync_ship_doc_pkg.shipconfirm_event_process: Starting apps initialize with user: ' ||
              l_user_id || ' resp: ' || l_resp_id || ' appl: ' ||
              l_appl_id);

    fnd_global.APPS_INITIALIZE(l_user_id, l_resp_id, l_appl_id);

    write_log('xxssys_sync_ship_doc_pkg.shipconfirm_event_process: Apps initialized successfully');

    IF l_eventname = 'xxssys.oracle.apps.wsh.delivery.shipconfirmed' THEN
      l_delivery_id := p_event.getvalueforparameter('DELIVERY_ID');

      write_log('xxssys_sync_ship_doc_pkg.shipconfirm_event_process: before calling handle_delivery_ship_docs');
      handle_delivery_ship_docs(l_delivery_id,
                                l_org_id,
                                l_book_doc_set,
                                l_status,
                                l_status_message);
      write_log('xxssys_sync_ship_doc_pkg.shipconfirm_event_process: after calling handle_delivery_ship_docs');
    END IF;

    write_log('xxssys_sync_ship_doc_pkg.shipconfirm_event_process : handle_delivery_ship_docs status: ' ||
              l_status);
    write_log('xxssys_sync_ship_doc_pkg.shipconfirm_event_process : handle_delivery_ship_docs status message: ' ||
              l_status_message);

    --commit;

    if l_status = 'S' then
      RETURN 'SUCCESS';
    else
      write_log('xxssys_sync_ship_doc_pkg.shipconfirm_event_process: before inserting NOTIF_EMAIL event for error encountered');
      autonomous_event_insert(lp_db_trigger_mode => 'N',
                              lp_target_name     => 'STRATAFORCE',
                              lp_event_name      => l_eventname,
                              lp_user_id         => l_user_id,
                              lp_program_name_to => 'XXOM_SFORCE_SHPCONFIRM_DOC_SYNC_ERROR_TO',
                              lp_program_name_cc => 'XXOM_SFORCE_SHPCONFIRM_DOC_SYNC_ERROR_CC',
                              lp_operating_unit  => l_org_id,
                              lp_entity          => 'SHIP_COMFIRM_DOCS',
                              lp_entity_id       => l_delivery_id,
                              lp_subject         => 'Strataforce - Error in Ship Confirm document generator event processor',
                              lp_body            => 'Delivery ID: ' ||
                                                    l_delivery_id || chr(13) ||
                                                    chr(10) ||
                                                    l_status_message ||
                                                    chr(13) || chr(10) ||
                                                    'Error Time: ' ||
                                                    SYSDATE);
      write_log('xxssys_sync_ship_doc_pkg.shipconfirm_event_process: after inserting NOTIF_EMAIL event for error encountered');

      wf_core.context('xxssys_sync_ship_doc_pkg.shipconfirm_event_process',
                      'function subscription',
                      p_event.geteventname(),
                      p_event.geteventkey());
      wf_event.seterrorinfo(p_event, 'ERROR: ' || l_status_message);
      RETURN 'ERROR';
    end if;

    RETURN 'SUCCESS';

  EXCEPTION
    WHEN OTHERS THEN
      write_log('xxssys_sync_ship_doc_pkg.shipconfirm_event_process: UNEXPECTED ERROR: ' ||
                substr(sqlerrm, 1, 1000));
      write_log('xxssys_sync_ship_doc_pkg.shipconfirm_event_process: before inserting NOTIF_EMAIL event for unexpected error');

      autonomous_event_insert(lp_db_trigger_mode => 'N',
                              lp_target_name     => 'STRATAFORCE',
                              lp_event_name      => l_eventname,
                              lp_user_id         => l_user_id,
                              lp_program_name_to => 'XXOM_SFORCE_SHPCONFIRM_DOC_SYNC_ERROR_TO',
                              lp_program_name_cc => 'XXOM_SFORCE_SHPCONFIRM_DOC_SYNC_ERROR_CC',
                              lp_operating_unit  => l_org_id,
                              lp_entity          => 'SHIP_COMFIRM_DOCS',
                              lp_entity_id       => l_delivery_id,
                              lp_subject         => 'Strataforce - Error in Ship Confirm document generator event processor',
                              lp_body            => 'Delivery ID: ' ||
                                                    l_delivery_id || chr(13) ||
                                                    chr(10) ||
                                                    substr(sqlerrm, 1, 4000) ||
                                                    chr(13) || chr(10) ||
                                                    'Error Time: ' ||
                                                    SYSDATE);

      write_log('xxssys_sync_ship_doc_pkg.shipconfirm_event_process: after inserting NOTIF_EMAIL event for unexpected error');

      wf_core.context('xxssys_sync_ship_doc_pkg.shipconfirm_event_process',
                      'function subscription',
                      p_event.geteventname(),
                      p_event.geteventkey());
      wf_event.seterrorinfo(p_event, 'ERROR');
      RETURN 'ERROR';
  END shipconfirm_event_process;

END xxssys_sync_ship_doc_pkg;
/
