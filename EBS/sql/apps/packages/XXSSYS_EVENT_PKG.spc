CREATE OR REPLACE PACKAGE xxssys_event_pkg AUTHID CURRENT_USER AS
  ----------------------------------------------------------------------------
  --  name:            xxssys_event_pkg
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   22/06/2015
  ----------------------------------------------------------------------------
  --  purpose :        CHG0035652 - Generic package to handle all common interface
  --                   related functionalities. Current functionalities include:
  --                       Inserting new event information in XXSSYS_EVENTS table
  --                       Purging event table
  --                       Update status of events to ERR or SUCCESS
  --                       Updated events with BPEL process instance ID
  --                       Check if event entity is already interfaced
  --                       Retry processing of error events
  --                   of events
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  22/06/2015  Diptasurjya Chatterjee(TCS)  CHG0035652 - initial build
  --  1.1  21/10/2015  Diptasurjya Chatterjee(TCS)  CHG0036886 - Change procedure generate_data_xml to consider target_name in query
  --                                                Add new procedure process_event_error,fetch_event_error to update event errors and
  --                                                store them in new error table XXSSYS_EVENT_ERRORS and display the same in custom
  --                                                event monitor form Also added attribute3 to be handled
  --                                                in functions/procedures:
  --                                                1. insert_event
  --                                                2. is_sync
  --                                                3. Purge
  --                                                Add new function to partition event table based on target
  --                                                name profile option set at site/user level
  --  1.2  26/10/2015  Kundan Bhagat                CHG0036750 - Updated/Added below procedures
  --                                                1. update_error
  --                                                2. update_success
  --                                                3. update_bpel_instance_id
  --                                                4. update_one_bpel_instance_id
  --                                                5. Retry
  --                                                6. insert_event
  --                                                7. Update_new
  -- 1.3 9.11.2017     yuval tal                    CHG0041829  add update_status_bulk
  -- 1.4 02/12/2018    Diptasurjya                  CHG0041829 - Modify xxssys_source_data_rec field length
  -- 1.5 20-Feb-2018   Lingaraj                     CHG0042196 - insert_event Over loaded Procedure Added
  -- 2.0 04/24/3018    Diptasurjya                  CHG0042626 - Add new procedures: process_event, purge_all, insert_mail_event, send_mail_from_events
  -- 2.1 12/12/2018    Diptasurjya                  CHG0043798 - Create new procedure process_event_autonomous to process event insert in autonomous mode
  ----------------------------------------------------------------------------
  ----------------------------------------------------------------------------
  /* Global Variable declaration for Logging unit*/
  g_log              VARCHAR2(1) := fnd_profile.value('AFLOG_ENABLED');
  g_log_module       VARCHAR2(100) := fnd_profile.value('AFLOG_MODULE');
  g_request_id       NUMBER := fnd_profile.value('CONC_REQUEST_ID');
  g_api_name         VARCHAR2(30) := 'xxssys_event_pkg';
  g_log_program_unit VARCHAR2(100);
  /* End - Global Variable Declaration */

  TYPE xxssys_source_data_rec IS RECORD(
    seq_no           NUMBER,
    target_name      VARCHAR2(30),
    entity_name      VARCHAR2(50), -- CHG0041829 change length from 10 to 50
    event_id         VARCHAR2(30),
    field_name       VARCHAR2(30),
    field_data_type  VARCHAR2(30),
    field_value      VARCHAR2(4000),
    last_update_date DATE); -- CHG0036886 - Dipta added on ECOM 14-MAR-2016

  TYPE xxssys_source_data_tab IS TABLE OF xxssys_source_data_rec INDEX BY BINARY_INTEGER;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name            Description
  -- 1.0  26/10/2015  Diptasurjya     Initial Creation for CHG0036886.
  --                  Chatterjee
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE write_log(p_msg VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function inserts new event record if unprocessed event does not exist, otherwise
  --          active_flag field will be updated for existing event
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/06/2015  Diptasurjya Chatterjee        Initial Build
  -- 1.1  27/10/2015  Diptasurjya Chatterjee        CHG0036886 - Added attribute3 to check_existing function call
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_event(p_xxssys_event_rec xxssys_events%ROWTYPE,
     p_db_trigger_mode  VARCHAR2 DEFAULT 'N');

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          This function inserts or updates event in XXSSYS_EVENTS table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  04/24/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE process_event(p_xxssys_event_rec xxssys_events%ROWTYPE,
      p_db_trigger_mode  VARCHAR2 DEFAULT 'N');

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0043798
  --          This function inserts or updates event in XXSSYS_EVENTS table in autonomous transaction mode
  --          CAUTION: Please use this CAREFULLY only when required, as this will run in its own SQL session,
  --          and will potentially cause too many seesions to be opened and concurrency issues with main session
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  12/12/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE process_event_autonomous(pa_xxssys_event_rec xxssys_events%ROWTYPE,
      pa_db_trigger_mode  VARCHAR2 DEFAULT 'N');

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function checks whether processed event is already inserted in
  --          event table for change entity
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/06/2015  Diptasurjya Chatterjee        Initial Build
  -- 1.1  27/10/2015  Diptasurjya Chatterjee        CHG0036886 - Added attribute3 to cursor query
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_sync(p_xxssys_event_rec xxssys_events%ROWTYPE) RETURN VARCHAR2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          Update event table status field to ERR for event_id
  --          This procedure is obsolete.
  --          DO NOT USE FOR ANY FUTURE INTERFACE DEVELOPMENTS. Use procedure process_event_error
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/06/2015  Diptasurjya Chatterjee        Initial Build
  -- 1.1  26/10/2015  Kundan Bhagat                 CHG0036750 - Added last_update_date in update query
  -- --------------------------------------------------------------------------------------------
  PROCEDURE update_error(p_event_id    IN NUMBER,
     p_err_message IN VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036750
  --          Update event table status field to NEW
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  24/09/2015  Kundan Bhagat                 Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE update_new(p_event_id    IN NUMBER,
             p_closed_flag IN VARCHAR2 DEFAULT 'Y');

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          Update status for event row in table XXSSYS_EVENTS
  --          Insert error message for event in error table XXSSYS_EVENT_ERRORS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/06/2015  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE process_event_error(p_event_id     IN NUMBER,
            p_error_system IN VARCHAR2,
            p_err_message  IN VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          Update event table status field to SUCCESS for event_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  24/06/2015  Diptasurjya Chatterjee        Initial Build
  -- 1.1  26/10/2015  Kundan Bhagat                 CHG0036750 - Added last_update_date in update query
  -- --------------------------------------------------------------------------------------------
  PROCEDURE update_success(p_event_id IN NUMBER);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042196
  --          Update event table status field to IN_PROCESS for event_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  28/02/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE update_inprocess(p_event_id IN NUMBER);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          Update event table bpel_instance_id for specified number of records
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  24/06/2015  Diptasurjya Chatterjee        Initial Build
  -- 1.1  26/10/2015  Kundan Bhagat                 CHG0036750 - Added last_update_date in update query
  -- --------------------------------------------------------------------------------------------

  FUNCTION update_bpel_instance_id(p_no_of_records    NUMBER,
               p_entity_name      VARCHAR2,
               p_target_name      VARCHAR2,
               p_bpel_instance_id NUMBER) RETURN VARCHAR2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          Update event table bpel_instance_id for specified event_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/06/2015  Diptasurjya Chatterjee        Initial Build
  -- 1.1  26/10/2015  Kundan Bhagat                 CHG0036750 - Added last_update_date in update query
  -- --------------------------------------------------------------------------------------------

  FUNCTION update_one_bpel_instance_id(p_event_id         NUMBER,
         p_entity_name      VARCHAR2,
         p_target_name      VARCHAR2,
         p_bpel_instance_id NUMBER)
    RETURN VARCHAR2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          Remove records from XXSSYS_EVENTS based on input status. The latest event record will
  --          kept in event table for every entity, attribute1 combination
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  17/07/2015  Diptasurjya Chatterjee        Initial Build
  -- 1.1  27/10/2015  Diptasurjya Chatterjee        CHG0036886 - Added attribute3 to delete query
  --                                                Add parameter p_target_name to procedure
  --                                                Fix delete query to check creation_date >
  --                                                (sysdate-nvl(p_event_days,1000000)) earlier it was <
  -- --------------------------------------------------------------------------------------------
  PROCEDURE purge(x_errbuf       OUT VARCHAR2,
        x_retcode      OUT NUMBER,
        p_event_status IN VARCHAR2,
        p_event_days   IN NUMBER,
        p_target_name  IN VARCHAR2 DEFAULT NULL);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          Remove all records from XXSSYS_EVENTS based on input entity/target/status/days combination
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  12/07/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE purge_all(x_errbuf       OUT VARCHAR2,
        x_retcode      OUT NUMBER,
        p_event_status IN VARCHAR2,
        p_event_days   IN NUMBER,
        p_target_name  IN VARCHAR2,
        p_entity_name  IN VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          Update status of specified entity_id, bpel_instance_id records to NEW
  --          This procedure will be called from the XXSSYS Event Monitor form
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  17/07/2015  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE retry(p_target_name      IN VARCHAR2,
        p_entity_name      IN VARCHAR2,
        p_bpel_instance_id IN VARCHAR2,
        x_records_updated  OUT NUMBER,
        x_status           OUT VARCHAR2,
        x_status_message   OUT VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          Generate XML data for provided event id for monitor form
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  30/07/2015  Diptasurjya Chatterjee        Initial Build
  -- 1.1  27/10/2015  Diptasurjya Chatterjee        CHG0036886 - Fix issue with multiple target names in event table
  -- --------------------------------------------------------------------------------------------
  PROCEDURE generate_data_xml(x_source_data_tbl IN OUT xxssys_source_data_tab,
          p_entity_name     IN VARCHAR2,
          p_event_id        IN VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          Fetch error data for provided event id for monitor form
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  30/10/2015  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE fetch_event_error(x_event_error_tbl IN OUT xxssys_source_data_tab,
          p_event_id        IN VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Function to partition event table based on target name set in profile XXSSYS_EVENT_TARGET
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name            Description
  -- 1.0  02/11/2015  Diptasurjya     Initial Creation for CHG0036886.
  --                  Chatterjee
  -- ---------------------------------------------------------------------------------------------
  FUNCTION partion_table_by_target(obj_schema VARCHAR2,
               obj_name   VARCHAR2) RETURN VARCHAR2;

  ------------------------------------------------
  -- update_status_bulk
  -- Ver  Date        Name            Description
  -- 1.1  9.11.207     yuval tal       CHGxxxxxxx add update_status_bulk

  ---------------------------------------------------

  PROCEDURE update_status_bulk(p_err_code    OUT VARCHAR2,
           p_err_message OUT VARCHAR2,
           p_event_tab   xxobjt.xxssys_events_tab);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042196
  --          This function inserts new event record if unprocessed event does not exist,and returns the Event ID
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                          Description
  -- 1.0  20-Feb-2018  Lingaraj Sarangi               CHG0042196 - Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE insert_event(p_xxssys_event_rec xxssys_events%ROWTYPE,
     p_db_trigger_mode  VARCHAR2 DEFAULT 'N',
     x_event_id         OUT NUMBER);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042196
  --          This function inserts new event record if unprocessed event does not exist,and returns the Event ID
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                          Description
  -- 1.0  20-Feb-2018  Lingaraj Sarangi               CHG0042196 - Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE insert_event(p_target_name xxssys_events.target_name%TYPE,
     p_entity_name xxssys_events.entity_name%TYPE,
     p_entity_id   xxssys_events.entity_id%TYPE,
     p_active_flag xxssys_events.active_flag%TYPE,
     p_status      xxssys_events.status%TYPE,
     p_event_name  xxssys_events.event_name%TYPE,
     --p_request_messgae    xxssys_events.request_messgae%type,
     --p_err_message        xxssys_events.err_message%type,
     p_attribute1       xxssys_events.attribute1%TYPE,
     p_attribute2       xxssys_events.attribute2%TYPE,
     p_attribute3       xxssys_events.attribute3%TYPE,
     p_attribute4       xxssys_events.attribute4%TYPE,
     p_attribute5       xxssys_events.attribute5%TYPE,
     p_attribute6       xxssys_events.attribute6%TYPE,
     p_attribute7       xxssys_events.attribute7%TYPE,
     p_attribute8       xxssys_events.attribute8%TYPE,
     p_attribute9       xxssys_events.attribute9%TYPE,
     p_attribute10      xxssys_events.attribute10%TYPE,
     p_last_update_date xxssys_events.last_update_date%TYPE,
     p_last_updated_by  xxssys_events.last_updated_by%TYPE,
     p_creation_date    xxssys_events.creation_date%TYPE,
     p_created_by       xxssys_events.created_by%TYPE,
     --p_last_update_login  xxssys_events.last_update_login%type,
     --p_bpel_instance_id   xxssys_events.bpel_instance_id%type,
     --p_api_message        xxssys_events.api_message%type,
     p_entity_code     xxssys_events.entity_code%TYPE,
     p_external_id     xxssys_events.external_id%TYPE,
     p_db_trigger_mode VARCHAR2 DEFAULT 'N',
     x_event_id        OUT xxssys_events.event_id%TYPE);


  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          This Procedure is used to insert NOTIF_EMAIL type events in the event table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                       Description
  -- 1.0  07/11/2018  Diptasurjya Chatterjee     Initial Build
  -- --------------------------------------------------------------------------------------------
  procedure insert_mail_event(p_db_trigger_mode IN VARCHAR2,
                              p_target_name     IN VARCHAR2,
                              p_program_name_to IN VARCHAR2,
                              p_program_name_cc IN VARCHAR2,
                              p_operating_unit  IN NUMBER,
                              p_entity          IN VARCHAR2,
                              p_entity_id       IN NUMBER default null,
                              p_entity_code     IN VARCHAR2 default NULL,
                              p_subject         IN VARCHAR2,
                              p_body            IN VARCHAR2,
                              p_event_name      IN VARCHAR2,
                              p_user_id         IN NUMBER);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          This Procedure is used to send Emails for all EMAIL_NOTIF events in NEW status
  --          based on input target name
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  13/07/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE send_mail_from_events(errbuf  OUT VARCHAR2,
                                  retcode OUT NUMBER,
                                  p_target_name IN VARCHAR2);
END xxssys_event_pkg;
/
