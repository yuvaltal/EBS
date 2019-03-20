CREATE OR REPLACE TRIGGER XXWSH_NEW_DELIVERIES_BU_TRG2
  before update of status_code on WSH_NEW_DELIVERIES
  for each row
WHEN (new.status_code='CL' and nvl(old.status_code,'-1')!='CL' )
DECLARE
--------------------------------------------------------------------
  --  name:            XXWSH_NEW_DELIVERIES_BU_TRG2
  --  create by:       Diptasurjya Chatterjee
  --  Revision:        1.0
  --  creation date:   08/07/2018
  --------------------------------------------------------------------
  --  purpose : This trigger will call the custom business event xxssys.oracle.apps.wsh.delivery.shipconfirmed
  --------------------------------------------------------------------
  --  ver  date        name                      desc
  --  1.0  08/07/2018  Diptasurjya Chatterjee    CHG0043434 - initial build
  --------------------------------------------------------------------
  l_event_parameter_list	WF_PARAMETER_LIST_T;
	l_param			            WF_PARAMETER_T;
	l_event_name			      VARCHAR2(100)	:= 'xxssys.oracle.apps.wsh.delivery.shipconfirmed';
	l_event_key			        VARCHAR2(100)	:= 'XXSHPCONF_EVNT:'||:new.delivery_id;

	l_parameter_index		NUMBER		:= 0;
begin
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

  -- Adding DELIVERY_ID parameter
  l_param := wf_parameter_t(NULL,NULL);
  l_event_parameter_list.EXTEND;
  l_param.setname('DELIVERY_ID');
  l_param.setvalue(TO_CHAR(:new.DELIVERY_ID));
	l_parameter_index := l_parameter_index + 1;
	l_event_parameter_list(l_parameter_index) := l_param;

	wf_event.RAISE
	(
		p_event_name => l_event_name,
		p_event_key  => l_event_key,
		p_parameters => l_event_parameter_list
	);

exception
when others then
  xxssys_event_pkg.insert_mail_event(p_db_trigger_mode => 'Y',
                                     p_target_name     => 'STRATAFORCE',
                                     p_event_name      => l_event_name,
                                     p_user_id         => fnd_global.USER_ID,
                                     p_program_name_to => 'XXOM_SFORCE_SHPCONFIRM_DOC_SYNC_ERROR_TO',
                                     p_program_name_cc => 'XXOM_SFORCE_SHPCONFIRM_DOC_SYNC_ERROR_CC' ,
                                     p_operating_unit  => null,
                                     p_entity          => 'SHIPCONFIRM_DOCS',
                                     p_entity_id       => :new.DELIVERY_ID,
                                     p_subject         => 'Strataforce - Error in Ship Confirm document generator event processor',
                                     p_body            => 'Delivery ID: ' || :new.DELIVERY_ID || chr(13)||chr(10) ||
                                                          /*'Order Number: ' || l_order_number || chr(13)||chr(10) ||
                                                          'Org ID: ' || l_org_id || chr(13)||chr(10) ||*/
                                                          substr(sqlerrm, 1, 4000) || chr(13)||chr(10) ||
                                                          'Error Time: ' || SYSDATE);
END XXWSH_NEW_DELIVERIES_BU_TRG2;
/
