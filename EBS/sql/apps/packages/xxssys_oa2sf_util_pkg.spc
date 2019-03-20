CREATE OR REPLACE PACKAGE xxssys_oa2sf_util_pkg IS

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
  --  1.1  07-AUG-18         Lingaraj Sarangi     CHG0043669  - need word replacment in SFDC
  --                                              inteface for Canada States same as done in US
  --  1.2  03-Sep-18         Lingaraj Sarangi     CTASK0038184 - FSL Order SF ID Validation
  --                                              [get_sf_fsl_header_id] -New Function Added     
  --  1.3  15-Nov-18         Lingaraj             CHG0044334 - Change in SO header interface 
  --                                              Update "Complete Order Shipped Date" and "Systems Shipped Date"
  --                                              Two New Function Added                
  --------------------------------------------------------------------

  g_relatedtosystems       VARCHAR2(255) := '';
  g_relatedtosystems2      VARCHAR2(255) := '';
  g_relatedtosystems3      VARCHAR2(255) := '';
  g_relatedtosystems4      VARCHAR2(255) := '';
  g_relatedtosystems5      VARCHAR2(255) := '';
  g_relatedtoproductfamily VARCHAR2(500) := '';

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
  FUNCTION get_sf_product_id(p_item_code IN VARCHAR2) RETURN VARCHAR2;

  --
  FUNCTION get_sf_related_item_product_id(p_item_code     IN VARCHAR2,
			      p_relation_type IN VARCHAR2)
    RETURN VARCHAR2;

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
  FUNCTION get_sf_itemcat_id(p_category_key IN VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_cpq_feature(p_item_code VARCHAR2) RETURN VARCHAR2;

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
  --------------------------------------------------------------------

  FUNCTION get_product_type(p_item_code         VARCHAR2,
		    p_inventory_item_id NUMBER) RETURN VARCHAR2;

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
    RETURN VARCHAR2;

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
    RETURN VARCHAR2;

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
    RETURN VARCHAR2;

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
    RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_active_price
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
  FUNCTION get_active_price(p_pricebook_listheader_id IN NUMBER,
		    p_inventory_item_id       IN NUMBER)
    RETURN NUMBER;

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
  FUNCTION get_sf_feature_id(p_item_code IN VARCHAR2) RETURN VARCHAR2;

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
    RETURN VARCHAR2;

  FUNCTION get_relatedtosystem_value(p_seq NUMBER) RETURN VARCHAR2;

  FUNCTION get_sf_account_id(p_account_number IN VARCHAR2)
  
   RETURN VARCHAR2;

  FUNCTION get_sf_pay_term_id(p_pay_term_id IN NUMBER) RETURN VARCHAR2;

  FUNCTION get_sf_contact_id(p_contact_id IN NUMBER) RETURN VARCHAR2;

  FUNCTION get_sf_opportunity_id(p_quote_no IN VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_sf_record_type_id(p_sobjecttype IN VARCHAR2,
		         p_name        VARCHAR2) RETURN VARCHAR2;
  FUNCTION get_sf_quote_id(p_quote_no IN VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_category_value(p_category_set_name VARCHAR2,
		      p_inventory_item_id NUMBER) RETURN VARCHAR2;

  FUNCTION is_sf_system_steup_exists(p_item_code IN VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_sf_currency_id(p_curr_code IN VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_sf_so_header_id(p_so_header_id IN NUMBER) RETURN VARCHAR2;
  FUNCTION get_sf_so_line_id(p_so_line_id IN NUMBER) RETURN VARCHAR2;

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
		       p_line_id   NUMBER) RETURN VARCHAR2;

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
  FUNCTION get_invoice4so_line(p_line_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_so_line_delivery_status(p_line_id NUMBER) RETURN VARCHAR2;

  FUNCTION is_order_line_on_hold(p_header_id NUMBER,
		         p_line_id   NUMBER) RETURN VARCHAR2;

  FUNCTION get_dist_functional_amount(p_line_id NUMBER) RETURN NUMBER;

  FUNCTION get_sf_asset_id(p_instance_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_sf_service_asset_id(p_line_id           IN NUMBER,
		           p_item_id           IN NUMBER,
		           p_attribute1        IN VARCHAR2,
		           p_attribute14       IN VARCHAR2,
		           p_srv_ref_type_code IN VARCHAR2,
		           p_srv_ref_line_id   IN NUMBER,
		           p_serial_number     IN VARCHAR2)
    RETURN VARCHAR2;

  FUNCTION get_item_uom_code(p_inventory_item_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_sf_price_line_id(p_list_header_id NUMBER,
		        p_item_code      VARCHAR2,
		        p_currency_code  VARCHAR2) RETURN VARCHAR2;

  ----------------------------------------------------------------------------------------------
  -- Ver    When        Who            Description
  -- -----  ----------  -------------  -----------------------------------------------------------
  -- 1.0    28/03/2018  Roman.W.       CHG0042560 - Sites - Locations oa2sf interface
  --                                   use in view XXHZ_SITE_DTL_V
  ----------------------------------------------------------------------------------------------
  FUNCTION get_sf_freight_term_id(p_freight_term VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_sf_site_id(p_site_id IN NUMBER) RETURN VARCHAR2;
  ----------------------------------------------------------------------------------------------
  -- Ver    When         Who            Description
  -- -----  ----------  -------------  -----------------------------------------------------------
  -- 1.0    02-May-2018  Lingaraj      CHG0041504 - Product interface
  ----------------------------------------------------------------------------------------------
  FUNCTION get_sf_servicecontract_id(p_coverage_schedule_id NUMBER)
    RETURN VARCHAR2;
  ----------------------------------------------------------------------------------------------
  -- Ver    When         Who            Description
  -- -----  ----------  -------------  -----------------------------------------------------------
  -- 1.0    02-May-2018  Lingaraj      CHG0042734 -Create Order interface - Enable Strataforce to create orders in Oracle
  ----------------------------------------------------------------------------------------------
  FUNCTION get_sf_fsl_so_header_id(p_so_header_id IN NUMBER) RETURN VARCHAR2;

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
  FUNCTION get_sf_location_id(p_location_code IN VARCHAR2) RETURN VARCHAR2;

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
  FUNCTION get_pl_transalation(p_list_header_id IN NUMBER) RETURN NUMBER;

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
		  p_state_code   VARCHAR2) RETURN VARCHAR2;
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
    RETURN VARCHAR2;

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
  FUNCTION get_order_complete_ship_date(p_header_id IN NUMBER) RETURN DATE;

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
  FUNCTION get_systems_ship_date(p_header_id IN NUMBER) RETURN DATE;

END xxssys_oa2sf_util_pkg;
/
