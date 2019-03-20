declare
-----------------------------------------------------------------------------------------------
--                                    SFDEV
-----------------------------------------------------------------------------------------------
-- Ver    When         Who         Description
-- -----  -----------  ----------  ------------------------------------------------------------
-- 1.0    28-AUG-2018  Roman W.    CHG0043434 - Sync documents from Oracle to salesforce
--                                    create setup for concurrent "XX CUST Document Submitter"
-----------------------------------------------------------------------------------------------
l_set_id NUMBER;
l_count  NUMBER;
l_book_location VARCHAR2(300) := '/mnt/oracle/strataforce/outgoing/book';
l_ship_location VARCHAR2(300) := '/mnt/oracle/strataforce/outgoing/ship';
begin 
    select count(*)
    into l_count
    from xx_cust_report_submitter xcrs
    where xcrs.set_code in ('SSYS_BOOK', 'SSYS_SHIPC');
    
    if l_count > 0 then
      delete 
        from XX_CUST_REPORT_SUBMITTER_PARAM xcrsp
       where xcrsp.set_id in (select set_id
                              from xx_cust_report_submitter xcrs
                              where xcrs.set_code in ('SSYS_BOOK','SSYS_SHIPC' )
                             );
      commit;                         
      
      delete 
      from   xx_cust_report_submitter xcrs
      where  xcrs.set_code in ('SSYS_BOOK' , 'SSYS_SHIPC');
      
      commit;                         
    end if;  
