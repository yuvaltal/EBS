CREATE OR REPLACE TRIGGER XXOM_ORDER_HEADER_SOA_V_TRG
  INSTEAD OF UPDATE ON XXOM_ORDER_HEADER_SOA_V

  FOR EACH ROW
--------------------------------------------------------------------
--  name:     XXOM_ORDER_HEADER_SOA_V_TRG
--  Description:     ORDER HEADER interface list for strataforce system
--                  used by soa
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   9.11.17       yuval tal       CHG0042041 - strataforce  project order header  Interface initial build
--------------------------------------------------------------------
BEGIN
  IF :new.status = 'IN_PROCESS' AND nvl(:old.status, 'NEW') = 'NEW' THEN

    UPDATE XXSSYS_EVENTS t
    SET    t.status = 'IN_PROCESS'
    WHERE  t.event_id =
           nvl(:old.event_id, :new.event_id);
  END IF;

end XXOM_ORDER_HEADER_SOA_V_TRG;
/
