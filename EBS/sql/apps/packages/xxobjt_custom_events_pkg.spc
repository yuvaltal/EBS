create or replace package xxobjt_custom_events_pkg AS

  -- ---------------------------------------------------------------------------------
  -- Name:       XXOBJT_CUSTOM_EVENTS_PKG
  -- Created By: MMAZANET
  -- Revision:   1.0
  -- ---------------------------------------------------------------------------------
  -- Purpose: This package will be multi-purpose:
  --          1) It will be used for handling custom events from Oracle applications
  --          2) This can also be used for error logging by calling the insert_error_event
  --             procedure.  This can be called from any code unit.  An alert called
  --             'XXOBJT_ERROR_RPT' has been built on this table to report any errors.
  --
  --          This package also contains a procedure called delete_event_tbl.  This
  --          can be used to clear records from this table periodically.
  -- ---------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  03/14/2014  MMAZANET    Initial Creation for CHG0031323.
  -- 1.1  06.04.14    yuval tal   CUST776 - Customer support SF-OA interfaces\CR 1215
  --                              add handle_events/om_events/ar_events  
  -- ---------------------------------------------------------------------------------

  PROCEDURE insert_error_event(p_error_msg    IN VARCHAR2,
		       p_calling_prog IN VARCHAR2,
		       p_attribute5   IN VARCHAR2 DEFAULT NULL,
		       p_attribute6   IN VARCHAR2 DEFAULT NULL,
		       p_attribute7   IN VARCHAR2 DEFAULT NULL,
		       p_attribute8   IN VARCHAR2 DEFAULT NULL,
		       p_attribute9   IN VARCHAR2 DEFAULT NULL,
		       p_attribute10  IN VARCHAR2 DEFAULT NULL,
		       p_attribute11  IN VARCHAR2 DEFAULT NULL,
		       p_attribute12  IN VARCHAR2 DEFAULT NULL,
		       p_attribute13  IN VARCHAR2 DEFAULT NULL,
		       p_attribute14  IN VARCHAR2 DEFAULT NULL,
		       p_attribute15  IN VARCHAR2 DEFAULT NULL);

  PROCEDURE insert_event(p_rec xxobjt_custom_events%ROWTYPE);

  PROCEDURE delete_event_tbl(errbuff       OUT VARCHAR2,
		     retcode       OUT NUMBER,
		     p_event_id    IN NUMBER,
		     p_event_name  IN VARCHAR2,
		     p_event_table IN VARCHAR2,
		     p_event_key   IN VARCHAR2,
		     p_date_from   IN VARCHAR2,
		     p_date_to     IN VARCHAR2,
		     p_truncate    IN VARCHAR2);

  --------------------------------------------------------------------
  -- handle_events
  --------------------------------------------------------------------
  --  purpose :  process custom event from table xxobjt_custom_events
  --             simulate oracle register event
  --             every run will search new records according to last proceed event_id
  --             CUST776 - Customer support SF-OA interfaces\CR 1215 - Customer support SF-OA interfaces
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/03/2014  yuval tal         initial build
  --------------------------------------------------------------------

  PROCEDURE handle_events(errbuf  OUT VARCHAR2,
		  retcode OUT VARCHAR2);

  PROCEDURE om_events(errbuf            OUT VARCHAR2,
	          retcode           OUT VARCHAR2,
	          p_last_date_check VARCHAR2);
  PROCEDURE ar_events(errbuf            OUT VARCHAR2,
	          retcode           OUT VARCHAR2,
	          p_last_date_check VARCHAR2);

  PROCEDURE cs_events(errbuf            OUT VARCHAR2,
	          retcode           OUT VARCHAR2,
	          p_last_date_check VARCHAR2);
END xxobjt_custom_events_pkg;
/