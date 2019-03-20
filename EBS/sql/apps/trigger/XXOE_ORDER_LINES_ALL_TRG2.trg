CREATE OR REPLACE TRIGGER XXOE_ORDER_LINES_ALL_TRG2
--------------------------------------------------------------------------------------------------
--  name:              XXOE_ORDER_LINES_ALL_TRG2
--  create by:         Diptasurjya Chatterjee
--  Revision:          1.0
--  creation date:     08/08/2018
--------------------------------------------------------------------------------------------------
--  purpose :          CHG0043434  : Raise business event when order is booked or changes occur
--                     to lines of a booked order
--  Modification History
--------------------------------------------------------------------------------------------------
--  ver   date          Name                 Desc
--  1.0   08/08/2018    Diptasurjya          CHG0043434 - Initial build
--------------------------------------------------------------------------------------------------
BEFORE INSERT OR UPDATE ON oe_order_lines_all
FOR EACH ROW WHEN (new.flow_status_code = 'BOOKED')
DECLARE
  l_event_count number;

  l_event_parameter_list  WF_PARAMETER_LIST_T;
  l_param                  WF_PARAMETER_T;
  l_event_name            VARCHAR2(100)  := 'xxssys.oracle.apps.ont.order.booked';
	l_event_key			        VARCHAR2(100)	:= 'XXOEBOOK_EVNT:'||:new.header_id;

	l_parameter_index		NUMBER		:= 0;
BEGIN
  select count(1)
    into l_event_count
    from applsys.aq$wf_deferred a
   where a.user_data.event_key like 'XXOEBOOK_EVNT:'||:NEW.HEADER_ID||'%'
     and a.user_data.EVENT_NAME = l_event_name
     and msg_state = 'READY';

  if l_event_count = 0 then
    l_event_key := l_event_key||':'||XXOE_BOOK_CUST_BE_SEQ.Nextval;

    l_event_parameter_list := WF_PARAMETER_LIST_T();

    -- Adding USER_ID parameter
    l_param := wf_parameter_t(NULL,NULL);
    l_event_parameter_list.EXTEND;
    l_param.setname('USER_ID');
    l_param.setvalue(to_char(fnd_global.USER_ID));
    l_parameter_index := l_parameter_index + 1;
    l_event_parameter_list(l_parameter_index) := l_param;

    -- Adding RESP_ID parameter
    l_param := wf_parameter_t(NULL,NULL);
    l_event_parameter_list.EXTEND;
    l_param.setname('RESP_ID');
    l_param.setvalue(to_char(fnd_global.RESP_ID));
    l_parameter_index := l_parameter_index + 1;
    l_event_parameter_list(l_parameter_index) := l_param;

    -- Adding RESP_APPL_ID parameter
    l_param := wf_parameter_t(NULL,NULL);
    l_event_parameter_list.EXTEND;
    l_param.setname('RESP_APPL_ID');
    l_param.setvalue(to_char(fnd_global.RESP_APPL_ID));
    l_parameter_index := l_parameter_index + 1;
    l_event_parameter_list(l_parameter_index) := l_param;

    -- Adding HEADER_ID parameter
    l_param := wf_parameter_t(NULL,NULL);
    l_event_parameter_list.EXTEND;
    l_param.setname('HEADER_ID');
    l_param.setvalue(:NEW.HEADER_ID);
    l_parameter_index := l_parameter_index + 1;
    l_event_parameter_list(l_parameter_index) := l_param;

    wf_event.RAISE
    (
      p_event_name => l_event_name,
      p_event_key  => l_event_key,
      p_parameters => l_event_parameter_list
    );
  end if;

EXCEPTION
WHEN OTHERS THEN
  xxssys_event_pkg.insert_mail_event(p_db_trigger_mode => 'Y',
                                     p_target_name     => 'STRATAFORCE',
                                     p_event_name      => l_event_name,
                                     p_user_id         => fnd_global.USER_ID,
                                     p_program_name_to => 'XXOM_SFORCE_ORDER_BOOK_DOC_SYNC_ERROR_TO',
                                     p_program_name_cc => 'XXOM_SFORCE_ORDER_BOOK_DOC_SYNC_ERROR_CC' ,
                                     p_operating_unit  => :NEW.ORG_ID,
                                     p_entity          => 'ORDER_BOOK_DOCS',
                                     p_entity_id       => :NEW.HEADER_ID,
                                     p_subject         => 'Strataforce - Error in Order Book document generator event processor',
                                     p_body            => 'Order Header ID: ' || :NEW.HEADER_ID || chr(13)||chr(10) ||
                                                          'Org ID: ' || :NEW.ORG_ID || chr(13)||chr(10) ||
                                                          substr(sqlerrm, 1, 4000) || chr(13)||chr(10) ||
                                                          'Error Time: ' || SYSDATE);
END XXOE_ORDER_LINES_ALL_TRG2;
/
