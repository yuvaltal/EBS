CREATE OR REPLACE PACKAGE BODY XXQP_PL_FORMULA_SYNC_PKG AS
  ----------------------------------------------------------------------------
  --  name:            XXQP_PL_FORMULA_SYNC_PKG
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   07/13/2018
  ----------------------------------------------------------------------------
  --  purpose :        CHG0043433 - Package to handle interfacing formula based PLs
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  07/13/2018  Diptasurjya Chatterjee(TCS)  CHG0043433 - initial build
  ----------------------------------------------------------------------------

  procedure insert_formula_pl_line_event(p_target_name IN varchar2,
                                        p_entity_name IN varchar2,
                                        p_inventory_item_id IN number,
                                        p_list_header_id IN number,
                                        p_list_price IN number,
                                        p_item_code IN varchar2,
                                        p_item_uom_code IN varchar2,
                                        p_currency_code IN varchar2,
                                        p_status IN varchar2,
                                        p_user_id IN number,
                                        p_event_name IN varchar2) is
    l_xxssys_event_rec      xxssys_events%ROWTYPE;

  BEGIN


    l_xxssys_event_rec.target_name     := p_target_name;
    l_xxssys_event_rec.entity_name     := p_entity_name;
    l_xxssys_event_rec.entity_id       := p_list_header_id;
    l_xxssys_event_rec.entity_code     := p_list_header_id||'|'||p_item_code||'|'||p_currency_code;
    l_xxssys_event_rec.attribute1      := p_inventory_item_id;
    l_xxssys_event_rec.attribute4      := p_item_code;
    l_xxssys_event_rec.attribute5      := p_currency_code;
    l_xxssys_event_rec.attribute7      := p_list_price;
    l_xxssys_event_rec.attribute8      := p_item_uom_code;
    l_xxssys_event_rec.active_flag     := p_status;
    l_xxssys_event_rec.event_name      := p_event_name;
    l_xxssys_event_rec.last_updated_by := p_user_id;
    l_xxssys_event_rec.created_by      := p_user_id;
    

    xxssys_event_pkg.insert_event(l_xxssys_event_rec,'Y');
  end insert_formula_pl_line_event;
  
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0043433 - This function fetched default values for pricing PAI from lookup XXQP_PRICING_DEFAULT_VALUES
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  07/17/2018  Diptasurjya Chatterjee (TCS)    CHG0043433 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_default_values(p_lookup_code VARCHAR2) RETURN VARCHAR2 IS
    l_default_value NUMBER;
  BEGIN
    SELECT to_number(meaning)
    INTO   l_default_value
    FROM   fnd_lookup_values
    WHERE  lookup_type = 'XXQP_PRICING_DEFAULT_VALUES'
    AND    lookup_code = p_lookup_code
    AND    enabled_flag = 'Y'
    AND    LANGUAGE = 'US';

    RETURN(l_default_value);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN(-1);
  END;
  
  --------------------------------------------------------------------
  --  name:            call_price_api
  --  create by:       Diptasurjya
  --  Revision:        1.0
  --  creation date:   07/17/2018
  --------------------------------------------------------------------
  --  purpose : CHG0043433 - This procedure will call the pricing API to return list price value
  ------------------------------------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  07/17/2018  Diptasurjya        CHG0043433 - initial build
  ------------------------------------------------------------------------------------------------
  PROCEDURE call_price_api(p_item_id        IN NUMBER,
                           p_price_list_id  IN NUMBER,
                           x_list_price     OUT NUMBER,
                           x_item_uom       OUT VARCHAR2,
                           x_status         OUT VARCHAR2,
                           x_status_msg     OUT VARCHAR2)

   IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_item_price NUMBER;
    l_item_uom VARCHAR2(20);

    p_order_header xxqp_pricereq_header_tab_type;
    p_item_lines   xxqp_pricereq_lines_tab_type;

    l_order_header_rec xxqp_pricereq_header_rec_type;
    l_item_lines_rec   xxqp_pricereq_lines_rec_type;

    l_session_details    xxqp_pricereq_session_tab_type := xxqp_pricereq_session_tab_type();
    l_order_details      xxqp_pricereq_header_tab_type := xxqp_pricereq_header_tab_type();
    l_line_details       xxqp_pricereq_lines_tab_type := xxqp_pricereq_lines_tab_type();
    l_modifier_details   xxqp_pricereq_mod_tab_type := xxqp_pricereq_mod_tab_type();
    l_attribute_details  xxqp_pricereq_attr_tab_type := xxqp_pricereq_attr_tab_type();
    l_related_adjustment xxqp_pricereq_reltd_tab_type := xxqp_pricereq_reltd_tab_type();
    l_cust_account_id    hz_cust_accounts.cust_account_id%TYPE;
    l_ship_to_site_id    hz_cust_site_uses_all.site_use_id%TYPE;
    l_bill_to_site_id    hz_cust_site_uses_all.site_use_id%TYPE;
    l_order_type_id      oe_order_headers_all.order_type_id%TYPE;
    l_org_id             NUMBER;
    i                    NUMBER;
    
    l_status           VARCHAR2(10);
    l_status_message   VARCHAR2(1000);
    l_price_request_id VARCHAR2(100);
    
    l_pl_org_id        NUMBER;
  BEGIN
    select qlh.ORIG_ORG_ID
      into l_pl_org_id
      from qp_list_headers_all qlh
     where list_header_id = p_price_list_id;

    l_org_id          := nvl(l_pl_org_id, get_default_values('XX_ORG_ID'));

    l_price_request_id := 'GP' || xxqp_price_request_id_seq.nextval;
    l_order_header_rec := xxqp_pricereq_header_rec_type(l_price_request_id, NULL, l_cust_account_id, NULL,
                null, null, l_org_id,get_default_values('XX_OPERATION_NO'), '', '', NULL, p_price_list_id,
                NULL,NULL,NULL,sysdate,'','','','',l_order_type_id,'','','','','','','','','','','',
                '','','','','','','','',NULL,NULL,NULL,NULL);


    l_item_lines_rec := xxqp_pricereq_lines_rec_type(1,'',p_item_id,NULL,'',1,'','','',NULL,'',
             '', '', '', '', '', '', '', '', '', '', '', '', NULL, NULL);

    p_order_header := xxqp_pricereq_header_tab_type(l_order_header_rec);
    p_item_lines   := xxqp_pricereq_lines_tab_type(l_item_lines_rec);

    xxqp_request_price_pkg.price_request(p_order_header       => p_order_header,
                                         p_item_lines         => p_item_lines,
                                         p_custom_attributes  => NULL,
                                         p_pricing_phase      => 'LINE',
                                         p_debug_flag         => 'N',
                                         p_pricing_server     => 'FAILOVER',
                                         p_request_source     => 'STRATAFORCE',
                                         x_session_details    => l_session_details,
                                         x_order_details      => l_order_details,
                                         x_line_details       => l_line_details,
                                         x_modifier_details   => l_modifier_details,
                                         x_attribute_details  => l_attribute_details,
                                         x_related_adjustment => l_related_adjustment,
                                         x_status             => l_status,
                                         x_status_message     => l_status_message);

    IF l_status = 'SP01' THEN
      i := l_line_details.first;

      IF i IS NOT NULL THEN
        LOOP

          IF l_line_details(i).unit_sales_price IS NOT NULL AND l_line_details(i).line_num = 1 THEN
            l_item_price := l_line_details(i).unit_sales_price;
            l_item_uom := l_line_details(i).priced_uom;
            EXIT;
          END IF;
          EXIT WHEN i = l_line_details.last;
          i := l_line_details.next(i);
        END LOOP;
      END IF;

      DELETE FROM xx_qp_pricereq_session
      WHERE  request_number = l_price_request_id;
      
      COMMIT;
      
      x_list_price := l_item_price;
      x_item_uom   := l_item_uom;
      x_status     := 'S';
    ELSE
      x_status     := 'E';
      x_status_msg := 'PRICING ERROR: '||l_status_message;
    END IF;
  
  Exception when others then
    x_status := 'E';
    x_status_msg := 'UNEXPECTED ERROR: '||sqlerrm;
  END;
  
  
  
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0043433
  --          This Procedure is used to generate prices of relevant items for a formula based PL
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  13/07/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE populate_pl_formula_events(errbuf  OUT VARCHAR2,
                                       retcode OUT NUMBER,
                                       p_target_name IN varchar2,
                                       p_list_header_id IN NUMBER) is

    l_list_price  number;
    l_priced_uom  varchar2(20);
    l_currency_code varchar2(10);
    l_entity_name           VARCHAR2(20) := 'PRICE_LINE_FORMULA';


    l_program_name varchar2(1000);
    l_user_id number;
    l_active_flag varchar2(100);

    l_last_event_id  number;
    l_last_price varchar2(100);
    l_last_active_flag varchar2(100);

    l_pl_item_list XXINV_PRODUCT_TAB_TYPE := XXINV_PRODUCT_TAB_TYPE();
    
    l_price_status   varchar2(1);
    l_price_message  varchar2(4000);
    
    l_is_error       varchar2(1) := 'N';
    
    l_exception_message varchar2(4000);
    e_exception exception;
  BEGIN
    fnd_file.PUT_LINE(fnd_file.OUTPUT,'INPUT: Price List ID: '||p_list_header_id);
    fnd_file.PUT_LINE(fnd_file.OUTPUT,'INPUT: Target Name: '||p_target_name);
    
    begin
      -- Determine currency code from price list
      select qlh.CURRENCY_CODE
        into l_currency_code
        from qp_list_headers_all qlh
       where list_header_id = p_list_header_id;

      -- fetch Session user ID
      l_user_id := fnd_global.USER_ID;

      -- Fetch concurrent program name which will be used as event_name while inserting events
      select fcp.CONCURRENT_PROGRAM_NAME||'(CONC_REQ_ID:'||fnd_global.CONC_REQUEST_ID||')'
        into l_program_name
        from fnd_concurrent_programs_vl fcp
       where fcp.CONCURRENT_PROGRAM_ID = fnd_global.CONC_PROGRAM_ID;
    exception when others then
      l_exception_message := 'UNEXPECTED ERROR: While deriving default values for event generation. '||sqlerrm;
      raise e_exception;
    end;
    
    begin
      -- We will fetch the list of valid items in a table of record type
      -- Because we will need this type while determining items to be disabled
      -- And this is a time costly query
      select xxinv_product_rec_type(null,aa.inventory_item_id,aa.item_code,
                                    null,aa.uom_code,null,null,null,null,null,null,null,null,
                                    null,null,null,null,null,null,null,null,null,null,
                                    null,null,null,null,null,null,null,null,null,null,
                                    null,null,null,null)
        bulk collect into l_pl_item_list
        from
      (select to_char(msib.inventory_item_id) inventory_item_id, msib.segment1 item_code, msib.primary_uom_code uom_code
        from mtl_system_items_b msib
       where msib.organization_id = xxinv_utils_pkg.get_master_organization_id
         and xxinv_utils_pkg.get_category_segment(p_segment_name => 'SEGMENT1',
                                                  p_category_set_id => 1100000221,
                                                  p_inventory_item_id => msib.inventory_item_id) = 'Customer Support'
         and msib.enabled_flag = 'Y'
         and trunc(sysdate) between nvl(msib.start_date_active,sysdate-1) and nvl(msib.end_date_active,sysdate+1)
         and msib.primary_uom_code in (select qll.product_uom_code
                                        from qp_list_lines_v qll
                                       where qll.list_header_id = p_list_header_id
                                         and qll.product_attribute = 'PRICING_ATTRIBUTE3'
                                         and qll.product_attribute_context = 'ITEM'
                                         and qll.product_attr_value = 'ALL'
                                         and trunc(sysdate) between nvl(qll.start_date_active,sysdate-1) and nvl(qll.end_date_active,sysdate+1))
      union
      select qll.product_id inventory_item_id, qll.product_attr_val_disp item_code, qll.product_uom_code uom_code
        from qp_list_lines_v qll
       where qll.list_header_id = p_list_header_id
         and qll.product_attribute = 'PRICING_ATTRIBUTE1'
         and qll.product_attribute_context = 'ITEM'
         and trunc(sysdate) between nvl(qll.start_date_active,sysdate-1) and nvl(qll.end_date_active,sysdate+1)) aa
       /*where rownum < 1000*/;
    
    exception when others then
      l_exception_message := 'UNEXPECTED ERROR: While generating item list for pricing. '||sqlerrm;
      raise e_exception;
    end;
    
    fnd_file.PUT_LINE(fnd_file.OUTPUT, 'Items count considered for price generation: '||l_pl_item_list.count);
    
    -- Start code for inserting events for all valid items as per list fetched above
    for i in 1..l_pl_item_list.count loop
      begin
        l_active_flag := 'Y';
        l_last_active_flag := null;
        
        call_price_api(p_item_id        => l_pl_item_list(i).inventory_item_id,
                       p_price_list_id  => p_list_header_id,
                       x_list_price     => l_list_price,
                       x_item_uom       => l_priced_uom,
                       x_status         => l_price_status,
                       x_status_msg     => l_price_message);
        
        
        if l_price_status = 'E' then
          l_exception_message := 'ERROR: Exiting program. Exception while calculating price for item ID: '||l_pl_item_list(i).inventory_item_id||' and pricelist '||p_list_header_id ||'. '||l_price_message;

          fnd_file.PUT_LINE(fnd_file.LOG,l_exception_message);
          l_is_error := 'Y';
          
          continue;
        end if;
        
        -- If the price of the item is 0 then no event should be raised.
        -- But if the item was interfaced earlier in active state then we will insert event in inactive status
        begin
          select xe.event_id,xe.active_flag,xe.attribute7
            into l_last_event_id, l_last_active_flag, l_last_price
            from (SELECT xe1.event_id,xe1.active_flag,xe1.attribute7,
             rank() over(PARTITION BY xe1.entity_id,
                                      xe1.attribute1,
                                      xe1.attribute5,
                                      xe1.attribute8,
                                      xe1.entity_name,
                                      xe1.target_name ORDER BY xe1.event_id DESC) rn
            FROM   xxssys_events xe1
            WHERE  xe1.entity_id = p_list_header_id
            AND    xe1.entity_name = l_entity_name
            AND    xe1.target_name = p_target_name
            AND    xe1.status = 'SUCCESS'
            AND    xe1.attribute1 = l_pl_item_list(i).inventory_item_id
            AND    xe1.attribute5 = l_currency_code
            AND    xe1.attribute8 = l_priced_uom) xe
           where xe.rn = 1;
        exception when no_data_found then
          l_last_active_flag := 'X';
        end;
          
        -- If last interfaced event with Inactive flag or last interfaced event not found
        if l_last_active_flag in ('N','X') then
          /*if l_list_price = 0 then  -- List price calculated as 0 so no event needed
            continue;
          else  -- List price is non-0 so insert event as active
            l_active_flag := 'Y';
          end if;*/
          l_active_flag := 'Y';
          
        elsif l_last_active_flag = 'Y' then  -- Last interfaced event with Active flag
          /*if l_list_price = 0 then -- List price calculated as 0 so insert event as inactive
            l_active_flag := 'N';
          else  -- List price is non-0*/
            if l_last_price = l_list_price then  -- New calculated price is same as last successfully interfaced price no event needed
              continue;
            else  -- new price is different than last interfaced price so insert event as active
              l_active_flag := 'Y';
            end if;
          --end if;
        end if;

        -- Insert Formula based PL line event
        insert_formula_pl_line_event(p_target_name         => p_target_name,
                                     p_entity_name         => l_entity_name,
                                     p_inventory_item_id   => l_pl_item_list(i).inventory_item_id,
                                     p_list_header_id      => p_list_header_id,
                                     p_list_price          => l_list_price,
                                     p_item_code           => l_pl_item_list(i).segment1,
                                     p_item_uom_code       => l_pl_item_list(i).PRIMARY_UNIT_OF_MEASURE,
                                     p_currency_code       => l_currency_code,
                                     p_status              => l_active_flag,
                                     p_user_id             => l_user_id,
                                     p_event_name          => l_program_name);

      exception when others then
        l_exception_message := 'UNEXPECTED ERROR: While generating event for item ID: '||l_pl_item_list(i).inventory_item_id||chr(13)||chr(10)||' '||sqlerrm;
        l_is_error := 'Y';
        
        fnd_file.PUT_LINE(fnd_file.LOG,l_exception_message);
      end;
    end loop;
    
    -- Start code for disabling item prices which existed before but are no longer
    -- valid for interfacing
    for rec_exist_items in (
              select xe.attribute1 inventory_item_id,xe.attribute4 segment1, xe.attribute8 uom_code
                from (SELECT xe1.attribute1,xe1.attribute4,xe1.attribute8,
                             rank() over(PARTITION BY xe1.entity_id,
                                                      xe1.entity_name,
                                                      xe1.target_name ORDER BY xe1.event_id DESC) rn
                        FROM xxssys_events xe1
                       WHERE xe1.entity_id = p_list_header_id
                         AND xe1.entity_name = l_entity_name
                         AND xe1.target_name = p_target_name
                         AND xe1.status = 'SUCCESS'
                         AND xe1.active_flag = 'Y') xe
               where xe.rn = 1
               minus
               SELECT to_char(t1.inventory_item_id),t1.segment1,t1.PRIMARY_UNIT_OF_MEASURE uom_code
                 FROM TABLE(CAST(l_pl_item_list AS
                     XXINV_PRODUCT_TAB_TYPE)) t1) loop
      
      begin
        fnd_file.PUT_LINE(fnd_file.OUTPUT,'Existing item to be removed from pricelist: Item ID: '||rec_exist_items.inventory_item_id);

        insert_formula_pl_line_event(p_target_name         => p_target_name,
                                     p_entity_name         => l_entity_name,
                                     p_inventory_item_id   => rec_exist_items.inventory_item_id,
                                     p_list_header_id      => p_list_header_id,
                                     p_list_price          => 0,
                                     p_item_code           => rec_exist_items.segment1,
                                     p_item_uom_code       => rec_exist_items.uom_code,
                                     p_currency_code       => l_currency_code,
                                     p_status              => 'N',
                                     p_user_id             => l_user_id,
                                     p_event_name          => l_program_name);
      exception when others then
        l_exception_message := 'UNEXPECTED ERROR: While generating event for removal of item ID: '||rec_exist_items.inventory_item_id||chr(13)||chr(10)||' '||sqlerrm;
        l_is_error := 'Y';
        
        fnd_file.PUT_LINE(fnd_file.LOG,l_exception_message);
      end;
    end loop;
    
    if l_is_error = 'N' then
      commit;
    else
      rollback;
    end if;
    
    retcode := 0;
  EXCEPTION when e_exception then
    retcode := 2;
    errbuf := l_exception_message;
    fnd_file.PUT_LINE(fnd_file.LOG, l_exception_message);
  when others then
    retcode := 2;
    errbuf := substr(sqlerrm,4000,1);
    fnd_file.PUT_LINE(fnd_file.LOG, sqlerrm);
  END populate_pl_formula_events;

END XXQP_PL_FORMULA_SYNC_PKG;
/
