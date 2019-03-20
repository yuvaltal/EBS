CREATE OR REPLACE TRIGGER XXOM_PRICELINES_SOA_V_TRG
  INSTEAD OF UPDATE ON XXOM_PRICELINES_SOA_V

  FOR EACH ROW
--------------------------------------------------------------------
--  name       :     XXOM_PRICELINES_SOA_V_TRG
--  Description:     update xxssys_events view support for soa use
--                   used by soa (Strataforce Project)
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   9.11.17       yuval tal       CHG0041808 - Pricelist Lines Interface - initial build
--------------------------------------------------------------------
BEGIN
  IF :new.status = 'IN_PROCESS' AND nvl(:old.status, 'NEW') = 'NEW' THEN

    UPDATE XXSSYS_EVENTS t
    SET    t.status = 'IN_PROCESS'
    WHERE  t.event_id =
           nvl(:old.event_id, :new.event_id);
  END IF;

End XXOM_PRICELINES_SOA_V_TRG;
/
