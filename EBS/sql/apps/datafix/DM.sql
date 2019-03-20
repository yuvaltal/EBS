DECLARE

CURSOR c_exists(p_target_name VARCHAR2,
                p_entity_name VARCHAR2,p_entity_code VARCHAR2
                ,p_entity_id NUMBER,p_attribute1 VARCHAR2, p_attribute2 VARCHAR2,p_attribute3  VARCHAR2  ) IS
      SELECT event_id
      FROM   xxssys_events
      WHERE   1= 1 --status = 'NEW'
      AND  concatenated_key_cols = (p_target_name || '-' ||
                                    p_entity_name || '-' ||
                                    p_entity_code || '-' ||
                                    p_entity_id   || '-' ||
                                    p_attribute1  || '-' ||
                                    p_attribute2  || '-' ||
                                    p_attribute3
                                    );


 l_no_of_rec        number := 0;
  l_event_id       NUMBER;
BEGIN
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   09-Oct-2018 Lingaraj          CHG0043859- Install base interface changes from Oracle to salesforce
  -- Migrate Data from xxobjt_oa2sf_interface Table to XXSSYS_EVENTS Table
  -----------------------------------------------------------------------
FOR rec in
		(
		 Select 'STRATAFORCE' TARGET_NAME,
				 'ASSET'       ENTITY_NAME ,
				  Source_id     Entity_Id,
				  status  ,
                 'INSTALL_BASE_UPGRADE'  EVENT_NAME,
				 'INSTALL_BASE_UPGRADE'  ATTRIBUTE1,
				 (Select segment1 from mtl_system_items_b
				   where organization_id = 91
				   and inventory_item_id = to_number(Source_ID2)
				 ) ATTRIBUTE2,
                 'XXOBJT_OA2SF_INTERFACE|DATA_MIGRATION' ATTRIBUTE9  ,
				 ('ORACLE_EVENT_ID|'||ORACLE_EVENT_ID) ATTRIBUTE10
		  from xxobjt_oa2sf_interface
		  where source_name =  'MACHINE_UPGRADE'
		  and Source_ID2 is not null -- Exclude records where Source_ID2 is null
          --and rownum < 10
		)
LOOP
     IF  c_exists%ISOPEN THEN
         CLOSE c_exists;
     END IF;

     OPEN c_exists(rec.target_name ,
                   rec.entity_name,
                   NULL ,
                   rec.Entity_Id ,
                   rec.ATTRIBUTE1,
                   rec.ATTRIBUTE2,
                   NULL);
    FETCH c_exists
      INTO l_event_id;
    IF c_exists%FOUND THEN
       CONTINUE;
    ELSE
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
         rec.target_name,
         rec.entity_name,
         rec.entity_id,
         NULL,
         rec.status,
         rec.event_name,
         NULL,
         NULL,
         rec.attribute1,
         rec.attribute2,
         NULL, --attribute3
         null, --attribute4
         null, --attribute5
         NULL, --attribute6
         NULL, --attribute7
         NULL, --attribute8
         rec.attribute9, --attribute9
         rec.attribute10, --attribute10
         NULL,
         SYSDATE,
         NULL,
         SYSDATE,
         NULL,
         NULL,
         NULL,  -- CHG0042626
         rec.target_name || '-' ||
         rec.entity_name || '-' ||
         '' || '-' ||
         rec.entity_id || '-' || rec.attribute1 || '-' ||
         rec.attribute2 || '-' || ''
         );

       l_no_of_rec := l_no_of_rec + 1;
    END IF;



END LOOP;
commit;

  CLOSE c_exists;

dbms_output.put_line('No Of records Inserted :' || l_no_of_rec);
Exception
When others Then
  dbms_output.put_line(sqlerrm);
    CLOSE c_exists;
  rollback;
END;