-- 1) SSYS_BOOK XXOEORDPROFORMA

      l_set_id := XX_CUST_CONC_SUBMITTER_S.nextval;
      
      -- Header
      Insert into XX_CUST_REPORT_SUBMITTER (SET_ID,SET_CODE,ORG_ID,APPLICATION_SHORT_NAME,CONCURRENT_PROGRAM_NAME,TEMPLATE_CODE,ENABLE_FLAG,EXPORT_FOLDER,EXPORT_FILE_NAME,ADMIN_USER,TEMPLATE_TYPE_CODE,DEFAULT_LANGUAGE,DEFAULT_TERRITORY,OUTPUT_TYPE,CC_MAIL_RECIPIENT_LIST,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE) 
                  values (l_set_id,'SSYS_BOOK',null,'XXOBJT','XXOEORDPROFORMA','XXOEORDPROFORMA','Y','/mnt/oracle/strataforce/outgoing/book','select ''ORD_PROF-''||
       (select ooha.order_number
        from OE_ORDER_HEADERS_ALL ooha
        where ooha.header_id = :1
       ) ||
       ''.pdf'' 
  from dual','DOVIK.POLLAK','RTF','en','US','PDF',null,12714,trunc(sysdate),12714,trunc(sysdate));
                         
      -- Line
      Insert into XX_CUST_REPORT_SUBMITTER_PARAM (SET_ID,SEQ_NO,DEFAULT_VALUE,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE) 
                  values (l_set_id,10,'select :1 from dual',12714,trunc(sysdate),12714,trunc(sysdate));
     
-- 2) SSYS_BOOK XXOEORDACK

      l_set_id := XX_CUST_CONC_SUBMITTER_S.nextval;
      
      -- Header
      Insert into XX_CUST_REPORT_SUBMITTER (SET_ID,SET_CODE,ORG_ID,APPLICATION_SHORT_NAME,CONCURRENT_PROGRAM_NAME,TEMPLATE_CODE,ENABLE_FLAG,EXPORT_FOLDER,EXPORT_FILE_NAME,ADMIN_USER,TEMPLATE_TYPE_CODE,DEFAULT_LANGUAGE,DEFAULT_TERRITORY,OUTPUT_TYPE,CC_MAIL_RECIPIENT_LIST,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE) 
                 values (l_set_id,'SSYS_BOOK',null,'XXOBJT','XXOEORDACK','XXOEORDACK','Y','/mnt/oracle/strataforce/outgoing/book','select ''ORD_ACK-''||
              (select ooha.order_number
                 from OE_ORDER_HEADERS_ALL ooha
                where ooha.header_id = :1
              ) ||''.pdf'' 
        from dual','DOVIK.POLLAK','RTF','en','US','PDF',null,12714,trunc(sysdate),12714,trunc(sysdate));
                          
      -- Line 
      Insert into XX_CUST_REPORT_SUBMITTER_PARAM (SET_ID,SEQ_NO,DEFAULT_VALUE,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE) 
                  values (l_set_id,10,'select :1 from dual',12714,to_date('02-AUG-2018','DD-MON-RRRR'),12714,to_date('02-AUG-2018','DD-MON-RRRR'));

-- 3) SSYS_SHIPC XXSSUS_WSHRDINV

      l_set_id := XX_CUST_CONC_SUBMITTER_S.nextval;
      -- Header
      Insert into XX_CUST_REPORT_SUBMITTER (SET_ID,SET_CODE,ORG_ID,APPLICATION_SHORT_NAME,CONCURRENT_PROGRAM_NAME,TEMPLATE_CODE,ENABLE_FLAG,EXPORT_FOLDER,EXPORT_FILE_NAME,ADMIN_USER,TEMPLATE_TYPE_CODE,DEFAULT_LANGUAGE,DEFAULT_TERRITORY,OUTPUT_TYPE,CC_MAIL_RECIPIENT_LIST,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE) 
                 values (l_set_id,'SSYS_SHIPC',null,'XXOBJT','XXSSUS_WSHRDINV','XXSSUS_WSHRDINV','Y','/mnt/oracle/strataforce/outgoing/ship','SELECT ''COMM_INV-'' || LISTAGG(source_header_number, ''_'') WITHIN GROUP (ORDER BY source_header_number) || ''.pdf''
        FROM (SELECT wdv.source_header_number
                FROM wsh_deliverables_v wdv
               WHERE wdv.delivery_id = :1
               GROUP BY wdv.source_header_number )','DOVIK.POLLAK','RTF','en','US','PDF',null,12714,trunc(sysdate),12714,trunc(sysdate));
         

      -- Line
      Insert into XX_CUST_REPORT_SUBMITTER_PARAM (SET_ID,SEQ_NO,DEFAULT_VALUE,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE) 
                  values (l_set_id,45,' select wdv.organization_id
   from wsh_deliverables_v wdv
  where wdv.delivery_id = :1',12714,trunc(sysdate),12714,trunc(sysdate));
  
      Insert into XX_CUST_REPORT_SUBMITTER_PARAM (SET_ID,SEQ_NO,DEFAULT_VALUE,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE) 
                  values (l_set_id,50,'select :1 from dual',12714,trunc(sysdate),12714,trunc(sysdate));

-- 4) SSYS_SHIPC XXOM_SSYS_RMA

      l_set_id := XX_CUST_CONC_SUBMITTER_S.nextval;
      
      -- Header
      Insert into XX_CUST_REPORT_SUBMITTER (SET_ID,SET_CODE,ORG_ID,APPLICATION_SHORT_NAME,CONCURRENT_PROGRAM_NAME,TEMPLATE_CODE,ENABLE_FLAG,EXPORT_FOLDER,EXPORT_FILE_NAME,ADMIN_USER,TEMPLATE_TYPE_CODE,DEFAULT_LANGUAGE,DEFAULT_TERRITORY,OUTPUT_TYPE,CC_MAIL_RECIPIENT_LIST,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE) 
                values (l_set_id,'SSYS_SHIPC',null,'XXOBJT','XXOM_SSYS_RMA','XXOM_SSYS_RMA','Y','/mnt/oracle/strataforce/outgoing/ship','SELECT ''RMA-'' || LISTAGG(source_header_number, ''_'') WITHIN GROUP (ORDER BY source_header_number) || ''.pdf''
        FROM (SELECT wdv.source_header_number
                FROM wsh_deliverables_v wdv
               WHERE wdv.delivery_id = :1
               GROUP BY wdv.source_header_number )','DOVIK.POLLAK','RTF','en','US','PDF',null,12714,trunc(sysdate),12714,trunc(sysdate));
         

      -- Line
      Insert into XX_CUST_REPORT_SUBMITTER_PARAM (SET_ID,SEQ_NO,DEFAULT_VALUE,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE) 
                  values (l_set_id,10,'select :1 from dual',12714,trunc(sysdate),12714,trunc(sysdate));
      
-- 5) SSYS_SHIPC XXSF_SERVICE_LABEL

      l_set_id := XX_CUST_CONC_SUBMITTER_S.nextval;
      -- Header
      Insert into XX_CUST_REPORT_SUBMITTER (SET_ID,SET_CODE,ORG_ID,APPLICATION_SHORT_NAME,CONCURRENT_PROGRAM_NAME,TEMPLATE_CODE,ENABLE_FLAG,EXPORT_FOLDER,EXPORT_FILE_NAME,ADMIN_USER,TEMPLATE_TYPE_CODE,DEFAULT_LANGUAGE,DEFAULT_TERRITORY,OUTPUT_TYPE,CC_MAIL_RECIPIENT_LIST,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE) 
                values (l_set_id,'SSYS_SHIPC',null,'XXOBJT','XXSF_SERVICE_LABEL','XXSF_SERVICE_LABEL','Y','/mnt/oracle/strataforce/outgoing/ship','SELECT ''ORD_PARTS-'' || LISTAGG(source_header_number, ''_'') WITHIN GROUP (ORDER BY source_header_number) || ''.pdf''
        FROM (SELECT wdv.source_header_number
                FROM wsh_deliverables_v wdv
               WHERE wdv.delivery_id = :1
               GROUP BY wdv.source_header_number )','DOVIK.POLLAK','RTF','en','US','PDF',null,12714,trunc(sysdate),12714,trunc(sysdate));
                         
      
      -- Line
      Insert into XX_CUST_REPORT_SUBMITTER_PARAM (SET_ID,SEQ_NO,DEFAULT_VALUE,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE) 
                  values (l_set_id,10,'select :1 from dual',12714,trunc(sysdate),12714,trunc(sysdate));

   commit;                        
end;
