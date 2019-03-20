CREATE OR REPLACE PACKAGE xxom_order_interface_pkg AUTHID CURRENT_USER AS
  --------------------------------------------------------------------
  --  name:              XXOM_ORDER_INTERFACE_PKG
  --  create by:         yuval tal
  --  Revision:          1.1
  --  creation date:     26/05/2013
  --------------------------------------------------------------------
  --  purpose :          CUST 675 eCommerce Integration
  --                     Interface between SYSS Salsforce system and Oracle Apps
  --
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  26/05/2013    yuval tal         Initial Build - CR736 eCommerce Integration IN - Handle Order creation/Query
  --  1.1  16/12/2013    Dalit A. Raviv    add 2 new procedures: create_quote create_sales_order_from_quote
  --  1.2  12/01/2014    Dalit A. Raviv    Procedure get_order_type_details add check to SF process
  --  1.3  07/01/2015    Michal Tzvik      CHG0034083? Monitor form for Orders Interface from SF-> OA and Purge process for log
  --                                       1. Add functions / procedures:
  --                                          - purge_order_interface_tables
  --                                          - get_contact_name
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            get_order_type_details
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/01/2014
  --------------------------------------------------------------------
  --  purpose :        Set order type id and lines type id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/01/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE get_order_type_details(p_interface_header_id IN NUMBER,
		           errbuf                OUT VARCHAR2,
		           retcode               OUT NUMBER);

  --------------------------------------------------------------------
  --  name:            create_quote
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/12/2013
  --------------------------------------------------------------------
  --  purpose :        create sales order from type quote according to data in tables
  --                   xxom_sf2oa_header_interface, xxom_sf2oa_lines_interface
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/12/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_quote(p_header_seq      NUMBER,
		 p_err_code        OUT VARCHAR2,
		 p_err_message     OUT VARCHAR2,
		 p_order_number    OUT NUMBER,
		 p_order_header_id OUT NUMBER,
		 p_order_status    OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            create_sales_order_from_quote
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/12/2013
  --------------------------------------------------------------------
  --  purpose :        create sales order from type quote according to data in tables
  --                   xxom_sf2oa_header_interface, xxom_sf2oa_lines_interface
  --
  --                   p_order_header_id (674830) is the draft headr id that created by the api process_order
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/12/2013  Dalit A. Raviv    initial build

  --------------------------------------------------------------------
  PROCEDURE create_sales_order_from_quote(p_order_header_id IN NUMBER,
			      p_user            IN NUMBER,
			      p_resp            IN NUMBER,
			      p_appl            IN NUMBER,
			      p_err_code        OUT VARCHAR2,
			      p_err_message     OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            create_order_api
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   26.5.2013
  --------------------------------------------------------------------
  --  purpose :        CR736 eCommerce Integration IN - Handle Order creation/Query
  --                   caliing so api
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26.5.2013   yuval tal         initial build
  --  1.1  12/01/2014  Dalit A. Raviv    add handle of create order in BOOKED status
  --  1.2  03/02/2014  Dalit A. Raviv    add Parameter of Line info from the API (p_line_tbl_out )
  --------------------------------------------------------------------
  PROCEDURE create_order_api(p_org_id             IN NUMBER,
		     p_user_id            IN NUMBER,
		     p_resp_id            IN NUMBER,
		     p_appl_id            IN NUMBER,
		     p_header_rec         oe_order_pub.header_rec_type,
		     p_line_tbl           oe_order_pub.line_tbl_type,
		     p_action_request_tbl oe_order_pub.request_tbl_type,
		     p_line_tbl_out       OUT oe_order_pub.line_tbl_type,
		     p_order_number       OUT NUMBER,
		     p_header_id          OUT NUMBER,
		     p_order_status       OUT VARCHAR2,
		     p_err_code           OUT VARCHAR2,
		     p_err_message        OUT VARCHAR2);

  FUNCTION get_freight_amount(p_oe_header_id NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:              create_order
  --  create by:         yuval tal
  --  Revision:          1.0
  --  creation date:     26.5.13
  --------------------------------------------------------------------
  --  purpose :          CUST 675 eCommerce Integration
  --                     Interface between SYSS Salsforce system and Oracle Apps
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  26.5.13       yuval tal         create sales order according to data in tables xxom_sf2oa_header_interface, xxom_sf2oa_lines_interface
  --  1.1  18/11/2013    Dalit A. Raviv    send org_id to function get_ship_invoice_org_id, get_sold_to_org_id instead of null CR1083
  --------------------------------------------------------------------
  PROCEDURE create_order(p_header_seq      NUMBER,
		 p_err_code        OUT VARCHAR2,
		 p_err_message     OUT VARCHAR2,
		 p_order_number    OUT NUMBER,
		 p_order_header_id OUT NUMBER,
		 p_order_status    OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:              get_order_type_name
  --  create by:         yuval tal
  --  Revision:          1.0
  --  creation date:     3.2.14
  --------------------------------------------------------------------
  --  purpose :          CUST 675 eCommerce Integration
  --                     Interface between SYSS Salsforce system and Oracle Apps
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  3.2.14       yuval tal
  FUNCTION get_order_type_name(p_order_type_id NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  /*PROCEDURE create_order_old(p_header_seq      NUMBER,
                               p_err_code        OUT VARCHAR2,
                               p_err_message     OUT VARCHAR2,
                               p_order_number    OUT NUMBER,
                               p_order_header_id OUT NUMBER,
                               p_order_status    OUT VARCHAR2);
  */
  FUNCTION get_site_use_id(p_org_id            NUMBER,
		   p_cust_acct_site_id NUMBER,
		   p_use_code          VARCHAR2) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            Purge_order_interface_tables
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   07/01/2015
  --------------------------------------------------------------------
  --  purpose :        CHG00340083
  --                   Purge order interface tables
  --                   Concurrent executable: XXOM_PURGE_ORDER_INT_TABELS
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/01/2015  Michal Tzvik    initial build
  --------------------------------------------------------------------
  PROCEDURE purge_order_interface_tables(errbuf             OUT VARCHAR2,
			     retcode            OUT VARCHAR2,
			     p_days_back        IN NUMBER,
			     p_source_type_code IN VARCHAR2,
			     p_status           IN VARCHAR2);

  --------------------------------------------------------------------
  --  name:            get_contact_name
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   07/01/2015
  --------------------------------------------------------------------
  --  purpose :        CHG00340083
  --                   get formated contact name
  --                   Called by view xxom_order_header_interface_v
  --                   for form XXOMORDERSINT
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/01/2015  Michal Tzvik    initial build
  --------------------------------------------------------------------
  FUNCTION get_contact_name(p_contact_id NUMBER) RETURN VARCHAR2;

END;
/
