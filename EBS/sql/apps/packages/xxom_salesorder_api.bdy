create or replace package body xxom_salesorder_api AS
  --------------------------------------------------------------------
  --  name:          xxom_salesorder_api
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/05/2017
  --------------------------------------------------------------------
  --  purpose :      CHG0041891: Sales Order processing package
  --------------------------------------------------------------------
  -- Call End Points: STRATAFORCE
  --------------------------------------------------------------------------------------------------------------------
  --  ver  date          name                      desc
  --  1.0  12/05/2017    Diptasurjya Chatterjee    Initial Build - CHG0041891
  --  1.1  05/02/2018    Lingaraj Sarangi          CHG0041892 - Validation rules and holds on Book
  --  1.2  07/20/2018    Diptasurjya               INC0127218 - Bug fixes on quote validation
  --  1.3  23-Jul-18     Diptasurjya               INC0127595 - Need to Change personalization to requery the order
  --  1.4  07/30/2018    Diptasurjya               INC0128351 - Allow manual adjustment to be negative amounts i.e markups
  --  1.5  28/08/2018    Diptasurjya               INC0131369 - Upper case checking added in update_line_dff procedure
  --  1.6  05/09/2018    Diptasurjya               INC0132115 - Modify update_line_dff to remove instance ID derivation logic
  --  1.7  12-SEP-18     Roman W.                  CHG0043970 - return reason code
  --  1.8  12/09/2018    Diptasurjya Chatterjee    CHG0043691 - Modify prepare_header_data to update ATTRIBUTE11 with deal type
  --  1.9  29-Oct-2018   Lingaraj                  CHG0044300 - Ammend "Get Quote Lines"" Interface
  --  2.0  20-NOV-2018   Lingaraj                  CHG0044433 - Get Quote Lines
  --                                               reuse the same Quote number when Order lines are cancelled
  --  2.1  08-Jan-2019   Diptasurjya               CHG0044253 - Add new fields in prepare_line_date for Service contract items
  --                                                            Modify update_line_dff to prevent updates of DFF for service contract items
  --  2.2  22-Jan-2019   Diptasurjya               INC0144895 - Change prepare_line_data to set pricing for SC item lines
  --  2.3  28-Jan-2019   Diptasurjya               INC0145470 - Change validation codes for SC items
  ----------------------------------------------------------------------------------------------------------------------
  g_master_invorg_id   NUMBER := xxinv_utils_pkg.get_master_organization_id; --29OCT18 for #CHG0044300
  g_strataforce_target VARCHAR2(150) := 'STRATAFORCE';  -- CHG0044253
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041891 - This function fetches order source ID from order source name or ID
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  12/05/2017  Diptasurjya Chatterjee (TCS)    CHG0041891 - Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION fetch_order_source_id(p_order_source_name IN VARCHAR2,
                                 p_order_source_id   IN VARCHAR2)
    RETURN NUMBER IS
    l_order_source_id NUMBER;
  BEGIN
    SELECT oos.order_source_id
      INTO l_order_source_id
      FROM oe_order_sources oos
     WHERE oos.order_source_id =
           nvl(p_order_source_id, oos.order_source_id)
       AND oos.name = nvl(p_order_source_name, oos.name)
       AND oos.enabled_flag = 'Y';

    RETURN l_order_source_id;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041891 - This function checks if Customer Account ID/Number is valid
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  12/05/2017  Diptasurjya Chatterjee (TCS)    CHG0041891 - Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION fetch_customer_account_id(p_cust_account_id     IN NUMBER,
                                     p_cust_account_number IN VARCHAR2)
    RETURN NUMBER IS
    l_cust_account_id NUMBER := 0;
  BEGIN
    SELECT hca.cust_account_id
      INTO l_cust_account_id
      FROM hz_cust_accounts hca
     WHERE hca.cust_account_id =
           nvl(p_cust_account_id, hca.cust_account_id)
       AND hca.account_number =
           nvl(p_cust_account_number, hca.account_number)
       AND hca.status = 'A';

    RETURN l_cust_account_id;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041891 - This function returns FOB code for a name
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  12/05/2017  Diptasurjya Chatterjee (TCS)    CHG0041891 - Initial Build
  -- --------------------------------------------------------------------------------------------
  /* -- Not in Use
  FUNCTION fetch_fob_code(p_fob_name IN VARCHAR2) RETURN VARCHAR2 IS
    l_fob_code VARCHAR2(30);
  BEGIN
    SELECT flvv.lookup_code
    INTO   l_fob_code
    FROM   fnd_lookup_values_vl flvv
    WHERE  flvv.lookup_type = 'FOB'
    AND    flvv.view_application_id = 222
    AND    flvv.lookup_code = p_fob_name;

    RETURN l_fob_code;
  END;
  */

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041891 - This function fetches Modifier ID from modifier name
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  26/06/2017  Diptasurjya Chatterjee (TCS)    CHG0041891 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION fetch_modifier_id(p_ask_for_mod_name IN VARCHAR2) RETURN NUMBER IS
    l_modifier_id NUMBER;
  BEGIN

    SELECT qlh.list_header_id
      INTO l_modifier_id
      FROM qp_list_headers_all qlh
     WHERE qlh.name = p_ask_for_mod_name;

    RETURN l_modifier_id;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041891 - This function fetches order transaction type name from order header ID
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  26/06/2017  Diptasurjya Chatterjee (TCS)    CHG0041891 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION fetch_order_type_from_header(p_header_id IN NUMBER)
    RETURN VARCHAR2 IS
    l_order_type VARCHAR2(30);
  BEGIN

    SELECT ott.name
      INTO l_order_type
      FROM oe_order_headers_all oh, oe_transaction_types_tl ott
     WHERE oh.header_id = p_header_id
       AND oh.order_type_id = ott.transaction_type_id
       AND ott.language = userenv('LANG');

    RETURN l_order_type;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041891 - This function fetches header DFF context name for a order type name
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  26/06/2017  Diptasurjya Chatterjee (TCS)    CHG0041891 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION fetch_header_flex_context(p_order_type IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_header_flex_context VARCHAR2(30);
  BEGIN

    SELECT con.descriptive_flex_context_code
      INTO l_header_flex_context
      FROM fnd_descr_flex_contexts_vl con, fnd_application_vl fav
     WHERE con.descriptive_flex_context_code = p_order_type
       AND fav.application_id = con.application_id
       AND con.enabled_flag = 'Y'
       AND fav.application_name = 'Order Management'
       AND con.descriptive_flexfield_name = 'OE_HEADER_ATTRIBUTES';

    RETURN l_header_flex_context;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041891 - This function fetches header DFF context name for a order type name
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  26/06/2017  Diptasurjya Chatterjee (TCS)    CHG0041891 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION fetch_line_flex_context(p_order_type IN VARCHAR2) RETURN VARCHAR2 IS
    l_line_flex_context VARCHAR2(30);
  BEGIN

    SELECT con.descriptive_flex_context_code
      INTO l_line_flex_context
      FROM fnd_descr_flex_contexts_vl con, fnd_application_vl fav
     WHERE con.descriptive_flex_context_code = p_order_type
       AND fav.application_id = con.application_id
       AND con.enabled_flag = 'Y'
       AND fav.application_name = 'Order Management'
       AND con.descriptive_flexfield_name = 'OE_LINE_ATTRIBUTES';

    RETURN l_line_flex_context;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041892 - This function the original Payment Terms on a quote data
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  04/02/2018  Diptasurjya Chatterjee (TCS)    CHG0041892 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_quote_pterms(p_so_line_id NUMBER, p_request_source VARCHAR2)
    RETURN NUMBER IS
    l_payment_term_id NUMBER;
  BEGIN

    SELECT qh.payment_term_id
      INTO l_payment_term_id
      FROM xxobjt.xxcpq_quote_header_mirr qh,
           oe_order_lines_all             ol,
           oe_order_headers_all           oh
     WHERE qh.price_request_number = oh.attribute4
       AND qh.source_name = p_request_source
       AND ol.line_id = p_so_line_id
       AND ol.header_id = oh.header_id;

    RETURN l_payment_term_id;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041891 - This function checks if a line is eligible for split
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  26/06/2017  Diptasurjya Chatterjee (TCS)    CHG0041891 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_eligible_for_split(p_inventory_item_id IN NUMBER,
                                 p_organization_id   IN NUMBER,
                                 p_request_source    IN VARCHAR2)
    RETURN NUMBER IS
    is_eligible_for_split NUMBER := 0;
  BEGIN
    BEGIN
      SELECT 1
        INTO is_eligible_for_split
        FROM mtl_system_items_b
       WHERE replenish_to_order_flag = 'Y'
         AND inventory_item_id = p_inventory_item_id
         AND organization_id = p_organization_id;
    EXCEPTION
      WHEN no_data_found THEN
        is_eligible_for_split := 0;
    END;

    RETURN is_eligible_for_split;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041891 - This function checks if an order is eligible for avg discount calculation
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  26/06/2017  Diptasurjya Chatterjee (TCS)    CHG0041891 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_eligible_for_avg_disc(p_header_id IN NUMBER) RETURN NUMBER IS
    is_eligible_for_avg_disc NUMBER := 0;
  BEGIN
    BEGIN
      SELECT 1
        INTO is_eligible_for_avg_disc
        FROM oe_order_headers_all oh
       WHERE oh.header_id = p_header_id
         AND xxoe_utils_pkg.calc_avg_discount(oh.order_type_id) = 'Y';
    EXCEPTION
      WHEN no_data_found THEN
        is_eligible_for_avg_disc := 0;
    END;

    RETURN is_eligible_for_avg_disc;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041891 - This function checks if an order line is eligible for system line association
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  21/02/2018  Diptasurjya Chatterjee (TCS)    CHG0041891 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_line_elig_system_assoc(p_line_id IN NUMBER) RETURN VARCHAR2 IS
    l_line_elig_system_assoc VARCHAR2(1);

  BEGIN
    -- Check for Activity Analysis valid values
    BEGIN
      SELECT 'Y'
        INTO l_line_elig_system_assoc
        FROM mtl_item_categories mic,
             mtl_categories_kfv  mc,
             oe_order_lines_all  ol,
             mtl_category_sets   mcs
       WHERE mic.category_id = mc.category_id
         AND mic.category_set_id = mcs.category_set_id
         AND mcs.category_set_name = 'Activity Analysis'
         AND mic.inventory_item_id = ol.inventory_item_id
         AND ol.line_id = p_line_id
         AND mic.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         AND mc.attribute9 = 'Y';

    EXCEPTION
      WHEN no_data_found THEN
        l_line_elig_system_assoc := 'N';
    END;

    -- Check if Billing Type is Upgrade
    IF l_line_elig_system_assoc = 'N' THEN
      BEGIN
        SELECT 'Y'
          INTO l_line_elig_system_assoc
          FROM mtl_system_items_b msib, oe_order_lines_all ol
         WHERE ol.line_id = p_line_id
           AND ol.inventory_item_id = msib.inventory_item_id
           AND msib.organization_id =
               xxinv_utils_pkg.get_master_organization_id
           AND msib.material_billable_flag = 'XXOBJ_UG';
      EXCEPTION
        WHEN no_data_found THEN
          l_line_elig_system_assoc := 'N';
      END;
    END IF;

    -- Check if Product Hierarchy contains Voxel Print
    IF l_line_elig_system_assoc = 'N' THEN
      BEGIN
        SELECT 'Y'
          INTO l_line_elig_system_assoc
          FROM mtl_item_categories mic,
               mtl_categories_kfv  mc,
               oe_order_lines_all  ol,
               mtl_category_sets   mcs,
               mtl_system_items_b  msib
         WHERE mic.category_id = mc.category_id
           AND mic.category_set_id = mcs.category_set_id
           AND mcs.category_set_name = 'Product Hierarchy'
           AND mic.inventory_item_id = ol.inventory_item_id
           AND ol.line_id = p_line_id
           AND mic.organization_id =
               xxinv_utils_pkg.get_master_organization_id
           AND msib.inventory_item_id = mic.inventory_item_id
           AND msib.organization_id = mic.organization_id
           AND upper(mc.concatenated_segments) LIKE '%VOXEL PRINT%';
      EXCEPTION
        WHEN no_data_found THEN
          l_line_elig_system_assoc := 'N';
      END;
    END IF;

    -- And new conditions here

    RETURN l_line_elig_system_assoc;
  END is_line_elig_system_assoc;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041891 - This function checks if bom_item_type for an item is valid for explicit
  --                       explosion during order line import
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  26/06/2017  Diptasurjya Chatterjee (TCS)    CHG0041891 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_item_bom_type_valid(p_inventory_item_id IN NUMBER)
    RETURN VARCHAR2 IS
    l_bom_item_type_valid VARCHAR2(1) := 'N';
  BEGIN
    SELECT 'Y'
      INTO l_bom_item_type_valid
      FROM bom_bill_of_materials_v x, mtl_system_items_b msib
     WHERE rownum = 1
       AND msib.bom_item_type = 1 --MODEL
       AND msib.inventory_item_id = x.assembly_item_id
       AND x.organization_id = msib.organization_id
       AND msib.organization_id =
           xxinv_utils_pkg.get_master_organization_id
       AND msib.inventory_item_id = p_inventory_item_id
       AND NOT EXISTS
     (SELECT 1
              FROM bom_inventory_components_v b
             WHERE b.bom_item_type = 2 -- OPTION CLASS
               AND b.bill_sequence_id = x.bill_sequence_id
               AND trunc(SYSDATE) BETWEEN b.implementation_date AND
                   nvl(b.disable_date, (SYSDATE + 1)));

    RETURN l_bom_item_type_valid;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
  END is_item_bom_type_valid;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041891 - This function checks SO is having any DG items in it
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/04/2018  Diptasurjya Chatterjee (TCS)    CHG0041891 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_order_dg_eligible(p_so_lines_tab xxom_so_lines_tab_type)
    RETURN VARCHAR2 IS
    l_is_dg_order VARCHAR2(1);
  BEGIN
    SELECT 'Y'
      INTO l_is_dg_order
      FROM TABLE(CAST(p_so_lines_tab AS xxom_so_lines_tab_type)) t1
     WHERE xxinv_utils_pkg.is_item_hazard_restricted(t1.inventory_item_id) = 'Y'
       AND rownum = 1;

    RETURN l_is_dg_order;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
  END is_order_dg_eligible;

  ----------------------------------------------------------------------------
  --  name:          validate_order_header
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/05/2017
  ----------------------------------------------------------------------------
  --  purpose :      CHG0041891: Source specific validations and derived field
  --                 population for order header
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  12/05/2017  Diptasurjya Chatterjee  CHG0041891 - initial build
  --  1.1  20-NOV-2018   Lingaraj              CHG0044433 - Get Quote Lines
  --                                           reuse the same Quote number when Order lines are cancelled
  --  1.2  03-Dec-2018  Lingaraj               CHG0044433 -CTASK0039493 - Pricelist Validation
  ----------------------------------------------------------------------------

  PROCEDURE validate_order_header(p_header_rec     IN xxobjt.xxom_so_header_rec_type,
                                  p_request_source IN VARCHAR2,
                                  p_book_validate  IN VARCHAR2 DEFAULT 'N',
                                  x_header_rec     OUT xxobjt.xxom_so_header_rec_type,
                                  x_status         OUT VARCHAR2,
                                  x_status_msg     OUT VARCHAR2) IS
    l_is_valid   NUMBER;
    l_header_rec xxom_so_header_rec_type;
    l_line_count NUMBER;

    l_order_source_id     NUMBER;
    l_order_type_expected VARCHAR2(300);

    l_step               VARCHAR2(50);
    l_price_list_id      NUMBER; --CHG0044433/CTASK0039493
  BEGIN
    l_header_rec := p_header_rec;
    oe_debug_pub.add('SSYS CUSTOM: Enter header record validation procedure : validate_order_header');
    x_status := fnd_api.g_ret_sts_success;

    IF l_header_rec IS NULL THEN
      x_status     := fnd_api.g_ret_sts_error;
      x_status_msg := x_status_msg ||
                      'ERROR: Order header information must be provided' ||
                      chr(13);
      RETURN;
    END IF;

    /* Start - STRATAFORCE specific - Reseller / 3RD party / End Customer accounts all null*/
    IF p_request_source = g_strataforce_target THEN
      /* header ID mandatory */
      IF l_header_rec.header_id IS NULL THEN
        x_status     := fnd_api.g_ret_sts_error;
        x_status_msg := x_status_msg ||
                        'ERROR: Order header ID must be provided ' ||
                        chr(13);
      END IF;

      /* Quote number mandatory */
      IF l_header_rec.sf_quote_number IS NULL THEN
        x_status     := fnd_api.g_ret_sts_error;
        x_status_msg := x_status_msg ||
                        'ERROR: Quote number must be provided ' || chr(13);
      END IF;

      /* Operation mandatory */
      IF l_header_rec.operation IS NULL THEN
        x_status     := fnd_api.g_ret_sts_error;
        x_status_msg := x_status_msg ||
                        'ERROR: Operation number must be provided ' ||
                        chr(13);
      END IF;

      IF l_header_rec.header_id IS NOT NULL AND
         l_header_rec.sf_quote_number IS NOT NULL THEN
        BEGIN
          l_is_valid := 0;
          SELECT oh.org_id, nvl(oh.price_list_id, 0) --CTASK0039493
            INTO l_header_rec.org_id, l_price_list_id --CTASK0039493
            FROM oe_order_headers_all oh, oe_order_headers_all_dfv ohd
           WHERE oh.header_id = l_header_rec.header_id
             AND oh.rowid = ohd.row_id
             AND ohd.quote_no = l_header_rec.sf_quote_number;

        EXCEPTION
          WHEN no_data_found THEN
            x_status     := fnd_api.g_ret_sts_error;
            x_status_msg := x_status_msg ||
                            'ERROR: Order header ID and Quote combination is not valid ' ||
                            chr(13);
        END;
      END IF;

      /* Pricelist mandatory */
      IF l_header_rec.price_list_id IS NULL THEN
        x_status     := fnd_api.g_ret_sts_error;
        x_status_msg := x_status_msg ||
                        'ERROR: Pricelist must be provided ' || chr(13);

      ELSE
        --CHG0044433/CTASK0039493
        --Price List Validation, Oracle Price List Vs Quote Price List
        If l_price_list_id != l_header_rec.price_list_id Then
          x_status     := fnd_api.g_ret_sts_error;
          x_status_msg := x_status_msg ||
                          'ERROR: There is a mismatch in Oracle Order and Quote Price list' ||
                          chr(13);
        End if;
      END IF;

      /* Validate SF oppurtunity */
      IF l_header_rec.sf_oppurtunity IS NULL OR
         l_header_rec.sf_oppurtunity = '' THEN
        x_status     := fnd_api.g_ret_sts_error;
        x_status_msg := x_status_msg ||
                        'ERROR: The quote you are trying to get is not related to an opportunity. Only quotes that are associated to an opportunity can be imported' ||
                        chr(13);
      END IF;

      /* Validate Quote status */
      IF upper(nvl(l_header_rec.sf_quote_status, 'X')) <> 'APPROVED' THEN
        x_status     := fnd_api.g_ret_sts_error;
        x_status_msg := x_status_msg ||
                        'ERROR: The quote you are trying to get is not approved yet in Salesforce ' ||
                        chr(13);
      END IF;

      --CHG0044433 Verify SBQQ__Quote__c.SBQQ__Primary__c = TRUE
      IF upper(nvl(l_header_rec.sf_sbqq_primary, 'FALSE')) <> 'TRUE' THEN
        x_status     := fnd_api.g_ret_sts_error;
        x_status_msg := x_status_msg ||
                        'ERROR: The quote you are trying to pull is not the primary quote.' ||
                        'Please mark it as primary in SFDC before pulling the quote.' ||
                        chr(13);
      END IF;

      IF l_header_rec.header_id IS NOT NULL THEN
        SELECT COUNT(1)
          INTO l_line_count
          FROM oe_order_lines_all
         WHERE header_id = l_header_rec.header_id;

        IF p_book_validate = 'N' AND l_line_count <> 0 THEN
          x_status     := fnd_api.g_ret_sts_error;
          x_status_msg := x_status_msg ||
                          'ERROR: Order already contains lines. Please delete the lines or open a separate Order ' ||
                          chr(13);
        END IF;

        l_line_count := 0;
        SELECT COUNT(1)
          INTO l_line_count
          FROM oe_order_headers_all
         WHERE header_id = l_header_rec.header_id
           AND flow_status_code = 'ENTERED';

        IF l_line_count = 0 THEN
          x_status     := fnd_api.g_ret_sts_error;
          x_status_msg := x_status_msg ||
                          'ERROR: Order is not in ENTERED state ' ||
                          chr(13);
        END IF;

        l_line_count := 0;
        SELECT COUNT(1)
          INTO l_line_count
          FROM oe_order_headers_all
         WHERE header_id = l_header_rec.header_id
           AND ship_from_org_id IS NOT NULL;

        IF l_line_count = 0 THEN
          x_status     := fnd_api.g_ret_sts_error;
          x_status_msg := x_status_msg ||
                          'ERROR: Order header does not have warehouse defined ' ||
                          chr(13);
        END IF;
      END IF;

      IF l_header_rec.calculate_price_flag IS NOT NULL THEN
        BEGIN
          SELECT lookup_code
            INTO l_header_rec.calculate_price_flag
            FROM fnd_lookup_values_vl
           WHERE lookup_type = 'CALCULATE_PRICE_FLAG'
             AND view_application_id = 660
             AND enabled_flag = 'Y'
             AND l_header_rec.calculate_price_flag = lookup_code;
        EXCEPTION
          WHEN no_data_found THEN
            x_status     := fnd_api.g_ret_sts_error;
            x_status_msg := x_status_msg ||
                            'ERROR: Calculate price flag is not valid ' ||
                            chr(13);
        END;
      END IF;
      l_step := 'before Validate FOB name';
      /* Validate FOB name
       --This Part Commented - Reason- FOB Code Received from SFDC , not Fob Name
      IF l_header_rec.fob IS NOT NULL THEN
        BEGIN
          l_header_rec.fob_code := fetch_fob_code(l_header_rec.fob);
        EXCEPTION
          WHEN no_data_found THEN
            x_status     := fnd_api.g_ret_sts_error;
            x_status_msg := x_status_msg || 'ERROR: FOB name is not valid ' ||
        chr(13);
        END;
      END IF; */
      l_step := 'before Order type validation';
      /* Order type validation */
      IF l_header_rec.operation IS NOT NULL AND
         l_header_rec.org_id IS NOT NULL AND
         l_header_rec.header_id IS NOT NULL THEN
        BEGIN
          SELECT 1
            INTO l_is_valid
            FROM fnd_flex_values_vl   fv,
                 fnd_flex_value_sets  vs,
                 oe_order_headers_all oh
           WHERE fv.flex_value_set_id = vs.flex_value_set_id
             AND vs.flex_value_set_name = 'XXOM_SF2OA_Order_Types_Mapping'
             AND fv.attribute1 = l_header_rec.operation
             AND fv.attribute2 = l_header_rec.org_id
             AND oh.header_id = l_header_rec.header_id
             AND fv.attribute3 = oh.order_type_id;

          l_is_valid := 0;
        EXCEPTION
          WHEN no_data_found THEN
            BEGIN
              SELECT ot.name
                INTO l_order_type_expected
                FROM fnd_flex_values_vl      fv,
                     fnd_flex_value_sets     vs,
                     oe_transaction_types_tl ot
               WHERE fv.flex_value_set_id = vs.flex_value_set_id
                 AND vs.flex_value_set_name =
                     'XXOM_SF2OA_Order_Types_Mapping'
                 AND fv.attribute1 = l_header_rec.operation
                 AND fv.attribute2 = l_header_rec.org_id
                 AND fv.attribute3 = ot.transaction_type_id
                 AND ot.language = userenv('LANG');
            EXCEPTION
              WHEN no_data_found THEN
                x_status     := fnd_api.g_ret_sts_error;
                x_status_msg := x_status_msg ||
                                'ERROR: The Operation number: ' ||
                                l_header_rec.operation ||
                                ' and Operating Unit: ' ||
                                l_header_rec.org_id ||
                                ' combination received is not valid ' ||
                                chr(13);
            END;

            x_status     := fnd_api.g_ret_sts_error;
            x_status_msg := x_status_msg ||
                            'ERROR: The order type you have created does not match the opportunity type associated with the quote. Please choose an order type that matches the opportunity.' ||
                            chr(13) || ' Expected Order Type: ' ||
                            l_order_type_expected || chr(13);
        END;
      END IF;

      /* Start - Order Source validate/derive */
      IF l_header_rec.order_source IS NULL AND
         l_header_rec.order_source_id IS NULL THEN
        BEGIN
          SELECT attribute3
            INTO l_header_rec.order_source_id
            FROM fnd_flex_values ffv, fnd_flex_value_sets ffvs
           WHERE ffvs.flex_value_set_name = 'XXSSYS_EVENT_TARGET_NAME'
             AND ffvs.flex_value_set_id = ffv.flex_value_set_id
             AND ffv.attribute1 = 'Y'
             AND upper(ffv.flex_value) = upper(p_request_source)
             AND ffv.enabled_flag = 'Y'
             AND SYSDATE BETWEEN nvl(ffv.start_date_active, SYSDATE - 1) AND
                 nvl(ffv.end_date_active, SYSDATE + 1);
        EXCEPTION
          WHEN no_data_found THEN
            x_status     := fnd_api.g_ret_sts_error;
            x_status_msg := x_status_msg ||
                            'ERROR: Default Order Source not setup in VS XXSSYS_EVENT_TARGET_NAME for target ' ||
                            p_request_source || chr(13);
        END;
      END IF;

      IF l_header_rec.order_source IS NOT NULL AND
         l_header_rec.order_source_id IS NULL THEN
        BEGIN
          l_header_rec.order_source_id := fetch_order_source_id(p_order_source_name => l_header_rec.order_source,
                                                                p_order_source_id   => NULL);
        EXCEPTION
          WHEN no_data_found THEN
            x_status     := fnd_api.g_ret_sts_error;
            x_status_msg := x_status_msg || 'ERROR: Provided Order Source ' ||
                            l_header_rec.order_source || ' is not valid' ||
                            chr(13);
        END;
      END IF;
      /* End - Order Source validate/derive*/

      IF l_header_rec.sf_reseller_account IS NULL AND
         l_header_rec.sf_3rd_party_account IS NULL AND
         l_header_rec.sf_end_cust_account IS NULL AND
         l_header_rec.sf_reseller_account_id IS NULL AND
         l_header_rec.sf_3rd_party_account_id IS NULL AND
         l_header_rec.sf_end_cust_account_id IS NULL THEN
        x_status     := fnd_api.g_ret_sts_error;
        x_status_msg := x_status_msg ||
                        'VALIDATION ERROR: No customer information provided' ||
                        chr(13);
      END IF;

      /* End - STRATAFORCE specific - Reseller / 3RD party / End Customer accounts all null*/

      /* Start - Reseller account validate */
      IF l_header_rec.sf_reseller_account IS NOT NULL OR
         l_header_rec.sf_reseller_account_id IS NOT NULL THEN
        BEGIN
          l_header_rec.sf_reseller_account_id := fetch_customer_account_id(l_header_rec.sf_reseller_account_id,
                                                                           l_header_rec.sf_reseller_account);

        EXCEPTION
          WHEN no_data_found THEN
            x_status     := fnd_api.g_ret_sts_error;
            x_status_msg := x_status_msg ||
                            'ERROR: Reseller account information is not valid ' ||
                            chr(13);
        END;
      END IF;
      /* End - Reseller account validate*/

      /* Start - 3rd party account validate */
      IF l_header_rec.sf_3rd_party_account IS NOT NULL OR
         l_header_rec.sf_3rd_party_account_id IS NOT NULL THEN
        BEGIN
          l_header_rec.sf_3rd_party_account_id := fetch_customer_account_id(l_header_rec.sf_3rd_party_account_id,
                                                                            l_header_rec.sf_3rd_party_account);

        EXCEPTION
          WHEN no_data_found THEN
            x_status     := fnd_api.g_ret_sts_error;
            x_status_msg := x_status_msg ||
                            'ERROR: 3rd party account information not valid ' ||
                            chr(13);
        END;
      END IF;
      /* End - 3rd party account validate*/

      /* Start - End Customer account validate */
      IF l_header_rec.sf_end_cust_account IS NOT NULL OR
         l_header_rec.sf_end_cust_account_id IS NOT NULL THEN
        BEGIN
          l_header_rec.sf_end_cust_account_id := fetch_customer_account_id(l_header_rec.sf_end_cust_account_id,
                                                                           l_header_rec.sf_end_cust_account);

        EXCEPTION
          WHEN no_data_found THEN
            x_status     := fnd_api.g_ret_sts_error;
            x_status_msg := x_status_msg ||
                            'ERROR: End customer account information not valid ' ||
                            chr(13);
        END;
      END IF;
      /* End - End Customer account validate*/

      /* Start quote account ownership checks */
      IF x_status <> fnd_api.g_ret_sts_error THEN
        BEGIN
          l_is_valid := 0;

          SELECT oh.header_id
            INTO l_is_valid
            FROM oe_order_headers_all oh
           WHERE oh.header_id = l_header_rec.header_id
             AND oh.sold_to_org_id IN
                 (l_header_rec.sf_reseller_account_id,
                  l_header_rec.sf_3rd_party_account_id,
                  l_header_rec.sf_end_cust_account_id);

        EXCEPTION
          WHEN no_data_found THEN
            x_status     := fnd_api.g_ret_sts_error;
            x_status_msg := x_status_msg ||
                            'ERROR: The Bill To account specified on the order does not match optional accounts from the quote' ||
                            chr(13);
        END;

        IF x_status <> fnd_api.g_ret_sts_error THEN
          BEGIN
            l_is_valid := 0;

            SELECT oh.header_id
              INTO l_is_valid
              FROM oe_order_headers_all oh
             WHERE oh.header_id = l_header_rec.header_id
               AND xxhz_util.get_account_id_of_site_use_id(oh.ship_to_org_id) IN
                   (l_header_rec.sf_reseller_account_id,
                    l_header_rec.sf_3rd_party_account_id,
                    l_header_rec.sf_end_cust_account_id);

          EXCEPTION
            WHEN no_data_found THEN
              x_status     := fnd_api.g_ret_sts_error;
              x_status_msg := x_status_msg ||
                              'ERROR: The Ship To account specified on the order does not match optional accounts from the quote' ||
                              chr(13);
          END;
        END IF;

        -- Keep End customer validation for book event only
        IF p_book_validate = 'Y' THEN
          IF x_status <> fnd_api.g_ret_sts_error THEN
            BEGIN
              l_is_valid := 0;

              SELECT oh.header_id
                INTO l_is_valid
                FROM oe_order_headers_all oh
               WHERE oh.header_id = l_header_rec.header_id
                 AND (oh.sold_to_org_id =
                     l_header_rec.sf_end_cust_account_id OR
                     xxhz_util.get_account_id_of_site_use_id(oh.ship_to_org_id) =
                     l_header_rec.sf_end_cust_account_id OR
                     oh.end_customer_id =
                     l_header_rec.sf_end_cust_account_id);

            EXCEPTION
              WHEN no_data_found THEN
                x_status     := fnd_api.g_ret_sts_error;
                x_status_msg := x_status_msg ||
                                'ERROR: The End Customer specified on the Order does not match the End Customer on the quote' ||
                                chr(13);
            END;
          END IF;
        END IF; -- End customer validation
      END IF;
      /* End quote account ownership checks */
      l_step := 'Start check of promo code ';
      /* Start check of promo code */
      IF l_header_rec.ask_for_modifier_name IS NOT NULL THEN
        BEGIN
          l_header_rec.ask_for_modifier_id := fetch_modifier_id(l_header_rec.ask_for_modifier_name);
        EXCEPTION
          WHEN no_data_found THEN
            x_status     := fnd_api.g_ret_sts_error;
            x_status_msg := x_status_msg || 'ERROR: Promotional code: ' ||
                            l_header_rec.ask_for_modifier_name ||
                            ' is not valid ' || chr(13);
        END;
      END IF;
      /* End check of promo code */
    END IF; -- End STRATAFORCE validations

    oe_debug_pub.add('SSYS CUSTOM: Header validation status: ' || x_status);
    oe_debug_pub.add('SSYS CUSTOM: Header validation status message: ' ||
                     x_status_msg);
    oe_debug_pub.add('SSYS CUSTOM: Leaving header record validation procedure : validate_order_header');
    x_header_rec := l_header_rec;
  EXCEPTION
    WHEN OTHERS THEN
      x_status     := fnd_api.g_ret_sts_error;
      x_status_msg := l_step || ' ' ||
                      'UNEXPECTED ERROR: In validate_order_header ' ||
                      SQLERRM;

      oe_debug_pub.add('SSYS CUSTOM: Header validation status: ' ||
                       x_status);
      oe_debug_pub.add('SSYS CUSTOM: Header validation status message: ' ||
                       x_status_msg);
      oe_debug_pub.add('SSYS CUSTOM: Leaving header record validation procedure : validate_order_header');
  END validate_order_header;

  ----------------------------------------------------------------------------
  --  name:          validate_order_header
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/05/2017
  ----------------------------------------------------------------------------
  --  purpose :      CHG0041891: Source specific validations and derived field
  --                 population for order header
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  12/05/2017  Diptasurjya Chatterjee  CHG0041891 - initial build
  --  1.1  07/30/2018  Diptasurjya Chatterjee  INC0128351 - Manual adjustment amount can be negative ie. markup
  ----------------------------------------------------------------------------

  PROCEDURE validate_order_line(p_header_rec     IN xxobjt.xxom_so_header_rec_type,
                                p_line_tab       IN xxobjt.xxom_so_lines_tab_type,
                                p_request_source IN VARCHAR2,
                                x_line_tab       OUT xxobjt.xxom_so_lines_tab_type,
                                x_status         OUT VARCHAR2,
                                x_status_msg     OUT VARCHAR2) IS
    l_is_valid   VARCHAR2(1) := 'Y';
    l_header_rec xxom_so_header_rec_type;
    l_line_tab   xxom_so_lines_tab_type := xxom_so_lines_tab_type();

    l_max_line_num NUMBER;

    l_order_source_id NUMBER;
  BEGIN
    l_header_rec := p_header_rec;
    l_line_tab   := p_line_tab;
    x_status     := fnd_api.g_ret_sts_success;

    oe_debug_pub.add('SSYS CUSTOM: Enter line table validation procedure : validate_order_line');

    IF l_line_tab IS NULL OR l_line_tab.count = 0 THEN
      x_status     := fnd_api.g_ret_sts_error;
      x_status_msg := x_status_msg ||
                      'ERROR: At least 1 line must be provided' || chr(13);
      RETURN;
    END IF;

    SELECT MAX(t1.line_number)
      INTO l_max_line_num
      FROM TABLE(CAST(l_line_tab AS xxom_so_lines_tab_type)) t1;

    FOR lr IN 1 .. l_line_tab.count LOOP

      IF l_line_tab(lr).line_number IS NULL THEN
        /*x_status     := fnd_api.g_ret_sts_error;
            x_status_msg := x_status_msg ||
        'ERROR: Line Number must be provided for Item: ' || l_line_tab(lr)
                 .item || chr(13);*/
        l_line_tab(lr).line_number := l_max_line_num + 1;
      END IF;

      IF l_line_tab(lr)
       .item IS NULL AND l_line_tab(lr).inventory_item_id IS NULL THEN
        x_status     := fnd_api.g_ret_sts_error;
        x_status_msg := x_status_msg ||
                        'ERROR: Item code or item ID must be provided for line number: ' || l_line_tab(lr)
                       .line_number || chr(13);
      END IF;
      /*
      if l_line_tab(lr).item_uom is null then
        x_status := fnd_api.G_RET_STS_ERROR;
        x_status_msg := x_status_msg||'ERROR: Item UOM must be provided for line number: '||l_line_tab(lr).line_number||chr(13);
      end if;
      */
      IF l_line_tab(lr)
       .item IS NOT NULL AND l_line_tab(lr).inventory_item_id IS NULL THEN
        l_line_tab(lr).inventory_item_id := xxinv_utils_pkg.get_item_id(l_line_tab(lr).item);

        IF l_line_tab(lr).inventory_item_id IS NULL THEN
          x_status     := fnd_api.g_ret_sts_error;
          x_status_msg := x_status_msg || 'ERROR: Item code : ' || l_line_tab(lr).item ||
                          ' is not valid for line: ' || l_line_tab(lr)
                         .line_number || chr(13);
        END IF;
      END IF;

      IF l_line_tab(lr).item_uom IS NOT NULL AND l_line_tab(lr)
         .inventory_item_id IS NOT NULL THEN
        BEGIN
          SELECT 'Y'
            INTO l_is_valid
            FROM mtl_item_uoms_view
           WHERE inventory_item_id = l_line_tab(lr).inventory_item_id
             AND organization_id =
                 xxinv_utils_pkg.get_master_organization_id
             AND uom_code = l_line_tab(lr).item_uom;
        EXCEPTION
          WHEN no_data_found THEN
            x_status     := fnd_api.g_ret_sts_error;
            x_status_msg := x_status_msg || 'ERROR: Item UOM code : ' || l_line_tab(lr)
                           .item_uom || ' is not valid for line: ' || l_line_tab(lr)
                           .line_number || chr(13);
        END;
      END IF;

      IF l_line_tab(lr).manual_adjustment_amt IS NOT NULL AND l_line_tab(lr)
         .manual_adjustment_amt <> 0 THEN
        -- INC0128351 change check to not equals 0 from gt 0
        IF l_line_tab(lr).manual_adj_mod_line_id IS NULL THEN
          SELECT to_number(attribute5)
            INTO l_line_tab(lr).manual_adj_mod_line_id
            FROM fnd_flex_values ffv, fnd_flex_value_sets ffvs
           WHERE ffvs.flex_value_set_name = 'XXSSYS_EVENT_TARGET_NAME'
             AND ffvs.flex_value_set_id = ffv.flex_value_set_id
             AND upper(ffv.flex_value) = upper(p_request_source)
             AND ffv.enabled_flag = 'Y'
             AND SYSDATE BETWEEN nvl(ffv.start_date_active, SYSDATE - 1) AND
                 nvl(ffv.end_date_active, SYSDATE + 1);
          IF l_line_tab(lr).manual_adj_mod_line_id IS NULL THEN
            x_status     := fnd_api.g_ret_sts_error;
            x_status_msg := x_status_msg ||
                            'ERROR: Manual Adjustment modifier not set in valueset XXSSYS_EVENT_TARGET_NAME: ' || l_line_tab(lr)
                           .line_number || chr(13);
          END IF;
        ELSE
          BEGIN
            SELECT ql.list_line_id
              INTO l_line_tab(lr).manual_adj_mod_line_id
              FROM qp_list_headers_all qh, qp_list_lines ql
             WHERE qh.list_header_id = ql.list_header_id
               AND ql.list_line_id = l_line_tab(lr).manual_adj_mod_line_id
               AND qh.active_flag = 'Y'
               AND SYSDATE BETWEEN nvl(qh.start_date_active, SYSDATE - 1) AND
                   nvl(qh.end_date_active, SYSDATE + 1)
               AND SYSDATE BETWEEN nvl(ql.start_date_active, SYSDATE - 1) AND
                   nvl(ql.end_date_active, SYSDATE + 1)
               AND nvl(ql.automatic_flag, 'N') = 'N'
               AND ql.modifier_level_code = 'LINE'
               AND qh.list_type_code <> 'CHARGES'
               AND qh.pte_code = 'ORDFUL'
               AND ql.arithmetic_operator = 'AMT';
          EXCEPTION
            WHEN no_data_found THEN
              x_status     := fnd_api.g_ret_sts_error;
              x_status_msg := x_status_msg ||
                              'ERROR: Manual Adjustment modifier : ' || l_line_tab(lr)
                             .manual_adj_mod_line_id || ' for line: ' || l_line_tab(lr)
                             .line_number || ' is not valid ' || chr(13);
          END;
        END IF;
      END IF;
    END LOOP;

    x_line_tab := l_line_tab;
    oe_debug_pub.add('SSYS CUSTOM: Line validation status: ' || x_status);
    oe_debug_pub.add('SSYS CUSTOM: Line validation status message: ' ||
                     x_status_msg);
    oe_debug_pub.add('SSYS CUSTOM: Leaving line table validation procedure : validate_order_line');
  EXCEPTION
    WHEN OTHERS THEN
      x_status     := fnd_api.g_ret_sts_error;
      x_status_msg := 'UNEXPECTED ERROR: In validate_order_line ' ||
                      SQLERRM;

      oe_debug_pub.add('SSYS CUSTOM: Line validation status: ' || x_status);
      oe_debug_pub.add('SSYS CUSTOM: Line validation status message: ' ||
                       x_status_msg);
      oe_debug_pub.add('SSYS CUSTOM: Leaving line table validation procedure : validate_order_line');
  END validate_order_line;

  ----------------------------------------------------------------------------
  --  name:          prepare_header_data
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/05/2017
  ----------------------------------------------------------------------------
  --  purpose :      CHG0041891: Build header record for Order processing
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  12/05/2017  Diptasurjya Chatterjee  CHG0041891 - initial build
  --  1.1  12/09/2018  Diptasurjya Chatterjee  CHG0043691 - Handle deal type update
  ----------------------------------------------------------------------------

  FUNCTION prepare_header_data(p_header_rec     IN xxobjt.xxom_so_header_rec_type,
                               p_request_source IN VARCHAR2,
                               p_process_mode   IN VARCHAR2,
                               p_is_dg_order    IN VARCHAR2)
    RETURN oe_order_pub.header_rec_type IS
    l_header_rec     oe_order_pub.header_rec_type;
    l_header_context VARCHAR2(30);

    l_existing_shp_instr VARCHAR2(2000);

  BEGIN

    IF p_request_source = g_strataforce_target THEN
      l_header_rec                 := oe_order_pub.g_miss_header_rec;
      l_header_rec.operation       := p_process_mode;
      l_header_rec.header_id       := p_header_rec.header_id;
      l_header_rec.org_id          := p_header_rec.org_id;
      l_header_rec.order_source_id := p_header_rec.order_source_id;
      l_header_rec.price_list_id   := p_header_rec.price_list_id;
      l_header_rec.end_customer_id := p_header_rec.sf_end_cust_account_id; -- Override header end customer with SFDC data

      l_header_rec.attribute11 := p_header_rec.attribute11; -- CHG0043691 - deal type from SFDC to be updated

      IF p_is_dg_order = 'Y' THEN
        SELECT oh.shipping_instructions
          INTO l_existing_shp_instr
          FROM oe_order_headers_all oh
         WHERE header_id = p_header_rec.header_id;

        IF l_existing_shp_instr IS NULL OR l_existing_shp_instr = '' THEN
          l_header_rec.shipping_instructions := 'DANGEROUS GOOD';
        ELSE
          l_header_rec.shipping_instructions := l_existing_shp_instr ||
                                                ', DANGEROUS GOOD';
        END IF;
      END IF;

      IF p_header_rec.payment_term_id IS NOT NULL THEN
        l_header_rec.payment_term_id := p_header_rec.payment_term_id;
      END IF;
      IF p_header_rec.freight_terms_code IS NOT NULL THEN
        l_header_rec.freight_terms_code := p_header_rec.freight_terms_code;
      END IF;
      IF p_header_rec.fob_code IS NOT NULL THEN
        l_header_rec.fob_point_code := p_header_rec.fob_code;
      END IF;

      SELECT CONTEXT
        INTO l_header_context
        FROM oe_order_headers_all
       WHERE header_id = p_header_rec.header_id;

      IF l_header_context IS NULL THEN
        BEGIN
          l_header_rec.context := fetch_header_flex_context(fetch_order_type_from_header(p_header_rec.header_id));
        EXCEPTION
          WHEN no_data_found THEN
            l_header_rec.context := fnd_api.g_miss_char;
        END;
      END IF;

    END IF;

    RETURN l_header_rec;

  END prepare_header_data;

  ----------------------------------------------------------------------------
  --  name:          prepare_line_data
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/05/2017
  ----------------------------------------------------------------------------
  --  purpose :      CHG0041891: Build line table type for Order processing
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  12/05/2017  Diptasurjya Chatterjee  CHG0041891 - initial build
  --  1.1  12-SEP-18   Roman W.                CHG0043970 - return reason code
  --  2.0  09-Jan-2019 Diptasurjya             CHG0044253 - Populate data for Service Contract lines
  --                                                        specific for Service COntract module implementation
  --  2.1  22-Jan-2019 Diptasurjya             INC0144895 - SC item price fix
  ----------------------------------------------------------------------------

  FUNCTION prepare_line_data(p_header_rec     IN xxobjt.xxom_so_header_rec_type,
                             p_line_tab       IN xxobjt.xxom_so_lines_tab_type,
                             p_request_source IN VARCHAR2,
                             p_process_mode   IN VARCHAR2)
    RETURN oe_order_pub.line_tbl_type IS
    l_line_tbl           oe_order_pub.line_tbl_type;

    -- Start - Change to handle PTO explode
    CURSOR cur_model_items(cp_inventory_item_id NUMBER) IS
      SELECT bic.component_quantity,
             bbo.assembly_item_id,
             bic.component_item_id,
             bic.item_num,
             msib_c.bom_item_type child_bom_item_type
        FROM bom_bill_of_materials_v    bbo,
             bom_inventory_components_v bic,
             mtl_system_items_b         msib_c
       WHERE bbo.bill_sequence_id = bic.bill_sequence_id
         AND bbo.assembly_item_id = cp_inventory_item_id
         AND bbo.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         AND msib_c.organization_id = bbo.organization_id
         AND msib_c.inventory_item_id = bic.component_item_id
         AND SYSDATE BETWEEN nvl(bic.implementation_date, SYSDATE - 1) AND
             nvl(bic.disable_date, SYSDATE + 1)
       ORDER BY bic.item_num;

    CURSOR cur_option_items(cp_inventory_item_id NUMBER) IS
      SELECT bic.component_quantity,
             bbo.assembly_item_id,
             bic.component_item_id,
             bic.item_num
        FROM bom_bill_of_materials_v bbo, bom_inventory_components_v bic
       WHERE bbo.bill_sequence_id = bic.bill_sequence_id
         AND bbo.assembly_item_id = cp_inventory_item_id
         AND bbo.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         AND SYSDATE BETWEEN nvl(bic.implementation_date, SYSDATE - 1) AND
             nvl(bic.disable_date, SYSDATE + 1)
       ORDER BY bic.item_num;
    -- End - Change to handle PTO explode

    l_last_line_index NUMBER; -- Change to handle PTO explode

    l_sc_line_index NUMBER; -- CHG0044253 added for Contract ref line association
  BEGIN

    IF p_request_source = g_strataforce_target THEN
      FOR lr IN 1 .. p_line_tab.count LOOP
        l_line_tbl(lr) := oe_order_pub.g_miss_line_rec;
        l_line_tbl(lr).operation := oe_globals.g_opr_create;
        l_line_tbl(lr).inventory_item_id := p_line_tab(lr).inventory_item_id;
        l_line_tbl(lr).ordered_quantity := p_line_tab(lr).ordered_quantity;
        l_line_tbl(lr).unit_selling_price := p_line_tab(lr)
                                             .unit_selling_price -
                                              nvl(p_line_tab(lr)
                                                  .manual_adjustment_amt,
                                                  0);
        l_line_tbl(lr).unit_list_price := p_line_tab(lr).unit_list_price;
        IF p_line_tab(lr).item_uom IS NOT NULL THEN
          l_line_tbl(lr).order_quantity_uom := p_line_tab(lr).item_uom;
        END IF;

        IF p_header_rec.operation = 23 AND p_line_tab(lr)
          .ordered_quantity < 0 THEN
          l_line_tbl(lr).return_reason_code := 'TRADE IN RETURN';
        elsif p_header_rec.operation = 20 AND p_line_tab(lr) --CHG0043970
             .ordered_quantity < 0 THEN
          --CHG0043970
          l_line_tbl(lr).return_reason_code := fnd_profile.VALUE('XXOM_LINE_RETURN_REASON_CODE'); --CHG0043970
        END IF;

        l_line_tbl(lr).orig_sys_line_ref := p_line_tab(lr)
                                            .external_ref_number;

        --l_line_tbl(lr).tax_value := p_line_tab(lr).tax_value;
        l_line_tbl(lr).calculate_price_flag := p_header_rec.calculate_price_flag;
        BEGIN
          l_line_tbl(lr).context := fetch_line_flex_context(fetch_order_type_from_header(p_header_rec.header_id));
        EXCEPTION
          WHEN no_data_found THEN
            l_line_tbl(lr).context := fnd_api.g_miss_char;
        END;


        /* CHG0044253 - Start assignment of service fields if system relation required and line_number and required by is NULL */
        IF upper(p_line_tab(lr).sf_rel_syst_required) = 'TRUE' THEN
          IF p_line_tab(lr).parent_line_number IS NULL and p_line_tab(lr).Oracle_required_by IS NULL
          THEN

            if p_line_tab(lr).sf_activity_analysis = 'Contracts' then
              l_line_tbl(lr).service_reference_type_code := 'CUSTOMER_PRODUCT';
              l_line_tbl(lr).service_reference_line_id := p_line_tab(lr).sf_serial_external_key;
              l_line_tbl(lr).service_start_date := p_line_tab(lr).sbqq_start_date;
              l_line_tbl(lr).service_end_date := p_line_tab(lr).sbqq_end_date;
              l_line_tbl(lr).accounting_rule_id := 1000;
              l_line_tbl(lr).item_type_code := 'SERVICE';
              l_line_tbl(lr).unit_list_price := p_line_tab(lr).unit_list_price * p_line_tab(lr).ordered_quantity;  -- INC0144895 added
              l_line_tbl(lr).unit_selling_price := (p_line_tab(lr).unit_selling_price
                                                    - nvl(p_line_tab(lr).manual_adjustment_amt,0)) -- 23jan2019 manual adj added
                                                    * p_line_tab(lr).ordered_quantity;  -- INC0144895 added
              l_line_tbl(lr).ordered_quantity := 1;
              l_line_tbl(lr).calculate_price_flag := 'N';  -- INC0144895 added
            end if;
          END IF;
        END IF;
        /* CHG0044253 - End*/

        -- Start - Trade In Logic
        IF p_line_tab(lr).ordered_quantity = -1 THEN
          IF p_line_tab(lr)
           .sf_activity_analysis IN ('Systems (net)', 'Systems-Used') THEN
            l_line_tbl(lr).attribute9 := nvl(p_line_tab(lr)
                                             .sf_related_serial_num,
                                             fnd_api.g_miss_char);
          ELSE
            l_line_tbl(lr).attribute9 := nvl(p_line_tab(lr)
                                             .sf_quote_serial_num,
                                             fnd_api.g_miss_char);
          END IF;
        END IF;
        -- End - Trade In logic

        -- Start - Resin Credit logic
        IF p_line_tab(lr).sf_prod_external_key = 'RESIN_CREDIT' THEN
          l_line_tbl(lr).attribute4 := nvl(to_char(p_line_tab(lr)
                                                   .sf_net_total),
                                           fnd_api.g_miss_char);
        END IF;
        -- End - Resin Credit logic

        --set line level DFF attributes
        l_line_tbl(lr).attribute1 := nvl(p_line_tab(lr).attribute1,
                                         fnd_api.g_miss_char);
        l_line_tbl(lr).attribute2 := nvl(p_line_tab(lr).attribute2,
                                         fnd_api.g_miss_char);
        l_line_tbl(lr).attribute3 := nvl(p_line_tab(lr).attribute3,
                                         fnd_api.g_miss_char);
        IF l_line_tbl(lr).attribute4 IS NULL THEN
          l_line_tbl(lr).attribute4 := nvl(p_line_tab(lr).attribute4,
                                           fnd_api.g_miss_char);
        END IF;
        l_line_tbl(lr).attribute5 := nvl(p_line_tab(lr).attribute5,
                                         fnd_api.g_miss_char);
        l_line_tbl(lr).attribute6 := nvl(p_line_tab(lr).attribute6,
                                         fnd_api.g_miss_char);
        l_line_tbl(lr).attribute7 := nvl(p_line_tab(lr).attribute7,
                                         fnd_api.g_miss_char);
        l_line_tbl(lr).attribute8 := nvl(p_line_tab(lr).attribute8,
                                         fnd_api.g_miss_char);
        IF l_line_tbl(lr).attribute9 IS NULL THEN
          l_line_tbl(lr).attribute9 := nvl(p_line_tab(lr).attribute9,
                                           fnd_api.g_miss_char);
        END IF;
        l_line_tbl(lr).attribute10 := nvl(p_line_tab(lr).attribute10,
                                          fnd_api.g_miss_char);
        l_line_tbl(lr).attribute11 := nvl(p_line_tab(lr).attribute11,
                                          fnd_api.g_miss_char);
        l_line_tbl(lr).attribute12 := nvl(p_line_tab(lr).attribute12,
                                          fnd_api.g_miss_char);
        l_line_tbl(lr).attribute13 := nvl(p_line_tab(lr).attribute13,
                                          fnd_api.g_miss_char);
        l_line_tbl(lr).attribute14 := nvl(p_line_tab(lr).attribute14,
                                          fnd_api.g_miss_char);
        l_line_tbl(lr).attribute15 := nvl(p_line_tab(lr).attribute15,
                                          fnd_api.g_miss_char);

        IF is_item_bom_type_valid(p_line_tab(lr).inventory_item_id) = 'Y' THEN
          l_line_tbl(lr).top_model_line_index := lr;
        END IF;

        l_last_line_index := lr; -- Change to handle PTO explode
      END LOOP;
    END IF;


    -- Start - Change to handle PTO explode
    l_last_line_index := l_last_line_index + 1;

    FOR i IN 1 .. l_line_tbl.count LOOP
      l_sc_line_index := null;  -- CHG0044253 reset variable

      IF is_item_bom_type_valid(l_line_tbl(i).inventory_item_id) = 'Y' THEN
        -- bom_item_type = 1 is Model
        /*if xxssys_strataforce_events_pkg.is_bom_valid(l_line_tbl(i).inventory_item_id,
        xxinv_utils_pkg.get_master_organization_id) = 'Y' then*/
        FOR rec_model IN cur_model_items(l_line_tbl(i).inventory_item_id) LOOP
          l_line_tbl(l_last_line_index) := oe_order_pub.g_miss_line_rec;
          l_line_tbl(l_last_line_index).operation := oe_globals.g_opr_create;
          l_line_tbl(l_last_line_index).order_source_id := p_header_rec.order_source_id;
          l_line_tbl(l_last_line_index).inventory_item_id := rec_model.component_item_id;
          l_line_tbl(l_last_line_index).ordered_quantity := rec_model.component_quantity * l_line_tbl(i).ordered_quantity;
          l_line_tbl(l_last_line_index).top_model_line_index := i;
          l_line_tbl(l_last_line_index).link_to_line_index := i;

          /* CHG0044253 - Start assignment of service fields if system relation required and line_number and/or required by is NOT NULL
                          and parent item is PTO*/

          for sc_rec in (SELECT t1.external_ref_number,t1.inventory_item_id, t1.ordered_quantity, t1.item_uom, t1.unit_list_price, t1.unit_selling_price, nvl(t1.MANUAL_ADJUSTMENT_AMT,0) MANUAL_ADJUSTMENT_AMT
                           FROM TABLE(CAST(p_line_tab AS xxom_so_lines_tab_type)) t1
                          WHERE (t1.parent_line_number = l_line_tbl(i).orig_sys_line_ref
                                 or
                                 t1.Oracle_required_by = l_line_tbl(i).orig_sys_line_ref)
                            AND t1.sf_activity_analysis = 'Contracts'
                            AND upper(t1.sf_rel_syst_required) = 'TRUE') loop

            if xxinv_utils_pkg.get_category_value(1100000222,
                                                  l_line_tbl(l_last_line_index).inventory_item_id,
                                                  g_master_invorg_id) = 'Systems (net)' and
               xxssys_strataforce_events_pkg.is_bom_valid(l_line_tbl(l_last_line_index).inventory_item_id,
                                                          g_master_invorg_id) = 'N' then

              for lind in 1 .. l_line_tbl.count loop
                if l_line_tbl(lind).orig_sys_line_ref = sc_rec.external_ref_number then
                  l_sc_line_index := lind;
                  exit;
                end if;
              end loop;

              l_line_tbl(l_sc_line_index).service_reference_type_code := 'ORDER';
              l_line_tbl(l_sc_line_index).service_line_index := l_last_line_index;
              l_line_tbl(l_sc_line_index).service_duration := sc_rec.ordered_quantity;
              l_line_tbl(l_sc_line_index).service_period := sc_rec.item_uom;
              l_line_tbl(l_sc_line_index).accounting_rule_id := 1000;
              l_line_tbl(l_sc_line_index).item_type_code := 'SERVICE';
              l_line_tbl(l_sc_line_index).unit_list_price := sc_rec.unit_list_price * sc_rec.ordered_quantity;  -- INC0144895 added
              l_line_tbl(l_sc_line_index).unit_selling_price := (sc_rec.unit_selling_price - sc_rec.MANUAL_ADJUSTMENT_AMT) * sc_rec.ordered_quantity;  -- INC0144895 added .. 23jan2019 manual adj added
              l_line_tbl(l_sc_line_index).calculate_price_flag := 'N';  -- INC0144895 added
              l_line_tbl(l_sc_line_index).ordered_quantity := 1;
            end if;
          end loop;

          /* CHG0044253 - End */

          l_last_line_index := l_last_line_index + 1;

        /*if rec_model.child_bom_item_type = 2 then    -- bom_item_type = 2 is Option Class
                                                                                            for rec_option in cur_option_items(rec_model.component_item_id) loop
                                                                                              l_line_tbl(l_last_line_index) := oe_order_pub.g_miss_line_rec;
                                                                                              l_line_tbl(l_last_line_index).operation := oe_globals.g_opr_create;
                                                                                              l_line_tbl(l_last_line_index).inventory_item_id := rec_option.component_item_id;
                                                                                              l_line_tbl(l_last_line_index).ordered_quantity := rec_option.component_quantity*l_line_tbl(i).ordered_quantity;
                                                                                              l_line_tbl(l_last_line_index).top_model_line_index := i;
                                                                                              l_line_tbl(l_last_line_index).link_to_line_index := i;

                                                                                              l_last_line_index := l_last_line_index+1;
                                                                                            end loop;
                                                                                          end if;*/
        END LOOP;
      /* CHG0044253 - Start assignment of service fields if system relation required and line_number and/or required by is NOT NULL
                  and parent item is not PTO */
      ELSE
        for sc_rec in (SELECT t1.external_ref_number,t1.inventory_item_id, t1.ordered_quantity, t1.item_uom, t1.unit_list_price, t1.unit_selling_price, nvl(t1.MANUAL_ADJUSTMENT_AMT,0) MANUAL_ADJUSTMENT_AMT
                         FROM TABLE(CAST(p_line_tab AS xxom_so_lines_tab_type)) t1
                        WHERE (t1.parent_line_number = l_line_tbl(i).orig_sys_line_ref
                               or
                               t1.Oracle_required_by = l_line_tbl(i).orig_sys_line_ref)
                          AND t1.sf_activity_analysis = 'Contracts'
                          AND upper(t1.sf_rel_syst_required) = 'TRUE') loop

            for lind in 1 .. l_line_tbl.count loop
              if l_line_tbl(lind).orig_sys_line_ref = sc_rec.external_ref_number then
                l_sc_line_index := lind;
                exit;
              end if;
            end loop;

            l_line_tbl(l_sc_line_index).service_reference_type_code := 'ORDER';
            l_line_tbl(l_sc_line_index).service_line_index := i;
            l_line_tbl(l_sc_line_index).service_duration := sc_rec.ordered_quantity;
            l_line_tbl(l_sc_line_index).service_period := sc_rec.item_uom;
            l_line_tbl(l_sc_line_index).accounting_rule_id := 1000;
            l_line_tbl(l_sc_line_index).item_type_code := 'SERVICE';
            l_line_tbl(l_sc_line_index).unit_list_price := sc_rec.unit_list_price * sc_rec.ordered_quantity;  -- INC0144895 added
            l_line_tbl(l_sc_line_index).unit_selling_price := (sc_rec.unit_selling_price - sc_rec.MANUAL_ADJUSTMENT_AMT) * sc_rec.ordered_quantity;  -- INC0144895 added .. 23jan2019 manual adj added
            l_line_tbl(l_sc_line_index).ordered_quantity := 1;
            l_line_tbl(l_sc_line_index).calculate_price_flag := 'N';  -- INC0144895 added
        end loop;
      END IF;
    END LOOP;
    -- End - Change to handle PTO explode

    RETURN l_line_tbl;
  END prepare_line_data;

  ----------------------------------------------------------------------------
  --  name:          prepare_line_data
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/05/2017
  ----------------------------------------------------------------------------
  --  purpose :      CHG0041891: Build line table type for Order processing
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  12/05/2017  Diptasurjya Chatterjee  CHG0041891 - initial build
  ----------------------------------------------------------------------------

  FUNCTION prepare_line_split_data(p_header_id      IN NUMBER,
                                   p_request_source IN VARCHAR2,
                                   p_user_id        IN NUMBER)
    RETURN oe_order_pub.line_tbl_type IS

    CURSOR cur_line_to_split IS
      SELECT ol.line_id, ol.ordered_quantity, ol.inventory_item_id
        FROM oe_order_lines_all ol, oe_order_headers_all oh
       WHERE oh.header_id = p_header_id
         AND ol.header_id = oh.header_id
         AND ol.ordered_quantity > 1
         AND is_eligible_for_split(ol.inventory_item_id,
                                   ol.ship_from_org_id,
                                   p_request_source) = 1
      /*and 1=2*/
      ;

    l_line_tbl           oe_order_pub.line_tbl_type;

    l_tbl_indx NUMBER := 0;
  BEGIN

    FOR rec_line_to_split IN cur_line_to_split LOOP
      l_tbl_indx := l_tbl_indx + 1;

      l_line_tbl(l_tbl_indx) := oe_order_pub.g_miss_line_rec;
      l_line_tbl(l_tbl_indx).operation := oe_globals.g_opr_update;
      l_line_tbl(l_tbl_indx).split_by := p_user_id; -- user_id
      l_line_tbl(l_tbl_indx).split_action_code := 'SPLIT';
      l_line_tbl(l_tbl_indx).header_id := p_header_id; -- header_id of the order
      l_line_tbl(l_tbl_indx).line_id := rec_line_to_split.line_id; -- line_id of the order line
      l_line_tbl(l_tbl_indx).ordered_quantity := 1; -- new ordered quantity
      l_line_tbl(l_tbl_indx).change_reason := 'MISC'; -- change reason code */

      FOR cnt IN 1 .. (rec_line_to_split.ordered_quantity - 1) LOOP
        l_tbl_indx := l_tbl_indx + 1;

        l_line_tbl(l_tbl_indx) := oe_order_pub.g_miss_line_rec;
        l_line_tbl(l_tbl_indx).operation := oe_globals.g_opr_create;
        l_line_tbl(l_tbl_indx).split_by := 'USER'; -- Should be the string 'USER'
        l_line_tbl(l_tbl_indx).split_action_code := 'SPLIT';
        l_line_tbl(l_tbl_indx).header_id := p_header_id;
        l_line_tbl(l_tbl_indx).split_from_line_id := rec_line_to_split.line_id; -- line_id of  original line
        l_line_tbl(l_tbl_indx).inventory_item_id := rec_line_to_split.inventory_item_id; -- inventory item id
        l_line_tbl(l_tbl_indx).ordered_quantity := 1;
      END LOOP;
    END LOOP;

    RETURN l_line_tbl;

  END prepare_line_split_data;

  ----------------------------------------------------------------------------
  --  name:          prepare_line_delete_data
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 10/01/2019
  ----------------------------------------------------------------------------
  --  purpose :      CHG0044253: Build line table type for Order processing to delete lines
  --                             When source = STRATAFORCE
  --                             While importing order lines of SERVICE type, we are associating corresponding PTO
  --                             item line to the service line.
  --                             But in case the parent line is a PTO KIT, the import process is not being able to
  --                             identify the PTO child system line and associate the service line with same.
  --                             This is causing the service line to get associated to the PTO parent line, and
  --                             Oracle is automatically generating service lines for all the child items of
  --                             PTO KIT.
  --                             This process will identiy all lines which are associated to the PTO parent and
  --                             non-system child items and mark them for deletion
  --                             This process will also update the remaining service line with proper
  --                             orig_system_line_ref from the deleted line
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  10/01/2019  Diptasurjya Chatterjee  CHG0044253 - initial build
  ----------------------------------------------------------------------------

  FUNCTION prepare_line_delete_data(p_header_id      IN NUMBER,
                                    p_request_source IN VARCHAR2)
    RETURN oe_order_pub.line_tbl_type IS

    CURSOR cur_line_to_delete IS
      SELECT ol.line_id,oos.name order_source_name, ol.orig_sys_line_ref, ol_parent.line_id top_model_line_id, oh.attribute4
        FROM oe_order_lines_all ol,
             oe_order_sources oos,
             oe_order_headers_all oh,
             oe_order_lines_all ol_serv,
             oe_order_lines_all ol_parent
       WHERE oh.header_id = p_header_id
         AND ol.header_id = oh.header_id
         and ol.order_source_id = oos.order_source_id
         AND ol.service_reference_type_code = 'ORDER'
         and ol.item_type_code = 'SERVICE'
         and ol.service_reference_line_id = ol_serv.line_id
         and ol_serv.top_model_line_id = ol_parent.line_id
         and (xxssys_strataforce_events_pkg.is_bom_valid(p_inventory_item_id => ol_serv.inventory_item_id,
                                                        p_organization_id   => g_master_invorg_id) = 'Y'
              or
              (xxinv_utils_pkg.get_category_value(1100000222,ol_serv.inventory_item_id,g_master_invorg_id) <> 'Systems (net)'
               and ol_serv.top_model_line_id = ol_parent.line_id));

    l_line_tbl           oe_order_pub.line_tbl_type;

    l_tbl_indx NUMBER := 0;

    l_orig_sys_line_ref  varchar2(50);
    l_top_model_line_id  number;
    l_order_source_id    number;

    l_exists_in_quote_bkp varchar2(1);
  BEGIN
    if p_request_source = g_strataforce_target then
      FOR rec_line_to_delete IN cur_line_to_delete LOOP
        l_tbl_indx := l_tbl_indx + 1;

        l_line_tbl(l_tbl_indx) := oe_order_pub.g_miss_line_rec;
        l_line_tbl(l_tbl_indx).operation := oe_globals.G_OPR_DELETE;
        l_line_tbl(l_tbl_indx).header_id := p_header_id; -- header_id of the order
        l_line_tbl(l_tbl_indx).line_id := rec_line_to_delete.line_id; -- line_id of the order line

        begin
          select 'Y'
            into l_exists_in_quote_bkp
            from xxcpq_quote_lines_mirr xqm
           where xqm.price_request_number = rec_line_to_delete.attribute4
             and xqm.external_ref_number = rec_line_to_delete.orig_sys_line_ref;
        exception when no_data_found then
          l_exists_in_quote_bkp := 'N';
        end;

        if l_exists_in_quote_bkp = 'Y' then
          l_orig_sys_line_ref := rec_line_to_delete.orig_sys_line_ref;
          l_top_model_line_id := rec_line_to_delete.top_model_line_id;
        end if;
      END LOOP;

      if l_orig_sys_line_ref is not null then
        -- Update orig sys ref from deleted line to the remaining line
        l_tbl_indx := l_tbl_indx + 1;

        l_line_tbl(l_tbl_indx) := oe_order_pub.g_miss_line_rec;
        l_line_tbl(l_tbl_indx).operation := oe_globals.G_OPR_UPDATE;
        l_line_tbl(l_tbl_indx).header_id := p_header_id;


        select ol_serv.line_id
          into l_line_tbl(l_tbl_indx).line_id
          from oe_order_lines_all ol, oe_order_lines_all ol_serv
         where ol.top_model_line_id = l_top_model_line_id
           and ol.line_id = ol_serv.service_reference_line_id
           and ol_serv.service_reference_type_code = 'ORDER'
           and ol_serv.item_type_code = 'SERVICE'
           and xxssys_strataforce_events_pkg.is_bom_valid(p_inventory_item_id => ol.inventory_item_id,
                                                          p_organization_id   => g_master_invorg_id) = 'N'
           and xxinv_utils_pkg.get_category_value(1100000222,ol.inventory_item_id,g_master_invorg_id) = 'Systems (net)'
           and rownum=1;

        l_line_tbl(l_tbl_indx).orig_sys_line_ref := l_orig_sys_line_ref;
      end if;
    end if;

    RETURN l_line_tbl;

  END prepare_line_delete_data;

  ----------------------------------------------------------------------------
  --  name:          prepare_head_adj_data
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/05/2017
  ----------------------------------------------------------------------------
  --  purpose :      CHG0041891: Build header level adjustments table type for Order processing
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  12/05/2017  Diptasurjya Chatterjee  CHG0041891 - initial build
  --  1.1  07/30/2018  Diptasurjya             INC0128351 - Exclude adjustment information which are excluded
  --                                           from SO creation
  --                                           Select information without filter
  ----------------------------------------------------------------------------

  FUNCTION prepare_head_adj_data(p_header_rec     IN xxobjt.xxom_so_header_rec_type,
                                 p_request_source IN VARCHAR2,
                                 p_process_mode   IN VARCHAR2)
    RETURN oe_order_pub.header_adj_tbl_type IS

    CURSOR c_adjustment(p_request_number IN VARCHAR2) IS
      SELECT *
        FROM xx_qp_pricereq_modifiers adj
       WHERE adj.request_number = p_request_number
            --AND    trunc(end_date) IS NULL - INC0128351 commented
         AND request_source = p_request_source
         AND adjustment_level = 'HEADER'
         AND nvl(adj.exclude_for_so, 'N') = 'N' -- INC0128351 add
       ORDER BY line_num, line_adj_num;

    l_header_adj_tbl oe_order_pub.header_adj_tbl_type;
    l_adj_inx        NUMBER;
  BEGIN
    FOR i IN c_adjustment(p_header_rec.price_request_number) LOOP
      l_adj_inx := c_adjustment%ROWCOUNT;

      l_header_adj_tbl(l_adj_inx) := oe_order_pub.g_miss_header_adj_rec;
      l_header_adj_tbl(l_adj_inx).list_header_id := i.list_header_id;
      l_header_adj_tbl(l_adj_inx).list_line_id := i.list_line_id;
      l_header_adj_tbl(l_adj_inx).applied_flag := i.applied_flag;
      l_header_adj_tbl(l_adj_inx).automatic_flag := i.automatic_flag;
      l_header_adj_tbl(l_adj_inx).list_line_type_code := i.list_type_code;
      l_header_adj_tbl(l_adj_inx).update_allowed := i.update_allowed;
      l_header_adj_tbl(l_adj_inx).updated_flag := i.updated_flag;
      l_header_adj_tbl(l_adj_inx).operand := i.operand;
      l_header_adj_tbl(l_adj_inx).adjusted_amount := i.adjusted_amount;
      l_header_adj_tbl(l_adj_inx).adjusted_amount_per_pqty := i.adjusted_amount;
      l_header_adj_tbl(l_adj_inx).range_break_quantity := i.line_quantity;
      l_header_adj_tbl(l_adj_inx).operand_per_pqty := i.operand;
      l_header_adj_tbl(l_adj_inx).pricing_phase_id := i.pricing_phase_id;
      l_header_adj_tbl(l_adj_inx).accrual_flag := i.accrual_flag;
      l_header_adj_tbl(l_adj_inx).source_system_code := 'QP';
      l_header_adj_tbl(l_adj_inx).modifier_level_code := i.modifier_level_code;
      l_header_adj_tbl(l_adj_inx).price_break_type_code := i.price_break_type_code;
      l_header_adj_tbl(l_adj_inx).arithmetic_operator := i.operand_calculation_code;
      l_header_adj_tbl(l_adj_inx).operation := oe_globals.g_opr_create;
    END LOOP;

    RETURN l_header_adj_tbl;
  END prepare_head_adj_data;

  ----------------------------------------------------------------------------
  --  name:          prepare_head_adj_att_data
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/05/2017
  ----------------------------------------------------------------------------
  --  purpose :      CHG0041891: Build line level adjustment attributes table type for Order processing
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  12/05/2017  Diptasurjya Chatterjee  CHG0041891 - initial build
  --  1.1  07/30/2018  Diptasurjya             INC0128351 - Exclude adjustment information which are excluded
  --                                           from SO creation
  --                                           Select adjustment info wihtout end date filter
  ----------------------------------------------------------------------------

  FUNCTION prepare_head_adj_att_data(p_header_rec     IN xxobjt.xxom_so_header_rec_type,
                                     p_request_source IN VARCHAR2,
                                     p_process_mode   IN VARCHAR2)
    RETURN oe_order_pub.header_adj_att_tbl_type IS

    CURSOR c_adjustment(p_request_number IN VARCHAR2) IS
      SELECT *
        FROM xx_qp_pricereq_modifiers adj
       WHERE adj.request_number = p_request_number
            --AND    trunc(end_date) IS NULL - INC0128351 commented
         AND request_source = p_request_source
         AND adjustment_level = 'HEADER'
         AND nvl(adj.exclude_for_so, 'N') = 'N' -- INC0128351 add
       ORDER BY line_num, line_adj_num;

    CURSOR c_attributes(p_request_number IN VARCHAR2) IS
      SELECT *
        FROM xx_qp_pricereq_attributes attrib
       WHERE attrib.request_number = p_request_number
            --AND    trunc(end_date) IS NULL - INC0128351 commented
         AND request_source = p_request_source
         AND adjustment_level = 'HEADER'
         AND nvl(attrib.exclude_for_so, 'N') = 'N' -- INC0128351 add
       ORDER BY line_num, line_adj_num;

    l_header_adj_attrib_tbl oe_order_pub.header_adj_att_tbl_type;
    l_att_inx               NUMBER;
    l_adj_index_hdr_calc    NUMBER;
  BEGIN
    FOR i IN c_attributes(p_header_rec.price_request_number) LOOP
      l_att_inx            := c_attributes%ROWCOUNT;
      l_adj_index_hdr_calc := 1;

      l_header_adj_attrib_tbl(l_att_inx) := oe_order_pub.g_miss_header_adj_att_rec;
      IF i.context_type = 'PRICING_ATTRIBUTE' THEN
        l_header_adj_attrib_tbl(l_att_inx).flex_title := 'QP_ATTR_DEFNS_PRICING';
      ELSE
        l_header_adj_attrib_tbl(l_att_inx).flex_title := 'QP_ATTR_DEFNS_QUALIFIER';
      END IF;

      l_header_adj_attrib_tbl(l_att_inx).adj_index := NULL;

      FOR j IN c_adjustment(p_header_rec.price_request_number) LOOP
        IF i.line_adj_num = j.line_adj_num AND l_header_adj_attrib_tbl(l_att_inx)
          .adj_index IS NULL THEN
          l_header_adj_attrib_tbl(l_att_inx).adj_index := l_adj_index_hdr_calc;
        END IF;

        IF l_header_adj_attrib_tbl(l_att_inx).adj_index IS NOT NULL THEN
          EXIT;
        END IF;
        l_adj_index_hdr_calc := l_adj_index_hdr_calc + 1;
      END LOOP;

      l_header_adj_attrib_tbl(l_att_inx).pricing_context := i.context;
      l_header_adj_attrib_tbl(l_att_inx).pricing_attribute := i.attribute_col;
      l_header_adj_attrib_tbl(l_att_inx).pricing_attr_value_from := i.attr_value_from;
      l_header_adj_attrib_tbl(l_att_inx).pricing_attr_value_to := i.attr_value_to;
      l_header_adj_attrib_tbl(l_att_inx).comparison_operator := i.qual_comp_operator_code;
      l_header_adj_attrib_tbl(l_att_inx).operation := oe_globals.g_opr_create;
    END LOOP;
    RETURN l_header_adj_attrib_tbl;
  END prepare_head_adj_att_data;

  ----------------------------------------------------------------------------
  --  name:          prepare_head_prc_att_data
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/05/2017
  ----------------------------------------------------------------------------
  --  purpose :      CHG0041891: Build header level pricing attributes table type for Order processing
  --                 At present being only used for promo code application
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  12/05/2017  Diptasurjya Chatterjee  CHG0041891 - initial build
  ----------------------------------------------------------------------------

  FUNCTION prepare_head_prc_att_data(p_header_rec     IN xxobjt.xxom_so_header_rec_type,
                                     p_request_source IN VARCHAR2,
                                     p_process_mode   IN VARCHAR2)
    RETURN oe_order_pub.header_price_att_tbl_type IS
    l_header_prc_att_tbl oe_order_pub.header_price_att_tbl_type;
  BEGIN
    IF p_header_rec.ask_for_modifier_id IS NOT NULL THEN
      l_header_prc_att_tbl(1) := oe_order_pub.g_miss_header_price_att_rec;
      l_header_prc_att_tbl(1).flex_title := 'QP_ATTR_DEFNS_QUALIFIER';
      l_header_prc_att_tbl(1).pricing_context := 'MODLIST';
      l_header_prc_att_tbl(1).pricing_attribute1 := p_header_rec.ask_for_modifier_id;
      l_header_prc_att_tbl(1).operation := oe_globals.g_opr_create;
    END IF;
    RETURN l_header_prc_att_tbl;
  END prepare_head_prc_att_data;

  ----------------------------------------------------------------------------
  --  name:          prepare_line_adj_data
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/05/2017
  ----------------------------------------------------------------------------
  --  purpose :      CHG0041891: Build line level adjustments table type for Order processing
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  12/05/2017  Diptasurjya Chatterjee  CHG0041891 - initial build
  --  1.1  07/30/2018  Diptasurjya Chatterjee  INC0128351 - Allow manual adjustment amount to be negative i.e. markup
  --                                                        Exclude adjustment information which are excluded
  --                                                        from SO creation
  --                                                        Select adjustment information without end date filter
  ----------------------------------------------------------------------------

  FUNCTION prepare_line_adj_data(p_header_rec     IN xxobjt.xxom_so_header_rec_type,
                                 p_line_tab       IN xxobjt.xxom_so_lines_tab_type,
                                 p_request_source IN VARCHAR2,
                                 p_process_mode   IN VARCHAR2)
    RETURN oe_order_pub.line_adj_tbl_type IS

    CURSOR c_adjustment(p_request_number IN VARCHAR2) IS
      SELECT *
        FROM xx_qp_pricereq_modifiers adj
       WHERE adj.request_number = p_request_number
            --AND    trunc(end_date) IS NULL - INC0128351 commented
         AND request_source = p_request_source
         AND adjustment_level = 'LINE'
         AND nvl(adj.exclude_for_so, 'N') = 'N' -- INC0128351 add
       ORDER BY line_num, line_adj_num;

    l_line_adj_tbl       oe_order_pub.line_adj_tbl_type;
    l_adj_inx            NUMBER := 0;
    l_line_index_calc    NUMBER;
    l_manual_adj_count   NUMBER;
    l_manual_adj_line_id NUMBER;

    l_manual_adj_amt     number; -- INC0144895
  BEGIN
    FOR i IN c_adjustment(p_header_rec.price_request_number) LOOP
      l_adj_inx         := c_adjustment%ROWCOUNT;
      l_line_index_calc := 1;

      l_line_adj_tbl(l_adj_inx) := oe_order_pub.g_miss_line_adj_rec;
      l_line_adj_tbl(l_adj_inx).line_index := NULL;

      FOR j IN 1 .. p_line_tab.count LOOP
        IF i.line_num = p_line_tab(j).line_number AND l_line_adj_tbl(l_adj_inx)
          .line_index IS NULL THEN
          l_line_adj_tbl(l_adj_inx).line_index := l_line_index_calc;
          --l_manual_adj_amount := p_line_tab(j).manual_adjustment_amt;
          EXIT;
        END IF;

        l_line_index_calc := l_line_index_calc + 1;
      END LOOP;

      l_line_adj_tbl(l_adj_inx).list_header_id := i.list_header_id;
      l_line_adj_tbl(l_adj_inx).list_line_id := i.list_line_id;
      l_line_adj_tbl(l_adj_inx).applied_flag := i.applied_flag;
      l_line_adj_tbl(l_adj_inx).automatic_flag := i.automatic_flag;
      l_line_adj_tbl(l_adj_inx).orig_sys_discount_ref := 'SSYS_SFORCE_PRICE_ADJUSTMENTS' ||
                                                         i.line_num;
      l_line_adj_tbl(l_adj_inx).list_line_type_code := i.list_type_code;
      l_line_adj_tbl(l_adj_inx).update_allowed := i.update_allowed;
      l_line_adj_tbl(l_adj_inx).updated_flag := i.updated_flag;
      l_line_adj_tbl(l_adj_inx).operand := i.operand;
      l_line_adj_tbl(l_adj_inx).adjusted_amount := i.adjusted_amount;
      l_line_adj_tbl(l_adj_inx).adjusted_amount_per_pqty := i.adjusted_amount;
      l_line_adj_tbl(l_adj_inx).range_break_quantity := i.line_quantity;
      l_line_adj_tbl(l_adj_inx).operand_per_pqty := i.operand;
      l_line_adj_tbl(l_adj_inx).pricing_phase_id := i.pricing_phase_id;
      l_line_adj_tbl(l_adj_inx).accrual_flag := i.accrual_flag;
      l_line_adj_tbl(l_adj_inx).source_system_code := 'QP';
      l_line_adj_tbl(l_adj_inx).modifier_level_code := i.modifier_level_code;
      l_line_adj_tbl(l_adj_inx).price_break_type_code := i.price_break_type_code;
      l_line_adj_tbl(l_adj_inx).arithmetic_operator := i.operand_calculation_code;
      l_line_adj_tbl(l_adj_inx).operation := oe_globals.g_opr_create;

    END LOOP;

    /* Start manual adjustment processing */
    SELECT COUNT(1)
      INTO l_manual_adj_count
      FROM TABLE(CAST(p_line_tab AS xxom_so_lines_tab_type)) t1
     WHERE t1.manual_adj_mod_line_id IS NOT NULL;

    IF l_manual_adj_count > 0 THEN
      FOR k IN 1 .. p_line_tab.count LOOP
        IF p_line_tab(k).manual_adjustment_amt IS NOT NULL AND p_line_tab(k)
           .manual_adjustment_amt <> 0 THEN
          -- INC0128351 change check to not equals 0 from gt 0
          l_adj_inx := l_adj_inx + 1;

          l_line_adj_tbl(l_adj_inx) := oe_order_pub.g_miss_line_adj_rec;

          l_line_adj_tbl(l_adj_inx).line_index := k;
          l_line_adj_tbl(l_adj_inx).applied_flag := 'Y';
          l_line_adj_tbl(l_adj_inx).orig_sys_discount_ref := 'SSYS_SFORCE_PRICE_ADJUSTMENTS_MAN' || p_line_tab(k)
                                                            .line_number;
          l_line_adj_tbl(l_adj_inx).updated_flag := 'Y';
          l_line_adj_tbl(l_adj_inx).range_break_quantity := NULL;
          l_line_adj_tbl(l_adj_inx).operation := oe_globals.g_opr_create;

          SELECT qll.list_header_id,
                 qll.list_line_id,
                 qll.automatic_flag,
                 qll.list_line_type_code,
                 qll.pricing_phase_id,
                 qll.accrual_flag,
                 qll.source_system_code,
                 qll.modifier_level_code,
                 qll.price_break_type_code,
                 qll.arithmetic_operator,
                 qll.override_flag
            INTO l_line_adj_tbl(l_adj_inx).list_header_id,
                 l_line_adj_tbl(l_adj_inx).list_line_id,
                 l_line_adj_tbl(l_adj_inx).automatic_flag,
                 l_line_adj_tbl(l_adj_inx).list_line_type_code,
                 l_line_adj_tbl(l_adj_inx).pricing_phase_id,
                 l_line_adj_tbl(l_adj_inx).accrual_flag,
                 l_line_adj_tbl(l_adj_inx).source_system_code,
                 l_line_adj_tbl(l_adj_inx).modifier_level_code,
                 l_line_adj_tbl(l_adj_inx).price_break_type_code,
                 l_line_adj_tbl(l_adj_inx).arithmetic_operator,
                 l_line_adj_tbl(l_adj_inx).update_allowed
            FROM qp_list_lines qll
           WHERE qll.list_line_id = p_line_tab(k).manual_adj_mod_line_id;

          -- Assumption - Manual adjustment will be received in per quantity

          -- INC0144895 start
          l_manual_adj_amt := p_line_tab(k).manual_adjustment_amt;
          if p_line_tab(k).SF_ACTIVITY_ANALYSIS = 'Contracts' then
            l_manual_adj_amt := p_line_tab(k).manual_adjustment_amt*p_line_tab(k).ordered_quantity;
          end if;
          -- INC0144895 end

          l_line_adj_tbl(l_adj_inx).adjusted_amount := -1 * l_manual_adj_amt;
          l_line_adj_tbl(l_adj_inx).adjusted_amount_per_pqty := -1 * l_manual_adj_amt;
          l_line_adj_tbl(l_adj_inx).operand := l_manual_adj_amt;
          l_line_adj_tbl(l_adj_inx).operand_per_pqty := l_manual_adj_amt;

        END IF;
      END LOOP;
    END IF;
    /* End manual adjustment processing */

    RETURN l_line_adj_tbl;
  END prepare_line_adj_data;

  ----------------------------------------------------------------------------
  --  name:          prepare_line_adj_att_data
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/05/2017
  ----------------------------------------------------------------------------
  --  purpose :      CHG0041891: Build line level adjustment attributes table type for Order processing
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  12/05/2017  Diptasurjya Chatterjee  CHG0041891 - initial build
  --  1.1  07/30/2018  Diptasurjya             INC0128351 - Exclude adjustment information which are excluded
  --                                           from SO creation
  --                                           Select adjustment info without end date modifier
  ----------------------------------------------------------------------------

  FUNCTION prepare_line_adj_att_data(p_header_rec     IN xxobjt.xxom_so_header_rec_type,
                                     p_line_tab       IN xxobjt.xxom_so_lines_tab_type,
                                     p_request_source IN VARCHAR2,
                                     p_process_mode   IN VARCHAR2)
    RETURN oe_order_pub.line_adj_att_tbl_type IS

    CURSOR c_attributes(p_request_number IN VARCHAR2) IS
      SELECT *
        FROM xx_qp_pricereq_attributes attrib
       WHERE attrib.request_number = p_request_number
            --AND    trunc(end_date) IS NULL - INC0128351 commented
         AND request_source = p_request_source
         AND adjustment_level = 'LINE'
         AND nvl(attrib.exclude_for_so, 'N') = 'N' -- INC0128351 add
       ORDER BY line_num, line_adj_num;

    CURSOR c_adjustment(p_request_number IN VARCHAR2) IS
      SELECT *
        FROM xx_qp_pricereq_modifiers adj
       WHERE adj.request_number = p_request_number
            --AND    trunc(end_date) IS NULL - INC0128351 commented
         AND request_source = p_request_source
         AND adjustment_level = 'LINE'
         AND nvl(adj.exclude_for_so, 'N') = 'N' -- INC0128351 add
       ORDER BY line_num, line_adj_num;

    l_line_adj_attrib_tbl oe_order_pub.line_adj_att_tbl_type;
    l_att_inx             NUMBER;
    l_adj_index_calc      NUMBER;
  BEGIN
    FOR i IN c_attributes(p_header_rec.price_request_number) LOOP
      l_att_inx        := c_attributes%ROWCOUNT;
      l_adj_index_calc := 1;

      l_line_adj_attrib_tbl(l_att_inx) := oe_order_pub.g_miss_line_adj_att_rec;
      IF i.context_type = 'PRICING_ATTRIBUTE' THEN
        l_line_adj_attrib_tbl(l_att_inx).flex_title := 'QP_ATTR_DEFNS_PRICING';
      ELSE
        l_line_adj_attrib_tbl(l_att_inx).flex_title := 'QP_ATTR_DEFNS_QUALIFIER';
      END IF;

      l_line_adj_attrib_tbl(l_att_inx).adj_index := NULL;
      FOR j IN c_adjustment(p_header_rec.price_request_number) LOOP
        IF i.line_adj_num = j.line_adj_num AND l_line_adj_attrib_tbl(l_att_inx)
          .adj_index IS NULL THEN
          l_line_adj_attrib_tbl(l_att_inx).adj_index := l_adj_index_calc;
        END IF;

        IF l_line_adj_attrib_tbl(l_att_inx).adj_index IS NOT NULL THEN
          EXIT;
        END IF;
        l_adj_index_calc := l_adj_index_calc + 1;
      END LOOP;

      l_line_adj_attrib_tbl(l_att_inx).pricing_context := i.context;
      l_line_adj_attrib_tbl(l_att_inx).pricing_attribute := i.attribute_col;
      l_line_adj_attrib_tbl(l_att_inx).pricing_attr_value_from := i.attr_value_from;
      l_line_adj_attrib_tbl(l_att_inx).pricing_attr_value_to := i.attr_value_to;
      l_line_adj_attrib_tbl(l_att_inx).comparison_operator := i.qual_comp_operator_code;
      l_line_adj_attrib_tbl(l_att_inx).operation := oe_globals.g_opr_create;
    END LOOP;

    RETURN l_line_adj_attrib_tbl;
  END prepare_line_adj_att_data;

  ----------------------------------------------------------------------------
  --  name:          prepare_line_adj_assoc_data
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/05/2017
  ----------------------------------------------------------------------------
  --  purpose :      CHG0041891: Build line level adjustment association table type for Order processing
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  12/05/2017  Diptasurjya Chatterjee  CHG0041891 - initial build
  --  1.1  07/30/2018  Diptasurjya             INC0128351 - Exclude adjustment information which are excluded
  --                                           from SO creation
  --                                           Select adjustment information without end date filter
  ----------------------------------------------------------------------------

  FUNCTION prepare_line_adj_assoc_data(p_header_rec     IN xxobjt.xxom_so_header_rec_type,
                                       p_line_tab       IN xxobjt.xxom_so_lines_tab_type,
                                       p_request_source IN VARCHAR2,
                                       p_process_mode   IN VARCHAR2)
    RETURN oe_order_pub.line_adj_assoc_tbl_type IS

    CURSOR c_assoc(p_request_number IN VARCHAR2) IS
      SELECT *
        FROM xx_qp_pricereq_reltd_adj assoc
       WHERE assoc.request_number = p_request_number
            --AND    trunc(end_date) IS NULL - INC0128351 commented
         AND request_source = p_request_source
         AND adjustment_level = 'LINE'
         AND nvl(assoc.exclude_for_so, 'N') = 'N' -- INC0128351 add
       ORDER BY line_num, line_adj_num;

    CURSOR c_adjustment(p_request_number IN VARCHAR2) IS
      SELECT *
        FROM xx_qp_pricereq_modifiers adj
       WHERE adj.request_number = p_request_number
            --AND    trunc(end_date) IS NULL - INC0128351 commented
         AND request_source = p_request_source
         AND adjustment_level = 'LINE'
         AND nvl(adj.exclude_for_so, 'N') = 'N' -- INC0128351 add
       ORDER BY line_num, line_adj_num;

    l_line_adj_assoc_tbl oe_order_pub.line_adj_assoc_tbl_type;
    l_assoc_inx          NUMBER;
    l_adj_index_calc     NUMBER;
    l_line_index_calc    NUMBER;
  BEGIN
    FOR i IN c_assoc(p_header_rec.price_request_number) LOOP
      l_assoc_inx       := c_assoc%ROWCOUNT;
      l_adj_index_calc  := 1;
      l_line_index_calc := 1;

      l_line_adj_assoc_tbl(l_assoc_inx) := oe_order_pub.g_miss_line_adj_assoc_rec;
      l_line_adj_assoc_tbl(l_assoc_inx).line_index := NULL;

      FOR j IN 1 .. p_line_tab.count LOOP
        IF i.line_num = p_line_tab(j).line_number AND l_line_adj_assoc_tbl(l_assoc_inx)
          .line_index IS NULL THEN
          l_line_adj_assoc_tbl(l_assoc_inx).line_index := l_line_index_calc;
          EXIT;
        END IF;
        l_line_index_calc := l_line_index_calc + 1;
      END LOOP;

      l_line_adj_assoc_tbl(l_assoc_inx).adj_index := NULL;
      l_line_adj_assoc_tbl(l_assoc_inx).rltd_adj_index := NULL;

      FOR j IN c_adjustment(p_header_rec.price_request_number) LOOP
        IF i.line_adj_num = j.line_adj_num AND l_line_adj_assoc_tbl(l_assoc_inx)
          .adj_index IS NULL THEN
          l_line_adj_assoc_tbl(l_assoc_inx).adj_index := l_adj_index_calc;
        END IF;

        IF i.related_line_adj_num = j.line_adj_num AND l_line_adj_assoc_tbl(l_assoc_inx)
          .rltd_adj_index IS NULL THEN
          l_line_adj_assoc_tbl(l_assoc_inx).rltd_adj_index := l_adj_index_calc;
        END IF;

        IF l_line_adj_assoc_tbl(l_assoc_inx).adj_index IS NOT NULL AND l_line_adj_assoc_tbl(l_assoc_inx)
           .rltd_adj_index IS NOT NULL THEN
          EXIT;
        END IF;
        l_adj_index_calc := l_adj_index_calc + 1;
      END LOOP;

      l_line_adj_assoc_tbl(l_assoc_inx).operation := oe_globals.g_opr_create;
    END LOOP;

    RETURN l_line_adj_assoc_tbl;
  END prepare_line_adj_assoc_data;

  ----------------------------------------------------------------------

  --  name:          update_pricing_tables
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/08/2017
  ----------------------------------------------------------------------
  --  purpose :      CHG0041891: Set order_created_flag as 'S' if order
  --                 creation is successful.Else set it as 'E' for error
  --------------------------------------------------------------------------------------------------------------------
  --  ver  date          name                     desc
  --  1.0  12/08/2017    Diptasurjya Chatterjee   CHG0041897 - Initial Build
  ----------------------------------------------------------------------

  PROCEDURE update_pricing_tables(p_request_number IN VARCHAR2,
                                  p_import_status  IN VARCHAR2,
                                  p_request_source IN VARCHAR2,
                                  x_status         OUT VARCHAR2,
                                  x_status_message OUT VARCHAR2) IS

  BEGIN

    UPDATE xx_qp_pricereq_session adj
       SET adj.order_created_flag = p_import_status, adj.end_date = SYSDATE
     WHERE adj.request_number = p_request_number
       AND adj.order_created_flag IS NULL
       AND request_source = p_request_source;

    UPDATE xx_qp_pricereq_modifiers adj
       SET adj.order_created_flag = p_import_status, adj.end_date = SYSDATE
     WHERE adj.request_number = p_request_number
       AND adj.order_created_flag IS NULL
       AND request_source = p_request_source;

    UPDATE xx_qp_pricereq_attributes adj
       SET adj.order_created_flag = p_import_status, adj.end_date = SYSDATE
     WHERE adj.request_number = p_request_number
       AND adj.order_created_flag IS NULL
       AND request_source = p_request_source;

    UPDATE xx_qp_pricereq_reltd_adj adj
       SET adj.order_created_flag = p_import_status, adj.end_date = SYSDATE
     WHERE adj.request_number = p_request_number
       AND adj.order_created_flag IS NULL
       AND request_source = p_request_source;

    x_status         := fnd_api.g_ret_sts_success;
    x_status_message := '';
  EXCEPTION
    WHEN OTHERS THEN
      x_status         := fnd_api.g_ret_sts_error;
      x_status_message := 'UNEXPECTED ERROR: In update_pricing_tables ' ||
                          SQLERRM;
  END update_pricing_tables;

  ----------------------------------------------------------------------------
  --  name:          update_avg_discount_dff
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/06/2017
  ----------------------------------------------------------------------------
  --  purpose :      CHG0041891: Update Avg discount DFF at order header
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  12/05/2017  Diptasurjya Chatterjee  CHG0041891 - initial build
  ----------------------------------------------------------------------------

  PROCEDURE update_avg_discount_dff(p_header_id   IN NUMBER,
                                    x_err_code    OUT VARCHAR2,
                                    x_err_message OUT VARCHAR2) IS
    l_header_rec_upd     oe_order_pub.header_rec_type;
    l_header_rec_upd_out oe_order_pub.header_rec_type;

    l_return_status VARCHAR2(2000);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);

    l_msg_index NUMBER;
    l_data      VARCHAR2(4000);
  BEGIN
    l_header_rec_upd             := oe_order_pub.g_miss_header_rec;
    l_header_rec_upd.operation   := oe_globals.g_opr_update;
    l_header_rec_upd.header_id   := p_header_id;
    l_header_rec_upd.attribute17 := xxoe_utils_pkg.get_order_average_discount(p_header_id => p_header_id);

    oe_order_pub.process_header(p_header_rec     => l_header_rec_upd,
                                x_header_out_rec => l_header_rec_upd_out,
                                x_return_status  => l_return_status,
                                x_msg_count      => l_msg_count,
                                x_msg_data       => l_msg_data);

    IF l_return_status = fnd_api.g_ret_sts_success THEN
      x_err_code    := fnd_api.g_ret_sts_success;
      x_err_message := NULL;
    ELSE
      FOR i IN 1 .. l_msg_count LOOP
        oe_msg_pub.get(p_msg_index     => i,
                       p_encoded       => fnd_api.g_false,
                       p_data          => l_data,
                       p_msg_index_out => l_msg_index);
        --dbms_output.put_line('Msg ' || l_data);
      END LOOP;

      x_err_code    := fnd_api.g_ret_sts_error;
      x_err_message := 'API ERROR: In update_avg_discount_dff: ' || l_data;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code    := fnd_api.g_ret_sts_error;
      x_err_message := 'UNEXPECTED ERROR: In update_avg_discount_dff. ' ||
                       SQLERRM;
  END update_avg_discount_dff;

  ----------------------------------------------------------------------------
  --  name:          update_system_assoc_dff
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/06/2017
  ----------------------------------------------------------------------------
  --  purpose :      CHG0041891: Update Avg discount DFF at order header
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  12/05/2017  Diptasurjya Chatterjee  CHG0041891 - initial build
  --  1.1  28/08/2018  Diptasurjya Chatterjee  INC0131369 - add upper case conversion for checking sf_rel_syst_required
  --  1.2  05/09/2018  Diptasurjya Chatterjee  INC0132115 - Remove instance ID derivation logic as we are already receiving the same
  --  1.3  29-Oct-2018 Lingaraj                CHG0044300 - Ammend "Get Quote Lines"" Interface
  --  1.4  09-Jan-2019 Diptasurjya             CHG0044253 - DFF will not be updated for Contract items
  ----------------------------------------------------------------------------

  PROCEDURE update_line_dff(p_header_id   IN NUMBER,
                                         p_line_tbl    IN xxobjt.xxom_so_lines_tab_type,
                                         x_err_code    OUT VARCHAR2,
                                         x_err_message OUT VARCHAR2) IS

    l_parent_line_id NUMBER;
    l_parent_item_id NUMBER;
    l_line_tbl       xxobjt.xxom_so_lines_tab_type;

    l_line_api_tbl     oe_order_pub.line_tbl_type;
    l_line_api_tbl_out oe_order_pub.line_tbl_type;

    l_return_status VARCHAR2(2000);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);

    l_msg_index NUMBER;
    l_data      VARCHAR2(4000);

    l_line_index      NUMBER := 1;
    l_serial_number   VARCHAR2(240);
    l_concat_segments VARCHAR2(240);
    l_ex_msg          VARCHAR2(500);
    ex_custom_err EXCEPTION;
  BEGIN
    -- Set line ID of all received line records based on the Orig System ref set on each of the order lines
    l_line_tbl := p_line_tbl;

    FOR i IN 1 .. l_line_tbl.count LOOP
      BEGIN
        SELECT line_id
          INTO l_line_tbl(i).line_id
          FROM oe_order_lines_all
         WHERE orig_sys_line_ref = l_line_tbl(i).external_ref_number
           AND header_id = p_header_id;
      EXCEPTION
        WHEN no_data_found OR too_many_rows THEN
          l_ex_msg := 'No matching orig_sys_line_ref found for external_ref_number :' || l_line_tbl(i)
                     .external_ref_number;
          RAISE ex_custom_err;
      END;
    END LOOP;

    -- Loop through all the received lines
    FOR i IN 1 .. l_line_tbl.count LOOP
      -- Check if line is eligible for association with system
      l_serial_number   := '';
      l_concat_segments := '';

      --if is_line_elig_system_assoc(l_line_tbl(i).line_id) = 'Y' then
      IF upper(l_line_tbl(i).sf_rel_syst_required) = 'TRUE' THEN
        -- INC0131369 - Dipta added upper
        -- Use field sent by SFDC instead of using logic in is_line_elig_system_assoc
        IF l_line_tbl(i).parent_line_number IS NULL and l_line_tbl(i).Oracle_required_by IS NULL --29OCT18 for #CHG0044300
        THEN
          if l_line_tbl(i).sf_activity_analysis <> 'Contracts' then  -- CHG0044253 - DFF not updated for Contracts
            l_line_api_tbl(l_line_index) := oe_order_pub.g_miss_line_rec;
            l_line_api_tbl(l_line_index).operation := oe_globals.g_opr_update;
            l_line_api_tbl(l_line_index).line_id := l_line_tbl(i).line_id;


            l_line_api_tbl(l_line_index).attribute14 := l_line_tbl(i).serial_number;

            IF l_line_tbl(i).sf_serial_external_key IS NOT NULL THEN
              l_line_api_tbl(l_line_index).attribute1 := l_line_tbl(i).sf_serial_external_key; -- INC0132115
            END IF;

            l_line_index := l_line_index + 1;
          end if;
        ELSE
          l_parent_line_id := NULL; --29OCT18 for #CHG0044300
          l_parent_item_id := NULL; --29OCT18 for #CHG0044300
          BEGIN
            SELECT t1.line_id, t1.inventory_item_id
              INTO l_parent_line_id, l_parent_item_id
              FROM TABLE(CAST(l_line_tbl AS xxom_so_lines_tab_type)) t1
             WHERE t1.external_ref_number = --l_line_tbl(i).parent_line_number; --Commented  #CHG0044300
                   (Case
                     When l_line_tbl(i).parent_line_number IS NOT NULL THEN --Case added 29OCT18 for #CHG0044300
                      l_line_tbl(i).parent_line_number
                     Else
                      l_line_tbl(i).Oracle_required_by
                   End);
          EXCEPTION
            WHEN OTHERS THEN
              ----Message modified  #CHG0044300
              l_ex_msg := 'Error during matching of external_ref_number with ' || (Case
                            When l_line_tbl(i).parent_line_number IS NOT NULL THEN --Case added 29OCT18 for #CHG0044300
                             'parent_line_number :' || l_line_tbl(i).parent_line_number
                            Else
                             'Oracle_required_by :' || l_line_tbl(i).Oracle_required_by
                          End) || '. Error :' || SQLERRM;
              RAISE ex_custom_err;
          END;

          IF xxssys_strataforce_events_pkg.is_bom_valid(p_inventory_item_id => l_parent_item_id,
                                                        p_organization_id   => g_master_invorg_id
                                                        /*xxinv_utils_pkg.get_master_organization_id*/ --#CHG0044300
                                                        ) = 'Y' THEN
            FOR pto_rec IN (SELECT line_id, inventory_item_id
                              FROM oe_order_lines_all
                             WHERE link_to_line_id = l_parent_line_id
                               AND header_id = p_header_id) LOOP
              IF xxinv_utils_pkg.get_category_value(1100000222,
                                                    pto_rec.inventory_item_id,
                                                    g_master_invorg_id
                                                    /*xxinv_utils_pkg.get_master_organization_id*/ --#CHG0044300
                                                    ) = 'Systems (net)' AND
                 xxssys_strataforce_events_pkg.is_bom_valid(pto_rec.inventory_item_id,
                                                            g_master_invorg_id
                                                            /*xxinv_utils_pkg.get_master_organization_id*/ --#CHG0044300
                                                            ) = 'N' THEN

                if l_line_tbl(i).sf_activity_analysis <> 'Contracts' then  -- CHG0044253 - DFF not updated for Contracts
                  l_line_api_tbl(l_line_index) := oe_order_pub.g_miss_line_rec;
                  l_line_api_tbl(l_line_index).operation := oe_globals.g_opr_update;
                  l_line_api_tbl(l_line_index).line_id := l_line_tbl(i).line_id;
                  l_line_api_tbl(l_line_index).attribute15 := to_char(pto_rec.line_id);

                  l_line_index := l_line_index + 1;
                end if;
                CONTINUE;
              END IF;
            END LOOP;
          ELSE
            if l_line_tbl(i).sf_activity_analysis <> 'Contracts' then  -- CHG0044253 - DFF not updated for Contracts
              l_line_api_tbl(l_line_index) := oe_order_pub.g_miss_line_rec;
              l_line_api_tbl(l_line_index).operation := oe_globals.g_opr_update;
              l_line_api_tbl(l_line_index).line_id := l_line_tbl(i).line_id;
              l_line_api_tbl(l_line_index).attribute15 := to_char(l_parent_line_id);

              l_line_index := l_line_index + 1;
            end if;
          END IF;
        END IF;
      END IF;
    END LOOP;

    if l_line_api_tbl is not null and l_line_api_tbl.count > 0 then
      oe_order_pub.process_line(p_line_tbl      => l_line_api_tbl,
                                x_line_out_tbl  => l_line_api_tbl_out,
                                x_return_status => l_return_status,
                                x_msg_count     => l_msg_count,
                                x_msg_data      => l_msg_data);

      IF l_return_status = fnd_api.g_ret_sts_success THEN
        x_err_code    := fnd_api.g_ret_sts_success;
        x_err_message := NULL;
      ELSE
        FOR i IN 1 .. l_msg_count LOOP
          oe_msg_pub.get(p_msg_index     => i,
                         p_encoded       => fnd_api.g_false,
                         p_data          => l_data,
                         p_msg_index_out => l_msg_index);
        END LOOP;

        x_err_code    := fnd_api.g_ret_sts_error;
        x_err_message := 'API ERROR: In update_line_dff: ' || l_data;
      END IF;
    else
      x_err_code    := fnd_api.g_ret_sts_success;
      x_err_message := 'No Eligible lines found for DFF update';
    end if;
  EXCEPTION
    WHEN ex_custom_err THEN
      x_err_code    := fnd_api.g_ret_sts_error;
      x_err_message := 'UNEXPECTED ERROR: In xxom_salesorder_api.update_line_dff. ' ||
                       l_ex_msg;
    WHEN OTHERS THEN
      x_err_code    := fnd_api.g_ret_sts_error;
      x_err_message := 'UNEXPECTED ERROR: In xxom_salesorder_api.update_line_dff. ' ||
                       SQLERRM;
  END update_line_dff;

  ----------------------------------------------------------------------------
  --  name:          call_order_api
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/06/2017
  ----------------------------------------------------------------------------
  --  purpose :      CHG0041891: Source specific validation and Generic call to standard Sales order processing API
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  12/05/2017  Diptasurjya Chatterjee  CHG0041891 - initial build
  ----------------------------------------------------------------------------

  PROCEDURE call_order_api(pc_header_rec         IN oe_order_pub.header_rec_type,
                           pc_line_tbl           IN oe_order_pub.line_tbl_type,
                           pc_action_tbl         IN oe_order_pub.request_tbl_type,
                           pc_hdr_adj_tbl        IN oe_order_pub.header_adj_tbl_type,
                           pc_hdr_adj_att_tbl    IN oe_order_pub.header_adj_att_tbl_type,
                           pc_hdr_prc_att_tbl    IN oe_order_pub.header_price_att_tbl_type,
                           pc_line_adj_tbl       IN oe_order_pub.line_adj_tbl_type,
                           pc_line_adj_att_tbl   IN oe_order_pub.line_adj_att_tbl_type,
                           pc_line_adj_assoc_tbl IN oe_order_pub.line_adj_assoc_tbl_type,
                           x_err_code            OUT VARCHAR2,
                           x_err_message         OUT VARCHAR2,
                           x_order_number        OUT NUMBER,
                           x_order_header_id     OUT NUMBER) IS

    l_api_version_number NUMBER := 1;
    l_return_status      VARCHAR2(20);
    l_msg_count          NUMBER;
    l_msg_data           VARCHAR2(4000);
    l_msg_index          NUMBER;
    l_data               VARCHAR2(4000);

    l_header_rec_out             oe_order_pub.header_rec_type;
    l_header_val_rec_out         oe_order_pub.header_val_rec_type;
    l_header_adj_tbl_out         oe_order_pub.header_adj_tbl_type;
    l_header_adj_val_tbl_out     oe_order_pub.header_adj_val_tbl_type;
    l_header_price_att_tbl_out   oe_order_pub.header_price_att_tbl_type;
    l_header_adj_att_tbl_out     oe_order_pub.header_adj_att_tbl_type;
    l_header_adj_assoc_tbl_out   oe_order_pub.header_adj_assoc_tbl_type;
    l_header_scredit_tbl_out     oe_order_pub.header_scredit_tbl_type;
    l_header_scredit_val_tbl_out oe_order_pub.header_scredit_val_tbl_type;
    l_line_tbl_out               oe_order_pub.line_tbl_type;
    l_line_val_tbl_out           oe_order_pub.line_val_tbl_type;
    l_line_adj_tbl_out           oe_order_pub.line_adj_tbl_type;
    l_line_adj_val_tbl_out       oe_order_pub.line_adj_val_tbl_type;
    l_line_price_att_tbl_out     oe_order_pub.line_price_att_tbl_type;
    l_line_adj_att_tbl_out       oe_order_pub.line_adj_att_tbl_type;
    l_line_adj_assoc_tbl_out     oe_order_pub.line_adj_assoc_tbl_type;
    l_line_scredit_tbl_out       oe_order_pub.line_scredit_tbl_type;
    l_line_scredit_val_tbl_out   oe_order_pub.line_scredit_val_tbl_type;
    l_lot_serial_tbl_out         oe_order_pub.lot_serial_tbl_type;
    l_lot_serial_val_tbl_out     oe_order_pub.lot_serial_val_tbl_type;
    l_action_request_tbl_out     oe_order_pub.request_tbl_type;
  BEGIN
    oe_order_pub.process_order(p_api_version_number   => l_api_version_number,
                               p_header_rec           => pc_header_rec,
                               p_line_tbl             => pc_line_tbl,
                               p_action_request_tbl   => pc_action_tbl,
                               p_header_adj_tbl       => pc_hdr_adj_tbl,
                               p_header_adj_att_tbl   => pc_hdr_adj_att_tbl,
                               p_header_price_att_tbl => pc_hdr_prc_att_tbl,
                               p_line_adj_tbl         => pc_line_adj_tbl,
                               p_line_adj_att_tbl     => pc_line_adj_att_tbl,
                               p_line_adj_assoc_tbl   => pc_line_adj_assoc_tbl,
                               --p_org_id                 => 737,--pc_header_rec.org_id,
                               --OUT variables
                               x_header_rec             => l_header_rec_out,
                               x_header_val_rec         => l_header_val_rec_out,
                               x_header_adj_tbl         => l_header_adj_tbl_out,
                               x_header_adj_val_tbl     => l_header_adj_val_tbl_out,
                               x_header_price_att_tbl   => l_header_price_att_tbl_out,
                               x_header_adj_att_tbl     => l_header_adj_att_tbl_out,
                               x_header_adj_assoc_tbl   => l_header_adj_assoc_tbl_out,
                               x_header_scredit_tbl     => l_header_scredit_tbl_out,
                               x_header_scredit_val_tbl => l_header_scredit_val_tbl_out,
                               x_line_tbl               => l_line_tbl_out,
                               x_line_val_tbl           => l_line_val_tbl_out,
                               x_line_adj_tbl           => l_line_adj_tbl_out,
                               x_line_adj_val_tbl       => l_line_adj_val_tbl_out,
                               x_line_price_att_tbl     => l_line_price_att_tbl_out,
                               x_line_adj_att_tbl       => l_line_adj_att_tbl_out,
                               x_line_adj_assoc_tbl     => l_line_adj_assoc_tbl_out,
                               x_line_scredit_tbl       => l_line_scredit_tbl_out,
                               x_line_scredit_val_tbl   => l_line_scredit_val_tbl_out,
                               x_lot_serial_tbl         => l_lot_serial_tbl_out,
                               x_lot_serial_val_tbl     => l_lot_serial_val_tbl_out,
                               x_action_request_tbl     => l_action_request_tbl_out,
                               x_return_status          => l_return_status,
                               x_msg_count              => l_msg_count,
                               x_msg_data               => l_msg_data);

    IF l_return_status = fnd_api.g_ret_sts_success THEN
      x_err_code    := fnd_api.g_ret_sts_success;
      x_err_message := NULL;

      x_order_header_id := l_header_rec_out.header_id;
      x_order_number    := l_header_rec_out.order_number;
    ELSE
      FOR i IN 1 .. l_msg_count LOOP
        oe_msg_pub.get(p_msg_index     => i,
                       p_encoded       => fnd_api.g_false,
                       p_data          => l_data,
                       p_msg_index_out => l_msg_index);
        --dbms_output.put_line('Msg ' || l_data);
      END LOOP;

      x_err_code        := fnd_api.g_ret_sts_error;
      x_err_message     := 'API ERROR: In call_order_api: ' || l_data ||
                           fnd_message.get;
      x_order_header_id := NULL;
      x_order_number    := NULL;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code    := fnd_api.g_ret_sts_error;
      x_err_message := 'UNEXPECTED ERROR: In call_order_api. ' || SQLERRM;
  END call_order_api;

  ----------------------------------------------------------------------------
  --  name:          split_line
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/05/2017
  ----------------------------------------------------------------------------
  --  purpose :      CHG0041891: Split order line
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  12/05/2017  Diptasurjya Chatterjee  CHG0041891 - initial build
  ----------------------------------------------------------------------------

  PROCEDURE split_line(p_header_id      IN NUMBER,
                       p_request_source IN VARCHAR2,
                       p_user_id        IN NUMBER,
                       p_err_code       OUT VARCHAR2,
                       p_err_message    OUT VARCHAR2) IS

    l_header_rec            oe_order_pub.header_rec_type;
    l_line_tbl              oe_order_pub.line_tbl_type;
    l_action_request_tbl    oe_order_pub.request_tbl_type;
    l_header_adj_tbl        oe_order_pub.header_adj_tbl_type;
    l_header_adj_attrib_tbl oe_order_pub.header_adj_att_tbl_type;
    l_header_prc_att_tbl    oe_order_pub.header_price_att_tbl_type;
    l_line_adj_tbl          oe_order_pub.line_adj_tbl_type;
    l_line_adj_assoc_tbl    oe_order_pub.line_adj_assoc_tbl_type;
    l_line_adj_attrib_tbl   oe_order_pub.line_adj_att_tbl_type;

    l_api_status          VARCHAR2(1);
    l_api_message         VARCHAR2(4000);
    l_api_order_number    NUMBER;
    l_api_order_header_id NUMBER;

  BEGIN
    /* Start - Null initialize all inputs except line tbl */
    l_action_request_tbl    := oe_order_pub.g_miss_request_tbl;
    l_header_rec            := oe_order_pub.g_miss_header_rec;
    l_header_adj_tbl        := oe_order_pub.g_miss_header_adj_tbl;
    l_header_adj_attrib_tbl := oe_order_pub.g_miss_header_adj_att_tbl;
    l_header_prc_att_tbl    := oe_order_pub.g_miss_header_price_att_tbl;
    l_line_adj_tbl          := oe_order_pub.g_miss_line_adj_tbl;
    l_line_adj_attrib_tbl   := oe_order_pub.g_miss_line_adj_att_tbl;
    l_line_adj_assoc_tbl    := oe_order_pub.g_miss_line_adj_assoc_tbl;
    /* End - Null initialization */
    l_line_tbl := prepare_line_split_data(p_header_id,
                                          p_request_source,
                                          p_user_id);

    IF l_line_tbl IS NOT NULL AND l_line_tbl.count > 0 THEN
      call_order_api(pc_header_rec         => l_header_rec,
                     pc_line_tbl           => l_line_tbl,
                     pc_action_tbl         => l_action_request_tbl,
                     pc_hdr_adj_tbl        => l_header_adj_tbl,
                     pc_hdr_adj_att_tbl    => l_header_adj_attrib_tbl,
                     pc_hdr_prc_att_tbl    => l_header_prc_att_tbl,
                     pc_line_adj_tbl       => l_line_adj_tbl,
                     pc_line_adj_att_tbl   => l_line_adj_attrib_tbl,
                     pc_line_adj_assoc_tbl => l_line_adj_assoc_tbl,
                     x_err_code            => l_api_status,
                     x_err_message         => l_api_message,
                     x_order_number        => l_api_order_number,
                     x_order_header_id     => l_api_order_header_id);

      IF l_api_status = fnd_api.g_ret_sts_success THEN
        p_err_code    := l_api_status;
        p_err_message := '';
      ELSE
        p_err_code    := l_api_status;
        p_err_message := l_api_message;
      END IF;
    ELSE
      p_err_code    := fnd_api.g_ret_sts_success;
      p_err_message := 'No Eligible lines found for Splitting';
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := fnd_api.G_RET_STS_ERROR;
      p_err_message := 'UNEXPECTED ERROR: In split_line ' || SQLERRM;
  END split_line;

  ----------------------------------------------------------------------------
  --  name:          split_line
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 10/01/2019
  ----------------------------------------------------------------------------
  --  purpose :      CHG0044253: Delete order line
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  10/01/2019  Diptasurjya Chatterjee  CHG0044253 - initial build
  ----------------------------------------------------------------------------

  PROCEDURE delete_order_line(p_header_id      IN NUMBER,
                              p_request_source IN VARCHAR2,
                              p_err_code       OUT VARCHAR2,
                              p_err_message    OUT VARCHAR2) IS

    l_header_rec            oe_order_pub.header_rec_type;
    l_line_tbl              oe_order_pub.line_tbl_type;
    l_action_request_tbl    oe_order_pub.request_tbl_type;
    l_header_adj_tbl        oe_order_pub.header_adj_tbl_type;
    l_header_adj_attrib_tbl oe_order_pub.header_adj_att_tbl_type;
    l_header_prc_att_tbl    oe_order_pub.header_price_att_tbl_type;
    l_line_adj_tbl          oe_order_pub.line_adj_tbl_type;
    l_line_adj_assoc_tbl    oe_order_pub.line_adj_assoc_tbl_type;
    l_line_adj_attrib_tbl   oe_order_pub.line_adj_att_tbl_type;

    l_api_status          VARCHAR2(1);
    l_api_message         VARCHAR2(4000);
    l_api_order_number    NUMBER;
    l_api_order_header_id NUMBER;

  BEGIN
    /* Start - Null initialize all inputs except line tbl */
    l_action_request_tbl    := oe_order_pub.g_miss_request_tbl;
    l_header_rec            := oe_order_pub.g_miss_header_rec;
    l_header_adj_tbl        := oe_order_pub.g_miss_header_adj_tbl;
    l_header_adj_attrib_tbl := oe_order_pub.g_miss_header_adj_att_tbl;
    l_header_prc_att_tbl    := oe_order_pub.g_miss_header_price_att_tbl;
    l_line_adj_tbl          := oe_order_pub.g_miss_line_adj_tbl;
    l_line_adj_attrib_tbl   := oe_order_pub.g_miss_line_adj_att_tbl;
    l_line_adj_assoc_tbl    := oe_order_pub.g_miss_line_adj_assoc_tbl;
    /* End - Null initialization */

    l_line_tbl := prepare_line_delete_data(p_header_id,p_request_source);

    IF l_line_tbl IS NOT NULL AND l_line_tbl.count > 0 THEN
      call_order_api(pc_header_rec         => l_header_rec,
                     pc_line_tbl           => l_line_tbl,
                     pc_action_tbl         => l_action_request_tbl,
                     pc_hdr_adj_tbl        => l_header_adj_tbl,
                     pc_hdr_adj_att_tbl    => l_header_adj_attrib_tbl,
                     pc_hdr_prc_att_tbl    => l_header_prc_att_tbl,
                     pc_line_adj_tbl       => l_line_adj_tbl,
                     pc_line_adj_att_tbl   => l_line_adj_attrib_tbl,
                     pc_line_adj_assoc_tbl => l_line_adj_assoc_tbl,
                     x_err_code            => l_api_status,
                     x_err_message         => l_api_message,
                     x_order_number        => l_api_order_number,
                     x_order_header_id     => l_api_order_header_id);

      IF l_api_status = fnd_api.g_ret_sts_success THEN
        p_err_code    := l_api_status;
        p_err_message := '';
      ELSE
        p_err_code    := l_api_status;
        p_err_message := l_api_message;
      END IF;
    ELSE
      p_err_code    := fnd_api.g_ret_sts_success;
      p_err_message := 'No Eligible lines found for deleting';
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := fnd_api.G_RET_STS_ERROR;
      p_err_message := 'UNEXPECTED ERROR: In delete_order_line ' || SQLERRM;
  END delete_order_line;

  --------------------------------------------------------------------
  --  name:          pricing_temp_housekeep
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 04/13/2018
  --------------------------------------------------------------------
  --  purpose :      CHG0041891: This function will check if input header and line details
  --                 has any get item adjustment informtion present in pricing temporary tables.
  --                 If present, program will check if corresponding get item line has
  --                 come as part of input. If no input of get item line was received, then
  --                 remove the related lines, adjustment and adjustment attribute information
  --                 from pricing temporary tables:
  --                 XX_QP_PRICEREQ_RELTD_ADJ, XX_QP_PRICEREQ_MODIFIERS, XX_QP_PRICEREQ_ATTRIBUTES
  ----------------------------------------------------------------------
  --  ver  date          name                 desc
  --  1.0  04/13/2018    Diptasurjya          CHG0041891- Initial build
  ----------------------------------------------------------------------
  FUNCTION pricing_temp_housekeep(p_header_rec xxobjt.xxom_so_header_rec_type,
                                  p_line_tab   xxobjt.xxom_so_lines_tab_type)
    RETURN VARCHAR2 IS
    l_get_line_exists    VARCHAR2(1) := 'N';
  BEGIN
    FOR get_line_rec IN (SELECT xqrld.rowid rid,
                                xqrld.line_num,
                                xqrld.related_line_num,
                                xqrld.line_adj_num,
                                xqrld.related_line_adj_num
                           FROM xx_qp_pricereq_reltd_adj xqrld
                          WHERE xqrld.request_number =
                                p_header_rec.price_request_number
                            AND xqrld.relationship_type_code =
                                'GENERATED_LINE'
                            AND xqrld.request_source = g_strataforce_target) LOOP
      BEGIN
        SELECT 'Y'
          INTO l_get_line_exists
          FROM TABLE(CAST(p_line_tab AS xxom_so_lines_tab_type)) t1
         WHERE t1.line_number = get_line_rec.related_line_num;
      EXCEPTION
        WHEN no_data_found THEN
          l_get_line_exists := 'N';
      END;

      IF l_get_line_exists = 'N' THEN
        -- INC0128351 Comment delete statements update new exclude column instead
        -- This will keep audit histroy of pricing

        /*DELETE FROM xx_qp_pricereq_attributes xqa
         WHERE  xqa.request_number = p_header_rec.price_request_number
         AND    xqa.line_num IN
        (get_line_rec.related_line_num, get_line_rec.line_num)
         AND    xqa.line_adj_num IN
        (get_line_rec.line_adj_num,
          get_line_rec.related_line_adj_num);

         DELETE FROM xx_qp_pricereq_modifiers xqm
         WHERE  xqm.request_number = p_header_rec.price_request_number
         AND    xqm.line_num IN
        (get_line_rec.related_line_num, get_line_rec.line_num)
         AND    xqm.line_adj_num IN
        (get_line_rec.line_adj_num,
          get_line_rec.related_line_adj_num);*/

        -- Delete all attributes of the generated line that has been removed
        /*DELETE FROM xx_qp_pricereq_attributes xqa
        WHERE  xqa.request_number = p_header_rec.price_request_number
        AND    xqa.line_num = get_line_rec.related_line_num
        AND    xqa.request_source = g_strataforce_target;*/

        update xx_qp_pricereq_attributes xqa
           set xqa.exclude_for_so = 'Y',
               xqa.exclude_reason = 'Get line removed from SFDC'
         where xqa.request_number = p_header_rec.price_request_number
           AND xqa.line_num = get_line_rec.related_line_num
           AND xqa.request_source = g_strataforce_target;

        -- Delete all modifier info for generated line that has been removed
        /*DELETE FROM xx_qp_pricereq_modifiers xqm
        WHERE  xqm.request_number = p_header_rec.price_request_number
        AND    xqm.line_num = get_line_rec.related_line_num
        AND    xqm.request_source = g_strataforce_target;*/

        update xx_qp_pricereq_modifiers xqm
           set xqm.exclude_for_so = 'Y',
               xqm.exclude_reason = 'Get line removed from SFDC'
         where xqm.request_number = p_header_rec.price_request_number
           AND xqm.line_num = get_line_rec.related_line_num
           AND xqm.request_source = g_strataforce_target;

        /*DELETE FROM xx_qp_pricereq_reltd_adj xqr
        WHERE  ROWID = get_line_rec.rid;*/

        update xx_qp_pricereq_reltd_adj xqr
           set xqr.exclude_for_so = 'Y',
               xqr.exclude_reason = 'Get line removed from SFDC'
         where ROWID = get_line_rec.rid;
      END IF;

    END LOOP;

    RETURN 'Y';
  END pricing_temp_housekeep;

  --------------------------------------------------------------------
  --  name:          backup_quote
  --  created by:    Lingaraj Sarangi
  --  Revision       1.0
  --  creation date: 05/02/2018
  --------------------------------------------------------------------
  --  purpose :      CHG0041892: This Procedure will create a backup of the
  --                 of the Sales Quote during creating or overwritting a Sales Quote
  ----------------------------------------------------------------------
  --  ver  date          name                 desc
  --  1.0 05-Feb-2018    Lingaraj             CHG0041892- Validation rules and holds on Book
  --  1.1 20-Nov-2018    Lingaraj             CHG0044433 - Get Quote Lines
  ----------------------------------------------------------------------

  PROCEDURE backup_quote(p_header_rec     IN xxobjt.xxom_so_header_rec_type,
                         p_line_tab       IN xxobjt.xxom_so_lines_tab_type,
                         p_request_source IN VARCHAR2,
                         x_err_code       OUT VARCHAR2,
                         x_err_msg        OUT VARCHAR2) IS
  BEGIN
    x_err_code := fnd_api.g_ret_sts_success;
    --Delete exists records from backup tables header /lines (according to source and quote number )
    --Delete Header backup Table
    DELETE xxobjt.xxcpq_quote_header_mirr
     WHERE source_name = p_request_source
       AND price_request_number = p_header_rec.price_request_number;

    --Delete Line backup Table
    DELETE xxobjt.xxcpq_quote_lines_mirr
     WHERE source_name = p_request_source
       AND price_request_number = p_header_rec.price_request_number;

    --Create Header Backup
    INSERT INTO xxobjt.xxcpq_quote_header_mirr
      (source_name,
       price_request_number,
       external_ref_number,
       order_number,
       header_id,
       org_id,
       country_code,
       sold_to_account,
       sold_to_org_id,
       ship_to_org_id,
       invoice_to_org_id,
       ship_to_contact_id,
       sold_to_contact_id,
       invoice_to_contact_id,
       order_source_id,
       order_source,
       currency_code,
       ordered_date,
       operation,
       order_type_name,
       order_type_id,
       cust_po_number,
       shipping_method_code,
       freight_terms_code,
       incoterms,
       fob,
       fob_code,
       payment_term_id,
       contractnumber,
       freightcost,
       freightcosttax,
       price_list_name,
       price_list_id,
       ship_incomplete,
       comments,
       salesrep_id,
       avg_discount_percent,
       pofile,
       pocontenttype,
       ipay_approvalcode,
       ipay_exttoken,
       ipay_customerrefnum,
       ipay_transactionid,
       ipayccnumber,
       ipay_orderidpson,
       ipay_instrid,
       ask_for_modifier_name,
       ask_for_modifier_id,
       calculate_price_flag,
       sf_quote_number,
       sf_quote_status,
       sf_sbqq_primary,
       sf_oppurtunity,
       sf_reseller_account,
       sf_reseller_account_id,
       sf_3rd_party_account,
       sf_3rd_party_account_id,
       sf_end_cust_account,
       sf_end_cust_account_id,
       attribute1,
       attribute2,
       attribute4,
       attribute6,
       attribute7,
       attribute8,
       attribute10,
       attribute11,
       attribute12,
       attribute13,
       attribute14,
       attribute15,
       user_id,
       resp_id,
       appl_id,
       --
       creation_date,
       created_by,
       last_updated_by,
       last_update_date,
       last_update_login)
    VALUES
      (p_request_source,
       p_header_rec.price_request_number,
       p_header_rec.external_ref_number,
       p_header_rec.order_number,
       p_header_rec.header_id,
       p_header_rec.org_id,
       p_header_rec.country_code,
       p_header_rec.sold_to_account,
       p_header_rec.sold_to_org_id,
       p_header_rec.ship_to_org_id,
       p_header_rec.invoice_to_org_id,
       p_header_rec.ship_to_contact_id,
       p_header_rec.sold_to_contact_id,
       p_header_rec.invoice_to_contact_id,
       p_header_rec.order_source_id,
       p_header_rec.order_source,
       p_header_rec.currency_code,
       p_header_rec.ordered_date,
       p_header_rec.operation,
       p_header_rec.order_type_name,
       p_header_rec.order_type_id,
       p_header_rec.cust_po_number,
       p_header_rec.shipping_method_code,
       p_header_rec.freight_terms_code,
       p_header_rec.incoterms,
       p_header_rec.fob,
       p_header_rec.fob_code,
       p_header_rec.payment_term_id,
       p_header_rec.contractnumber,
       p_header_rec.freightcost,
       p_header_rec.freightcosttax,
       p_header_rec.price_list_name,
       p_header_rec.price_list_id,
       p_header_rec.ship_incomplete,
       p_header_rec.comments,
       p_header_rec.salesrep_id,
       p_header_rec.avg_discount_percent,
       p_header_rec.pofile,
       p_header_rec.pocontenttype,
       p_header_rec.ipay_approvalcode,
       p_header_rec.ipay_exttoken,
       p_header_rec.ipay_customerrefnum,
       p_header_rec.ipay_transactionid,
       p_header_rec.ipayccnumber,
       p_header_rec.ipay_orderidpson,
       p_header_rec.ipay_instrid,
       p_header_rec.ask_for_modifier_name,
       p_header_rec.ask_for_modifier_id,
       p_header_rec.calculate_price_flag,
       p_header_rec.sf_quote_number,
       p_header_rec.sf_quote_status,
       p_header_rec.sf_sbqq_primary,
       p_header_rec.sf_oppurtunity,
       p_header_rec.sf_reseller_account,
       p_header_rec.sf_reseller_account_id,
       p_header_rec.sf_3rd_party_account,
       p_header_rec.sf_3rd_party_account_id,
       p_header_rec.sf_end_cust_account,
       p_header_rec.sf_end_cust_account_id,
       p_header_rec.attribute1,
       p_header_rec.attribute2,
       p_header_rec.attribute4,
       p_header_rec.attribute6,
       p_header_rec.attribute7,
       p_header_rec.attribute8,
       p_header_rec.attribute10,
       p_header_rec.attribute11,
       p_header_rec.attribute12,
       p_header_rec.attribute13,
       p_header_rec.attribute14,
       p_header_rec.attribute15,
       p_header_rec.user_id,
       p_header_rec.resp_id,
       p_header_rec.appl_id,
       --
       SYSDATE,
       to_number(fnd_profile.value('USER_ID')),
       to_number(fnd_profile.value('USER_ID')),
       SYSDATE,
       to_number(fnd_profile.value('LOGIN_ID')));
    --Backup Line
    FOR i IN 1 .. p_line_tab.count() LOOP
      INSERT INTO xxobjt.xxcpq_quote_lines_mirr
        (source_name,
         price_request_number,
         external_ref_number,
         header_id,
         line_id,
         line_number,
         item,
         inventory_item_id,
         ordered_quantity,
         unit_list_price,
         unit_selling_price,
         item_uom,
         manual_adjustment_amt,
         manual_adj_mod_line_id,
         total_selling_price,
         tax_value,
         order_source_id,
         order_source,
         item_type,
         --
         sf_line_name,
         parent_line_number,
         sf_line_number,
         sf_activity_analysis,
         sf_billing_type,
         sf_product_hierarchy,
         sf_serial_external_key,
         sf_pto_kit_model,
         serial_number,
         sf_prod_external_key,
         sf_related_serial_num,
         sf_net_total,
         sf_rel_syst_required,
         sf_quote_serial_num,
         --
         attribute1,
         attribute2,
         attribute3,
         attribute4,
         attribute5,
         attribute6,
         attribute7,
         attribute8,
         attribute9,
         attribute10,
         attribute11,
         attribute12,
         attribute13,
         attribute14,
         attribute15,
         --
         creation_date,
         created_by,
         last_updated_by,
         last_update_date,
         last_update_login)
      VALUES
        (p_request_source,
         p_line_tab            (i).price_request_number,
         p_line_tab            (i).external_ref_number,
         p_header_rec.header_id,
         p_line_tab            (i).line_id,
         p_line_tab            (i).line_number,
         p_line_tab            (i).item,
         p_line_tab            (i).inventory_item_id,
         p_line_tab            (i).ordered_quantity,
         p_line_tab            (i).unit_list_price,
         p_line_tab            (i).unit_selling_price,
         p_line_tab            (i).item_uom,
         p_line_tab            (i).manual_adjustment_amt,
         p_line_tab            (i).manual_adj_mod_line_id,
         p_line_tab            (i).total_selling_price,
         p_line_tab            (i).tax_value,
         p_line_tab            (i).order_source_id,
         p_line_tab            (i).order_source,
         p_line_tab            (i).item_type,
         --
         p_line_tab(i).sf_line_name,
         p_line_tab(i).parent_line_number,
         p_line_tab(i).sf_line_number,
         p_line_tab(i).sf_activity_analysis,
         p_line_tab(i).sf_billing_type,
         p_line_tab(i).sf_product_hierarchy,
         p_line_tab(i).sf_serial_external_key,
         p_line_tab(i).sf_pto_kit_model,
         p_line_tab(i).serial_number,
         p_line_tab(i).sf_prod_external_key,
         p_line_tab(i).sf_related_serial_num,
         p_line_tab(i).sf_net_total,
         p_line_tab(i).sf_rel_syst_required,
         p_line_tab(i).sf_quote_serial_num,
         --
         p_line_tab(i).attribute1,
         p_line_tab(i).attribute2,
         p_line_tab(i).attribute3,
         p_line_tab(i).attribute4,
         p_line_tab(i).attribute5,
         p_line_tab(i).attribute6,
         p_line_tab(i).attribute7,
         p_line_tab(i).attribute8,
         p_line_tab(i).attribute9,
         p_line_tab(i).attribute10,
         p_line_tab(i).attribute11,
         p_line_tab(i).attribute12,
         p_line_tab(i).attribute13,
         p_line_tab(i).attribute14,
         p_line_tab(i).attribute15,
         --
         SYSDATE,
         to_number(fnd_profile.value('USER_ID')),
         to_number(fnd_profile.value('USER_ID')),
         SYSDATE,
         to_number(fnd_profile.value('LOGIN_ID')));
    END LOOP;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := fnd_api.g_ret_sts_unexp_error;
      x_err_msg  := 'UNEXPECTED ERROR in xxom_salesorder_api.backup_quote :' ||
                    SQLERRM;
  END backup_quote;

  ----------------------------------------------------------------------------
  --  name:          process_order
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/05/2017
  ----------------------------------------------------------------------------
  --  purpose :      CHG0041891: Source specific validation and Generic call to standard Sales order processing API
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  12/05/2017  Diptasurjya Chatterjee  CHG0041891 - initial build
  --  1.1  05/02/2018  Lingaraj Sarangi        CHG0041892 - Validation rules and holds on Book
  --  1.2  23-Jul-18   Diptasurjya             INC0127595 - Need to Change personalization to requery the order
  --  1.3  07/30/2018  Diptasurjya             INC0128351 - Remove validation check for Pricing line and quote line matching
  --                                           as SFDC can send us lines which were not sent for pricing
  --  1.4  29-Oct-2018   Lingaraj              CHG0044300 - Ammend "Get Quote Lines"" Interface
  --  1.5  10-Jan-2019 Diptasurjya             CHG0044253 - Add line delete code call
  ----------------------------------------------------------------------------

  PROCEDURE process_order(p_header_rec      IN xxobjt.xxom_so_header_rec_type,
                          p_line_tab        IN xxobjt.xxom_so_lines_tab_type,
                          p_request_source  IN VARCHAR2,
                          p_err_code        OUT VARCHAR2,
                          p_err_message     OUT VARCHAR2,
                          p_order_number    OUT NUMBER,
                          p_order_header_id OUT NUMBER) IS

    l_request_source_user    NUMBER;
    l_responsibility_id      NUMBER;
    l_price_calculation_mode VARCHAR2(1);

    l_header_valid_status VARCHAR2(1);
    l_line_valid_status   VARCHAR2(1);
    l_line_split_status   VARCHAR2(1);
    l_line_delete_status  VARCHAR2(1);   -- CHG0044253
    l_prc_tbl_upd_status  VARCHAR2(1);
    l_avg_disc_upd_status VARCHAR2(1);
    l_line_dff_upd_status VARCHAR2(1);

    l_header_status_msg       VARCHAR2(2000);
    l_line_status_msg         VARCHAR2(2000);
    l_line_split_status_msg   VARCHAR2(2000);
    l_line_delete_status_msg  VARCHAR2(2000);  -- CHG0044253
    l_prc_tbl_upd_status_msg  VARCHAR2(2000);
    l_avg_disc_upd_status_msg VARCHAR2(2000);
    l_line_dff_upd_status_msg VARCHAR2(2000);

    l_cust_header_rec xxom_so_header_rec_type;
    l_cust_line_tab   xxom_so_lines_tab_type := xxom_so_lines_tab_type();

    l_debug_profile_value VARCHAR2(1);
    l_debug_file_name     VARCHAR2(2000);

    l_action_request_tbl oe_order_pub.request_tbl_type;

    l_header_rec            oe_order_pub.header_rec_type;
    l_header_adj_tbl        oe_order_pub.header_adj_tbl_type;
    l_header_adj_attrib_tbl oe_order_pub.header_adj_att_tbl_type;
    l_header_prc_att_tbl    oe_order_pub.header_price_att_tbl_type;

    l_line_tbl            oe_order_pub.line_tbl_type;
    l_line_adj_tbl        oe_order_pub.line_adj_tbl_type;
    l_line_adj_attrib_tbl oe_order_pub.line_adj_att_tbl_type;
    l_line_adj_assoc_tbl  oe_order_pub.line_adj_assoc_tbl_type;

    l_api_status          VARCHAR2(1);
    l_api_message         VARCHAR2(4000);
    l_api_order_number    NUMBER;
    l_api_order_header_id NUMBER;

    l_is_order_dg_eligible VARCHAR2(1);

    l_pricing_maint_status VARCHAR2(1);
    l_prc_quote_match      VARCHAR2(1) := 'N';
    e_pricing_maint_exc EXCEPTION;

  BEGIN
    /* Find EBS user for request source */
    BEGIN
      SELECT attribute2, attribute4
        INTO l_request_source_user, l_price_calculation_mode
        FROM fnd_flex_values ffv, fnd_flex_value_sets ffvs
       WHERE ffvs.flex_value_set_name = 'XXSSYS_EVENT_TARGET_NAME'
         AND ffvs.flex_value_set_id = ffv.flex_value_set_id
         AND upper(ffv.flex_value) = upper(p_request_source)
         AND ffv.enabled_flag = 'Y'
         AND SYSDATE BETWEEN nvl(ffv.start_date_active, SYSDATE - 1) AND
             nvl(ffv.end_date_active, SYSDATE + 1);
    EXCEPTION
      WHEN no_data_found THEN
        p_err_code    := fnd_api.g_ret_sts_error;
        p_err_message := 'VALIDATION ERROR: Request source ' ||
                         p_request_source || ' is not valid';
        RETURN;
    END;

    /* EBS user is required - check */
    IF l_request_source_user IS NULL THEN
      p_err_code    := fnd_api.g_ret_sts_error;
      p_err_message := 'VALIDATION ERROR: No EBS user assigned for request source STRATAFORCE in valueset XXSSYS_EVENT_TARGET_NAME ';
      RETURN;
    END IF;

    -- Initialize OM debug based on profile FND:Debug for EBS user
    l_debug_profile_value := fnd_profile.value_specific('AFLOG_ENABLED',
                                                        l_request_source_user);
    IF l_debug_profile_value = 'Y' THEN
      oe_debug_pub.setdebuglevel(5);
      oe_debug_pub.g_dir := fnd_profile.value('OE_DEBUG_LOG_DIRECTORY'); -- Must be registered UTL Directory
      l_debug_file_name  := oe_debug_pub.set_debug_mode('FILE');
      oe_debug_pub.initialize;
      oe_debug_pub.debug_on;
      oe_debug_pub.add('SSYS CUSTOM: OM Debug log location: ' ||
                       l_debug_file_name);
    END IF;

    /* Find OM responsibility against EBS user for apps_initialize */
    /*begin
      select responsibility_id
        into l_responsibility_id
        from fnd_user_resp_groups_all
       where user_id = l_request_source_user
         and responsibility_application_id = 660
         and rownum=1;
    exception when no_data_found then
      p_err_code    := fnd_api.G_RET_STS_ERROR;
      p_err_message := 'VALIDATION ERROR: No OM responsibilities assigned to user '|| l_request_source_user;
      oe_debug_pub.add('SSYS CUSTOM: '||p_err_message);
      oe_debug_pub.add('SSYS CUSTOM: Exiting program xxom_salesorder_api.process_order');
      return;
    end;*/

    validate_order_header(p_header_rec     => p_header_rec,
                          p_request_source => p_request_source,
                          x_header_rec     => l_cust_header_rec,
                          x_status         => l_header_valid_status,
                          x_status_msg     => l_header_status_msg);

    validate_order_line(p_header_rec     => p_header_rec,
                        p_line_tab       => p_line_tab,
                        p_request_source => p_request_source,
                        x_line_tab       => l_cust_line_tab,
                        x_status         => l_line_valid_status,
                        x_status_msg     => l_line_status_msg);

    IF l_header_valid_status = fnd_api.g_ret_sts_error OR
       l_line_valid_status = fnd_api.g_ret_sts_error THEN
      p_err_code    := fnd_api.g_ret_sts_error;
      p_err_message := l_header_status_msg || l_line_status_msg;
      oe_debug_pub.add('SSYS CUSTOM: ' || p_err_message);
      oe_debug_pub.add('SSYS CUSTOM: Exiting program xxom_salesorder_api.process_order');
      ROLLBACK;
      RETURN;
    ELSE
      IF l_cust_header_rec.calculate_price_flag IS NULL THEN
        l_cust_header_rec.calculate_price_flag := nvl(l_price_calculation_mode,
                                                      'N');
      END IF;
    END IF;

    /* perform initializations */
    --fnd_global.apps_initialize(l_request_source_user, l_responsibility_id, 660);
    fnd_global.apps_initialize(l_cust_header_rec.user_id,
                               l_cust_header_rec.resp_id,
                               l_cust_header_rec.appl_id);
    mo_global.set_policy_context('S', l_cust_header_rec.org_id);
    mo_global.init('ONT');

    IF p_request_source = g_strataforce_target THEN
      -- prepare all input table and record types to process_order API
      oe_debug_pub.add('SSYS CUSTOM: Preparing input types for xxom_salesorder_api.process_order');
      BEGIN
        l_action_request_tbl := oe_order_pub.g_miss_request_tbl;

        l_is_order_dg_eligible := is_order_dg_eligible(l_cust_line_tab);

        -- Perform housekeeping on pricing temporary tables
        -- Remove modifier/attribute/related attribute entries in case get line is deleted
        -- NOTE: This will only be done for
        BEGIN
          l_pricing_maint_status := pricing_temp_housekeep(l_cust_header_rec,
                                                           l_cust_line_tab);
        EXCEPTION
          WHEN OTHERS THEN
            p_err_code    := fnd_api.g_ret_sts_error;
            p_err_message := 'UNEXPECTED ERROR: While housekeeping pricing temporary tables for get line removal. ' ||
                             SQLERRM;
            oe_debug_pub.add('SSYS CUSTOM: ' || p_err_message);
            oe_debug_pub.add('SSYS CUSTOM: Exiting program xxom_salesorder_api.process_order');
            RETURN;
        END;

        -- INC0128351 comment below check as we expect lines which did not go through pricing call in SFDC
        /*BEGIN
              SELECT 'Y'
              INTO   l_prc_quote_match
              FROM   dual
              WHERE  (SELECT COUNT(1)
              FROM   TABLE(CAST(p_line_tab AS xxom_so_lines_tab_type)) t1
              WHERE  t1.line_number IN
             (SELECT DISTINCT xqm.line_num
              FROM   xx_qp_pricereq_modifiers xqm
              WHERE  xqm.request_number =
                     l_cust_header_rec.price_request_number
              AND    xqm.request_source = g_strataforce_target)) =
             (SELECT COUNT(DISTINCT xqm.line_num)
              FROM   xx_qp_pricereq_modifiers xqm
              WHERE  xqm.request_number =
             l_cust_header_rec.price_request_number
              AND    xqm.request_source = g_strataforce_target);

              IF l_prc_quote_match = 'N' THEN
        p_err_code    := fnd_api.g_ret_sts_error;
        p_err_message := 'VALIDATION ERROR: The number of lines priced differs from number of lines received for Quote import. ';
        oe_debug_pub.add('SSYS CUSTOM: ' || p_err_message);
        oe_debug_pub.add('SSYS CUSTOM: Exiting program xxom_salesorder_api.process_order');
        RETURN;
              END IF;
            EXCEPTION
              --No Data Found Exception Added : INC0127595
              WHEN NO_DATA_FOUND THEN
                p_err_code    := fnd_api.g_ret_sts_error;
                p_err_message := 'VALIDATION ERROR: The number of lines priced differs from number of lines received for Quote import. ';
                oe_debug_pub.add('SSYS CUSTOM: ' || p_err_message);
                oe_debug_pub.add('SSYS CUSTOM: Exiting program xxom_salesorder_api.process_order');
                RETURN;
              WHEN OTHERS THEN
        p_err_code    := fnd_api.g_ret_sts_error;
        p_err_message := 'UNEXPECTED ERROR: While validating pricing lines and Quote lines. ' ||
                 SQLERRM;
        oe_debug_pub.add('SSYS CUSTOM: ' || p_err_message);
        oe_debug_pub.add('SSYS CUSTOM: Exiting program xxom_salesorder_api.process_order');
        RETURN;
            END;*/
        -- End pricing table housekeeping

        l_header_rec := prepare_header_data(l_cust_header_rec,
                                            p_request_source,
                                            oe_globals.g_opr_update,
                                            l_is_order_dg_eligible);
        l_line_tbl   := prepare_line_data(l_cust_header_rec,
                                          l_cust_line_tab,
                                          p_request_source,
                                          oe_globals.g_opr_create);

        IF l_price_calculation_mode <> 'Y' THEN
          l_header_adj_tbl        := prepare_head_adj_data(l_cust_header_rec,
                                                           p_request_source,
                                                           oe_globals.g_opr_create);
          l_header_adj_attrib_tbl := prepare_head_adj_att_data(l_cust_header_rec,
                                                               p_request_source,
                                                               oe_globals.g_opr_create);
          l_header_prc_att_tbl    := prepare_head_prc_att_data(l_cust_header_rec,
                                                               p_request_source,
                                                               oe_globals.g_opr_create);
          l_line_adj_tbl          := prepare_line_adj_data(l_cust_header_rec,
                                                           l_cust_line_tab,
                                                           p_request_source,
                                                           oe_globals.g_opr_create);
          l_line_adj_attrib_tbl   := prepare_line_adj_att_data(l_cust_header_rec,
                                                               l_cust_line_tab,
                                                               p_request_source,
                                                               oe_globals.g_opr_create);
          l_line_adj_assoc_tbl    := prepare_line_adj_assoc_data(l_cust_header_rec,
                                                                 l_cust_line_tab,
                                                                 p_request_source,
                                                                 oe_globals.g_opr_create);
        ELSE
          l_header_adj_tbl        := oe_order_pub.g_miss_header_adj_tbl;
          l_header_adj_attrib_tbl := oe_order_pub.g_miss_header_adj_att_tbl;
          l_header_prc_att_tbl    := oe_order_pub.g_miss_header_price_att_tbl;
          l_line_adj_tbl          := oe_order_pub.g_miss_line_adj_tbl;
          l_line_adj_attrib_tbl   := oe_order_pub.g_miss_line_adj_att_tbl;
          l_line_adj_assoc_tbl    := oe_order_pub.g_miss_line_adj_assoc_tbl;
        END IF;

        --V1.1 Start - CHG0041892 - Validation rules and holds on Book
        xxom_salesorder_api.backup_quote(p_header_rec     => l_cust_header_rec,
                                         p_line_tab       => l_cust_line_tab,
                                         p_request_source => p_request_source,
                                         x_err_code       => l_api_status,
                                         x_err_msg        => l_api_message);
        IF l_api_status != fnd_api.g_ret_sts_success THEN
          p_err_code    := fnd_api.g_ret_sts_error;
          p_err_message := 'UNEXPECTED ERROR: While creating the backup of the Quote.' ||
                           l_api_message;
          oe_debug_pub.add('SSYS CUSTOM: ' || p_err_message);
          oe_debug_pub.add('SSYS CUSTOM: Exiting program xxom_salesorder_api.process_order');
          RETURN;
        END IF;
        --V1.1 End   - CHG0041892 - Validation rules and holds on Book
      EXCEPTION
        WHEN OTHERS THEN
          p_err_code    := fnd_api.g_ret_sts_error;
          p_err_message := 'UNEXPECTED ERROR: While preparing input types. ' ||
                           SQLERRM;
          oe_debug_pub.add('SSYS CUSTOM: ' || p_err_message);
          oe_debug_pub.add('SSYS CUSTOM: Exiting program xxom_salesorder_api.process_order');
          RETURN;
      END;

      -- Call API to update header and create new lines
      call_order_api(pc_header_rec         => l_header_rec,
                     pc_line_tbl           => l_line_tbl,
                     pc_action_tbl         => l_action_request_tbl,
                     pc_hdr_adj_tbl        => l_header_adj_tbl,
                     pc_hdr_adj_att_tbl    => l_header_adj_attrib_tbl,
                     pc_hdr_prc_att_tbl    => l_header_prc_att_tbl,
                     pc_line_adj_tbl       => l_line_adj_tbl,
                     pc_line_adj_att_tbl   => l_line_adj_attrib_tbl,
                     pc_line_adj_assoc_tbl => l_line_adj_assoc_tbl,
                     x_err_code            => l_api_status,
                     x_err_message         => l_api_message,
                     x_order_number        => l_api_order_number,
                     x_order_header_id     => l_api_order_header_id);

      IF l_api_status = fnd_api.g_ret_sts_success THEN
        -- CHG0044253 - add below order line delete call
        -- Delete Order lines if required
        delete_order_line(p_header_id      => l_header_rec.header_id,
                          p_request_source => p_request_source,
                          p_err_code       => l_line_delete_status,
                          p_err_message    => l_line_delete_status_msg);

        IF l_line_delete_status = fnd_api.G_RET_STS_SUCCESS THEN
        -- CHG0044253 - end line delete call
          -- Call API to split all eligible lines on order
          split_line(p_header_id      => l_header_rec.header_id,
                     p_request_source => p_request_source,
                     p_user_id        => l_request_source_user,
                     p_err_code       => l_line_split_status,
                     p_err_message    => l_line_split_status_msg);

          IF l_line_split_status = fnd_api.g_ret_sts_success THEN
            -- Update Average discount DFF on order header
            IF is_eligible_for_avg_disc(l_header_rec.header_id) = 1 THEN
              update_avg_discount_dff(p_header_id   => l_header_rec.header_id,
                                      x_err_code    => l_avg_disc_upd_status,
                                      x_err_message => l_avg_disc_upd_status_msg);
            ELSE
              l_avg_disc_upd_status := fnd_api.g_ret_sts_success;
            END IF;

            IF l_avg_disc_upd_status = fnd_api.g_ret_sts_success THEN
              -- Update line DFFs
              update_line_dff(p_header_id   => l_header_rec.header_id,  -- CHG0044253 - procedure name changed
                              p_line_tbl    => l_cust_line_tab,
                              x_err_code    => l_line_dff_upd_status,
                              x_err_message => l_line_dff_upd_status_msg);

              IF l_line_dff_upd_status = fnd_api.g_ret_sts_success THEN
                -- Update custom pricing tables
                update_pricing_tables(l_cust_header_rec.price_request_number,
                                      fnd_api.g_ret_sts_success,
                                      p_request_source,
                                      l_prc_tbl_upd_status,
                                      l_prc_tbl_upd_status_msg);

                IF l_prc_tbl_upd_status = fnd_api.g_ret_sts_success THEN
                  p_err_code        := l_line_split_status;
                  p_err_message     := 'Quote lines imported successfully';
                  p_order_number    := l_api_order_number;
                  p_order_header_id := l_api_order_header_id;
                  COMMIT;
                ELSE
                  p_err_code    := l_prc_tbl_upd_status;
                  p_err_message := 'ERROR: Operation: Pricing Tables Update: ' ||
                                   l_prc_tbl_upd_status_msg;
                  ROLLBACK;
                END IF;
              ELSE
                p_err_code    := l_line_dff_upd_status;
                p_err_message := 'ERROR: Operation: Order Line DFF Update: ' ||
                                 l_line_dff_upd_status_msg;
                ROLLBACK;
              END IF;
            ELSE
              p_err_code    := l_avg_disc_upd_status;
              p_err_message := 'ERROR: Operation: Average Discount Update: ' ||
                               l_avg_disc_upd_status_msg;
              ROLLBACK;
            END IF;
          ELSE
            p_err_code    := l_line_split_status;
            p_err_message := 'ERROR: Operation: Line Split: ' ||
                             l_line_split_status_msg;
            ROLLBACK;
          END IF;
        -- CHG0044253 - Line delete error handling
        ELSE
          p_err_code    := l_line_delete_status;
          p_err_message := 'ERROR: Operation: Line Delete: ' || l_line_delete_status_msg;
          ROLLBACK;
        END IF;
        -- CHG0044253 - End Line delete error handling
      ELSE
        p_err_code    := l_api_status;
        p_err_message := 'ERROR: Operation: Line Import: ' || l_api_message;
        ROLLBACK;
      END IF;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := fnd_api.g_ret_sts_error;
      p_err_message := 'UNEXPECTED ERROR: In process_order ' || SQLERRM;
  END process_order;

  --------------------------------------------------------------------
  --  name:          process_quote_lines
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/04/2017
  --------------------------------------------------------------------
  --  purpose :      CHG0041891: This proceure will be called from custom menu option on the
  --                 Sales Order form. It will take quote number (stored on Sales Order header DFF)
  --                 as input and call SOA webservice, which will fetch header/line details of the quote
  --                 from STRATAFORCE and call seperate API to update header and/or create lines in Oracle
  --------------------------------------------------------------------------------------------------------------------
  --  ver  date          name                 desc
  --  1.0 04-DEC-2017    Diptasurjya          CHG0041891 - Initial build
  --  1.1 20-NOV-2018    Lingaraj             CHG0044433 - Get Quote Lines
  --                                          reuse the same Quote number when Order lines are cancelled
  ----------------------------------------------------------------------------------------------------------------------

  PROCEDURE process_quote_lines(x_retcode         OUT NUMBER,
                                x_errbuf          OUT VARCHAR2,
                                p_order_header_id IN NUMBER) IS

    l_quote_number     VARCHAR2(200);
    l_order_number     NUMBER;
    l_org_id           NUMBER;
    l_so_line_count    NUMBER;
    l_quote_orders     VARCHAR2(2000) := 0;
    l_so_header_status VARCHAR2(20);

    l_user_id NUMBER;
    l_resp_id NUMBER;
    l_appl_id NUMBER;

    service_            sys.utl_dbws.service;
    call_               sys.utl_dbws.call;
    service_qname       sys.utl_dbws.qname;
    response            sys.xmltype;
    request             sys.xmltype;
    l_string_type_qname sys.utl_dbws.qname;

    l_err_msg VARCHAR2(2000) := NULL;

    l_ws_q_err_message VARCHAR2(2000);
    l_ws_q_err_code    VARCHAR2(1);
    l_ws_success       VARCHAR2(10);
    l_ws_err_mesage    VARCHAR2(2000);

  BEGIN
    x_retcode := 0;
    fnd_file.put_line(fnd_file.log,
                      'INPUT: Order Header ID: ' || p_order_header_id);
    /* Perform basic validations */
    BEGIN
      -- Fetch quote number from Header DFF
      SELECT ohd.quote_no, oh.order_number, oh.org_id, oh.flow_status_code
        INTO l_quote_number, l_order_number, l_org_id, l_so_header_status
        FROM oe_order_headers_all oh, oe_order_headers_all_dfv ohd
       WHERE oh.header_id = p_order_header_id
         AND oh.rowid = ohd.row_id;

      fnd_file.put_line(fnd_file.log,
                        'DERIVED: Order Number: ' || l_order_number);
      fnd_file.put_line(fnd_file.log, 'DERIVED: Org ID: ' || l_org_id);

      IF l_quote_number IS NULL THEN
        -- Quote number not entered .. throw error
        x_retcode := 2;
        x_errbuf  := 'ERROR: Quote number must be entered on Sales Order Header DFF' ||
                     chr(13);
      END IF;

      IF l_so_header_status <> 'ENTERED' THEN
        x_retcode := 2;
        x_errbuf  := x_errbuf ||
                     'ERROR: Sales order must be in ENTERED state, to add quote lines' ||
                     chr(13);
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        -- Order information not valid
        x_retcode := 2;
        x_errbuf  := 'ERROR: Order not found';
    END;

    -- Check Quote no duplicate
    IF l_quote_number IS NOT NULL THEN
      BEGIN
        SELECT listagg(oh.order_number, ',') within GROUP(ORDER BY oh.order_number)
          INTO l_quote_orders
          FROM oe_order_headers_all oh, oe_order_headers_all_dfv ohd
         WHERE oh.rowid = ohd.row_id
           AND ohd.quote_no = l_quote_number
           AND oh.flow_status_code <> 'CANCELLED'
           AND oh.header_id <> p_order_header_id
           AND xxoe_utils_pkg.get_order_status_for_sforce(oh.header_id) <>
               'CANCELLED' --CHG0044433
        ;

        IF l_quote_orders IS NOT NULL THEN
          x_retcode := 2;
          x_errbuf  := 'ERROR: Quote no ' || l_quote_number ||
                       ' already exists on other orders: ' ||
                       l_quote_orders;
        END IF;
      EXCEPTION
        WHEN no_data_found THEN
          NULL;
      END;
    END IF;

    -- Get number of lines existing for order
    SELECT COUNT(1)
      INTO l_so_line_count
      FROM oe_order_lines_all ol
     WHERE ol.header_id = p_order_header_id;

    IF l_so_line_count <> 0 THEN
      -- Existing line count not 0 for order .. throw error
      x_retcode := 2;
      x_errbuf  := x_errbuf ||
                   'ERROR: You cannot get Quote lines for an Order that already contains lines. Please delete the lines or open a separate Order';
    END IF;

    IF x_retcode <> 0 THEN
      fnd_file.put_line(fnd_file.log, 'VALIDATION ' || x_errbuf);
      RETURN;
    END IF;
    /* End validations */

    l_user_id := fnd_global.user_id;
    l_resp_id := fnd_global.resp_id;
    l_appl_id := fnd_global.resp_appl_id;

    /* Start webservice call processing */
    fnd_file.put_line(fnd_file.log,
                      'BPEL CALL: Starting BPEL connection processing');
    service_qname       := sys.utl_dbws.to_qname('http://www.stratasys.dmn/QuoteLineRequest',
                                                 'QuoteLineRequest');
    l_string_type_qname := sys.utl_dbws.to_qname('http://www.w3.org/2001/XMLSchema',
                                                 'string');
    service_            := sys.utl_dbws.create_service(service_qname);
    call_               := sys.utl_dbws.create_call(service_);

    fnd_file.put_line(fnd_file.log,
                      'XXOBJT_SF2OA_SOA_SRV_NUM=' ||
                      fnd_profile.value('XXOBJT_SF2OA_SOA_SRV_NUM'));

    IF nvl(fnd_profile.value('XXOBJT_SF2OA_SOA_SRV_NUM'), '1') = '1' THEN
      sys.utl_dbws.set_target_endpoint_address(call_,
                                               xxobjt_bpel_utils_pkg.get_bpel_host_srv1 ||
                                               '/soa-infra/services/sfdc/processQuoteLinesCmp/processquotelinesbpel_client_ep?WSDL');

    ELSE
      sys.utl_dbws.set_target_endpoint_address(call_,
                                               xxobjt_bpel_utils_pkg.get_bpel_host_srv2 ||
                                               '/soa-infra/services/sfdc/processQuoteLinesCmp/processquotelinesbpel_client_ep?WSDL');

    END IF;

    sys.utl_dbws.set_property(call_, 'SOAPACTION_USE', 'TRUE');
    sys.utl_dbws.set_property(call_, 'SOAPACTION_URI', 'process');
    sys.utl_dbws.set_property(call_, 'OPERATION_STYLE', 'document');
    sys.utl_dbws.set_property(call_,
                              'ENCODINGSTYLE_URI',
                              'http://schemas.xmlsoap.org/soap/encoding/');

    sys.utl_dbws.set_return_type(call_, l_string_type_qname);
    -- Set request input
    request := sys.xmltype('<quot:processQuoteLineRequest xmlns:quot="http://www.stratasys.dmn/QuoteLineRequest">
              <quot:HeaderInfo>
    <quot:source_name>' || g_strataforce_target ||
                           '</quot:source_name>
    <quot:source_reference_id>' || l_quote_number ||
                           '</quot:source_reference_id>
          </quot:HeaderInfo>
          <quot:Quote_Details>
    <quot:So_Header_Id>' || p_order_header_id ||
                           '</quot:So_Header_Id>
    <quot:User_Id>' || l_user_id ||
                           '</quot:User_Id>
    <quot:Resp_Id>' || l_resp_id ||
                           '</quot:Resp_Id>
    <quot:Appl_Id>' || l_appl_id ||
                           '</quot:Appl_Id>
    <quot:Quote_Number>' || l_quote_number ||
                           '</quot:Quote_Number>
    <quot:Order_Number>' || l_order_number ||
                           '</quot:Order_Number>
          </quot:Quote_Details>
            </quot:processQuoteLineRequest>');

    response := sys.utl_dbws.invoke(call_, request);
    sys.utl_dbws.release_call(call_);
    sys.utl_dbws.release_service(service_);

    SELECT response.extract('//Err_Code/text()', 'xmlns:tns="http://www.stratasys.dmn/processQuoteLineResponse" xmlns="http://www.stratasys.dmn/processQuoteLineResponse"')
           .getstringval(),
           response.extract('//Err_Message/text()', 'xmlns:tns="http://www.stratasys.dmn/processQuoteLineResponse" xmlns="http://www.stratasys.dmn/processQuoteLineResponse"')
           .getstringval(),
           response.extract('//isSuccess/text()', 'xmlns:tns="http://www.stratasys.dmn/processQuoteLineResponse" xmlns="http://www.stratasys.dmn/processQuoteLineResponse"')
           .getstringval(),
           response.extract('//errorMessgae/text()', 'xmlns:tns="http://www.stratasys.dmn/processQuoteLineResponse" xmlns="http://www.stratasys.dmn/processQuoteLineResponse"')
           .getstringval()
      INTO l_ws_q_err_code,
           l_ws_q_err_message,
           l_ws_success,
           l_ws_err_mesage
      FROM dual;

    IF l_ws_q_err_code IS NULL THEN
      x_retcode := 2;
      x_errbuf  := 'ERROR: ' || l_ws_err_mesage;
    ELSE
      IF l_ws_q_err_code = fnd_api.g_ret_sts_error THEN
        x_retcode := 2;
        x_errbuf  := l_ws_q_err_message;
      ELSE
        x_retcode := 0;
        x_errbuf  := l_ws_q_err_message;
      END IF;
    END IF;

    fnd_file.put_line(fnd_file.log,
                      'Webservice response - ' || response.getstringval());

  EXCEPTION
    WHEN OTHERS THEN

      l_err_msg := 'ERROR: While processing BPEL for quote :' ||
                   l_quote_number || ' for Order Header ID: ' ||
                   p_order_header_id || ' ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, l_err_msg);
      sys.utl_dbws.release_call(call_);
      sys.utl_dbws.release_service(service_);
      x_retcode := 2;
      x_errbuf  := l_err_msg;
  END process_quote_lines;

  PROCEDURE insert_test_order_lines(x_status         OUT VARCHAR2,
                                    x_status_message OUT VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    i                INTEGER;
    l_status         VARCHAR2(1);
    l_status_message VARCHAR2(2000);
    l_err_code       VARCHAR2(5);
    l_order_no       NUMBER;
    l_header_id      NUMBER;
    l_order_status   VARCHAR2(30);

    l_order_header xxom_so_header_rec_type;
    l_order_lines  xxom_so_lines_tab_type := xxom_so_lines_tab_type();
  BEGIN
    l_order_header := xxom_so_header_rec_type(NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL);

    --l_order_header.order_number := 891;
    l_order_header.price_request_number := 10123;
    --l_order_header.Org_id :=737;
    --l_order_header.sold_to_org_id:=2116049;--2120269;
    --l_order_header.ship_to_org_id:= 169660;--145176;
    --l_order_header.invoice_to_org_id :=133211;
    --l_order_header.ship_to_contact_id :=4787094;
    --l_order_header.sold_to_contact_id:=4787094;
    --l_order_header.invoice_to_contact_id :=4787094;
    --l_order_header.ordered_date := '05-JAN-2016 14:07:11';
    --l_order_header.operation :=12;
    --l_order_header.cust_po_number := '125078 ON';
    --l_order_header.shipping_method_code :='000001_UPS_L_GND';
    l_order_header.freight_terms_code := 'PRE2010';
    l_order_header.payment_term_id    := 1003;
    l_order_header.header_id          := 1751643;
    --l_order_header.freightCost :=16.79;
    --l_order_header.freightCostTax :=0.0;
    l_order_header.price_list_id       := 9053;
    l_order_header.sf_quote_number     := 'Q-12345';
    l_order_header.sf_end_cust_account := '42305';
    l_order_header.fob_code            := 'DESTINATION';
    l_order_header.operation           := 20;
    l_order_header.sf_oppurtunity      := 'TEST-OP';
    l_order_header.sf_quote_status     := 'APPROVED';
    l_order_header.sf_sbqq_primary     := 'TRUE';
    l_order_header.user_id             := 19933;
    l_order_header.resp_id             := 50587;
    l_order_header.appl_id             := 660;
    --l_order_header.splitOrder :='N';
    --l_order_header.comments := null;
    --l_order_header.salesrep_id := -3;
    --l_order_header.order_source_name := 'eCommerce Order';

    l_order_lines.extend();
    l_order_lines(1) := xxom_so_line_rec_type(NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,null,null);

    /*l_order_lines(1).line_number := 101;
        l_order_lines(1).inventory_item_id := 953150;
        l_order_lines(1).unit_selling_price := 260000;
        l_order_lines(1).unit_list_price := 260000;
        l_order_lines(1).tax_value := 0.0;
        l_order_lines(1).ordered_quantity := 1;
        l_order_lines(1).item_uom := 'DZ';

        l_order_lines.extend();
        l_order_lines(2) := xxom_so_line_rec_type(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
    NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
        l_order_lines(2).line_number := 102;
        l_order_lines(2).inventory_item_id := 953150;
        l_order_lines(2).unit_selling_price := 260000;
        l_order_lines(2).unit_list_price := 260000;
        l_order_lines(2).tax_value := 0.0;
        l_order_lines(2).ordered_quantity := 2;
        l_order_lines(2).item_uom := 'EA';

        l_order_lines.extend();
        l_order_lines(3) := xxom_so_line_rec_type(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
    NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
        l_order_lines(3).line_number := 103;
        l_order_lines(3).inventory_item_id := 1105806;
        l_order_lines(3).unit_selling_price := 45900;
        l_order_lines(3).unit_list_price := 45900;
        l_order_lines(3).tax_value := 0.0;
        l_order_lines(3).ordered_quantity := 4;
        l_order_lines(3).item_uom := 'EA';

        l_order_lines.extend();
        l_order_lines(4) := xxom_so_line_rec_type(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
    NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
        l_order_lines(4).line_number := 104;
        l_order_lines(4).inventory_item_id := 1311737;
        l_order_lines(4).unit_selling_price := 0;
        l_order_lines(4).unit_list_price := 480.0;
        l_order_lines(4).tax_value := 0.0;
        l_order_lines(4).ordered_quantity := 2;
        l_order_lines(4).item_uom := 'EA';*/

    l_order_lines.extend();
    l_order_lines(1) := xxom_so_line_rec_type(NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,null,null);
    l_order_lines(1).line_number := 101;
    l_order_lines(1).inventory_item_id := 18993;
    l_order_lines(1).unit_selling_price := 0;
    l_order_lines(1).unit_list_price := 546.0;
    l_order_lines(1).tax_value := 0.0;
    l_order_lines(1).ordered_quantity := 2;
    l_order_lines(1).item_uom := 'EA';

    /*l_order_lines.extend();
        l_order_lines(6) := xxom_so_line_rec_type(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
    NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
        l_order_lines(6).line_number := 106;
        l_order_lines(6).inventory_item_id := 632005;
        l_order_lines(6).unit_selling_price := 0;
        l_order_lines(6).unit_list_price := 517.0;
        l_order_lines(6).tax_value := 0.0;
        l_order_lines(6).ordered_quantity := 2;
        l_order_lines(6).item_uom := 'EA';*/

    xxom_salesorder_api.process_order(p_header_rec      => l_order_header,
                                      p_line_tab        => l_order_lines,
                                      p_request_source  => 'STRATAFORCE',
                                      p_err_code        => l_status,
                                      p_err_message     => l_status_message,
                                      p_order_number    => l_order_no,
                                      p_order_header_id => l_header_id);

    --dbms_output.put_line(l_status);
    --dbms_output.put_line(l_status_message);
    IF l_status = 'S' THEN
      dbms_output.put_line(l_order_no);
      COMMIT;
    ELSE
      ROLLBACK;
    END IF;

    x_status         := l_status;
    x_status_message := l_status_message;
  END insert_test_order_lines;

  --------------------------------------------------------------------
  --  name:          process_quote_lines
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 12/04/2017
  --------------------------------------------------------------------
  --  purpose :      CHG0041891: This proceure will be called from custom menu option on the
  --                 Sales Order form. It will take quote number (stored on Sales Order header DFF)
  --                 as input and call SOA webservice, which will fetch header/line details of the quote
  --                 from STRATAFORCE and call seperate API to update header and/or create lines in Oracle
  --------------------------------------------------------------------------------------------------------------------
  --  ver  date          name                 desc
  --  1.0 04-DEC-2017    Diptasurjya          CHG0041891 - Initial build
  --  1.1 23-Jul-18      Diptasurjya          INC0127595 - Need to Change personalization to requery the order
  ----------------------------------------------------------------------------------------------------------------------

  FUNCTION process_quote_lines(p_order_header_id IN NUMBER) RETURN VARCHAR2 IS
    l_status         VARCHAR2(10);
    l_status_message VARCHAR2(2000);
  BEGIN
    process_quote_lines(l_status, l_status_message, p_order_header_id);

    /*if l_status = 0 then
      insert_test_order_lines(l_status,l_status_message);
    end if;*/

    IF l_status = 0 THEN
      --INC0127595 Commented.
      RETURN l_status_message; -- || chr(10) || chr(10) || 'Re-Query order to load changes';
    ELSE
      RETURN l_status_message;
    END IF;

  END process_quote_lines;

  --------------------------------------------------------------------
  --  name:          validate_quote
  --  created by:    Lingaraj Sarangi
  --  Revision       1.0
  --  creation date: 05/02/2018
  --------------------------------------------------------------------
  --  purpose :      CHG0041892: Will be Called from Sales Order Form Personilization
  --                 ??????ERROR MESSAGE
  ----------------------------------------------------------------------
  --  ver  date          name              Desc
  --  1.0 05-Feb-2017    Lingaraj          CHG0041892- Validation rules and holds on Book
  --  1.1 07/20/2018     Diptasurjya       INC0127218 -
  --                                          Bug 1. FREIGHT items need to be exlcuded from SFDC side data also before comparing lines from SFDC and Oracle
  --                                          Bug 2. Order amount calculated from Oracle order lines should be rounded
  --  1.2 20-Nov-2018   Lingaraj           CHG0044433 - Get Quote Lines
  --  1.3 03-Dec-2018   LIngaraj           CHG0044433/CTASK0039554 - Order Validation Logic Change During booking
  --  1.4 22-Jan-2019   Diptasurjya        INC0144895 - Change validation codes for SC items
  --  1.5 28-Jan-2019   Diptasurjya        INC0145470 - Change validation codes for SC items
  ----------------------------------------------------------------------
  FUNCTION validate_quote(p_header_id      NUMBER,
                          p_quote_number   VARCHAR2,
                          p_price_list_id  NUMBER,
                          p_request_source VARCHAR2) RETURN VARCHAR2 IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    CURSOR c_all_product_exits1 IS
      SELECT ql.item, SUM(ql.ordered_quantity) ordered_quantity
        FROM xxobjt.xxcpq_quote_lines_mirr ql, mtl_system_items_b msib -- INC0127218
       WHERE ql.price_request_number = p_quote_number
         AND ql.source_name = p_request_source
         AND ql.inventory_item_id = msib.inventory_item_id -- INC0127218
         AND msib.organization_id =
             xxinv_utils_pkg.get_master_organization_id -- INC0127218
            -- INC0127218 - Add below exclusion
         AND msib.item_type NOT IN
             (fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'),
              fnd_profile.value('XXAR_FREIGHT_AR_ITEM'))
       GROUP BY ql.item
      MINUS
      SELECT msib.segment1 item,
             SUM(
             decode(line_category_code,
                    'RETURN',
                    --(decode(ol.item_type_code,'SERVICE',ol.service_duration, ol.ordered_quantity)) * -1,  -- INC0144895 handle SERVICE item quantity  -- INC0145470 commented
                    --(decode(ol.item_type_code,'SERVICE',ol.service_duration, ol.ordered_quantity))  --INC0140978  INC0144895 - handle SERVICE item quantity -- INC0145470 commented
                    (decode(nvl(ol.service_reference_type_code,'X'),'ORDER',ol.service_duration, ol.ordered_quantity)) * -1,  -- INC0145470 added
                    (decode(nvl(ol.service_reference_type_code,'X'),'ORDER',ol.service_duration, ol.ordered_quantity))  -- INC0145470 added
                    )) ordered_quantity
        FROM oe_order_lines_all ol, mtl_system_items_b msib
       WHERE ol.header_id = p_header_id
         AND ol.cancelled_flag <> 'Y'
         AND nvl(ol.item_type_code, '-1') NOT IN ('OPTION', 'INCLUDED')
         AND msib.organization_id = 91
         AND msib.inventory_item_id = ol.inventory_item_id
         AND msib.item_type NOT IN
             (fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'),
              fnd_profile.value('XXAR_FREIGHT_AR_ITEM'))
       GROUP BY msib.segment1, ol.line_category_code;

    -- price_request_number
    CURSOR c_all_product_exits2 IS
      SELECT msib.segment1 item,
             SUM(
             decode(line_category_code,
                    'RETURN',
                    --(decode(ol.item_type_code,'SERVICE',ol.service_duration, ol.ordered_quantity)) * -1,  -- INC0144895 handle SERVICE item quantity -- INC0145470 commented
                    --(decode(ol.item_type_code,'SERVICE',ol.service_duration, ol.ordered_quantity))  --INC0140978 INC0144895 - handle SERVICE item quantity -- INC0145470 commented
                    (decode(nvl(ol.service_reference_type_code,'X'),'ORDER',ol.service_duration, ol.ordered_quantity)) * -1,  -- INC0145470 added
                    (decode(nvl(ol.service_reference_type_code,'X'),'ORDER',ol.service_duration, ol.ordered_quantity))  -- INC0145470 added
                    )) ordered_quantity
        FROM oe_order_lines_all ol, mtl_system_items_b msib
       WHERE ol.header_id = p_header_id
         AND ol.cancelled_flag <> 'Y'
         AND nvl(ol.item_type_code, '-1') NOT IN ('OPTION', 'INCLUDED')
         AND msib.organization_id = 91
         AND msib.inventory_item_id = ol.inventory_item_id
         AND msib.item_type NOT IN
             (fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'),
              fnd_profile.value('XXAR_FREIGHT_AR_ITEM'))
       GROUP BY msib.segment1, ol.line_category_code
      MINUS
      SELECT ql.item, SUM(ql.ordered_quantity) ordered_quantity
        FROM xxobjt.xxcpq_quote_lines_mirr ql
       WHERE ql.price_request_number = p_quote_number
         AND ql.source_name = p_request_source
       GROUP BY ql.item;

    CURSOR c_quote_tot_amt IS
      SELECT SUM(ql.total_selling_price)
        FROM xxobjt.xxcpq_quote_lines_mirr ql, mtl_system_items_b msib -- INC0127218
       WHERE ql.price_request_number = p_quote_number
         AND ql.source_name = p_request_source
         AND ql.inventory_item_id = msib.inventory_item_id -- INC0127218
         AND msib.organization_id =
             xxinv_utils_pkg.get_master_organization_id -- INC0127218
            -- INC0127218 - Add below exclusion
         AND msib.item_type NOT IN
             (fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'),
              fnd_profile.value('XXAR_FREIGHT_AR_ITEM'));

    CURSOR c_oh_total_amt IS
      SELECT SUM(round((decode(line_category_code,
                               'RETURN',
                               ol.ordered_quantity * -1,
                               ol.ordered_quantity) *
                       ol.unit_selling_price),
                       2)) oh_total_amt -- INC0127218  round 2
        FROM oe_order_lines_all ol, mtl_system_items_b msib
       WHERE ol.header_id = p_header_id
         AND msib.organization_id = 91
         AND msib.inventory_item_id = ol.inventory_item_id
         AND msib.item_type NOT IN
             (fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'),
              fnd_profile.value('XXAR_FREIGHT_AR_ITEM'))
         AND ol.cancelled_flag <> 'Y';

    CURSOR c_qh_record IS
      SELECT *
        FROM xxobjt.xxcpq_quote_header_mirr qh
       WHERE qh.source_name = p_request_source
         AND qh.price_request_number = p_quote_number;

    l_validation_error VARCHAR2(2000) := '';
    l_tot_qh_amt       NUMBER;
    l_tot_oh_amt       NUMBER;
    l_oh_term_name     VARCHAR2(240);
    l_qh_term_name     VARCHAR2(240);
    l_qh_period_length NUMBER;
    l_oh_period_length NUMBER;
    l_hold_id          NUMBER;
    l_errbuf           VARCHAR2(3000);
    l_retcode          VARCHAR2(10);

    l_round_factor       NUMBER;
    l_quote_orders       VARCHAR2(300);
    l_header_quot_no     VARCHAR2(1000);

    l_qh_quote_number    xxobjt.xxcpq_quote_header_mirr.sf_quote_number%TYPE;
    l_qh_price_list_id   NUMBER;
    l_qh_payment_term_id NUMBER;
    l_oh_price_list_id   NUMBER;
    l_oh_payment_term_id NUMBER;
    l_cpq_hold_name      VARCHAR2(150);
    l_header_rec         xxobjt.xxom_so_header_rec_type := xxobjt.xxom_so_header_rec_type(NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL,
                                                                                          NULL);
    --------------------------------------------------------------
  BEGIN
    --Begin CHG0044433/CTASK0039554
    If upper(p_request_source) != upper(g_strataforce_target) Then
      Begin
        SELECT oh.attribute4
          INTO l_header_quot_no
          FROM oe_order_headers_all oh
         WHERE oh.header_id = p_header_id;

        SELECT listagg(oh.order_number, ',') within GROUP(ORDER BY oh.order_number)
          INTO l_quote_orders
          FROM oe_order_headers_all oh, oe_order_headers_all_dfv ohd
         WHERE oh.rowid = ohd.row_id
           AND ohd.quote_no = l_header_quot_no
           AND oh.flow_status_code <> 'CANCELLED'
           AND oh.header_id <> p_header_id
           AND xxoe_utils_pkg.get_order_status_for_sforce(oh.header_id) <>
               'CANCELLED'; --CHG0044433

        If l_quote_orders is not null Then
          l_validation_error := 'Quote no :' || l_header_quot_no ||
                                ', also associated with below Sales Orders.' ||
                                CHR(10) ||
                                'Please remove the Quote no reference from not Required Sales Orders (' ||
                                l_quote_orders || ').';

          Return l_validation_error;
        End If;

      Exception
        When others Then
          l_validation_error := 'UNEXPECTED ERROR in xxom_salesorder_api.validate_quote,' ||
                                'during non STRATAFORCE Sales Quote Validation.' ||
                                CHR(10) || sqlerrm;
          Return l_validation_error;
      End;

      If l_header_quot_no is null then
        Return '';
      else
        Return 'Quote no cannot be accepted for Order Source other then STRATAFORCE.' || CHR(10) || ' Please remove the Quote no from DFF.';
      End if;
    End If;
    l_header_quot_no := '';
    --End CHG0044433/CTASK0039554

    BEGIN
      SELECT ohd.quote_no
        INTO l_header_quot_no
        FROM oe_order_headers_all oh, oe_order_headers_all_dfv ohd
       WHERE oh.header_id = p_header_id
         AND oh.rowid = ohd.row_id
         AND to_char(oh.order_source_id) =
             (SELECT ffvd.order_source
                FROM fnd_flex_values     ffv,
                     fnd_flex_value_sets ffvs,
                     fnd_flex_values_dfv ffvd
               WHERE ffvs.flex_value_set_name = 'XXSSYS_EVENT_TARGET_NAME'
                 AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                 AND upper(ffv.flex_value) = upper(g_strataforce_target)
                 AND ffv.enabled_flag = 'Y'
                 AND ffvd.row_id = ffv.rowid
                 AND SYSDATE BETWEEN nvl(ffv.start_date_active, SYSDATE - 1) AND
                     nvl(ffv.end_date_active, SYSDATE + 1));

      IF l_header_quot_no IS NULL THEN
        l_validation_error := 'Cannot book order based on quote with no quote reference';
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        l_validation_error := 'Unexpected error while validating quote number.' ||
                              CHR(10) || SQLERRM;
    END;

    BEGIN
      -- get header info from backup header Table
      SELECT qh.sf_quote_number,
             qh.price_list_id,
             qh.payment_term_id,
             pay_term.name,
             to_number(pay_term.attribute1) period_length
        INTO l_qh_quote_number,
             l_qh_price_list_id,
             l_qh_payment_term_id,
             l_qh_term_name,
             l_qh_period_length
        FROM xxobjt.xxcpq_quote_header_mirr qh, ra_terms_vl pay_term
       WHERE
      --qh.header_id = p_header_id
       qh.price_request_number = p_quote_number
       AND qh.source_name = p_request_source
       AND qh.payment_term_id = pay_term.term_id(+);
      --
      --get Sales order header info from Oracle Apps seeded Table
      SELECT oh.payment_term_id,
             pay_term.name,
             to_number(pay_term.attribute1) period_length
        INTO l_oh_payment_term_id, l_oh_term_name, l_oh_period_length
        FROM oe_order_headers_all oh, ra_terms_vl pay_term
       WHERE oh.header_id = p_header_id
         AND oh.payment_term_id = pay_term.term_id(+);

      --Price Request Quote Number and SO DFF Quote number Should Match
      IF l_qh_quote_number != p_quote_number THEN
        l_validation_error := 'Price Request Quote number doesnot match with Sales Order Quote.';
      ELSIF l_qh_price_list_id != p_price_list_id THEN
        l_validation_error := 'Sales Order Price list does not match with Quote.';
        /*ElsIf l_oh_term_name is null Then
              l_validation_error := 'Sales Order doesnot have any Payment Term.';
        ElsIf l_qh_term_name is null  Then
              l_validation_error := 'Sales Quote doesnot have any Payment Term.';*/
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        l_validation_error := 'No Data found in the Quote backup table.';
      WHEN OTHERS THEN
        l_validation_error := SQLERRM;
    END;

    /*------------------------------------------------------------------
      All items in Quote must exist in order
      (compare total quantity per product code and not specific lines)
      ------------------------------------------------------------------
    */
    IF l_validation_error IS NULL THEN
      BEGIN
        FOR qh_rec IN c_all_product_exits1 LOOP
          l_validation_error := (CASE
                                  WHEN l_validation_error IS NULL THEN
                                   ''
                                  ELSE
                                   l_validation_error || ','
                                END) || qh_rec.item;

        END LOOP;

        l_validation_error := (CASE
                                WHEN l_validation_error IS NULL THEN
                                 ''
                                ELSE
                                 l_validation_error ||
                                 ' - Items available in Quote but not available in Sales Order.'
                              END);

        FOR oh_rec IN c_all_product_exits2 LOOP
          l_validation_error := (CASE
                                  WHEN l_validation_error IS NULL THEN
                                   ''
                                  ELSE
                                   l_validation_error || ','
                                END) || oh_rec.item;

        END LOOP;

        l_validation_error := (CASE
                                WHEN l_validation_error IS NULL THEN
                                 ''
                                ELSE
                                 l_validation_error ||
                                 ' - Items available in Sales Order but not available in Quote.'
                              END);

      EXCEPTION
        WHEN OTHERS THEN
          l_validation_error := 'Error During Item Comparision :' ||
                                SQLERRM;
      END;
    END IF;

    IF l_validation_error IS NULL THEN
      --Get Total Quote Amount
      BEGIN
        OPEN c_quote_tot_amt;
        FETCH c_quote_tot_amt
          INTO l_tot_qh_amt;
        CLOSE c_quote_tot_amt;

        --Get Total Sales Order Amount
        OPEN c_oh_total_amt;
        FETCH c_oh_total_amt
          INTO l_tot_oh_amt;
        CLOSE c_oh_total_amt;

        IF nvl(l_tot_oh_amt, 0) != nvl(l_tot_qh_amt, 0) THEN
          l_validation_error := l_validation_error || chr(10) ||
                                'Total quote amount:' ||
                                nvl(l_tot_qh_amt, 0) ||
                                ' and total Sales order amount:' ||
                                l_tot_oh_amt || ' does not match.';
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          l_validation_error := 'Error During Total Amount Comparision :' ||
                                SQLERRM;
      END;
    END IF;

    IF l_validation_error IS NULL THEN

      FOR rec IN c_qh_record LOOP
        l_header_rec.price_request_number    := rec.price_request_number;
        l_header_rec.external_ref_number     := rec.external_ref_number;
        l_header_rec.order_number            := rec.order_number;
        l_header_rec.header_id               := rec.header_id;
        l_header_rec.org_id                  := rec.org_id;
        l_header_rec.country_code            := rec.country_code;
        l_header_rec.sold_to_account         := rec.sold_to_account;
        l_header_rec.sold_to_org_id          := rec.sold_to_org_id;
        l_header_rec.ship_to_org_id          := rec.ship_to_org_id;
        l_header_rec.invoice_to_org_id       := rec.invoice_to_org_id;
        l_header_rec.ship_to_contact_id      := rec.ship_to_contact_id;
        l_header_rec.sold_to_contact_id      := rec.sold_to_contact_id;
        l_header_rec.invoice_to_contact_id   := rec.invoice_to_contact_id;
        l_header_rec.order_source_id         := rec.order_source_id;
        l_header_rec.order_source            := rec.order_source;
        l_header_rec.currency_code           := rec.currency_code;
        l_header_rec.ordered_date            := rec.ordered_date;
        l_header_rec.operation               := rec.operation;
        l_header_rec.order_type_name         := rec.order_type_name;
        l_header_rec.order_type_id           := rec.order_type_id;
        l_header_rec.cust_po_number          := rec.cust_po_number;
        l_header_rec.shipping_method_code    := rec.shipping_method_code;
        l_header_rec.freight_terms_code      := rec.freight_terms_code;
        l_header_rec.incoterms               := rec.incoterms;
        l_header_rec.fob                     := rec.fob;
        l_header_rec.fob_code                := rec.fob_code;
        l_header_rec.payment_term_id         := rec.payment_term_id;
        l_header_rec.contractnumber          := rec.contractnumber;
        l_header_rec.freightcost             := rec.freightcost;
        l_header_rec.freightcosttax          := rec.freightcosttax;
        l_header_rec.price_list_name         := rec.price_list_name;
        l_header_rec.price_list_id           := rec.price_list_id;
        l_header_rec.ship_incomplete         := rec.ship_incomplete;
        l_header_rec.comments                := rec.comments;
        l_header_rec.salesrep_id             := rec.salesrep_id;
        l_header_rec.avg_discount_percent    := rec.avg_discount_percent;
        l_header_rec.pofile                  := rec.pofile;
        l_header_rec.pocontenttype           := rec.pocontenttype;
        l_header_rec.ipay_approvalcode       := rec.ipay_approvalcode;
        l_header_rec.ipay_exttoken           := rec.ipay_exttoken;
        l_header_rec.ipay_customerrefnum     := rec.ipay_customerrefnum;
        l_header_rec.ipay_transactionid      := rec.ipay_transactionid;
        l_header_rec.ipayccnumber            := rec.ipayccnumber;
        l_header_rec.ipay_orderidpson        := rec.ipay_orderidpson;
        l_header_rec.ipay_instrid            := rec.ipay_instrid;
        l_header_rec.ask_for_modifier_name   := rec.ask_for_modifier_name;
        l_header_rec.ask_for_modifier_id     := rec.ask_for_modifier_id;
        l_header_rec.calculate_price_flag    := rec.calculate_price_flag;
        l_header_rec.sf_quote_number         := rec.sf_quote_number;
        l_header_rec.sf_quote_status         := rec.sf_quote_status;
        l_header_rec.sf_sbqq_primary         := rec.sf_sbqq_primary;
        l_header_rec.sf_oppurtunity          := rec.sf_oppurtunity;
        l_header_rec.sf_reseller_account     := rec.sf_reseller_account;
        l_header_rec.sf_reseller_account_id  := rec.sf_reseller_account_id;
        l_header_rec.sf_3rd_party_account    := rec.sf_3rd_party_account;
        l_header_rec.sf_3rd_party_account_id := rec.sf_3rd_party_account_id;
        l_header_rec.sf_end_cust_account     := rec.sf_end_cust_account;
        l_header_rec.sf_end_cust_account_id  := rec.sf_end_cust_account_id;
        l_header_rec.attribute1              := rec.attribute1;
        l_header_rec.attribute2              := rec.attribute2;
        l_header_rec.attribute4              := rec.attribute4;
        l_header_rec.attribute6              := rec.attribute6;
        l_header_rec.attribute7              := rec.attribute7;
        l_header_rec.attribute8              := rec.attribute8;
        l_header_rec.attribute10             := rec.attribute10;
        l_header_rec.attribute11             := rec.attribute11;
        l_header_rec.attribute12             := rec.attribute12;
        l_header_rec.attribute13             := rec.attribute13;
        l_header_rec.attribute14             := rec.attribute14;
        l_header_rec.attribute15             := rec.attribute15;
        l_header_rec.user_id                 := rec.user_id;
        l_header_rec.resp_id                 := rec.resp_id;
        l_header_rec.appl_id                 := rec.appl_id;
      END LOOP;
      --Validate Order Header details
      xxom_salesorder_api.validate_order_header(p_header_rec     => l_header_rec, --IN Type of xxobjt.xxom_so_header_rec_type
                                                p_request_source => p_request_source, --In Param
                                                p_book_validate  => 'Y',
                                                x_header_rec     => l_header_rec, --Out Type of xxobjt.xxom_so_header_rec_type
                                                x_status         => l_retcode, --Out Type Char
                                                x_status_msg     => l_errbuf --Out Type Char
                                                );
      IF l_retcode != fnd_api.g_ret_sts_success THEN
        l_validation_error := 'Error During the validating Sales Order :' ||
                              l_errbuf;
      END IF;
    END IF;

    -- Validations For? Apply Hold - SSYS CPQ Payment Terms Approval
    /*If l_validation_error is null Then

       If (nvl(l_qh_term_name,'-1') != nvl(l_oh_term_name,'-1'))
       Then

         If l_qh_period_length is not null and l_oh_period_length is not null and
              (nvl(l_oh_period_length,0) <= nvl(l_qh_period_length,0) )
         Then
           Null;--No Action required
         Else

                -- get Hold From Profile
                Begin
                  l_cpq_hold_name  := fnd_profile.value('XXOM_CPQ_SO_HOLD_NAME');
                  select hold_id
                  into l_hold_id
                  from OE_HOLD_DEFINITIONS
                  where  name  = l_cpq_hold_name;--'SSYS CPQ Payment Terms Approval';
                Exception
                When no_data_found Then
                  l_validation_error := 'CPQ Hold: '||l_cpq_hold_name ||' Not found in Table OE_HOLD_DEFINITIONS.';
                End;

                l_errbuf  := '';
                l_retcode := '';
            Begin
                xxom_auto_hold_pkg.apply_hold
                                 (errbuf           =>l_errbuf,        --OUT VARCHAR2,
                                  retcode          =>l_retcode,       --OUT VARCHAR2,
                                  p_so_header_id   =>p_header_id,     --IN NUMBER,
                                  p_org_id         =>fnd_global.ORG_ID,--IN NUMBER,   -
                                  p_user_id        =>fnd_global.USER_ID, --IN NUMBER,
                                  p_hold_id        =>l_hold_id,       --IN NUMBER,
                                  p_hold_notes     => 'Auto'--IN VARCHAR2
                                 );

                If  l_retcode <> 0 Then
                  --Hold Failed to apply
                  l_validation_error := 'Automatic hold failed to Apply for - SSYS CPQ Payment Terms Approval.'
                                     ||CHR(10)||'Error:'|| l_errbuf;
                End If;
            Exception
            When Others Then
               l_validation_error := 'Error During Apply Hold :'||sqlerrm;
               l_retcode := 1;
            End;

         End If;

       End If;

    End If;*/

    IF l_validation_error IS NOT NULL THEN
      l_validation_error := 'SSYS CPQ Quote Validation Failed.' || chr(10) ||
                            l_validation_error || chr(10) ||
                            'You cannot proceed with Sales Order Booking.';
    END IF;

    --Remove below Line after Testing
    --l_validation_error := l_validation_error ||chr(10)||'.Force Error.' ;
    COMMIT;

    RETURN l_validation_error;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN l_validation_error || '.UNEXPECTED ERROR in xxom_salesorder_api.validate_quote:' || SQLERRM || '.Please Contact your administrator.';
  END validate_quote;

END xxom_salesorder_api;
/
