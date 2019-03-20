CREATE OR REPLACE TRIGGER xxokc_k_items_aiu_trg
--------------------------------------------------------------------------------------------------
  --  name:              XXOKC_K_ITEMS_AIU_TRG
  --  create by:         Lingaraj Sarangi
  --  Revision:          1.0
  --  creation date:     10-May-2018
  --------------------------------------------------------------------------------------------------
  --  purpose :          CHG0042873 - Service Contract interface - Oracle 2 SFDC
  --                                   trigger on OKC_K_ITEMS
  --
  --  Modification History
  --------------------------------------------------------------------------------------------------
  --  ver   date          Name                       Desc
  --  1.0   10-May-2018   Lingaraj Sarangi           CHG0042873 - Service Contract interface - Oracle 2 SFDC
  --------------------------------------------------------------------------------------------------
  AFTER INSERT OR UPDATE ON "OKC"."OKC_K_ITEMS"
  FOR EACH ROW

  WHEN (new.creation_date > to_date ('01012019', 'ddmmyyyy'))
DECLARE
  l_trigger_name     VARCHAR2(50) := 'XXOKC_K_ITEMS_AIU_TRG';
  l_error_message    VARCHAR2(500) := '';
  l_old_okc_item_rec okc.okc_k_items%ROWTYPE;
  l_new_okc_item_rec okc.okc_k_items%ROWTYPE;
  l_trigger_action   VARCHAR2(10) := '';
BEGIN

  IF inserting THEN
    l_trigger_action := 'INSERT';
  ELSIF updating THEN
    l_trigger_action := 'UPDATE';
  END IF;

  -----------------------------------------------------------
  -- Old Column Values Before Update
  -----------------------------------------------------------
  IF updating THEN
    l_old_okc_item_rec.id                     := :old.id;
    l_old_okc_item_rec.cle_id                 := :old.cle_id;
    l_old_okc_item_rec.chr_id                 := :old.chr_id;
    l_old_okc_item_rec.cle_id_for             := :old.cle_id_for;
    l_old_okc_item_rec.dnz_chr_id             := :old.dnz_chr_id;
    l_old_okc_item_rec.object1_id1            := :old.object1_id1;
    l_old_okc_item_rec.object1_id2            := :old.object1_id2;
    l_old_okc_item_rec.jtot_object1_code      := :old.jtot_object1_code;
    l_old_okc_item_rec.uom_code               := :old.uom_code;
    l_old_okc_item_rec.exception_yn           := :old.exception_yn;
    l_old_okc_item_rec.number_of_items        := :old.number_of_items;
    l_old_okc_item_rec.priced_item_yn         := :old.priced_item_yn;
    l_old_okc_item_rec.object_version_number  := :old.object_version_number;
    l_old_okc_item_rec.created_by             := :old.created_by;
    l_old_okc_item_rec.creation_date          := :old.creation_date;
    l_old_okc_item_rec.last_updated_by        := :old.last_updated_by;
    l_old_okc_item_rec.last_update_date       := :old.last_update_date;
    l_old_okc_item_rec.last_update_login      := :old.last_update_login;
    l_old_okc_item_rec.security_group_id      := :old.security_group_id;
    l_old_okc_item_rec.upg_orig_system_ref    := :old.upg_orig_system_ref;
    l_old_okc_item_rec.upg_orig_system_ref_id := :old.upg_orig_system_ref_id;
    l_old_okc_item_rec.program_application_id := :old.program_application_id;
    l_old_okc_item_rec.program_id             := :old.program_id;
    l_old_okc_item_rec.program_update_date    := :old.program_update_date;
    l_old_okc_item_rec.request_id             := :old.request_id;
  END IF;
  -----------------------------------------------------------
  -- New Column Values After Update
  -----------------------------------------------------------
  IF inserting OR updating THEN
    l_new_okc_item_rec.id                     := :new.id;
    l_new_okc_item_rec.cle_id                 := :new.cle_id;
    l_new_okc_item_rec.chr_id                 := :new.chr_id;
    l_new_okc_item_rec.cle_id_for             := :new.cle_id_for;
    l_new_okc_item_rec.dnz_chr_id             := :new.dnz_chr_id;
    l_new_okc_item_rec.object1_id1            := :new.object1_id1;
    l_new_okc_item_rec.object1_id2            := :new.object1_id2;
    l_new_okc_item_rec.jtot_object1_code      := :new.jtot_object1_code;
    l_new_okc_item_rec.uom_code               := :new.uom_code;
    l_new_okc_item_rec.exception_yn           := :new.exception_yn;
    l_new_okc_item_rec.number_of_items        := :new.number_of_items;
    l_new_okc_item_rec.priced_item_yn         := :new.priced_item_yn;
    l_new_okc_item_rec.object_version_number  := :new.object_version_number;
    l_new_okc_item_rec.created_by             := :new.created_by;
    l_new_okc_item_rec.creation_date          := :new.creation_date;
    l_new_okc_item_rec.last_updated_by        := :new.last_updated_by;
    l_new_okc_item_rec.last_update_date       := :new.last_update_date;
    l_new_okc_item_rec.last_update_login      := :new.last_update_login;
    l_new_okc_item_rec.security_group_id      := :new.security_group_id;
    l_new_okc_item_rec.upg_orig_system_ref    := :new.upg_orig_system_ref;
    l_new_okc_item_rec.upg_orig_system_ref_id := :new.upg_orig_system_ref_id;
    l_new_okc_item_rec.program_application_id := :new.program_application_id;
    l_new_okc_item_rec.program_id             := :new.program_id;
    l_new_okc_item_rec.program_update_date    := :new.program_update_date;
    l_new_okc_item_rec.request_id             := :new.request_id;
  END IF;

  --Call Trigger Event Processor
  xxssys_strataforce_events_pkg.okc_item_trg_processor(p_old_okc_item_rec => l_old_okc_item_rec,
				       p_new_okc_item_rec => l_new_okc_item_rec,
				       p_trigger_name     => l_trigger_name,
				       p_trigger_action   => l_trigger_action);

EXCEPTION
  WHEN OTHERS THEN
    l_error_message := substrb(SQLERRM, 1, 500);
    raise_application_error(-20999, l_error_message);
END xxokc_k_items_aiu_trg;
/
