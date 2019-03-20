CREATE OR REPLACE PACKAGE "XXSSYS_STRATAFORCE_EVENTS_PKG" AUTHID CURRENT_USER AS
  ----------------------------------------------------------------------------
  --  name:            xxssys_strataforce_events_pkg
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   11/14/2017
  ----------------------------------------------------------------------------
  --  purpose :        CHG0041829 - Generic package to handle all interface
  --                   event generation funtions/procedures for new Salesforce platform
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  11/14/2017  Diptasurjya Chatterjee(TCS)  CHG0041829 - initial build
  --  2.0  01/04/2018  Roman .W
  --  2.1  29.03.18    yuval tal                    CHG0042619 add is_asset_valid2sync
  --  2.2  04/12/2018  Diptasurjya                  CHG0042706 - Handle XXCS_PB_PRODUCT_FAMILY VSET interface
  --  2.3  10/12/2018  Roman W.                     INC0140843 - Strataforce  events  missing entity_code value wit...
  ----------------------------------------------------------------------------

  /* Global Variable declaration for Logging unit*/
  g_log              VARCHAR2(1) := fnd_profile.value('AFLOG_ENABLED');
  g_log_module       VARCHAR2(100) := fnd_profile.value('AFLOG_MODULE');
  g_request_id       NUMBER := fnd_profile.value('CONC_REQUEST_ID');
  g_api_name         VARCHAR2(30) := 'xxssys_strataforce_events_pkg';
  g_log_program_unit VARCHAR2(100);
  /* End - Global Variable Declaration */

  g_target_name                VARCHAR2(30) := 'STRATAFORCE';
  g_account_entity_name        VARCHAR2(50) := 'ACCOUNT';
  g_site_entity_name           VARCHAR2(50) := 'SITE';
  g_contact_entity_name        VARCHAR2(50) := 'CONTACT';
  g_fob_entity_name            VARCHAR2(50) := 'FOB';
  g_payment_term_entity_name   VARCHAR2(50) := 'PAY_TERM';
  g_item_entity_name           VARCHAR2(50) := 'PRODUCT'; --'ITEM';
  g_pricelist_entity_name      VARCHAR2(50) := 'PRICE_BOOK';
  g_pricelist_line_entity_name VARCHAR2(50) := 'PRICE_ENTRY';
  g_item_cat_entity_name       VARCHAR2(50) := 'ITEM_CATEGORY'; --'ITEM_CAT';
  g_bom_feature_entity_name    VARCHAR2(50) := 'BOM';
  g_bom_option_entity_name     VARCHAR2(50) := 'BOM_OPTION';
  g_freight_term_entity_name   VARCHAR2(50) := 'FREIGHT_TERM';
  g_quote_line_entity_name     VARCHAR2(50) := 'QUOTE_LINE';
  g_product_rule               VARCHAR2(50) := 'XXCS_PB_PRODUCT_FAMILY'; -- CHG0042706
  g_okc_contract_entity_name   VARCHAR2(50) := 'OKC_SERVICE_CONTRACT'; --CHG0042873

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name            Description
  -- 1.0  26/10/2015  Diptasurjya     Initial Creation for CHG0036886.
  --                  Chatterjee
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE write_log(p_msg VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          Check if user ID passed is a salesforce user
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee             CHG0041829 : Initial build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_strataforce_user(p_user_id NUMBER) RETURN VARCHAR2;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          Function to check is the Price book is Enabled to Sync to SFDC or Not
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/14/2017  Lingaraj                      Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_pricebook_sync_to_sf(p_list_header_id NUMBER) RETURN VARCHAR2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042706
  --          This function handles vasue set XXCS_PB_PRODUCT_FAMILY insert/update trigger to generate XXSSYS_EVENTS record
  --
  -- --------------------------------------------------------------------------------------------
  -- Usage: Trigger XXFND_VSET_VALUE_AIU_TRG2
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date           Name                   Description
  -- 1.0  13-Apr-2018    Diptasurjya            Initial Build
  -- ----------------------------------------------------------------------------------------
  PROCEDURE vset_common_trg_processor(p_old_vsetv_rec  IN fnd_flex_values%ROWTYPE,
			  p_new_vsetv_rec  IN fnd_flex_values%ROWTYPE,
			  p_trigger_name   IN VARCHAR2,
			  p_vset_name      IN VARCHAR2,
			  p_trigger_action IN VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This is a common validation procedure which will be used for performing any required validations
  --          for every entity being interfaced to SFDC Strataforce instance
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/14/2017  Diptasurjya Chatterjee(TCS)   Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE validate_entity(p_entity_name     IN VARCHAR2,
		    p_sub_entity_name IN VARCHAR2 DEFAULT NULL,
		    p_entity_id       IN NUMBER,
		    p_entity_code     IN VARCHAR2,
		    x_is_valid        OUT VARCHAR2,
		    x_status          OUT VARCHAR2,
		    x_status_message  OUT VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function handles inventory item insert/update trigger to generate XXSSYS_EVENTS record
  --
  -- --------------------------------------------------------------------------------------------
  -- Usage: Trigger XXINV_ITEM_AIUR_TRG1 on Table MTL_SYSTEM_ITEMS_B
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee             Initial Build
  -- ----------------------------------------------------------------------------------------
  PROCEDURE item_trg_processor(p_old_item_rec   IN mtl_system_items_b%ROWTYPE,
		       p_new_item_rec   IN mtl_system_items_b%ROWTYPE,
		       p_trigger_name   IN VARCHAR2,
		       p_trigger_action IN VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          Events generated for Product "PRODUCT"
  --          Used internally by this Package and also called by Trigger :"xxinv_item_cat_aiudr_trg3"
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/14/2017  Lingaraj                      Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE insert_product_event(p_inventory_item_id NUMBER,
		         p_item_code         VARCHAR2 DEFAULT NULL,
		         p_last_updated_by   NUMBER,
		         p_created_by        NUMBER,
		         p_trigger_name      VARCHAR2,
		         p_trigger_action    VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          Events generated for "ITEM_CATEGORY"
  --          called by Trigger :"xxinv_item_cat_aiudr_trg3"
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/14/2017  Lingaraj                      Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE item_cat_trg_processor(p_old_item_cat_rec IN mtl_item_categories%ROWTYPE,
		           p_new_item_cat_rec IN mtl_item_categories%ROWTYPE,
		           p_trigger_name     IN VARCHAR2,
		           p_trigger_action   IN VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function handles FRIGHT Term insert/update trigger to generate XXSSYS_EVENTS record
  --
  -- --------------------------------------------------------------------------------------------
  -- Usage: Trigger XXFND_LOOKUP_VALUES_AIUR_TRG1
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date           Name                               Description
  -- 1.0  06-Dec-2017    Lingaraj Sarangi                   Initial Build
  -- ----------------------------------------------------------------------------------------
  PROCEDURE flv_common_trg_processor(p_old_flv_rec    IN fnd_lookup_values%ROWTYPE,
			 p_new_flv_rec    IN fnd_lookup_values%ROWTYPE,
			 p_trigger_name   IN VARCHAR2,
			 p_lookup_type    IN VARCHAR2,
			 p_trigger_action IN VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function handles PROICE BOOK insert/update trigger to generate XXSSYS_EVENTS record
  --
  -- --------------------------------------------------------------------------------------------
  -- Usage: Trigger XXQP_LIST_HEADERS_AIUR_TRG1
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date           Name                               Description
  -- 1.0  06-Dec-2017    Lingaraj Sarangi                   Initial Build
  -- ----------------------------------------------------------------------------------------
  PROCEDURE pricebook_trg_processor(p_old_pl_rec     IN qp.qp_list_headers_b%ROWTYPE,
			p_new_pl_rec     IN qp.qp_list_headers_b%ROWTYPE,
			p_trigger_name   IN VARCHAR2,
			p_trigger_action IN VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function handles PRICE BOOK insert/update trigger to generate XXSSYS_EVENTS record
  --
  -- --------------------------------------------------------------------------------------------
  -- Usage: Trigger XXQP_LIST_HEADERS_TL_AIUR_TRG1
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date           Name                               Description
  -- 1.0  06-Dec-2017    Lingaraj Sarangi                   Initial Build
  -- ----------------------------------------------------------------------------------------
  PROCEDURE pricebook_tl_trg_processor(p_list_header_id  NUMBER,
			   p_created_by      NUMBER,
			   p_last_updated_by NUMBER,
			   p_trigger_name    VARCHAR2,
			   p_trigger_action  VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function handles PRICE Line Update trigger to generate XXSSYS_EVENTS record
  --
  -- --------------------------------------------------------------------------------------------
  -- Usage: Trigger XXQP_LIST_LINES_BIUDR_TRG1
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date           Name                               Description
  -- 1.0  06-Dec-2017    Lingaraj Sarangi                   Initial Build
  -- ----------------------------------------------------------------------------------------
  PROCEDURE priceline_trg_processor(p_old_pl_rec     IN qp.qp_list_lines%ROWTYPE,
			p_new_pl_rec     IN qp.qp_list_lines%ROWTYPE,
			p_trigger_name   IN VARCHAR2,
			p_trigger_action IN VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function handles PRICE Line insert/Delete trigger to generate XXSSYS_EVENTS record
  --
  -- --------------------------------------------------------------------------------------------
  -- Usage: Trigger XXQP_PRICING_ATT_BDR_TRG1
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date           Name                               Description
  -- 1.0  06-Dec-2017    Lingaraj Sarangi                   Initial Build
  -- ----------------------------------------------------------------------------------------
  PROCEDURE price_attr_trg_processor(p_list_header_id  NUMBER,
			 p_list_line_id    NUMBER,
			 p_inv_item_id     NUMBER,
			 p_last_updated_by NUMBER,
			 p_created_by      NUMBER,
			 p_trigger_name    VARCHAR2,
			 p_trigger_action  VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function handles AR Payment Term insert/update trigger to generate XXSSYS_EVENTS record
  --
  -- --------------------------------------------------------------------------------------------
  -- Usage: Trigger XXRA_TERMS_AIUR_TRG1 and  XXRA_TERMS_TL_AIUR_TRG1
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date           Name                               Description
  -- 1.0  06-Dec-2017    Lingaraj Sarangi                   Initial Build
  -- ----------------------------------------------------------------------------------------
  PROCEDURE payterm_trg_processor(p_term_id         IN NUMBER,
		          p_term_name       IN VARCHAR2 DEFAULT NULL,
		          p_start_date      IN DATE,
		          p_end_date        IN DATE,
		          p_created_by      IN NUMBER,
		          p_last_updated_by IN NUMBER,
		          p_trigger_name    IN VARCHAR2,
		          p_trigger_action  IN VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function will be used as Rule function for all activated business events
  --          for customer creation or update for new Salesforce platform
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  22/11/2017  Diptasurjya Chatterjee(TCS)   Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION customer_event_process(p_subscription_guid IN RAW,
		          p_event             IN OUT NOCOPY wf_event_t)
    RETURN VARCHAR2;

  PROCEDURE handle_om_hold_event(errbuf          OUT VARCHAR2,
		         retcode         OUT VARCHAR2,
		         p_order_hold_id NUMBER,
		         p_event_name    VARCHAR2);

  ----------------------------------------------------------------------------------------------------------
  -- Ver     When          Who          Description
  -- ------  ------------  -----------  --------------------------------------------------------------------
  -- 1.0     10/12/2018    Roman W.     INC0140843 - Strataforce  events  missing entity_code value wit...
  ----------------------------------------------------------------------------------------------------------
  PROCEDURE handle_order_line_event(errbuf        OUT VARCHAR2,
			retcode       OUT VARCHAR2,
			p_line_id     NUMBER,
			p_event_name  VARCHAR2,
			p_entity_code VARCHAR2 DEFAULT NULL);
  ----------------------------------------------------------------------------------------------------------
  -- Ver     When          Who          Description
  -- ------  ------------  -----------  --------------------------------------------------------------------
  -- 1.0     10/12/2018    Roman W.     INC0140843 - Strataforce  events  missing entity_code value wit...
  ----------------------------------------------------------------------------------------------------------
  PROCEDURE handle_order_header_event(errbuf        OUT VARCHAR2,
			  retcode       OUT VARCHAR2,
			  p_header_id   NUMBER,
			  p_event_name  VARCHAR2,
			  p_entity_code VARCHAR2 DEFAULT NULL -- inc0140843
			  );

  PROCEDURE handle_custom_events(errbuf  OUT VARCHAR2,
		         retcode OUT VARCHAR2);

  PROCEDURE sync_bom(errbuf             OUT VARCHAR2,
	         retcode            OUT VARCHAR2,
	         p_sync_x_days_back IN NUMBER DEFAULT 1);
  --
  PROCEDURE mtl_cat_trg_processor(p_old_cat_rec    IN mtl_categories_b%ROWTYPE,
		          p_new_cat_rec    IN mtl_categories_b%ROWTYPE,
		          p_trigger_name   IN VARCHAR2,
		          p_trigger_action IN VARCHAR2);

  --CHG0042203 - New 'System' item setup interface
  PROCEDURE process_system_setup(p_event_id_tab IN xxobjt.xxssys_interface_event_tab,
		         x_xml          OUT CLOB,
		         x_err_code     OUT VARCHAR2, -- S - SUCCESS  - E- ERROR
		         x_err_messge   OUT VARCHAR2);

  FUNCTION is_bom_valid(p_bill_sequence_id IN NUMBER,
		p_item_id          NUMBER,
		p_organization_id  IN NUMBER) RETURN VARCHAR2;

  FUNCTION is_bom_valid(p_inventory_item_id NUMBER,
		p_organization_id   NUMBER) RETURN VARCHAR2;

  PROCEDURE get_price_line_item_info(p_list_header_id NUMBER,
			 p_list_line_id   NUMBER,
			 x_item_id        OUT NUMBER,
			 x_item_code      OUT VARCHAR2,
			 x_currency_code  OUT VARCHAR2);

  FUNCTION is_valid_order_type(p_order_type_id IN NUMBER) RETURN VARCHAR2;

  FUNCTION is_asset_valid2sync(p_instance_id NUMBER) RETURN VARCHAR2;
  ---------------------------------------------------------------------------
  -- get_order_source_name - Fetch get_order_source Name for given source id
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  -- 1.0      30.Apr.18  Lingaraj       CHG0042734 - Initial Build
  -----------------------------------------------------------------------------
  FUNCTION get_order_source_name(p_order_source_id VARCHAR2) RETURN VARCHAR2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042873
  --
  --
  -- --------------------------------------------------------------------------------------------
  -- Usage: Called from Trigger: XXOKC_K_HEADERS_ALL_B_AIU_TRG
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date           Name                               Description
  -- 1.0  14-May-2018    Lingaraj Sarangi                   CHG0042873 - Service Contract interface - Oracle 2 SFDC
  -- ----------------------------------------------------------------------------------------
  PROCEDURE okc_header_trg_processor(p_old_okc_h_rec  IN okc.okc_k_headers_all_b%ROWTYPE,
			 p_new_okc_h_rec  IN okc.okc_k_headers_all_b%ROWTYPE,
			 p_trigger_name   IN VARCHAR2,
			 p_trigger_action IN VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042873
  --
  --
  -- --------------------------------------------------------------------------------------------
  -- Usage: Called from Trigger: XXOKC_K_LINES_B_AIU_TRG
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date           Name                               Description
  -- 1.0  14-May-2018    Lingaraj Sarangi                   CHG0042873 - Service Contract interface - Oracle 2 SFDC
  -- ----------------------------------------------------------------------------------------
  PROCEDURE okc_line_trg_processor(p_old_okc_line_rec IN okc.okc_k_lines_b%ROWTYPE,
		           p_new_okc_line_rec IN okc.okc_k_lines_b%ROWTYPE,
		           p_trigger_name     IN VARCHAR2,
		           p_trigger_action   IN VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042873
  --
  --
  -- --------------------------------------------------------------------------------------------
  -- Usage: Called from Trigger: XXOKC_K_ITEMS_AIU_TRG
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date           Name                               Description
  -- 1.0  14-May-2018    Lingaraj Sarangi                   CHG0042873 - Service Contract interface - Oracle 2 SFDC
  -- ----------------------------------------------------------------------------------------
  PROCEDURE okc_item_trg_processor(p_old_okc_item_rec IN okc.okc_k_items%ROWTYPE,
		           p_new_okc_item_rec IN okc.okc_k_items%ROWTYPE,
		           p_trigger_name     IN VARCHAR2,
		           p_trigger_action   IN VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041808 - Pricelist Line Interface
  -- Task   : CTASK0036370
  -- Purpose: When ever there is a new Item Relation ship of Type 'Service' Type
  --          Created/Modified/Deleted , the respective Items Price need to be synced to SFDC
  -- --------------------------------------------------------------------------------------------
  -- Usage: Called from Trigger :  'XXINV_RELATED_ITEMS_AIUR_TRG1'
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date           Name                               Description
  -- 1.0  06-Jun-2018    Lingaraj Sarangi                   CHG0041808[CTASK0036370] - Initial Build
  -- ----------------------------------------------------------------------------------------
  PROCEDURE related_item_trg_processor(p_old_rec        IN mtl_related_items%ROWTYPE,
			   p_new_rec        IN mtl_related_items%ROWTYPE,
			   p_trigger_name   IN VARCHAR2,
			   p_trigger_action IN VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041808 - Pricelist Line Interface
  -- Task   :
  -- Purpose: This Procedure is generate Price Entry Events for all the Records of a Price List
  --          or If Restricted to a Price List and Price Line.
  --          The Currency Code is Mandatory .
  --          This Procedure Should not be Called from Outside
  -- Currently Called from : 'pricebook_trg_processor' and 'related_item_trg_processor'
  -- --------------------------------------------------------------------------------------------
  -- Usage: Called from Trigger :  No
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date           Name                               Description
  -- 1.0  06-Jun-2018    Lingaraj Sarangi                   CHG0041808[CTASK0036370] - Initial Build
  -- ----------------------------------------------------------------------------------------
  PROCEDURE populate_priceentry_events(p_list_header_id IN NUMBER,
			   p_list_line_id   IN NUMBER DEFAULT NULL,
			   p_currency_code  IN VARCHAR2,
			   p_trigger_name   IN VARCHAR2,
			   p_trigger_action IN VARCHAR2);

END xxssys_strataforce_events_pkg;
/
