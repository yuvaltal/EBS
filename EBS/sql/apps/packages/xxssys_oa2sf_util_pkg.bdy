CREATE OR REPLACE PACKAGE BODY xxssys_oa2sf_util_pkg IS

  --------------------------------------------------------------------
  --  name:            xxssys_oa2sf_util_pkg
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   15-Nov-2017
  --------------------------------------------------------------------
  --  purpose :       Strataforce Project
  --                  This Package will hold all general Functions
  --                  and Packages used by   Strataforce Project
  --------------------------------------------------------------------
  --  ver  date              name                 desc
  --------------------------------------------------------------------
  --  1.0  15-Nov-2016       Lingaraj Sarangi     CHG0041504 - Strataforce Project
  --  1.1  28/03/2018        Roman.W              CHG0042560 - Sites - Locations oa2sf interface
  --                                                           cange in GET_SF_ACCOUNT_ID function
  --  1.2  07-AUG-18         Lingaraj Sarangi     CHG0043669  - need word replacment in SFDC inteface
  --                                              for Canada States same as done in US
  --  1.3  15-Aug-18         Lingaraj Sarangi     INC0130190 - price book generation performance improvment
  --  1.4  03-Sep-18         Lingaraj Sarangi     CTASK0038184 - FSL Order SF ID Validation
  --                                              [get_sf_fsl_header_id] -New Function Added
  --  1.5  15-Nov-18         Lingaraj             CHG0044334 - Change in SO header interface
  --                                              Update "Complete Order Shipped Date" and "Systems Shipped Date"
  --                                              Two New Function Added
  -- 1.6 27- jan -19          yuval tal           INC0145322   modify get_Asset_id / get_SF_so_order
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            get_sf_product_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   15-Nov-2017
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get Sales Force Product ID equivalent of Oracle Apps Item Code
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi      initial version
  --------------------------------------------------------------------
  FUNCTION get_sf_product_id(p_item_code IN VARCHAR2) RETURN VARCHAR2 IS
    l_product2_id VARCHAR2(240);
  BEGIN
    /* SELECT id
    INTO   l_product2_id
    FROM   xxsf2_product2
    WHERE  external_key__c = p_item_code;
    */
  
    SELECT external_id
    INTO   l_product2_id
    FROM   xxssys_events xe
    WHERE  xe.target_name = 'STRATAFORCE'
    AND    xe.entity_name = 'PRODUCT'
    AND    xe.status = 'SUCCESS'
    AND    xe.entity_code = p_item_code
    AND    external_id IS NOT NULL
    AND    rownum = 1;
  
    RETURN l_product2_id;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'NOVALUE';
  END get_sf_product_id;
  --
  FUNCTION get_related_item(p_item_code     IN VARCHAR2,
		    p_relation_type IN VARCHAR2) RETURN VARCHAR2 IS
    l_related_item_code VARCHAR2(240);
  BEGIN
  
    SELECT msib_related.segment1
    INTO   l_related_item_code
    -- listagg(mri.related_item_id, ',') within GROUP(ORDER BY mri.related_item_id) replace_item_id
    FROM   mtl_related_items  mri,
           fnd_lookup_values  flv,
           mtl_system_items_b msib,
           mtl_system_items_b msib_related
    WHERE  (mri.end_date IS NULL OR mri.end_date > SYSDATE)
    AND    flv.lookup_type = 'MTL_RELATIONSHIP_TYPES'
    AND    flv.language = 'US'
    AND    flv.lookup_code = mri.relationship_type_id
    AND    msib.organization_id = mri.organization_id
    AND    mri.inventory_item_id = msib.inventory_item_id
    AND    msib_related.organization_id = mri.organization_id
    AND    mri.related_item_id = msib_related.inventory_item_id
    AND    msib.segment1 = p_item_code
    AND    flv.meaning = p_relation_type --'Substitute'
    AND    mri.organization_id = 91
    AND    rownum = 1;
  
    RETURN l_related_item_code;
  EXCEPTION
    WHEN no_data_found OR too_many_rows THEN
      RETURN NULL;
  END get_related_item;

  --
  FUNCTION get_sf_related_item_product_id(p_item_code     IN VARCHAR2,
			      p_relation_type IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_related_item  VARCHAR2(240);
    l_sf_product_id VARCHAR2(18);
  BEGIN
    l_related_item := get_related_item(p_item_code, p_relation_type);
  
    IF l_related_item IS NOT NULL THEN
      l_sf_product_id := get_sf_product_id(l_related_item);
    
      IF l_sf_product_id != 'NOVALUE' THEN
        RETURN l_sf_product_id;
      ELSE
        RETURN NULL;
      END IF;
    ELSE
      RETURN NULL;
    END IF;
  
  END get_sf_related_item_product_id;

  --------------------------------------------------------------------
  --  name:            get_sf_itemcat_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   15-Nov-2017
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get Sales Force Product Category ID equivalent of Oracle Apps Item Code
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi      initial version
  --------------------------------------------------------------------
  FUNCTION get_sf_itemcat_id(p_category_key IN VARCHAR2) RETURN VARCHAR2 IS
    l_sf_category_id VARCHAR2(18);
  BEGIN
    /*SELECT id
    INTO   l_sf_category_id
    FROM   xxsf2_categories
    WHERE  external_key__c = p_category_key;
    
    RETURN l_sf_category_id;*/
  
    BEGIN
      SELECT external_id
      INTO   l_sf_category_id
      FROM   xxssys_events xe
      WHERE  xe.target_name = 'STRATAFORCE'
      AND    xe.entity_name = 'ITEM_CATEGORY'
      AND    xe.status = 'SUCCESS'
      AND    xe.entity_code = p_category_key
      AND    external_id IS NOT NULL
      AND    rownum = 1;
    
      RETURN l_sf_category_id;
    EXCEPTION
      WHEN no_data_found THEN
        RETURN NULL;
    END;
  
  EXCEPTION
    WHEN no_data_found OR too_many_rows THEN
      RETURN NULL;
  END get_sf_itemcat_id;

  --------------------------------------------------------------------
  --  name:            get_category_set_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   16-Nov-2017
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get Category Set ID
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi      initial version
  --------------------------------------------------------------------
  FUNCTION get_category_set_id(p_category_set_name IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_category_set_id NUMBER;
  BEGIN
    SELECT category_set_id
    INTO   l_category_set_id
    FROM   mtl_category_sets_tl
    WHERE  category_set_name = p_category_set_name
    AND    LANGUAGE = userenv('LANG');
  
    RETURN l_category_set_id;
  EXCEPTION
    WHEN no_data_found OR too_many_rows THEN
      RETURN NULL;
  END get_category_set_id;

  --------------------------------------------------------------------
  --  name:            get_sf_OperatingUnit_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   21-Nov-2017
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get Sf Operating Unit ID
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi      CHG0041565 - Pricelist Interface -initial version
  --------------------------------------------------------------------
  FUNCTION get_sf_operatingunit_id(p_operatingunit_id IN NUMBER)
    RETURN VARCHAR2 IS
    l_sf_operatingunit_id VARCHAR2(18) := NULL;
  BEGIN
  
    IF p_operatingunit_id IS NOT NULL THEN
      SELECT id
      INTO   l_sf_operatingunit_id
      FROM   xxsf2_operating_unit sf_ou
      WHERE  sf_ou.external_key__c = p_operatingunit_id; --external_key__c is NUMBER in SF[Table : OPERATING_UNIT__C]
    END IF;
  
    RETURN l_sf_operatingunit_id;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_sf_operatingunit_id;

  --------------------------------------------------------------------
  --  name:            get_sf_pricebook_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   21-Nov-2017
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get Sf Price List ID
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi      CHG0041565 - Pricelist Interface -initial version
  --------------------------------------------------------------------
  FUNCTION get_sf_pricebook_id(p_pricebook_listheader_id IN NUMBER)
    RETURN VARCHAR2 IS
    l_sf_pricebook_id VARCHAR2(18);
  BEGIN
  
    /*IF p_pricebook_listheader_id IS NOT NULL THEN
      SELECT id
      INTO   l_sf_pricebook_id
      FROM   xxsf2_pricebook2 pricebook
      WHERE  pricebook.external_key__c = to_char(p_pricebook_listheader_id);
    ELSE
      l_sf_pricebook_id := '';
    END IF;
    
    RETURN l_sf_pricebook_id;*/
  
    IF p_pricebook_listheader_id IS NULL THEN
      RETURN 'NOVALUE';
    END IF;
  
    SELECT external_id
    INTO   l_sf_pricebook_id
    FROM   xxssys_events xe
    WHERE  xe.target_name = 'STRATAFORCE'
    AND    xe.entity_name = 'PRICE_BOOK'
    AND    xe.status = 'SUCCESS'
    AND    xe.entity_id = p_pricebook_listheader_id
    AND    nvl(external_id, 'x') != 'x'
    AND    rownum = 1;
  
    RETURN l_sf_pricebook_id;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'NOVALUE';
    
  END get_sf_pricebook_id;

  --------------------------------------------------------------------
  --  name:            get_oracle_DirectPL_UnitPrice
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   21-Nov-2017
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get Sf Price List ID
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi      CHG0041808 - Pricelist Lines Interface -initial version
  --------------------------------------------------------------------
  FUNCTION get_oracle_directpl_unitprice(p_pricebook_listheader_id IN NUMBER,
			     p_inventory_item_id       IN NUMBER)
    RETURN NUMBER IS
    l_unit_price          NUMBER := NULL;
    l_related_inv_item_id NUMBER;
  BEGIN
  
    /*Select qll.operand unit_price
    into l_unit_price
    from
         qp_list_headers_all_b qlh,
         qp_list_lines         qll,
         qp_pricing_attributes qpa
         --mtl_system_items_b    msi
     WHERE qlh.list_header_id  = qll.list_header_id
     AND   qll.list_line_id    = qpa.list_line_id
     --AND   msi.organization_id = xxinv_utils_pkg.get_master_organization_id
     AND   to_number(qpa.product_attr_value) = p_inventory_item_id -- msi.inventory_item_id
     --AND   msi.segment1  =  p_item_code
     AND   trunc(sysdate) Between qll.start_date_active and nvl(qll.start_date_active, (sysdate+1));*/
  
    IF p_pricebook_listheader_id IS NULL THEN
      RETURN NULL;
    END IF;
  
    l_unit_price := get_active_price(p_pricebook_listheader_id,
			 p_inventory_item_id);
  
    /*Products not found in Direct PL, check if they have
      Item Relationship Type = Service
      (mtl_related_items.relationship_type_ID = 5) where
       From Item (mtl_related_items.INVENTORY_ITEM_ID) = Product Code.
      If yes,
      bring the price of the item which exists in the To Item
      (mtl_related_items.RELATED_ITEM_ID)
      from the Direct PL.
    */
    IF l_unit_price IS NULL THEN
      BEGIN
        -- Get the Related Item with Relation ship of Type Service
        SELECT related_item_id
        INTO   l_related_inv_item_id
        FROM   mtl_related_items
        WHERE  relationship_type_id = 5
        AND    inventory_item_id = p_inventory_item_id;
      
        l_unit_price := get_active_price(p_pricebook_listheader_id,
			     l_related_inv_item_id);
      
      EXCEPTION
        WHEN no_data_found THEN
          l_unit_price := NULL;
      END;
    END IF;
  
    RETURN l_unit_price;
  END get_oracle_directpl_unitprice;

  --------------------------------------------------------------------
  --  name:            get_active_price
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   21-Nov-2017
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get Active Price for the Item respective to the Price List
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi      CHG0041808 - Pricelist Lines Interface -initial version
  --------------------------------------------------------------------
  FUNCTION get_active_price(p_pricebook_listheader_id IN NUMBER,
		    p_inventory_item_id       IN NUMBER)
    RETURN NUMBER IS
    l_unit_price NUMBER;
  BEGIN
    SELECT qll.operand unit_price
    INTO   l_unit_price
    FROM   qp_list_headers_all_b qlh,
           qp_list_lines         qll,
           qp_pricing_attributes qpa
    WHERE  qlh.list_header_id = qll.list_header_id
    AND    qll.list_line_id = qpa.list_line_id
    AND    qlh.list_header_id = p_pricebook_listheader_id
    AND    qpa.product_attr_value = to_char(p_inventory_item_id)
    AND    trunc(SYSDATE) BETWEEN nvl(qlh.start_date_active, (SYSDATE - 1)) AND
           nvl(qlh.end_date_active, (SYSDATE + 1))
    AND    trunc(SYSDATE) BETWEEN nvl(qll.start_date_active, (SYSDATE - 1)) AND
           nvl(qll.end_date_active, (SYSDATE + 1))
    AND    qpa.pricing_attribute_context IS NULL
    AND    rownum = 1;
  
    RETURN l_unit_price;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_active_price;

  --------------------------------------------------------------------
  --  name:            get_sf_feature_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   26-Nov-2017
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get Sf BOM Feature ID
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi      CHG0041630 - PTO Interface -initial version
  --------------------------------------------------------------------
  FUNCTION get_sf_feature_id(p_item_code IN VARCHAR2) RETURN VARCHAR2 IS
    l_sf_product_feature_id VARCHAR2(18);
  BEGIN
    /*   SELECT id
      INTO   l_sf_product_feature_id
      FROM   xxsf2_productfeature
      WHERE  external_key__c = p_item_code;
    
      RETURN l_sf_product_feature_id;
    
    EXCEPTION
      When no_data_found Then*/
    BEGIN
      SELECT external_id
      INTO   l_sf_product_feature_id
      FROM   xxssys_events xe
      WHERE  xe.target_name = 'STRATAFORCE'
      AND    xe.entity_name = 'BOM'
      AND    xe.status = 'SUCCESS'
      AND    xe.entity_code = p_item_code
      AND    external_id IS NOT NULL
      AND    rownum = 1;
    
      RETURN l_sf_product_feature_id;
    EXCEPTION
      WHEN no_data_found THEN
        RETURN 'NOVALUE';
    END;
  END get_sf_feature_id;

  --------------------------------------------------------------------
  --  name:            get_concatenated_segments
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   26-Nov-2017
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi
  --------------------------------------------------------------------
  FUNCTION get_concatenated_segments(p_inventory_item_id IN NUMBER)
    RETURN VARCHAR2 IS
    CURSOR c_category_segments IS
      SELECT mic.inventory_item_id,
	 fl.parent_flex_value,
	 mc.concatenated_segments
      FROM   mtl_item_categories       mic,
	 mtl_categories_kfv        mc,
	 mtl_category_sets         mcs,
	 fnd_flex_value_children_v fl, -- family
	 fnd_flex_value_children_v fl_1, -- technology
	 fnd_flex_value_sets       vs,
	 fnd_flex_values           ffv_tech,
	 fnd_flex_values           ffv_fmly
      WHERE  mic.category_id = mc.category_id
      AND    mcs.category_set_id = mic.category_set_id
      AND    mic.organization_id =
	 xxinv_utils_pkg.get_master_organization_id
      AND    mcs.category_set_name IN
	 ('CS Price Book Product Type',
	   'SALES Price Book Product Type')
      AND    vs.flex_value_set_name = 'XXCS_PB_PRODUCT_FAMILY'
      AND    nvl(ffv_fmly.enabled_flag, 'N') = 'Y'
      AND    nvl(ffv_tech.enabled_flag, 'N') = 'Y'
      AND    fl.flex_value_set_id = vs.flex_value_set_id
      AND    fl.flex_value = mc.concatenated_segments
      AND    fl_1.flex_value_set_id = vs.flex_value_set_id
      AND    fl_1.flex_value = fl.parent_flex_value
      AND    ffv_tech.flex_value_set_id = vs.flex_value_set_id
      AND    ffv_tech.flex_value = fl_1.parent_flex_value
      AND    ffv_fmly.flex_value_set_id = vs.flex_value_set_id
      AND    ffv_fmly.flex_value = fl.parent_flex_value
      AND    inventory_item_id = p_inventory_item_id; --1184513;
  
    l_concatinated_segs VARCHAR2(4000) := '';
    TYPE t_family_tab IS TABLE OF VARCHAR2(80) INDEX BY VARCHAR2(80);
    l_family_tab t_family_tab;
    l_char       VARCHAR2(80);
  BEGIN
  
    g_relatedtoproductfamily := NULL;
    g_relatedtosystems       := NULL;
    g_relatedtosystems2      := NULL;
    g_relatedtosystems3      := NULL;
    g_relatedtosystems4      := NULL;
    g_relatedtosystems5      := NULL;
    FOR rec IN c_category_segments LOOP
      l_concatinated_segs := (CASE
		       WHEN l_concatinated_segs IS NULL THEN
		        ''
		       ELSE
		        (l_concatinated_segs || '|')
		     END) || rec.concatenated_segments;
    
      l_family_tab(rec.parent_flex_value) := rec.parent_flex_value;
    END LOOP;
  
    l_char := l_family_tab.first;
    /* For i in l_family_tab.FIRST .. l_family_tab.LAST Loop
       l_char := l_family_tab.NEXT()
       g_RelatedToProductFamily  := g_RelatedToProductFamily || l_family_tab(i);
    End Loop;      */
  
    WHILE (l_char IS NOT NULL) LOOP
      g_relatedtoproductfamily := g_relatedtoproductfamily || ';' || l_char;
      l_char                   := l_family_tab.next(l_char);
    END LOOP;
  
    g_relatedtoproductfamily := ltrim(g_relatedtoproductfamily, ';');
  
    g_relatedtosystems  := substr(l_concatinated_segs, 1, 255);
    g_relatedtosystems2 := substr(l_concatinated_segs, 256, 255);
    g_relatedtosystems3 := substr(l_concatinated_segs, 511, 255);
    g_relatedtosystems4 := substr(l_concatinated_segs, 766, 255);
    g_relatedtosystems5 := substr(l_concatinated_segs, 1021, 255);
  
    /* g_RelatedToSystems  := substr(l_concatinated_segs , 1   , 50);
    g_RelatedToSystems2 := substr(l_concatinated_segs , 51 , 50);
    g_RelatedToSystems3 := substr(l_concatinated_segs , 101 ,50);
    g_RelatedToSystems4 := substr(l_concatinated_segs , 151 , 50);
    g_RelatedToSystems5 := substr(l_concatinated_segs , 201, 50); */
  
    RETURN 'Y'; /*l_concatinated_segs*/
  
    /* Exception
    When Others Then
     Return null;*/
  END get_concatenated_segments;

  --
  FUNCTION get_relatedtosystem_value(p_seq NUMBER) RETURN VARCHAR2 IS
    l_relatedtosystem_value VARCHAR2(500);
  BEGIN
    l_relatedtosystem_value := (CASE p_seq
		         WHEN 1 THEN
		          g_relatedtosystems
		         WHEN 2 THEN
		          g_relatedtosystems2
		         WHEN 3 THEN
		          g_relatedtosystems3
		         WHEN 4 THEN
		          g_relatedtosystems4
		         WHEN 5 THEN
		          g_relatedtosystems5
		         WHEN 6 THEN
		          g_relatedtoproductfamily
		         ELSE
		          ''
		       END);
  
    RETURN l_relatedtosystem_value;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_relatedtosystem_value;

  --------------------------------------------------------------------
  --  name:            get_sf_account_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   15-Nov-2017
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get Sales Force Product ID equivalent of Oracle Apps Item Code
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi      initial version
  --------------------------------------------------------------------
  FUNCTION get_sf_account_id(p_account_number IN VARCHAR2) RETURN VARCHAR2 IS
    l_account_id VARCHAR2(50);
  BEGIN
  
    IF p_account_number IS NULL THEN
      RETURN NULL;
    END IF;
  
    SELECT external_id
    INTO   l_account_id
    FROM   xxssys_events xe
    WHERE  xe.target_name = 'STRATAFORCE'
    AND    xe.entity_name = 'ACCOUNT'
    AND    xe.status = 'SUCCESS'
    AND    xe.entity_code = p_account_number
    AND    external_id IS NOT NULL
    AND    rownum = 1;
  
    RETURN l_account_id;
  EXCEPTION
    WHEN no_data_found THEN
      BEGIN
        SELECT id
        INTO   l_account_id
        FROM   xxsf2_account
        WHERE  external_key__c = p_account_number;
        RETURN l_account_id;
      EXCEPTION
        WHEN OTHERS THEN
          RETURN NULL;
      END;
  END get_sf_account_id;

  --------------------------------------------------------------------
  --  name:            get_sf_site_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   15-Nov-2017
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get Sales Force Product ID equivalent of Oracle Apps Item Code
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi      initial version
  --------------------------------------------------------------------
  FUNCTION get_sf_site_id(p_site_id IN NUMBER) RETURN VARCHAR2 IS
    l_site_id VARCHAR2(50);
  BEGIN
  
    IF p_site_id IS NULL THEN
      RETURN NULL;
    END IF;
  
    SELECT external_id
    INTO   l_site_id
    FROM   xxssys_events xe
    WHERE  xe.target_name = 'STRATAFORCE'
    AND    xe.entity_name = 'SITE'
    AND    xe.status = 'SUCCESS'
    AND    xe.entity_id = p_site_id
    AND    external_id IS NOT NULL
    AND    rownum = 1;
  
    RETURN l_site_id;
  EXCEPTION
    WHEN no_data_found OR too_many_rows THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------------
  --  name:            get_sf_contact_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   15-Nov-2017
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get Sales Force Product ID equivalent of Oracle Apps Item Code
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi      initial version
  --------------------------------------------------------------------
  FUNCTION get_sf_contact_id(p_contact_id IN NUMBER) RETURN VARCHAR2 IS
    l_contact_id VARCHAR2(50);
  BEGIN
    SELECT id
    INTO   l_contact_id
    FROM   xxsf2_contact
    WHERE  external_key__c = to_char(p_contact_id);
  
    RETURN l_contact_id;
  EXCEPTION
    WHEN no_data_found OR too_many_rows THEN
      RETURN NULL;
  END;
  --------------------------------------------------------------------
  --  name:            get_sf_account_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   15-Nov-2017
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get Sales Force Product ID equivalent of Oracle Apps Item Code
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi      initial version
  --------------------------------------------------------------------
  FUNCTION get_sf_pay_term_id(p_pay_term_id IN NUMBER) RETURN VARCHAR2 IS
    l_pay_term_id VARCHAR2(240);
  BEGIN
    /* SELECT id
    INTO   l_pay_term_id
    FROM   xxsf2_payment_term__c
    WHERE  external_key__c = to_char(p_pay_term_id);*/
  
    SELECT external_id
    INTO   l_pay_term_id
    FROM   xxssys_events xe
    WHERE  xe.target_name = 'STRATAFORCE'
    AND    xe.entity_name = 'PAY_TERM'
    AND    xe.status = 'SUCCESS'
    AND    xe.entity_id = p_pay_term_id
    AND    external_id IS NOT NULL
    AND    rownum = 1;
  
    RETURN l_pay_term_id;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_sf_pay_term_id;

  --------------------------------------------------------------------
  --  name:            get_cpq_feature
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   15-Nov-2017
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi      CHG0041504 - Product Interface
  --------------------------------------------------------------------

  FUNCTION get_cpq_feature(p_item_code VARCHAR2) RETURN VARCHAR2 IS
    CURSOR c(c_item_code VARCHAR2) IS
    
      SELECT base.item,
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
	  FROM   mtl_categories_v /*@ERP_SOURCE*/   mcv,
	         fnd_flex_values_vl /*@ERP_SOURCE*/ f
	  WHERE  mcv.structure_id = 50592
	  AND    mcv.attribute9 = f.flex_value
	  AND    f.flex_value_set_id = 1013893) micv,
	 (SELECT msi.segment1                     item,
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
	  FROM   mtl_system_items_b /*@ERP_SOURCE*/     msi,
	         gl_code_combinations_v /*@ERP_SOURCE*/ g,
	         gl_code_combinations_v /*@ERP_SOURCE*/ g1,
	         fnd_flex_values_vl /*@ERP_SOURCE*/     f1,
	         fnd_lookup_values_vl /*@ERP_SOURCE*/   f2,
	         mtl_item_status /*@ERP_SOURCE*/        mi,
	         mtl_item_categories_v /*@ERP_SOURCE*/  mic,
	         mtl_item_categories_v /*@ERP_SOURCE*/  mic1,
	         mtl_item_categories_v /*@ERP_SOURCE*/  mic2
	  WHERE  msi.organization_id = 91
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
      AND    base.item = c_item_code;
  
    l_ret VARCHAR2(240);
  BEGIN
  
    FOR i IN c(p_item_code) LOOP
    
      l_ret := i.cpq_feature;
    END LOOP;
  
    RETURN l_ret;
  
    -- when others then
  END;

  --------------------------------------------------------------------
  --  name:            get_product_type
  --  create by:       Diptasurjya Chatterjee
  --  Revision:        1.0
  --  creation date:   23-Feb-2018
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --
  --------------------------------------------------------------------
  --  ver  date           name                        desc
  --  1.0  23-Feb-2018    Diptasurjya Chatterjee      CHG0042196 - pricebook generation
  --  1.1  15-Aug-2018    Lingaraj Sarangi            INC0130190 - price book generation performance improvment
  --------------------------------------------------------------------

  FUNCTION get_product_type(p_item_code         VARCHAR2,
		    p_inventory_item_id NUMBER) RETURN VARCHAR2 IS
  
    CURSOR c(c_item_id NUMBER) IS
      SELECT micv.product_type
      FROM   (SELECT mcv.attribute11 product_type,
	         mcv.segment1,
	         mcv.segment2,
	         mcv.segment3,
	         mcv.segment4,
	         mcv.segment5,
	         mcv.segment6,
	         mcv.segment7,
	         mcv.segment8,
	         mcv.segment9,
	         f.description   pl_mapping_desc
	  FROM   mtl_categories_v   mcv,
	         fnd_flex_values_vl f
	  WHERE  mcv.structure_id = 50592
	  AND    mcv.attribute9 = f.flex_value
	  AND    f.flex_value_set_id = 1013893) micv,
	 (SELECT msi.inventory_item_id,
	         msi.segment1                     item,
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
	  WHERE  msi.organization_id = 91
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
	  AND    mic2.category_set_id(+) = 1100000248
	  AND    msi.inventory_item_id = c_item_id --INC0130190
	  ) base
      WHERE  base."Line Of Business" = micv.segment1(+)
      AND    BASE."Product Line" = micv.segment2(+)
      AND    BASE."Product Family" = micv.segment3(+)
      AND    BASE."Sub Family" = micv.segment4(+)
      AND    BASE."Specialty/Flavor" = micv.segment5(+)
      AND    BASE."Technology" = micv.segment6(+)
      AND    BASE."Item Type" = micv.segment7(+)
      AND    BASE."Activity Analysis" = micv.segment8(+)
      AND    BASE."Brand" = micv.segment9(+);
  
    l_ret               VARCHAR2(240);
    l_inventory_item_id NUMBER := p_inventory_item_id; --INC0130190
  BEGIN
    --Begin INC0130190
    IF l_inventory_item_id IS NULL AND p_item_code IS NULL THEN
      RETURN '';
    END IF;
  
    IF l_inventory_item_id IS NULL AND p_item_code IS NOT NULL THEN
      BEGIN
        SELECT inventory_item_id
        INTO   l_inventory_item_id
        FROM   mtl_system_items_b
        WHERE  organization_id = 91
        AND    segment1 = p_item_code;
      EXCEPTION
        WHEN no_data_found THEN
          RETURN '';
      END;
    END IF;
    --End INC0130190
    FOR i IN c(l_inventory_item_id) LOOP
      l_ret := i.product_type;
    END LOOP;
  
    RETURN l_ret;
  
  END get_product_type;

  --------------------------------------------------------------------
  --  name:            sf_opportunity_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   15-Nov-2017
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get Sales Force Product Category ID equivalent of Oracle Apps Item Code
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi      initial version
  --------------------------------------------------------------------
  FUNCTION get_sf_opportunity_id(p_quote_no IN VARCHAR2) RETURN VARCHAR2 IS
    l_sbqq__opportunity2__c VARCHAR2(50);
  BEGIN
    SELECT sbqq__opportunity2__c
    INTO   l_sbqq__opportunity2__c
    FROM   xxsf2_sbqq__quote__c
    WHERE  NAME = p_quote_no;
  
    RETURN l_sbqq__opportunity2__c;
  EXCEPTION
    WHEN no_data_found OR too_many_rows THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------------
  --  name:            get_sf_quote_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   15-Nov-2017
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get Sales Force Product Category ID equivalent of Oracle Apps Item Code
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi      initial version
  --------------------------------------------------------------------
  FUNCTION get_sf_quote_id(p_quote_no IN VARCHAR2) RETURN VARCHAR2 IS
    l_quote_id VARCHAR2(50);
  BEGIN
    SELECT id
    INTO   l_quote_id
    FROM   xxsf2_sbqq__quote__c
    WHERE  NAME = p_quote_no;
  
    RETURN l_quote_id;
  EXCEPTION
    WHEN no_data_found OR too_many_rows THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            get_sf_record_type_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   15-Nov-2017
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get Sales Force Product Category ID equivalent of Oracle Apps Item Code
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi      initial version
  --------------------------------------------------------------------
  FUNCTION get_sf_record_type_id(p_sobjecttype IN VARCHAR2,
		         p_name        VARCHAR2) RETURN VARCHAR2 IS
    l_id VARCHAR2(50);
  BEGIN
  
    SELECT id
    INTO   l_id
    FROM   xxsf2_recordtype t
    WHERE  t.sobjecttype = p_sobjecttype
    AND    upper(t.developername) = upper(REPLACE(p_name, ' ', '_'));
  
    RETURN l_id;
  EXCEPTION
    WHEN no_data_found OR too_many_rows THEN
      RETURN NULL;
  END get_sf_record_type_id;

  FUNCTION get_category_value(p_category_set_name VARCHAR2,
		      p_inventory_item_id NUMBER) RETURN VARCHAR2 IS
    --
    l_category VARCHAR2(150);
  BEGIN
  
    SELECT mc.concatenated_segments
    INTO   l_category
    FROM   mtl_item_categories_v mic,
           mtl_categories_kfv    mc
    WHERE  mic.category_id = mc.category_id
    AND    mic.category_set_name = p_category_set_name
    AND    mic.inventory_item_id = p_inventory_item_id
    AND    mic.organization_id = 91;
  
    RETURN(l_category);
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_category_value;
  --------------------------------------------------------------------
  --  name:            get_sf_feature_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   26-Nov-2017
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get Sf BOM Feature ID
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi      CHG0041630 - PTO Interface -initial version
  --------------------------------------------------------------------
  FUNCTION is_sf_system_steup_exists(p_item_code IN VARCHAR2) RETURN VARCHAR2 IS
    l_exists VARCHAR2(1) := 'N';
  BEGIN
  
    SELECT 'Y'
    INTO   l_exists
    FROM   xxssys_events xe
    WHERE  xe.target_name = 'STRATAFORCE'
    AND    xe.entity_name = 'SYSTEM_SETUP'
    AND    xe.status = 'SUCCESS'
    AND    xe.entity_code = p_item_code
    AND    rownum = 1;
  
    RETURN l_exists;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
  END is_sf_system_steup_exists;

  --------------------------------------------------------------------
  --  name:            get_sf_quote_id
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   15-Nov-2017
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   CHG0042336 - Currencies oracle2sf
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    yuval tal             CHG0042336 - Currencies oracle2sf
  --------------------------------------------------------------------
  FUNCTION get_sf_currency_id(p_curr_code IN VARCHAR2) RETURN VARCHAR2 IS
    l_curr_id VARCHAR2(50);
  BEGIN
    SELECT id
    INTO   l_curr_id
    FROM   xxsf2_currencytype
    WHERE  isocode = p_curr_code;
  
    RETURN l_curr_id;
  EXCEPTION
    WHEN no_data_found OR too_many_rows THEN
      RETURN NULL;
  END;

  -------------------------------------------------------------------
  --  name:            get_sf_oe_header_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   13-Mar-2018
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get Sales Force Order Header ID - SF ID
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi      CHG0042043 - Order line interface OA2SF
  --  1.1  27.01.19       INC0145322  Yuval tal             INC0145322   - fetch from copystorm if not found 
  --------------------------------------------------------------------
  FUNCTION get_sf_so_header_id(p_so_header_id IN NUMBER) RETURN VARCHAR2 IS
    l_sf_id VARCHAR2(18);
  BEGIN
  
    SELECT external_id
    INTO   l_sf_id
    FROM   xxssys_events xe
    WHERE  xe.target_name = 'STRATAFORCE'
    AND    xe.entity_name = 'SO_HEADER'
    AND    xe.status = 'SUCCESS'
    AND    xe.entity_id = p_so_header_id
    AND    external_id IS NOT NULL
    AND    rownum = 1;
  
    RETURN l_sf_id;
  EXCEPTION
    WHEN no_data_found THEN
      --NODATAFOUND and If the Object is not found in Copy strom
      BEGIN
        SELECT id
        INTO   l_sf_id
        FROM   xxsf2_order
        WHERE  external_key__c = to_char(p_so_header_id);
      
        RETURN l_sf_id;
      EXCEPTION
        WHEN no_data_found THEN
          RETURN 'NOVALUE';
      END;
  END get_sf_so_header_id;

  -------------------------------------------------------------------
  --  name:            get_sf_so_line_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   13-Mar-2018
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get Sales Force Order Line ID - SF ID
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2017    Lingaraj Sarangi      CHG0042043 - Order line interface OA2SF
  --------------------------------------------------------------------
  FUNCTION get_sf_so_line_id(p_so_line_id IN NUMBER) RETURN VARCHAR2 IS
    l_sf_oe_line_id VARCHAR2(240);
  BEGIN
  
    SELECT external_id
    INTO   l_sf_oe_line_id
    FROM   xxssys_events xe
    WHERE  xe.target_name = 'STRATAFORCE'
    AND    xe.entity_name = 'SO_LINE'
    AND    xe.status = 'SUCCESS'
    AND    xe.entity_id = p_so_line_id
    AND    external_id IS NOT NULL
    AND    rownum = 1;
  
    RETURN l_sf_oe_line_id;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'NOVALUE';
  END get_sf_so_line_id;

  --------------------------------------------------------------------
  --  name:            get_order_line_hold
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   05/02/2014
  --------------------------------------------------------------------
  --  purpose :   CUST776 - Customer support SF-OA interfaces\CR 1215 - Customer support SF-OA interfaces
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/02/2014  yuval tal        initial build - used in view XXOBJT_OA2SF_ORDER_LINES_V
  --------------------------------------------------------------------
  FUNCTION get_order_line_hold(p_header_id NUMBER,
		       p_line_id   NUMBER) RETURN VARCHAR2 IS
  
    l_hold_desc VARCHAR2(2000);
  BEGIN
  
    SELECT listagg(hold_name, ', ') within GROUP(ORDER BY header_id)
    INTO   l_hold_desc
    FROM   xx_oe_holds_history_v t
    WHERE  t.header_id = p_header_id
    AND    t.line_id = p_line_id
    AND    t.released_flag = 'N';
  
    RETURN l_hold_desc;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'Error';
  END get_order_line_hold;

  FUNCTION is_order_line_on_hold(p_header_id NUMBER,
		         p_line_id   NUMBER) RETURN VARCHAR2 IS
  
    l_is_on_hold VARCHAR2(1) := 'N';
  BEGIN
  
    SELECT 'Y'
    INTO   l_is_on_hold
    FROM   xx_oe_holds_history_v t
    WHERE  t.header_id = p_header_id
    AND    t.line_id = p_line_id
    AND    t.released_flag = 'N'
    AND    rownum = 1;
  
    RETURN l_is_on_hold;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
    WHEN OTHERS THEN
      RETURN 'ERROR';
  END is_order_line_on_hold;

  --------------------------------------------------------------------
  --  name:            source_data_query
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   05/02/2014
  --------------------------------------------------------------------
  --  purpose :   CUST776 - Customer support SF-OA interfaces\CR 1215 - Customer support SF-OA interfaces
  --              XX OA2SF Monitor form
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/02/2014  yuval tal        initial build - used in view XXOBJT_OA2SF_ORDER_LINES_V
  --------------------------------------------------------------------
  FUNCTION get_invoice4so_line(p_line_id NUMBER) RETURN VARCHAR2 IS
    l_inv_number VARCHAR2(500);
  BEGIN
  
    SELECT --hh.trx_number
     listagg(hh.trx_number, ', ') within GROUP(ORDER BY l.interface_line_attribute6)
    INTO   l_inv_number
    FROM   ra_customer_trx_lines_all l,
           ra_customer_trx_all       hh
    
    WHERE  hh.customer_trx_id = l.customer_trx_id
    AND    l.line_type = 'LINE'
    AND    l.interface_line_attribute6 = to_char(nvl(p_line_id, '-999'));
  
    RETURN l_inv_number;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_invoice4so_line;

  FUNCTION get_so_line_delivery_status(p_line_id NUMBER) RETURN VARCHAR2 IS
    l_status VARCHAR2(20);
  BEGIN
  
    SELECT status_code
    INTO   l_status
    FROM   (SELECT decode(wnd.status_code,
		  'CL',
		  'Close',
		  'IT',
		  'In-Transit',
		  'OP',
		  'Open',
		  wnd.status_code) status_code,
	       wnd.creation_date
	FROM   wsh_delivery_details     wdd,
	       wsh_delivery_assignments wda,
	       wsh_new_deliveries       wnd
	WHERE  wdd.delivery_detail_id = wda.delivery_detail_id
	AND    wda.delivery_id = wnd.delivery_id
	AND    wdd.source_line_id = p_line_id
	ORDER  BY wnd.creation_date DESC)
    WHERE  rownum = 1;
  
    RETURN l_status;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_so_line_delivery_status;

  FUNCTION get_dist_functional_amount(p_line_id NUMBER) RETURN NUMBER IS
    l_dist_functional_amount NUMBER;
  BEGIN
  
    SELECT
    ---
     (CASE
       WHEN msi.item_type IN
	(fnd_profile.value('XXAR_FREIGHT_AR_ITEM'),
	 fnd_profile.value('XXAR PREPAYMENT ITEM TYPES')) THEN
        nvl(to_char(oel.unit_selling_price), '0')
     
       ELSE
        decode(oeh.attribute17,
	   'Total list price amount equal 0',
	   '0',
	   round(decode(sign(oel.unit_selling_price),
		    -1,
		    oel.unit_selling_price,
		    xxar_autoinvoice_pkg.get_price_list_dist(oel.line_id,
					         oel.unit_list_price,
					         oel.attribute4) *
		    oel.ordered_quantity *
		    (decode(oeh.attribute17,
			100,
			0,
			(100 - oeh.attribute17) / 100))),
	         2))
     END) dist_functional_amount
    INTO   l_dist_functional_amount
    FROM   mtl_system_items_b   msi,
           oe_order_lines_all   oel,
           oe_order_headers_all oeh
    WHERE  oel.line_id = p_line_id
    AND    oel.inventory_item_id = msi.inventory_item_id
    AND    oel.header_id = oeh.header_id
    AND    msi.organization_id = 91;
  
    RETURN l_dist_functional_amount;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '-999';
  END get_dist_functional_amount;

  ----------------------------------------------------------------
  --get_sf_asset_id
  -- 
  --  ver  date                       name              desc
  --  1.1  27.01.19                   Yuval tal         INC0145322   - fetch from copystorm if not found 
  ----------------------------------------------------------------

  FUNCTION get_sf_asset_id(p_instance_id NUMBER) RETURN VARCHAR2 IS
  
    l_sf_id VARCHAR2(18);
  BEGIN
  
    IF p_instance_id IS NULL THEN
      RETURN 'NOVALUE';
    END IF;
    BEGIN
      SELECT external_id
      INTO   l_sf_id
      FROM   xxssys_events xe
      WHERE  xe.target_name = 'STRATAFORCE'
      AND    xe.entity_name = 'ASSET'
      AND    xe.status = 'SUCCESS'
      AND    xe.entity_id = p_instance_id
      AND    external_id IS NOT NULL
      AND    rownum = 1;
    EXCEPTION
      WHEN no_data_found THEN
        -- INC0145322 
      
        SELECT id
        INTO   l_sf_id
        FROM   xxsf2_asset
        WHERE  external_key__c = to_char(p_instance_id);
      
    END;
  
    RETURN l_sf_id;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'NOVALUE';
    
  END get_sf_asset_id;

  FUNCTION get_sf_service_asset_id(p_line_id           IN NUMBER, -- OE_ORDER_LINES_ALL.LINE_ID
		           p_item_id           IN NUMBER, -- OE_ORDER_LINES_ALL.INVENTORY_ITEM_ID
		           p_attribute1        IN VARCHAR2, -- OE_ORDER_LINES_ALL.ATTRIBUTE1
		           p_attribute14       IN VARCHAR2, -- OE_ORDER_LINES_ALL.ATTRIBUTE14
		           p_srv_ref_type_code IN VARCHAR2, -- OE_ORDER_LINES_ALL.SERIVICE_REFERENCE_TYPE_CODE
		           p_srv_ref_line_id   IN NUMBER, -- OE_ORDER_LINES_ALL.SERIVICE_REFERENCE_LINE_ID
		           p_serial_number     IN VARCHAR2 -- OE_ORDER_LINES_ALL_DFV.SERIAL_NUMBER
		           ) RETURN VARCHAR2 IS
    l_sf_id              VARCHAR2(50);
    l_instance_id        NUMBER := -99;
    l_valid_contact_item VARCHAR2(1);
  BEGIN
    BEGIN
      SELECT 'Y'
      INTO   l_valid_contact_item
      FROM   mtl_item_categories_v mic_sc,
	 mtl_system_items_b    msi
      WHERE  mic_sc.inventory_item_id = msi.inventory_item_id
      AND    msi.inventory_item_id = p_item_id
      AND    mic_sc.organization_id = msi.organization_id
      AND    msi.organization_id = 91
      AND    mic_sc.category_set_name = 'Activity Analysis'
      AND    mic_sc.segment1 = 'Contracts'
      AND    msi.inventory_item_status_code NOT IN
	 ('XX_DISCONT', 'Inactive', 'Obsolete')
      AND    msi.coverage_schedule_id IS NOT NULL;
    EXCEPTION
      WHEN no_data_found THEN
        RETURN '';
    END;
  
    IF p_srv_ref_type_code = 'CUSTOMER_PRODUCT' THEN
      -- LOGIC 01
    
      l_instance_id := p_srv_ref_line_id;
    
    ELSIF p_srv_ref_type_code = 'ORDER' THEN
      -- LOGIC 02
    
      SELECT cii.instance_id
      INTO   l_instance_id
      FROM   wsh_delivery_details wdd,
	 csi_item_instances   cii,
	 oe_order_lines_all   ol
      WHERE  ol.line_id = p_srv_ref_line_id
      AND    wdd.source_line_id = ol.line_id
      AND    ol.cancelled_quantity = 0
      AND    wdd.serial_number IS NOT NULL
      AND    cii.serial_number = wdd.serial_number
      AND    cii.inventory_item_id = ol.inventory_item_id;
    
    ELSIF p_srv_ref_type_code IS NULL THEN
      -- LOGIC 03
    
      CASE
        WHEN xxoe_utils_pkg.is_item_service_contract(p_item_id) = 'N' AND
	 xxoe_utils_pkg.is_item_service_warranty(p_item_id) = 'N' THEN
          l_instance_id := p_attribute1;
        ELSE
        
          SELECT cii.instance_id
          INTO   l_instance_id
          FROM   xxcs_items_printers_v   pr,
	     mtl_item_categories_v   mic_pr,
	     mtl_item_categories_v   mic_sc,
	     xxsf_csi_item_instances cii,
	     oe_order_lines_all      ol
          WHERE  pr.inventory_item_id = mic_pr.inventory_item_id
          AND    ol.cancelled_quantity = 0
          AND    mic_sc.inventory_item_id = ol.inventory_item_id
          AND    mic_pr.organization_id = 91
          AND    mic_pr.category_set_name = 'Product Hierarchy'
          AND    mic_sc.organization_id = 91
          AND    mic_sc.category_set_name = 'Product Hierarchy'
          AND    mic_sc.segment2 = mic_pr.segment2
          AND    mic_sc.segment3 IN (mic_pr.segment3, mic_pr.segment2)
          AND    mic_sc.segment4 = mic_pr.segment4
          AND    mic_pr.inventory_item_id = cii.inventory_item_id
          AND    cii.serial_number = p_serial_number
          AND    ol.line_id = p_line_id
          AND    rownum = 1;
      END CASE;
    END IF;
  
    IF l_instance_id != -99 THEN
      l_sf_id := get_sf_asset_id(l_instance_id);
    END IF;
  
    RETURN l_sf_id;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN '';
  END get_sf_service_asset_id;

  FUNCTION get_item_uom_code(p_inventory_item_id NUMBER) RETURN VARCHAR2 IS
    l_primary_uom_code mtl_system_items_b.primary_uom_code%TYPE;
  BEGIN
  
    SELECT t.primary_uom_code
    INTO   l_primary_uom_code
    FROM   mtl_system_items_b t
    WHERE  t.organization_id = 91
    AND    t.inventory_item_id = p_inventory_item_id;
  
    RETURN l_primary_uom_code;
  
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END get_item_uom_code;

  FUNCTION get_sf_price_line_id(p_list_header_id NUMBER,
		        p_item_code      VARCHAR2,
		        p_currency_code  VARCHAR2) RETURN VARCHAR2 IS
    l_sf_id VARCHAR2(18);
    l_key   VARCHAR2(300) := (p_list_header_id || '|' || p_item_code || '|' ||
		     p_currency_code);
  BEGIN
  
    SELECT external_id
    INTO   l_sf_id
    FROM   (SELECT event_id,
	       external_id
	FROM   xxssys_events xe
	WHERE  xe.target_name = 'STRATAFORCE'
	AND    xe.entity_name = 'PRICE_ENTRY'
	AND    xe.status = 'SUCCESS'
	AND    xe.entity_id = p_list_header_id --list headerid
	AND    xe.entity_code = l_key
	AND    xe.external_id IS NOT NULL
	ORDER  BY 1 DESC)
    WHERE  rownum = 1;
  
    /*
    SELECT id
    INTO   l_sf_id
    FROM   xxsf2_pricebookentry
    WHERE  external_key__c = (p_list_header_id || '|' || p_item_code || '|' ||
           p_currency_code)
    AND    isactive = 1;*/
  
    RETURN l_sf_id;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'NOVALUE';
  END get_sf_price_line_id;
  ----------------------------------------------------------------------------------------------
  -- Ver    When        Who            Description
  -- -----  ----------  -------------  -----------------------------------------------------------
  -- 1.0    28/03/2018  Roman.W.       CHG0042560 - Sites - Locations oa2sf interface
  ----------------------------------------------------------------------------------------------
  FUNCTION get_sf_freight_term_id(p_freight_term VARCHAR2) RETURN VARCHAR2 IS
    ------------------------------
    --     Local Definition
    ------------------------------
    l_ret_val VARCHAR2(300);
    ------------------------------
    --     Code Section
    ------------------------------
  BEGIN
    BEGIN
      SELECT id
      INTO   l_ret_val
      FROM   freight_terms__c@source_sf2 ftc
      WHERE  ftc.external_key__c = p_freight_term;
    
    EXCEPTION
      WHEN no_data_found THEN
        l_ret_val := NULL;
      WHEN too_many_rows THEN
        l_ret_val := NULL;
      WHEN OTHERS THEN
        l_ret_val := NULL;
    END;
  
    RETURN l_ret_val;
  END get_sf_freight_term_id;

  ----------------------------------------------------------------------------------------------
  -- Ver    When         Who            Description
  -- -----  ----------  -------------  -----------------------------------------------------------
  -- 1.0    02-May-2018  Lingaraj      CHG0041504 - Product interface
  ----------------------------------------------------------------------------------------------
  FUNCTION get_sf_servicecontract_id(p_coverage_schedule_id NUMBER)
    RETURN VARCHAR2 IS
    l_sfid VARCHAR2(18);
  BEGIN
  
    IF p_coverage_schedule_id IS NULL THEN
      RETURN '';
    END IF;
  
    SELECT id
    INTO   l_sfid
    FROM   xxsf2_servicecontract
    WHERE  external_key__c = to_char(p_coverage_schedule_id);
  
    RETURN l_sfid;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN '';
  END get_sf_servicecontract_id;
  ----------------------------------------------------------------------------------------------
  -- Ver    When         Who            Description
  -- -----  ----------  -------------  -----------------------------------------------------------
  -- 1.0    02-May-2018  Lingaraj      CHG0042734 -Create Order interface - Enable Strataforce to create orders in Oracle
  --                                   p_int_type (PRODUCT_REQUEST_HEADER OR QUOTE_HEADER)
  ----------------------------------------------------------------------------------------------
  FUNCTION get_sf_fsl_so_header_id(p_so_header_id IN NUMBER) RETURN VARCHAR2 IS
    l_sf_id VARCHAR2(18);
  BEGIN
    SELECT external_id
    INTO   l_sf_id
    FROM   xxssys_events xe
    WHERE  xe.target_name = 'STRATAFORCE'
    AND    xe.entity_name = 'SO_HEADER_FSL'
    AND    xe.status = 'SUCCESS'
    AND    xe.entity_id = p_so_header_id
    AND    xe.external_id IS NOT NULL
          --AND    xe.attribute2  = p_int_type  --PRODUCT_REQUEST_HEADER OR QUOTE_HEADER
    AND    rownum = 1;
  
    RETURN l_sf_id;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'NOVALUE';
  END get_sf_fsl_so_header_id;

  --------------------------------------------------------------------
  --  name:            get_sf_location_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   29-May-2018
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get Sf Inv Organization ID
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  29-May-2018    Lingaraj Sarangi      CHG0042878 - CAR stock Subinventory interface - Oracle to Salesforce
  --------------------------------------------------------------------
  FUNCTION get_sf_location_id(p_location_code IN VARCHAR2) RETURN VARCHAR2 IS
    l_sf_id VARCHAR2(18);
  BEGIN
  
    SELECT id
    INTO   l_sf_id
    FROM   xxsf2_locations t
    WHERE  t.external_key__c = upper(p_location_code);
  
    RETURN l_sf_id;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'NOVALUE';
  END get_sf_location_id;

  --------------------------------------------------------------------
  --  name:            get_PL_transalation
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   18-July-2018
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   This function will Translate the Price List Header ID
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  18-Jul-2018    Lingaraj Sarangi      Intial Build
  --------------------------------------------------------------------
  FUNCTION get_pl_transalation(p_list_header_id IN NUMBER) RETURN NUMBER IS
    l_translated_pl_id NUMBER;
  BEGIN
    SELECT to_number(ffvv.description)
    INTO   l_translated_pl_id
    FROM   fnd_flex_value_sets ffvs,
           fnd_flex_values_vl  ffvv
    WHERE  flex_value_set_name = 'XXQP_STRATAFORCE_PL_TRANSLATION'
    AND    ffvs.flex_value_set_id = ffvv.flex_value_set_id
    AND    nvl(ffvv.enabled_flag, 'N') = 'Y'
    AND    ffvv.flex_value = to_char(p_list_header_id);
  
    RETURN nvl(l_translated_pl_id, p_list_header_id);
  EXCEPTION
    WHEN no_data_found THEN
      RETURN p_list_header_id;
  END get_pl_transalation;

  --------------------------------------------------------------------
  --  name:            get_state_desc
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   07-Aug-2018
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   This function will Translate State Code to State Desc
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  07-Aug-2018    Lingaraj Sarangi      CHG0043669 - Intial Build
  --------------------------------------------------------------------
  FUNCTION get_state_name(p_country_code VARCHAR2,
		  p_state_code   VARCHAR2) RETURN VARCHAR2 IS
    l_state_name VARCHAR2(100);
  BEGIN
  
    SELECT geography_name state_name
    INTO   l_state_name
    FROM   hz_geographies
    WHERE  country_code = p_country_code --'ca'
    AND    geography_type = 'STATE'
    AND    geography_code = p_state_code;
  
    RETURN l_state_name;
  EXCEPTION
    WHEN no_data_found OR too_many_rows THEN
      RETURN p_state_code;
  END get_state_name;
  --------------------------------------------------------------------
  --  name:            get_sf_fsl_header_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   03-Sep-2018
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   This function will
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  03-Sep-2018    Lingaraj Sarangi      CHG0042734 - Intial Build
  --------------------------------------------------------------------
  FUNCTION get_sf_fsl_header_id(p_header_id             IN NUMBER,
		        p_sync_destination_code IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_sfid VARCHAR2(18);
  BEGIN
    IF p_sync_destination_code = 'PRODUCT_REQUEST_HEADER' THEN
      SELECT id
      INTO   l_sfid
      FROM   xxsf2_productrequest
      WHERE  external_key__c = p_header_id;
    ELSIF p_sync_destination_code = 'QUOTE_HEADER' THEN
      SELECT id
      INTO   l_sfid
      FROM   xxsf2_sbqq__quote__c
      WHERE  external_key__c = p_header_id;
    ELSE
      RETURN 'NOVALUE';
    END IF;
    RETURN l_sfid;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'NOVALUE';
  END get_sf_fsl_header_id;

  --------------------------------------------------------------------
  --  name:            get_order_complete_ship_date
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   15-Nov-2018
  --------------------------------------------------------------------
  --  purpose :        Strataforce Project
  --                   Get the latest ?Actual Fulfillment date? when Order is Closed.
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2018    Lingaraj Sarangi      CHG0044334 - Change in SO header interface
  --                                            Update "Complete Order Shipped Date" and "Systems Shipped Date"
  --------------------------------------------------------------------
  FUNCTION get_order_complete_ship_date(p_header_id IN NUMBER) RETURN DATE IS
    CURSOR ord_cur IS
      SELECT MAX(ol.actual_fulfillment_date) actual_fulfillment_date
      FROM   oe_order_headers_all oh,
	 oe_order_lines_all   ol
      WHERE  oh.header_id = ol.header_id
      AND    oh.header_id = p_header_id
      AND    oh.flow_status_code = 'CLOSED'
      AND    nvl(ol.cancelled_flag, 'N') != 'Y';
    l_act_fulfillment_date DATE;
  BEGIN
    OPEN ord_cur;
    FETCH ord_cur
      INTO l_act_fulfillment_date;
    IF ord_cur%NOTFOUND THEN
      l_act_fulfillment_date := NULL;
    END IF;
    CLOSE ord_cur;
  
    RETURN l_act_fulfillment_date;
  END get_order_complete_ship_date;

  --------------------------------------------------------------------
  --  name:            get_sf_fsl_header_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   15-Nov-2018
  --------------------------------------------------------------------
  --  purpose : Strataforce Project
  --  Logic   : when all order lines with product.
  --            activity_analysis in (?Systems (net)?, ?Systems-Used?,?BDL-Systems?) are in status closed,
  --            take the latest ?Actual Fulfillment Date? from these order lines,
  --            and populate this date in Order.
  --------------------------------------------------------------------
  --  ver  date           name                  desc
  --  1.0  15-Nov-2018    Lingaraj Sarangi      CHG0044334 - Change in SO header interface
  --                                            Update "Complete Order Shipped Date" and "Systems Shipped Date"
  --------------------------------------------------------------------
  FUNCTION get_systems_ship_date(p_header_id IN NUMBER) RETURN DATE IS
    CURSOR ord_cur IS
      SELECT ol.actual_fulfillment_date,
	 ol.actual_shipment_date,
	 ol.flow_status_code line_status,
	 decode(wdd.released_status,
	        'C',
	        'SHIPPED',
	        NULL,
	        'NOVALUE',
	        wdd.released_status) released_status
      FROM   oe_order_headers_all oh,
	 oe_order_lines_all   ol,
	 wsh_delivery_details wdd
      WHERE  oh.header_id = ol.header_id
      AND    oh.header_id = p_header_id
      AND    wdd.source_header_id(+) = oh.header_id
      AND    wdd.source_line_id(+) = ol.line_id
      AND    get_category_value('Activity Analysis', ol.inventory_item_id) IN
	 ('Systems (net)', 'Systems-Used', 'BDL-Systems')
      AND    nvl(ol.cancelled_flag, 'N') != 'Y'
      AND    nvl(ol.ordered_quantity, 0) > 0;
  
    l_tot_rec_cnt       NUMBER := 0;
    l_no_of_rec_closed  NUMBER := 0;
    l_act_shipment_date DATE := NULL;
  BEGIN
    FOR rec IN ord_cur LOOP
      l_tot_rec_cnt := l_tot_rec_cnt + 1; -- Total No of Activity Analysis Order Lines
    
      IF rec.released_status = 'SHIPPED' THEN
        l_no_of_rec_closed := l_no_of_rec_closed + 1; -- Total no of Lines Closed where as per condition
      ELSE
        RETURN NULL;
      END IF;
    
      IF l_act_shipment_date IS NULL THEN
        l_act_shipment_date := rec.actual_shipment_date;
      ELSIF rec.actual_shipment_date > l_act_shipment_date THEN
        l_act_shipment_date := rec.actual_shipment_date; --Get the Max fulfillment date
      END IF;
    
    END LOOP;
  
    IF l_tot_rec_cnt = 0 THEN
      --If no Record Then return Null
      RETURN NULL;
    ELSIF l_tot_rec_cnt = l_no_of_rec_closed THEN
      -- If logic satisfies send Max FulllFillment Date
      RETURN l_act_shipment_date;
    ELSE
      --If   l_tot_rec_cnt !=  l_no_of_rec_closed
      RETURN NULL;
    END IF;
  
  END get_systems_ship_date;

END xxssys_oa2sf_util_pkg;
/
