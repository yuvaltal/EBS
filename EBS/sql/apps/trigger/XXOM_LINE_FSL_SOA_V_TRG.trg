CREATE OR REPLACE TRIGGER XXOM_LINE_FSL_SOA_V_TRG
  INSTEAD OF UPDATE ON    XXOM_LINE_FSL_SOA_V

  FOR EACH ROW
--------------------------------------------------------------------
--  name:     XXOM_LINE_FSL_SOA_V_TRG
--  Description:     ORDER HEADER interface list for strataforce system
--                  used by soa
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   26.04.18      Lingaraj       CHG0042734 -Create Order interface - Enable Strataforce to create orders in Oracle
--------------------------------------------------------------------
BEGIN
  IF :new.status = 'IN_PROCESS' AND nvl(:old.status, 'NEW') = 'NEW' THEN

    UPDATE XXSSYS_EVENTS t
    SET    t.status = 'IN_PROCESS'
    WHERE  t.event_id =
           nvl(:old.event_id, :new.event_id);
  END IF;

end XXOM_LINE_FSL_SOA_V_TRG;
/
