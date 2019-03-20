create or replace package body xxoe_utils_pkg IS

  --------------------------------------------------------------------
  --  name:            XXOE_UTILS_PKG
  --  create by:       RanS
  --  Revision:        1.11
  --  creation date:   25/10/2009
  --------------------------------------------------------------------
  --  purpose :        various utilities for OE
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  25/10/2009  RanS            initial build
  --  1.1  02/02/2009  Dalit A. raviv  Resin Balance customization
  --  1.2  15/07/2010  Yuval Tal       add procedure get_order_average_dicount
  --  1.4  02/01/2011  Yuval Tal       add get_requestor_name+ get_requisition_number
  --                                   (used in XXWSH_SHIPPING_DETAILS_V)
  --  1.5   1.2.11      yuval tal       add is_hazard_delivery
  --  1.6   30.10.11     yuval tal      add get_line_ship_to_territory -- CR329
  --  1.7   20.5.12     dovik pollak    add function is_coupon_item
  --  1.8   23.7.13     yuval tal       add show_dental_alert
  --  1.9   03.12.13    Dovik pollak/
  --                    Ofer Suad       CR 1122  add bundle functionality
  --  1.10  19/02/2014  Dalit A. Raviv  REP009 - Order Acknowledgment\
  --                                    CR1327 Adjustment for Dental Advantage Sticker
  --                                    add function - show_dis_get_line
  --  1.11  09/03/2014  Dalit A. Raviv  OCHG0031347 - Get shipping instructions
  --  1.12   23.3.14    yuval tal       CHG0031606  modify is_bundle_line
  --                                              is_comp_bundle_line
  --                                              : Bug Fix- OM General Report- Upgrade kit items
  -- 1.13  6.4.14        yuval tal      CHG0031865 modify show_dis_get_line : change p_line_id type from number to char
  -- 1.14  09.06.14      yuval tal      CHG0032388 - add function  get_cancelation_comment
  -- 1.15  01.7.14       yuval tal      CHG0031508 - Salesforce Customer support Implementation  CTASK0014413  - add get_SO_line_delivery
  -- 1.16  07.09.2014    Michal Tzvik   CHG0032651 - add function om_print_config_option
  -- 1.17  21.10.2014    Ofer Suad      CHG0032650 ? PTOs: Average Discount Calculation and Revenue Distribution
  -- 1.18  28.10.2014    Michal Tzvik   CHG0033456 ? Customs Clearance Charges for FOC Service Part - Add function
  -- 1.19  24.11.2014    Michal Tzvik   CHG0033602 ? Add a new Function to detect Service Contract Items - Add function is_item_service_contract
  -- 1.20  12.11.2014    Ofer Suad      CHG0033824 - modify is_option_line : Fix Revenue Distribution for PTO's Bundles
  -- 1.21  22.01.2015    Michal Tzvik   CHG0033848 - Add function get_qp_list_price
  -- 1.22  28.01.2015    Michal Tzvik   CHG0034428 - 1. Add function calc_avg_discount
  --                                                 2. Modify function_is initial_order
  -- 1.23  26.04.2015    Michal Tzvik  CHG0034991 - Add parameter p_org_id to FUNCTION get_resin_balance
  -- 1.24  07.03.2016 Lingaraj Sarangi CHG0037863 -DG- Add indication on Shipping Docs for Non Restricted items
  -- 1.25  26.05.2016 Lingaraj Sarangi INC0065232 -Dist Functional Amount Wrong on OM general report
  -- 1.27 15.06.2016  Dipta Chatterjee  CHG0038661- Resin Credit balance is not correct
  -- 1.28 29.5.2016   yuval tal         CHG0038970  modify  add safe_devisor/get_precision
  --                                    get_price_list_dist proc  from  xxar_autoinvoice_pkg.get_price_list_dist
  -- 1.29 12.1.2017   Dipta            CHG0039567- Add new function get_resin_credit_description
  --                   Chatterjee      to return Resin Credit line item description
  -- 1.30 19.1.2017   L.Sarangi        CHG0039931 - Correct avarage discount claculation for Kit in PTO order
  --                                   Function Modified is is_option_line,change Code given by Ofer Suad

  -- 1.32 14.2.2017  Adi Safin         CHG0040093 -  interface to bring the SN for warranty PN's
  --                                   Added a New Function <is_item_service_warranty>
  -- 1.33 04.04.2017 Lingaraj Sarangi  CHG0040389: Resin Credit  - add an option to link resin credit consumption orders to resin credit purchase order
  --                                   Function <get_original_so_resin_balance> Created
  -- 1.34 15.5.17      yuval tal       INC0092883 - modify  get_original_so_resin_balance
  -- 1.4  23.7.17      yuval tal       CHG0041110 - modify is_option_line : PTO type Model item at zero amount
  -- 1.41 09/26/2017   Dipta           CHG0041334 - Add new function get_resin_credit_for_bundle to be used by OIC
  --                   Chatterjee      setup for calculating the resin credit included within bundle item order lines
  -- 1.5  19.02.2018 bellona banerjee  CHG0041294- Added P_Delivery_Name to is_hazard_delivery and is_dg_restricted_delivery
  --                   as part of delivery_id to delivery_name conversion
  -- 1.6  01/12/2018   Roman W         CHG0044580 - added  logic to get_order_status_for_sforce
  -- 1.7  23/12/2018   Roman W         CHG0044705 - Commercial Invoice - change logic to identify lines under service contract
  --                                          code corection in function is_line_order_under_contract 
  ------------------------------------------------------------------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            get_shipping_instructions
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   01.7.14
  --------------------------------------------------------------------
  --  purpose :       CHG0031508 - Salesforce Customer support Implementation CTASK0014413  - add get_SO_line_delivery
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  01.7.14  yuval tal   initial build
  --------------------------------------------------------------------

  FUNCTION get_so_line_delivery(p_line_id NUMBER) RETURN VARCHAR2 IS
    l_delivery VARCHAR2(2000);
  BEGIN
  
    SELECT listagg(NAME, ',') within GROUP(ORDER BY source_line_id)
      INTO l_delivery
      FROM (SELECT DISTINCT wnd.name, source_line_id
              FROM wsh_delivery_details     wdd,
                   wsh_delivery_assignments wda,
                   wsh_new_deliveries       wnd
             WHERE wdd.delivery_detail_id = wda.delivery_detail_id
               AND wda.delivery_id = wnd.delivery_id
               AND wdd.source_line_id = p_line_id);
  
    RETURN l_delivery;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  ----------------------------------------
  -- get_requestor_name Yuval Tal 2.01.11
  ----------------------------------------

  FUNCTION get_requestor_name(p_line_id NUMBER) RETURN VARCHAR2 IS
  
    CURSOR c IS
      SELECT hr_general.decode_person_name(ql.to_person_id) requestor
        FROM oe_order_lines_all ola, po_requisition_lines_all ql
       WHERE ola.source_document_type_id = 10
         AND ql.requisition_line_id = ola.source_document_line_id
         AND p_line_id = ola.line_id
         AND ql.org_id = ola.org_id;
    l_tmp VARCHAR2(250);
  BEGIN
  
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
    RETURN l_tmp;
  END;
  ----------------------------------------
  -- get_requisition_number Yuval Tal 2.01.11
  ----------------------------------------

  FUNCTION get_requisition_number(p_line_id NUMBER) RETURN VARCHAR2 IS
    CURSOR c IS
      SELECT rh.segment1
        FROM oe_order_lines_all         ola,
             po_requisition_lines_all   ql,
             po_requisition_headers_all rh
       WHERE rh.requisition_header_id = ql.requisition_header_id
         AND ola.source_document_type_id = 10
         AND ql.requisition_line_id = ola.source_document_line_id
         AND p_line_id = ola.line_id;
    --  AND ql.org_id = ola.org_id;
    l_tmp VARCHAR2(250);
  BEGIN
  
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
    RETURN l_tmp;
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               is_initial_order
  --  create by:
  --  Revision:
  --  creation date:
  --  Purpose :           Returns Y if the supplied order type represents
  --                      an initial order, and N if not.
  --                      In case of some error returns E.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0                                 Initial Build
  --  1.1   28/01/2015    Michal Tzvik    CHG0034428: replace attribute5 with attribute10
  ----------------------------------------------------------------------
  FUNCTION is_initial_order(p_order_type_id NUMBER) RETURN VARCHAR2 IS
    v_ret VARCHAR2(1);
  
  BEGIN
    SELECT nvl(rctt.attribute10, 'N') init_order -- 1.1 Michal Tzvik: replace attribute5 with attribute10
      INTO v_ret
      FROM oe_transaction_types_all ott, ra_cust_trx_types_all rctt
     WHERE ott.cust_trx_type_id = rctt.cust_trx_type_id
       AND ott.org_id = rctt.org_id
       AND transaction_type_id = p_order_type_id;
  
    RETURN v_ret;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'E';
  END is_initial_order;

  --------------------------------------------------------------------
  --  customization code: CHG0034428
  --  name:               calc_avg_discount
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      28/01/2015
  --  Purpose :           Returns Y if the supplied order type require
  --                      average discount calculation
  --                      In case of some error returns E.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   28/01/2015    Michal Tzvik    Initial Build: CHG0034428
  ----------------------------------------------------------------------
  FUNCTION calc_avg_discount(p_order_type_id NUMBER) RETURN VARCHAR2 IS
    v_ret VARCHAR2(1);
  
  BEGIN
    SELECT nvl(rcttad.adjust_interface_by_avg_disc, 'N')
      INTO v_ret
      FROM oe_transaction_types_all  otta,
           ra_cust_trx_types_all     rctta,
           ra_cust_trx_types_all_dfv rcttad
     WHERE otta.cust_trx_type_id = rctta.cust_trx_type_id
       AND rcttad.row_id = rctta.rowid
       AND otta.org_id = rctta.org_id
       AND otta.transaction_type_id = p_order_type_id;
  
    RETURN v_ret;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'E';
  END calc_avg_discount;

  ------------------------------------------------------------
  -- Name: is_item_resin
  -- Description: Returns Y if the supplied item is of type Resin
  --              and N if not.
  ------------------------------------------------------------
  FUNCTION is_item_resin(p_inventory_item_id NUMBER) RETURN VARCHAR2 IS
    v_ret VARCHAR2(1);
  
  BEGIN
    SELECT 'Y'
      INTO v_ret
      FROM mtl_categories_b mc, mtl_item_categories mic
     WHERE mic.organization_id = xxinv_utils_pkg.get_master_organization_id
       AND mic.category_id = mc.category_id
       AND mic.category_set_id = 1100000041 --Inventory
       AND mc.segment1 = 'Resins'
       AND mic.inventory_item_id = p_inventory_item_id;
  
    RETURN v_ret;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
  END is_item_resin;

  ------------------------------------------------------------
  -- Name: get_resin_balance
  -- Description: Returns the balance of resin credit per customer and currency,
  -- excluding the current order.
  -- If no balance exists returns 0.
  ------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0                                 Initial Build
  --  1.1   26/04/2015    Michal Tzvik    CHG0034991: Add parameter p_org_id
  --  1.2   15/06/2016  Dipta Chatterjee  CHG0038661- Resin Credit balance is not correct
  ------------------------------------------------------------
  FUNCTION get_resin_balance(p_customer_num VARCHAR2,
                             p_currency     VARCHAR2,
                             p_order_num    NUMBER DEFAULT NULL,
                             p_org_id       NUMBER DEFAULT NULL) -- 1.1 Michal Tzvik 16/04/2015
   RETURN NUMBER IS
  
    v_ret NUMBER;
  
  BEGIN
    SELECT SUM(credit_amount)
      INTO v_ret
      FROM xxoe_resin_balance_line_v
     WHERE customer_number = p_customer_num --'3041'
       AND currency = p_currency --'USD'
       AND order_number != nvl(p_order_num, 0) --100778
          --AND    org_id = nvl(p_org_id, org_id); -- 1.1 Michal Tzvik 16/04/2015 , Commented on 1.2 Version
       AND decode(org_id, 89, 737, org_id) =
           nvl(p_org_id, decode(org_id, 89, 737, org_id)); --1.2 Dipta  CHG0038661  - 15 JUN 2016
  
    RETURN nvl(v_ret, 0);
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 0;
  END get_resin_balance;

  ------------------------------------------------------------
  -- Name: is_item_resin_credit
  -- Description: Returns Y if the supplied item is of type Resin credit
  --              and N if not.
  ------------------------------------------------------------
  FUNCTION is_item_resin_credit(p_inventory_item_id NUMBER) RETURN VARCHAR2 IS
    v_ret VARCHAR2(1);
  
  BEGIN
    SELECT 'Y'
      INTO v_ret
      FROM mtl_system_items_b msi
     WHERE msi.item_type = fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE')
       AND msi.inventory_item_id = p_inventory_item_id
       AND msi.organization_id = xxinv_utils_pkg.get_master_organization_id;
  
    RETURN v_ret;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
  END is_item_resin_credit;

  ------------------------------------------------------------
  -- Name: is_coupon_item
  -- Description: Returns Y if the supplied item is of type Coupon
  --              and N if not.
  ------------------------------------------------------------
  FUNCTION is_coupon_item(p_inventory_item_id NUMBER) RETURN VARCHAR2 IS
    v_ret VARCHAR2(1);
  
  BEGIN
  
    SELECT 'Y'
      INTO v_ret
      FROM mtl_system_items_b msi
     WHERE msi.item_type = fnd_profile.value('XXAR_COUPON_ITEM_TYPE')
       AND msi.inventory_item_id = p_inventory_item_id
       AND msi.organization_id = xxinv_utils_pkg.get_master_organization_id;
  
    RETURN v_ret;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
  END is_coupon_item;
  ------------------------------------------------------------
  -- Name: is_comp_bundle_line
  -- Description: Returns Y if the supplied item is of type bundle component
  --              and N if not.
  --------------------------------------------------------------------
  --  ver  date        name           desc

  -- 1.x  23.3.14      yuval tal      CHG0031606  - add :   AND NOT EXISTS
  --                                  (SELECT 1
  --                                          FROM xxcs_sales_ug_items_v t
  --                                           WHERE ol1.inventory_item_id = t.upgrade_item_id)
  ------------------------------------------------------------
  FUNCTION is_comp_bundle_line(p_line_id NUMBER) RETURN VARCHAR2 IS
    v_ret VARCHAR2(1);
  
  BEGIN
  
    SELECT 'Y'
      INTO v_ret
      FROM oe_order_lines_all ol, oe_price_adjustments_v opa
    
     WHERE opa.line_id = ol.line_id
       AND ol.line_id = p_line_id
       AND opa.list_line_type_code = 'DIS'
       AND EXISTS
     (SELECT 1
              FROM oe_price_adjustments_v opa1,
                   oe_order_lines_all     ol1,
                   mtl_system_items_b     msb
             WHERE ol1.header_id = ol.header_id
               AND opa1.line_id = ol1.line_id
               AND opa1.list_line_type_code = 'PRG'
               AND msb.inventory_item_id = ol1.inventory_item_id
               AND msb.organization_id =
                   xxinv_utils_pkg.get_master_organization_id
               AND opa1.list_header_id = opa.list_header_id
               AND msb.inventory_item_flag = 'N'
               AND NOT EXISTS
             (SELECT 1
                      FROM xxcs_sales_ug_items_v t
                     WHERE ol1.inventory_item_id = t.upgrade_item_id));
  
    RETURN v_ret;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
  END is_comp_bundle_line;
  ------------------------------------------------------------
  -- Name: is_bundle_line
  -- Description: Returns Y if the supplied item is of type bundle component
  --              and N if not.

  --  ver  date        name           desc
  -------------------------------------------------------------------------------
  -- 1.x  23.3.14      yuval tal      CHG0031606  - add :   AND NOT EXISTS
  --                                  (SELECT 1
  --                                          FROM xxcs_sales_ug_items_v t
  --                                           WHERE ol1.inventory_item_id = t.upgrade_item_id)
  ------------------------------------------------------------
  FUNCTION is_bundle_line(p_line_id NUMBER) RETURN VARCHAR2 IS
    v_ret VARCHAR2(1);
  
  BEGIN
  
    SELECT 'Y'
      INTO v_ret
      FROM oe_price_adjustments_v opa1,
           oe_order_lines_all     ol1,
           mtl_system_items_b     msb
     WHERE ol1.line_id = p_line_id
       AND opa1.line_id = ol1.line_id
       AND opa1.list_line_type_code = 'PRG'
       AND msb.inventory_item_id = ol1.inventory_item_id
       AND msb.organization_id = xxinv_utils_pkg.get_master_organization_id
       AND msb.inventory_item_flag = 'N'
       AND EXISTS
     (SELECT 1
              FROM oe_order_lines_all ol, oe_price_adjustments_v opa
             WHERE opa.line_id = ol.line_id
               AND ol1.header_id = ol.header_id
               AND opa1.list_header_id = opa.list_header_id
               AND opa.list_line_type_code = 'DIS')
       AND NOT EXISTS
     (SELECT 1
              FROM xxcs_sales_ug_items_v t
             WHERE ol1.inventory_item_id = t.upgrade_item_id)
          
       AND rownum = 1;
  
    RETURN v_ret;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
  END is_bundle_line;
  ------------------------------------------------------------
  -- Name: calc_resin_credit
  -- Description:
  ------------------------------------------------------------
  FUNCTION calc_resin_credit(p_form_total   NUMBER,
                             p_line_prev    NUMBER,
                             p_line_new     NUMBER,
                             p_currency     VARCHAR2,
                             p_customer_num VARCHAR2,
                             p_order_num    NUMBER) RETURN NUMBER IS
  
    v_ret              NUMBER;
    v_form_request     NUMBER;
    v_existing_balance NUMBER;
    v_calc             NUMBER;
  
  BEGIN
  
    v_form_request     := p_form_total - p_line_prev + p_line_new;
    v_existing_balance := get_resin_balance(p_customer_num,
                                            p_currency,
                                            p_order_num);
    v_calc             := v_existing_balance + v_form_request;
  
    IF v_calc < 0 THEN
      v_ret := v_calc;
    ELSE
      v_ret := NULL;
    END IF;
  
    RETURN v_ret;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END calc_resin_credit;

  --------------------------------------------------------------------
  --  name:            get_exists_resin_balance
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   02/04/20010
  --------------------------------------------------------------------
  --  purpose :        get So resin credit balance from data base
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_exists_resin_balance(p_customer_num VARCHAR2,
                                    p_currency     VARCHAR2,
                                    p_order_num    NUMBER DEFAULT NULL)
    RETURN NUMBER IS
  
    l_ret NUMBER;
  
  BEGIN
    SELECT SUM(credit_amount)
      INTO l_ret
      FROM xxoe_resin_balance_line_v
     WHERE customer_number = p_customer_num --'3041'
       AND currency = p_currency --'USD'
       AND order_number = nvl(p_order_num, 0); --100778
  
    RETURN nvl(l_ret, 0);
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 0;
    WHEN OTHERS THEN
      RETURN 0;
  END get_exists_resin_balance;

  --------------------------------------------------------------------
  --  name:            get_global_sum_rc_value
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   03/02/2010
  --------------------------------------------------------------------
  --  purpose :        Calc global sum value
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/02/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_global_sum_rc_value(p_global_sum      NUMBER,
                                   p_line_unit_price NUMBER,
                                   p_global_hist     NUMBER) RETURN NUMBER IS
  
  BEGIN
    IF p_line_unit_price = p_global_hist THEN
      RETURN p_global_sum + p_line_unit_price;
    ELSE
      RETURN p_global_sum + p_line_unit_price - p_global_hist;
    END IF;
  END;

  --------------------------------------------------------------------
  --  name:            get_order_resin_balance
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   07/02/2010
  --------------------------------------------------------------------
  --  purpose :        Calc order resin balance without the current record.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/02/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_order_resin_balance(p_customer_num  VARCHAR2,
                                   p_currency      VARCHAR2,
                                   p_order_line_id NUMBER,
                                   p_order_num     NUMBER DEFAULT NULL)
    RETURN NUMBER IS
    l_ret NUMBER;
  
  BEGIN
    SELECT SUM(credit_amount)
      INTO l_ret
      FROM xxoe_resin_balance_line_v
     WHERE customer_number = p_customer_num --
       AND currency = p_currency --'USD'
       AND order_number = nvl(p_order_num, 0) --'107174'
       AND line_id <> nvl(p_order_line_id, -1);
  
    RETURN nvl(l_ret, 0);
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RETURN NULL;
  END get_order_resin_balance;

  --------------------------------------------------------------------
  --  name:            get_item_type
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/06/2010
  --------------------------------------------------------------------
  --  purpose :        get item id and return it's item type
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/06/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_item_type(p_inventory_item_id IN NUMBER) RETURN VARCHAR2 IS
    l_item_type VARCHAR2(30) := NULL;
  BEGIN
    SELECT msi.item_type
      INTO l_item_type
      FROM mtl_system_items_b msi
     WHERE organization_id = 91
       AND inventory_item_id = p_inventory_item_id;
  
    RETURN l_item_type;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  ------------------------------------------------------------------------
  --  get_order_average_discount
  ------------------------------------------------------------------------

  ------------------------------------------------------------------------
  --  get_order_average_discount
  ------------------------------------------------------------------------

  FUNCTION get_order_average_discount(p_header_id IN NUMBER) RETURN VARCHAR2 IS
    --l_discount NUMBER;
  
    l_selling_amount             NUMBER;
    l_unit_list_amount           NUMBER;
    l_company_ga_discount_amount NUMBER;
    l_sold_to_org_id             NUMBER;
  
  BEGIN
  
    SELECT t.sold_to_org_id
      INTO l_sold_to_org_id
      FROM oe_order_headers_all t
     WHERE t.header_id = p_header_id;
  
    SELECT /*round(100 * (1 - (*/
     SUM(ordered_quantity * unit_selling_price),
     SUM(ordered_quantity *
         decode(coupon_flag,
                'Y',
                unit_selling_price,
                decode(comp_bundle_line,
                       'Y',
                       0,
                       decode(option_line,
                              'Y',
                              0,
                              decode(att4_flag,
                                     'Y',
                                     nvl(attribute4, 0),
                                     unit_list_price))))) --,     2)
      INTO l_selling_amount, l_unit_list_amount
      FROM (SELECT t.attribute4,
                   msi.item_type,
                   t.inventory_item_id,
                   ott.transaction_type_code,
                   t.line_type_id,
                   ordered_quantity,
                   unit_selling_price,
                   unit_list_price,
                   xxoe_utils_pkg.is_item_resin_credit(t.inventory_item_id) att4_flag,
                   xxoe_utils_pkg.is_coupon_item(t.inventory_item_id) coupon_flag,
                   xxoe_utils_pkg.is_comp_bundle_line(t.line_id) comp_bundle_line,
                   xxoe_utils_pkg.is_option_line(t.line_id) option_line
              FROM oe_order_lines_all       t,
                   oe_transaction_types_all ott,
                   mtl_system_items_b       msi
             WHERE t.header_id = p_header_id
               AND ott.transaction_type_id = t.line_type_id
               AND ott.transaction_type_code = 'LINE'
               AND unit_selling_price >= 0
                  --AND ordered_quantity >= 0
               AND t.line_category_code != 'RETURN'
               AND nvl(t.cancelled_flag, 'N') = 'N'
               AND nvl(ott.attribute2, 'Y') = 'Y'
               AND msi.inventory_item_id = t.inventory_item_id
               AND msi.organization_id =
                   xxinv_utils_pkg.get_master_organization_id
               AND msi.item_type NOT IN
                   (fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'),
                    fnd_profile.value('XXAR_FREIGHT_AR_ITEM')));
  
    IF xxhz_party_ga_util.is_account_ga(l_sold_to_org_id) = 'Y' THEN
    
      SELECT SUM(t.adjusted_amount * l.ordered_quantity)
        INTO l_company_ga_discount_amount
        FROM oe_price_adjustments_v t, oe_order_lines_all l
       WHERE t.header_id = p_header_id
         AND l.line_id = t.line_id
         AND (list_line_type_code <> 'CIE') --)
         AND applied_flag = 'Y'
         AND list_line_type_code <> 'FREIGHT_CHARGE'
         AND t.adjustment_name = fnd_profile.value('XX_GA_ADJUSTMENT_NAME'); -- 'XX GA_test_1' ----- ????  change to profile
      --  ORDER BY pricing_group_sequence;
    
    END IF;
  
    l_selling_amount := l_selling_amount +
                        -1 * nvl(l_company_ga_discount_amount, 0);
    RETURN round(100 * (1 - (l_selling_amount / l_unit_list_amount)), 2);
  
  EXCEPTION
    WHEN zero_divide THEN
      RETURN 'Total list price amount equal 0';
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  -------------------------------------------
  --  is_hazard_delivery
  ------------------------------------------

  --FUNCTION is_hazard_delivery(p_delivery_id NUMBER) RETURN VARCHAR2 IS -- CHG0041294 on 19/02/2018 for delivery id to name change
  FUNCTION is_hazard_delivery(p_delivery_name VARCHAR2) RETURN VARCHAR2 IS
    -- CHG0041294 on 19/02/2018 for delivery id to name change
  
    CURSOR c IS
      SELECT 'Y'
        FROM wsh_new_deliveries       wnd,
             wsh_delivery_assignments wda,
             wsh_delivery_details     wdd
       WHERE wda.delivery_id = wnd.delivery_id
         AND wda.delivery_detail_id = wdd.delivery_detail_id
         AND wnd.delivery_id =
             xxinv_trx_in_pkg.get_delivery_id(p_delivery_name) --p_delivery_id  -- CHG0041294 on 19/02/2018 for delivery id to name change
         AND xxinv_utils_pkg.is_hazard_item(wdd.inventory_item_id,
                                            wdd.organization_id) = 'Y';
  
    l_tmp VARCHAR2(1);
  
  BEGIN
  
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
  
    RETURN nvl(l_tmp, 'N');
  
  END;

  --------------------------------------------
  -- get_line_ship_to_territory
  -- used by pick slip report
  -- cr : 329
  ------------------------------------------

  FUNCTION get_line_ship_to_territory(p_line_id NUMBER) RETURN VARCHAR2 IS
    CURSOR c IS
      SELECT rt.segment1
        FROM oe_order_headers_all   oh,
             oe_order_lines_all     ol,
             hz_locations           loc,
             hz_cust_site_uses_all  hcsu,
             hz_cust_acct_sites_all addr,
             hz_party_sites         party_site,
             fnd_territories_vl     ftv,
             ra_territories_kfv     rt
       WHERE oh.header_id = ol.header_id
         AND ol.ship_to_org_id = hcsu.site_use_id
         AND addr.cust_acct_site_id = hcsu.cust_acct_site_id
         AND addr.party_site_id = party_site.party_site_id
         AND loc.location_id = party_site.location_id
         AND loc.country = ftv.territory_code
         AND rt.status = 'A'
         AND ftv.territory_short_name =
             substr(rt.name, instr(rt.name, '.') + 1) --rt.segment2
         AND ol.line_id = p_line_id;
    l_tmp VARCHAR2(50);
  
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
    RETURN l_tmp;
  END;

  --------------------------------------------------------------------
  --  name:            get_chm_pack_of
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   23.7.13
  --------------------------------------------------------------------
  --  purpose : get pack of for item
  -- return 1 = pack unit number for item
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23.7.13     yuval tal     initial build
  --------------------------------------------------------------------
  FUNCTION get_chm_pack_of(p_item_id NUMBER) RETURN NUMBER IS
    l_tmp NUMBER;
  
    CURSOR c IS
      SELECT mdev_pack_of.element_value
      
        FROM mtl_descr_element_values_v mdev_pack_of
       WHERE mdev_pack_of.inventory_item_id = p_item_id
         AND mdev_pack_of.item_catalog_group_id = 2
         AND mdev_pack_of.element_name = 'pack of';
  
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
    RETURN l_tmp;
  
  END;

  --------------------------------------------------------------------
  --  name:            show_dental_alert
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   23.7.13
  --------------------------------------------------------------------
  --  purpose :        used by form personalization SO form w-v-r
  --                   cr889 - Controlling dental materials quantities in sales orders
  --                   check resin orders for dental items for not approved customers (add quantity from screen not yet saved ),
  --                   if resin unit count overflow limit show message in so form
  -- return 1 = show message / 0 do not show message
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23.7.13     yuval tal     initial build
  --------------------------------------------------------------------

  FUNCTION show_dental_alert(p_order_number     VARCHAR2,
                             p_item_id          NUMBER,
                             p_current_quantity NUMBER,
                             p_unit_limit       NUMBER,
                             p_month_back       NUMBER) RETURN NUMBER IS
  
    l_is_dental_cust         VARCHAR2(1);
    l_unit_count             NUMBER;
    l_pack_of                NUMBER;
    l_item_code              VARCHAR2(50);
    l_ship_to_account_number VARCHAR2(50);
    l_exclude_account_flag   VARCHAR2(1);
  
    CURSOR c_is_dental_customer IS
      SELECT 'Y', acct.account_number ship_to_account_number
        FROM oe_order_headers_all   h,
             hz_cust_site_uses_all  ship_su,
             hz_cust_acct_sites_all ship_cas,
             hz_party_sites         ship_ps,
             hz_cust_accounts       acct
       WHERE ship_cas.cust_account_id = acct.cust_account_id
         AND h.ship_to_org_id = ship_su.site_use_id
         AND ship_su.cust_acct_site_id = ship_cas.cust_acct_site_id
         AND ship_cas.party_site_id = ship_ps.party_site_id
         AND h.order_number = p_order_number
            
         AND EXISTS (SELECT 1
                FROM hz_code_assignments, hz_cust_accounts hca
               WHERE hca.cust_account_id = acct.cust_account_id
                 AND class_category = 'Objet Business Type'
                 AND owner_table_id = hca.party_id
                 AND class_code = 'Dental');
    -- exclude accounts
    CURSOR c_exclude_account(c_account_number VARCHAR2) IS
    
      SELECT 'Y'
        FROM fnd_flex_values_vl p, fnd_flex_value_sets vs
       WHERE flex_value = to_char(c_account_number)
         AND p.flex_value_set_id = vs.flex_value_set_id
         AND vs.flex_value_set_name = 'XXOM_DENTAL_APPROVED_CUSTOMERS'
         AND nvl(p.enabled_flag, 'N') = 'Y';
  
    -- get unit sold
    CURSOR c_get_units_sold IS
      SELECT SUM(total_units)
        FROM (SELECT (l.ordered_quantity *
                     nvl(get_chm_pack_of(l.inventory_item_id), 1)) total_units
              
                FROM oe_order_headers_all h,
                     oe_order_headers_all h2,
                     oe_order_lines_all   l
              
               WHERE h2.flow_status_code IN ('CLOSED', 'BOOKED')
                 AND l.header_id = h2.header_id
                 AND h.order_number = p_order_number --'202609'
                 AND h2.order_number != h.order_number
                 AND h2.sold_to_org_id = h.sold_to_org_id
                 AND nvl(l.cancelled_flag, 'N') != 'Y'
                 AND h2.ordered_date >=
                     add_months(SYSDATE, -1 * p_month_back)
                 AND xxobjt_general_utils_pkg.get_valueset_desc('XXOM_DENTAL_ITEMS',
                                                                l.ordered_item,
                                                                'ACTIVE') IS NOT NULL
              UNION ALL
              -- get quantity from current order
              SELECT (l.ordered_quantity *
                     nvl(get_chm_pack_of(l.inventory_item_id), 1)) total_units
              
                FROM oe_order_headers_all h, oe_order_lines_all l
               WHERE h.order_number = p_order_number
                 AND l.header_id = h.header_id
                 AND xxobjt_general_utils_pkg.get_valueset_desc('XXOM_DENTAL_ITEMS',
                                                                l.ordered_item,
                                                                'ACTIVE') IS NOT NULL
                    --'202609'
                 AND nvl(l.cancelled_flag, 'N') != 'Y');
  
  BEGIN
    l_pack_of   := nvl(get_chm_pack_of(p_item_id), 1);
    l_item_code := xxinv_utils_pkg.get_item_segment(p_item_id, 91);
  
    --  Is dental item
    IF xxobjt_general_utils_pkg.get_valueset_desc('XXOM_DENTAL_ITEMS',
                                                  l_item_code,
                                                  'ACTIVE') IS NOT NULL THEN
    
      OPEN c_is_dental_customer;
      FETCH c_is_dental_customer
        INTO l_is_dental_cust, l_ship_to_account_number;
      CLOSE c_is_dental_customer;
      -- is dental customer
      IF nvl(l_is_dental_cust, 'N') = 'N' THEN
        RETURN 1;
      
      ELSE
      
        -- check exclude accounts
        OPEN c_exclude_account(l_ship_to_account_number);
        FETCH c_exclude_account
          INTO l_exclude_account_flag;
        CLOSE c_exclude_account;
      
        IF nvl(l_exclude_account_flag, 'N') = 'N' THEN
          --  is quantity overflow limit
          OPEN c_get_units_sold;
          FETCH c_get_units_sold
            INTO l_unit_count;
          dbms_output.put_line('Past unit count=' || l_unit_count);
          dbms_output.put_line('Current units=' ||
                               (l_pack_of * p_current_quantity));
        
          CLOSE c_get_units_sold;
          IF l_unit_count + (l_pack_of * p_current_quantity) > p_unit_limit THEN
          
            RETURN 1;
          END IF;
        END IF;
      END IF; -- is dental customer
    
    END IF; -- Is dental item
  
    RETURN 0;
  END;

  --------------------------------------------------------------------
  --  name:            show_dis_get_line
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   19/02/2014
  --------------------------------------------------------------------
  --  purpose :        REP009 - Order Acknowledgment
  --                   CR1327 - Adjustment for Dental Advantage Sticker
  --                   The function will look if the oe_line have adjustment from
  --                   type discount, and will check for each adjustment found
  --                   at the modifier what is the value at the modifier att3.
  --                   this will determine if to show or not the line at reports.
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  19/02/2014  Dalit A. Raviv  initial build
  --  1.1 5.6.14       yuval tal       CHG0031865  change p_line_id type from number to char
  --------------------------------------------------------------------
  FUNCTION show_dis_get_line(p_line_id IN VARCHAR2) RETURN VARCHAR2 IS
    CURSOR get_adjustment_c(p_line_id IN NUMBER) IS
      SELECT opa.list_line_id
        FROM oe_order_lines_all ol, oe_price_adjustments_v opa
       WHERE opa.line_id = ol.line_id
         AND opa.list_line_type_code = 'DIS'
         AND ol.line_id = p_line_id; --1217869 , 1217870
  
    CURSOR get_modifier_c(p_line_list_id IN NUMBER) IS
      SELECT nvl(qpag.attribute3, 'Y') attribute3
        FROM qp_pricing_attr_get_v qpag
       WHERE qpag.list_line_id = p_line_list_id; -- 2666781 , 2666777
  
    l_return VARCHAR2(10) := 'Y';
  BEGIN
    -- 1. Get line adjustments
    FOR get_adjustment_r IN get_adjustment_c(p_line_id) LOOP
      -- 3. Get Modifier Details DFF Attribute3
      FOR get_modifier_r IN get_modifier_c(get_adjustment_r.list_line_id) LOOP
        IF get_modifier_r.attribute3 = 'NO' THEN
          l_return := 'N';
          EXIT;
        END IF;
      END LOOP;
      IF l_return = 'N' THEN
        EXIT;
      END IF;
    END LOOP;
    -- if loop 1 did not have any population the l_return value will get the value assugn at the declare
    -- else it will get it from the loop.
    RETURN l_return;
  
  EXCEPTION
    WHEN OTHERS THEN
      -- allways return Y - to show the line
      RETURN 'Y';
    
  END show_dis_get_line;

  --------------------------------------------------------------------
  --  name:            get_shipping_instructions
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/03/2014
  --------------------------------------------------------------------
  --  purpose :        get shipp to instructions by so header id and ship to location id
  --                   ship_to_org_id from the So show the ship to location information
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/03/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_shipping_instructions(p_ship_to_org_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_shipping_instructions VARCHAR2(240) := NULL;
  BEGIN
    SELECT nvl(h.attribute10, hca.attribute9) shipping_instructions
      INTO l_shipping_instructions
      FROM hz_cust_site_uses_all  h,
           hz_cust_accounts       hca,
           hz_cust_acct_sites_all hh
     WHERE 1 = 1
       AND h.site_use_id = p_ship_to_org_id
       AND hca.cust_account_id = hh.cust_account_id
       AND hh.cust_acct_site_id = h.cust_acct_site_id;
    --      oh.order_number        = '1001960'
  
    RETURN l_shipping_instructions;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------------
  --  name:            get_cancelation_comment
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   9.6.14
  --------------------------------------------------------------------
  --  purpose :       get caelation comment of sales order LINE , if null then looks for comment in header level
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/03/2014  yuval tal         initial build
  --------------------------------------------------------------------

  FUNCTION get_cancelation_comment(p_header_id NUMBER,
                                   p_line_id   NUMBER DEFAULT NULL)
    RETURN VARCHAR2 IS
    l_comment oe_reasons_v.comments%TYPE;
  BEGIN
  
    IF p_line_id IS NOT NULL THEN
    
      SELECT t.comments
        INTO l_comment
        FROM oe_reasons_v t
       WHERE t.reason_type_code = 'CANCEL_CODE'
         AND entity_code = 'LINE'
         AND t.header_id = p_header_id
         AND t.entity_id = p_line_id;
    
    END IF;
  
    IF l_comment IS NULL THEN
      SELECT t.comments
        INTO l_comment
        FROM oe_reasons_v t
       WHERE t.reason_type_code = 'CANCEL_CODE'
         AND entity_code = 'HEADER'
         AND t.header_id = p_header_id;
    END IF;
  
    RETURN l_comment;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END;
  --------------------------------
  FUNCTION is_model_line(p_line_id NUMBER) RETURN VARCHAR2 IS
    l_ret VARCHAR2(1) := 'N';
  BEGIN
    SELECT 'Y'
      INTO l_ret
      FROM oe_order_lines_all ol, mtl_system_items_b mb
     WHERE ol.line_id = p_line_id
       AND ol.item_type_code = 'MODEL'
       AND mb.inventory_item_id = ol.inventory_item_id
       AND mb.bom_item_type = 1
       AND mb.organization_id = ol.ship_from_org_id;
    RETURN l_ret;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END is_model_line;

  --------------------------------------------------------------------
  --  name:            is_option_line
  --  create by:
  --  Revision:
  --  creation date:
  ---------------------------------------------------------
  --  ver    date            name           desc
  --------------------------------------------------------
  --     1.X   12.11.2014    Ofer Suad      CHG0033824 -  Fix Revenue Distribution for PTO's Bundles
  --     1.1   26.05.2016    L Sarangi      INC0065232 -Dist Functional Amount Wrong on OM general report
  --     1.2   19.01.2017    L Sarangi      CHG0039931 - Correct avarage discount claculation for Kit in PTO order
  --     1.3   23.7.2017     yuval tal      CHG0041110 - modify is_option_line : PTO type Model item at zero amount
  ---------------------------------------------------------------------------
  FUNCTION is_option_line(p_line_id NUMBER) RETURN VARCHAR2
  
   IS
    l_ret VARCHAR2(1) := 'N';
    --  l_parent_unit_selling_price NUMBER; -- 12.11.2014    Ofer Suad      CHG0033824 --  CHG0041110
  BEGIN
    SELECT 'Y'
      INTO l_ret
      FROM oe_order_lines_all ol
     WHERE ol.line_id = p_line_id
          --AND    ol.item_type_code = 'OPTION' --CHG0039931 Commented on 19th Jan 2017
       AND ol.item_type_code IN --CHG0039931 the And Condition Added on 19th Jan 2017
           (SELECT flv.lookup_code
              FROM fnd_lookup_values flv
             WHERE flv.lookup_type = 'XXOE_PTO_COMPONENT_ITEM_TYPE'
               AND flv.language = 'US'
               AND flv.enabled_flag = 'Y'
               AND SYSDATE BETWEEN nvl(flv.start_date_active, SYSDATE - 1) AND
                   nvl(flv.end_date_active, SYSDATE + 1)
            
            )
       AND ol.top_model_line_id <> p_line_id; -- CHG0041110
  
    /*
    -- 12.11.2014    Ofer Suad      CHG0033824
                 Check  parent model unit selling price
                 If it is zero - Education order - it is not PTO option line
                 IF <> Zero - it is  PTO option line
    */
    -- CHG0041110 put in comment
    /*  BEGIN
      SELECT l.unit_selling_price
      INTO   l_parent_unit_selling_price
      FROM   oe_order_lines_all l
      WHERE  l.line_id =
             (SELECT ll.top_model_line_id
              FROM   oe_order_lines_all ll \*INC0065232 - Modified oe_order_lines to oe_order_lines_all *\
              WHERE  ll.line_id = p_line_id
              AND    ll.top_model_line_id <> ll.line_id); --CHG0039931 Added On 19th Jan 2017
    
      IF nvl(l_parent_unit_selling_price, 0) = 0 THEN
        l_ret := 'N';
      ELSE
        l_ret := 'Y';
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        l_ret := 'N';
    END;*/
    RETURN l_ret;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END is_option_line;
  --------------------------------------------------------------------
  --  customization code: CHG0032651
  --  name:               om_print_config_option
  --  create by:          Michal Tzvik
  --  Revision:
  --  creation date:
  --  Purpose :           Return Y if so line is ATO or PTO. Else return N.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   07.09.2014    Michal Tzvik    Initial Build
  -------------------------------------------------------
  FUNCTION om_print_config_option(p_so_line_id NUMBER) RETURN VARCHAR2 IS
    l_om_print_config_option VARCHAR2(1);
  
  BEGIN
  
    SELECT nvl(MAX('Y'), 'N')
      INTO l_om_print_config_option
      FROM ont.oe_order_lines_all   oola1,
           ont.oe_order_lines_all   oola2,
           bom_bill_of_materials    bill,
           bom_inventory_components comp,
           oe_sys_parameters_all    oesys
     WHERE oola1.line_id = p_so_line_id
       AND oola1.top_model_line_id <> oola1.line_id -- ATO/PTO Component Condition
       AND oola1.inventory_item_id = comp.component_item_id
       AND oola1.link_to_line_id = oola2.line_id
       AND oola1.org_id = oesys.org_id
       AND oesys.parameter_code = 'MASTER_ORGANIZATION_ID'
       AND bill.organization_id = oesys.parameter_value
       AND bill.bill_sequence_id = comp.bill_sequence_id
       AND bill.assembly_item_id = oola2.inventory_item_id
       AND nvl(comp.attribute1, 'Y') = 'N';
  
    RETURN l_om_print_config_option;
  
  END om_print_config_option;

  --------------------------------------------------------------------
  --  name:            IS_LINE_ORDER_UNDER_CONTRACT
  --  create by:       Adi Safin
  --  Revision:        1.0
  --  creation date:   07/10/2014
  --------------------------------------------------------------------
  --  purpose :        Function for Custom clearence report. Check according order line id
  --                   if it RMA(return and Replace) order (depot repair or SFDC) and the Printer is under contract
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  07/10/2014  Adi Safin        initial build
  --  1.1  23/12/2018  Roman W          CHG0044705 - Commercial Invoice - change logic to identify lines under service contract  
  --------------------------------------------------------------------
  FUNCTION is_line_order_under_contract(p_line_id IN NUMBER) RETURN VARCHAR2 IS
    l_is_machine_under_contract VARCHAR2(5) := 'N';
    l_service_application       VARCHAR2(15) := nvl(fnd_profile.value('XXINV_TPL_SERVICE_APPLICATION'),
                                                    'Oracle');
  BEGIN
  
    BEGIN
      -- start 
    
      SELECT 'Y'
        INTO l_is_machine_under_contract
        FROM oe_order_lines_all oola, XXOKC_SRV_CONTARCT_DTL_V osc
       WHERE oola.unit_selling_price = 0
         AND oola.attribute1 = to_char(osc.Asset_External_Key)
         AND xxinv_utils_pkg.get_category_segment('SEGMENT1',
                                                  1100000221,
                                                  oola.INVENTORY_ITEM_ID) =
             'Customer Support' -- FROM Product Hierarchy
         AND oola.line_id = p_line_id
         AND trunc(oola.pricing_date) BETWEEN osc.start_date AND
             osc.end_date;
    
      RETURN(l_is_machine_under_contract);
    
    EXCEPTION
      WHEN no_data_found THEN
        l_is_machine_under_contract := 'N'; -- RMA orders not from SFDC or not under contract
    END;
  
    IF l_service_application = 'SFDC' THEN
      -- Query for new SFDC
      BEGIN
        SELECT 'Y'
          INTO l_is_machine_under_contract
          FROM fnd_flex_value_sets  ffvs,
               fnd_flex_values      ffv,
               fnd_flex_values_tl   ffvt,
               oe_order_headers_all ooha,
               oe_order_lines_all   oola
         WHERE ffvs.flex_value_set_name = 'XXOM_SF2OA_Order_Types_Mapping'
           AND ffvs.flex_value_set_id = ffv.flex_value_set_id
           AND ffvt.flex_value_id = ffv.flex_value_id
           AND ffvt.language = 'US'
           AND ffv.enabled_flag = 'Y'
           AND ffv.attribute1 = '1' -- For return and replacement orders only
           AND ffv.attribute3 = to_char(ooha.order_type_id) -- Order type
           AND ooha.header_id = oola.header_id
           AND oola.line_id = p_line_id
           AND ooha.order_source_id = 1001 -- SERVICE SFDC
           AND ooha.attribute12 IS NOT NULL -- machine SN
           AND oola.unit_selling_price = 0;
      
      EXCEPTION
        WHEN no_data_found THEN
          l_is_machine_under_contract := 'N'; -- RMA orders not from SFDC or not under contract
      END;
    
    ELSE
      -- for order came from depot repair and the customer has contract for the machine
      BEGIN
        SELECT 'Y'
          INTO l_is_machine_under_contract
          FROM oe_order_headers_all ooha,
               oe_order_lines_all   oola,
               cs_incidents_all_b   cal
         WHERE ooha.header_id = oola.header_id
           AND ooha.source_document_type_id = 7 -- Service Billing.
           AND cal.incident_type_id = 11017 -- RMA Service request type
           AND cal.contract_number IS NOT NULL -- under warranty or contract
           AND oola.line_id = p_line_id
           AND cal.incident_number = ooha.orig_sys_document_ref;
      EXCEPTION
        WHEN no_data_found THEN
          -- Order not related to depot repair or machine not under contract
          l_is_machine_under_contract := 'N';
      END;
    
      IF l_is_machine_under_contract = 'N' THEN
        -- Query for old SFDC
        BEGIN
          SELECT 'Y'
            INTO l_is_machine_under_contract
            FROM fnd_flex_value_sets  ffvs,
                 fnd_flex_values      ffv,
                 fnd_flex_values_tl   ffvt,
                 oe_order_headers_all ooha,
                 oe_order_lines_all   oola
           WHERE ffvs.flex_value_set_name =
                 'XXOM_SF2OA_Order_Types_Mapping'
             AND ffvs.flex_value_set_id = ffv.flex_value_set_id
             AND ffvt.flex_value_id = ffv.flex_value_id
             AND ffvt.language = 'US'
             AND ffv.enabled_flag = 'Y'
             AND ffv.attribute1 = '1' -- For return and replacement orders only
             AND ffv.attribute3 = to_char(ooha.order_type_id) -- Order type
             AND ooha.header_id = oola.header_id
             AND ooha.order_source_id = 1001 -- SERVICE SFDC
             AND oola.line_id = p_line_id
             AND oola.attribute14 IS NOT NULL -- machine SN
             AND oola.unit_selling_price = 0;
        EXCEPTION
          WHEN no_data_found THEN
            l_is_machine_under_contract := 'N'; -- RMA orders not from SFDC or not under contract
        END;
      END IF;
    END IF;
  
    RETURN(l_is_machine_under_contract);
  
  END is_line_order_under_contract;
  --------------------------------------------------------------------
  --  customization code: CHG0033602
  --  name:               is_item_service_contract
  --  create by:          Michal Tzvik
  --  Revision:
  --  creation date:
  --  Purpose :           Return Y if item is Service Contract, else return N.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   04.11.2014    Michal Tzvik    Initial Build
  -------------------------------------------------------
  FUNCTION is_item_service_contract(p_inventory_item_id NUMBER)
    RETURN VARCHAR2 IS
    l_is_item_service_contract VARCHAR2(1);
  BEGIN
    SELECT nvl(MAX('Y'), 'N')
      INTO l_is_item_service_contract
      FROM mtl_item_categories_v mic_sc, mtl_system_items_b msi
     WHERE 1 = 1
       AND msi.inventory_item_id = p_inventory_item_id
       AND msi.organization_id = 91
       AND mic_sc.inventory_item_id = msi.inventory_item_id
       AND mic_sc.organization_id = msi.organization_id
       AND mic_sc.category_set_name = 'Activity Analysis'
       AND mic_sc.segment1 = 'Contracts'
       AND msi.inventory_item_status_code NOT IN
           ('XX_DISCONT', 'Inactive', 'Obsolete')
       AND msi.coverage_schedule_id IS NULL
       AND msi.primary_uom_code != 'EA';
  
    RETURN l_is_item_service_contract;
  
  END is_item_service_contract;

  --------------------------------------------------------------------
  --  customization code: CHG0033848
  --  name:               get_qp_list_price
  --  create by:          Michal Tzvik
  --  Revision:
  --  creation date:
  --  Purpose :           Get price from price list. Used when price_list in so line is 0
  --                      (PTO component lines, for example)
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   22.01.2015    Michal Tzvik    Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_qp_list_price(p_line_id NUMBER) RETURN NUMBER IS
    l_list_price NUMBER := 0;
    l_line_rec   oe_order_lines_all%ROWTYPE;
  BEGIN
  
    SELECT *
      INTO l_line_rec
      FROM oe_order_lines_all olla
     WHERE olla.line_id = p_line_id;
  
    IF xxoe_utils_pkg.is_item_resin_credit(l_line_rec.inventory_item_id) = 'Y' THEN
      RETURN nvl(l_line_rec.attribute4, 0);
    END IF;
  
    -- Price from Order Price List
    SELECT MAX(inv_convert.inv_um_convert_new(l_line_rec.inventory_item_id,
                                              
                                              NULL,
                                              
                                              qllv.operand,
                                              
                                              l_line_rec.order_quantity_uom,
                                              
                                              qllv.product_uom_code,
                                              
                                              NULL,
                                              NULL,
                                              'U'))
      INTO l_list_price
      FROM qp_list_lines_v qllv
     WHERE qllv.list_header_id = l_line_rec.price_list_id
       AND (qllv.end_date_active IS NULL OR
           trunc(qllv.end_date_active) >= trunc(SYSDATE))
       AND qllv.product_attribute_context = 'ITEM'
       AND qllv.product_attr_value = to_char(l_line_rec.inventory_item_id);
  
    IF l_list_price IS NULL THEN
      -- Price from Secondary Price List
      SELECT nvl(MAX(inv_convert.inv_um_convert_new(l_line_rec.inventory_item_id,
                                                    
                                                    NULL,
                                                    
                                                    qllv.operand,
                                                    
                                                    l_line_rec.order_quantity_uom,
                                                    
                                                    qllv.product_uom_code,
                                                    
                                                    NULL,
                                                    NULL,
                                                    'U')),
                 0)
        INTO l_list_price
        FROM qp_secondary_price_lists_v qspl, qp_list_lines_v qllv
       WHERE to_char(l_line_rec.price_list_id) = qspl.parent_price_list_id
         AND qllv.list_header_id = qspl.list_header_id
         AND qllv.product_attribute_context = 'ITEM'
         AND (qllv.end_date_active IS NULL OR
              trunc(qllv.end_date_active) >= trunc(SYSDATE))
         AND qllv.product_attr_value =
             to_char(l_line_rec.inventory_item_id);
    END IF;
    RETURN l_list_price;
  
  END get_qp_list_price;

  --------------------------------------------------------------------
  --  name:            is_Restricted_delivery
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   07-Mar-2016
  --------------------------------------------------------------------
  --  purpose :        CHG0037863
  --                   DG- Add indication on Shipping Docs for Non Restricted items
  --                   The function will return Y if the delivery conatins any DG Restricted Item
  --                   Will Return N , if the delivery conatins any DG non Restricted Item only or Non DG item and DG non restricted Item
  --                   Will Return null,if the delivery conatins only Non DG Item
  --------------------------------------------------------------------
  --  ver  date         name                 desc
  --  1.0  07-Mar-2016  Lingaraj Sarangi     initial version
  --------------------------------------------------------------------
  --FUNCTION is_dg_restricted_delivery(p_delivery_id NUMBER) RETURN VARCHAR2 IS    -- CHG0041294 on 19/02/2018 for delivery id to name change
  FUNCTION is_dg_restricted_delivery(p_delivery_name VARCHAR2)
    RETURN VARCHAR2 IS
    -- CHG0041294 on 19/02/2018 for delivery id to name change
  
    CURSOR c IS
      SELECT DISTINCT msi.inventory_item_id, msi.organization_id
        FROM wsh_deliverables_v wdv, mtl_system_items_b msi
       WHERE wdv.delivery_id =
             xxinv_trx_in_pkg.get_delivery_id(p_delivery_name) --p_delivery_id  -- CHG0041294 on 19/02/2018 for delivery id to name change
         AND wdv.inventory_item_id = msi.inventory_item_id
         AND wdv.organization_id = msi.organization_id
         AND xxinv_utils_pkg.is_hazard_item(msi.inventory_item_id,
                                            msi.organization_id) = 'Y';
  
    l_is_item_restricted VARCHAR2(1) := NULL;
  BEGIN
    --IF xxoe_utils_pkg.is_hazard_delivery(p_delivery_id) = 'N' THEN  -- CHG0041294 on 19/02/2018 for delivery id to name change
    IF xxoe_utils_pkg.is_hazard_delivery(p_delivery_name) = 'N' THEN
      -- CHG0041294 on 19/02/2018 for delivery id to name change
      --No hazard Item Found in the Delivery
      RETURN NULL;
    ELSE
      FOR rec IN c LOOP
        l_is_item_restricted := xxinv_utils_pkg.is_item_restricted(rec.inventory_item_id);
        IF l_is_item_restricted IS NULL OR l_is_item_restricted = 'Y' THEN
          RETURN 'Y'; -- If Restricted DG Item found
        END IF;
      END LOOP;
      RETURN 'N'; --The Delivery Contains DG items but the DG items are not restricted
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END is_dg_restricted_delivery;

  ------------------------------------------------------------
  -- Name: safe_devisor

  --  ver  date        name           desc
  ------------------------------------------------------------
  -- 1.26 29.5.2016   yuval tal         INC0064627  modify  add
  --                                    get_price_list_dist proc  from  xxar_autoinvoice_pkg.get_price_list_dist

  FUNCTION safe_devisor(p_devisor NUMBER) RETURN NUMBER IS
  BEGIN
    IF p_devisor IS NULL THEN
      RETURN 1;
    ELSIF p_devisor = 0 THEN
      RETURN 1;
    ELSE
      RETURN p_devisor;
    END IF;
  
  END safe_devisor;
  ------------------------------------------------------------
  -- Name: get_precision

  --  ver  date        name           desc
  ------------------------------------------------------------
  -- 1.26 29.5.2016   yuval tal         INC0064627  modify  add
  --                                    get_price_list_dist proc  from  xxar_autoinvoice_pkg.get_price_list_dist

  FUNCTION get_precision(p_currency_code VARCHAR2) RETURN NUMBER IS
    lv_precision fnd_currencies.precision%TYPE;
  BEGIN
  
    SELECT PRECISION
      INTO lv_precision
      FROM fnd_currencies c
     WHERE c.currency_code = p_currency_code;
  
    RETURN lv_precision;
  
  END get_precision;
  ------------------------------------------------------------
  -- Name: get_price_list_dist

  --  ver  date        name           desc
  ------------------------------------------------------------
  -- 1.26 29.5.2016   yuval tal         INC0064627  modify  add
  --                                    get_price_list_dist proc  from  xxar_autoinvoice_pkg.get_price_list_dist

  FUNCTION get_price_list_dist(p_line_id    NUMBER,
                               p_price_list NUMBER,
                               p_attribute4 NUMBER) RETURN NUMBER IS
  
    l_is_resin              VARCHAR2(1);
    l_cupon_amt             NUMBER;
    l_bundle_line_amt       NUMBER;
    l_comp_bundle_total_amt NUMBER;
    l_option_total_amt      NUMBER; --22/10/2014 Ofer Suad #CHG0032650
    l_option_qty            NUMBER; --22/10/2014 Ofer Suad #CHG0032650
    l_temp_option_total_amt NUMBER; --22/10/2014 Ofer Suad #CHG0032650
    l_option_line_amt       NUMBER; --22/10/2014 Ofer Suad #CHG0032650
    l_model_amt             NUMBER; --22/10/2014 Ofer Suad #CHG0032650
    l_resin_amt             NUMBER; --22/10/2014 Ofer Suad #CHG0032650
  
    CURSOR c_option_line IS --22/10/2014 Ofer Suad #CHG0032650
      SELECT ol.inventory_item_id,
             ol.ordered_quantity,
             ol.line_id,
             ol.price_list_id,
             ol.order_quantity_uom
        FROM oe_order_lines_all ol
       WHERE (ol.header_id, ol.top_model_line_id) =
             (SELECT header_id, ol1.top_model_line_id
                FROM oe_order_lines_all ol1
               WHERE ol1.line_id = p_line_id)
         AND xxoe_utils_pkg.is_option_line(ol.line_id) = 'Y';
  
  BEGIN
    --Begin 22/10/2014 Ofer Suad #CHG0032650
    SELECT decode(msi.item_type,
                  fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE'),
                  'Y',
                  'N')
      INTO l_is_resin
      FROM oe_order_lines_all ol, mtl_system_items_b msi
     WHERE ol.line_id = p_line_id
       AND ol.inventory_item_id = msi.inventory_item_id
       AND nvl(ol.ship_from_org_id,
               xxinv_utils_pkg.get_master_organization_id) =
           msi.organization_id;
  
    SELECT nvl(SUM(ol.attribute4), 0)
      INTO l_resin_amt
      FROM oe_order_lines_all ol, mtl_system_items_b msi
     WHERE (ol.header_id, ol.top_model_line_id) =
           (SELECT header_id, ol1.top_model_line_id
              FROM oe_order_lines_all ol1
             WHERE ol1.line_id = p_line_id)
       AND ol.inventory_item_id = msi.inventory_item_id
       AND nvl(ol.ship_from_org_id,
               xxinv_utils_pkg.get_master_organization_id) =
           msi.organization_id
       AND msi.item_type = fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE');
  
    SELECT round(nvl(SUM(ol.ordered_quantity * ol.unit_list_price), 0),
                 get_precision(MAX(oh.transactional_curr_code)))
      INTO l_model_amt
      FROM oe_order_lines_all ol, oe_order_headers_all oh
     WHERE xxoe_utils_pkg.is_model_line(ol.line_id) = 'Y'
       AND oh.header_id = ol.header_id
       AND (ol.header_id, ol.top_model_line_id) =
           (SELECT header_id, ol1.top_model_line_id
              FROM oe_order_lines_all ol1
             WHERE ol1.line_id = p_line_id);
  
    l_option_total_amt := 0;
  
    FOR i IN c_option_line LOOP
      IF i.line_id = p_line_id THEN
        l_option_qty := i.ordered_quantity;
      END IF;
      l_temp_option_total_amt := 0;
      SELECT MAX(i.ordered_quantity *
                 inv_convert.inv_um_convert_new(i.inventory_item_id,
                                                NULL,
                                                pll1.operand,
                                                i.order_quantity_uom,
                                                pll1.product_uom_code,
                                                NULL,
                                                NULL,
                                                'U'))
        INTO l_temp_option_total_amt
        FROM apps.qp_list_lines_v pll1
       WHERE pll1.list_header_id = i.price_list_id
         AND nvl(trunc(pll1.end_date_active), trunc(SYSDATE + 1)) >=
             trunc(SYSDATE)
         AND pll1.product_attr_value = to_char(i.inventory_item_id);
      IF l_temp_option_total_amt IS NULL THEN
        BEGIN
          SELECT operand * i.ordered_quantity
            INTO l_temp_option_total_amt
            FROM (SELECT inv_convert.inv_um_convert_new(i.inventory_item_id,
                                                        NULL,
                                                        pll2.operand,
                                                        i.order_quantity_uom,
                                                        pll2.product_uom_code,
                                                        
                                                        NULL,
                                                        NULL,
                                                        'U') operand,
                         qspl.precedence
                  
                    FROM apps.qp_secondary_price_lists_v qspl,
                         apps.qp_list_lines_v            pll2
                   WHERE to_char(i.price_list_id) =
                         qspl.parent_price_list_id
                     AND pll2.list_header_id = qspl.list_header_id
                     AND nvl(trunc(pll2.end_date_active), trunc(SYSDATE + 1)) >=
                         trunc(SYSDATE)
                     AND to_char(i.inventory_item_id) =
                         pll2.product_attr_value
                   ORDER BY precedence)
           WHERE rownum = 1;
        EXCEPTION
          WHEN no_data_found THEN
            l_temp_option_total_amt := 0;
        END;
      END IF;
      l_option_total_amt := l_option_total_amt + l_temp_option_total_amt;
    END LOOP;
  
    BEGIN
      SELECT MAX(ol.ordered_quantity *
                 inv_convert.inv_um_convert_new(ol.inventory_item_id,
                                                NULL,
                                                pll1.operand,
                                                ol.order_quantity_uom,
                                                pll1.product_uom_code,
                                                
                                                NULL,
                                                NULL,
                                                'U')) operand
        INTO l_option_line_amt
        FROM apps.qp_list_lines_v pll1, oe_order_lines_all ol
       WHERE pll1.list_header_id = ol.price_list_id
         AND nvl(trunc(pll1.end_date_active), trunc(SYSDATE + 1)) >=
             trunc(SYSDATE)
         AND pll1.product_attr_value = to_char(ol.inventory_item_id)
         AND ol.line_id = p_line_id;
    
      IF l_option_line_amt IS NULL THEN
        SELECT operand
          INTO l_option_line_amt
          FROM (SELECT ol.ordered_quantity *
                       inv_convert.inv_um_convert_new(ol.inventory_item_id,
                                                      NULL,
                                                      pll2.operand,
                                                      ol.order_quantity_uom,
                                                      pll2.product_uom_code,
                                                      
                                                      NULL,
                                                      NULL,
                                                      'U') operand,
                       qspl.precedence
                
                  FROM apps.qp_secondary_price_lists_v qspl,
                       apps.qp_list_lines_v            pll2,
                       oe_order_lines_all              ol
                 WHERE ol.line_id = p_line_id
                   AND to_char(ol.price_list_id) = qspl.parent_price_list_id
                   AND pll2.list_header_id = qspl.list_header_id
                   AND nvl(trunc(pll2.end_date_active), trunc(SYSDATE + 1)) >=
                       trunc(SYSDATE)
                   AND to_char(ol.inventory_item_id) =
                       pll2.product_attr_value
                 ORDER BY qspl.precedence)
         WHERE rownum = 1;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        l_option_line_amt := 0;
    END;
    -- end 22/10/2014 Ofer Suad #CHG0032650
  
    IF xxoe_utils_pkg.is_bundle_line(p_line_id) = 'Y' OR
       xxoe_utils_pkg.is_model_line(p_line_id) = 'Y' THEN
      RETURN 0;
    ELSIF xxoe_utils_pkg.is_comp_bundle_line(p_line_id) = 'Y' THEN
      SELECT SUM(ol.unit_list_price)
        INTO l_bundle_line_amt
        FROM oe_order_lines_all ol
       WHERE ol.header_id = (SELECT ol1.header_id
                               FROM oe_order_lines_all ol1
                              WHERE ol1.line_id = p_line_id)
         AND xxoe_utils_pkg.is_bundle_line(ol.line_id) = 'Y';
    
      SELECT SUM(ol.unit_list_price * ol.ordered_quantity)
        INTO l_comp_bundle_total_amt
        FROM oe_order_lines_all ol
       WHERE ol.header_id = (SELECT ol1.header_id
                               FROM oe_order_lines_all ol1
                              WHERE ol1.line_id = p_line_id)
         AND xxoe_utils_pkg.is_comp_bundle_line(ol.line_id) = 'Y';
      RETURN l_bundle_line_amt *(p_price_list /
                                 safe_devisor(l_comp_bundle_total_amt)); --CHG0035690 add safe_devisor
    
    ELSIF xxoe_utils_pkg.is_option_line(p_line_id) = 'Y'
    
     THEN
      IF l_is_resin = 'N' THEN
        RETURN(l_option_line_amt / safe_devisor(l_option_qty)) *(l_model_amt / ----CHG0035690 add safe_devisor
                                                                 safe_devisor(l_option_total_amt + --CHG0035690 add safe_devisor
                                                                              l_resin_amt));
      ELSE
        RETURN l_resin_amt *(l_model_amt /
                             safe_devisor(l_option_total_amt + l_resin_amt)); --CHG0035690 add safe_devisor
      END IF;
    ELSE
      BEGIN
      
        SELECT ol.unit_selling_price
          INTO l_cupon_amt
          FROM oe_order_lines_all ol, mtl_system_items_b msi
         WHERE ol.line_id = p_line_id
           AND ol.inventory_item_id = msi.inventory_item_id
           AND ol.ship_from_org_id = msi.organization_id
           AND msi.item_type = fnd_profile.value('XXAR_COUPON_ITEM_TYPE');
        RETURN l_cupon_amt;
      EXCEPTION
        WHEN no_data_found THEN
          BEGIN
          
            SELECT 'Y'
              INTO l_is_resin
              FROM oe_order_lines_all ol, mtl_system_items_b msi
             WHERE ol.line_id = p_line_id
               AND ol.inventory_item_id = msi.inventory_item_id
               AND nvl(ol.ship_from_org_id,
                       xxinv_utils_pkg.get_master_organization_id) =
                   msi.organization_id
               AND msi.item_type !=
                   fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE');
          
            RETURN p_price_list;
          
          EXCEPTION
            WHEN no_data_found THEN
            
              RETURN p_attribute4;
            
          END;
        
      END;
    END IF;
  END get_price_list_dist;

  ------------------------------------------------------------
  -- Name: get_resin_credit_description
  -- Description: Returns the resin credit line description
  -- If resin amount is 0 or less null is returned
  ------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   12/28/2016    Dipta Chatterjee  CHG0039567- Resin Credit balance is not correct
  ------------------------------------------------------------
  FUNCTION get_resin_credit_description(p_line_id NUMBER) RETURN VARCHAR2 IS
    CURSOR cur_order_details IS
      SELECT ol.inventory_item_id,
             (to_number(nvl(ol.attribute4, '0'))) resin_credit_amount,
             oh.transactional_curr_code currency_code,
             ol.ship_from_org_id
        FROM oe_order_lines_all ol, oe_order_headers_all oh
       WHERE ol.line_id = p_line_id
         AND ol.header_id = oh.header_id;
  
    l_desc VARCHAR2(2000);
  BEGIN
  
    FOR rec IN cur_order_details LOOP
      l_desc := xxinv_utils_pkg.get_item_desc_tl(rec.inventory_item_id,
                                                 rec.ship_from_org_id,
                                                 fnd_global.org_id);
      IF rec.resin_credit_amount > 0 THEN
        l_desc := rec.currency_code || ' ' || rec.resin_credit_amount || ' ' ||
                  l_desc;
      END IF;
    END LOOP;
  
    RETURN l_desc;
  END get_resin_credit_description;

  --------------------------------------------------------------------
  --  customization code: CHG0040093
  --  name:               is_item_service_warranty
  --  create by:          Adi Safin
  --  Revision:
  --  creation date:
  --  Purpose :           Return Y if item is Service Warranty, else return N.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   14.02.2017    Adi Safin    Initial Build
  -------------------------------------------------------
  FUNCTION is_item_service_warranty(p_inventory_item_id NUMBER)
    RETURN VARCHAR2 IS
    l_is_item_service_contract VARCHAR2(1);
  BEGIN
    SELECT nvl(MAX('Y'), 'N')
      INTO l_is_item_service_contract
      FROM mtl_item_categories_v mic_sc, mtl_system_items_b msi
     WHERE 1 = 1
       AND msi.inventory_item_id = p_inventory_item_id
       AND msi.organization_id = 91
       AND mic_sc.inventory_item_id = msi.inventory_item_id
       AND mic_sc.organization_id = msi.organization_id
       AND mic_sc.category_set_name = 'Activity Analysis'
       AND mic_sc.segment1 = 'Warranty'
       AND msi.inventory_item_status_code NOT IN
           ('XX_DISCONT', 'Inactive', 'Obsolete')
       AND msi.coverage_schedule_id IS NULL
       AND msi.primary_uom_code != 'EA';
  
    RETURN l_is_item_service_contract;
  
  END is_item_service_warranty;

  ------------------------------------------------------------
  -- Name: get_original_so_resin_balance
  -- Description: Returns the balance of Orinal SO's resin credit per customer and currency,
  -- excluding the current order.
  -- If no balance exists returns 0.
  ------------------------------------------------------------
  --  ver  date         name               desc
  --  1.0  04.04.2017   Lingaraj Sarangi   CHG0040389 :Initial Build
  --  1.1  15.5.17      yuval tal          INC0092883 - improve performence , split query into 2 sql
  ------------------------------------------------------------

  FUNCTION get_original_so_resin_balance(p_customer_num      VARCHAR2,
                                         p_currency          VARCHAR2,
                                         p_exclude_order_num NUMBER,
                                         p_org_so_num        NUMBER,
                                         p_org_id            NUMBER DEFAULT NULL,
                                         p_line_status       VARCHAR2 DEFAULT NULL)
    RETURN NUMBER IS
    v_credit NUMBER;
    v_debit  NUMBER;
  BEGIN
  
    SELECT SUM(credit_amount)
    
      INTO v_credit
      FROM xxoe_resin_balance_line_v
     WHERE 1 = 1
       AND customer_number = p_customer_num
       AND currency = p_currency
       AND order_number = p_org_so_num
       AND credit_amount > 0
       AND decode(org_id, 89, 737, org_id) =
           decode(nvl(p_org_id, org_id), 89, 737, org_id);
    -- dbms_output.put_line('v_credit=' || v_credit);
    -- get consuption amount
  
    SELECT SUM(credit_amount)
      INTO v_debit
      FROM xxoe_resin_balance_line_v
     WHERE 1 = 1
       AND customer_number = p_customer_num
       AND order_number != nvl(p_exclude_order_num, 0)
       AND currency = p_currency
       AND credit_amount < 0
       AND original_so = to_char(p_org_so_num)
       AND line_status = nvl(p_line_status, line_status)
       AND decode(org_id, 89, 737, org_id) =
           decode(nvl(p_org_id, org_id), 89, 737, org_id);
  
    -- dbms_output.put_line('v_debit=' || v_debit);
    RETURN nvl(nvl(v_credit, 0) + nvl(v_debit, 0), 0);
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 0;
    WHEN OTHERS THEN
      RETURN 0;
  END get_original_so_resin_balance;

  ------------------------------------------------------------
  -- Name: get_resin_credit_for_bundle
  -- Description: Returns the resin credit issued as part of a bundle item
  -- This function will take the order line id of the bundle item as input
  -- and try to find all resin_credit lines that were created as part of the bundle item line
  -- This will then return the sum of all the resin credit amounts (attribute4)
  --
  -- Usage: OIC Collection parameter setup for system transaction collection
  ------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   09/20/2017    Dipta Chatterjee  CHG0041334- Return resin credt amount issued as part of bundle item
  ------------------------------------------------------------

  function get_resin_credit_for_bundle(p_line_id          IN number,
                                       p_comm_line_api_id IN varchar2 DEFAULT null)
    return number is
    l_bundled_resin_credit    number := 0;
    l_remove_rc_profile_value varchar2(1);
  begin
    if p_comm_line_api_id is null then
      l_remove_rc_profile_value := nvl(fnd_profile.VALUE('XXCN_REMOVE_BUNDLE_RESIN_CREDIT'),
                                       'N');
    else
      begin
        select profile_option_value
          into l_remove_rc_profile_value
          from (select fpov.profile_option_value
                  from fnd_profile_option_value_a fpov,
                       fnd_profile_options_vl     fpo
                 where fpov.profile_option_id = fpo.PROFILE_OPTION_ID
                   and fpo.PROFILE_OPTION_NAME =
                       'XXCN_REMOVE_BUNDLE_RESIN_CREDIT'
                   and fpov.audit_timestamp >
                       (select creation_date
                          from cn_comm_lines_api_all ccla
                         where ccla.comm_lines_api_id = p_comm_line_api_id)
                   and fpov.level_value =
                       (select ccla.org_id
                          from cn_comm_lines_api_all ccla
                         where ccla.comm_lines_api_id = p_comm_line_api_id)
                 order by fpov.audit_timestamp)
         where rownum = 1;
      exception
        when no_data_found then
          l_remove_rc_profile_value := nvl(fnd_profile.VALUE('XXCN_REMOVE_BUNDLE_RESIN_CREDIT'),
                                           'N');
      end;
    end if;
  
    if l_remove_rc_profile_value = 'Y' then
      begin
        select sum(ol.attribute4)
          into l_bundled_resin_credit
          from oe_order_lines_all ol, mtl_system_items_b msib
         where ol.top_model_line_id = p_line_id
           and msib.segment1 = 'RESIN_CREDIT'
           and msib.organization_id =
               xxinv_utils_pkg.get_master_organization_id
           and msib.inventory_item_id = ol.inventory_item_id
           and ol.flow_status_code = 'CLOSED'
         group by ol.header_id, ol.top_model_line_id;
      exception
        when no_data_found then
          l_bundled_resin_credit := 0;
      end;
    else
      l_bundled_resin_credit := 0;
    end if;
    return nvl(l_bundled_resin_credit, 0);
  end get_resin_credit_for_bundle;

  --------------------------------------------------------------------------------------------------
  --  name:              get_order_status_for_sforce
  --  create by:         Diptasurjya Chatterjee
  --  Revision:          1.0
  --  creation date:     08/08/2018
  --------------------------------------------------------------------------------------------------
  --  purpose :          CHG0043691  : Fetch order header status for Strataforce
  --  Modification History
  --------------------------------------------------------------------------------------------------
  --  ver   date          Name                 Desc
  --  1.0   08/08/2018    Diptasurjya          CHG0043691 - Initial build
  --  1.1   01/12/2018    Roman W.             CHG0044580 - Salesforce oracle Order Sync
  --------------------------------------------------------------------------------------------------
  function get_order_status_for_sforce(p_header_id number) return varchar2 is
    l_status varchar2(100);
  
    l_cancelled_line_cnt    number := 0;
    l_total_tang_line_count number := 0;
  
    l_cancelled_intang_line_cnt number := 0;
    l_total_intang_line_count   number := 0;
  
  begin
    -- is order with integeble items only
    -- is order include non-intageble items
    select count(1)
      into l_cancelled_line_cnt
      from oe_order_lines_all ol
     where ol.header_id = p_header_id
       and ol.flow_status_code = 'CANCELLED'
       and xxinv_utils_pkg.is_intangible_items(ol.inventory_item_id) = 'N';
  
    select count(1)
      into l_total_tang_line_count
      from oe_order_lines_all ol
     where ol.header_id = p_header_id
       and xxinv_utils_pkg.is_intangible_items(ol.inventory_item_id) = 'N';
  
    /*
    --1.1
    select count(1)
      into l_cancelled_intang_line_cnt
      from oe_order_lines_all ol
     where ol.header_id = p_header_id
       and ol.flow_status_code = 'CANCELLED'
       and xxinv_utils_pkg.is_intangible_items(ol.inventory_item_id) = 'Y';
    --1.1
    select count(1)
      into l_total_intang_line_count
      from oe_order_lines_all ol
     where ol.header_id = p_header_id
       and xxinv_utils_pkg.is_intangible_items(ol.inventory_item_id) = 'Y';
    */
    if l_cancelled_line_cnt = l_total_tang_line_count and
       l_total_tang_line_count != 0 then
      -- 1.1
      l_status := 'CANCELLED';
      /*  
      elsif l_cancelled_intang_line_cnt = l_total_intang_line_count and
            l_total_intang_line_count != 0 then
        -- 1.1
        l_status := 'CANCELLED';
      */
    else
      select flow_status_code
        into l_status
        from oe_order_headers_all
       where header_id = p_header_id;
    end if;
  
    return l_status;
  end get_order_status_for_sforce;
END xxoe_utils_pkg;
/
