CREATE OR REPLACE PACKAGE xxobjt_oa2sf_interface_pkg IS

  --------------------------------------------------------------------
  --  name:            XXOBJT_OA2SF_INTERFACE_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   01/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        CUST352 - Oracle Interface with SFDC
  --                   This package Handle all procedure that transfer
  --                   data from oracle to SF.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  01/09/2010  Dalit A. Raviv    initial build
  --  1.1  05/01/2014  Dalit A. Raviv    add 2 functions: get_entity_sf_id, check_party_type
  --  1.2  03/02/2014  Vitaly            Two procedures are added ( get_source_view_data , source_data_query )
  --  1.3  08/01/2015  Michal Tzvik      CHG00340083
  --                                     Add function purge_objct_interface_tables
  --  1.4  21.11.17   yuval tal         CHG0041509 add is_account_merge
  --------------------------------------------------------------------
  TYPE t_oa2sf_rec IS RECORD(
    status       VARCHAR2(50), -- NEW/IN-PROCESS/ERR/SUCCESS
    process_mode VARCHAR2(50), -- INSERT/UPDATE
    source_id    VARCHAR2(50), -- oracle_id
    source_id2   VARCHAR2(50),
    source_name  VARCHAR2(50), -- ACCOUNT/SITE/?.
    sf_id        VARCHAR2(250)); --sf_id

  TYPE xxinv_source_view_data_rec IS RECORD(
    seq_no          NUMBER,
    source_name     VARCHAR2(100),
    source_id       VARCHAR2(100),
    view_name       VARCHAR2(30),
    field_name      VARCHAR2(30),
    field_data_type VARCHAR2(30),
    field_value     VARCHAR2(3000));

  TYPE xxinv_source_data_tab IS TABLE OF xxinv_source_view_data_rec INDEX BY BINARY_INTEGER;

  TYPE xxinv_source_view_data_tbl IS TABLE OF xxinv_source_view_data_rec;

  --------------------------------------------------------------------
  --  name:            is_relate_to_sf
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        function that check by entity name
  --                   if entity relate to sales force
  --                   for example att4 = Y for party/ cust_account
  --------------------------------------------------------------------

  FUNCTION get_sf_format(p_date DATE) RETURN VARCHAR2;
  --  ver  date        name              desc
  --  1.0  05/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION is_relate_to_sf(p_source_id    IN NUMBER,
		   p_source_name  IN VARCHAR2,
		   p_process_mode IN VARCHAR2) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            is_source_id_exist
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that check by entity name
  --                   if entity relate to sales force
  --                   for example att4 = Y for party/ cust_account
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION is_source_id_exist(p_source_id   IN VARCHAR2,
		      p_source_name IN VARCHAR2) RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            insert_into_interface
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that insert row to interface tbl
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE insert_into_interface(p_oa2sf_rec IN t_oa2sf_rec,
		          p_err_code  OUT VARCHAR2,
		          p_err_msg   OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            upd_system_err
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   01/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  01/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE upd_system_err(p_batch_id IN NUMBER,
		   p_err_code IN OUT VARCHAR2,
		   p_err_msg  IN OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            Call_Bpel_Process
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   02/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Call Bpel process - xxOA2SF_interfaces
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  02/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            get_sf_owner_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   01/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Function that will return sf_owner_id
  --                   by several parmeters.
  --                   Postal_code (Postal_code_from - postal_code_to)
  --                   City
  --                   County
  --                   State_code
  --                   Country_code
  --                   The logic is according to above order,
  --                   while parameters 1,2,3,4 can be null.
  --                   start check if p_Postal_code is not null - check by postal code range
  --                   if null check by p_city, if null check by p_county,
  --                   if null check by p_state_code, if null check by p_country_code.
  --                   exception will return null.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  01/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_sf_owner_id(p_postal_code  IN VARCHAR2,
		   p_city         IN VARCHAR2,
		   p_county       IN VARCHAR2,
		   p_state_code   IN VARCHAR2,
		   p_country_code IN VARCHAR2) RETURN VARCHAR2;

  /*  --------------------------------------------------------------------
  --  name:            get_product_sf_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Function that will return if product relate to SF
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_product_sf_id(p_source_id IN NUMBER) RETURN VARCHAR2;*/

  --------------------------------------------------------------------
  --  name:            get_price_list_header_is_SF
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Function that will return if price list header
  --                   connect to Sf
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_price_list_header_is_sf(p_source_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            upd_oracle_sf_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/01/2014 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Update batch_id at xxobjt_oa2sf_interface tbl
  --                   Loop on records (for each  X records according profile )
  --                   according to SOURCE_NAME, STATUS = NEW and MODE=INSERT
  --                   Update batch_id and status = IN_PROCESS
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/01/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE upd_oracle_sf_id(p_bpel_instance_id IN NUMBER,
		     p_err_code         OUT VARCHAR2,
		     p_err_msg          OUT VARCHAR2);

  PROCEDURE upd_oracle_sf_id(p_source_name     IN VARCHAR2,
		     p_sf_id           IN VARCHAR2,
		     p_source_id       IN VARCHAR2,
		     p_oracle_event_id IN NUMBER,
		     p_err_code        OUT VARCHAR2,
		     p_err_msg         OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            Get_entity_sf_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/01/2014
  --------------------------------------------------------------------
  --  purpose :        CR 1215 - Customer support SF-OA interfaces
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05/01/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_entity_sf_id(p_entity    VARCHAR2,
		    p_entity_id VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_entity_oe_id(p_entity VARCHAR2,
		    p_sf_id  VARCHAR2) RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            is_valid_to_sf
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/01/2014
  --------------------------------------------------------------------
  --  purpose :        CR 1215 - Customer support SF-OA interfaces
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05/01/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION is_valid_to_sf(p_entity    VARCHAR2,
		  p_entity_id VARCHAR2) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            sync_item_on_hand
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/01/2014
  --------------------------------------------------------------------
  --  purpose :        procedure will get all items that had transaction
  --                   in the last XXX hour.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/01/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE sync_item_on_hand(errbuf       OUT VARCHAR2,
		      retcode      OUT VARCHAR2,
		      p_hours_back IN NUMBER,
		      p_item_id    IN NUMBER);

  --------------------------------------------------------------------
  --  name:            sync_daily_rate
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   06/01/2014
  --------------------------------------------------------------------
  --  purpose :        procedure will craete new records for bpel rate sync process
  --                   source=CUR_RATE source_id =cuurency_code
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/01/2014  yuval tal    initial build
  --------------------------------------------------------------------
  PROCEDURE sync_daily_rate(errbuf  OUT VARCHAR2,
		    retcode OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            sync_Secondary_Price_Books
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   06/01/2014
  --------------------------------------------------------------------
  --  purpose :        procedure will craete new records for bpel rate sync process
  --                   source=SEC_PRICEBOOK source_id =parent_price_list_id||?-?||qsec.list_header_id XXOBJT_OA2SF_SECONDARY_PRICE_V
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/01/2014  yuval tal    initial build
  --------------------------------------------------------------------
  PROCEDURE sync_secondary_price_books(errbuf  OUT VARCHAR2,
			   retcode OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            get_mail_dist_list
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   06/01/2014
  --------------------------------------------------------------------
  --  purpose :        procedure will return dist list for error alert event
  --                   p_type - TO/CC
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/01/2014  yuval tal    initial build
  --------------------------------------------------------------------
  FUNCTION get_mail_distribution_list(p_oracle_event_id NUMBER,
			  p_type            VARCHAR2 DEFAULT 'TO')
    RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            get_source_view_data
  --  create by:       Vitaly
  --  Revision:        1.0
  --  creation date:   03/02/2014
  --------------------------------------------------------------------
  --  purpose :   CUST776 - Customer support SF-OA interfaces\CR 1215 - Customer support SF-OA interfaces
  --              XX OA2SF Monitor form
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/02/2014  Vitaly            initial build
  --------------------------------------------------------------------
  FUNCTION get_source_view_data(p_source_name VARCHAR2,
		        p_source_id   VARCHAR2)
    RETURN xxinv_source_view_data_tbl
    PIPELINED;
  --------------------------------------------------------------------
  --  name:            source_data_query
  --  create by:       Vitaly
  --  Revision:        1.0
  --  creation date:   03/02/2014
  --------------------------------------------------------------------
  --  purpose :   CUST776 - Customer support SF-OA interfaces\CR 1215 - Customer support SF-OA interfaces
  --              XX OA2SF Monitor form
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/02/2014  Vitaly            initial build
  --------------------------------------------------------------------
  PROCEDURE source_data_query(source_data   IN OUT xxinv_source_data_tab,
		      p_source_name IN VARCHAR2,
		      p_source_id   IN VARCHAR2);

  --------------------------------------------------------------------
  --  name:            get_invoice4so_line
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

  FUNCTION get_order_hold(p_header_id NUMBER) RETURN VARCHAR2;
  FUNCTION get_order_line_hold(p_header_id NUMBER,
		       p_line_id   NUMBER) RETURN VARCHAR2;
  PROCEDURE handle_events(errbuf  OUT VARCHAR2,
		  retcode OUT VARCHAR2);

  PROCEDURE check_quantity_available(p_organization_id   NUMBER,
			 p_subinventory_code VARCHAR2,
			 p_inventory_item_id NUMBER,
			 p_revision          VARCHAR2,
			 p_quantity          NUMBER,
			 p_err_code          OUT NUMBER,
			 p_err_message       OUT VARCHAR2);

  PROCEDURE get_item_dist_account_id(p_organization_id       NUMBER,
			 p_inventory_item_id     NUMBER,
			 p_cost_of_sales_account OUT NUMBER,
			 p_err_code              OUT NUMBER,
			 p_err_message           OUT VARCHAR2);
  PROCEDURE get_material_trx_info(p_err_code    OUT NUMBER,
		          p_err_message OUT VARCHAR2,
		          p_tab         IN OUT xxobjt_oa2sf_material_tab_type);

  PROCEDURE submit_pull_requestset(p_source     VARCHAR2,
		           p_request_id OUT NUMBER,
		           p_err_code   OUT VARCHAR2,

		           p_err_message OUT VARCHAR2);

  -- 1.3 CHG0034083 Michal Tzvik 08/01/2015
  PROCEDURE purge_objct_interface_tables(errbuf      OUT VARCHAR2,
			     retcode     OUT VARCHAR2,
			     p_days_back IN NUMBER,
			     p_status    IN VARCHAR2);

  FUNCTION is_account_merged(p_account_number VARCHAR2) RETURN VARCHAR2;

  ------------------------------------------------------------------------------------
  -- Ver      Who        When            Description
  -- -------  ---------  -------------   ---------------------------------------------
  -- 1.0      Roman.W    02/04/2018      CHG0042619 - Install base interface
  --                                                  from Oracle to salesforce
  ------------------------------------------------------------------------------------
  FUNCTION get_sf_parent_instance_id(parent_instance_id NUMBER) RETURN NUMBER;

END xxobjt_oa2sf_interface_pkg;
/
