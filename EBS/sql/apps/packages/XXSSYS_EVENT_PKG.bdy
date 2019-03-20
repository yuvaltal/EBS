CREATE OR REPLACE PACKAGE BODY xxssys_event_pkg AS
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
  --                                                Add new procedure process_event_error to update event errors and store
  --                                                them in new error table XXSSYS_EVENT_ERRORS. Also added attribute3 to be handled
  --                                                in functions/procedures:
  --                                                1. insert_event
  --                                                2. is_sync
  --                                                3. Purge
  --                                                Add new function partion_table_by_target to partition
  --                                                event table based on target name profile option set at site/user level
  --  1.2  26/10/2015  Kundan Bhagat                CHG0036750 - Updated/Added below procedures
  --                                                1. update_error
  --                                                2. update_success
  --                                                3. update_bpel_instance_id
  --                                                4. update_one_bpel_instance_id
  --                                                                                                5. Retry
  --                                                                                                6. insert_event
  --                                                                                                7. Update_new
  --
  -- 1.3 9.11.2017    yuval tal                  CHG0041829 add update_status_bulk
  --                                                         modify insert_event /check_exists/delete_event
  -- 1.4 28/12/2017   Diptasurjya Chatterjee      CHG0041829 - Modify generate_data_xml procedure to handle query based data source also
  -- 1.5  9.11.207    yuval tal                   CHG0041829 add update_status_bulk
  -- 1.6  20-Feb-2018  Lingaraj                   CHG0042196 - insert_event Over loaded Procedure Added
  -- 1.7  17/07/2018  Lingaraj Sarangi            CTASK0037600  - Purge the Records which are in ERR , but higher events are Processed
  -- 1.8  07/27/2018  Diptasurjya                 CHG0042626 - Customer interface re-design related changes
  -- 1.9  2-Aug-2018  Lingaraj                    CHG0043574 - modify partion_table_by_target Event monitor form - adding security functionality
  -- 2.0  27-Sep-2018 Lingaraj                    CHG0044070 - CTASK0038565 - xxssys_events  table performence check
  -- 2.1  04/01/2019  Roman W.                    INC0143319 - bug fix
  -- 2.2  12/12/2018  Diptasurjya                 CHG0043798 - Create new procedure process_event_autonomous to process event insert in autonomous mode
  --                                              Modify process_event to fix bug in building the concatenated key cols field
  -- 2.3  25/01/2019  Diptasurjya                 INC0145264 - Email event enter changed to fetch distribution list without OOU in case null value is
  --                                              fetched for specific OU
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name            Description
  -- 1.0  26/10/2015  Diptasurjya     Initial Creation for CHG0036886.
  --                  Chatterjee
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE write_log(p_msg VARCHAR2) IS
  BEGIN

    IF g_log = 'Y' AND 'xxssys.event_process.' || g_api_name ||
       g_log_program_unit LIKE lower(g_log_module) THEN
      fnd_log.string(log_level => fnd_log.level_unexpected,
	         module    => 'xxssys.event_process.' || g_api_name ||
		          g_log_program_unit,
	         message   => p_msg);
    END IF;
  END write_log;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function checks exists of unc sync record
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/06/2015  Diptasurjya Chatterjee        Initial Build
  -- 1.1  27/10/2015  Diptasurjya Chatterjee        CHG0036886 - Added attribute3 to cursor query
  -- 1.2  09.11.17    yuval tal                     CHGxxxxxxx add source_code support
  -- 1.3  27-Sep-2018 Lingaraj                      CHG0044070 - CTASK0038565 - xxssys_events  table performence check
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_existing(p_target_name IN VARCHAR2,
		  p_entity_name IN VARCHAR2,
		  p_entity_id   IN NUMBER,
		  p_entity_code IN VARCHAR2,
		  p_attribute1  IN VARCHAR2,
		  p_attribute2  IN VARCHAR2,
		  p_attribute3  IN VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2 IS

    l_event_id NUMBER := 0;

    CURSOR c_exists IS
      SELECT event_id
      FROM   xxssys_events
      WHERE  status = 'NEW'
	--concatenated_key_cols Added on 27 Sep 2018 for CHG0044070
      AND    concatenated_key_cols =
	 (p_target_name || '-' || p_entity_name || '-' ||
	 p_entity_code || '-' || p_entity_id || '-' || p_attribute1 || '-' ||
	 p_attribute2 || '-' || p_attribute3);

    /*AND    nvl(entity_id, -1) = nvl(p_entity_id, -1)
    AND    nvl(entity_code, '~') = nvl(p_entity_code, '~')
    AND    entity_name = p_entity_name
    AND    target_name = p_target_name
    AND    nvl(attribute1, '-1') = nvl(p_attribute1, '-1')
    AND    nvl(attribute2, '-1') = nvl(p_attribute2, '-1')
    AND    nvl(attribute3, '-1') = nvl(p_attribute3, '-1');*/ --Commented on 27 Sep 2018 for CHG0044070
  BEGIN

    OPEN c_exists;
    FETCH c_exists
      INTO l_event_id;

    IF c_exists%FOUND THEN
      RETURN l_event_id;
    ELSE
      RETURN 0;
    END IF;
    CLOSE c_exists;

  END check_existing;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          Delete specific NEW events from event table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/06/2015  Diptasurjya Chatterjee        Initial Build
  -- 1.1  27/10/2015  Diptasurjya Chatterjee        CHG0036886 - Added attribute3 to cursor query
  -- 1.2  09.11.17    yuval tal                     CHGxxxxxxx add source_code support
  -- --------------------------------------------------------------------------------------------
  PROCEDURE delete_event(p_xxssys_event_rec xxssys_events%ROWTYPE) IS
  BEGIN
    DELETE FROM xxssys_events
    WHERE  status = 'NEW'
    AND    nvl(entity_id, -1) = nvl(p_xxssys_event_rec.entity_id, -1) --CHGxxxxxxx
    AND    nvl(entity_code, '~') = nvl(p_xxssys_event_rec.entity_code, '~') --CHGxxxxxxx
    AND    entity_name = p_xxssys_event_rec.entity_name
    AND    target_name = p_xxssys_event_rec.target_name
    AND    nvl(attribute1, '-1') = nvl(p_xxssys_event_rec.attribute1, '-1')
    AND    nvl(attribute2, '-1') = nvl(p_xxssys_event_rec.attribute2, '-1')
    AND    nvl(attribute3, '-1') = nvl(p_xxssys_event_rec.attribute3, '-1');
    COMMIT;
  END delete_event;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function checks whether processed event is already inserted in
  --          event table for change entity
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/06/2015  Diptasurjya Chatterjee        Initial Build
  -- 1.1  27/10/2015  Diptasurjya Chatterjee        CHG0036886 - Added attribute3 to cursor query
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_sync(p_xxssys_event_rec xxssys_events%ROWTYPE) RETURN VARCHAR2 IS
    l_active VARCHAR2(1);

    CURSOR c_active IS
      SELECT active_flag
      FROM   (SELECT nvl(active_flag, 'Y') active_flag,
	         rank() over(PARTITION BY xe1.entity_id, xe1.attribute1, xe1.attribute2, xe1.attribute3, xe1.entity_name, xe1.target_name ORDER BY xe1.event_id DESC) rn
	  FROM   xxssys_events xe1
	  WHERE  status = 'SUCCESS'
	  AND    entity_id = p_xxssys_event_rec.entity_id
	  AND    entity_name = p_xxssys_event_rec.entity_name
	  AND    target_name = p_xxssys_event_rec.target_name
	  AND    nvl(attribute1, '-1') =
	         nvl(p_xxssys_event_rec.attribute1, '-1')
	  AND    nvl(attribute2, '-1') =
	         nvl(p_xxssys_event_rec.attribute2, '-1')
	  AND    nvl(attribute3, '-1') =
	         nvl(p_xxssys_event_rec.attribute3, '-1'))
      WHERE  rn = 1;
  BEGIN

    OPEN c_active;
    FETCH c_active
      INTO l_active;

    IF c_active%NOTFOUND THEN
      /*delete_event(p_xxssys_event_rec);*/ /* This code block is reachable only if event entity is
                                                                                                                                                                                             not enabled for interfacing, and the entity was never
                                                                                                                                                                                             interfaced before - This code will remove all unprocessed
                                                                                                                                                                                             events for the entity, as data for this entity is not
                                                                                                                                                                                             yet interfaced, hence not to be inactivated and is not
                                                                                                                                                                                             currently eligible for interfacing
                                                                                                                                                                                             */
      RETURN 'FALSE';
    ELSIF c_active%FOUND AND l_active = 'N' THEN
      RETURN 'FALSE';
    ELSE
      RETURN 'TRUE';
    END IF;

    CLOSE c_active;

  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          This function inserts or updates event in XXSSYS_EVENTS table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  04/24/2018  Diptasurjya Chatterjee        Initial Build
  -- 1.1  19/12/2018  Diptasurjya                   CHG0043798 - Entity_code column should be included
  --                                                while building the field concatenated_key_cols
  -- --------------------------------------------------------------------------------------------
  PROCEDURE process_event(p_xxssys_event_rec xxssys_events%ROWTYPE,
		  p_db_trigger_mode  VARCHAR2 DEFAULT 'N') IS
    l_event_id           NUMBER;
    l_last_success_event NUMBER := 0;
    l_message_match      VARCHAR2(1) := 'N';

    l_status         VARCHAR2(5) := 'NEW';
    l_status_message VARCHAR2(2000) := NULL;

  BEGIN

    -- Section 1.
    -- Below section will identify if event for same entity and target exists in NEW status
    l_event_id := check_existing(p_xxssys_event_rec.target_name,
		         p_xxssys_event_rec.entity_name,
		         p_xxssys_event_rec.entity_id,
		         p_xxssys_event_rec.entity_code,
		         p_xxssys_event_rec.attribute1,
		         p_xxssys_event_rec.attribute2,
		         p_xxssys_event_rec.attribute3);

    IF l_event_id = 0 THEN
      -- NEW event does not exist for entity
      -- Section 2.
      -- Below section will identify last interfaced event id for entity_id/attribute1/attribute2/attribute3/entity_name/target_name combination
      BEGIN
        SELECT event_id
        INTO   l_last_success_event
        FROM   (SELECT xe1.event_id,
	           rank() over(PARTITION BY xe1.entity_id, xe1.attribute1, xe1.attribute2, xe1.attribute3, xe1.entity_name, xe1.target_name ORDER BY xe1.event_id DESC) rn
	    FROM   xxssys_events xe1
	    WHERE  status = 'SUCCESS'
	    AND    entity_id = p_xxssys_event_rec.entity_id
	    AND    entity_name = p_xxssys_event_rec.entity_name
	    AND    target_name = p_xxssys_event_rec.target_name
	    AND    nvl(attribute1, '-1') =
	           nvl(p_xxssys_event_rec.attribute1, '-1')
	    AND    nvl(attribute2, '-1') =
	           nvl(p_xxssys_event_rec.attribute2, '-1')
	    AND    nvl(attribute3, '-1') =
	           nvl(p_xxssys_event_rec.attribute3, '-1'))
        WHERE  rn = 1;
      EXCEPTION
        WHEN no_data_found THEN
          l_last_success_event := 0;
      END;

      -- Section 3.
      -- If last interfaced event is found then compare the event message of the last interfaced event with current event message
      IF l_last_success_event <> 0 THEN
        -- Event with specified entity details was successfully interfaced earlier
        SELECT decode(dbms_lob.compare(p_xxssys_event_rec.event_message,
			   xe.event_message),
	          0,
	          'Y',
	          'N')
        INTO   l_message_match
        FROM   xxssys_events xe
        WHERE  xe.event_id = l_last_success_event;
      ELSE
        l_message_match := 'N'; -- If no previously interfaced events found then set message match flag to N, so as to insert new event
      END IF;

      -- Section 4.
      -- If the event message is different than previous interfaced event, or if no previous interfaced event was found
      -- then insert a new event
      IF l_message_match = 'N' THEN

        INSERT INTO xxssys_events
          (event_id,
           target_name,
           entity_name,
           entity_id,
           status,
           event_name,
           request_messgae,
           err_message,
           attribute1,
           attribute2,
           attribute3,
           attribute4,
           attribute5,
           attribute6,
           attribute7,
           attribute8,
           attribute9,
           attribute10,
           active_flag,
           last_update_date,
           last_updated_by,
           creation_date,
           created_by,
           last_update_login,
           concatenated_key_cols,
           event_message)
        VALUES
          (xxssys_events_seq.nextval,
           p_xxssys_event_rec.target_name,
           p_xxssys_event_rec.entity_name,
           p_xxssys_event_rec.entity_id,
           nvl(p_xxssys_event_rec.status, l_status),
           p_xxssys_event_rec.event_name, --p_event.geteventname(),
           nvl(p_xxssys_event_rec.err_message, l_status_message),
           NULL,
           p_xxssys_event_rec.attribute1,
           p_xxssys_event_rec.attribute2,
           p_xxssys_event_rec.attribute3,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           p_xxssys_event_rec.active_flag,
           SYSDATE,
           p_xxssys_event_rec.last_updated_by,
           SYSDATE,
           p_xxssys_event_rec.created_by,
           NULL,
           p_xxssys_event_rec.target_name || '-' ||
           p_xxssys_event_rec.entity_name || '-' ||
           p_xxssys_event_rec.entity_code || '-' || -- CHG0043798 bug - add new column to concatenated field
           p_xxssys_event_rec.entity_id || '-' ||
           p_xxssys_event_rec.attribute1 || '-' ||
           p_xxssys_event_rec.attribute2 || '-' ||
           p_xxssys_event_rec.attribute3,
           p_xxssys_event_rec.event_message);
      END IF;
    ELSE
      -- NEW status event exists for entity
      -- Only update the event message for the existing NEW event
      -- No event match checks will be done for this case

      UPDATE xxssys_events
      SET    event_message    = p_xxssys_event_rec.event_message,
	 status           = nvl(p_xxssys_event_rec.status, status),
	 err_message      = nvl(p_xxssys_event_rec.err_message,
			err_message),
	 last_update_date = SYSDATE,
	 last_updated_by  = p_xxssys_event_rec.last_updated_by
      WHERE  event_id = l_event_id;

    END IF;

    IF p_db_trigger_mode = 'N' THEN
      COMMIT;
    END IF;
  EXCEPTION
    WHEN dup_val_on_index THEN
      NULL;
  END process_event;

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
			 pa_db_trigger_mode  VARCHAR2 DEFAULT 'N') IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    process_event(p_xxssys_event_rec => pa_xxssys_event_rec,
	      p_db_trigger_mode  => pa_db_trigger_mode);
  END process_event_autonomous;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042196
  --          This function inserts new event record if unprocessed event does not exist
  --          and returns the Event ID
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                          Description
  -- 1.0  20-Feb-2018  Lingaraj Sarangi               CHG0042196 - Initial Build
  -- 1.3  07/10/2018   Diptasurjya                   CHG0042626 - Add event_message field
  -- --------------------------------------------------------------------------------------------
  PROCEDURE insert_event(p_xxssys_event_rec xxssys_events%ROWTYPE,
		 p_db_trigger_mode  VARCHAR2 DEFAULT 'N',
		 x_event_id         OUT NUMBER) IS
    l_status         VARCHAR2(5) := 'NEW';
    l_status_message VARCHAR2(2000) := NULL;
    l_event_id       NUMBER;
  BEGIN
    -- CHG0042626 - Add check for existing event below
    l_event_id := check_existing(p_xxssys_event_rec.target_name,
		         p_xxssys_event_rec.entity_name,
		         p_xxssys_event_rec.entity_id,
		         p_xxssys_event_rec.entity_code,
		         p_xxssys_event_rec.attribute1,
		         p_xxssys_event_rec.attribute2,
		         p_xxssys_event_rec.attribute3);

    IF l_event_id = 0 THEN
      -- CHG0042626 - No existing events so insert NEW event
      INSERT INTO xxssys_events
        (event_id,
         target_name,
         entity_name,
         entity_id,
         entity_code,
         status,
         event_name,
         request_messgae,
         err_message,
         attribute1,
         attribute2,
         attribute3,
         attribute4,
         attribute5,
         attribute6,
         attribute7,
         attribute8,
         attribute9,
         attribute10,
         active_flag,
         last_update_date,
         last_updated_by,
         creation_date,
         created_by,
         last_update_login,
         event_message, -- CHG0042626
         concatenated_key_cols)
      VALUES
        (xxssys_events_seq.nextval,
         p_xxssys_event_rec.target_name,
         p_xxssys_event_rec.entity_name,
         p_xxssys_event_rec.entity_id,
         p_xxssys_event_rec.entity_code,
         l_status,
         p_xxssys_event_rec.event_name,
         l_status_message,
         NULL,
         p_xxssys_event_rec.attribute1,
         p_xxssys_event_rec.attribute2,
         p_xxssys_event_rec.attribute3,
         p_xxssys_event_rec.attribute4,
         p_xxssys_event_rec.attribute5,
         p_xxssys_event_rec.attribute6,
         p_xxssys_event_rec.attribute7,
         p_xxssys_event_rec.attribute8,
         p_xxssys_event_rec.attribute9,
         p_xxssys_event_rec.attribute10,
         p_xxssys_event_rec.active_flag,
         SYSDATE,
         p_xxssys_event_rec.last_updated_by,
         SYSDATE,
         p_xxssys_event_rec.created_by,
         NULL,
         p_xxssys_event_rec.event_message, -- CHG0042626
         p_xxssys_event_rec.target_name || '-' ||
         p_xxssys_event_rec.entity_name || '-' ||
         p_xxssys_event_rec.entity_code || '-' ||
         p_xxssys_event_rec.entity_id || '-' ||
         p_xxssys_event_rec.attribute1 || '-' ||
         p_xxssys_event_rec.attribute2 || '-' ||
         p_xxssys_event_rec.attribute3)
      RETURNING event_id INTO x_event_id;
      -- CHG0042626 - If event exists then update event_message with new data
    ELSE
      UPDATE xxssys_events
      SET    active_flag      = p_xxssys_event_rec.active_flag,
	 event_message    = p_xxssys_event_rec.event_message,
	 last_update_date = SYSDATE,
	 last_updated_by  = p_xxssys_event_rec.last_updated_by
      WHERE  event_id = l_event_id;

      x_event_id := l_event_id;
    END IF;

    IF p_db_trigger_mode = 'N' THEN
      COMMIT;
    END IF;
  EXCEPTION
    WHEN dup_val_on_index THEN
      x_event_id := -1;
  END insert_event;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function inserts new event record if unprocessed event does not exist, otherwise
  --          active_flag field will be updated for existing event
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/06/2015  Diptasurjya Chatterjee        Initial Build
  -- 1.1  27/10/2015  Diptasurjya Chatterjee        CHG0036886 - Added attribute3 to check_existing function call
  -- 1.2  28/01/2015  Kundan Bhagat                                                 CHG0036750 - Updated Insert statement to insert value of newly added
  -- 1.3  9.11.207     yuval tal                     CHGxxxxxxx  support ENTITY_CODE
  -- 1.4  20-Feb-2018  Lingaraj                      CHG0042196 - insert_event Over loaded Procedure Added
  -- --------------------------------------------------------------------------------------------
  PROCEDURE insert_event(p_xxssys_event_rec xxssys_events%ROWTYPE,
		 p_db_trigger_mode  VARCHAR2 DEFAULT 'N') IS
    l_event_id       NUMBER;
    l_status         VARCHAR2(5) := 'NEW';
    l_status_message VARCHAR2(2000) := NULL;

  BEGIN
    --v1.4 CHG0042196 - Calling the Overloaded Procedure
    insert_event(p_xxssys_event_rec => p_xxssys_event_rec,
	     p_db_trigger_mode  => p_db_trigger_mode,
	     x_event_id         => l_event_id);

    /* INSERT INTO xxssys_events
      (event_id,
       target_name,
       entity_name,
       entity_id,
       entity_code, --CHGxxxxxxx
       status,
       event_name,
       request_messgae,
       err_message,
       attribute1,
       attribute2,
       attribute3,
       attribute4,
       attribute5,
       attribute6,
       attribute7,
       attribute8,
       attribute9,
       attribute10,
       active_flag,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by,
       last_update_login,
       concatenated_key_cols)
    VALUES
      (xxssys_events_seq.nextval,
       p_xxssys_event_rec.target_name,
       p_xxssys_event_rec.entity_name,
       p_xxssys_event_rec.entity_id,
       p_xxssys_event_rec.entity_code, --CHGxxxxxxx
       l_status,
       p_xxssys_event_rec.event_name, --p_event.geteventname(),
       l_status_message,
       NULL,
       p_xxssys_event_rec.attribute1,
       p_xxssys_event_rec.attribute2,
       p_xxssys_event_rec.attribute3,
       p_xxssys_event_rec.attribute4,
       p_xxssys_event_rec.attribute5,
       p_xxssys_event_rec.attribute6,
       p_xxssys_event_rec.attribute7,
       p_xxssys_event_rec.attribute8,
       p_xxssys_event_rec.attribute9,
       p_xxssys_event_rec.attribute10,
       p_xxssys_event_rec.active_flag,
       SYSDATE,
       p_xxssys_event_rec.last_updated_by,
       SYSDATE,
       p_xxssys_event_rec.created_by,
       NULL,
       p_xxssys_event_rec.target_name || '-' ||
       p_xxssys_event_rec.entity_name || '-' ||
       p_xxssys_event_rec.entity_code || '-' ||
       p_xxssys_event_rec.entity_id || '-' || p_xxssys_event_rec.attribute1 || '-' ||
       p_xxssys_event_rec.attribute2 || '-' ||
       p_xxssys_event_rec.attribute3); --CHGxxxxxxx

    IF p_db_trigger_mode = 'N' THEN
      COMMIT;
    END IF;      */
    /* ELSE
         UPDATE xxssys_events
         SET    active_flag = p_xxssys_event_rec.active_flag
         WHERE  event_id = l_event_id;

         IF p_db_trigger_mode = 'N' THEN
           COMMIT;
         END IF;
      END IF;
    EXCEPTION
      WHEN dup_val_on_index THEN
        NULL;*/
  END insert_event;

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
		 p_err_message IN VARCHAR2) IS
  BEGIN
    UPDATE xxssys_events
    SET    status           = 'ERR',
           err_message      = p_err_message,
           last_update_date = SYSDATE
    WHERE  event_id = p_event_id;
  END update_error;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036750
  --          Update event table status field to NEW
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  24/09/2015  Kundan Bhagat                 Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE update_new(p_event_id    IN NUMBER,
	           p_closed_flag IN VARCHAR2 DEFAULT 'Y') IS
    l_status VARCHAR2(20);
  BEGIN
    UPDATE xxssys_events xe
    SET    xe.status          = 'NEW',
           xe.request_messgae = NULL,
           xe.err_message     = NULL,
           last_update_date   = SYSDATE
    WHERE  xe.event_id = p_event_id;
    COMMIT;
  EXCEPTION
    WHEN dup_val_on_index THEN
      -- new records already exists !!!!
      IF p_closed_flag = 'Y' THEN
        UPDATE xxssys_events xe
        SET    xe.status          = 'CLOSED',
	   xe.request_messgae = NULL,
	   xe.err_message     = NULL,
	   last_update_date   = SYSDATE
        WHERE  xe.event_id = p_event_id;
        COMMIT;
      ELSE
        RAISE dup_val_on_index;
      END IF;
    WHEN OTHERS THEN
      ROLLBACK;
  END update_new;

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
		        p_err_message  IN VARCHAR2) IS
  BEGIN
    UPDATE xxssys_events
    SET    status           = 'ERR',
           last_update_date = SYSDATE
    WHERE  event_id = p_event_id;

    INSERT INTO xxssys_event_errors
      (event_error_id,
       event_id,
       error_system,
       status_message,
       created_by,
       creation_date,
       last_updated_by,
       last_update_date,
       last_update_login)
    VALUES
      (xxssys_event_error_seq.nextval,
       p_event_id,
       p_error_system,
       p_err_message,
       -1,
       SYSDATE,
       -1,
       SYSDATE,
       -1);
  END process_event_error;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          Update event table status field to SUCCESS for event_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  24/06/2015  Diptasurjya Chatterjee        Initial Build
  -- 1.1  26/10/2015  Kundan Bhagat                 CHG0036750 - Added last_update_date in update query
  -- --------------------------------------------------------------------------------------------
  PROCEDURE update_success(p_event_id IN NUMBER) IS
  BEGIN
    UPDATE xxssys_events
    SET    status           = 'SUCCESS',
           err_message      = NULL,
           last_update_date = SYSDATE
    WHERE  event_id = p_event_id;

  END update_success;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042196
  --          Update event table status field to IN_PROCESS for event_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  28/02/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE update_inprocess(p_event_id IN NUMBER) IS
  BEGIN
    UPDATE xxssys_events
    SET    status           = 'IN_PROCESS',
           err_message      = NULL,
           last_update_date = SYSDATE
    WHERE  event_id = p_event_id;

  END update_inprocess;

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
		           p_bpel_instance_id NUMBER) RETURN VARCHAR2 IS
  BEGIN
    UPDATE xxssys_events
    SET    bpel_instance_id = p_bpel_instance_id,
           last_update_date = SYSDATE
    WHERE  ROWID IN (SELECT ROWID
	         FROM   (SELECT ROWID,
			event_id,
			rank() over(PARTITION BY status ORDER BY event_id) AS ran
		     FROM   xxssys_events
		     WHERE  status = 'NEW'
		     AND    entity_name = p_entity_name
		     AND    target_name = p_target_name)
	         WHERE  ran <= p_no_of_records);

    COMMIT;
    RETURN 'Y';
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END update_bpel_instance_id;

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
    RETURN VARCHAR2 IS
  BEGIN
    UPDATE xxssys_events
    SET    bpel_instance_id = p_bpel_instance_id,
           last_update_date = SYSDATE
    WHERE  entity_name = p_entity_name
    AND    target_name = p_target_name
    AND    event_id = p_event_id;

    COMMIT;
    RETURN 'Y';
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END update_one_bpel_instance_id;

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
  -- 1.2  17/07/2018  Lingaraj Sarangi              CTASK0037600  - Purge the Records which are in ERR , but higher events are Processed
  -- --------------------------------------------------------------------------------------------
  PROCEDURE purge(x_errbuf       OUT VARCHAR2,
	      x_retcode      OUT NUMBER,
	      p_event_status IN VARCHAR2,
	      p_event_days   IN NUMBER,
	      p_target_name  IN VARCHAR2 DEFAULT NULL) IS
    l_records_updated NUMBER;
    l_record_found    VARCHAR2(1);
  BEGIN
    DELETE FROM xxssys_events xe2
    WHERE  xe2.event_id IN
           (SELECT event_id
	FROM   (SELECT xe1.event_id,
		   xe1.entity_id,
		   xe1.attribute1,
		   xe1.attribute2,
		   xe1.attribute3,
		   xe1.entity_name,
		   xe1.target_name,
		   xe1.status,
		   rank() over(PARTITION BY concatenated_key_cols ORDER BY xe1.event_id DESC) rn
	        FROM   xxssys_events xe1
	        WHERE  xe1.status = nvl(p_event_status, xe1.status)
	        AND    xe1.status NOT IN ('IN_PROCESS', 'NEW')
	        AND    xe1.target_name =
		   nvl(p_target_name, xe1.target_name)
	        AND    trunc(xe1.creation_date) <
		   (SYSDATE - nvl(p_event_days, 1000000)))
	WHERE  rn > 1);

    l_records_updated := SQL%ROWCOUNT;

    --Begin CTASK0037600
    --After deleting all relevant records , create new cursor for ERR records only
    --If success records exists with higher event_id in status success per same CONCATENATED_KEY_COLS then delete record
    FOR rec IN (SELECT event_id,
	           concatenated_key_cols
	    FROM   xxssys_events xe
	    WHERE  xe.status = 'ERR'
	    AND    xe.target_name = nvl(p_target_name, xe.target_name)
	    AND    trunc(xe.creation_date) >
	           (SYSDATE - nvl(p_event_days, 1000000))) LOOP
      l_record_found := 'N';
      BEGIN
        SELECT 'Y'
        INTO   l_record_found
        FROM   xxssys_events xe
        WHERE  xe.status = 'SUCCESS'
        AND    xe.concatenated_key_cols = rec.concatenated_key_cols
        AND    xe.event_id > rec.event_id
        AND    rownum = 1;

        DELETE FROM xxssys_events xe
        WHERE  event_id = rec.event_id;

        l_records_updated := l_records_updated + 1;
      EXCEPTION
        WHEN no_data_found THEN
          l_record_found := 'N';
      END;

    END LOOP;
    --ENd CTASK0037600

    COMMIT;

    x_errbuf  := 'SUCCESS';
    x_retcode := 0;

    fnd_file.put_line(fnd_file.log,
	          'Purge program completed successfully. Total records purged: ' ||
	          l_records_updated);

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      fnd_file.put_line(fnd_file.log,
		'Purge program completed with errors.');
      fnd_file.put_line(fnd_file.log, 'ERROR MESSAGE: ' || SQLERRM);

      x_errbuf  := 'ERROR';
      x_retcode := 2;
  END;

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
	          p_entity_name  IN VARCHAR2) IS
    l_records_updated NUMBER;
  BEGIN
    DELETE FROM xxssys_events xe
    WHERE  xe.target_name = p_target_name
    AND    trunc(xe.creation_date) < (SYSDATE - nvl(p_event_days, 0))
    AND    xe.entity_name = p_entity_name
    AND    xe.status = p_event_status;

    l_records_updated := SQL%ROWCOUNT;

    COMMIT;

    x_errbuf  := 'SUCCESS';
    x_retcode := 0;

    fnd_file.put_line(fnd_file.log,
	          'Purge All program completed successfully. Total records purged for entity: ' ||
	          p_entity_name || ' for target: ' || p_target_name ||
	          ' :: ' || l_records_updated);

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      fnd_file.put_line(fnd_file.log,
		'Purge All program completed with errors.');
      fnd_file.put_line(fnd_file.log, 'ERROR MESSAGE: ' || SQLERRM);

      x_errbuf  := 'ERROR';
      x_retcode := 2;
  END purge_all;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          Update status of specified entity_id, bpel_instance_id records to NEW
  --          This procedure will be called from the XXSSYS Event Monitor form
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  17/07/2015  Diptasurjya Chatterjee        Initial Build
  -- 1.1  28/01/2015  Kundan Bhagat                 CHG0036750 -Commented Update statement and call update_new procedure
  -- 1.2  04/01/2019  Roman W.                      INC0143319 -  bug fix
  -- --------------------------------------------------------------------------------------------
  PROCEDURE retry(p_target_name      IN VARCHAR2,
	      p_entity_name      IN VARCHAR2,
	      p_bpel_instance_id IN VARCHAR2,
	      x_records_updated  OUT NUMBER,
	      x_status           OUT VARCHAR2,
	      x_status_message   OUT VARCHAR2) IS

    CURSOR cur_retry(p_entity_name      IN VARCHAR2,
	         p_target_name      IN VARCHAR2,
	         p_bpel_instance_id IN VARCHAR2) IS
    /* Rem By Romaqn 04/12/2019 - INC0143319
                                                                      SELECT event_id
                                                                      FROM   xxssys_events a
                                                                      WHERE  a.entity_name = nvl(p_entity_name, a.entity_name)
                                                                      AND    a.target_name = nvl(p_target_name, a.target_name)
                                                                      AND    nvl(a.bpel_instance_id, -1) = nvl(p_bpel_instance_id, nvl(a.bpel_instance_id, -1))
                                                                      AND    a.status = 'ERR';
                                                                      */
    -- Added By Roman W. 04/12/2019 INC0143319
      SELECT event_id
      FROM   (SELECT event_id,
	         row_number() over(PARTITION BY concatenated_key_cols ORDER BY event_id DESC) row_inx
	  FROM   xxssys_events xe_main
	  WHERE  xe_main.entity_name =
	         nvl(p_entity_name, xe_main.entity_name)
	  AND    xe_main.target_name =
	         nvl(p_target_name, xe_main.target_name)
	  AND    xe_main.bpel_instance_id =
	         nvl(p_bpel_instance_id,
		  nvl(xe_main.bpel_instance_id, -1))
	  AND    xe_main.status = 'ERR')
      WHERE  row_inx = 1;

    l_purge_errbuf  VARCHAR2(10);
    l_purge_retcode NUMBER;
    l_rec_count     NUMBER := 0;
  BEGIN

    FOR i IN cur_retry(p_entity_name, p_target_name, p_bpel_instance_id) LOOP
      update_new(p_event_id => i.event_id);
      l_rec_count := l_rec_count + 1;
    END LOOP;

    x_records_updated := l_rec_count; --SQL%ROWCOUNT;
    x_status          := 'SUCCESS';
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      x_status          := 'ERROR';
      x_records_updated := 0;
      x_status_message  := 'ERROR: ' || SQLERRM;
  END retry;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          Generate XML data for provided event id for monitor form
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  30/07/2015  Diptasurjya Chatterjee        Initial Build
  -- 1.1  27/10/2015  Diptasurjya Chatterjee        CHG0036886 - Fix issue with multiple target names in event table
  -- 1.2  28/12/2017  Diptasurjya Chatterjee        CHG0041829 - Fetch data when query is provided instead of data generation function
  -- 1.3  05/08/2018  Diptasurjya                   CHG0042626 - new customer data generation changes
  -- --------------------------------------------------------------------------------------------
  PROCEDURE generate_data_xml(x_source_data_tbl IN OUT xxssys_source_data_tab,
		      p_entity_name     IN VARCHAR2,
		      p_event_id        IN VARCHAR2) IS
    l_str VARCHAR2(2000);
    --l_xml xmltype;
    l_query       VARCHAR2(2000);
    l_query_final VARCHAR2(2000);

    l_source_data_type xxssys_source_data_tab;

    l_data_proc            VARCHAR2(240);
    l_package_name         VARCHAR2(30);
    l_function_name        VARCHAR2(30);
    l_function_output_type VARCHAR2(30);
    l_parameters           VARCHAR2(3000);
    TYPE char_tab_type IS TABLE OF VARCHAR2(240);
    l_varchar_pos char_tab_type;
    l_col_values  char_tab_type;

    l_cols1 VARCHAR2(240);
    l_cols2 VARCHAR2(240);

    l_count           NUMBER := 0;
    l_field_value     VARCHAR2(4000);
    l_target_name     VARCHAR2(30);
    l_pos_tmp         NUMBER;
    l_var_type_tmp    VARCHAR2(30);
    l_param_str_final VARCHAR2(3000);

    l_event_message     VARCHAR2(4000); -- CHG0042626
    l_query_result_clob CLOB; -- CHG0041829
    l_view_name         VARCHAR2(30); -- CHG0041829
    l_view_tab_start    NUMBER := 0; -- CHG0041829
    l_query_params      char_tab_type := char_tab_type(); -- CHG0041829
  BEGIN
    -- Fetch data function specified in value set DFF Attribute 1 of XXSSYS_EVENT_ENTITY_NAME VS
    SELECT target_name,
           dbms_lob.substr(event_message, 4000, 1) -- CHG0042626 fetch event_message
    INTO   l_target_name,
           l_event_message -- CHG0042626 fetch event_message
    FROM   xxssys_events
    WHERE  event_id = p_event_id;

    SELECT attribute1
    INTO   l_data_proc
    FROM   fnd_flex_values     ffv,
           fnd_flex_value_sets ffvs
    WHERE  ffv.flex_value_set_id = ffvs.flex_value_set_id
    AND    ffvs.flex_value_set_name = 'XXSSYS_EVENT_ENTITY_NAME'
    AND    ffv.flex_value = p_entity_name
    AND    ffv.parent_flex_value_low = l_target_name; -- CHG0036886 - Dipta - Fix to handle multiple Target names

    -- CHG0041829 - Start Dipta for STRATAFORCE
    IF instr(upper(l_data_proc), 'SELECT', 1) = 1 THEN
      --l_target_name = 'STRATAFORCE' then

      FOR rec IN (SELECT LEVEL AS n,
		 regexp_substr(l_data_proc, '[^ ]+', 1, LEVEL) AS val
	      FROM   dual
	      CONNECT BY regexp_substr(l_data_proc, '[^ ]+', 1, LEVEL) IS NOT NULL) LOOP
        IF (l_view_tab_start + 1) = rec.n THEN
          l_view_name := TRIM(upper(rec.val));
        END IF;

        IF upper(rec.val) = 'FROM' THEN
          l_view_tab_start := rec.n;
        ELSIF upper(rec.val) = 'WHERE' THEN
          l_view_tab_start := 0;
        END IF;

        IF instr(rec.val, ':', 1) > 0 THEN
          l_count := l_count + 1;
          l_query_params.extend;
          l_query_params(l_count) := TRIM(translate(substr(rec.val,
				           instr(rec.val,
					     ':',
					     1)),
				    '()''',
				    '   '));
        END IF;
      END LOOP;

      FOR m IN 1 .. l_query_params.count LOOP
        dbms_output.put_line(l_query_params(m));
        l_query := 'select ' || REPLACE(l_query_params(m), ':', '') ||
	       ' from xxssys_events where event_id = ' || p_event_id;
        write_log('After Strataforce handle: 1.1.1: ' || l_query);
        -- Execute dynamic SQL to get parameter value required for fetching data
        EXECUTE IMMEDIATE l_query
          INTO l_cols2;
        l_data_proc := REPLACE(l_data_proc,
		       l_query_params(m),
		       nvl(l_cols2, '''NULL'''));
      END LOOP;

      --dbms_output.put_line(l_data_proc);

      SELECT dbms_xmlgen.getxml(l_data_proc)
      INTO   l_query_result_clob
      FROM   dual;

      FOR view_col_rec IN (SELECT column_id,
		          l_target_name,
		          p_entity_name,
		          p_event_id,
		          column_name,
		          data_type,
		          NULL,
		          SYSDATE
		   FROM   all_tab_columns atc
		   WHERE  atc.table_name = l_view_name
		   ORDER  BY column_id) LOOP
        l_count := l_source_data_type.count + 1;
        l_source_data_type(l_count) := view_col_rec;
        write_log('XML: ' || l_query_result_clob);
        SELECT extractvalue(xmltype(l_query_result_clob),
		    '//' || view_col_rec.column_name)
        INTO   l_field_value
        FROM   dual;

        l_source_data_type(l_count).field_value := l_field_value;
      END LOOP;

      x_source_data_tbl := l_source_data_type;
      RETURN;
    END IF;
    -- CHG0041829 - End Dipta for STRATAFORCE

    -- Parse above fetched string into package, function and parameters
    l_package_name  := upper(substr(l_data_proc,
			0,
			instr(l_data_proc, '.') - 1));
    l_function_name := REPLACE(upper(substr(l_data_proc,
			        0,
			        instr(l_data_proc, '(') - 1)),
		       l_package_name || '.',
		       NULL);
    l_parameters    := REPLACE(REPLACE(upper(l_data_proc),
			   l_package_name || '.' ||
			   l_function_name || '(',
			   NULL),
		       ')',
		       NULL);

    -- Fetch function parameters position and type
    SELECT position || ':' || pls_type
    BULK   COLLECT
    INTO   l_varchar_pos
    FROM   all_arguments
    WHERE  object_id = (SELECT object_id
		FROM   all_objects
		WHERE  object_name = l_package_name
		AND    object_type = 'PACKAGE')
    AND    object_name = l_function_name
    AND    in_out = 'IN'
    ORDER  BY sequence;

    --
    SELECT type_name
    INTO   l_function_output_type
    FROM   all_arguments
    WHERE  object_id = (SELECT object_id
		FROM   all_objects
		WHERE  object_name = l_package_name
		AND    object_type = 'PACKAGE')
    AND    object_name = l_function_name
    AND    in_out = 'OUT'
    ORDER  BY sequence;

    IF l_event_message IS NULL THEN
      -- CHG0042626 if event message is null only then process data as per message generation function
      -- Prepare columns to be fetched from event table
      l_cols1 := REPLACE(REPLACE(l_parameters, ':', NULL), ',', '||'',''||');

      -- Prepare query to be used for fetching data from event table
      l_query := 'select ' || l_cols1 ||
	     ' from xxssys_events where event_id = ' || p_event_id;

      -- Execute dynamic SQL to get data required for fetching data
      EXECUTE IMMEDIATE l_query
        INTO l_cols2;

      -- Replace null data fetched with NULL string
      l_cols2 := REPLACE(l_cols2, ',,', ',NULL,');

      -- Split the data string fetched above using ',' as delimiter
      WITH t AS
       (SELECT l_cols2 input
        FROM   dual)
      SELECT token
      BULK   COLLECT
      INTO   l_col_values
      FROM   t model dimension BY(1 rn) measures(input input, CAST(NULL AS VARCHAR2(10)) token) rules(token [ FOR rn FROM 1 TO nvl(length(regexp_replace(input [ 1 ], '[^,]')), 0) + 1 increment 1 ] = regexp_substr(input [ 1 ], '[^,]+', 1, cv(rn)))
      ORDER  BY rn;

      -- Use the parameter location and type and parameter value to prepare final query string
      -- This step is required to wrap VARCHAR2 parameters with quotes
      IF l_varchar_pos IS NOT NULL THEN
        FOR i IN 1 .. l_varchar_pos.count LOOP
          l_pos_tmp      := substr(l_varchar_pos(i),
		           0,
		           instr(l_varchar_pos(i), ':') - 1);
          l_var_type_tmp := REPLACE(l_varchar_pos(i),
			l_pos_tmp || ':',
			NULL);

          IF l_var_type_tmp = 'NUMBER' THEN
	l_param_str_final := l_param_str_final ||
		         nvl(l_col_values(i), 'null') || ',';
          ELSIF l_var_type_tmp = 'VARCHAR2' THEN
	l_param_str_final := l_param_str_final || '''' ||
		         nvl(l_col_values(i), 'null') || ''',';
          END IF;
        END LOOP;
      END IF;

      -- Remove last comma (,) from the query string
      l_param_str_final := rtrim(l_param_str_final, ',');

      -- prepare final data fetch query string
      l_query_final := 'select xmltype
       (' || l_package_name || '.' || l_function_name || '(' ||
	           l_param_str_final || '))
       from dual';

      -- Execute dynamic sql to generate XML data related to input parameter event
      EXECUTE IMMEDIATE l_query_final
        INTO l_str;
    ELSE
      -- CHG0042626 - event message is not null
      l_str := l_event_message;
      write_log('Here: 0.2 ' || l_str);
    END IF;

    write_log('Here: 1');

    FOR rec IN (SELECT attr_no,
	           l_target_name,
	           p_entity_name,
	           p_event_id,
	           attr_name,
	           attr_type_name,
	           NULL           field_value,
	           SYSDATE        last_update_date -- CHG0036886 - Dipta added on ECOM 14-MAR-2016
	    FROM   all_type_attrs
	    WHERE  type_name = l_function_output_type
	    ORDER  BY attr_no) LOOP
      l_count := l_source_data_type.count + 1;
      l_source_data_type(l_count) := rec;
      SELECT extractvalue(xmltype(l_str), '//' || rec.attr_name)
      INTO   l_field_value
      FROM   dual;
      l_source_data_type(l_count).field_value := l_field_value;
    END LOOP;
    write_log('Here: 2');
    -- Return values
    x_source_data_tbl := l_source_data_type;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          Fetch error data for provided event id for monitor form
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  30/10/2015  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE fetch_event_error(x_event_error_tbl IN OUT xxssys_source_data_tab,
		      p_event_id        IN VARCHAR2) IS
    l_event_error_data xxssys_source_data_tab;
    l_count            NUMBER := 0;
  BEGIN
    FOR rec1 IN (SELECT rownum,
		xe.target_name,
		xe.entity_name,
		p_event_id,
		'' field_name,
		'' field_type,
		xee.status_message,
		xee.last_update_date -- CHG0036886 - Dipta added on ECOM 14-MAR-2016
	     FROM   xxssys_event_errors xee,
		xxssys_events       xe
	     WHERE  xe.event_id = p_event_id
	     AND    xe.event_id = xee.event_id
	     ORDER  BY xee.event_error_id) LOOP
      l_count := l_event_error_data.count + 1;
      l_event_error_data(l_count) := rec1;
      l_event_error_data(l_count).seq_no := l_count;
    END LOOP;

    FOR rec2 IN (SELECT rownum,
		target_name,
		entity_name,
		p_event_id,
		'' field_name,
		'' field_type,
		err_message,
		last_update_date -- CHG0036886 - Dipta added on ECOM 14-MAR-2016
	     FROM   xxssys_events
	     WHERE  event_id = p_event_id
	     AND    err_message IS NOT NULL) LOOP
      l_count := l_event_error_data.count + 1;
      l_event_error_data(l_count) := rec2;
      l_event_error_data(l_count).seq_no := l_count;
    END LOOP;

    x_event_error_tbl := l_event_error_data;
  END fetch_event_error;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Function to partition event table based on target name set in profile XXSSYS_EVENT_TARGET
  --          If profile value is null, no records will be displayed
  --          If profile value is ALL then all target data will be shown
  --          Otherwise data will be displayed based on profile value
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name            Description
  -- 1.0  02/11/2015  Diptasurjya     Initial Creation for CHG0036886.
  --                  Chatterjee
  -- 1.1 2-Aug-2018   Lingaraj        CHG0043574 - Event monitor form - adding security functionality
  -- ---------------------------------------------------------------------------------------------
  FUNCTION partion_table_by_target(obj_schema VARCHAR2,
		           obj_name   VARCHAR2) RETURN VARCHAR2 IS
    l_target VARCHAR2(20) := NULL;

    l_sql VARCHAR2(2000);
  BEGIN
    g_log_program_unit := 'partion_table_by_target';
    --fnd_profile.get('XXSSYS_EVENT_TARGET', l_target);

    /*SELECT 'target_name=' ||
           decode(l_target, 'ALL', 'target_name', '''' || l_target || '''')
    INTO   l_sql
    FROM   dual;*/
    l_sql := Q'[
	(nvl(fnd_profile.value('XXSSYS_EVENT_TARGET'),'N')) = 'Y'
	 OR
	(
	  (TARGET_NAME,ENTITY_NAME) IN
	    (
	    select  ffvv_s.ATTRIBUTE2 TARGET_NAME, NVL(ffvv_s.ATTRIBUTE3,ENTITY_NAME) ENTITY_NAME
	          from
	          FND_FLEX_VALUE_SETS ffvs_s,
	          FND_FLEX_VALUES_VL ffvv_s
	          where ffvs_s.FLEX_VALUE_SET_ID = ffvv_s.FLEX_VALUE_SET_ID
	          and ffvs_s.FLEX_VALUE_SET_NAME = 'XXSSYS_EVENT_MONITOR_ACCESS'
	          and ffvv_s.ENABLED_FLAG = 'Y'
	          and ffvv_s.ATTRIBUTE1 = to_char(FND_GLOBAL.USER_ID)
	     )
	 )]';
    write_log(l_sql);

    RETURN l_sql;
  END;

  ------------------------------------------------
  -- update_status_bulk
  ---------------------------------------------------
  -- Ver  Date        Name            Description
  -- 1.1  9.11.207     yuval tal      CHG0041829 add update_status_bulk

  ---------------------------------------------------

  PROCEDURE update_status_bulk(p_err_code    OUT VARCHAR2,
		       p_err_message OUT VARCHAR2,
		       p_event_tab   xxobjt.xxssys_events_tab) IS
  BEGIN

    p_err_code := 'S';

    FORALL indx IN 1 .. p_event_tab.count
      UPDATE xxssys_events
      SET    last_update_date = SYSDATE,
	 status           = nvl(p_event_tab(indx).status, status),
	 request_messgae  = nvl(p_event_tab(indx).request_messgae,
			request_messgae),
	 err_message      = p_event_tab(indx).err_message,
	 bpel_instance_id = nvl(p_event_tab(indx).bpel_instance_id,
			bpel_instance_id),

	 api_message = nvl(p_event_tab(indx).api_message, api_message),
	 external_id = nvl(p_event_tab(indx).external_id, external_id) ----CHG041829
      WHERE  event_id = p_event_tab(indx).event_id; --CHG041829
    p_err_code := 'S';
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code    := 'E';
      p_err_message := SQLERRM;

  END;

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
		 x_event_id        OUT xxssys_events.event_id%TYPE) IS
    l_xxssys_event_rec xxssys_events%ROWTYPE;
  BEGIN
    l_xxssys_event_rec.target_name      := p_target_name;
    l_xxssys_event_rec.entity_name      := p_entity_name;
    l_xxssys_event_rec.entity_id        := p_entity_id;
    l_xxssys_event_rec.active_flag      := p_active_flag;
    l_xxssys_event_rec.status           := p_status;
    l_xxssys_event_rec.event_name       := p_event_name;
    l_xxssys_event_rec.attribute1       := p_attribute1;
    l_xxssys_event_rec.attribute2       := p_attribute2;
    l_xxssys_event_rec.attribute3       := p_attribute3;
    l_xxssys_event_rec.attribute4       := p_attribute4;
    l_xxssys_event_rec.attribute5       := p_attribute5;
    l_xxssys_event_rec.attribute6       := p_attribute6;
    l_xxssys_event_rec.attribute7       := p_attribute7;
    l_xxssys_event_rec.attribute8       := p_attribute8;
    l_xxssys_event_rec.attribute9       := p_attribute9;
    l_xxssys_event_rec.attribute10      := p_attribute10;
    l_xxssys_event_rec.last_update_date := p_last_update_date;
    l_xxssys_event_rec.last_updated_by  := p_last_updated_by;
    l_xxssys_event_rec.creation_date    := p_creation_date;
    l_xxssys_event_rec.created_by       := p_created_by;
    l_xxssys_event_rec.entity_code      := p_entity_code;
    l_xxssys_event_rec.external_id      := p_external_id;

    --P_LAST_UPDATE_LOGIN  XXSSYS_EVENTS.LAST_UPDATE_LOGIN%TYPE,
    --P_BPEL_INSTANCE_ID   XXSSYS_EVENTS.BPEL_INSTANCE_ID%TYPE,
    --P_API_MESSAGE        XXSSYS_EVENTS.API_MESSAGE%TYPE,
    --P_REQUEST_MESSGAE    XXSSYS_EVENTS.REQUEST_MESSGAE%TYPE,
    --P_ERR_MESSAGE        XXSSYS_EVENTS.ERR_MESSAGE%TYPE,

    insert_event(p_xxssys_event_rec => l_xxssys_event_rec,
	     p_db_trigger_mode  => p_db_trigger_mode,
	     x_event_id         => x_event_id);

  END insert_event;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          This Procedure is used to insert NOTIF_EMAIL type events in the event table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                       Description
  -- 1.0  07/11/2018  Diptasurjya Chatterjee     Initial Build
  -- 1.1  25/01/2019  Diptasurjya                INC0145264 - fetch mail dist list without OU if OU based list is NULL
  -- --------------------------------------------------------------------------------------------
  PROCEDURE insert_mail_event(p_db_trigger_mode IN VARCHAR2,
		      p_target_name     IN VARCHAR2,
		      p_program_name_to IN VARCHAR2,
		      p_program_name_cc IN VARCHAR2,
		      p_operating_unit  IN NUMBER,
		      p_entity          IN VARCHAR2,
		      p_entity_id       IN NUMBER DEFAULT NULL,
		      p_entity_code     IN VARCHAR2 DEFAULT NULL,
		      p_subject         IN VARCHAR2,
		      p_body            IN VARCHAR2,
		      p_event_name      IN VARCHAR2,
		      p_user_id         IN NUMBER) IS

    l_notification_email VARCHAR2(20) := 'NOTIF_EMAIL';
    l_xxssys_event_rec   xxssys_events%ROWTYPE;
    l_mail_to_list       VARCHAR2(240);
    l_mail_cc_list       VARCHAR2(240);
    l_message_data       CLOB;
  BEGIN

    l_mail_to_list := nvl(xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => p_operating_unit,
					          p_program_short_name => p_program_name_to),
		  xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					          p_program_short_name => p_program_name_to)); -- INC0145264 added nvl and no OU fetch

    l_mail_cc_list := nvl(xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => p_operating_unit,
					          p_program_short_name => p_program_name_cc),
		  xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					          p_program_short_name => p_program_name_cc)); -- INC0145264 added nvl and no OU fetch

    l_message_data := '<NOTIFICATION_MAIL_DATA>' || '<SUBJECT>' ||
	          p_subject || '</SUBJECT>' || '<MAIL_TO>' ||
	          l_mail_to_list || '</MAIL_TO>' || '<MAIL_CC>' ||
	          l_mail_cc_list || '</MAIL_CC>' || '<BODY>' || p_body ||
	          '</BODY>' || '</NOTIFICATION_MAIL_DATA>';

    l_xxssys_event_rec.target_name     := p_target_name;
    l_xxssys_event_rec.entity_name     := l_notification_email;
    l_xxssys_event_rec.entity_id       := p_entity_id;
    l_xxssys_event_rec.entity_code     := p_entity_code;
    l_xxssys_event_rec.attribute1      := p_entity;
    l_xxssys_event_rec.event_name      := p_event_name;
    l_xxssys_event_rec.last_updated_by := p_user_id;
    l_xxssys_event_rec.created_by      := p_user_id;
    l_xxssys_event_rec.event_message   := l_message_data;

    xxssys_event_pkg.insert_event(l_xxssys_event_rec, p_db_trigger_mode);
  END insert_mail_event;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042626
  --          This Procedure is used to send Emails for all EMAIL_NOTIF events in NEW status
  --          based on input target name
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  13/07/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE send_mail_from_events(errbuf        OUT VARCHAR2,
		          retcode       OUT NUMBER,
		          p_target_name IN VARCHAR2) IS
    l_mail_to_list VARCHAR2(240);
    l_mail_cc_list VARCHAR2(240);
    l_err_code     VARCHAR2(4000);
    l_err_msg      VARCHAR2(4000);

    l_body VARCHAR2(4000);

    CURSOR cur_mail_events IS
      SELECT xmltype(xe.event_message).extract('//SUBJECT/text()')
	 .getstringval() subject,
	 xmltype(xe.event_message).extract('//MAIL_TO/text()')
	 .getstringval() to_mail,
	 xmltype(xe.event_message).extract('//MAIL_CC/text()')
	 .getstringval() cc_mail,
	 listagg('<TR><TD>' || xe.attribute1 ||
	         '</TD><TD style="white-space:pre-wrap; word-wrap:break-word">' || xmltype(xe.event_message).extract('//BODY/text()')
	         .getstringval() || '</TD></TR>',
	         '') within GROUP(ORDER BY event_id) bodytxt
      FROM   xxssys_events xe
      WHERE  entity_name = 'NOTIF_EMAIL'
      AND    status = 'IN_PROCESS'
      AND    xe.target_name = p_target_name
      GROUP  BY xmltype(xe.event_message).extract('//SUBJECT/text()')
	    .getstringval(),
	    xmltype(xe.event_message).extract('//MAIL_TO/text()')
	    .getstringval(),
	    xmltype(xe.event_message).extract('//MAIL_CC/text()')
	    .getstringval()
      ORDER  BY 1 DESC;

    l_api_phase VARCHAR2(240) := 'event processor';
  BEGIN

    UPDATE xxssys_events xe
    SET    xe.status = 'IN_PROCESS'
    WHERE  entity_name = 'NOTIF_EMAIL'
    AND    target_name = p_target_name
    AND    status = 'NEW';

    COMMIT;

    FOR rec IN cur_mail_events LOOP
      l_body := xxobjt_wf_mail_support.get_header_html('INTERNAL') ||
	    '<TABLE style="color:darkblue" BORDER=1 cellPadding=2><TR><TH>Entity</TH><TH>Message</TH></TR>' ||
	    rec.bodytxt || '</TABLE>' ||
	    xxobjt_wf_mail_support.get_footer_html;

      xxobjt_wf_mail.send_mail_html(p_to_role     => rec.to_mail,
			p_cc_mail     => rec.cc_mail,
			p_subject     => rec.subject,
			p_body_html   => l_body,
			p_err_code    => l_err_code,
			p_err_message => l_err_msg);

      IF l_err_code <> 0 THEN
        UPDATE xxssys_events xe
        SET    xe.status      = 'ERR',
	   xe.err_message = l_err_msg
        WHERE  entity_name = 'NOTIF_EMAIL'
        AND    status = 'IN_PROCESS'
        AND    target_name = p_target_name
        AND     xmltype(xe.event_message).extract('//SUBJECT/text()')
	  .getstringval() = rec.subject
        AND     xmltype(xe.event_message).extract('//MAIL_TO/text()')
	  .getstringval() = rec.to_mail
        AND     xmltype(xe.event_message).extract('//MAIL_CC/text()')
	  .getstringval() = rec.cc_mail;
      ELSE
        UPDATE xxssys_events xe
        SET    xe.status = 'SUCCESS'
        WHERE  entity_name = 'NOTIF_EMAIL'
        AND    status = 'IN_PROCESS'
        AND    target_name = p_target_name
        AND     xmltype(xe.event_message).extract('//SUBJECT/text()')
	  .getstringval() = rec.subject
        AND     xmltype(xe.event_message).extract('//MAIL_TO/text()')
	  .getstringval() = rec.to_mail
        AND     xmltype(xe.event_message).extract('//MAIL_CC/text()')
	  .getstringval() = rec.cc_mail;
      END IF;

      COMMIT;
    END LOOP;

    retcode := 0;
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'UNEXPECTED ERROR: ' || SQLERRM;

      UPDATE xxssys_events xe
      SET    xe.status      = 'ERR',
	 xe.err_message = errbuf
      WHERE  entity_name = 'NOTIF_EMAIL'
      AND    status = 'IN_PROCESS'
      AND    target_name = p_target_name;
      COMMIT;

  END send_mail_from_events;
END xxssys_event_pkg;
/
