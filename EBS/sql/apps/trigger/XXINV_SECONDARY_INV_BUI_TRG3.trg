CREATE OR REPLACE TRIGGER XXINV_SECONDARY_INV_BUI_TRG3
--------------------------------------------------------------------------------------------------
--  name:              XXINV_SECONDARY_INV_BUI_TRG3
--  create by:         Lingaraj Sarangi
--  Revision:          1.0
--  creation date:     29-May-2018
--------------------------------------------------------------------------------------------------
--  purpose :          CHG0042878 - CAR stock Subinventory interface - Oracle to Salesforce
--                                   trigger on Table  MTL_SECONDARY_INVENTORIES
--
--  Modification History
--------------------------------------------------------------------------------------------------
--  ver   date          Name                       Desc
--  1.0   29-May-2018   Lingaraj Sarangi           CHG0042878 - CAR stock Subinventory interface - Oracle to Salesforce
--------------------------------------------------------------------------------------------------
BEFORE INSERT OR UPDATE  ON "INV"."MTL_SECONDARY_INVENTORIES"
FOR EACH ROW
when(
     UPPER(NVL(NEW.SECONDARY_INVENTORY_NAME,OLD.SECONDARY_INVENTORY_NAME)) like '%CAR'
    )
DECLARE
  l_trigger_name    VARCHAR2(50)   := 'XXINV_SECONDARY_INV_BUI_TRG3';
  l_error_message   VARCHAR2(500)  := '';
  l_trigger_action  VARCHAR2(10)   := '';
  l_subname			 inv.mtl_secondary_inventories.secondary_inventory_name%type;
  l_invorgcode       VARCHAR2(15);
  l_xxssys_event_rec xxssys_events%ROWTYPE;
BEGIN
  IF INSERTING THEN
     l_trigger_action := 'INSERT';
  ELSIF UPDATING THEN
     l_trigger_action := 'UPDATE';
  END IF;

  If  (:NEW.SECONDARY_INVENTORY_NAME != :OLD.SECONDARY_INVENTORY_NAME)
     OR (nvl(:NEW.DESCRIPTION,'~')  != nvl(:OLD.DESCRIPTION,'~'))
	 OR (nvl(:NEW.DISABLE_DATE,trunc(sysdate + 1)) != nvl(:OLD.DISABLE_DATE,trunc(sysdate + 1)))
  THEN
    -- Only if Subinventory Name  or Description or Disable Date Changed , generate Event
	  l_subname							 := nvl(:NEW.SECONDARY_INVENTORY_NAME , :OLD.SECONDARY_INVENTORY_NAME);
	  l_invorgcode	                     := xxinv_utils_pkg.get_org_code(nvl(:NEW.organization_id , :OLD.organization_id));
	  l_xxssys_event_rec                 := NULL;
      l_xxssys_event_rec.target_name     := 'STRATAFORCE';
      l_xxssys_event_rec.entity_name     := 'SUBINV';
      l_xxssys_event_rec.entity_code     := l_invorgcode||'|'||l_subname;
      l_xxssys_event_rec.attribute1      := l_invorgcode;
	  l_xxssys_event_rec.last_updated_by := nvl(:NEW.last_updated_by , :OLD.last_updated_by);
	  l_xxssys_event_rec.created_by      := nvl(:NEW.created_by , :OLD.created_by);
	  l_xxssys_event_rec.event_name      :=  l_trigger_name||'('||l_trigger_action||')';

	  xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
  End If;
Exception
WHEN OTHERS THEN
  l_error_message := substrb(sqlerrm,1,500);
  RAISE_APPLICATION_ERROR(-20999,l_error_message);
END XXINV_SECONDARY_INV_BUI_TRG3;
/
