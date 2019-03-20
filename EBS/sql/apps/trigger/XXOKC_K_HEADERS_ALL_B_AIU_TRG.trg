CREATE OR REPLACE TRIGGER xxokc_k_headers_all_b_aiu_trg
--------------------------------------------------------------------------------------------------
  --  name:              XXOKC_K_HEADERS_ALL_B_AIU_TRG
  --  create by:         Lingaraj Sarangi
  --  Revision:          1.0
  --  creation date:     10-May-2018
  --------------------------------------------------------------------------------------------------
  --  purpose :          CHG0042873 - Service Contract interface - Oracle 2 SFDC
  --                                   trigger on OKC_K_HEADERS_ALL_B
  --
  --  Modification History
  --------------------------------------------------------------------------------------------------
  --  ver   date          Name                       Desc
  --  1.0   10-May-2018   Lingaraj Sarangi           CHG0042873 - Service Contract interface - Oracle 2 SFDC
  --------------------------------------------------------------------------------------------------
  AFTER INSERT OR UPDATE ON "OKC"."OKC_K_HEADERS_ALL_B"
  FOR EACH ROW

  WHEN (new.sts_code != 'ENTERED' AND new.creation_date > to_date
  ('01012019', 'ddmmyyyy'))
DECLARE
  l_trigger_name   VARCHAR2(50) := 'XXOKC_K_HEADERS_ALL_B_AIU_TRG';
  l_error_message  VARCHAR2(500) := '';
  l_old_okc_h_rec  okc.okc_k_headers_all_b%ROWTYPE;
  l_new_okc_h_rec  okc.okc_k_headers_all_b%ROWTYPE;
  l_trigger_action VARCHAR2(10) := '';
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
  
    l_old_okc_h_rec.id                       := :old.id;
    l_old_okc_h_rec.contract_number          := :old.contract_number;
    l_old_okc_h_rec.authoring_org_id         := :old.authoring_org_id;
    l_old_okc_h_rec.contract_number_modifier := :old.contract_number_modifier;
    l_old_okc_h_rec.chr_id_response          := :old.chr_id_response;
    l_old_okc_h_rec.chr_id_award             := :old.chr_id_award;
    l_old_okc_h_rec.chr_id_renewed           := :old.chr_id_renewed;
    l_old_okc_h_rec.inv_organization_id      := :old.inv_organization_id;
    l_old_okc_h_rec.sts_code                 := :old.sts_code;
    l_old_okc_h_rec.qcl_id                   := :old.qcl_id;
    l_old_okc_h_rec.scs_code                 := :old.scs_code;
    l_old_okc_h_rec.trn_code                 := :old.trn_code;
    l_old_okc_h_rec.currency_code            := :old.currency_code;
    l_old_okc_h_rec.archived_yn              := :old.archived_yn;
    l_old_okc_h_rec.deleted_yn               := :old.deleted_yn;
    l_old_okc_h_rec.template_yn              := :old.template_yn;
    l_old_okc_h_rec.chr_type                 := :old.chr_type;
    l_old_okc_h_rec.object_version_number    := :old.object_version_number;
    l_old_okc_h_rec.created_by               := :old.created_by;
    l_old_okc_h_rec.creation_date            := :old.creation_date;
    l_old_okc_h_rec.last_updated_by          := :old.last_updated_by;
    l_old_okc_h_rec.cust_po_number_req_yn    := :old.cust_po_number_req_yn;
    l_old_okc_h_rec.pre_pay_req_yn           := :old.pre_pay_req_yn;
    l_old_okc_h_rec.cust_po_number           := :old.cust_po_number;
    l_old_okc_h_rec.dpas_rating              := :old.dpas_rating;
    l_old_okc_h_rec.template_used            := :old.template_used;
    l_old_okc_h_rec.date_approved            := :old.date_approved;
    l_old_okc_h_rec.datetime_cancelled       := :old.datetime_cancelled;
    l_old_okc_h_rec.auto_renew_days          := :old.auto_renew_days;
    l_old_okc_h_rec.date_issued              := :old.date_issued;
    l_old_okc_h_rec.datetime_responded       := :old.datetime_responded;
    l_old_okc_h_rec.rfp_type                 := :old.rfp_type;
    l_old_okc_h_rec.keep_on_mail_list        := :old.keep_on_mail_list;
    l_old_okc_h_rec.set_aside_percent        := :old.set_aside_percent;
    l_old_okc_h_rec.response_copies_req      := :old.response_copies_req;
    l_old_okc_h_rec.date_close_projected     := :old.date_close_projected;
    l_old_okc_h_rec.datetime_proposed        := :old.datetime_proposed;
    l_old_okc_h_rec.date_signed              := :old.date_signed;
    l_old_okc_h_rec.date_terminated          := :old.date_terminated;
    l_old_okc_h_rec.date_renewed             := :old.date_renewed;
    l_old_okc_h_rec.start_date               := :old.start_date;
    l_old_okc_h_rec.end_date                 := :old.end_date;
    l_old_okc_h_rec.buy_or_sell              := :old.buy_or_sell;
    l_old_okc_h_rec.issue_or_receive         := :old.issue_or_receive;
    l_old_okc_h_rec.last_update_login        := :old.last_update_login;
    l_old_okc_h_rec.estimated_amount         := :old.estimated_amount;
    l_old_okc_h_rec.attribute_category       := :old.attribute_category;
    l_old_okc_h_rec.last_update_date         := :old.last_update_date;
    l_old_okc_h_rec.attribute1               := :old.attribute1;
    l_old_okc_h_rec.attribute2               := :old.attribute2;
    l_old_okc_h_rec.attribute3               := :old.attribute3;
    l_old_okc_h_rec.attribute4               := :old.attribute4;
    l_old_okc_h_rec.attribute5               := :old.attribute5;
    l_old_okc_h_rec.attribute6               := :old.attribute6;
    l_old_okc_h_rec.attribute7               := :old.attribute7;
    l_old_okc_h_rec.attribute8               := :old.attribute8;
    l_old_okc_h_rec.attribute9               := :old.attribute9;
    l_old_okc_h_rec.attribute10              := :old.attribute10;
    l_old_okc_h_rec.attribute11              := :old.attribute11;
    l_old_okc_h_rec.attribute12              := :old.attribute12;
    l_old_okc_h_rec.attribute13              := :old.attribute13;
    l_old_okc_h_rec.attribute14              := :old.attribute14;
    l_old_okc_h_rec.attribute15              := :old.attribute15;
    l_old_okc_h_rec.security_group_id        := :old.security_group_id;
    l_old_okc_h_rec.chr_id_renewed_to        := :old.chr_id_renewed_to;
    l_old_okc_h_rec.estimated_amount_renewed := :old.estimated_amount_renewed;
    l_old_okc_h_rec.currency_code_renewed    := :old.currency_code_renewed;
    l_old_okc_h_rec.upg_orig_system_ref      := :old.upg_orig_system_ref;
    l_old_okc_h_rec.upg_orig_system_ref_id   := :old.upg_orig_system_ref_id;
    l_old_okc_h_rec.application_id           := :old.application_id;
    l_old_okc_h_rec.resolved_until           := :old.resolved_until;
    l_old_okc_h_rec.orig_system_source_code  := :old.orig_system_source_code;
    l_old_okc_h_rec.orig_system_id1          := :old.orig_system_id1;
    l_old_okc_h_rec.orig_system_reference1   := :old.orig_system_reference1;
    l_old_okc_h_rec.program_application_id   := :old.program_application_id;
    l_old_okc_h_rec.program_id               := :old.program_id;
    l_old_okc_h_rec.program_update_date      := :old.program_update_date;
    l_old_okc_h_rec.request_id               := :old.request_id;
    l_old_okc_h_rec.price_list_id            := :old.price_list_id;
    l_old_okc_h_rec.pricing_date             := :old.pricing_date;
    l_old_okc_h_rec.total_line_list_price    := :old.total_line_list_price;
    l_old_okc_h_rec.sign_by_date             := :old.sign_by_date;
    l_old_okc_h_rec.user_estimated_amount    := :old.user_estimated_amount;
    l_old_okc_h_rec.governing_contract_yn    := :old.governing_contract_yn;
    l_old_okc_h_rec.document_id              := :old.document_id;
    l_old_okc_h_rec.conversion_type          := :old.conversion_type;
    l_old_okc_h_rec.conversion_rate          := :old.conversion_rate;
    l_old_okc_h_rec.conversion_rate_date     := :old.conversion_rate_date;
    l_old_okc_h_rec.conversion_euro_rate     := :old.conversion_euro_rate;
    l_old_okc_h_rec.cust_acct_id             := :old.cust_acct_id;
    l_old_okc_h_rec.bill_to_site_use_id      := :old.bill_to_site_use_id;
    l_old_okc_h_rec.inv_rule_id              := :old.inv_rule_id;
    l_old_okc_h_rec.renewal_type_code        := :old.renewal_type_code;
    l_old_okc_h_rec.renewal_notify_to        := :old.renewal_notify_to;
    l_old_okc_h_rec.renewal_end_date         := :old.renewal_end_date;
    l_old_okc_h_rec.ship_to_site_use_id      := :old.ship_to_site_use_id;
    l_old_okc_h_rec.payment_term_id          := :old.payment_term_id;
    l_old_okc_h_rec.approval_type            := :old.approval_type;
    l_old_okc_h_rec.term_cancel_source       := :old.term_cancel_source;
    l_old_okc_h_rec.payment_instruction_type := :old.payment_instruction_type;
    l_old_okc_h_rec.org_id                   := :old.org_id;
    l_old_okc_h_rec.cancelled_amount         := :old.cancelled_amount;
    l_old_okc_h_rec.billed_at_source         := :old.billed_at_source;
  
  END IF;
  -----------------------------------------------------------
  -- New Column Values After Update
  -----------------------------------------------------------
  IF inserting OR updating THEN
    l_new_okc_h_rec.id                       := :new.id;
    l_new_okc_h_rec.contract_number          := :new.contract_number;
    l_new_okc_h_rec.authoring_org_id         := :new.authoring_org_id;
    l_new_okc_h_rec.contract_number_modifier := :new.contract_number_modifier;
    l_new_okc_h_rec.chr_id_response          := :new.chr_id_response;
    l_new_okc_h_rec.chr_id_award             := :new.chr_id_award;
    l_new_okc_h_rec.chr_id_renewed           := :new.chr_id_renewed;
    l_new_okc_h_rec.inv_organization_id      := :new.inv_organization_id;
    l_new_okc_h_rec.sts_code                 := :new.sts_code;
    l_new_okc_h_rec.qcl_id                   := :new.qcl_id;
    l_new_okc_h_rec.scs_code                 := :new.scs_code;
    l_new_okc_h_rec.trn_code                 := :new.trn_code;
    l_new_okc_h_rec.currency_code            := :new.currency_code;
    l_new_okc_h_rec.archived_yn              := :new.archived_yn;
    l_new_okc_h_rec.deleted_yn               := :new.deleted_yn;
    l_new_okc_h_rec.template_yn              := :new.template_yn;
    l_new_okc_h_rec.chr_type                 := :new.chr_type;
    l_new_okc_h_rec.object_version_number    := :new.object_version_number;
    l_new_okc_h_rec.created_by               := :new.created_by;
    l_new_okc_h_rec.creation_date            := :new.creation_date;
    l_new_okc_h_rec.last_updated_by          := :new.last_updated_by;
    l_new_okc_h_rec.cust_po_number_req_yn    := :new.cust_po_number_req_yn;
    l_new_okc_h_rec.pre_pay_req_yn           := :new.pre_pay_req_yn;
    l_new_okc_h_rec.cust_po_number           := :new.cust_po_number;
    l_new_okc_h_rec.dpas_rating              := :new.dpas_rating;
    l_new_okc_h_rec.template_used            := :new.template_used;
    l_new_okc_h_rec.date_approved            := :new.date_approved;
    l_new_okc_h_rec.datetime_cancelled       := :new.datetime_cancelled;
    l_new_okc_h_rec.auto_renew_days          := :new.auto_renew_days;
    l_new_okc_h_rec.date_issued              := :new.date_issued;
    l_new_okc_h_rec.datetime_responded       := :new.datetime_responded;
    l_new_okc_h_rec.rfp_type                 := :new.rfp_type;
    l_new_okc_h_rec.keep_on_mail_list        := :new.keep_on_mail_list;
    l_new_okc_h_rec.set_aside_percent        := :new.set_aside_percent;
    l_new_okc_h_rec.response_copies_req      := :new.response_copies_req;
    l_new_okc_h_rec.date_close_projected     := :new.date_close_projected;
    l_new_okc_h_rec.datetime_proposed        := :new.datetime_proposed;
    l_new_okc_h_rec.date_signed              := :new.date_signed;
    l_new_okc_h_rec.date_terminated          := :new.date_terminated;
    l_new_okc_h_rec.date_renewed             := :new.date_renewed;
    l_new_okc_h_rec.start_date               := :new.start_date;
    l_new_okc_h_rec.end_date                 := :new.end_date;
    l_new_okc_h_rec.buy_or_sell              := :new.buy_or_sell;
    l_new_okc_h_rec.issue_or_receive         := :new.issue_or_receive;
    l_new_okc_h_rec.last_update_login        := :new.last_update_login;
    l_new_okc_h_rec.estimated_amount         := :new.estimated_amount;
    l_new_okc_h_rec.attribute_category       := :new.attribute_category;
    l_new_okc_h_rec.last_update_date         := :new.last_update_date;
    l_new_okc_h_rec.attribute1               := :new.attribute1;
    l_new_okc_h_rec.attribute2               := :new.attribute2;
    l_new_okc_h_rec.attribute3               := :new.attribute3;
    l_new_okc_h_rec.attribute4               := :new.attribute4;
    l_new_okc_h_rec.attribute5               := :new.attribute5;
    l_new_okc_h_rec.attribute6               := :new.attribute6;
    l_new_okc_h_rec.attribute7               := :new.attribute7;
    l_new_okc_h_rec.attribute8               := :new.attribute8;
    l_new_okc_h_rec.attribute9               := :new.attribute9;
    l_new_okc_h_rec.attribute10              := :new.attribute10;
    l_new_okc_h_rec.attribute11              := :new.attribute11;
    l_new_okc_h_rec.attribute12              := :new.attribute12;
    l_new_okc_h_rec.attribute13              := :new.attribute13;
    l_new_okc_h_rec.attribute14              := :new.attribute14;
    l_new_okc_h_rec.attribute15              := :new.attribute15;
    l_new_okc_h_rec.security_group_id        := :new.security_group_id;
    l_new_okc_h_rec.chr_id_renewed_to        := :new.chr_id_renewed_to;
    l_new_okc_h_rec.estimated_amount_renewed := :new.estimated_amount_renewed;
    l_new_okc_h_rec.currency_code_renewed    := :new.currency_code_renewed;
    l_new_okc_h_rec.upg_orig_system_ref      := :new.upg_orig_system_ref;
    l_new_okc_h_rec.upg_orig_system_ref_id   := :new.upg_orig_system_ref_id;
    l_new_okc_h_rec.application_id           := :new.application_id;
    l_new_okc_h_rec.resolved_until           := :new.resolved_until;
    l_new_okc_h_rec.orig_system_source_code  := :new.orig_system_source_code;
    l_new_okc_h_rec.orig_system_id1          := :new.orig_system_id1;
    l_new_okc_h_rec.orig_system_reference1   := :new.orig_system_reference1;
    l_new_okc_h_rec.program_application_id   := :new.program_application_id;
    l_new_okc_h_rec.program_id               := :new.program_id;
    l_new_okc_h_rec.program_update_date      := :new.program_update_date;
    l_new_okc_h_rec.request_id               := :new.request_id;
    l_new_okc_h_rec.price_list_id            := :new.price_list_id;
    l_new_okc_h_rec.pricing_date             := :new.pricing_date;
    l_new_okc_h_rec.total_line_list_price    := :new.total_line_list_price;
    l_new_okc_h_rec.sign_by_date             := :new.sign_by_date;
    l_new_okc_h_rec.user_estimated_amount    := :new.user_estimated_amount;
    l_new_okc_h_rec.governing_contract_yn    := :new.governing_contract_yn;
    l_new_okc_h_rec.document_id              := :new.document_id;
    l_new_okc_h_rec.conversion_type          := :new.conversion_type;
    l_new_okc_h_rec.conversion_rate          := :new.conversion_rate;
    l_new_okc_h_rec.conversion_rate_date     := :new.conversion_rate_date;
    l_new_okc_h_rec.conversion_euro_rate     := :new.conversion_euro_rate;
    l_new_okc_h_rec.cust_acct_id             := :new.cust_acct_id;
    l_new_okc_h_rec.bill_to_site_use_id      := :new.bill_to_site_use_id;
    l_new_okc_h_rec.inv_rule_id              := :new.inv_rule_id;
    l_new_okc_h_rec.renewal_type_code        := :new.renewal_type_code;
    l_new_okc_h_rec.renewal_notify_to        := :new.renewal_notify_to;
    l_new_okc_h_rec.renewal_end_date         := :new.renewal_end_date;
    l_new_okc_h_rec.ship_to_site_use_id      := :new.ship_to_site_use_id;
    l_new_okc_h_rec.payment_term_id          := :new.payment_term_id;
    l_new_okc_h_rec.approval_type            := :new.approval_type;
    l_new_okc_h_rec.term_cancel_source       := :new.term_cancel_source;
    l_new_okc_h_rec.payment_instruction_type := :new.payment_instruction_type;
    l_new_okc_h_rec.org_id                   := :new.org_id;
    l_new_okc_h_rec.cancelled_amount         := :new.cancelled_amount;
    l_new_okc_h_rec.billed_at_source         := :new.billed_at_source;
  END IF;

  --Call Trigger Event Processor
  xxssys_strataforce_events_pkg.okc_header_trg_processor(p_old_okc_h_rec  => l_old_okc_h_rec,
				         p_new_okc_h_rec  => l_new_okc_h_rec,
				         p_trigger_name   => l_trigger_name,
				         p_trigger_action => l_trigger_action);

EXCEPTION
  WHEN OTHERS THEN
    l_error_message := substrb(SQLERRM, 1, 500);
  
    fnd_log.string(log_level => fnd_log.level_unexpected,
	       module    => 'TRIGGER.XXOKC_K_HEADERS_ALL_B_AIU_TRG',
	       message   => l_error_message);
  
  --RAISE_APPLICATION_ERROR(-20999,l_error_message);
END xxokc_k_headers_all_b_aiu_trg;
/
