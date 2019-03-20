CREATE OR REPLACE TRIGGER xxokc_k_lines_b_aiu_trg
--------------------------------------------------------------------------------------------------
  --  name:              XXOKC_K_LINES_B_AIU_TRG
  --  create by:         Lingaraj Sarangi
  --  Revision:          1.0
  --  creation date:     10-May-2018
  --------------------------------------------------------------------------------------------------
  --  purpose :          CHG0042873 - Service Contract interface - Oracle 2 SFDC
  --                                   trigger on OKC_K_LINES_B
  --
  --  Modification History
  --------------------------------------------------------------------------------------------------
  --  ver   date          Name                       Desc
  --  1.0   10-May-2018   Lingaraj Sarangi           CHG0042873 - Service Contract interface - Oracle 2 SFDC
  --------------------------------------------------------------------------------------------------
  AFTER INSERT OR UPDATE ON "OKC"."OKC_K_LINES_B"
  FOR EACH ROW

  WHEN (new.sts_code NOT IN ('ENTERED', 'HOLD') AND new.lse_id IN (9, 18) AND
       new.creation_date > to_date ('01012019', 'ddmmyyyy'))
DECLARE
  l_trigger_name     VARCHAR2(50) := 'XXOKC_K_LINES_B_AIU_TRG';
  l_error_message    VARCHAR2(500) := '';
  l_old_okc_line_rec okc.okc_k_lines_b%ROWTYPE;
  l_new_okc_line_rec okc.okc_k_lines_b%ROWTYPE;
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
  
    l_old_okc_line_rec.id                       := :old.id;
    l_old_okc_line_rec.line_number              := :old.line_number;
    l_old_okc_line_rec.chr_id                   := :old.chr_id;
    l_old_okc_line_rec.cle_id                   := :old.cle_id;
    l_old_okc_line_rec.cle_id_renewed           := :old.cle_id_renewed;
    l_old_okc_line_rec.dnz_chr_id               := :old.dnz_chr_id;
    l_old_okc_line_rec.display_sequence         := :old.display_sequence;
    l_old_okc_line_rec.sts_code                 := :old.sts_code;
    l_old_okc_line_rec.trn_code                 := :old.trn_code;
    l_old_okc_line_rec.lse_id                   := :old.lse_id;
    l_old_okc_line_rec.exception_yn             := :old.exception_yn;
    l_old_okc_line_rec.object_version_number    := :old.object_version_number;
    l_old_okc_line_rec.created_by               := :old.created_by;
    l_old_okc_line_rec.creation_date            := :old.creation_date;
    l_old_okc_line_rec.last_updated_by          := :old.last_updated_by;
    l_old_okc_line_rec.last_update_date         := :old.last_update_date;
    l_old_okc_line_rec.hidden_ind               := :old.hidden_ind;
    l_old_okc_line_rec.price_negotiated         := :old.price_negotiated;
    l_old_okc_line_rec.price_level_ind          := :old.price_level_ind;
    l_old_okc_line_rec.price_unit               := :old.price_unit;
    l_old_okc_line_rec.price_unit_percent       := :old.price_unit_percent;
    l_old_okc_line_rec.invoice_line_level_ind   := :old.invoice_line_level_ind;
    l_old_okc_line_rec.dpas_rating              := :old.dpas_rating;
    l_old_okc_line_rec.template_used            := :old.template_used;
    l_old_okc_line_rec.price_type               := :old.price_type;
    l_old_okc_line_rec.currency_code            := :old.currency_code;
    l_old_okc_line_rec.last_update_login        := :old.last_update_login;
    l_old_okc_line_rec.date_terminated          := :old.date_terminated;
    l_old_okc_line_rec.start_date               := :old.start_date;
    l_old_okc_line_rec.end_date                 := :old.end_date;
    l_old_okc_line_rec.attribute_category       := :old.attribute_category;
    l_old_okc_line_rec.attribute1               := :old.attribute1;
    l_old_okc_line_rec.attribute2               := :old.attribute2;
    l_old_okc_line_rec.attribute3               := :old.attribute3;
    l_old_okc_line_rec.attribute4               := :old.attribute4;
    l_old_okc_line_rec.attribute5               := :old.attribute5;
    l_old_okc_line_rec.attribute6               := :old.attribute6;
    l_old_okc_line_rec.attribute7               := :old.attribute7;
    l_old_okc_line_rec.attribute8               := :old.attribute8;
    l_old_okc_line_rec.attribute9               := :old.attribute9;
    l_old_okc_line_rec.attribute10              := :old.attribute10;
    l_old_okc_line_rec.attribute11              := :old.attribute11;
    l_old_okc_line_rec.attribute12              := :old.attribute12;
    l_old_okc_line_rec.attribute13              := :old.attribute13;
    l_old_okc_line_rec.attribute14              := :old.attribute14;
    l_old_okc_line_rec.attribute15              := :old.attribute15;
    l_old_okc_line_rec.security_group_id        := :old.security_group_id;
    l_old_okc_line_rec.cle_id_renewed_to        := :old.cle_id_renewed_to;
    l_old_okc_line_rec.price_negotiated_renewed := :old.price_negotiated_renewed;
    l_old_okc_line_rec.currency_code_renewed    := :old.currency_code_renewed;
    l_old_okc_line_rec.upg_orig_system_ref      := :old.upg_orig_system_ref;
    l_old_okc_line_rec.upg_orig_system_ref_id   := :old.upg_orig_system_ref_id;
    l_old_okc_line_rec.date_renewed             := :old.date_renewed;
    l_old_okc_line_rec.orig_system_source_code  := :old.orig_system_source_code;
    l_old_okc_line_rec.orig_system_id1          := :old.orig_system_id1;
    l_old_okc_line_rec.orig_system_reference1   := :old.orig_system_reference1;
    l_old_okc_line_rec.program_application_id   := :old.program_application_id;
    l_old_okc_line_rec.program_id               := :old.program_id;
    l_old_okc_line_rec.program_update_date      := :old.program_update_date;
    l_old_okc_line_rec.request_id               := :old.request_id;
    l_old_okc_line_rec.price_list_id            := :old.price_list_id;
    l_old_okc_line_rec.price_list_line_id       := :old.price_list_line_id;
    l_old_okc_line_rec.line_list_price          := :old.line_list_price;
    l_old_okc_line_rec.item_to_price_yn         := :old.item_to_price_yn;
    l_old_okc_line_rec.pricing_date             := :old.pricing_date;
    l_old_okc_line_rec.price_basis_yn           := :old.price_basis_yn;
    l_old_okc_line_rec.config_header_id         := :old.config_header_id;
    l_old_okc_line_rec.config_revision_number   := :old.config_revision_number;
    l_old_okc_line_rec.config_complete_yn       := :old.config_complete_yn;
    l_old_okc_line_rec.config_valid_yn          := :old.config_valid_yn;
    l_old_okc_line_rec.config_top_model_line_id := :old.config_top_model_line_id;
    l_old_okc_line_rec.config_item_type         := :old.config_item_type;
    l_old_okc_line_rec.config_item_id           := :old.config_item_id;
    l_old_okc_line_rec.service_item_yn          := :old.service_item_yn;
    l_old_okc_line_rec.ph_pricing_type          := :old.ph_pricing_type;
    l_old_okc_line_rec.ph_price_break_basis     := :old.ph_price_break_basis;
    l_old_okc_line_rec.ph_min_qty               := :old.ph_min_qty;
    l_old_okc_line_rec.ph_min_amt               := :old.ph_min_amt;
    l_old_okc_line_rec.ph_qp_reference_id       := :old.ph_qp_reference_id;
    l_old_okc_line_rec.ph_value                 := :old.ph_value;
    l_old_okc_line_rec.ph_enforce_price_list_yn := :old.ph_enforce_price_list_yn;
    l_old_okc_line_rec.ph_adjustment            := :old.ph_adjustment;
    l_old_okc_line_rec.ph_integrated_with_qp    := :old.ph_integrated_with_qp;
    l_old_okc_line_rec.cust_acct_id             := :old.cust_acct_id;
    l_old_okc_line_rec.bill_to_site_use_id      := :old.bill_to_site_use_id;
    l_old_okc_line_rec.inv_rule_id              := :old.inv_rule_id;
    l_old_okc_line_rec.line_renewal_type_code   := :old.line_renewal_type_code;
    l_old_okc_line_rec.ship_to_site_use_id      := :old.ship_to_site_use_id;
    l_old_okc_line_rec.payment_term_id          := :old.payment_term_id;
    l_old_okc_line_rec.date_cancelled           := :old.date_cancelled;
    l_old_okc_line_rec.term_cancel_source       := :old.term_cancel_source;
    l_old_okc_line_rec.payment_instruction_type := :old.payment_instruction_type;
    l_old_okc_line_rec.annualized_factor        := :old.annualized_factor;
    l_old_okc_line_rec.cancelled_amount         := :old.cancelled_amount;
  
  END IF;
  -----------------------------------------------------------
  -- New Column Values After Update
  -----------------------------------------------------------
  IF inserting OR updating THEN
    l_new_okc_line_rec.id                       := :new.id;
    l_new_okc_line_rec.line_number              := :new.line_number;
    l_new_okc_line_rec.chr_id                   := :new.chr_id;
    l_new_okc_line_rec.cle_id                   := :new.cle_id;
    l_new_okc_line_rec.cle_id_renewed           := :new.cle_id_renewed;
    l_new_okc_line_rec.dnz_chr_id               := :new.dnz_chr_id;
    l_new_okc_line_rec.display_sequence         := :new.display_sequence;
    l_new_okc_line_rec.sts_code                 := :new.sts_code;
    l_new_okc_line_rec.trn_code                 := :new.trn_code;
    l_new_okc_line_rec.lse_id                   := :new.lse_id;
    l_new_okc_line_rec.exception_yn             := :new.exception_yn;
    l_new_okc_line_rec.object_version_number    := :new.object_version_number;
    l_new_okc_line_rec.created_by               := :new.created_by;
    l_new_okc_line_rec.creation_date            := :new.creation_date;
    l_new_okc_line_rec.last_updated_by          := :new.last_updated_by;
    l_new_okc_line_rec.last_update_date         := :new.last_update_date;
    l_new_okc_line_rec.hidden_ind               := :new.hidden_ind;
    l_new_okc_line_rec.price_negotiated         := :new.price_negotiated;
    l_new_okc_line_rec.price_level_ind          := :new.price_level_ind;
    l_new_okc_line_rec.price_unit               := :new.price_unit;
    l_new_okc_line_rec.price_unit_percent       := :new.price_unit_percent;
    l_new_okc_line_rec.invoice_line_level_ind   := :new.invoice_line_level_ind;
    l_new_okc_line_rec.dpas_rating              := :new.dpas_rating;
    l_new_okc_line_rec.template_used            := :new.template_used;
    l_new_okc_line_rec.price_type               := :new.price_type;
    l_new_okc_line_rec.currency_code            := :new.currency_code;
    l_new_okc_line_rec.last_update_login        := :new.last_update_login;
    l_new_okc_line_rec.date_terminated          := :new.date_terminated;
    l_new_okc_line_rec.start_date               := :new.start_date;
    l_new_okc_line_rec.end_date                 := :new.end_date;
    l_new_okc_line_rec.attribute_category       := :new.attribute_category;
    l_new_okc_line_rec.attribute1               := :new.attribute1;
    l_new_okc_line_rec.attribute2               := :new.attribute2;
    l_new_okc_line_rec.attribute3               := :new.attribute3;
    l_new_okc_line_rec.attribute4               := :new.attribute4;
    l_new_okc_line_rec.attribute5               := :new.attribute5;
    l_new_okc_line_rec.attribute6               := :new.attribute6;
    l_new_okc_line_rec.attribute7               := :new.attribute7;
    l_new_okc_line_rec.attribute8               := :new.attribute8;
    l_new_okc_line_rec.attribute9               := :new.attribute9;
    l_new_okc_line_rec.attribute10              := :new.attribute10;
    l_new_okc_line_rec.attribute11              := :new.attribute11;
    l_new_okc_line_rec.attribute12              := :new.attribute12;
    l_new_okc_line_rec.attribute13              := :new.attribute13;
    l_new_okc_line_rec.attribute14              := :new.attribute14;
    l_new_okc_line_rec.attribute15              := :new.attribute15;
    l_new_okc_line_rec.security_group_id        := :new.security_group_id;
    l_new_okc_line_rec.cle_id_renewed_to        := :new.cle_id_renewed_to;
    l_new_okc_line_rec.price_negotiated_renewed := :new.price_negotiated_renewed;
    l_new_okc_line_rec.currency_code_renewed    := :new.currency_code_renewed;
    l_new_okc_line_rec.upg_orig_system_ref      := :new.upg_orig_system_ref;
    l_new_okc_line_rec.upg_orig_system_ref_id   := :new.upg_orig_system_ref_id;
    l_new_okc_line_rec.date_renewed             := :new.date_renewed;
    l_new_okc_line_rec.orig_system_source_code  := :new.orig_system_source_code;
    l_new_okc_line_rec.orig_system_id1          := :new.orig_system_id1;
    l_new_okc_line_rec.orig_system_reference1   := :new.orig_system_reference1;
    l_new_okc_line_rec.program_application_id   := :new.program_application_id;
    l_new_okc_line_rec.program_id               := :new.program_id;
    l_new_okc_line_rec.program_update_date      := :new.program_update_date;
    l_new_okc_line_rec.request_id               := :new.request_id;
    l_new_okc_line_rec.price_list_id            := :new.price_list_id;
    l_new_okc_line_rec.price_list_line_id       := :new.price_list_line_id;
    l_new_okc_line_rec.line_list_price          := :new.line_list_price;
    l_new_okc_line_rec.item_to_price_yn         := :new.item_to_price_yn;
    l_new_okc_line_rec.pricing_date             := :new.pricing_date;
    l_new_okc_line_rec.price_basis_yn           := :new.price_basis_yn;
    l_new_okc_line_rec.config_header_id         := :new.config_header_id;
    l_new_okc_line_rec.config_revision_number   := :new.config_revision_number;
    l_new_okc_line_rec.config_complete_yn       := :new.config_complete_yn;
    l_new_okc_line_rec.config_valid_yn          := :new.config_valid_yn;
    l_new_okc_line_rec.config_top_model_line_id := :new.config_top_model_line_id;
    l_new_okc_line_rec.config_item_type         := :new.config_item_type;
    l_new_okc_line_rec.config_item_id           := :new.config_item_id;
    l_new_okc_line_rec.service_item_yn          := :new.service_item_yn;
    l_new_okc_line_rec.ph_pricing_type          := :new.ph_pricing_type;
    l_new_okc_line_rec.ph_price_break_basis     := :new.ph_price_break_basis;
    l_new_okc_line_rec.ph_min_qty               := :new.ph_min_qty;
    l_new_okc_line_rec.ph_min_amt               := :new.ph_min_amt;
    l_new_okc_line_rec.ph_qp_reference_id       := :new.ph_qp_reference_id;
    l_new_okc_line_rec.ph_value                 := :new.ph_value;
    l_new_okc_line_rec.ph_enforce_price_list_yn := :new.ph_enforce_price_list_yn;
    l_new_okc_line_rec.ph_adjustment            := :new.ph_adjustment;
    l_new_okc_line_rec.ph_integrated_with_qp    := :new.ph_integrated_with_qp;
    l_new_okc_line_rec.cust_acct_id             := :new.cust_acct_id;
    l_new_okc_line_rec.bill_to_site_use_id      := :new.bill_to_site_use_id;
    l_new_okc_line_rec.inv_rule_id              := :new.inv_rule_id;
    l_new_okc_line_rec.line_renewal_type_code   := :new.line_renewal_type_code;
    l_new_okc_line_rec.ship_to_site_use_id      := :new.ship_to_site_use_id;
    l_new_okc_line_rec.payment_term_id          := :new.payment_term_id;
    l_new_okc_line_rec.date_cancelled           := :new.date_cancelled;
    l_new_okc_line_rec.term_cancel_source       := :new.term_cancel_source;
    l_new_okc_line_rec.payment_instruction_type := :new.payment_instruction_type;
    l_new_okc_line_rec.annualized_factor        := :new.annualized_factor;
    l_new_okc_line_rec.cancelled_amount         := :new.cancelled_amount;
  END IF;

  --Call Trigger Event Processor
  xxssys_strataforce_events_pkg.okc_line_trg_processor(p_old_okc_line_rec => l_old_okc_line_rec,
				       p_new_okc_line_rec => l_new_okc_line_rec,
				       p_trigger_name     => l_trigger_name,
				       p_trigger_action   => l_trigger_action);

EXCEPTION
  WHEN OTHERS THEN
    l_error_message := substrb(SQLERRM, 1, 500);
    raise_application_error(-20999, l_error_message);
END xxokc_k_lines_b_aiu_trg;
/
