CREATE OR REPLACE TRIGGER XXINV_ITEM_ONHAND_AIUR_TRG2
--------------------------------------------------------------------------------------------------
--  name:              XXINV_ITEM_ONHAND_AIUR_TRG2
--  create by:         LINGARAJ
--  Revision:          1.0
--  creation date:     31.May.2018
--------------------------------------------------------------------------------------------------
--  purpose :          CHG0042877 - CAR stock onhand quantity interface - Oracle to salesforce
--                       : Insert/Update/Delete trigger on MTL_ONHAND_QUANTITIES_DETAIL to
--                               for real time integration of item onhand with interfacing applications
--SFDC Interface        : STRATAFORCE
--  Modification History
--------------------------------------------------------------------------------------------------
--  ver   date          Name                 Desc
--  1.0   31.May.2018   Lingaraj             CHG0042877 - CAR stock onhand quantity interface - Oracle to salesforce
--------------------------------------------------------------------------------------------------

AFTER INSERT OR UPDATE OR DELETE ON "INV"."MTL_ONHAND_QUANTITIES_DETAIL"
FOR EACH ROW

when(upper(nvl(new.subinventory_code,old.subinventory_code)) like '%CAR')
DECLARE
  l_trigger_name    VARCHAR2(30) := 'XXINV_ITEM_ONHAND_AIUR_TRG2';
  old_items_rec     xxinv_pronto_event_pkg.item_onhand_rec_type;
  new_items_rec     xxinv_pronto_event_pkg.item_onhand_rec_type;
  l_error_message   VARCHAR2(2000);
  l_trigger_action  VARCHAR2(10)   := '';
  l_xxssys_event_rec xxssys_events%ROWTYPE;
BEGIN
  l_error_message := '';

  IF INSERTING THEN
     l_trigger_action := 'INSERT';
  ELSIF UPDATING THEN
     l_trigger_action := 'UPDATE';
  ELSIF DELETING THEN
     l_trigger_action := 'DELETE';
  END IF;


    -- Generate Event
    l_xxssys_event_rec                 := NULL;
    l_xxssys_event_rec.target_name     := 'STRATAFORCE';
    l_xxssys_event_rec.entity_name     := 'SUBINVQNT';
    l_xxssys_event_rec.entity_id       := nvl(:new.inventory_item_id , :old.inventory_item_id);
    l_xxssys_event_rec.attribute1      := nvl(:new.subinventory_code , :old.subinventory_code);
    l_xxssys_event_rec.attribute2      := xxinv_utils_pkg.get_org_code(nvl(:new.organization_id , :old.organization_id));
    l_xxssys_event_rec.attribute3      := nvl(:new.organization_id , :old.organization_id);
    l_xxssys_event_rec.attribute4      := nvl(:new.transaction_uom_code , :old.transaction_uom_code);
    l_xxssys_event_rec.last_updated_by := nvl(:NEW.last_updated_by , :OLD.last_updated_by);
    l_xxssys_event_rec.created_by      := nvl(:NEW.created_by , :OLD.created_by);
    l_xxssys_event_rec.event_name      :=  l_trigger_name||'('||l_trigger_action||')';
    l_xxssys_event_rec.entity_code     := xxinv_utils_pkg.get_item_segment(l_xxssys_event_rec.entity_id ,l_xxssys_event_rec.attribute3);

    xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');

Exception
WHEN OTHERS THEN
  l_error_message := substrb(sqlerrm,1,500);
  RAISE_APPLICATION_ERROR(-20999,l_error_message);
END XXINV_ITEM_ONHAND_AIUR_TRG2;
/
