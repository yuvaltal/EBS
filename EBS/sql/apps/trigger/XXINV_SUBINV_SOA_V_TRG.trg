CREATE OR REPLACE TRIGGER XXINV_SUBINV_SOA_V_TRG
  INSTEAD OF UPDATE ON XXINV_SUBINV_SOA_V
  FOR EACH ROW
--------------------------------------------------------------------
--  customization code: CHG0042878 - CAR stock Subinventory interface - Oracle to Salesforce
--  name:               XXINV_SUBINV_SOA_V_TRG
--  create by:          Lingaraj
--  creation date:      29.May.18
--  Description:        get subinventory data for oracle sf sync
--
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   29.May.18     Lingaraj        CHG0042878 - initial build
--------------------------------------------------------------------
BEGIN
  IF :new.status = 'IN_PROCESS' AND nvl(:old.status, 'NEW') = 'NEW' THEN
    UPDATE XXSSYS_EVENTS t
    SET    t.status = 'IN_PROCESS'
    WHERE  t.event_id =
           nvl(:old.event_id, :new.event_id);
  END IF;
END;
/
