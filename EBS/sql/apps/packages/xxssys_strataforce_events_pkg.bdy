CREATE OR REPLACE PACKAGE BODY xxssys_strataforce_events_pkg AS
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
  -- ----  ----------  ---------------------------- --------------------------------------------------------------------------------------------
  --  1.0  11/14/2017  Diptasurjya Chatterjee(TCS)  CHG0041829 - initial build
  --  1.1  28.03.18    yuval tal                    CHG0042619 modify handle_custom_events / add handle_asset_event
  --  1.2  29.03.18    yuval tal/Roman.W.           CHG0042560 - Sites - Locations oa2sf interface
  --                                                    modify handle_site / customer_event_process/ add handle_site_use_account/handle_account_site
  --                                                    BE : 1) oracle.apps.ar.hz.CustAcctSite.create
  --                                                         2) oracle.apps.ar.hz.CustAcctSite.update
  --                                                         3) oracle.apps.ar.hz.CustAcctSiteUse.create
  --                                                         4) oracle.apps.ar.hz.CustAcctSiteUse.update
  --  1.3  10.4.18       yuval tal                  CHG0042619 add is_asset_valid2sync ,modify handle_custom_events ,add handle_asset_event
  --  1.4  18-Feb-2018   Lingaraj Sarangi           CHG0042203 - New 'System' item setup interface
  --  1.4  04/12/2018    Diptasurjya                CHG0042706 - Handle XXCS_PB_PRODUCT_FAMILY VSET interface
  --  1.5  07/17/2018    Diptasurjya                CTASK0037600 - Add additional filter to handle_contact_point
  --  1.6   12.8.18       yuval tal                 INC0129899 modify generate_bom_events
  --  1.7  03.10.18      Lingaraj                   CHG0043859 - Install base interface changes from Oracle to salesforce
  --  1.8  15-Nov-18     Lingaraj                   CHG0044334 - Change in SO header interface
  --                                                     Update "Complete Order Shipped Date" and "Systems Shipped Date"
  --  1.9  20-Nov-18     Lingaraj                   CHG0042632 - CTASK0039365 - sync Location
  --  2.0  10/12/2018    Roman W.                   CHG0044657 - Strataforce  events  missing entity_code value wit...    
  --                                                      handle_order_line_event
  --                                                      handle_order_header_event
  --  2.1  31/12/2018    Lingaraj                   CHG0044757 - add logic to choose relevant shipping information and billing information
  --  2.2  09/01/2019    Lingaraj                   INC0143702 - Business Event - subscription (Handling Site create/update)   
  ----------------------------------------------------------------------------------------------------------------------------------------------
  g_user_id     NUMBER := 0;
  g_resp_id     NUMBER := 0;
  g_appl_id     NUMBER := 0;
  g_eventname   VARCHAR2(1000);
  g_eventaction VARCHAR2(10);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name            Description
  -- 1.0  11/20/2017  Diptasurjya     Initial Creation for CHG0041829.
  --                  Chatterjee
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE write_log(p_msg VARCHAR2) IS
  BEGIN
  
    IF g_log = 'Y' AND 'xxssys.' || g_api_name || g_log_program_unit LIKE
       lower(g_log_module) THEN
      fnd_log.string(log_level => fnd_log.level_unexpected,
	         module    => 'xxssys.' || g_api_name ||
		          g_log_program_unit,
	         message   => p_msg);
    END IF;
  END write_log;

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
		    x_status_message  OUT VARCHAR2) IS
    l_function_string  VARCHAR2(150);
    l_validation_query VARCHAR2(2000);
  
  BEGIN
    BEGIN
      SELECT upper(ffvv.attribute2)
      INTO   l_function_string
      FROM   fnd_flex_values_vl  ffvv,
	 fnd_flex_value_sets ffvs
      WHERE  ffvs.flex_value_set_name = 'XXSSYS_EVENT_ENTITY_NAME'
      AND    ffvv.parent_flex_value_low = 'STRATAFORCE'
      AND    ffvv.flex_value = p_entity_name
      AND    ffvs.flex_value_set_id = ffvv.flex_value_set_id
      AND    ffvv.enabled_flag = 'Y'
      AND    SYSDATE BETWEEN nvl(ffvv.start_date_active, SYSDATE - 1) AND
	 nvl(ffvv.end_date_active, SYSDATE + 1)
      AND    ffvv.attribute2 IS NOT NULL;
    EXCEPTION
      WHEN no_data_found THEN
        x_status         := 'S';
        x_is_valid       := 'X';
        x_status_message := 'No Validations to be performed';
        RETURN;
    END;
  
    l_function_string := REPLACE(l_function_string,
		         ':P_SUB_ENTITY_NAME',
		         nvl(p_sub_entity_name, 'null'));
    l_function_string := REPLACE(l_function_string,
		         ':P_ENTITY_ID',
		         nvl(to_char(p_entity_id), 'null'));
    l_function_string := REPLACE(l_function_string,
		         ':P_ENTITY_CODE',
		         '''' || p_entity_code || '''');
  
    l_validation_query := 'select ' || l_function_string || ' from dual';
  
    EXECUTE IMMEDIATE l_validation_query
      INTO x_is_valid;
  
    x_status := 'S';
  EXCEPTION
    WHEN OTHERS THEN
      x_status         := 'E';
      x_status_message := 'ERROR: UNEXCEPTED VALIDATION ERROR: ' || SQLERRM;
  END validate_entity;

  -- --------------------------------------------------------------------------------------------
  -- Name:              compare_old_new_items
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     11/026/2017
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function will be used to compare item before update with item after update
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/26/2017  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION compare_old_new_items(p_old_item_rec mtl_system_items_b%ROWTYPE,
		         p_new_item_rec mtl_system_items_b%ROWTYPE)
    RETURN VARCHAR2 IS
    l_comparison_status VARCHAR2(10);
  BEGIN
    IF p_old_item_rec.segment1 = p_new_item_rec.segment1 AND
       nvl(p_old_item_rec.inventory_item_status_code, '-1') =
       nvl(p_new_item_rec.inventory_item_status_code, '-1') AND
       nvl(p_old_item_rec.description, '-1') =
       nvl(p_new_item_rec.description, '-1') AND
       nvl(p_old_item_rec.primary_uom_code, '-1') =
       nvl(p_new_item_rec.primary_uom_code, '-1') AND
       nvl(p_old_item_rec.volume_uom_code, '-1') =
       nvl(p_new_item_rec.volume_uom_code, '-1') AND
       nvl(p_old_item_rec.weight_uom_code, '-1') =
       nvl(p_new_item_rec.weight_uom_code, '-1') AND
       nvl(p_old_item_rec.unit_weight, 0) =
       nvl(p_new_item_rec.unit_weight, 0) AND
       nvl(p_old_item_rec.unit_volume, 0) =
       nvl(p_new_item_rec.unit_volume, 0) AND
      
       nvl(p_old_item_rec.item_type, '-1') =
       nvl(p_new_item_rec.item_type, '-1') AND
       nvl(p_old_item_rec.customer_order_enabled_flag, '-1') =
       nvl(p_new_item_rec.customer_order_enabled_flag, '-1') AND
       nvl(p_old_item_rec.customer_order_flag, '-1') =
       nvl(p_new_item_rec.customer_order_flag, '-1') AND
       nvl(p_old_item_rec.returnable_flag, '-1') =
       nvl(p_new_item_rec.returnable_flag, '-1') AND
       nvl(p_old_item_rec.material_billable_flag, '-1') =
       nvl(p_new_item_rec.material_billable_flag, '-1')
    
     THEN
      RETURN 'N'; -- Record Not Changed
    ELSE
      RETURN 'Y'; -- Record Changed
    END IF;
  END compare_old_new_items;

  FUNCTION compare_old_new_flv(p_old_flv_rec fnd_lookup_values%ROWTYPE,
		       p_new_flv_rec fnd_lookup_values%ROWTYPE,
		       p_lookup_type VARCHAR2) RETURN VARCHAR2 IS
    l_comparison_status VARCHAR2(10);
  BEGIN
    IF p_lookup_type IN ('FREIGHT_TERMS', 'FOB') THEN
      IF p_old_flv_rec.lookup_type = p_new_flv_rec.lookup_type AND
         nvl(p_old_flv_rec.lookup_code, '-1') =
         nvl(p_new_flv_rec.lookup_code, '-1') AND
         nvl(p_old_flv_rec.meaning, '-1') =
         nvl(p_new_flv_rec.meaning, '-1') AND
        -- nvl(p_old_flv_rec.description,'-1')       = nvl(p_new_flv_rec.description,'-1')     and
         nvl(p_old_flv_rec.enabled_flag, '-1') =
         nvl(p_new_flv_rec.enabled_flag, '-1') AND
         nvl(p_old_flv_rec.start_date_active, trunc(SYSDATE)) =
         nvl(p_new_flv_rec.start_date_active, trunc(SYSDATE)) AND
         nvl(p_old_flv_rec.end_date_active, trunc(SYSDATE)) =
         nvl(p_new_flv_rec.end_date_active, trunc(SYSDATE))
      --nvl(p_old_flv_rec.tag,'-1')               = nvl(p_new_flv_rec.tag,'-1')
       THEN
        RETURN 'Y';
      ELSE
        RETURN 'N';
      END IF;
    END IF;
  END compare_old_new_flv;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042706 - This function compares two valuset value input records
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  04/13/2018  Diptasurjya Chatterjee (TCS)    CHG0042706 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION compare_old_new_vsetv(p_old_vsetv_rec fnd_flex_values%ROWTYPE,
		         p_new_vsetv_rec fnd_flex_values%ROWTYPE,
		         p_vset_name     VARCHAR2) RETURN VARCHAR2 IS
    l_comparison_status VARCHAR2(10);
  BEGIN
    IF p_vset_name IN ('XXCS_PB_PRODUCT_FAMILY') THEN
      IF p_old_vsetv_rec.flex_value = p_new_vsetv_rec.flex_value AND
         nvl(p_old_vsetv_rec.enabled_flag, 'N') =
         nvl(p_new_vsetv_rec.enabled_flag, 'N') AND
         nvl(p_old_vsetv_rec.start_date_active,
	 to_date('01-JAN-1900', 'dd-MON-rrrr')) =
         nvl(p_new_vsetv_rec.start_date_active,
	 to_date('01-JAN-1900', 'dd-MON-rrrr')) AND
         nvl(p_old_vsetv_rec.end_date_active,
	 to_date('01-JAN-1900', 'dd-MON-rrrr')) =
         nvl(p_new_vsetv_rec.end_date_active,
	 to_date('01-JAN-1900', 'dd-MON-rrrr')) THEN
        RETURN 'Y';
      ELSE
        RETURN 'N';
      END IF;
    END IF;
  END compare_old_new_vsetv;

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
			  p_trigger_action IN VARCHAR2) IS
    l_compare_rec_status VARCHAR2(1) := 'N';
    --l_is_valid           varchar2(1);
    --l_validation_status  varchar2(1);
    l_error_message VARCHAR2(2000);
  
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    e_validation_exception EXCEPTION;
    l_entity_name  VARCHAR2(50) := '';
    l_create_event VARCHAR2(1) := 'N';
  BEGIN
    g_log_program_unit := lower(p_vset_name) || '_trg_processor';
    write_log('Inside ' || p_vset_name || '  trigger processer for ' ||
	  g_target_name);
  
    IF p_trigger_action = 'UPDATE' THEN
      -- Compare old and new records to check for applicable changes
      l_compare_rec_status := compare_old_new_vsetv(p_old_vsetv_rec,
				    p_new_vsetv_rec,
				    p_vset_name);
    END IF;
  
    --N - Changes in Old and New Rec
    --Y - Old and New Records Match
  
    IF l_compare_rec_status = 'N' THEN
      --Prepare Event Record
    
      --Select the Entity Name
      IF p_vset_name = 'XXCS_PB_PRODUCT_FAMILY' THEN
        l_entity_name  := g_product_rule;
        l_create_event := 'Y';
      ELSE
        l_entity_name  := '';
        l_create_event := 'N';
      END IF;
    
      l_xxssys_event_rec.target_name := g_target_name;
      l_xxssys_event_rec.entity_name := l_entity_name;
    
      l_xxssys_event_rec.active_flag := 'Y';
    
      l_xxssys_event_rec.entity_id       := nvl(p_new_vsetv_rec.flex_value_id,
				p_old_vsetv_rec.flex_value_id);
      l_xxssys_event_rec.last_updated_by := nvl(p_new_vsetv_rec.last_updated_by,
				p_old_vsetv_rec.last_updated_by);
      l_xxssys_event_rec.created_by      := nvl(p_new_vsetv_rec.created_by,
				p_old_vsetv_rec.created_by);
      l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			        p_trigger_action || ')';
    
      IF l_create_event = 'Y' THEN
        xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
        write_log('trigger event inserted for Value Set :' || p_vset_name);
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_error_message := substr(SQLERRM, 1, 500);
      raise_application_error(-20001, l_error_message);
  END vset_common_trg_processor;

  FUNCTION compare_old_new_pricebook_b(p_old_pl_rec IN qp.qp_list_headers_b%ROWTYPE,
			   p_new_pl_rec IN qp.qp_list_headers_b%ROWTYPE)
    RETURN VARCHAR2 IS
    l_comparison_status VARCHAR2(10);
  BEGIN
  
    IF p_old_pl_rec.list_header_id = p_new_pl_rec.list_header_id AND
       nvl(p_old_pl_rec.currency_code, '-1') =
       nvl(p_new_pl_rec.currency_code, '-1') AND
      
       nvl(p_old_pl_rec.active_flag, '-1') =
       nvl(p_new_pl_rec.active_flag, '-1') AND
      
       nvl(p_old_pl_rec.global_flag, '-1') =
       nvl(p_new_pl_rec.global_flag, '-1') AND
      
       nvl(p_old_pl_rec.orig_org_id, -99) =
       nvl(p_new_pl_rec.orig_org_id, -99)
      /*And nvl(p_old_PL_rec.start_date_active,trunc(sysdate - 1))
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   = nvl(p_new_PL_rec.start_date_active,trunc(sysdate - 1))*/
      
       AND nvl(p_old_pl_rec.attribute3, '-1') =
       nvl(p_new_pl_rec.attribute3, '-1') --Usage
      
       AND nvl(p_old_pl_rec.attribute6, '-1') =
       nvl(p_new_pl_rec.attribute6, '-1') --Transfer to SF?
      
       AND nvl(p_old_pl_rec.attribute10, '-1') =
       nvl(p_new_pl_rec.attribute10, '-1') --GAM price list
      
       AND nvl(p_old_pl_rec.attribute11, '-1') =
       nvl(p_new_pl_rec.attribute11, '-1') -- Direct PL
      
       AND nvl(p_old_pl_rec.attribute12, '-1') =
       nvl(p_new_pl_rec.attribute12, '-1') --Pre-Commision enabled
      
       AND nvl(p_old_pl_rec.attribute14, '-1') =
       nvl(p_new_pl_rec.attribute14, '-1') --Direct\Indirect
     THEN
      RETURN 'N'; -- Record Not Changed
    ELSE
      RETURN 'Y'; -- Record Changed
    END IF;
  
  END compare_old_new_pricebook_b;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          Check if user ID passed is a salesforce user
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee             CHG0041829 : Initial build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_strataforce_user(p_user_id NUMBER) RETURN VARCHAR2 IS
    l_is_salesforce_user NUMBER;
  BEGIN
    SELECT COUNT(1)
    INTO   l_is_salesforce_user
    FROM   fnd_user fu
    WHERE  fu.user_id = p_user_id
    AND    fu.user_name = g_target_name;
    IF l_is_salesforce_user > 0 THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;
  END is_strataforce_user;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          Function to check is the Price book is Enabled to Sync to SFDC or Not
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/14/2017  Lingaraj                      Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_pricebook_sync_to_sf(p_list_header_id NUMBER) RETURN VARCHAR2 IS
    l_sync_to_sf VARCHAR2(1) := 'N';
  BEGIN
    SELECT 'Y'
    INTO   l_sync_to_sf
    FROM   qp_list_headers_b
    WHERE  list_header_id = p_list_header_id
    AND    nvl(attribute6, 'N') = 'Y' -- sync to SF Flag should be Yes
    AND    nvl(active_flag, 'N') = 'Y' -- Price Should Be ative
    AND    trunc(SYSDATE) BETWEEN nvl(start_date_active, (SYSDATE - 1)) AND
           nvl(end_date_active, (SYSDATE + 1));
  
    RETURN l_sync_to_sf;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
    WHEN too_many_rows THEN
      RETURN 'Y';
  END is_pricebook_sync_to_sf;
  --
  FUNCTION get_price_list_currency(p_list_header_id IN NUMBER)
    RETURN VARCHAR2 IS
    l_currency_code qp_list_headers_all_b.currency_code%TYPE;
  BEGIN
  
    SELECT currency_code
    INTO   l_currency_code
    FROM   qp_list_headers_all_b
    WHERE  list_header_id = p_list_header_id;
  
    RETURN l_currency_code;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_price_list_currency;
  --
  /*FUNCTION get_price_line_info1(p_list_header_id    IN NUMBER,
                                p_list_line_id      IN NUMBER,
                                x_currency_code     OUT VARCHAR2,
                                x_itemcode          OUT VARCHAR2,
                                x_inventory_item_id OUT NUMBER
                                )
    RETURN BOOLEAN IS
  BEGIN
  
    SELECT currency_code,
           segment1,
           inventory_item_id
    INTO   x_currency_code,
           x_itemcode,
           x_inventory_item_id
    FROM   xxom_pricelines_dtl_v
    WHERE  list_header_id = p_list_header_id
    AND    list_line_id = p_list_line_id;
  
    RETURN TRUE;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN FALSE;
  END;*/

  -- --------------------------------------------------------------------------------------------
  -- get_price_line_item_code
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                Description
  -- 1.0  18-Feb-2018   yuval tal          CHG0041630 - Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE get_price_line_item_info(p_list_header_id NUMBER,
			 p_list_line_id   NUMBER,
			 x_item_id        OUT NUMBER,
			 x_item_code      OUT VARCHAR2,
			 x_currency_code  OUT VARCHAR2) IS
  
  BEGIN
    SELECT msib.segment1,
           msib.inventory_item_id,
           qlh.currency_code
    INTO   x_item_code,
           x_item_id,
           x_currency_code
    FROM   qp_list_headers_all_b qlh,
           qp_pricing_attributes qpa,
           mtl_system_items_b    msib
    WHERE  qlh.list_header_id = qpa.list_header_id
    AND    qpa.list_header_id = p_list_header_id
    AND    qpa.list_line_id = p_list_line_id
    AND    msib.organization_id = 91
    AND    qpa.product_attr_value <> 'ALL'
    AND    qpa.product_attr_value = to_char(msib.inventory_item_id)
    AND    qpa.product_attribute_context = 'ITEM'
    AND    qlh.list_type_code = 'PRL'
    AND    nvl(qpa.pricing_attribute_context, 'x') = 'x';
  
    /*EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL; */
  END get_price_line_item_info;
  -- --------------------------------------------------------------------------------------------
  -- is_bom_valid
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                Description
  -- 1.0  18-Feb-2018   Lingaraj Sarangi    CHG0041630 - Initial Build
  -- --------------------------------------------------------------------------------------------
  --
  --PTO kit (msib.bom_item_type = 4 AND msib.pick_components_flag = 'Y') --PTO KIT
  -- Identifying PTO Model with no option class:
  --  BOM Item Type = Model (in table mtl_system_items_b, field BOM_ITEM_TYPE = 1 ) and check inside BOM that all components do not have BOM Item Type = Option Class. If even one component has BOM Item type= Option Class =2, do not interface.
  -----------------------------------------------------------------------------------------------
  FUNCTION is_bom_valid(p_bill_sequence_id IN NUMBER,
		p_item_id          IN NUMBER,
		p_organization_id  IN NUMBER) RETURN VARCHAR2 IS
  
    l_bom_type        NUMBER := NULL;
    l_cnt             NUMBER := 0;
    l_is_valid        VARCHAR2(1) := 'N';
    l_organization_id NUMBER := xxinv_utils_pkg.get_master_organization_id;
  BEGIN
  
    --Is Item Valid PTO KIT or PTO Model  Item ?
    --If not satisfy, control will move to Exception Section
    SELECT bom_item_type
    INTO   l_bom_type
    FROM   mtl_system_items_b msib
    WHERE  msib.organization_id = nvl(p_organization_id, l_organization_id)
    AND    msib.inventory_item_id = p_item_id
    AND    ((msib.bom_item_type = 4 AND msib.pick_components_flag = 'Y') --PTO KIT
          OR (msib.bom_item_type = 1) --PTO Model
          );
  
    IF l_bom_type = 4 THEN
      l_is_valid := 'Y';
    ELSIF l_bom_type = 1 THEN
    
      BEGIN
      
        IF p_bill_sequence_id IS NOT NULL THEN
        
          SELECT 'N'
          INTO   l_is_valid
          FROM   bom_bill_of_materials_v x
          
          WHERE  x.bill_sequence_id = p_bill_sequence_id
          AND    EXISTS
           (SELECT 1
	      FROM   bom_inventory_components_v b
	      WHERE  b.bom_item_type = 2 -- OPTION  CLASS
	      AND    b.bill_sequence_id = x.bill_sequence_id
	      AND    trunc(SYSDATE) BETWEEN b.implementation_date AND
		 nvl(b.disable_date, (SYSDATE + 1)));
        
        ELSE
        
          SELECT 'N'
          INTO   l_is_valid
          FROM   bom_bill_of_materials_v x,
	     mtl_system_items_b      msib
          WHERE  rownum = 1
          AND    msib.bom_item_type = 1 --Model
          AND    msib.inventory_item_id = x.assembly_item_id
          AND    x.organization_id = msib.organization_id
          AND    msib.organization_id =
	     nvl(p_organization_id, l_organization_id)
          AND    msib.inventory_item_id = p_item_id
          AND    EXISTS
           (SELECT 1
	      FROM   bom_inventory_components_v b
	      WHERE  b.bom_item_type = 2 -- OPTION CLASS
	      AND    b.bill_sequence_id = x.bill_sequence_id
	      AND    trunc(SYSDATE) BETWEEN b.implementation_date AND
		 nvl(b.disable_date, (SYSDATE + 1)));
        
        END IF;
      EXCEPTION
        WHEN no_data_found THEN
          l_is_valid := 'Y';
        
      END;
    
    END IF;
  
    RETURN l_is_valid;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
  END is_bom_valid;
  --
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041630
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                Description
  -- 1.0  18-Feb-2018   Lingaraj Sarangi    CHG0041630 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_bom_valid(p_inventory_item_id NUMBER,
		p_organization_id   NUMBER) RETURN VARCHAR2 IS
  
  BEGIN
  
    RETURN is_bom_valid(p_bill_sequence_id => NULL,
		p_item_id          => p_inventory_item_id,
		p_organization_id  => p_organization_id);
  END is_bom_valid;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          Generate account event in table XXSSYS_EVENTS from relevant business events
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee             CHG0041829 : Initial build
  -- 1.1  24/05/2018  Lingaraj                           Fix- If p_cust_account_number not available fetch and assign
  -- --------------------------------------------------------------------------------------------
  PROCEDURE handle_account(p_cust_account_id     IN NUMBER,
		   p_cust_account_number VARCHAR2 DEFAULT NULL) IS
    l_xxssys_event_rec    xxssys_events%ROWTYPE;
    l_is_valid            VARCHAR2(1);
    l_error               VARCHAR2(3000);
    l_cust_account_number VARCHAR2(240) := p_cust_account_number;
  BEGIN
    write_log('xxssys_strataforce_events_pkg.handle_account Called, cust_account_id :' ||
	  p_cust_account_id);
    BEGIN
      l_is_valid := xxssys_strataforce_valid_pkg.validate_account(p_sub_entity_code => NULL,
					      p_entity_id       => p_cust_account_id,
					      p_entity_code     => NULL);
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20001, 'UNEXPECTED ERROR: ' || SQLERRM);
    END;
    write_log('Is Account Valid :' || l_is_valid);
  
    IF l_is_valid <> 'N' THEN
      --Version 1.1
      --If p_cust_account_number is null then Fetch the Account Number and assign to the Entity Code
      IF p_cust_account_number IS NULL THEN
        BEGIN
          SELECT account_number
          INTO   l_cust_account_number
          FROM   hz_cust_accounts
          WHERE  cust_account_id = p_cust_account_id;
        EXCEPTION
          WHEN no_data_found THEN
	NULL;
        END;
      END IF;
    
      l_xxssys_event_rec.target_name     := g_target_name;
      l_xxssys_event_rec.entity_name     := g_account_entity_name;
      l_xxssys_event_rec.entity_id       := p_cust_account_id;
      l_xxssys_event_rec.entity_code     := l_cust_account_number;
      l_xxssys_event_rec.event_name      := g_eventname;
      l_xxssys_event_rec.last_updated_by := g_user_id;
      l_xxssys_event_rec.created_by      := g_user_id;
    
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
      write_log('Event Generated for :' || g_account_entity_name ||
	    ' ,entity_id : ' || p_cust_account_id);
    END IF;
  END handle_account;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042560
  --          Generate site event in table XXSSYS_EVENTS from relevant business events
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  29.3.18  Yuval tal            CHG0042560 - Sites - Locations oa2sf interface
  -- 1.1  20-Nov-18  Lingaraj           CHG0042632 - CTASK0039365 - sync Location
  -- 1.2  31-Dec-18  Lingaraj           CHG0044757 - Sync only Sites Where Site Org ID = hz_parties.Attribute3
  -- 1.3  09-Jan-19  Lingaraj           INC0143702 - Business Event - subscription (Handling Site create/update) 
  -- --------------------------------------------------------------------------------------------
  PROCEDURE handle_account_site(p_cust_acct_site_id IN NUMBER) IS
    l_xxssys_event_rec xxssys_events%ROWTYPE;
  
    CURSOR c_site IS
      SELECT hca.cust_account_id,
	 hcasa.cust_acct_site_id,
	 hca.account_number,
	 hps.party_site_number --CHG0042632
      FROM   hz_cust_accounts       hca,
	 hz_parties             hp,
	 hz_party_sites         hps,
	 hz_cust_acct_sites_all hcasa
      
      WHERE  hca.party_id = hp.party_id
      AND    hca.cust_account_id = hcasa.cust_account_id
      AND    hps.party_site_id = hcasa.party_site_id
      AND    hcasa.org_id != 89
      AND    hp.party_type IN ('ORGANIZATION', 'PERSON') --CHG0044757 -CTASK0039880
      AND    hcasa.cust_acct_site_id = p_cust_acct_site_id;
  l_event_name VARCHAR2(500); --INC0143702
  BEGIN
    l_event_name := 'xxssys_strataforce_events_pkg.handle_account_site' ||
                   (Case When g_eventname is not null Then
                       ('|'||g_eventname)
                    Else
                       ''
                    End);     --INC0143702  
    
    FOR i IN c_site LOOP
      l_xxssys_event_rec.target_name     := g_target_name;
      l_xxssys_event_rec.entity_name     := g_site_entity_name;
      l_xxssys_event_rec.entity_id       := p_cust_acct_site_id;
      l_xxssys_event_rec.entity_code     := i.party_site_number; --CHG0042632
      --l_xxssys_event_rec.event_name      := 'xxssys_strataforce_events_pkg.handle_account_site'; --CHG0042632
      l_xxssys_event_rec.event_name      := l_event_name;----INC0143702
      l_xxssys_event_rec.last_updated_by := g_user_id;
      l_xxssys_event_rec.created_by      := g_user_id;
    
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
    
      --Generate Account EVENT to sync the Site and Bill to Address
      --Added on 22.Jun.2018
      l_xxssys_event_rec.entity_name := g_account_entity_name;
      l_xxssys_event_rec.entity_id   := i.cust_account_id;
      l_xxssys_event_rec.entity_code := i.account_number;
    
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
    END LOOP;
  
  END handle_account_site;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042560
  --          Generate site event in table XXSSYS_EVENTS from relevant business events
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  29.3.18  Yuval tal            CHG0042560 - Sites - Locations oa2sf interface
  -- 1.1  31-Dec-18  Lingaraj           CHG0044757 - Sync only Sites Where Site Org ID = hz_parties.Attribute3
  -- 1.2  09-Jan-19  Lingaraj           INC0143702 - Business Event - subscription (Handling Site create/update)
  -- --------------------------------------------------------------------------------------------
  PROCEDURE handle_site_use_account(p_site_use_id IN NUMBER) IS
    l_xxssys_event_rec xxssys_events%ROWTYPE;
  
    CURSOR c_site IS
      SELECT hcasa.cust_acct_site_id,
	 suse.site_use_id,
	 hps.party_site_number --CHG0042632
      FROM   hz_cust_accounts       hca,
	 hz_parties             hp,
	 hz_party_sites         hps,
	 hz_cust_acct_sites_all hcasa,
	 hz_cust_site_uses_all  suse
      WHERE  hca.party_id = hp.party_id
      AND    hca.cust_account_id = hcasa.cust_account_id
      AND    hps.party_site_id = hcasa.party_site_id
      AND    hcasa.org_id = suse.org_id
      AND    hcasa.cust_acct_site_id = suse.cust_acct_site_id
      AND    suse.site_use_code IN ('BILL_TO', 'SHIP_TO')
      AND    hcasa.org_id != 89
      AND    suse.site_use_id = p_site_use_id
      AND    hp.party_type IN ('ORGANIZATION', 'PERSON'); --CHG0044757 -CTASK0039880
  l_event_name VARCHAR2(500);--INC0143702
  BEGIN
   l_event_name := 'xxssys_strataforce_events_pkg.handle_account_site' ||
                    (Case When g_eventname is not null Then
                       ('|'||g_eventname)
                    Else
                       ''
                    End); --INC0143702
                     
    FOR i IN c_site LOOP
      l_xxssys_event_rec.target_name     := g_target_name;
      l_xxssys_event_rec.entity_name     := g_site_entity_name;
      l_xxssys_event_rec.entity_id       := i.cust_acct_site_id;
      l_xxssys_event_rec.entity_code     := i.party_site_number; --CHG0042632
      --l_xxssys_event_rec.event_name      := 'xxssys_strataforce_events_pkg.handle_site_use_account'; --CHG0042632
      l_xxssys_event_rec.event_name      := l_event_name;--INC0143702
      l_xxssys_event_rec.last_updated_by := g_user_id;
      l_xxssys_event_rec.created_by      := g_user_id;
    
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
    END LOOP;
  
  END handle_site_use_account;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          Generate account event in table XXSSYS_EVENTS from relevant business events
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee             CHG0041829 : Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE handle_contact(p_contact_id IN NUMBER) IS
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    l_is_valid         VARCHAR2(1) := 'N';
  BEGIN
  
    BEGIN
      l_is_valid := xxssys_strataforce_valid_pkg.validate_contact(p_sub_entity_code => NULL,
					      p_entity_id       => p_contact_id,
					      p_entity_code     => NULL);
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20001, 'UNEXPECTED ERROR: ' || SQLERRM);
    END;
    write_log('handle_contact() - Valid Contact :' || l_is_valid);
  
    IF l_is_valid <> 'N' THEN
      l_xxssys_event_rec.target_name     := g_target_name;
      l_xxssys_event_rec.entity_name     := g_contact_entity_name;
      l_xxssys_event_rec.entity_id       := p_contact_id;
      l_xxssys_event_rec.event_name      := g_eventname;
      l_xxssys_event_rec.last_updated_by := g_user_id;
      l_xxssys_event_rec.created_by      := g_user_id;
    
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
    END IF;
  END handle_contact;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function is used to handle the Party information.
  --          A party entity can be associated with an account or a contact. So we will need to check
  --          both account and contact for change in party information
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE handle_party(p_party_id IN NUMBER) IS
    CURSOR cur_acct IS
      SELECT hca.cust_account_id,
	 hca.account_number,
	 hp.party_id
      FROM   hz_cust_accounts hca,
	 hz_parties       hp
      WHERE  hca.party_id = hp.party_id
      AND    hp.party_id = p_party_id;
  
    CURSOR cur_contact_of IS
      SELECT hcar.cust_account_role_id contact_id,
	 hp_cont.party_id
      FROM   hz_cust_accounts      hca,
	 hz_parties            hp_cont,
	 hz_relationships      hr,
	 hz_cust_account_roles hcar
      WHERE  hp_cont.party_id = p_party_id
      AND    hcar.cust_account_id = hca.cust_account_id
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.party_id = hr.party_id
      AND    hcar.cust_acct_site_id IS NULL
      AND    hp_cont.party_id = hr.subject_id
      AND    hr.subject_type = 'PERSON'
      AND    hr.object_type = 'ORGANIZATION'
      AND    hr.relationship_code = 'CONTACT_OF'
      AND    hca.party_id = hr.object_id;
  
    CURSOR cur_employee_of IS
      SELECT hcar.cust_account_role_id contact_id,
	 hp_cont.party_id
      FROM   hz_cust_accounts      hca,
	 hz_parties            hp_cont,
	 hz_relationships      hr,
	 hz_cust_account_roles hcar
      WHERE  hp_cont.party_id = p_party_id
      AND    hcar.cust_account_id = hca.cust_account_id
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.party_id = hr.party_id
      AND    hcar.cust_acct_site_id IS NULL
      AND    hp_cont.party_id = hr.subject_id
      AND    hr.subject_type = 'PERSON'
      AND    hr.object_type = 'ORGANIZATION'
      AND    hr.relationship_code = 'EMPLOYEE_OF'
      AND    hca.party_id = hr.object_id;
  
    l_is_valid VARCHAR2(1);
  BEGIN
    write_log('xxssys_strataforce_events_pkg.handle_party Called with p_party_id :' ||
	  p_party_id);
    -- Start account checking for party
    BEGIN
      l_is_valid := xxssys_strataforce_valid_pkg.validate_account(p_sub_entity_code => 'PARTY',
					      p_entity_id       => p_party_id,
					      p_entity_code     => NULL);
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20001, 'UNEXPECTED ERROR: ' || SQLERRM);
    END;
  
    write_log('Valid Account :' || l_is_valid);
  
    IF l_is_valid <> 'N' THEN
      FOR rec_acct IN cur_acct LOOP
        handle_account(rec_acct.cust_account_id, rec_acct.account_number);
      END LOOP;
    END IF;
    -- End account checking for party
  
    -- Start contact checking for party
    l_is_valid := NULL;
  
    BEGIN
      l_is_valid := xxssys_strataforce_valid_pkg.validate_contact(p_sub_entity_code => 'PARTY',
					      p_entity_id       => p_party_id,
					      p_entity_code     => NULL);
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20001, 'UNEXPECTED ERROR: ' || SQLERRM);
    END;
  
    IF l_is_valid <> 'N' THEN
      FOR rec_contact IN cur_contact_of LOOP
        handle_contact(rec_contact.contact_id);
      END LOOP;
    
      FOR rec_contact IN cur_employee_of LOOP
        handle_contact(rec_contact.contact_id);
      END LOOP;
    END IF;
    -- End contact checking for party
  END handle_party;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function is used to handle the HZ Relationship information.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE handle_relationship(p_relationship_id IN NUMBER) IS
    CURSOR cur_relationship IS
      SELECT hca_subject.cust_account_id sub_account_id,
	 hca_object.cust_account_id  obj_account_id
      FROM   hz_cust_accounts hca_subject,
	 hz_cust_accounts hca_object,
	 hz_relationships hr
      WHERE  hr.relationship_id = p_relationship_id
      AND    hr.subject_id = hca_subject.cust_account_id
      AND    hr.object_id = hca_object.cust_account_id
      AND    hca_subject.status = 'A'
      AND    hca_object.status = 'A';
  
    l_is_valid           VARCHAR2(1);
    l_validation_status  VARCHAR2(1);
    l_validation_message VARCHAR2(2000);
    l_fsl_order_source   VARCHAR2(30);
  
    e_validation_exception EXCEPTION;
  BEGIN
    BEGIN
      l_is_valid := xxssys_strataforce_valid_pkg.validate_account(p_sub_entity_code => 'RELATIONSHIP',
					      p_entity_id       => p_relationship_id,
					      p_entity_code     => NULL);
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20001, 'UNEXPECTED ERROR: ' || SQLERRM);
    END;
  
    IF l_is_valid <> 'N' THEN
      FOR rec_relationship IN cur_relationship LOOP
        handle_account(rec_relationship.sub_account_id);
        handle_account(rec_relationship.obj_account_id);
      END LOOP;
    END IF;
  END handle_relationship;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function is used to handle the HZ Code Assignment information.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE handle_code_assignment(p_code_assignment_id IN NUMBER) IS
  
    CURSOR cur_code_assignment IS
      SELECT hca.cust_account_id
      FROM   hz_cust_accounts    hca,
	 hz_parties          hp,
	 hz_code_assignments hco
      WHERE  hca.party_id = hp.party_id
      AND    hco.code_assignment_id = p_code_assignment_id
      AND    hp.party_id = hco.owner_table_id
      AND    hca.status = 'A'
      AND    hp.party_type IN ('PERSON', 'ORGANIZATION')
      AND    rownum = 1;
  
    l_is_valid VARCHAR2(1);
  BEGIN
    BEGIN
      l_is_valid := xxssys_strataforce_valid_pkg.validate_account(p_sub_entity_code => 'CODE_ASSIGNMENT',
					      p_entity_id       => p_code_assignment_id,
					      p_entity_code     => NULL);
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20001, 'UNEXPECTED ERROR: ' || SQLERRM);
    END;
  
    IF l_is_valid <> 'N' THEN
      FOR rec_code_assignment IN cur_code_assignment LOOP
        handle_account(rec_code_assignment.cust_account_id);
      END LOOP;
    END IF;
  END handle_code_assignment;  
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - INC0143702
  --          This function is used to handle the Party Site information.
  --          Source of the Code is [xxhz_ecomm_event_pkg - Package]
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name            Description  
  -- 1.0  09/01/2019    Lingaraj        INC0143702 - Business Event - subscription (Handling Site create/update)
  -- --------------------------------------------------------------------------------------------
  PROCEDURE handle_party_site(p_party_site_id IN NUMBER) IS

    l_exists_site VARCHAR2(1) := 'T';
    l_party_site  NUMBER;
    l_cnt         NUMBER := 0;

    CURSOR cur_party_site IS
      SELECT hcsua.site_use_id party_site_id
      FROM   hz_cust_accounts       hca,
	  hz_party_sites         hps,
	  hz_cust_site_uses_all  hcsua,
	  hz_cust_acct_sites_all hcasa
      WHERE  hps.party_site_id = p_party_site_id
      AND    hps.party_id = hca.party_id
      AND    hps.party_site_id = hcasa.party_site_id
      AND    hca.cust_account_id = hcasa.cust_account_id
      AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
      AND    EXISTS (SELECT 1
	         FROM   hr_organization_units hru
	         WHERE  hru.organization_id = hcasa.org_id
	         AND    hru.attribute7 = 'Y');

    CURSOR cur_contact IS
      SELECT hcar.cust_account_role_id contact_id
      FROM   hz_cust_accounts      hca,
	  hz_party_sites        hps,
	  hz_relationships      hr,
	  hz_cust_account_roles hcar
      WHERE  hps.party_site_id = p_party_site_id
      AND    hr.party_id = hps.party_id
      AND    hr.subject_type = 'ORGANIZATION'
      AND    hr.subject_id = hca.party_id
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.party_id = hr.party_id
      AND    hcar.cust_acct_site_id IS NULL;

  BEGIN

    FOR i IN cur_party_site LOOP
      EXIT WHEN cur_party_site%NOTFOUND;
      handle_site_use_account(i.party_site_id);
      l_cnt := l_cnt + 1;
    END LOOP;

    IF l_cnt = 0 THEN
      FOR j IN cur_contact LOOP
        handle_contact(j.contact_id);
      END LOOP;
    END IF;

  END handle_party_site;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - INC0143702
  --          This function This function handles cust_account_role_id
  --          Source of the Code is [xxhz_ecomm_event_pkg - Package]
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name            Description  
  -- 1.0  09/01/2019    Lingaraj        INC0143702 - Business Event - subscription (Handling Site create/update)
  -- ----------------------------------------------------------------------------------------
  PROCEDURE handle_cust_accnt_role(p_cust_account_role_id IN NUMBER) IS
  
    CURSOR cur_accnt_role IS
      SELECT cust_account_role_id
      FROM   hz_cust_account_roles
      WHERE  cust_account_role_id = p_cust_account_role_id;
  
  BEGIN
    FOR i IN cur_accnt_role LOOP
      handle_contact(i.cust_account_role_id);
    END LOOP;
  
  END handle_cust_accnt_role;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function handles org_contact_id info
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee             Initial Build
  -- ----------------------------------------------------------------------------------------
  PROCEDURE handle_org_contact(p_org_contact_id IN NUMBER) IS
    CURSOR cur_org_contact IS
      SELECT cust_roles.cust_account_role_id contact_id
      FROM   hz_cust_accounts      cust_acc,
	 hz_cust_account_roles cust_roles,
	 hz_relationships      cust_rel,
	 hz_parties            cust_party,
	 hz_parties            party,
	 hz_org_contacts       hoc
      WHERE  cust_acc.cust_account_id = cust_roles.cust_account_id
      AND    cust_acc.status = 'A'
      AND    hoc.org_contact_id = p_org_contact_id
      AND    cust_roles.role_type = 'CONTACT'
      AND    cust_roles.cust_acct_site_id IS NULL
      AND    cust_roles.party_id = cust_rel.party_id
      AND    cust_rel.subject_type = 'PERSON'
      AND    cust_rel.subject_id = cust_party.party_id
      AND    cust_rel.relationship_id = hoc.party_relationship_id
      AND    party.party_type = 'ORGANIZATION'
      AND    cust_acc.party_id = party.party_id;
  
    l_is_valid VARCHAR2(1);
  BEGIN
    BEGIN
      l_is_valid := xxssys_strataforce_valid_pkg.validate_contact(p_sub_entity_code => 'ORG_CONTACT',
					      p_entity_id       => p_org_contact_id,
					      p_entity_code     => NULL);
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20001, 'UNEXPECTED ERROR: ' || SQLERRM);
    END;
  
    IF l_is_valid <> 'N' THEN
      FOR rec_org_contact IN cur_org_contact LOOP
        handle_contact(rec_org_contact.contact_id);
      END LOOP;
    END IF;
  END handle_org_contact;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function handles contact point info
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee             Initial Build
  -- 1.1  07/18/2018  Diptasurjya Chatterjee             CTASK0037600 - Add active status check for account cursor
  -- ----------------------------------------------------------------------------------------
  PROCEDURE handle_contact_point(p_contact_point_id IN NUMBER) IS
    CURSOR cur_account IS
      SELECT DISTINCT hca.cust_account_id
      FROM   hz_contact_points     hcp,
	 hz_cust_accounts      hca,
	 hz_relationships      hr,
	 hz_cust_account_roles hcar
      WHERE  hcp.contact_point_id = p_contact_point_id
      AND    hcp.owner_table_name = 'HZ_PARTIES'
      AND    hcp.owner_table_id = hr.party_id
      AND    hr.subject_type = 'ORGANIZATION'
      AND    hr.subject_id = hca.party_id
      AND    hcar.role_type = 'CONTACT'
      AND    hca.status = 'A'
      AND    hcar.party_id = hr.party_id
      AND    hcar.cust_acct_site_id IS NULL
      AND    ((hcp.contact_point_type = 'PHONE' AND
	hcp.phone_line_type IN ('GEN', 'FAX')) OR
	hcp.contact_point_type = 'WEB');
  
    CURSOR cur_cont_point IS
      SELECT DISTINCT cust_roles.cust_account_role_id contact_id
      FROM   hz_cust_accounts      cust_acc,
	 hz_cust_account_roles cust_roles,
	 hz_relationships      cust_rel,
	 hz_parties            cust_party,
	 hz_parties            cust_party1,
	 hz_org_contacts       cust_cont,
	 hz_contact_points     hcp
      WHERE  hcp.contact_point_id = p_contact_point_id
      AND    hcp.owner_table_name = 'HZ_PARTIES'
      AND    hcp.owner_table_id = cust_roles.party_id
      AND    cust_acc.cust_account_id = cust_roles.cust_account_id
      AND    cust_acc.status = 'A'
      AND    cust_roles.role_type = 'CONTACT'
      AND    cust_roles.cust_acct_site_id IS NULL
      AND    cust_roles.party_id = cust_rel.party_id
      AND    cust_rel.subject_type = 'PERSON'
      AND    cust_rel.subject_id = cust_party.party_id
      AND    cust_cont.party_relationship_id = cust_rel.relationship_id
      AND    cust_acc.party_id = cust_party1.party_id
      AND    cust_party1.party_type = 'ORGANIZATION';
  
    l_is_valid VARCHAR2(1);
  
  BEGIN
    BEGIN
      l_is_valid := xxssys_strataforce_valid_pkg.validate_contact(p_sub_entity_code => 'CONTACT_POINT',
					      p_entity_id       => p_contact_point_id,
					      p_entity_code     => NULL);
      write_log('Is VALID Contact :' || l_is_valid);
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20001, 'UNEXPECTED ERROR: ' || SQLERRM);
    END;
  
    IF l_is_valid <> 'N' THEN
      FOR rec_account IN cur_account LOOP
        handle_account(rec_account.cust_account_id);
      END LOOP;
    
      FOR rec_cont_point IN cur_cont_point LOOP
        handle_contact(rec_cont_point.contact_id);
      END LOOP;
    END IF;
  END handle_contact_point;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function handles HZ location info
  --          Change in location entity can impact a contact or a site. So both contact and site
  --          entities will be checked and events will be created as required for either of them
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee             Initial Build
  -- 1.1  29.3.18     yuval .tal                         CHG0042560 - add site support
  -- 1.2  09/01/2019    Lingaraj                   INC0143702 - Business Event - subscription (Handling Site create/update)
  -- ----------------------------------------------------------------------------------------
  PROCEDURE handle_location(p_location_id IN NUMBER) IS
    CURSOR cur_contact IS
      SELECT cust_roles.cust_account_role_id contact_id
      FROM   hz_cust_accounts      cust_acc,
	 hz_cust_account_roles cust_roles,
	 hz_relationships      cust_rel,
	 hz_parties            cust_party,
	 hz_org_contacts       cust_cont,
	 hz_party_sites        x,
	 hz_parties            party
      WHERE  cust_cont.status = 'A'
      AND    x.party_id = cust_roles.party_id
      AND    x.location_id = p_location_id
      AND    cust_acc.cust_account_id = cust_roles.cust_account_id
      AND    cust_acc.status = 'A'
      AND    cust_roles.role_type = 'CONTACT'
      AND    cust_roles.cust_acct_site_id IS NULL
      AND    cust_roles.party_id = cust_rel.party_id
      AND    cust_rel.subject_type = 'PERSON'
      AND    cust_rel.subject_id = cust_party.party_id
      AND    cust_cont.party_relationship_id = cust_rel.relationship_id
      AND    party.party_type IN ('PERSON', 'ORGANIZATION')
      AND    cust_acc.party_id = party.party_id;
  
    CURSOR cur_site IS
      SELECT site.cust_acct_site_id
      FROM   hz_parties             hp,
	 hz_cust_accounts       hca,
	 hz_cust_acct_sites_all site,
	 hz_party_sites         hps
      WHERE  hca.party_id = hp.party_id
      AND    hca.cust_account_id = site.cust_account_id
      AND    site.party_site_id = hps.party_site_id
	  AND hp.party_type IN ('PERSON', 'ORGANIZATION') --INC0143702
      --AND    hp.party_type = 'ORGANIZATION'
      AND    hca.status = 'A'
      AND    hps.status = 'A'
      AND    site.status = 'A'
      AND    hps.location_id = p_location_id;
  
    l_is_valid VARCHAR2(1);
  
  BEGIN
    /* Start - Contact checking for location change */
    BEGIN
      l_is_valid := xxssys_strataforce_valid_pkg.validate_contact(p_sub_entity_code => 'LOCATION',
					      p_entity_id       => p_location_id,
					      p_entity_code     => NULL);
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20001, 'UNEXPECTED ERROR: ' || SQLERRM);
    END;
  
    IF l_is_valid <> 'N' THEN
      FOR rec_contact IN cur_contact LOOP
        handle_contact(rec_contact.contact_id);
      END LOOP;
    END IF;
    -- enter site events
    FOR rec_site IN cur_site LOOP
      handle_account_site(rec_site.cust_acct_site_id);
    
    END LOOP;
  
  END handle_location;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function handles inventory item insert/update trigger to generate XXSSYS_EVENTS record
  --
  -- --------------------------------------------------------------------------------------------
  -- Usage: Trigger XXINV_ITEM_AIUR_TRG1
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee             Initial Build
  -- 1.1  21/05/2018  Lingaraj Sarangi                   CHG0042204 - CTASK0036714 - Quote expiration on discontinued item
  -- ----------------------------------------------------------------------------------------
  PROCEDURE item_trg_processor(p_old_item_rec   IN mtl_system_items_b%ROWTYPE,
		       p_new_item_rec   IN mtl_system_items_b%ROWTYPE,
		       p_trigger_name   IN VARCHAR2,
		       p_trigger_action IN VARCHAR2) IS
  
    l_inventory_item_id  NUMBER;
    l_is_valid           VARCHAR2(1);
    l_validation_status  VARCHAR2(1);
    l_validation_message VARCHAR2(2000);
    l_is_item_changed    VARCHAR2(1) := 'N';
  
    l_xxssys_event_rec xxssys_events%ROWTYPE;
  
    e_validation_exception EXCEPTION;
  BEGIN
    g_log_program_unit := 'item_trigger_processor';
  
    write_log('Inside item trigger processer for ' || g_target_name);
  
    IF p_trigger_action = 'UPDATE' THEN
      -- Compare old and new records to check for applicable changes
      l_is_item_changed := compare_old_new_items(p_old_item_rec,
				 p_new_item_rec);
    END IF;
  
    write_log('Item trigger compare status: ' || l_is_item_changed);
  
    IF l_is_item_changed = 'Y' OR p_trigger_action = 'INSERT' THEN
    
      insert_product_event(p_inventory_item_id => nvl(p_new_item_rec.inventory_item_id,
				      p_old_item_rec.inventory_item_id),
		   p_item_code         => nvl(p_new_item_rec.segment1,
				      p_old_item_rec.segment1),
		   p_last_updated_by   => nvl(p_new_item_rec.last_updated_by,
				      p_old_item_rec.last_updated_by),
		   p_created_by        => nvl(p_new_item_rec.created_by,
				      p_old_item_rec.created_by),
		   p_trigger_name      => p_trigger_name,
		   p_trigger_action    => p_trigger_action);
    
    END IF;
  
    --CHG0042204 - Quote expiration on discontinued items
    --Insert Quote expiration Event, If Item Status Changed to Discontinued or Obsolete
    IF l_is_item_changed = 'Y' AND
       (p_old_item_rec.inventory_item_status_code NOT IN
       ('XX_DISCONT', 'Obsolete') AND p_new_item_rec.inventory_item_status_code IN
       ('XX_DISCONT', 'Obsolete')) THEN
      l_xxssys_event_rec                 := NULL;
      l_xxssys_event_rec.target_name     := g_target_name;
      l_xxssys_event_rec.entity_name     := g_quote_line_entity_name;
      l_xxssys_event_rec.entity_id       := p_new_item_rec.inventory_item_id;
      l_xxssys_event_rec.entity_code     := p_new_item_rec.segment1;
      l_xxssys_event_rec.last_updated_by := nvl(p_new_item_rec.last_updated_by,
				p_old_item_rec.last_updated_by);
      l_xxssys_event_rec.created_by      := nvl(p_new_item_rec.created_by,
				p_old_item_rec.created_by);
      l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			        p_trigger_action || ')';
    
      --Begin CHG0042204 - CTASK0036714
      l_xxssys_event_rec.attribute2 := p_new_item_rec.inventory_item_status_code;
      IF (xxssys_oa2sf_util_pkg.get_category_value('Activity Analysis',
				   p_new_item_rec.inventory_item_id) IN
         ('Systems (net)', 'Systems-Used', 'BDL-Systems')) THEN
        l_xxssys_event_rec.attribute3 := 'True';
      ELSE
        l_xxssys_event_rec.attribute3 := 'False';
      END IF;
      --End CHG0042204 - CTASK0036714
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
    
      write_log('Quote expiration event inserted');
    END IF;
  
    --Create "PRICE_ENTRY_STD" events for all Currencies
    --Master Organization restriction is available in Trigger [XXINV_ITEM_AIUR_TRG1]
    IF p_trigger_action = 'INSERT' THEN
      FOR cur_rec IN (SELECT currency_code
	          FROM   fnd_currencies_vl fc
	          WHERE  instr(fnd_profile.value('XXOBJT_OA2SF_CURRENCY_LIST'),
		           fc.currency_code) > 0) LOOP
      
        l_xxssys_event_rec             := NULL;
        l_xxssys_event_rec.entity_name := 'PRICE_ENTRY_STD';
        l_xxssys_event_rec.entity_id   := p_new_item_rec.inventory_item_id;
        l_xxssys_event_rec.attribute2  := cur_rec.currency_code;
        l_xxssys_event_rec.attribute3  := p_new_item_rec.segment1;
        l_xxssys_event_rec.entity_code := cur_rec.currency_code || '|' ||
			      p_new_item_rec.segment1;
      
        l_xxssys_event_rec.target_name     := g_target_name;
        l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			          p_trigger_action || ')';
        l_xxssys_event_rec.created_by      := p_new_item_rec.created_by;
        l_xxssys_event_rec.last_updated_by := p_new_item_rec.last_updated_by;
      
        xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
      
      END LOOP;
    END IF;
  
  EXCEPTION
    WHEN e_validation_exception THEN
      raise_application_error(-20001, l_validation_message);
  END item_trg_processor;
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
		         p_trigger_action    VARCHAR2) IS
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    l_item_code        VARCHAR2(240) := p_item_code;
  BEGIN
    IF p_item_code IS NULL THEN
      BEGIN
        SELECT segment1
        INTO   l_item_code
        FROM   mtl_system_items_b
        WHERE  organization_id = xxinv_utils_pkg.get_master_organization_id
        AND    inventory_item_id = p_inventory_item_id;
      EXCEPTION
        WHEN no_data_found THEN
          l_item_code := '';
      END;
    END IF;
  
    l_xxssys_event_rec                 := NULL;
    l_xxssys_event_rec.target_name     := g_target_name;
    l_xxssys_event_rec.entity_name     := g_item_entity_name;
    l_xxssys_event_rec.entity_id       := p_inventory_item_id;
    l_xxssys_event_rec.entity_code     := l_item_code;
    l_xxssys_event_rec.last_updated_by := p_last_updated_by;
    l_xxssys_event_rec.created_by      := p_created_by;
    l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			      p_trigger_action || ')';
  
    xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
  
    write_log('Item trigger event inserted');
  
  END insert_product_event;
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
		           p_trigger_action   IN VARCHAR2) IS
    l_error_message    VARCHAR2(500);
    l_inv_item_id      NUMBER;
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    l_category_key     VARCHAR2(240);
    l_item_id          NUMBER;
  BEGIN
    l_inv_item_id := NULL;
  
    --l_category_key > msi.segment1 ||'|'|| category_set_id||'|'|| mic1.category_id category_key,
    SELECT (msi.segment1 || '|' ||
           nvl(p_new_item_cat_rec.category_set_id,
	    p_old_item_cat_rec.category_set_id) || '|' ||
           nvl(p_new_item_cat_rec.category_id,
	    p_old_item_cat_rec.category_id)),
           inventory_item_id
    INTO   l_category_key,
           l_item_id
    FROM   mtl_system_items_b msi
    WHERE  organization_id = xxinv_utils_pkg.get_master_organization_id
    AND    inventory_item_id =
           nvl(p_new_item_cat_rec.inventory_item_id,
	    p_old_item_cat_rec.inventory_item_id);
  
    l_xxssys_event_rec                 := NULL;
    l_xxssys_event_rec.target_name     := g_target_name;
    l_xxssys_event_rec.entity_name     := g_item_cat_entity_name;
    l_xxssys_event_rec.entity_code     := l_category_key;
    l_xxssys_event_rec.entity_id       := l_item_id;
    l_xxssys_event_rec.last_updated_by := nvl(p_new_item_cat_rec.last_updated_by,
			          p_old_item_cat_rec.last_updated_by);
    l_xxssys_event_rec.created_by      := nvl(p_new_item_cat_rec.created_by,
			          p_old_item_cat_rec.created_by);
    l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			      p_trigger_action || ')';
    --l_xxssys_event_rec.active_flag      := 'Y';
    IF p_trigger_action = 'DELETE' THEN
      l_xxssys_event_rec.attribute1 := p_trigger_action;
    END IF;
  
    xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
  
    IF p_trigger_action = 'UPDATE' AND
       nvl(p_old_item_cat_rec.category_id, 0) <>
       nvl(p_new_item_cat_rec.category_id, 0) THEN
      l_category_key := '';
    
      SELECT (msi.segment1 || '|' || p_old_item_cat_rec.category_set_id || '|' ||
	 p_old_item_cat_rec.category_id),
	 msi.inventory_item_id
      INTO   l_category_key,
	 l_item_id
      FROM   mtl_system_items_b msi
      WHERE  organization_id = xxinv_utils_pkg.get_master_organization_id
      AND    inventory_item_id =
	 nvl(p_new_item_cat_rec.inventory_item_id,
	      p_old_item_cat_rec.inventory_item_id);
    
      l_xxssys_event_rec                 := NULL;
      l_xxssys_event_rec.target_name     := g_target_name;
      l_xxssys_event_rec.entity_name     := g_item_cat_entity_name;
      l_xxssys_event_rec.entity_code     := l_category_key;
      l_xxssys_event_rec.entity_id       := l_item_id;
      l_xxssys_event_rec.last_updated_by := nvl(p_new_item_cat_rec.last_updated_by,
				p_old_item_cat_rec.last_updated_by);
      l_xxssys_event_rec.created_by      := nvl(p_new_item_cat_rec.created_by,
				p_old_item_cat_rec.created_by);
      l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			        p_trigger_action || ')';
      l_xxssys_event_rec.attribute1      := 'DELETE';
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      l_error_message := substr(SQLERRM, 1, 500);
      raise_application_error(-20001, l_error_message);
  END item_cat_trg_processor;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function will be used as Rule function for all activated business events
  --          for customer creation or update
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/14/2017  Diptasurjya Chatterjee(TCS)   Initial Build
  -- 1.1  29.3.18     yuval tal   CHG0042560 add site events
  -- 1.2  09/01/2019  Lingaraj    INC0143702 - Business Event - subscription (Handling Site create/update)
  -- --------------------------------------------------------------------------------------------

  FUNCTION customer_event_process(p_subscription_guid IN RAW,
		          p_event             IN OUT NOCOPY wf_event_t)
    RETURN VARCHAR2 IS
    l_parameter_name  VARCHAR2(30);
    l_parameter_value VARCHAR2(4000);
    /*l_next_parameter WF_PARAMETER_T;
    l_parameter_list WF_PARAMETER_LIST_T ;*/
  BEGIN
    g_log_program_unit := 'customer_event_process';
    g_eventname        := p_event.geteventname();
    g_eventaction      := upper(substr(g_eventname,
			   instr(g_eventname, '.', -1) + 1));
    g_user_id          := p_event.getvalueforparameter('USER_ID');
    g_resp_id          := p_event.getvalueforparameter('RESP_ID');
    g_appl_id          := p_event.getvalueforparameter('RESP_APPL_ID');
  
    /* Do not process event for BE fired due to changes by STRATAFORCE user */
    IF is_strataforce_user(g_user_id) = 'Y' THEN
      RETURN 'SUCCESS';
    END IF;
    /* End user ID check */
  
    write_log('Inside event processor : Business Event Triggered');
    write_log(g_eventname);
    /*l_parameter_list     := p_event.getparameterlist();
    
    IF l_parameter_list IS NOT NULL THEN
      FOR i IN l_parameter_list.FIRST .. l_parameter_list.LAST
      LOOP
          write_log('Name:'||l_parameter_list(i).getName() ||';Value:'||l_parameter_list(i).getValue());
      END LOOP;
    
    END IF;*/
  
    IF g_eventname = 'oracle.apps.ar.hz.Person.update' THEN
    
      l_parameter_name  := 'PARTY_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_party(l_parameter_value);
      -- site support CHG0042560
    ELSIF g_eventname IN
          ('oracle.apps.ar.hz.CustAcctSite.create',
           'oracle.apps.ar.hz.CustAcctSite.update') THEN
    
      l_parameter_name  := 'CUST_ACCT_SITE_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_account_site(l_parameter_value);
    
    ELSIF g_eventname IN
          ('oracle.apps.ar.hz.CustAcctSiteUse.create',
           'oracle.apps.ar.hz.CustAcctSiteUse.update') THEN
    
      l_parameter_name  := 'SITE_USE_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_site_use_account(l_parameter_value);
    
      ---
    
    ELSIF g_eventname = 'oracle.apps.ar.hz.Organization.update' THEN
    
      l_parameter_name  := 'PARTY_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_party(l_parameter_value);
    
    ELSIF g_eventname = 'oracle.apps.ar.hz.CustAccount.create' OR
          g_eventname = 'oracle.apps.ar.hz.CustAccount.update' THEN
    
      l_parameter_name  := 'CUST_ACCOUNT_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_account(l_parameter_value);
    
    ELSIF g_eventname = 'oracle.apps.ar.hz.OrgContact.create' OR
          g_eventname = 'oracle.apps.ar.hz.OrgContact.update' THEN
    
      l_parameter_name  := 'ORG_CONTACT_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_org_contact(l_parameter_value);
    ELSIF g_eventname = 'oracle.apps.ar.hz.Location.create' OR
          g_eventname = 'oracle.apps.ar.hz.Location.update' THEN
    
      l_parameter_name  := 'LOCATION_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_location(l_parameter_value);
    ELSIF g_eventname = 'oracle.apps.ar.hz.ContactPoint.create' OR
          g_eventname = 'oracle.apps.ar.hz.ContactPoint.update' THEN
    
      l_parameter_name  := 'CONTACT_POINT_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_contact_point(l_parameter_value);
    ELSIF g_eventname = 'oracle.apps.ar.hz.Relationship.create' OR
          g_eventname = 'oracle.apps.ar.hz.Relationship.update' THEN
    
      l_parameter_name  := 'RELATIONSHIP_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_relationship(l_parameter_value);
    ELSIF g_eventname = 'oracle.apps.ar.hz.CodeAssignment.create' OR
          g_eventname = 'oracle.apps.ar.hz.CodeAssignment.update' THEN
    
      l_parameter_name  := 'CODE_ASSIGNMENT_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_code_assignment(l_parameter_value);
     
    ELSIF g_eventname = 'oracle.apps.ar.hz.CustAccountRole.create' OR
          g_eventname = 'oracle.apps.ar.hz.CustAccountRole.update' THEN
    
      l_parameter_name  := 'CUST_ACCOUNT_ROLE_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);
    
      handle_cust_accnt_role(l_parameter_value);
     --INC0143702 Begin
    ELSIF g_eventname = 'oracle.apps.ar.hz.PartySite.create' OR
          g_eventname = 'oracle.apps.ar.hz.PartySite.update' THEN

      l_parameter_name  := 'PARTY_SITE_ID';
      l_parameter_value := p_event.getvalueforparameter(l_parameter_name);

      handle_party_site(l_parameter_value);
      --INC0143702 End
    END IF;
  
    write_log('Parameter Name  :' || l_parameter_name ||
	  '; Parameter Value :' || l_parameter_value);
  
    RETURN 'SUCCESS';
  
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context(pkg_name  => 'xxssys_strataforce_events_pkg',
	          proc_name => 'customer_event_process',
	          arg1      => ('EventName:' || p_event.geteventname()),
	          arg2      => ('EventKey:' || p_event.geteventkey()),
	          arg3      => ('ParameterName:' || l_parameter_name),
	          arg4      => ('ParameterValue:' || l_parameter_value));
      wf_event.seterrorinfo(p_event, 'ERROR');
    
      RETURN 'ERROR';
    
  END customer_event_process;

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
			 p_trigger_action IN VARCHAR2) IS
    l_compare_rec_status VARCHAR2(1) := 'N';
    --l_is_valid           varchar2(1);
    --l_validation_status  varchar2(1);
    l_error_message VARCHAR2(2000);
  
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    e_validation_exception EXCEPTION;
    l_entity_name  VARCHAR2(50) := '';
    l_create_event VARCHAR2(1) := 'N';
  BEGIN
    g_log_program_unit := lower(p_lookup_type) || '_trg_processor';
    write_log('Inside ' || p_lookup_type || '  trigger processer for ' ||
	  g_target_name);
  
    IF p_trigger_action = 'UPDATE' THEN
      -- Compare old and new records to check for applicable changes
      l_compare_rec_status := compare_old_new_flv(p_old_flv_rec,
				  p_new_flv_rec,
				  p_lookup_type);
    END IF;
  
    --N - Changes in Old and New Rec
    --Y - Old and New Records Match
  
    IF l_compare_rec_status = 'N' THEN
      --Prepare Event Record
    
      --Select the Entity Name
      IF p_lookup_type = 'FREIGHT_TERMS' THEN
        l_entity_name := g_freight_term_entity_name;
      ELSIF p_lookup_type = 'FOB' THEN
        l_entity_name := g_fob_entity_name;
      ELSE
        l_entity_name := '';
      END IF;
    
      l_xxssys_event_rec.target_name := g_target_name;
      l_xxssys_event_rec.entity_name := l_entity_name;
    
      IF p_trigger_action = 'DELETE' OR
         nvl(p_new_flv_rec.enabled_flag, 'N') = 'N' THEN
        l_xxssys_event_rec.attribute1 := 'DELETE'; --For DML
        -- Check the Code is sync to SFDC , any success event is available .. They Send DELETE
      END IF;
      --l_xxssys_event_rec.active_flag      := 'Y';
    
      l_xxssys_event_rec.entity_code     := nvl(p_new_flv_rec.lookup_code,
				p_old_flv_rec.lookup_code);
      l_xxssys_event_rec.last_updated_by := nvl(p_new_flv_rec.last_updated_by,
				p_old_flv_rec.last_updated_by);
      l_xxssys_event_rec.created_by      := nvl(p_new_flv_rec.created_by,
				p_old_flv_rec.created_by);
      l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			        p_trigger_action || ')';
    
      IF p_lookup_type = 'FREIGHT_TERMS'
      --And p_trigger_action in ('INSERT' ,'UPDATE' )
       THEN
        l_create_event := 'Y';
      ELSIF p_lookup_type = 'FOB'
      --And p_trigger_action in ('INSERT' ,'UPDATE' )
       THEN
        l_create_event := 'Y';
      END IF;
    
      IF l_create_event = 'Y' THEN
        xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
        write_log('trigger event inserted for Lookup Type :' ||
	      p_lookup_type);
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_error_message := substr(SQLERRM, 1, 500);
      raise_application_error(-20001, l_error_message);
  END flv_common_trg_processor;

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
			   p_trigger_action IN VARCHAR2) IS
    CURSOR c_price_entry(p_old_item         NUMBER,
		 p_new_item         NUMBER,
		 p_old_related_item NUMBER,
		 p_new_related_item NUMBER) IS
      SELECT qlha.currency_code,
	 qll.start_date_active,
	 qll.end_date_active,
	 qpa.list_line_id,
	 qlha.list_header_id,
	 msib.segment1 item_code,
	 msib.inventory_item_id
      FROM   qp_list_headers_all_b qlha,
	 qp_list_lines         qll,
	 qp_pricing_attributes qpa,
	 mtl_system_items_b    msib
      WHERE  qlha.list_header_id = qpa.list_header_id
      AND    nvl(qlha.attribute6, 'N') = 'Y' -- sync to SF Flag should be Yes
      AND    nvl(qlha.active_flag, 'N') = 'Y' -- Price List Header Should Be ative
      AND    qlha.list_type_code = 'PRL'
      AND    qll.list_header_id = qlha.list_header_id
      AND    qll.list_line_id = qpa.list_line_id
      AND    msib.organization_id = 91
      AND    to_char(msib.inventory_item_id) = qpa.product_attr_value
      AND    qpa.product_attr_value <> 'ALL'
      AND    qpa.product_attribute_context = 'ITEM'
      AND    nvl(qpa.pricing_attribute_context, 'x') = 'x'
      AND    nvl(qlha.attribute11, 'x') <> 'x'
      AND    trunc(SYSDATE) BETWEEN
	 nvl(qlha.start_date_active, (SYSDATE - 1)) AND
	 nvl(qlha.end_date_active, (SYSDATE + 1))
      AND    trunc(SYSDATE) BETWEEN
	 nvl(qll.start_date_active, (SYSDATE - 1)) AND
	 nvl(qll.end_date_active, (SYSDATE + 1))
      AND    msib.inventory_item_id IN
	 (p_old_item,
	   p_new_item,
	   p_old_related_item,
	   p_new_related_item);
  BEGIN
    --Searhc for all the available (sync to SF = Y) prices for both
    --Item and Related Item
    FOR rec IN c_price_entry(nvl(p_old_rec.inventory_item_id, 0),
		     nvl(p_new_rec.inventory_item_id, 0),
		     nvl(p_old_rec.related_item_id, 0),
		     nvl(p_new_rec.related_item_id, 0)) LOOP
      populate_priceentry_events(p_list_header_id => rec.list_header_id,
		         p_list_line_id   => rec.list_line_id,
		         p_currency_code  => rec.currency_code,
		         p_trigger_name   => p_trigger_name,
		         p_trigger_action => 'UPDATE');
    END LOOP;
  END related_item_trg_processor;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041808 - Pricelist Line Interface
  -- Task   :
  -- Purpose:
  --
  -- --------------------------------------------------------------------------------------------
  -- Usage: Called from Trigger :  No
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date           Name                               Description
  -- 1.0  06-Dec-2017    Lingaraj Sarangi                   CHG0041808[CTASK0036370] - Initial Build
  -- ----------------------------------------------------------------------------------------
  PROCEDURE generate_related_price_events(p_list_header_id   NUMBER,
			      p_inv_item_id      NUMBER,
			      p_inv_item_code    VARCHAR2,
			      p_price_start_date DATE DEFAULT trunc(SYSDATE), --Start Date of the Price if Parent price Start Date is in Future
			      p_trigger_name     VARCHAR2,
			      p_trigger_action   VARCHAR2,
			      p_created_by       NUMBER,
			      p_last_updated_by  NUMBER) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  
    CURSOR cur_related_price IS
      SELECT qlha.currency_code,
	 qll.start_date_active,
	 qll.end_date_active,
	 qpa.list_line_id,
	 qlha.list_header_id,
	 msib.segment1 item_code,
	 msib.inventory_item_id
      FROM   qp_list_headers_all_b qlha,
	 qp_list_lines         qll,
	 qp_pricing_attributes qpa,
	 mtl_system_items_b    msib
      WHERE  qlha.list_header_id = qpa.list_header_id
      AND    nvl(qlha.attribute6, 'N') = 'Y' -- sync to SF Flag should be Yes
      AND    nvl(qlha.active_flag, 'N') = 'Y' -- Price List Header Should Be ative
      AND    qlha.list_type_code = 'PRL'
      AND    nvl(qlha.attribute11, 'X') = to_char(p_list_header_id) -- Direct Price List
	
      AND    trunc(SYSDATE) BETWEEN
	 nvl(qlha.start_date_active, (SYSDATE - 1)) AND
	 nvl(qlha.end_date_active, (SYSDATE + 1))
      AND    trunc(SYSDATE) BETWEEN
	 nvl(qll.start_date_active, (SYSDATE - 1)) AND
	 nvl(qll.end_date_active, (SYSDATE + 1))
      AND    qpa.product_attribute_context = 'ITEM'
      AND    nvl(qpa.pricing_attribute_context, 'x') = 'x'
      AND    qpa.product_attr_value <> 'ALL'
      AND    qpa.product_attr_value =
	 nvl(to_char(p_inv_item_id), qpa.product_attr_value)
      AND    qll.list_header_id = qlha.list_header_id
      AND    qll.list_line_id = qpa.list_line_id
      AND    msib.organization_id = 91
      AND    msib.inventory_item_id = to_number(qpa.product_attr_value)
      
      UNION ALL
      --CHG0041808 [CTASK0036370]
      --Below Query will fetch the Related Items (Service) available for Item
      --Below Query will execute Only if Item Id Provided
      SELECT qlha.currency_code,
	 qll.start_date_active,
	 qll.end_date_active,
	 qpa.list_line_id,
	 qlha.list_header_id,
	 msib.segment1 item_code,
	 msib.inventory_item_id
      FROM   qp_list_headers_all_b qlha,
	 qp_list_lines         qll,
	 qp_pricing_attributes qpa,
	 mtl_system_items_b    msib,
	 mtl_related_items     mri
      WHERE  qlha.list_header_id = qpa.list_header_id
      AND    nvl(qlha.attribute6, 'N') = 'Y' -- sync to SF Flag should be Yes
      AND    nvl(qlha.active_flag, 'N') = 'Y' -- Price List Header Should Be ative
      AND    qlha.list_type_code = 'PRL'
      AND    nvl(qlha.attribute11, 'X') = to_char(p_list_header_id) -- Direct Price List
      AND    qll.list_header_id = qlha.list_header_id
      AND    qll.list_line_id = qpa.list_line_id
      AND    msib.organization_id = 91
      AND    msib.inventory_item_id = to_number(qpa.product_attr_value)
      AND    qpa.product_attribute_context = 'ITEM'
      AND    nvl(qpa.pricing_attribute_context, 'x') = 'x'
      AND    qpa.product_attr_value <> 'ALL'
      AND    mri.relationship_type_id = 5 -- Service Type
      AND    mri.inventory_item_id = to_number(qpa.product_attr_value)
      AND    mri.inventory_item_id = msib.inventory_item_id
      AND    mri.related_item_id = p_inv_item_id
      AND    p_inv_item_id IS NOT NULL
      AND    trunc(SYSDATE) BETWEEN
	 nvl(qlha.start_date_active, (SYSDATE - 1)) AND
	 nvl(qlha.end_date_active, (SYSDATE + 1))
      AND    trunc(SYSDATE) BETWEEN
	 nvl(qll.start_date_active, (SYSDATE - 1)) AND
	 nvl(qll.end_date_active, (SYSDATE + 1));
  
    l_key              VARCHAR2(240);
    l_xxssys_event_rec xxssys_events%ROWTYPE;
  
  BEGIN
    FOR rec IN cur_related_price LOOP
      l_key := rec.list_header_id || '|' || rec.item_code || '|' ||
	   rec.currency_code;
    
      l_xxssys_event_rec                 := NULL;
      l_xxssys_event_rec.entity_name     := g_pricelist_line_entity_name; --'PRICE_ENTRY';
      l_xxssys_event_rec.entity_id       := rec.list_header_id;
      l_xxssys_event_rec.entity_code     := l_key;
      l_xxssys_event_rec.target_name     := g_target_name;
      l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			        p_trigger_action || ')';
      l_xxssys_event_rec.created_by      := p_created_by;
      l_xxssys_event_rec.last_updated_by := p_last_updated_by;
    
      l_xxssys_event_rec.attribute1 := rec.inventory_item_id;
      l_xxssys_event_rec.attribute2 := to_char((CASE
				 WHEN p_price_start_date >
				      nvl(rec.start_date_active,
				          trunc(SYSDATE)) THEN
				  p_price_start_date
				 ELSE
				  nvl(rec.start_date_active,
				      trunc(SYSDATE))
			           END),
			           'DD-MON-YYYY');
      l_xxssys_event_rec.attribute3 := to_char(nvl(rec.end_date_active,
				   (SYSDATE + 365)),
			           'DD-MON-YYYY');
      l_xxssys_event_rec.attribute4 := rec.item_code;
      l_xxssys_event_rec.attribute5 := rec.currency_code;
      l_xxssys_event_rec.attribute6 := rec.list_line_id;
    
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
    END LOOP;
    COMMIT;
  END generate_related_price_events;
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
  -- 1.0  06-Dec-2017    Lingaraj Sarangi                   CHG0041808[CTASK0036370] - Initial Build
  -- ----------------------------------------------------------------------------------------
  PROCEDURE populate_priceentry_events(p_list_header_id IN NUMBER,
			   p_list_line_id   IN NUMBER DEFAULT NULL,
			   p_currency_code  IN VARCHAR2,
			   p_trigger_name   IN VARCHAR2,
			   p_trigger_action IN VARCHAR2) IS
    CURSOR priceentry_c IS
      SELECT qll.list_line_id,
	 qll.operand,
	 qll.start_date_active,
	 qll.end_date_active,
	 qll.created_by,
	 qll.last_updated_by,
	 msib.inventory_item_id,
	 msib.segment1          item_code,
	 p_currency_code        currency_code
      FROM   qp_list_lines         qll,
	 qp_pricing_attributes qpa,
	 mtl_system_items_b    msib
      WHERE  qll.list_header_id = p_list_header_id
      AND    qll.list_line_id = qpa.list_line_id
      AND    qll.list_header_id = qpa.list_header_id
      AND    qpa.product_attribute_context = 'ITEM'
      AND    qll.list_line_id = nvl(p_list_line_id, qll.list_line_id)
      AND    qpa.product_attr_value <> 'ALL'
      AND    msib.inventory_item_id = to_number(qpa.product_attr_value)
      AND    msib.organization_id = 91
      AND    trunc(SYSDATE) BETWEEN
	 nvl(qll.start_date_active, (SYSDATE - 1)) AND
	 nvl(qll.end_date_active, (SYSDATE + 1))
      AND    nvl(qpa.pricing_attribute_context, 'x') = 'x';
  
    l_xxssys_event_rec  xxssys_events%ROWTYPE;
    l_currency_code     VARCHAR2(10);
    l_itemcode          VARCHAR2(240);
    l_inventory_item_id NUMBER;
    l_price_info_avail  BOOLEAN;
    l_key               VARCHAR2(240);
    l_rec_updated       NUMBER;
  BEGIN
  
    FOR rec IN priceentry_c LOOP
      l_key                              := p_list_header_id || '|' ||
			        rec.item_code || '|' ||
			        rec.currency_code;
      l_xxssys_event_rec                 := NULL;
      l_xxssys_event_rec.entity_name     := g_pricelist_line_entity_name;
      l_xxssys_event_rec.entity_id       := p_list_header_id;
      l_xxssys_event_rec.entity_code     := l_key;
      l_xxssys_event_rec.target_name     := g_target_name;
      l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			        p_trigger_action || ')';
      l_xxssys_event_rec.created_by      := rec.created_by;
      l_xxssys_event_rec.last_updated_by := rec.last_updated_by;
      l_xxssys_event_rec.attribute1      := rec.inventory_item_id;
      l_xxssys_event_rec.attribute2      := to_char(nvl(rec.start_date_active,
				        SYSDATE),
				    'DD-MON-YYYY');
      l_xxssys_event_rec.attribute3      := to_char(nvl(rec.end_date_active,
				        (SYSDATE + 365)),
				    'DD-MON-YYYY');
      l_xxssys_event_rec.attribute4      := rec.item_code;
      l_xxssys_event_rec.attribute5      := rec.currency_code;
      l_xxssys_event_rec.attribute6      := rec.list_line_id;
    
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
    
      IF p_trigger_action = 'INSERT' AND
         nvl(rec.end_date_active, trunc(SYSDATE)) > trunc(SYSDATE) THEN
        l_xxssys_event_rec                 := NULL;
        l_xxssys_event_rec.entity_name     := g_pricelist_line_entity_name;
        l_xxssys_event_rec.entity_id       := p_list_header_id;
        l_xxssys_event_rec.entity_code     := l_key;
        l_xxssys_event_rec.target_name     := g_target_name;
        l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			          p_trigger_action || ')';
        l_xxssys_event_rec.created_by      := rec.created_by;
        l_xxssys_event_rec.last_updated_by := rec.last_updated_by;
        l_xxssys_event_rec.attribute1      := rec.inventory_item_id;
        l_xxssys_event_rec.attribute2      := to_char(rec.end_date_active,
				      'DD-MON-YYYY');
        l_xxssys_event_rec.attribute3      := to_char(rec.end_date_active,
				      'DD-MON-YYYY');
        l_xxssys_event_rec.attribute4      := rec.item_code;
        l_xxssys_event_rec.attribute5      := rec.currency_code;
        l_xxssys_event_rec.attribute6      := rec.list_line_id;
      
        xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
      
      END IF;
    
    END LOOP;
  END populate_priceentry_events;
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
			p_trigger_action IN VARCHAR2) IS
  
    l_is_record_changed VARCHAR2(1) := 'N';
    l_error_message     VARCHAR2(2000);
    l_xxssys_event_rec  xxssys_events%ROWTYPE;
    e_validation_exception EXCEPTION;
    l_entity_name        VARCHAR2(50) := '';
    l_create_event       VARCHAR2(1) := 'N';
    l_pricebook_action   VARCHAR2(10) := '#';
    l_new_valid_sf_price VARCHAR2(1) := 'N';
    l_old_valid_sf_price VARCHAR2(1) := 'N';
    l_refresh_pl_lines   VARCHAR2(1) := 'N';
  BEGIN
    g_log_program_unit := 'pricebook_trg_processor';
  
    IF p_trigger_action = 'UPDATE' THEN
      -- Compare old and new records to check for applicable changes
      l_is_record_changed := compare_old_new_pricebook_b(p_old_pl_rec,
				         p_new_pl_rec);
      --N - Changes in Old and New Rec
      --Y - Old and New Records Match
      --END IF;
    
      IF l_is_record_changed = 'Y' AND (nvl(p_old_pl_rec.attribute11, '-1') !=
         nvl(p_new_pl_rec.attribute11, '-1')) THEN
        l_refresh_pl_lines := 'Y';
      END IF;
    
      --In Case of Update Trigger
      --IF p_trigger_action = 'UPDATE' THEN
      --Is OLD Record was valid for SF
      IF p_old_pl_rec.active_flag = 'Y' AND p_old_pl_rec.attribute6 = 'Y' THEN
        l_old_valid_sf_price := 'Y';
      ELSE
        l_old_valid_sf_price := 'N';
      END IF;
    
      --Is NEW Record was valid for SF
      IF p_new_pl_rec.active_flag = 'Y' AND p_new_pl_rec.attribute6 = 'Y' THEN
        l_new_valid_sf_price := 'Y';
      ELSE
        l_new_valid_sf_price := 'N';
      END IF;
      --
    END IF;
  
    IF p_trigger_action = 'INSERT' OR l_is_record_changed = 'Y' THEN
      -- Record Changed
      --Prepare Event Record
      l_xxssys_event_rec             := NULL;
      l_xxssys_event_rec.target_name := g_target_name;
      l_xxssys_event_rec.entity_name := g_pricelist_entity_name;
    
      l_xxssys_event_rec.entity_id       := nvl(p_new_pl_rec.list_header_id,
				p_old_pl_rec.list_header_id);
      l_xxssys_event_rec.last_updated_by := nvl(p_new_pl_rec.last_updated_by,
				p_old_pl_rec.last_updated_by);
      l_xxssys_event_rec.created_by      := nvl(p_new_pl_rec.created_by,
				p_old_pl_rec.created_by);
      l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			        p_trigger_action || ')';
    
      -- If the Price Book was Active for SF and Now it is not Then Inactivate it in SF
      /* -- Commented on 3rd July 18
      IF l_old_valid_sf_price = 'Y' AND l_new_valid_sf_price = 'N' THEN
        l_xxssys_event_rec.attribute1 := 'DELETE';
        l_trigger_action              := 'DELETE';
      ELSE
        l_trigger_action := p_trigger_action;
      END IF;*/
    
      --Insert PRICE BOOK Event
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
    
      --Populate Price ENTRY EVENTS
      IF (l_old_valid_sf_price = 'N' AND l_new_valid_sf_price = 'Y') OR --Sync to SF
         (l_old_valid_sf_price = 'Y' AND l_new_valid_sf_price = 'N') OR -- Delete from SF
         l_refresh_pl_lines = 'Y' THEN
      
        populate_priceentry_events(p_list_header_id => p_new_pl_rec.list_header_id,
		           p_trigger_name   => p_trigger_name,
		           p_trigger_action => 'INSERT', --l_trigger_action,
		           p_currency_code  => p_new_pl_rec.currency_code);
      
        generate_related_price_events(p_list_header_id  => p_new_pl_rec.list_header_id,
			  p_inv_item_id     => NULL,
			  p_inv_item_code   => NULL,
			  p_trigger_name    => p_trigger_name,
			  p_trigger_action  => 'INSERT',
			  p_created_by      => nvl(p_new_pl_rec.created_by,
					   p_old_pl_rec.created_by),
			  p_last_updated_by => nvl(p_new_pl_rec.last_updated_by,
					   p_old_pl_rec.last_updated_by));
      
      END IF;
    
    END IF;
  
  END pricebook_trg_processor;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function handles PROICE BOOK insert/update trigger to generate XXSSYS_EVENTS record
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
			   p_trigger_action  VARCHAR2) IS
    l_any_new_event    VARCHAR2(1);
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    l_error_message    VARCHAR2(500);
  BEGIN
    -- Create an Event for the PRICE BOOK
    l_xxssys_event_rec             := NULL;
    l_xxssys_event_rec.target_name := g_target_name;
    l_xxssys_event_rec.entity_name := g_pricelist_entity_name;
  
    l_xxssys_event_rec.entity_id       := p_list_header_id;
    l_xxssys_event_rec.last_updated_by := p_created_by;
    l_xxssys_event_rec.created_by      := p_last_updated_by;
    l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			      p_trigger_action || ')';
  
    --Insert PRICE BOOK Event
    xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
  
  END pricebook_tl_trg_processor;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function handles PROICE Line insert/update trigger to generate XXSSYS_EVENTS record
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
			p_trigger_action IN VARCHAR2) IS
    l_xxssys_event_rec  xxssys_events%ROWTYPE;
    l_error_message     VARCHAR2(500);
    l_currency_code     VARCHAR2(10);
    l_itemcode          VARCHAR2(240);
    l_item_id           NUMBER;
    l_inventory_item_id NUMBER;
    l_list_header_id    NUMBER := nvl(p_new_pl_rec.list_header_id,
			  p_old_pl_rec.list_header_id);
    l_list_line_id      NUMBER := nvl(p_new_pl_rec.list_line_id,
			  p_old_pl_rec.list_line_id);
    l_created_by        NUMBER := nvl(p_new_pl_rec.created_by,
			  p_old_pl_rec.created_by);
    l_last_updated_by   NUMBER := nvl(p_new_pl_rec.last_updated_by,
			  p_old_pl_rec.last_updated_by);
  
    l_old_from_date DATE := p_old_pl_rec.start_date_active;
    l_new_from_date DATE := p_new_pl_rec.start_date_active;
  
    l_old_to_date DATE := p_old_pl_rec.end_date_active;
    l_new_to_date DATE := p_new_pl_rec.end_date_active;
  
    --l_delete_pl_event  VARCHAR2(1) := 'N';
    --l_price_info_avail BOOLEAN;
    l_key     VARCHAR2(240);
    l_rec_cnt NUMBER;
  BEGIN
  
    get_price_line_item_info(p_list_header_id => l_list_header_id,
		     p_list_line_id   => l_list_line_id,
		     x_item_id        => l_item_id,
		     x_item_code      => l_itemcode,
		     x_currency_code  => l_currency_code);
  
    l_key := l_list_header_id || '|' || l_itemcode || '|' ||
	 l_currency_code;
  
    l_xxssys_event_rec                 := NULL;
    l_xxssys_event_rec.entity_name     := g_pricelist_line_entity_name; --'PRICE_ENTRY';
    l_xxssys_event_rec.entity_id       := l_list_header_id;
    l_xxssys_event_rec.entity_code     := l_key;
    l_xxssys_event_rec.target_name     := g_target_name;
    l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			      p_trigger_action || ')';
    l_xxssys_event_rec.created_by      := l_created_by;
    l_xxssys_event_rec.last_updated_by := l_last_updated_by;
    l_xxssys_event_rec.attribute1      := l_item_id;
    l_xxssys_event_rec.attribute2      := to_char(coalesce(l_new_from_date,
				           l_new_to_date - 1,
				           trunc(SYSDATE)),
				  'DD-MON-YYYY');
    l_xxssys_event_rec.attribute3      := to_char(nvl(l_new_to_date,
				      trunc(SYSDATE) + 365),
				  'DD-MON-YYYY');
    l_xxssys_event_rec.attribute4      := l_itemcode;
    l_xxssys_event_rec.attribute5      := l_currency_code;
    l_xxssys_event_rec.attribute6      := l_list_line_id;
  
    xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
  
    --Create a End Dated Event
    IF l_new_to_date IS NOT NULL AND l_new_to_date >= trunc(SYSDATE) THEN
      -- yuval change to >=
    
      l_xxssys_event_rec                 := NULL;
      l_xxssys_event_rec.entity_name     := g_pricelist_line_entity_name; --'PRICE_ENTRY';
      l_xxssys_event_rec.entity_id       := l_list_header_id;
      l_xxssys_event_rec.entity_code     := l_key;
      l_xxssys_event_rec.target_name     := g_target_name;
      l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			        p_trigger_action || ')';
      l_xxssys_event_rec.created_by      := l_created_by;
      l_xxssys_event_rec.last_updated_by := l_last_updated_by;
      l_xxssys_event_rec.attribute1      := l_item_id;
      l_xxssys_event_rec.attribute2      := to_char(l_new_to_date + 1,
				    'DD-MON-YYYY'); -- yuval event will be process day after
      l_xxssys_event_rec.attribute3      := to_char(l_new_to_date + 1,
				    'DD-MON-YYYY');
      l_xxssys_event_rec.attribute4      := l_itemcode;
      l_xxssys_event_rec.attribute5      := l_currency_code;
      l_xxssys_event_rec.attribute6      := l_list_line_id;
    
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
    
    END IF;
  
    generate_related_price_events(p_list_header_id   => l_list_header_id,
		          p_inv_item_id      => l_item_id,
		          p_inv_item_code    => l_itemcode,
		          p_price_start_date => trunc(coalesce(l_new_from_date,
					           l_new_to_date - 1,
					           SYSDATE)),
		          p_trigger_name     => p_trigger_name,
		          p_trigger_action   => p_trigger_action,
		          p_created_by       => l_created_by,
		          p_last_updated_by  => l_last_updated_by);
  
  END priceline_trg_processor;
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
			 p_trigger_action  VARCHAR2) IS
  
    l_key               VARCHAR2(240);
    l_xxssys_event_rec  xxssys_events%ROWTYPE;
    l_price_info_avail  BOOLEAN;
    l_currency_code     VARCHAR2(10);
    l_itemcode          VARCHAR2(240);
    l_inventory_item_id NUMBER;
    l_end_date_active   DATE;
    l_start_date_active DATE;
  BEGIN
  
    l_currency_code := get_price_list_currency(p_list_header_id);
    l_itemcode      := xxinv_utils_pkg.get_item_segment(p_inv_item_id, 91);
  
    l_key := p_list_header_id || '|' || l_itemcode || '|' ||
	 l_currency_code;
  
    BEGIN
      SELECT start_date_active,
	 end_date_active
      INTO   l_start_date_active,
	 l_end_date_active
      FROM   qp_list_lines
      WHERE  list_line_id = p_list_line_id;
    
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;
  
    --Start - Section to Insert Event for Both INSERT or DELETE
    l_xxssys_event_rec                 := NULL;
    l_xxssys_event_rec.entity_name     := g_pricelist_line_entity_name; --'PRICE_ENTRY';
    l_xxssys_event_rec.entity_id       := p_list_header_id;
    l_xxssys_event_rec.entity_code     := l_key;
    l_xxssys_event_rec.target_name     := g_target_name;
    l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			      p_trigger_action || ')';
    l_xxssys_event_rec.created_by      := p_created_by;
    l_xxssys_event_rec.last_updated_by := p_last_updated_by;
    l_xxssys_event_rec.attribute1      := p_inv_item_id;
  
    IF p_trigger_action = 'INSERT' THEN
      l_xxssys_event_rec.attribute2 := to_char(nvl(l_start_date_active,
				   SYSDATE),
			           'DD-MON-YYYY');
      l_xxssys_event_rec.attribute3 := to_char(nvl(l_end_date_active,
				   SYSDATE + 365),
			           'DD-MON-YYYY');
    ELSIF p_trigger_action = 'DELETE' THEN
      l_xxssys_event_rec.attribute2 := to_char(SYSDATE, 'DD-MON-YYYY');
      l_xxssys_event_rec.attribute3 := to_char(SYSDATE, 'DD-MON-YYYY');
    END IF;
  
    l_xxssys_event_rec.attribute4 := l_itemcode;
    l_xxssys_event_rec.attribute5 := l_currency_code;
    l_xxssys_event_rec.attribute6 := p_list_line_id;
  
    xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
    --END ----------------------------------------------------------
  
    --Create DELETE Event , If the END DATE available for the Price Line
    IF p_trigger_action = 'INSERT' AND
       nvl(l_end_date_active, trunc(SYSDATE)) > trunc(SYSDATE) THEN
    
      l_xxssys_event_rec                 := NULL;
      l_xxssys_event_rec.entity_name     := g_pricelist_line_entity_name; --'PRICE_ENTRY';
      l_xxssys_event_rec.entity_id       := p_list_header_id;
      l_xxssys_event_rec.entity_code     := l_key;
      l_xxssys_event_rec.target_name     := g_target_name;
      l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			        p_trigger_action || ')';
      l_xxssys_event_rec.created_by      := p_created_by;
      l_xxssys_event_rec.last_updated_by := p_last_updated_by;
      l_xxssys_event_rec.attribute1      := p_inv_item_id;
      l_xxssys_event_rec.attribute2      := to_char(l_end_date_active,
				    'DD-MON-YYYY');
      l_xxssys_event_rec.attribute3      := to_char(l_end_date_active,
				    'DD-MON-YYYY');
      l_xxssys_event_rec.attribute4      := l_itemcode;
      l_xxssys_event_rec.attribute5      := l_currency_code;
      l_xxssys_event_rec.attribute6      := p_list_line_id;
    
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
    
    END IF;
  
    generate_related_price_events(p_list_header_id   => p_list_header_id,
		          p_inv_item_id      => p_inv_item_id,
		          p_inv_item_code    => l_itemcode,
		          p_price_start_date => trunc(nvl(l_start_date_active,
					      SYSDATE)),
		          p_trigger_name     => p_trigger_name,
		          p_trigger_action   => p_trigger_action,
		          p_created_by       => p_created_by,
		          p_last_updated_by  => p_last_updated_by);
  
  END price_attr_trg_processor;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function handles AR Payment Term insert/update trigger to generate XXSSYS_EVENTS record
  --
  -- --------------------------------------------------------------------------------------------
  -- Usage: Trigger XXRA_TERMS_AIUR_TRG1
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date           Name                               Description
  -- 1.0  06-Dec-2017    Lingaraj Sarangi                   Initial Build
  -- 1.1  22-Jun-2018    Lingaraj Sarangi                   CHG0041763 - CTASK0037212
  -- ----------------------------------------------------------------------------------------
  PROCEDURE payterm_trg_processor(p_term_id         IN NUMBER,
		          p_term_name       IN VARCHAR2 DEFAULT NULL,
		          p_start_date      IN DATE,
		          p_end_date        IN DATE,
		          p_created_by      IN NUMBER,
		          p_last_updated_by IN NUMBER,
		          p_trigger_name    IN VARCHAR2,
		          p_trigger_action  IN VARCHAR2) IS
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    l_error_message    VARCHAR2(500);
    l_ar_term_name     VARCHAR2(240) := substr(p_term_name, 1, 50);
    l_start_date       DATE := p_start_date; --CTASK0037212
    l_end_date         DATE := p_end_date; --CTASK0037212
  BEGIN
    IF p_trigger_name = 'XXRA_TERMS_AIUR_TRG1' THEN
      BEGIN
        SELECT substr(NAME, 1, 50)
        INTO   l_ar_term_name
        FROM   ra_terms_tl t
        WHERE  t.term_id = p_term_id
        AND    t.language = 'US';
      
      EXCEPTION
        WHEN no_data_found THEN
          l_ar_term_name := '';
      END;
    ELSE
      --CTASK0037212#If the Procedure Called from ra_terms_tl Trigger
      BEGIN
        SELECT start_date_active,
	   end_date_active
        INTO   l_start_date,
	   l_end_date
        FROM   ra_terms_b t
        WHERE  t.term_id = p_term_id;
      EXCEPTION
        WHEN no_data_found THEN
          l_start_date := SYSDATE;
          l_end_date   := NULL;
      END;
    END IF;
  
    l_xxssys_event_rec                 := NULL;
    l_xxssys_event_rec.entity_name     := g_payment_term_entity_name;
    l_xxssys_event_rec.entity_id       := p_term_id;
    l_xxssys_event_rec.entity_code     := l_ar_term_name;
    l_xxssys_event_rec.target_name     := g_target_name;
    l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			      p_trigger_action || ')';
    l_xxssys_event_rec.created_by      := p_created_by;
    l_xxssys_event_rec.last_updated_by := p_last_updated_by;
    l_xxssys_event_rec.attribute1      := to_char(l_start_date,
				  'DD-MON-YYYY');
  
    --Insert PRICE ENTRY Event
    xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
  
    IF l_end_date IS NOT NULL THEN
      l_xxssys_event_rec.attribute1 := NULL;
      l_xxssys_event_rec.attribute2 := to_char(l_end_date, 'DD-MON-YYYY');
    
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      l_error_message := substr(SQLERRM, 1, 500);
      raise_application_error(-20001, l_error_message);
  END payterm_trg_processor;

  --------------------------------------------------------------------
  --  name:   handle_order_header_event
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   25.12.17
  --------------------------------------------------------------------
  --  purpose :
  --
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  ---  ----------  ---------------  ------------------------------
  --  1.0  25.12.17    yuval tal        iCHG0042041 nitial build
  --  1.1  16.07.18    Lingaraj         CTASK0037599 - Add Order number to Entity Code
  --  2.3  10/12/2018  Roman W.         CHG0044657 - Strataforce  events  missing entity_code value wit...  
  --------------------------------------------------------------------
  PROCEDURE handle_order_header_event(errbuf        OUT VARCHAR2,
			  retcode       OUT VARCHAR2,
			  p_header_id   NUMBER,
			  p_event_name  VARCHAR2,
			  p_entity_code VARCHAR2 DEFAULT NULL -- CHG0044657
			  ) IS
  
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    l_fsl_order_source VARCHAR2(30);
    l_fsl_attribute2   VARCHAR2(30);
    CURSOR c_ord IS
      SELECT *
      FROM   oe_order_headers_all t
      WHERE  t.header_id = p_header_id;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
  
    FOR i IN c_ord LOOP
      --
      l_fsl_order_source := get_order_source_name(i.order_source_id);
    
      IF nvl(l_fsl_order_source, '-1') = 'SFDC PR FSL' THEN
        l_fsl_attribute2 := 'PRODUCT_REQUEST_HEADER';
      ELSIF nvl(l_fsl_order_source, '-1') = 'SFDC QUOTE FSL' THEN
        l_fsl_attribute2 := 'QUOTE_HEADER';
      END IF;
    
      --
      IF is_valid_order_type(i.order_type_id) = 'Y' AND
         i.flow_status_code != 'DRAFT' AND i.transaction_phase_code != 'N' -- This is not a Quote
       THEN
        -- Create an Event for the Sales Order Header
        l_xxssys_event_rec             := NULL;
        l_xxssys_event_rec.target_name := g_target_name;
        l_xxssys_event_rec.entity_name := 'SO_HEADER';
        l_xxssys_event_rec.entity_id   := p_header_id;
        l_xxssys_event_rec.event_name  := p_event_name;
        l_xxssys_event_rec.entity_code := i.order_number; --CTASK0037599
        --Insert SO HEADER Event
        xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
      END IF;
    
      --Added for CHG0042734 -Create Order interface - Enable Strataforce to create orders in Oracle
      IF i.flow_status_code != 'DRAFT' AND i.transaction_phase_code != 'N' -- This is not a Quote
         AND l_fsl_order_source IN ('SFDC PR FSL', 'SFDC QUOTE FSL') THEN
        -- Create an Event for the Sales Order Header
        l_xxssys_event_rec             := NULL;
        l_xxssys_event_rec.target_name := g_target_name;
        l_xxssys_event_rec.entity_name := 'SO_HEADER_FSL';
        l_xxssys_event_rec.entity_id   := p_header_id;
        l_xxssys_event_rec.event_name  := p_event_name;
        l_xxssys_event_rec.attribute2  := l_fsl_attribute2;
        l_xxssys_event_rec.entity_code := i.order_number; --CTASK0037599
        --Insert SO HEADER Event
        xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
      END IF;
    
      COMMIT;
    END LOOP;
  
    IF p_event_name = 'SO_HEADER_DELETE' THEN
      -- Create an Event for the Sales Order Header
      l_xxssys_event_rec             := NULL;
      l_xxssys_event_rec.target_name := g_target_name;
      l_xxssys_event_rec.entity_name := 'SO_HEADER';
      l_xxssys_event_rec.entity_id   := p_header_id;
      l_xxssys_event_rec.event_name  := p_event_name;
      l_xxssys_event_rec.attribute1  := 'DELETE';
      l_xxssys_event_rec.entity_code := p_entity_code; -- CHG0044657
      --Insert SO HEADER Event
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
    
      --Added for CHG0042734 for FSL Order Source comment by yuval 
      --  l_xxssys_event_rec.entity_name := 'SO_HEADER_FSL';
      --  l_xxssys_event_rec.attribute2  := l_fsl_attribute2;
      --  xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
    
      COMMIT;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'handle_order_header_event - p_header_id=' || p_header_id || ' ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 2;
  END handle_order_header_event;

  --------------------------------------------------------------------
  --  name:    handle_om_hold_event
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   03/03/2014
  --------------------------------------------------------------------
  --  purpose :
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  25.12.17    yuval tal        CHG0042041/CHG0042043 initial build
  --------------------------------------------------------------------

  PROCEDURE handle_om_hold_event(errbuf          OUT VARCHAR2,
		         retcode         OUT VARCHAR2,
		         p_order_hold_id NUMBER,
		         p_event_name    VARCHAR2) IS
  
    CURSOR c_ord IS
      SELECT *
      FROM   oe_order_holds_all l
      WHERE  l.order_hold_id = p_order_hold_id;
  
  BEGIN
    errbuf  := NULL;
    retcode := 0;
  
    FOR i IN c_ord LOOP
      IF i.line_id IS NOT NULL THEN
        handle_order_line_event(errbuf,
		        retcode,
		        i.line_id,
		        'SO_LINE_UPDATE');
      ELSE
        handle_order_header_event(errbuf       => errbuf,
		          retcode      => retcode,
		          p_header_id  => i.header_id,
		          p_event_name => 'SO_HEADER_UPDATE');
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Failed handle_om_hold_event - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 2;
  END;
  --------------------------------------------------------------------
  --  name:    handle_order_line_event
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:
  --------------------------------------------------------------------
  --  purpose :
  --
  --------------------------------------------------------------------
  --  ver  date        name         desc
  --  ---  ----------  ----------   ----------------------------------
  --  1.0  25.12.17    yuval tal    CHG0042041/CHG0042043 initial build
  --  1.1  16.07.18    Lingaraj     CTASK0037599 - Entity Code = OrderNumber-LineNumber
  --  1.2  15-Nov-18   Lingaraj     CHG0044334 - Change in SO header interface
  --                                    Update "Complete Order Shipped Date" and "Systems Shipped Date"
  --  1.3  10/12/2018  Roman W.     CHG0044657 - Strataforce  events  missing entity_code value wit...
  --------------------------------------------------------------------
  PROCEDURE handle_order_line_event(errbuf        OUT VARCHAR2,
			retcode       OUT VARCHAR2,
			p_line_id     NUMBER,
			p_event_name  VARCHAR2,
			p_entity_code VARCHAR2 DEFAULT NULL -- CHG0044657
			) IS
  
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    l_fsl_order_source VARCHAR2(30);
    l_fsl_attribute2   VARCHAR2(30);
  
    CURSOR c_ord IS
      SELECT h.order_type_id,
	 l.flow_status_code,
	 h.order_number,
	 h.quote_number,
	 h.order_source_id,
	 h.transaction_phase_code,
	 l.line_number, --CTASK0037599
	 (nvl(h.order_number, h.quote_number) || '-' || l.line_number) entity_code --CTASK0037599
	,
	 l.inventory_item_id --CHG0044334
	,
	 l.header_id order_header_id,
	 nvl((SELECT 'SHIPPED'
	     FROM   wsh_delivery_details
	     WHERE  source_header_id = h.header_id
	     AND    source_line_id = l.line_id
	     AND    released_status = 'C' -- Shipped
	     AND    rownum = 1),
	     'NOVALUE') shipping_status,
	 get_order_source_name(h.order_source_id) order_source_name
      FROM   oe_order_headers_all h,
	 oe_order_lines_all   l
      WHERE  h.header_id = l.header_id
      AND    l.line_id = p_line_id;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
  
    FOR i IN c_ord LOOP
    
      --l_fsl_order_source := get_order_source_name(i.order_source_id);
    
      IF nvl(i.order_source_name, '-1') = 'SFDC PR FSL' THEN
        l_fsl_attribute2 := 'PRODUCT_REQUEST_LINE';
      ELSIF nvl(i.order_source_name, '-1') = 'SFDC QUOTE FSL' THEN
        l_fsl_attribute2 := 'QUOTE_LINE';
      END IF;
    
      -- check valid to sync
      IF is_valid_order_type(i.order_type_id) = 'Y' AND
         i.flow_status_code != 'DRAFT' AND i.transaction_phase_code != 'N' -- It is not a Quote
       THEN
        l_xxssys_event_rec             := NULL;
        l_xxssys_event_rec.target_name := g_target_name;
        l_xxssys_event_rec.entity_name := 'SO_LINE';
        l_xxssys_event_rec.entity_id   := p_line_id;
        l_xxssys_event_rec.event_name  := p_event_name;
        l_xxssys_event_rec.entity_code := i.entity_code; --CTASK0037599
        --Insert SO LINE Event
        xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
      
        --COMMIT;
      END IF;
    
      --Added for CHG0042734 -Create Order interface - Enable Strataforce to create orders in Oracle
      IF i.flow_status_code != 'DRAFT' AND i.transaction_phase_code != 'N' -- It is not a Quote
         AND i.order_source_name IN ('SFDC PR FSL', 'SFDC QUOTE FSL') THEN
        -- Create an Event for the Sales Order Header
        l_xxssys_event_rec             := NULL;
        l_xxssys_event_rec.target_name := g_target_name;
        l_xxssys_event_rec.entity_name := 'SO_LINE_FSL';
        l_xxssys_event_rec.entity_id   := p_line_id;
        l_xxssys_event_rec.event_name  := p_event_name;
        l_xxssys_event_rec.attribute2  := l_fsl_attribute2;
        l_xxssys_event_rec.entity_code := i.entity_code; --CTASK0037599
        --Insert SO Line Event
        xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
      
        --COMMIT;
      END IF;
    
      --Start CHG0044334 ----------------------------------------------
      IF i.shipping_status = 'SHIPPED' AND
         i.order_source_name = 'STRATAFORCE' AND
         xxssys_oa2sf_util_pkg.get_category_value('Activity Analysis',
				  i.inventory_item_id) IN
         ('Systems (net)', 'Systems-Used', 'BDL-Systems') THEN
        IF xxssys_oa2sf_util_pkg.get_systems_ship_date(i.order_header_id) IS NOT NULL THEN
          l_xxssys_event_rec             := NULL;
          l_xxssys_event_rec.target_name := g_target_name;
          l_xxssys_event_rec.entity_name := 'SO_HEADER';
          l_xxssys_event_rec.entity_id   := i.order_header_id;
          l_xxssys_event_rec.event_name  := p_event_name;
          l_xxssys_event_rec.entity_code := i.order_number;
        
          xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
        END IF;
      END IF;
      COMMIT;
      --End CHG0044334 -------------------------------------------------------
    
    END LOOP;
  
    IF p_event_name = 'SO_LINE_DELETE' THEN
      l_xxssys_event_rec             := NULL;
      l_xxssys_event_rec.target_name := g_target_name;
      l_xxssys_event_rec.entity_name := 'SO_LINE';
      l_xxssys_event_rec.entity_id   := p_line_id;
      l_xxssys_event_rec.event_name  := p_event_name;
      l_xxssys_event_rec.attribute1  := 'DELETE';
      l_xxssys_event_rec.entity_code := p_entity_code; -- CHG0044657
      --Insert SO LINE Event
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
    
      --Added for CHG0042734 for FSL Order Source  -- COMMENTS BY yuval 
      --  l_xxssys_event_rec.entity_name := 'SO_LINE_FSL';
      --  l_xxssys_event_rec.attribute2  := l_fsl_attribute2;
      --  xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
    
      COMMIT;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Failed sync_order_line -p_line_id= ' || p_line_id || ' ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 2;
  END handle_order_line_event;

  --------------------------------------------------------------------
  --  name:    handle_asset_event
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:
  --------------------------------------------------------------------
  --  purpose :
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --    1.1  28.03.18   yuval tal           CHG0042619 add handle_asset_event
  --    1.2  16.07.18   Lingaraj            CTASK0037600 -Item classification is  "Heads"  - Do not Generate Event
  --    1.3  03.10.18   Lingaraj      CHG0043859 - Install base interface changes from Oracle to salesforce
  --------------------------------------------------------------------
  PROCEDURE handle_asset_event(errbuf        OUT VARCHAR2,
		       retcode       OUT VARCHAR2,
		       p_instance_id NUMBER,
		       p_event_name  VARCHAR2) IS
  
    l_xxssys_event_rec xxssys_events%ROWTYPE;
  
    -- check scrap has account alias issue transaction
    CURSOR c_scrap(c_instance_id NUMBER) IS
      SELECT 1
      FROM   mtl_material_transactions mmt,
	 mtl_unit_transactions     mut,
	 csi_item_instances        cii
      WHERE  mmt.transaction_type_id IN (1, 4, 8, 32, 31, 63)
      AND    mmt.inventory_item_id = mut.inventory_item_id
      AND    mmt.transaction_id = mut.transaction_id
      AND    mmt.organization_id = mut.organization_id
      AND    mut.serial_number IS NOT NULL
      AND    mut.serial_number = cii.serial_number
      AND    cii.instance_id = c_instance_id
      AND    xxssys_oa2sf_util_pkg.get_category_value('Activity Analysis',
				      cii.inventory_item_id) !=
	 'Heads'; --CTASK0037600
  
    l_is_valid        VARCHAR2(1) := 'N';
    l_source_of_event xxssys_events.event_name%TYPE := 'XXSSYS_STRATAFORCE_EVENTS_PKG.HANDLE_ASSET_EVENT'; --#CHG0043859
  BEGIN
    errbuf  := NULL;
    retcode := 0;
  
    l_is_valid := is_asset_valid2sync(p_instance_id); --CTASK0037600
  
    IF l_is_valid = 'Y' THEN
      --CTASK0037600
      CASE
        WHEN p_event_name = 'INSTALL_BASE_SHIP' THEN
          l_xxssys_event_rec             := NULL;
          l_xxssys_event_rec.target_name := g_target_name;
          l_xxssys_event_rec.entity_name := 'ASSET';
          l_xxssys_event_rec.attribute1  := p_event_name;
          l_xxssys_event_rec.entity_id   := p_instance_id;
          l_xxssys_event_rec.event_name  := l_source_of_event; --#CHG0043859
        
          xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
        
        WHEN p_event_name = 'MACHINE_SCRAP' THEN
          FOR i IN c_scrap(p_instance_id) LOOP
	l_xxssys_event_rec             := NULL;
	l_xxssys_event_rec.target_name := g_target_name;
	l_xxssys_event_rec.entity_name := 'ASSET';
	l_xxssys_event_rec.attribute1  := p_event_name;
	l_xxssys_event_rec.entity_id   := p_instance_id;
	l_xxssys_event_rec.event_name  := l_source_of_event; --#CHG0043859
          
	xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
          END LOOP;
        
        WHEN p_event_name IN ('MACHINE_RETURN', 'HASP_UPGRADE') THEN
          -- Added on 03 Oct 18 for CHG0043859
          l_xxssys_event_rec             := NULL;
          l_xxssys_event_rec.target_name := g_target_name;
          l_xxssys_event_rec.entity_name := 'ASSET';
          l_xxssys_event_rec.attribute1  := p_event_name;
          l_xxssys_event_rec.entity_id   := p_instance_id;
          l_xxssys_event_rec.event_name  := l_source_of_event; --#CHG0043859
        
          xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
        ELSE
          NULL;
      END CASE;
    END IF;
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Failed sync_Asset p_instance_id= ' || p_instance_id || ' ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 2;
  END handle_asset_event;

  --------------------------------------------------------------------
  --  name:    handle_custom_events
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   25.12.17
  --------------------------------------------------------------------
  --  purpose :   handle STRTAFORCE custom events
  --              Called by XX SSYS Strataforce Custom Events/XXSSYS_STRTAFORCE_EVENT
  --
  --------------------------------------------------------------------------------------------------------
  --  ver  date        name            desc
  --  ---  ---------   -------------   -------------------------------------------------------------------
  --  1.0  25.12.17    yuval tal       CHG0042041/CHG0042043 initial build
  --  1.1  28.03.18    yuval tal       CHG0042619 - Install base interface from Oracle to salesforce
  --  1.2  10/12/2019  Roman W.        CHG0044657 - Strataforce  events  missing entity_code value wit... 
  --------------------------------------------------------------------------------------------------------
  PROCEDURE handle_custom_events(errbuf  OUT VARCHAR2,
		         retcode OUT VARCHAR2) IS
  
    CURSOR c_event IS
      SELECT *
      FROM   xxobjt_custom_events t
      -- WHERE t.creation_date > SYSDATE - 1 / 24
      WHERE  t.event_id >
	 nvl(fnd_profile.value('XXOA2STRATAFORCE_LAST_EVENT_ID'), 0)
      ORDER  BY t.event_id;
    l_err_code VARCHAR2(10);
    l_ret      BOOLEAN;
    l_event_id NUMBER;
  
    l_event_rec xxobjt_custom_events%ROWTYPE;
  BEGIN
    retcode := 0;
    fnd_file.put_line(fnd_file.log, 'Event     Event key');
    fnd_file.put_line(fnd_file.log, '--------------------');
  
    dbms_output.put_line('profile=' ||
		 fnd_profile.value('XXOA2STRATAFORCE_LAST_EVENT_ID'));
    FOR i IN c_event LOOP
      l_event_id := i.event_id;
      fnd_file.put_line(fnd_file.log,
		i.event_name || '        ' || i.event_key);
      l_event_rec := i;
      CASE i.event_name
        WHEN 'SO_HEADER_CREATE' THEN
          handle_order_header_event(errbuf,
			l_err_code,
			i.event_key,
			i.event_name);
        WHEN 'SO_HEADER_UPDATE' THEN
          handle_order_header_event(errbuf,
			l_err_code,
			i.event_key,
			i.event_name);
        WHEN 'SO_LINE_CREATE' THEN
          handle_order_line_event(errbuf,
		          l_err_code,
		          i.event_key,
		          i.event_name);
        WHEN 'SO_LINE_UPDATE' THEN
          handle_order_line_event(errbuf,
		          l_err_code,
		          i.event_key,
		          i.event_name);
        WHEN 'SO_HOLD_CREATE' THEN
          handle_om_hold_event(errbuf,
		       l_err_code,
		       i.event_key,
		       i.event_name);
        WHEN 'SO_HOLD_UPDATE' THEN
          handle_om_hold_event(errbuf,
		       l_err_code,
		       i.event_key,
		       i.event_name);
        
        WHEN 'SO_HEADER_DELETE' THEN
          IF is_valid_order_type(i.attribute1) = 'Y' --Attribute1 - Order Type Id
	 AND i.attribute3 IS NULL -- Attr3 - quote Number
           THEN
	handle_order_header_event(errbuf        => errbuf,
			  retcode       => l_err_code,
			  p_header_id   => i.event_key,
			  p_event_name  => i.event_name,
			  p_entity_code => i.attribute2 -- INC0140843
			  );
          END IF;
        
        WHEN 'SO_LINE_DELETE' THEN
          IF is_valid_order_type(i.attribute1) = 'Y' --Attribute1 - Order Type Id
	 AND i.attribute3 IS NULL -- Attr3 - Quote Number
           THEN
	handle_order_line_event(errbuf        => errbuf,
			retcode       => l_err_code,
			p_line_id     => i.event_key,
			p_event_name  => i.event_name,
			p_entity_code => i.attribute2 -- CHG0044657
			);
          
          END IF;
        
      -- asset events
      --INSTALL_BASE_SHIP
      --MACHINE_RESHIP
      --INSTALL_BASE_UPGRADE
      --HASP_UPGRADE
      --MACHINE_SCRAP
      --MACHINE_RETURN
      
        WHEN 'INSTALL_BASE_SHIP' THEN
        
          handle_asset_event(errbuf, l_err_code, i.event_key, i.event_name);
        WHEN 'MACHINE_RESHIP' THEN
          handle_asset_event(errbuf, l_err_code, i.event_key, i.event_name);
        WHEN 'INSTALL_BASE_UPGRADE' THEN
          handle_asset_event(errbuf, l_err_code, i.event_key, i.event_name);
        WHEN 'HASP_UPGRADE' THEN
          handle_asset_event(errbuf, l_err_code, i.event_key, i.event_name);
        WHEN 'INSTALL_BASE_SHIP' THEN
          handle_asset_event(errbuf, l_err_code, i.event_key, i.event_name);
        WHEN 'MACHINE_SCRAP' THEN
          handle_asset_event(errbuf, l_err_code, i.event_key, i.event_name);
        WHEN 'MACHINE_RETURN' THEN
          handle_asset_event(errbuf, l_err_code, i.event_key, i.event_name);
        
      -- end 1.1
        WHEN 'WSH_LINE_CREATE' THEN
          handle_order_line_event(errbuf,
		          l_err_code,
		          i.event_key,
		          i.event_name);
        WHEN 'WSH_LINE_UPDATE' THEN
          handle_order_line_event(errbuf,
		          l_err_code,
		          i.event_key,
		          i.event_name);
        ELSE
          NULL;
      END CASE;
      retcode := greatest(l_err_code, retcode);
    END LOOP;
  
    fnd_file.put_line(fnd_file.log, 'Last event id = ' || l_event_id);
    IF l_event_id IS NOT NULL THEN
      l_ret := fnd_profile_server.save(x_name       => 'XXOA2STRATAFORCE_LAST_EVENT_ID',
			   x_value      => l_event_id, --NULL,
			   x_level_name => 'SITE');
    END IF;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Failed xxobjt_oa2sf_interface_pkg.handle_events  - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 2;
  END handle_custom_events;
  ----------------------------------------------------------------------------
  --  name:            insert_bom_events
  --  create by:
  --  Revision:        1.0
  --  creation date:
  ----------------------------------------------------------------------------
  --  purpose :
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  -- ----  ----------  ---------------------------- ---------------------------------------
  -- 1.1   25.12.17    yuval tal                  Initial Build
  ------------------------------------------------------------------------------------------------
  PROCEDURE insert_bom_events(p_entity_name VARCHAR2,
		      p_entity_code VARCHAR2,
		      p_attribute1  VARCHAR2,
		      p_attribute2  VARCHAR2,
		      p_attribute3  VARCHAR2) IS
    l_xxssys_event_rec xxssys_events%ROWTYPE;
  BEGIN
    l_xxssys_event_rec                 := NULL;
    l_xxssys_event_rec.target_name     := g_target_name;
    l_xxssys_event_rec.entity_name     := p_entity_name;
    l_xxssys_event_rec.entity_code     := p_entity_code;
    l_xxssys_event_rec.event_name      := 'XXSSYS_STRATAFORCE_EVENTS_PKG.SYNC_BOM';
    l_xxssys_event_rec.created_by      := -1;
    l_xxssys_event_rec.last_updated_by := -1;
  
    l_xxssys_event_rec.attribute1 := p_attribute1; -- EVENT ACTION
    l_xxssys_event_rec.attribute2 := p_attribute2; -- Implementation Date
    l_xxssys_event_rec.attribute3 := p_attribute3; -- Disable Date
  
    xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
  
  END insert_bom_events;
  ----------------------------------------------------------------------------
  --  name:            generate_bom_events
  --  create by:
  --  Revision:        1.0
  --  creation date:
  ----------------------------------------------------------------------------
  --  purpose :
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  -- ----  ----------  ---------------------------- ---------------------------------------
  -- 1.1   12.8.18       yuval tal                  INC0129899 modify cursor sf_bom_options_c1
  ------------------------------------------------------------------------------------------------
  PROCEDURE generate_bom_events(p_bill_sequence_id  IN NUMBER,
		        p_top_model_item_id IN NUMBER,
		        p_assembly_item     IN VARCHAR2,
		        x_noof_bom_ev       OUT NUMBER,
		        x_noof_bom_opt_ev   OUT NUMBER) IS
    CURSOR sf_bom_options_c IS
      SELECT po.external_key__c bom_option_key
      FROM   xxsf2_productfeature pf,
	 xxsf2_productoptions po
      WHERE  pf.id = po.sbqq__feature__c
      AND    pf.external_key__c = p_assembly_item
      AND    po.external_key__c IS NOT NULL;
  
    CURSOR bom_active_components_c IS
      SELECT msib.segment1 component_code,
	 msib.bom_item_type,
	 bic.optional,
	 bic.implementation_date,
	 bic.disable_date,
	 (p_assembly_item || '|' || msib.segment1) bom_option_key
      FROM   bom_inventory_components_v bic,
	 mtl_system_items_b         msib
      WHERE  bic.bill_sequence_id = p_bill_sequence_id
      AND    bic.component_item_id = msib.inventory_item_id
      AND    msib.organization_id =
	 xxinv_utils_pkg.get_master_organization_id
      AND    trunc(nvl(bic.disable_date, (SYSDATE + 1))) > trunc(SYSDATE);
  
    --SFDC non Active Options to Be Deleted
    CURSOR sf_bom_options_c1 IS
      SELECT bom_option_key bom_option_key
      FROM   (SELECT to_char(po.external_key__c) bom_option_key
	  FROM   xxsf2_productfeature pf,
	         xxsf2_productoptions po
	  WHERE  pf.id = po.sbqq__feature__c
	  AND    pf.external_key__c =
	         'Included Items-' || p_assembly_item -- INC0129899 yuval 12.8.18
	  MINUS -- active components in erp
	  SELECT (p_assembly_item || '|' || msib.segment1) bom_option_key
	  FROM   bom_inventory_components_v bic,
	         mtl_system_items_b         msib
	  WHERE  bic.bill_sequence_id = p_bill_sequence_id
	  AND    bic.component_item_id = msib.inventory_item_id
	  AND    msib.organization_id =
	         xxinv_utils_pkg.get_master_organization_id
	        --  AND    trunc(nvl(bic.disable_date, (SYSDATE + 1))) >
	        --     trunc(SYSDATE)
	  AND    SYSDATE BETWEEN bic.implementation_date --INC0129899 yuval 12.8.18
	         AND nvl(bic.disable_date, (SYSDATE + 1)) --INC0129899 yuval 12.8.18
	  );
  
    l_p_item_code                 VARCHAR2(240);
    l_is_valid_bom_feature_itm    VARCHAR2(1) := 'N';
    l_xxssys_event_rec            xxssys_events%ROWTYPE;
    l_sf_delete_all_bom_options   VARCHAR2(1) := 'N';
    l_is_bom_valid                VARCHAR2(1) := 'N';
    l_is_sf_bom_feature_available VARCHAR2(1) := 'N';
    l_organization_id             NUMBER := xxinv_utils_pkg.get_master_organization_id;
  BEGIN
    x_noof_bom_ev     := 0;
    x_noof_bom_opt_ev := 0;
    --Verify the Item is a Valid PTO KIT or PTO Model Item to Sync to SFDC?
    -- Function Will return Y or N
    l_is_bom_valid := is_bom_valid(p_bill_sequence_id => p_bill_sequence_id,
		           p_item_id          => p_top_model_item_id,
		           p_organization_id  => l_organization_id);
  
    IF l_is_bom_valid = 'N' THEN
      -- Check the BOM Exists in CopyStorm , If Exists
      --Remove all the available BOM Options from SFDC by generating DELETE Events
      BEGIN
        SELECT 'Y'
        INTO   l_is_sf_bom_feature_available
        FROM   xxsf2_productfeature
        WHERE  external_key__c = p_assembly_item;
      
        FOR rec IN sf_bom_options_c LOOP
          insert_bom_events(p_entity_name => g_bom_option_entity_name,
		    p_entity_code => rec.bom_option_key,
		    p_attribute1  => 'DELETE',
		    p_attribute2  => '', -- Implementation Date
		    p_attribute3  => '' -- Di
		    );
        END LOOP;
      
        -- Check do we need to DELETE the BOM Feture Also ?????
      EXCEPTION
        WHEN no_data_found THEN
          l_is_sf_bom_feature_available := 'N';
      END;
    ELSE
    
      --Delete all BOM Options from SFDC which not Exists or not active in Oracle  for the BOM
      FOR component_rec IN sf_bom_options_c1 LOOP
        fnd_file.put_line(fnd_file.log,
		  'DELETE => ' || component_rec.bom_option_key);
        insert_bom_events(p_entity_name => g_bom_option_entity_name,
		  p_entity_code => component_rec.bom_option_key,
		  p_attribute1  => 'DELETE',
		  p_attribute2  => '',
		  p_attribute3  => '');
      END LOOP;
    
      -- Bom is Valid   , Sync Parent and Child both
      --Sync Parent BOM
      insert_bom_events(p_entity_name => g_bom_feature_entity_name,
		p_entity_code => p_assembly_item,
		p_attribute1  => '',
		p_attribute2  => '',
		p_attribute3  => '');
      x_noof_bom_ev := x_noof_bom_ev + 1;
      --Sync Children
      FOR act_bom_option_rec IN bom_active_components_c LOOP
        --If there is a Future Disable Date available , Generate 2 Events
        -- (1) 1st Event to Create or Update One BOM Option
        -- (2) 2nd Event to Delete BOM Option in Future
      
        --1st Event - Creat Upsert Event for sync the BOM Option to SFDC
        insert_bom_events(p_entity_name => g_bom_option_entity_name,
		  p_entity_code => act_bom_option_rec.bom_option_key,
		  p_attribute1  => '',
		  p_attribute2  => to_char(act_bom_option_rec.implementation_date,
				   'DD-MON-YYYY'),
		  p_attribute3  => '');
        x_noof_bom_opt_ev := x_noof_bom_opt_ev + 1;
      
        IF act_bom_option_rec.disable_date IS NOT NULL AND
           trunc(act_bom_option_rec.disable_date) > trunc(SYSDATE) THEN
        
          --2nd Event Create a Delete Event for Future When the BOM Option will be Disabled
          insert_bom_events(p_entity_name => g_bom_option_entity_name,
		    p_entity_code => act_bom_option_rec.bom_option_key,
		    p_attribute1  => 'DELETE',
		    p_attribute2  => to_char(act_bom_option_rec.implementation_date,
				     'DD-MON-YYYY'),
		    p_attribute3  => to_char(act_bom_option_rec.disable_date,
				     'DD-MON-YYYY'));
        
          x_noof_bom_opt_ev := x_noof_bom_opt_ev + 1;
        END IF;
      END LOOP;
    END IF;
  END generate_bom_events;
  --BOM Main Program
  PROCEDURE sync_bom(errbuf             OUT VARCHAR2,
	         retcode            OUT VARCHAR2,
	         p_sync_x_days_back IN NUMBER DEFAULT 1) IS
  
    CURSOR bom_c IS
      SELECT DISTINCT (CASE
		WHEN (bbo.bill_sequence_id = bic.bill_sequence_id) THEN
		 bbo.bill_sequence_id
		ELSE
		 bbo.common_bill_sequence_id
	          END) bill_sequence_id,
	          bbo.assembly_item_id,
	          msib_p.segment1 p_assembly_item
      FROM   bom_bill_of_materials_v    bbo,
	 bom_inventory_components_v bic,
	 mtl_system_items_b         msib_p
      WHERE  msib_p.organization_id = bbo.organization_id
      AND    msib_p.inventory_item_id = bbo.assembly_item_id
      AND    msib_p.organization_id =
	 xxinv_utils_pkg.get_master_organization_id
	--and    msib_p.segment1          = '125-40101'
      AND    (bbo.bill_sequence_id = bic.bill_sequence_id OR
	(bbo.bill_sequence_id != bbo.common_bill_sequence_id AND
	bbo.common_bill_sequence_id = bic.bill_sequence_id))
      AND    (bbo.last_update_date > (SYSDATE - p_sync_x_days_back) OR
	bic.last_update_date > (SYSDATE - p_sync_x_days_back));
  
    l_noof_bom_ev      NUMBER;
    l_noof_bom_opt_ev  NUMBER;
    l_noof_bom_ev1     NUMBER := 0;
    l_noof_bom_opt_ev1 NUMBER := 0;
  BEGIN
    retcode := 0;
    --Verify each rec and generate Events
    FOR bom_rec IN bom_c LOOP
      generate_bom_events(bom_rec.bill_sequence_id,
		  bom_rec.assembly_item_id,
		  bom_rec.p_assembly_item,
		  l_noof_bom_ev,
		  l_noof_bom_opt_ev);
      l_noof_bom_ev1     := l_noof_bom_ev1 + l_noof_bom_ev;
      l_noof_bom_opt_ev1 := l_noof_bom_opt_ev1 + l_noof_bom_opt_ev;
    END LOOP;
  
    fnd_file.put_line(fnd_file.log,
	          'Sync BOM Days Back :' || p_sync_x_days_back);
    fnd_file.put_line(fnd_file.log,
	          'No Of BOM Events Generated :' || l_noof_bom_ev1);
    fnd_file.put_line(fnd_file.log,
	          'No Of BOM Option Events Generated :' ||
	          l_noof_bom_opt_ev1);
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf := 'Failed xxssys_strataforce_events_pkg.generate_bom_events  - ' ||
	    substr(SQLERRM, 1, 240);
      fnd_file.put_line(fnd_file.log, errbuf);
      retcode := 2;
  END sync_bom;
  -----
  PROCEDURE mtl_cat_trg_processor(p_old_cat_rec    IN mtl_categories_b%ROWTYPE,
		          p_new_cat_rec    IN mtl_categories_b%ROWTYPE,
		          p_trigger_name   IN VARCHAR2,
		          p_trigger_action IN VARCHAR2) IS
    CURSOR c_cpq_category_chg(c_catgory_id NUMBER /*, c_structure_id NUMBER*/) IS
    /*  SELECT msib.inventory_item_id,msib.segment1 item_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          FROM mtl_item_categories_v t,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               mtl_system_items_b msib
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         WHERE t.category_id     = c_catgory_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           AND t.structure_id    = c_structure_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           AND t.organization_id = xxinv_utils_pkg.get_master_organization_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           AND msib.organization_id = t.organization_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           AND msib.inventory_item_id = t.inventory_item_id;*/
    
      SELECT base.item                 item_code,
	 base.inventory_item_id,
	 base.description,
	 base."Line Of Business",
	 base."Product Line",
	 base."Product Family",
	 base."Sub Family",
	 base."Specialty/Flavor",
	 base."Technology",
	 base."Item Type",
	 base."Activity Analysis",
	 base."Brand",
	 base.product_line,
	 base.product_line_desc,
	 micv.category_concat_segs cotegory,
	 micv.attribute10          cpq_feature,
	 base.creation_date,
	 base.item_type,
	 base.item_status
      FROM   (SELECT mcv.*,
	         f.description pl_mapping_desc
	  FROM   mtl_categories_v   mcv,
	         fnd_flex_values_vl f
	  WHERE  mcv.structure_id = 50592
	  AND    mcv.attribute9 = f.flex_value
	  AND    f.flex_value_set_id = 1013893) micv,
	 
	 (SELECT msi.segment1                     item,
	         msi.inventory_item_id,
	         msi.description,
	         mic.segment1                     "Line Of Business",
	         mic.segment2                     "Product Line",
	         mic.segment3                     "Product Family",
	         mic.segment4                     "Sub Family",
	         mic.segment5                     "Specialty/Flavor",
	         mic.segment6                     "Technology",
	         mic.segment7                     "Item Type",
	         mic1.segment1                    "Activity Analysis",
	         mic2.segment1                    "Brand",
	         mic.category_concat_segs         ph_concat,
	         g.segment5                       product_line,
	         f1.description                   product_line_desc,
	         msi.creation_date,
	         f2.meaning                       item_type,
	         mi.inventory_item_status_code_tl item_status
	  
	  FROM   mtl_system_items_b     msi,
	         gl_code_combinations_v g,
	         gl_code_combinations_v g1,
	         fnd_flex_values_vl     f1,
	         fnd_lookup_values_vl   f2,
	         mtl_item_status        mi,
	         mtl_item_categories_v  mic,
	         mtl_item_categories_v  mic1,
	         mtl_item_categories_v  mic2
	  WHERE  msi.organization_id =
	         xxinv_utils_pkg.get_master_organization_id
	  AND    msi.organization_id = mic.organization_id(+)
	  AND    msi.inventory_item_id = mic.inventory_item_id(+)
	  AND    msi.cost_of_sales_account = g.code_combination_id(+)
	  AND    g1.segment5 = f1.flex_value
	  AND    f1.flex_value_set_id = 1013893
	  AND    msi.cost_of_sales_account = g1.code_combination_id(+)
	  AND    f2.lookup_type(+) = 'ITEM_TYPE'
	  AND    msi.item_type = f2.lookup_code(+)
	  AND    msi.inventory_item_status_code =
	         mi.inventory_item_status_code(+)
	  AND    mic.category_set_id(+) = 1100000221
	  AND    msi.organization_id = mic1.organization_id(+)
	  AND    msi.inventory_item_id = mic1.inventory_item_id(+)
	  AND    mic1.category_set_id(+) = 1100000222
	  AND    msi.organization_id = mic2.organization_id(+)
	  AND    msi.inventory_item_id = mic2.inventory_item_id(+)
	  AND    mic2.category_set_id(+) = 1100000248) base
      
      WHERE  base."Line Of Business" = micv.segment1(+)
      AND    BASE."Product Line" = micv.segment2(+)
      AND    BASE."Product Family" = micv.segment3(+)
      AND    BASE."Sub Family" = micv.segment4(+)
      AND    BASE."Specialty/Flavor" = micv.segment5(+)
      AND    BASE."Technology" = micv.segment6(+)
      AND    BASE."Item Type" = micv.segment7(+)
      AND    BASE."Activity Analysis" = micv.segment8(+)
      AND    BASE."Brand" = micv.segment9(+)
	--AND    base.item = c_item_code;
      AND    micv.category_id = c_catgory_id; --219913  ;
  
    l_error_message   VARCHAR2(500);
    l_valid_structure VARCHAR2(1) := 'N';
  
    --l_old_category_id  NUMBER := p_old_cat_rec.category_id;
    l_category_id NUMBER := nvl(p_new_cat_rec.category_id,
		        p_old_cat_rec.category_id);
  
  BEGIN
  
    BEGIN
      SELECT 'Y'
      INTO   l_valid_structure
      FROM   fnd_id_flex_structures_vl fifs
      WHERE  fifs.application_id = 401
      AND    fifs.id_flex_code = 'MCAT'
      AND    fifs.id_flex_structure_name = 'Stratasys PL Mapping';
    EXCEPTION
      WHEN no_data_found THEN
        l_valid_structure := 'N';
    END;
  
    IF l_valid_structure = 'Y' AND l_category_id IS NOT NULL THEN
      --Find all the New Items associated with the Category
      FOR rec IN c_cpq_category_chg(l_category_id) LOOP
        insert_product_event(p_inventory_item_id => rec.inventory_item_id,
		     p_item_code         => rec.item_code,
		     p_last_updated_by   => nvl(p_new_cat_rec.last_updated_by,
				        p_old_cat_rec.last_updated_by),
		     p_created_by        => nvl(p_new_cat_rec.created_by,
				        p_old_cat_rec.created_by),
		     p_trigger_name      => p_trigger_name,
		     p_trigger_action    => p_trigger_action);
      END LOOP;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      l_error_message := substr(SQLERRM, 1, 500);
      raise_application_error(-20001, l_error_message);
  END mtl_cat_trg_processor;
  --

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041630
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                Description
  -- 1.0  18-Feb-2018   Lingaraj Sarangi    CHG0042203 - New 'System' item setup interface
  -- 1.1  11.4.18       yuval tal           CHG0042203 - CTASK0036202         Exclude xml entries for  configuration rule generation for  features  "Service Contracts & Warranty Upgrades"
  -- --------------------------------------------------------------------------------------------
  PROCEDURE process_system_setup(p_event_id_tab IN xxobjt.xxssys_interface_event_tab,
		         x_xml          OUT CLOB,
		         x_err_code     OUT VARCHAR2, -- S - SUCCESS  - E- ERROR
		         x_err_messge   OUT VARCHAR2) IS
    CURSOR c_sf IS
      SELECT NAME,
	 id,
	 decode(NAME,
	        'Materials',
	        10,
	        'Service Contracts & Warranty Upgrades',
	        20,
	        'Accessories',
	        30,
	        'Installation',
	        40,
	        'Printing Heads',
	        50) sbqq_number
      FROM   xxsf2_productrule t
      WHERE  t.name IN ('Materials',
		'Accessories',
		'Service Contracts & Warranty Upgrades',
		'Installation',
		'Printing Heads')
      AND    t.sbqq__active__c = 1
      AND    externalkey__c IS NOT NULL;
  
    l_header_xml            VARCHAR2(200);
    l_event_xml             CLOB; --VARCHAR2(4000);
    l_product_code          VARCHAR2(240);
    l_sf_product_id         VARCHAR2(240);
    l_sf_feature_exists     VARCHAR2(1) := 'N';
    l_status                VARCHAR2(10);
    l_error                 VARCHAR2(1000);
    l_feature_xml           CLOB; -- VARCHAR2(4000);
    l_config_xml            CLOB; --  VARCHAR2(4000);
    l_rec_cnt               NUMBER := 0;
    l_product_ruleid        VARCHAR2(255);
    l_configurationrule_key VARCHAR2(500);
    l_product_rule_name     VARCHAR2(100);
    l_cur_event_id          NUMBER;
    TYPE feature_type IS RECORD(
      NAME        VARCHAR2(100),
      sbqq_number NUMBER,
      sfid        VARCHAR2(240));
    TYPE feature_tab IS TABLE OF feature_type INDEX BY BINARY_INTEGER;
    l_feature_tab feature_tab;
    my_exception EXCEPTION;
    l_sqlerrm VARCHAR2(255);
    l_tmp     NUMBER;
  BEGIN
    x_err_code   := 'S';
    x_err_messge := '';
    x_xml        := '';
    l_header_xml := '<?xml version="1.0" encoding="utf-8"?>
		 <event_data xmlns="http://www.stratasys.com/strataforce/systemsetup">';
  
    FOR rec IN c_sf LOOP
      l_rec_cnt := l_rec_cnt + 1;
      l_feature_tab(l_rec_cnt).sbqq_number := rec.sbqq_number;
      l_feature_tab(l_rec_cnt).name := rec.name;
      l_feature_tab(l_rec_cnt).sfid := rec.id;
    END LOOP;
  
    --Added on 19-06-2018 ,if no active record availble in "xxsf2_productrule" Program will return Error
    IF l_rec_cnt = 0 THEN
      x_err_code   := 'E';
      x_err_messge := 'No record available in xxsf2_productrule Table.';
      RETURN;
    END IF;
  
    FOR i IN 1 .. p_event_id_tab.count() LOOP
      BEGIN
        --dbms_output.put_line('event_id :'||p_event_id_tab(i).event_id);
        l_event_xml         := NULL;
        l_product_code      := NULL;
        l_sf_product_id     := NULL;
        l_sf_feature_exists := 'N';
        l_status            := NULL;
        l_error             := NULL;
        l_config_xml        := NULL;
        l_feature_xml       := NULL;
        l_product_ruleid    := NULL;
        l_cur_event_id      := p_event_id_tab(i).event_id;
      
        BEGIN
          SELECT xxssys_oa2sf_util_pkg.get_sf_product_id(entity_code),
	     entity_code
          INTO   l_sf_product_id,
	     l_product_code
          FROM   xxssys_events
          WHERE  event_id = p_event_id_tab(i).event_id;
        
          IF l_sf_product_id IS NULL THEN
	l_status := 'NEW';
          ELSE
	l_status := 'SUCCESS';
          END IF;
        
        EXCEPTION
          WHEN no_data_found THEN
	l_status := 'ERR';
	l_error  := 'Event not Found';
        END;
      
        SELECT (xmlelement("event_id", p_event_id_tab(i).event_id) ||
	   xmlelement("item_code", l_product_code) ||
	   xmlelement("sf_item_code_id", l_sf_product_id) ||
	   xmlelement("status", l_status) || --NEW/SUCCESS/ERROR/CLOSE
	   xmlelement("err_message", l_error))
        INTO   l_event_xml
        FROM   dual;
      
        IF l_status = 'SUCCESS' THEN
          BEGIN
          
	SELECT 1
	INTO   l_tmp
	FROM   dual
	WHERE  xxssys_oa2sf_util_pkg.get_concatenated_segments(xxinv_utils_pkg.get_item_id(l_product_code)) = 'Y';
          
	l_product_rule_name := xxssys_oa2sf_util_pkg.g_relatedtosystems;
          
	SELECT product_rule.id
	INTO   l_product_ruleid
	FROM   xxsf2_productrule product_rule
	WHERE  product_rule.name = l_product_rule_name;
          
	--dbms_output.put_line('l_product_rule_name' ||
	--     l_product_rule_name);
	/*SELECT product_rule.id,
                   product.relatedtosystems__c
            INTO   l_product_ruleid,
                   l_product_rule_name
            FROM   xxsf2_product2    product,
                   xxsf2_productrule product_rule
            WHERE  product.relatedtosystems__c = product_rule.name
            AND    product.external_key__c = l_product_code;*/
          EXCEPTION
	WHEN too_many_rows THEN
	  l_status := 'ERR';
	  l_error  := 'Too many rows return from copy storm for  Product rule name (' ||
		  l_product_rule_name || ')';
	
	  RAISE my_exception;
	WHEN OTHERS THEN
	  l_status := 'ERR';
	  l_error  := 'No Product rule name found for (' ||
		  l_product_rule_name || ')';
	
	  RAISE my_exception;
          END;
          --   dbms_output.put_line('l_feature_tab=' || l_feature_tab.count());
        
          FOR i IN 1 .. l_feature_tab.count() LOOP
          
	--
          
	l_feature_xml := '';
	SELECT (xmlelement("name", l_feature_tab(i).name) ||
	       xmlelement("sbqq__number__c",
		       l_feature_tab(i).sbqq_number) ||
	       xmlelement("external_key__c",
		       (l_feature_tab(i)
		       .name || '-' || l_product_code)))
	INTO   l_feature_xml
	FROM   dual;
          
	l_feature_xml := '<feature>' || l_feature_xml;
	--CHG0042203 - CTASK0036202
	IF l_feature_tab(i)
	 .name != 'Service Contracts & Warranty Upgrades' THEN
	
	  ----------------------------------------
	  --First  configurationrule
	  ------------------------------------------
	  l_config_xml := '';
	
	  l_configurationrule_key := l_product_code || '-' || l_feature_tab(i).name || '-' || l_feature_tab(i).name;
	
	  SELECT (xmlelement("external_key__c", l_configurationrule_key) ||
	         xmlelement("sbqq__productrule__c",
		         l_feature_tab(i).sfid))
	  INTO   l_config_xml
	  FROM   dual;
	
	  l_feature_xml := l_feature_xml ||
		       '<configurationrule_list><configuration_rule>' ||
		       l_config_xml || '</configuration_rule>';
	
	  ---------------------------------------
	  --Second  configurationrule
	  -----------------------------------
	  l_configurationrule_key := l_product_code || '-' ||
			     l_product_rule_name || '-' || l_feature_tab(i).name;
	  l_config_xml            := '';
	  -- configurationrule key
	  --  SBQQ__Product__r.ProductCode &"-"& SBQQ__ProductRule__r.Name &"-"& SBQQ__ProductFeature__r.Name
	
	  SELECT (xmlelement("external_key__c", l_configurationrule_key) ||
	         xmlelement("sbqq__productrule__c", l_product_ruleid))
	  INTO   l_config_xml
	  FROM   dual;
	  l_feature_xml := l_feature_xml || '<configuration_rule>' ||
		       l_config_xml ||
		       '</configuration_rule></configurationrule_list>';
	
	END IF; --CHG0042203 - CTASK0036202
	l_event_xml := l_event_xml || l_feature_xml || '</feature>'; ----CHG0042203 - CTASK0036202
          
          -- dbms_output.put_line(length(l_event_xml));
          END LOOP;
        
        END IF;
      
      EXCEPTION
        WHEN my_exception THEN
        
          SELECT (xmlelement("event_id", p_event_id_tab(i).event_id) ||
	     xmlelement("item_code", l_product_code) ||
	     xmlelement("sf_item_code_id", l_sf_product_id) ||
	     xmlelement("status", 'ERR') ||
	     xmlelement("err_message", l_error))
          INTO   l_event_xml
          FROM   dual;
        
        WHEN OTHERS THEN
          l_sqlerrm := substr(SQLERRM, 1, 250);
          SELECT (xmlelement("event_id", p_event_id_tab(i).event_id) ||
	     xmlelement("item_code", l_product_code) ||
	     xmlelement("sf_item_code_id", l_sf_product_id) ||
	     xmlelement("status", 'ERR') ||
	     xmlelement("err_message", l_sqlerrm))
          INTO   l_event_xml
          FROM   dual;
        
      END;
      x_xml := x_xml || '<event>' || l_event_xml || '</event>';
    
    END LOOP;
  
    --Prepare Final XML
    x_xml := l_header_xml || '<event_list>' || x_xml ||
	 '</event_list></event_data>';
    --dbms_output.put_line('XML Data :'||x_xml);
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code   := 'E';
      x_err_messge := 'Error During EventId:' || to_char(l_cur_event_id) ||
	          ', Error :' || SQLERRM;
      write_log('Error In xxssys_strataforce_events_pkg.process_system_setup :' ||
	    x_err_messge);
  END process_system_setup;

  --------------------------------------------------------------------
  --  name:   is_valid_order_type
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   25.12.17
  --------------------------------------------------------------------
  --  purpose :
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  25.12.17    yuval tal         CHG0042041 initial build
  --------------------------------------------------------------------
  FUNCTION is_valid_order_type(p_order_type_id IN NUMBER) RETURN VARCHAR2 IS
  
    CURSOR c IS
      SELECT 'Y'
      FROM   oe_transaction_types_all t
      WHERE  t.attribute14 IS NULL
      AND    t.transaction_type_id = p_order_type_id;
    l_exist VARCHAR2(10) := NULL;
  
  BEGIN
    OPEN c;
    FETCH c
      INTO l_exist;
    CLOSE c;
  
    RETURN nvl(l_exist, 'N');
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END;

  --------------------------------------------------------------------
  --  name:   is_valid_order_type
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   25.12.17
  --------------------------------------------------------------------
  --  purpose :
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0 1.4.18    yuval tal         CHG0042619 sync asset from oracle 2 sfdc
  --  1.1 16.07.18  Lingaraj          CTASK0037600 -  item classification is  "Heads"  - Do not Generate Event
  --------------------------------------------------------------------

  FUNCTION is_asset_valid2sync(p_instance_id NUMBER) RETURN VARCHAR2 IS
    l_flag VARCHAR2(1);
  
    CURSOR c_valid IS
      SELECT 'Y' flag
      FROM   (SELECT cii.instance_id,
	         cii.serial_number,
	         msib.segment1,
	         msib.description,
	         msib.inventory_item_id
	  FROM   csi_i_parties_h        h,
	         csi_item_instances_h   hi,
	         csi_instance_details_v cid,
	         hz_parties             hp1,
	         hz_parties             hp2,
	         csi_item_instances     cii,
	         mtl_system_items_b     msib
	  WHERE  hi.transaction_id = h.transaction_id
	  AND    hi.instance_id = cii.instance_id
	  AND    cid.instance_id = cii.instance_id
	  AND    nvl(h.old_party_id, 10041) = hp1.party_id
	  AND    h.new_party_id = hp2.party_id
	  AND    nvl(h.old_party_id, 10041) <> h.new_party_id
	  AND    msib.organization_id = 91
	  AND    cii.inventory_item_id = msib.inventory_item_id
	  AND    nvl(h.old_party_id, 10041) = 10041
	  AND    cii.active_end_date IS NULL
	  AND    (cii.serial_number IS NOT NULL OR (xxssys_oa2sf_util_pkg.get_category_value('Activity Analysis',
								 msib.inventory_item_id) =
	        'Grabcad'))
	  AND    cii.instance_status_id = 10002
	  AND    cii.instance_id = p_instance_id
	  AND    xxssys_oa2sf_util_pkg.get_category_value('Activity Analysis',
					  msib.inventory_item_id) !=
	         'Heads' --CTASK0037600
	  UNION ALL
	  -- Created machines that marked manually by CS admin in Oracle.
	  SELECT cii.instance_id,
	         cii.serial_number,
	         msib.segment1,
	         msib.description,
	         msib.inventory_item_id
	  FROM   csi_item_instances cii,
	         mtl_system_items_b msib
	  WHERE  msib.organization_id = 91
	  AND    cii.inventory_item_id = msib.inventory_item_id
	  AND    cii.owner_party_id = 10041
	  AND    cii.active_end_date IS NULL
	  AND    cii.serial_number IS NOT NULL
	  AND    cii.attribute16 = 'Y')
      WHERE  instance_id = p_instance_id
      AND    xxssys_oa2sf_util_pkg.get_category_value('Activity Analysis',
				      inventory_item_id) !=
	 'Heads'; --CTASK0037600
  
  BEGIN
    FOR i IN c_valid LOOP
      l_flag := i.flag;
    END LOOP;
  
    RETURN nvl(l_flag, 'N');
  
  END is_asset_valid2sync;

  ---------------------------------------------------------------------------
  -- get_order_source_name - Fetch get_order_source Name for given source id
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  -- 1.0      30.Apr.18  Lingaraj       CHG0042734 - Initial Build
  -----------------------------------------------------------------------------
  FUNCTION get_order_source_name(p_order_source_id VARCHAR2) RETURN VARCHAR2 IS
    l_order_source VARCHAR2(100);
  BEGIN
  
    SELECT NAME
    INTO   l_order_source
    FROM   oe_order_sources
    WHERE  order_source_id = p_order_source_id;
  
    RETURN l_order_source;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN '';
  END get_order_source_name;

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
			 p_trigger_action IN VARCHAR2) IS
    l_xxssys_event_rec xxssys_events%ROWTYPE;
  BEGIN
  
    FOR okc_line_rec IN (SELECT *
		 FROM   okc_k_lines_b
		 WHERE  dnz_chr_id = p_new_okc_h_rec.id
		 AND    sts_code NOT IN ('ENTERED', 'HOLD')) LOOP
      okc_line_trg_processor(p_old_okc_line_rec => okc_line_rec,
		     p_new_okc_line_rec => okc_line_rec,
		     p_trigger_name     => p_trigger_name,
		     p_trigger_action   => p_trigger_action);
    
    END LOOP;
  
  END okc_header_trg_processor;

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
		           p_trigger_action   IN VARCHAR2) IS
    l_xxssys_event_rec xxssys_events%ROWTYPE;
  BEGIN
    -- Create an Event
    l_xxssys_event_rec             := NULL;
    l_xxssys_event_rec.target_name := g_target_name;
    l_xxssys_event_rec.entity_name := g_okc_contract_entity_name; --'OKC_SERVICE_CONTRACT';
  
    l_xxssys_event_rec.entity_code     := to_char(p_new_okc_line_rec.id);
    l_xxssys_event_rec.last_updated_by := p_new_okc_line_rec.last_updated_by;
    l_xxssys_event_rec.created_by      := p_new_okc_line_rec.created_by;
    l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			      p_trigger_action || ')';
  
    --Insert Event
    xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
  
    /*If p_new_okc_line_rec.start_date is not null Then
      l_xxssys_event_rec.attribute2      := to_char(p_new_okc_line_rec.start_date,'DD-MON-YYYY');
    End if;
    
    If p_new_okc_line_rec.end_date is not null Then
       l_xxssys_event_rec.attribute3      := to_char(p_new_okc_line_rec.end_date,'DD-MON-YYYY');
    End if;
    
    If p_new_okc_line_rec.date_terminated is not null Then
      l_xxssys_event_rec.attribute4      := to_char(p_new_okc_line_rec.date_terminated,'DD-MON-YYYY');
    End if;
    
     --Insert Event for End Date
     If p_new_okc_line_rec.end_date is not null
      and  p_new_okc_line_rec.end_date > trunc(sysdate)
     Then
       l_xxssys_event_rec.attribute2      := to_char(p_new_okc_line_rec.end_date+1,'DD-MON-YYYY');
       l_xxssys_event_rec.attribute3      := to_char(p_new_okc_line_rec.end_date+1,'DD-MON-YYYY');
    
       --Insert Event
       xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
     End if;
    
     --Insert Event for Termination Date
     If p_new_okc_line_rec.date_terminated is not null
       and p_new_okc_line_rec.date_terminated > trunc(sysdate)
     Then
       l_xxssys_event_rec.attribute2      := to_char(p_new_okc_line_rec.date_terminated+1,'DD-MON-YYYY');
       l_xxssys_event_rec.attribute3      := to_char(p_new_okc_line_rec.date_terminated+1,'DD-MON-YYYY');
    
       --Insert Event
       xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
     End if;
    
    */
  END okc_line_trg_processor;

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
		           p_trigger_action   IN VARCHAR2) IS
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    l_okc_line_rec     okc.okc_k_lines_b%ROWTYPE;
  BEGIN
  
    BEGIN
      SELECT *
      INTO   l_okc_line_rec
      FROM   okc.okc_k_lines_b
      WHERE  id = p_new_okc_item_rec.cle_id
      AND    sts_code NOT IN ('ENTERED', 'HOLD');
    
      l_okc_line_rec.last_updated_by := p_new_okc_item_rec.last_updated_by;
      l_okc_line_rec.created_by      := p_new_okc_item_rec.created_by;
    
      okc_line_trg_processor(p_old_okc_line_rec => l_okc_line_rec,
		     p_new_okc_line_rec => l_okc_line_rec,
		     p_trigger_name     => p_trigger_name,
		     p_trigger_action   => p_trigger_action);
    
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;
  
  END okc_item_trg_processor;

END xxssys_strataforce_events_pkg;
/
