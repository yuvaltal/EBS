CREATE OR REPLACE TRIGGER  XXINV_SUBINVQNT_SOA_V_TRG
INSTEAD OF UPDATE ON XXINV_SUBINVQNT_SOA_V
---------------------------------------------------------------------------------
--  customization code: CHG0042877 - CAR stock onhand quantity interface - Oracle to salesforce
--  name:               XXINV_SUBINVQNT_SOA_V_TRG
--  create by:          Lingaraj
--  creation date:      31.May.18
--  Description:        Used By SOA Composite to Sync Subinventory Onhand Quantity
--
---------------------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   29.May.18     Lingaraj        CHG0042877 - initial build
---------------------------------------------------------------------------------
FOR EACH ROW
BEGIN
  IF :new.status = 'IN_PROCESS' AND nvl(:old.status, 'NEW') = 'NEW' THEN
    UPDATE XXSSYS_EVENTS t
    SET    t.status = 'IN_PROCESS'
    WHERE  t.event_id =
           nvl(:old.event_id, :new.event_id);
  END IF;
End XXINV_SUBINVQNT_SOA_V_TRG;
/