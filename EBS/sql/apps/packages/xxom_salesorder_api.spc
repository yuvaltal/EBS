CREATE OR REPLACE PACKAGE xxom_salesorder_api AS
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
  ----------------------------------------------------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041891 - This function checks if a line is eligible for split
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  26/06/2017  Diptasurjya Chatterjee (TCS)    CHG0041891 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_eligible_for_split(p_inventory_item_id IN NUMBER,
		         p_organization_id   IN NUMBER,
		         p_request_source    IN VARCHAR2)
    RETURN NUMBER;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041891 - This function the original Payment Terms on a quote data
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  04/02/2018  Diptasurjya Chatterjee (TCS)    CHG0041892 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_quote_pterms(p_so_line_id     NUMBER,
		    p_request_source VARCHAR2) RETURN NUMBER;

  ----------------------------------------------------------------------------
  --  name:          process_order
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 20/03/2015
  ----------------------------------------------------------------------------
  --  purpose :      CHG0041891: Source specific validation and Generic call to standard Sales order processing API
  ----------------------------------------------------------------------------
  --  ver  date        name                    desc
  --  1.0  12/05/2017  Diptasurjya Chatterjee  CHG0041891 - initial build
  ----------------------------------------------------------------------------

  PROCEDURE process_order(p_header_rec      IN xxobjt.xxom_so_header_rec_type,
		  p_line_tab        IN xxobjt.xxom_so_lines_tab_type,
		  p_request_source  IN VARCHAR2,
		  p_err_code        OUT VARCHAR2,
		  p_err_message     OUT VARCHAR2,
		  p_order_number    OUT NUMBER,
		  p_order_header_id OUT NUMBER);

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
  --------------------------------------------------------------------
  -- Call End Point 1: Sales order Form personalization
  --------------------------------------------------------------------------------------------------------------------
  --  ver  date          name                 desc
  --  1.0 04-DEC-2017    Diptasurjya          CHG0041891 - Initial build
  ----------------------------------------------------------------------------------------------------------------------

  PROCEDURE process_quote_lines(x_retcode         OUT NUMBER,
		        x_errbuf          OUT VARCHAR2,
		        p_order_header_id IN NUMBER);

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
  ----------------------------------------------------------------------------------------------------------------------

  FUNCTION process_quote_lines(p_order_header_id IN NUMBER) RETURN VARCHAR2;

  PROCEDURE insert_test_order_lines(x_status         OUT VARCHAR2,
			x_status_message OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:          validate_quote
  --  created by:    Lingaraj Sarangi
  --  Revision       1.0
  --  creation date: 05/02/2018
  --------------------------------------------------------------------
  --  purpose :      CHG0041892: Will be Called from Sales Order Form Personilization
  ----------------------------------------------------------------------
  --  ver  date          name              Desc
  --  1.0 05-Feb-2017    Lingaraj          CHG0041892- Validation rules and holds on Book
  ----------------------------------------------------------------------
  FUNCTION validate_quote(p_header_id      NUMBER,
		  p_quote_number   VARCHAR2,
		  p_price_list_id  NUMBER,
		  p_request_source VARCHAR2) RETURN VARCHAR2;

END xxom_salesorder_api;
/
