create or replace package body xxinv_soa_onhand_pkg AS
  ----------------------------------------------------------------------------
  --  name:            xxinv_realtime_interfaces_pkg
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   10/26/2017
  ----------------------------------------------------------------------------
  --  purpose :        CHG0041332 - This is a generic package which will be used for
  --                   all future Inventory related realtime interfaces to/from Oracle
  --                   to downstream systems
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  10/26/2017  Diptasurjya Chatterjee(TCS)  CHG0041332 - Initial build
  --  1.1  14-May-2018 Lingaraj (TCS)               CHG0042879 - Inventory Check From Sales Force to Oracle
  --  1.2  01-Aug-2018 Lingaraj                     CHG0042879[CTASK0037719] - New parameter to the interface, 
  --                                                add car stock and filter main warehouses per region
  ----------------------------------------------------------------------------

  g_log              VARCHAR2(1) := fnd_profile.VALUE('AFLOG_ENABLED');
  g_log_module       VARCHAR2(100) := fnd_profile.VALUE('AFLOG_MODULE');
  g_api_name         VARCHAR2(30) := 'xxinv_soa_onhand_pkg';
  g_log_program_unit VARCHAR2(100);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name            Description
  -- 1.0  10/26/2017  Diptasurjya     CHG0041332 - Initial build
  --                  Chatterjee
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE write_log(p_msg VARCHAR2) IS
    l_log varchar2(1);
  BEGIN        
    IF g_log = 'Y' THEN
      fnd_log.string(log_level => fnd_log.level_unexpected,
                     module => g_api_name||
                                g_log_program_unit,
                     message => p_msg);
    END IF;
    --dbms_output.put_line(p_msg);
  END write_log;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041332 - This Procedure validates the onahnd request input data. It populates all
  --          derived fields into the type structure
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/26/2017  Diptasurjya Chatterjee (TCS)    CHG0041332 - Initial build
  -- 1.1  14-May-2018 Lingaraj (TCS)                  CHG0042879 - Inventory Check From Sales Force to Oracle
  --                                                  #In Case of STRATAFOCE the Organization Code will send on the Organization Name Field
  -- --------------------------------------------------------------------------------------------
  procedure validate_onhand_input(p_onhand_details IN OUT xxobjt.xxinv_onhand_tab_type,
                                  x_status OUT varchar2,
                                  x_status_message OUT varchar2) IS
    l_validation_status varchar2(1) := 'S';
    l_validation_message varchar2(2000);

    l_item_id     number;
    l_ou_id       number;
    l_inv_org_id  number;
    l_subinv_code varchar2(10);
  begin

    for i in 1..p_onhand_details.count loop
      l_item_id := null;
      l_ou_id := null;
      l_inv_org_id := null;
      l_subinv_code := null;

      l_validation_status := 'S';
      l_validation_message := null;

      -- Item validation
      if p_onhand_details(i).item_code is null and p_onhand_details(i).inventory_item_id is null then
        l_validation_status := 'E';
        l_validation_message := l_validation_message||'VALIDATION ERROR: Either Item code or Item ID is mandatory'||chr(13);
      else
        begin
          select msib.inventory_item_id
            into l_item_id
            from mtl_system_items_b msib
           where msib.segment1 = nvl(p_onhand_details(i).item_code, msib.segment1)
             and msib.inventory_item_id = nvl(p_onhand_details(i).inventory_item_id, msib.inventory_item_id)
             and msib.organization_id = xxinv_utils_pkg.get_master_organization_id;

          if p_onhand_details(i).inventory_item_id is null then
            p_onhand_details(i).inventory_item_id := l_item_id;
          end if;
        exception when no_data_found then
          l_validation_status := 'E';
          l_validation_message := l_validation_message||'VALIDATION ERROR: Item code or Item ID is not valid'||chr(13);
        end;
      end if;

      -- Operating Unit validation
      if p_onhand_details(i).ou_name is not null or p_onhand_details(i).org_id is not null then
        begin
          select hou.organization_id
            into l_ou_id
            from hr_operating_units hou
           where hou.name = nvl(p_onhand_details(i).ou_name, hou.name)
             and hou.organization_id = nvl(p_onhand_details(i).org_id, hou.organization_id);

          if p_onhand_details(i).org_id is null then
            p_onhand_details(i).org_id := l_ou_id;
          end if;
        exception when no_data_found then
          l_validation_status := 'E';
          l_validation_message := l_validation_message||'VALIDATION ERROR: Operating Unit Name or Operating Unit Org ID is not valid'||chr(13);
        end;
      end if;

      -- Inventory Organization validation
      if p_onhand_details(i).organization_name is not null or p_onhand_details(i).organization_id is not null then
        begin
          select ood.organization_id, ood.OPERATING_UNIT
            into l_inv_org_id, l_ou_id
            from org_organization_definitions ood
           where (
                   ood.ORGANIZATION_NAME = nvl(p_onhand_details(i).organization_name, ood.ORGANIZATION_NAME)
                    OR
                   --CHG0042879# OR Condition Added
                   ood.ORGANIZATION_CODE = nvl(p_onhand_details(i).organization_name, ood.ORGANIZATION_CODE)
                 )
             and ood.organization_id = nvl(p_onhand_details(i).organization_id, ood.organization_id);

          if p_onhand_details(i).organization_id is null then
            p_onhand_details(i).organization_id := l_inv_org_id;
          end if;

          if p_onhand_details(i).org_id is null then
            p_onhand_details(i).org_id := l_ou_id;
          end if;
        exception when no_data_found then
          l_validation_status := 'E';
          l_validation_message := l_validation_message||'VALIDATION ERROR: Inventory organization Name or Inventory Organization ID is not valid'||chr(13);
        end;
      end if;

      -- Operating Unit or Inventory Organization must be provided
      if p_onhand_details(i).org_id is null and p_onhand_details(i).organization_id is null then
        l_validation_status := 'E';
        l_validation_message := l_validation_message||'VALIDATION ERROR: Either Operating Unit or Inventory Organization is mandatory'||chr(13);
      end if;

      -- If Subinventory is provided Inventory Organization is mandatory
      if p_onhand_details(i).organization_id is null and p_onhand_details(i).subinventory_code is not null then
        l_validation_status := 'E';
        l_validation_message := l_validation_message||'VALIDATION ERROR: Inventory Organization is mandatory if Subinventory is provided'||chr(13);
      end if;

      -- Sub-Inventory validation
      if p_onhand_details(i).subinventory_code is not null and p_onhand_details(i).organization_id is not null then
        begin
          select msi.secondary_inventory_name
            into l_subinv_code
            from mtl_secondary_inventories msi
           where msi.secondary_inventory_name = p_onhand_details(i).subinventory_code
             and msi.organization_id = p_onhand_details(i).organization_id;

        exception when no_data_found then
          l_validation_status := 'E';
          l_validation_message := l_validation_message||'VALIDATION ERROR: Subinventory code is not valid'||chr(13);
        end;
      end if;

      p_onhand_details(i).status := l_validation_status;
      p_onhand_details(i).error_message := l_validation_message;
    end loop;
    x_status := 'S';
  exception when others then
    x_status := 'E';
    x_status_message := 'VALIDATION ERROR: '||sqlerrm;
  end validate_onhand_input;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042879 - This Procedure fetched the Related Item details depend on the
  --                       Relation Type (like Substitute)
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                Description
  -- 1.0  17/05/2018   Lingaraj            CHG0042879 - Inventory check - from salesforce to Oracle
  -- --------------------------------------------------------------------------------------------
  PROCEDURE get_related_item(p_item_code        IN VARCHAR2 DEFAULT NULL,
                            p_related_item_code IN VARCHAR2 DEFAULT NULL,
                            p_relation_type     IN VARCHAR2,

                            x_related_item_id   OUT NUMBER,
                            x_related_item_code OUT VARCHAR2,
                            x_related_item_desc OUT VARCHAR2,
                            x_parent_item_id    OUT NUMBER,
                            x_parent_item_code  OUT VARCHAR2,
                            x_parent_item_desc  OUT VARCHAR2
                            )
  IS
  BEGIN

    SELECT msib_related.inventory_item_id,
           msib_related.segment1,
           msib_related.description,
           --
           msib.inventory_item_id,
           msib.segment1,
           msib.description

    INTO   x_related_item_id,x_related_item_code,x_related_item_desc,
           x_parent_item_id, x_parent_item_code,x_parent_item_desc

    FROM   mtl_related_items  mri,
           fnd_lookup_values  flv,
           mtl_system_items_b msib,
           mtl_system_items_b msib_related
    WHERE  (mri.end_date IS NULL OR mri.end_date > SYSDATE)
    AND    flv.lookup_type = 'MTL_RELATIONSHIP_TYPES'
    AND    flv.language    = 'US'
    AND    flv.lookup_code = mri.relationship_type_id
    AND    msib.organization_id  = mri.organization_id
    AND    mri.inventory_item_id = msib.inventory_item_id
    AND    msib_related.organization_id = mri.organization_id
    AND    mri.related_item_id = msib_related.inventory_item_id
    AND    msib_related.segment1 = nvl(p_related_item_code,msib_related.segment1)
    AND    msib.segment1       = nvl(p_item_code ,msib.segment1)
    AND    flv.meaning         = p_relation_type
    AND    mri.organization_id = 91
    AND    rownum = 1;

  EXCEPTION
    WHEN no_data_found THEN
      x_related_item_id   := null;
      x_related_item_code := null;
      x_related_item_desc := null;
      x_parent_item_id    := null;
      x_parent_item_code  := null;
      x_parent_item_desc  := null;
  END get_related_item;  
  
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042879 - This Procedure have all the logic to fetch the onhand details of a product  
  --                       for Source = STRATAFORCE
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                Description  
  -- 1.0  01-Aug-2018  Lingaraj            CHG0042879[CTASK0037719] - New parameter to the interface,
  --                                       add car stock and filter main warehouses per region 
  -- --------------------------------------------------------------------------------------------
  Function get_product_message(p_inventory_item_id NUMBER) return VARCHAR2
  is  
   l_product_msg  fnd_documents_short_text.short_text%type;
  Begin
            SELECT  DISTINCT FDST.SHORT_TEXT 
                    into l_product_msg
            FROM   
                   fnd_document_categories_tl fdct,
                   fnd_documents_tl           fdt,
                   fnd_attached_documents     fad,
                   fnd_documents_short_text   fdst,
                   fnd_documents              fd
            WHERE   fad.pk2_value = p_inventory_item_id -- Parameter
            --fad.pk2_value(+) = p_inventory_item_id -- Parameter
            AND    fdct.user_name  = 'Product Messages'
            AND    fad.entity_name = 'MTL_SYSTEM_ITEMS'
            AND    fdct.LANGUAGE   = fdt.LANGUAGE 
            AND    fdt.LANGUAGE    = 'US'
            AND    fad.document_id = fd.document_id
            AND    fd.document_id  = fdt.document_id
            AND    fd.category_id  = fdct.category_id
            AND    fd.media_id     = fdst.media_id
            --AND    fd.category_id IN 
            --       (SELECT fdct.category_id FROM fnd_document_categories_tl fdct)            
            AND ROWNUM = 1;
        
    return l_product_msg;      
  Exception
  When no_data_found Then        
    Return '';
  End get_product_message;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042879 - This Procedure have all the logic to fetch the onhand details of a product
  --                       for Source = STRATAFORCE
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                Description
  -- 1.0  17/05/2018   Lingaraj            CHG0042879 - Inventory check - from salesforce to Oracle
  -- 1.2  01-Aug-2018 Lingaraj             CHG0042879[CTASK0037719] - New parameter to the interface, 
  --                                       add car stock and filter main warehouses per region
  -- --------------------------------------------------------------------------------------------
  Procedure strataforce_onhand_request(p_onhand_details      IN OUT xxobjt.xxinv_onhand_tab_type,
                                       p_global_availibility IN VARCHAR2,                 --#Values Permitted Yes or No
                                       p_car_stock_availability IN VARCHAR2 DEFAULT 'No', --#CTASK0037719 Values Permitted Yes or No
                                       p_source_system       IN VARCHAR2,
                                       p_onhand_type         IN VARCHAR2
                                       )
  is
   --Get all the Inv Organization where Subinventory's Attribute11 = Y
   cursor c_dist_inv_org ( p_organization_id number )
   is
     select  ood.organization_id , ood.organization_code,ood.operating_unit
        from org_organization_definitions ood
        where   
            ( p_global_availibility = 'No'  
             and ood.organization_id = p_organization_id)
            OR
            (p_global_availibility = 'Yes' 
              and ood.organization_id in
             (Select  allowed_warehouse_id from 
                     (
                              select '1' q,
                                     mp.organization_code  warehouse_location,
                                     mp.organization_code allowed_warehouse,
                                     mp.organization_id allowed_warehouse_id                                     
                              from mtl_parameters mp 
                              where exists ( select 1
                                             from mtl_subinventories_all_v ms
                                             where ms.organization_id = mp.organization_id
                                             and ms.attribute11 = 'Y'  
                                             and NVL(DISABLE_DATE,(sysdate + 1)) > sysdate
                                           )
                              and mp.organization_id  = p_organization_id     
                              union               
                              select '2' q,
                                    mp.organization_code,
                                    msn.to_organization_code,
                                    msn.to_organization_id 
                              from hr_organization_units hou,
                                    mtl_parameters mp ,
                                    mtl_shipping_network_view msn
                              where mp.organization_id = hou.organization_id
                              and   mp.organization_id  = msn.from_organization_id
                              and   mp.organization_id  =     p_organization_id
                              and   exists ( select 1
                                             from mtl_subinventories_all_v ms
                                             where ms.organization_id = mp.organization_id
                                             and   ms.attribute11 = 'Y'
                                            )
                              and   exists ( select 1
                                             from mtl_subinventories_all_v ms
                                             where ms.organization_id = msn.to_organization_id
                                             and   ms.attribute11 = 'Y'
                                            ) 
                         ) 
                     ) 
                  );

   --Below query will fetch all the Inv Org , Sub Inv and Item (Item Assigned to Inv Orgs and Sub Inv attr11 = Y)
   cursor c_onhand_qry (p_inventory_item_id NUMBER,p_organization_id number )
   is
     select msib.inventory_item_id, ood.organization_id,ood.organization_code,
            ood.operating_unit, msi.secondary_inventory_name,
            msib.inventory_item_status_code item_status_code

      from org_organization_definitions ood,
           mtl_secondary_inventories msi,
           mtl_system_items_b msib
     where msib.organization_id = ood.organization_id
       and ood.organization_id  = msi.organization_id
       and msi.attribute11      = 'Y'
       and msib.inventory_item_id = p_inventory_item_id  --Parameter
       and ood.organization_id    = p_organization_id  --Parameter
       and nvl(msi.disable_date,trunc(sysdate)) >= trunc(sysdate);
   
   --#CTASK0037719 CAR subinventory
   cursor c_car_subinv ( p_organization_id number , p_inventory_item_id number)
   is
    select msib.inventory_item_id, ood.organization_id,ood.organization_code,
            ood.operating_unit, msi.secondary_inventory_name,
            msib.inventory_item_status_code item_status_code                        
      from org_organization_definitions ood,
           mtl_secondary_inventories msi,
           mtl_system_items_b msib               
     where msib.organization_id = ood.organization_id
       and ood.organization_id  = msi.organization_id
       and msi.secondary_inventory_name like '%CAR'
       and msib.inventory_item_id = p_inventory_item_id  --Parameter       
       and ood.organization_id    = p_organization_id    --Parameter                                
       and nvl(msi.disable_date,trunc(sysdate)) >= trunc(sysdate);

   l_onhand_details_in   xxobjt.xxinv_onhand_tab_type := xxobjt.xxinv_onhand_tab_type();
   l_onhand_details_out  xxobjt.xxinv_onhand_tab_type := xxobjt.xxinv_onhand_tab_type();
   l_onhand_details_t    xxobjt.xxinv_onhand_tab_type := xxobjt.xxinv_onhand_tab_type();

   l_reservable_quantity number := 0; 
   l_sub_qty             number := 0;
   l_rec_cnt             number := 0;  
   l_rec_cnt_t           number := 0;
   l_item_status_code    varchar2(15) := '';
   l_related_item_desc   varchar2(500);
   l_related_item_id     number;
   l_related_item_code   varchar2(240);
   l_parent_item_id      number;
   l_parent_item_code    varchar2(240);
   l_parent_item_desc    varchar2(500);
   l_attribute1          varchar2(4000);   
  begin
    l_onhand_details_in := p_onhand_details;
    write_log('Source System :'||p_source_system);
    write_log('global_availibility :'||p_global_availibility);

    -- For Loop 1 # No Of Item OnHand Request
    FOR i IN 1 .. l_onhand_details_in.count LOOP
      
      If l_onhand_details_in(i).status = 'S' then
        
         --For Loop 2 # Distinct Organization Code , with Search Org Name on Top
         For rec_dist_inv_org in c_dist_inv_org(l_onhand_details_in(i).organization_id)
         Loop
              l_reservable_quantity := 0; 
              l_sub_qty           := 0;  
              l_rec_cnt_t         := 0;            
              l_related_item_desc := null;
              l_related_item_id   := null;
              l_related_item_code := null;
              l_parent_item_id    := null;
              l_parent_item_code  := null;
              l_parent_item_desc  := null;
              l_attribute1        := null;
              l_item_status_code  := null; 
              l_onhand_details_t :=  xxobjt.xxinv_onhand_tab_type();
            
            --Begin CHG0042879[CTASK0037719] Get the CAR Stock
            If  p_car_stock_availability = 'Yes' 
              and l_onhand_details_in(i).organization_id = rec_dist_inv_org.organization_id  
            Then
                
                For car_rec in c_car_subinv(l_onhand_details_in(i).organization_id ,
                                            l_onhand_details_in(i).inventory_item_id ) Loop 
                    
                    l_reservable_quantity :=
                    xxinv_utils_pkg.get_avail_to_reserve(p_inventory_item_id => l_onhand_details_in(i).inventory_item_id,
                                                         p_organization_id   => car_rec.organization_id,
                                                         p_subinventory      => car_rec.secondary_inventory_name);
                    
                  If l_reservable_quantity > 0 Then 
                    l_rec_cnt := l_rec_cnt+1;                              
                    l_onhand_details_out.extend();
                    l_onhand_details_out(l_rec_cnt) := l_onhand_details_in(i);
                    l_onhand_details_out(l_rec_cnt).reservable_quantity := l_reservable_quantity;
                    l_onhand_details_out(l_rec_cnt).organization_name   := car_rec.organization_code;
                    l_onhand_details_out(l_rec_cnt).organization_id     := car_rec.organization_id;    
                    l_onhand_details_out(l_rec_cnt).org_id              := car_rec.operating_unit; 
                    l_onhand_details_out(l_rec_cnt).subinventory_code   := car_rec.secondary_inventory_name;             
                    l_onhand_details_out(l_rec_cnt).attribute2          := i;-- Original Record Index       
                  End if;                                
                End Loop;
            End If;                                                  
            --End CHG0042879[CTASK0037719] Get the CAR Stock
             write_log('Loop 3 : Organization ID :'||rec_dist_inv_org.organization_id);
             write_log('Loop 3 :INV Organization ID :'||l_onhand_details_in(i).organization_id);
             write_log('Loop 3 :INV ID :'||l_onhand_details_in(i).inventory_item_id);
            --For Loop 3 # Query all the Subinventories for a Specific Organization Name
            for rec in c_onhand_qry (l_onhand_details_in(i).inventory_item_id,
                                     rec_dist_inv_org.organization_id
                                     )
            Loop
                  l_sub_qty := xxinv_utils_pkg.get_avail_to_reserve(p_inventory_item_id => rec.inventory_item_id,
                                                                    p_organization_id   => rec.organization_id,
                                                                    p_subinventory      =>  rec.secondary_inventory_name);
                

                  l_reservable_quantity :=  l_reservable_quantity + l_sub_qty ;

               write_log('reservable_quantity  :'||l_reservable_quantity ||
                           ' for Subinventory :'||rec.secondary_inventory_name ||
                           ' and Organization Id '|| rec.organization_id);
               l_reservable_quantity := nvl(l_reservable_quantity,0);

               If p_global_availibility = 'No'
                  OR
                  ( p_global_availibility = 'Yes'--Global Yes and Requested Inv Org
                   and l_onhand_details_in(i).organization_id = rec_dist_inv_org.organization_id
                  )
                  OR
                  (p_global_availibility = 'Yes'--Global Yes and not Requested Inv Org and Qty > 0
                   and l_sub_qty > 0
                   and l_onhand_details_in(i).organization_id != rec_dist_inv_org.organization_id
                  )
               Then 
                  write_log('Record Inserted.')     ;
                  --At the End Of Each Inventory Organization Onhand Qry  Populate Records
                  l_rec_cnt_t := l_rec_cnt_t+1;
                  l_onhand_details_t.extend();
                  l_onhand_details_t(l_rec_cnt_t) := l_onhand_details_in(i);
                  l_onhand_details_t(l_rec_cnt_t).reservable_quantity := l_sub_qty;
                  l_onhand_details_t(l_rec_cnt_t).organization_name   := rec_dist_inv_org.organization_code;
                  l_onhand_details_t(l_rec_cnt_t).organization_id     := rec_dist_inv_org.organization_id;
                  l_onhand_details_t(l_rec_cnt_t).org_id              := rec_dist_inv_org.operating_unit; 
                  l_onhand_details_t(l_rec_cnt_t).subinventory_code   := rec.secondary_inventory_name;
                  l_onhand_details_t(l_rec_cnt_t).attribute2 := i;-- Original Record Index
               End If;
               
              l_item_status_code := rec.item_status_code;
            End Loop; --# Get the Summation of Reservable qty
           --For Requested Inv Organization Only
           If l_onhand_details_in(i).organization_id = rec_dist_inv_org.organization_id Then

              --Extra Conditions For Comments
              If l_reservable_quantity = 0 Then
                 /*--Comment Condition = 1
                   If the part number status is ‘Phase out’ and there is no available stock
                   on the required inventory organization and there is “substituted” item in
                   the item relation need to add the following message.
                 */

                 If  nvl(l_item_status_code,'-1') = 'XX_PHASOUT' Then

                     --Is Related Substitute item available ?
                     get_related_item( p_item_code         => l_onhand_details_in(i).item_code
                                      ,p_related_item_code =>  null
                                      ,p_relation_type     => 'Substitute'
                                      ---
                                      ,x_related_item_id   =>  l_related_item_id
                                      ,x_related_item_code =>  l_related_item_code
                                      ,x_related_item_desc =>  l_related_item_desc
                                      ,x_parent_item_id    =>  l_parent_item_id
                                      ,x_parent_item_code  =>  l_parent_item_code
                                      ,x_parent_item_desc  =>  l_parent_item_desc
                                      );

                     If l_related_item_code is not null Then
                         fnd_message.clear;
                         fnd_message.set_name ('XXOBJT', 'XXOBJT_OA2SF_ONHAND_QUERY_001');
                         fnd_message.set_token('PARENT_ITEM_CODE', l_parent_item_code);
                         fnd_message.set_token('RELATED_ITEM_CODE', l_related_item_code);
                         fnd_message.set_token('RELATED_ITEM_DESC', l_related_item_desc);

                        l_attribute1 :=  fnd_message.get;    
                        l_attribute1 := l_attribute1 || get_product_message(l_related_item_id);--#CTASK0037719
                        write_log('Message Condition = 1 Satisfied');

                     End If;
                 Else
                     /* Comment Condition = 2
                        there is no available stock for the product on the required inventory
                        organization and there
                         is “Superseded” item in the item relationship need to add the message.
                     */
                     --Is Related Superseded item available ?
                     get_related_item( p_item_code         => l_onhand_details_in(i).item_code
                                      ,p_related_item_code =>  null
                                      ,p_relation_type     => 'Superseded'
                                      ------
                                      ,x_related_item_id   =>  l_related_item_id
                                      ,x_related_item_code =>  l_related_item_code
                                      ,x_related_item_desc =>  l_related_item_desc
                                      ,x_parent_item_id    =>  l_parent_item_id
                                      ,x_parent_item_code  =>  l_parent_item_code
                                      ,x_parent_item_desc  =>  l_parent_item_desc
                                      );

                    If l_related_item_id is not null Then
                        fnd_message.clear;
                        fnd_message.set_name ('XXOBJT', 'XXOBJT_OA2SF_ONHAND_QUERY_002');
                        fnd_message.set_token('PARENT_ITEM_CODE', l_parent_item_code);
                        fnd_message.set_token('RELATED_ITEM_CODE', l_related_item_code);
                        fnd_message.set_token('RELATED_ITEM_DESC', l_related_item_desc);

                        l_attribute1 := fnd_message.get;      
                        l_attribute1 := l_attribute1 || get_product_message(l_parent_item_id);--#CTASK0037719
                         write_log('Message Condition = 2 Satisfied');

                    End If;
                 End If;

              Else
                /* Comment Condition 3
                  the required product is defined as substitute to other product and there is
                  available stock from the other product add the  message.
                */
                   get_related_item( p_item_code         =>  null
                                    ,p_related_item_code =>  l_onhand_details_in(i).item_code
                                    ,p_relation_type     => 'Substitute'
                                    -----
                                    ,x_related_item_id   =>  l_related_item_id
                                    ,x_related_item_code =>  l_related_item_code
                                    ,x_related_item_desc =>  l_related_item_desc
                                    ,x_parent_item_id    =>  l_parent_item_id
                                    ,x_parent_item_code  =>  l_parent_item_code
                                    ,x_parent_item_desc  =>  l_parent_item_desc
                                    );
                  If l_parent_item_id is not null Then
                    l_reservable_quantity := 0;

                        --Check if the Parent Item Having Onhand Stock
                       for rec in c_onhand_qry (l_parent_item_id,
                                                rec_dist_inv_org.organization_id
                                               )
                        Loop
                              l_reservable_quantity := l_reservable_quantity + xxinv_utils_pkg.get_avail_to_reserve(p_inventory_item_id => rec.inventory_item_id,
                                                                                                                    p_organization_id   => rec.organization_id,
                                                                                                                    p_subinventory      =>  rec.secondary_inventory_name);

                        End Loop; --# Get the Summation of Reservable qty

                    If   l_reservable_quantity > 0 Then

                        fnd_message.clear;
                        fnd_message.set_name ('XXOBJT', 'XXOBJT_OA2SF_ONHAND_QUERY_003');
                        fnd_message.set_token('PARENT_ITEM_CODE', l_parent_item_code);
                        fnd_message.set_token('PARENT_ITEM_DESC', l_parent_item_desc);
                        fnd_message.set_token('RELATED_ITEM_CODE',l_related_item_code);
                        fnd_message.set_token('RELATED_ITEM_DESC',l_related_item_desc);

                        l_attribute1 := fnd_message.get;  
                        l_attribute1 := l_attribute1 || get_product_message(l_parent_item_id);--#CTASK0037719
                         write_log('Message Condition = 3 Satisfied');

                    End If;

                  End If;
              End If;

           End If;   
           
            --Attribute1 Comment  
            For j in 1..l_onhand_details_t.count Loop
              If  nvl(l_onhand_details_t(j).reservable_quantity,0) = 0
                 and  l_attribute1 is null
              Then        
                  l_rec_cnt := l_rec_cnt + 1;
                  l_onhand_details_out.extend();
                  l_onhand_details_out(l_rec_cnt) := l_onhand_details_t(j);
                  l_onhand_details_out(l_rec_cnt).attribute1 := 'No Available stock';
              Else  
                  l_rec_cnt := l_rec_cnt + 1;
                  l_onhand_details_out.extend();
                  l_onhand_details_out(l_rec_cnt) := l_onhand_details_t(j);
                  l_onhand_details_out(l_rec_cnt).attribute1 := l_attribute1;
              End If;
            End Loop;  
              
            l_attribute1 := null;
         End Loop;  --#2nd For Loop , Distinct Inv Org

      Else
        --If Validation Failed onhand Item Record need to assigned to Output  with Error Details
        l_rec_cnt := l_rec_cnt+1;
        l_onhand_details_out.extend();
        l_onhand_details_out(l_rec_cnt) := l_onhand_details_in(i);
      end if;
    End Loop; --#1st For Loop , No of Records onhand Qry

    p_onhand_details := l_onhand_details_out;
  End strataforce_onhand_request;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041332 - This procedure will fetch ohand reservable and/or transactable quantity
  --          for given item/items at Operating Unit/Inventory Org/Subinventory level.
  --          Inputs:  p_onhand_details => Table type containing item ID and Operating Unit, Inventory Org, Subinventory
  --                                       information.
  --                   p_onhand_level   => Valid values - OU / INV / SUBINV if NULL then processed at level till which data is sent in input p_onhand_details
  --                   p_onhand_type    => Valid values - A - ALL / R - RESERVABLE / T - TRANSACTABLE If ALL both reservable and transactable quantities sent
  --                   p_source_ref_id  => Requesting system reference ID
  --                   p_soa_ref_id     => SOA BPEL instance ID
  --                   p_source_system  => Source system name
  --          Outputs: x_onhand_details => Table type containing item ID and Operating Unit, Inventory Org, Subinventory
  --                                       information along with the corresponding quantities
  --                   x_status         => Request status - Valid values S/E
  --                   x_status_message => Request status message
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/26/2017  Diptasurjya Chatterjee (TCS)    CHG0041332 - Initial Build
  -- 1.1  14-May-2018 Lingaraj (TCS)                  CHG0042879 - Inventory Check From Sales Force to Oracle
  --                                                  New Parameter Added [p_global_availibility] Values Permitted Y or N
  -- 1.2  01-Aug-2018 Lingaraj                        CHG0042879[CTASK0037719] - New parameter to the interface, 
  --                                                  add car stock and filter main warehouses per region
  -- --------------------------------------------------------------------------------------------

  PROCEDURE request_onhand_quantity(p_onhand_details     IN xxobjt.xxinv_onhand_tab_type,
                                    p_onhand_level       IN VARCHAR2 DEFAULT NULL,
                                    p_onhand_type        IN VARCHAR2 DEFAULT 'A',
                                    p_source_ref_id      IN NUMBER DEFAULT NULL,
                                    p_soa_ref_id         IN NUMBER,
                                    p_source_system      IN VARCHAR2,
                                    p_global_availibility IN VARCHAR2 DEFAULT 'No', -- Values Permitted Yes or No
                                    p_car_stock_availability IN VARCHAR2 DEFAULT 'No', --#CTASK0037719 Values Permitted Yes or No
                                    x_onhand_details     OUT xxobjt.xxinv_onhand_tab_type,
                                    x_status             OUT VARCHAR2,
                                    x_status_message     OUT VARCHAR2)
  IS
    l_reservable_quantity number := 0;
    l_transactable_quantity number := 0;

    l_source_system varchar2(150);

    l_onhand_details_in   xxobjt.xxinv_onhand_tab_type := xxobjt.xxinv_onhand_tab_type();

    l_validation_status  varchar2(1);
    l_validation_message  varchar2(2000);

    e_validation_error   exception;
  BEGIN
    g_log_program_unit := 'request_onhand_quantity';

    l_onhand_details_in := p_onhand_details;

    /* Start - Validate input values */
    if p_soa_ref_id is null then
      x_status := 'E';
      x_status_message := 'ERROR: SOA reference ID is mandatory'||chr(13);
      return;
    end if;

    if l_onhand_details_in is null or l_onhand_details_in.count = 0 then
      x_status := 'E';
      x_status_message := 'ERROR: At least 1 item is required for API to work'||chr(13);
    end if;

    write_log('1. '||l_onhand_details_in.count);

    validate_onhand_input(l_onhand_details_in,
                          l_validation_status,
                          l_validation_message);

    if l_validation_status = 'E' then
      x_status := 'E';
      x_status_message := 'ERROR: Unexpected error while validating input. Please contact system administrator. '||l_validation_message||chr(13);
    end if;

    if p_onhand_level is not null and p_onhand_level not in ('OU','INV','SUBINV') then
      x_status := 'E';
      x_status_message := 'ERROR: Parameter Onahand Level should be blank or have valid values: OU, INV or SUBINV'||chr(13);
    end if;

    if p_onhand_type not in ('A','R','T') then
      x_status := 'E';
      x_status_message := 'ERROR: Valid values for parameter Onahand Tytpe are: A, R or T'||chr(13);
    end if;

    if p_source_system is null then
      x_status := 'E';
      x_status_message := 'ERROR: Source system is mandatory'||chr(13);
    else
      begin
        select upper(ffv.flex_value)
          into l_source_system
          from fnd_flex_values_vl ffv, fnd_flex_value_sets ffvs
         where ffvs.flex_value_set_id = ffv.FLEX_VALUE_SET_ID
           and ffvs.flex_value_set_name = 'XXSSYS_EVENT_TARGET_NAME'
           and ffv.ENABLED_FLAG = 'Y'
           and upper(ffv.flex_value) = upper(p_source_system)
           and sysdate between nvl(ffv.START_DATE_ACTIVE, sysdate-1)
               and nvl(ffv.END_DATE_ACTIVE, sysdate+1);
      exception when no_data_found then
        x_status := 'E';
        x_status_message := 'ERROR: Source system is not valid'||chr(13);
      end;
    end if;

    if x_status = 'E' then
      write_log('SOA BPEL Instance ID: '||p_soa_ref_id||' :: '||x_status_message);
      return;
    end if;
    /* End - Validate input values */

    write_log('2. '||l_onhand_details_in.count||' '||l_validation_status);

  if l_source_system = 'HYBRIS' then --CHG0042879 # If Condition Added
    FOR i IN 1 .. l_onhand_details_in.count LOOP
      write_log('3. '||p_source_system||' '||l_onhand_details_in.count||' '||l_onhand_details_in(i).status);

      if l_onhand_details_in(i).status = 'S' then
        write_log('3.1 '||p_source_system||' '||l_onhand_details_in.count||' '||l_onhand_details_in(i).status);

        --if l_source_system = 'HYBRIS' then --CHG0042879 #Commented
          write_log('4. '||l_onhand_details_in(i).inventory_item_id||' '||l_onhand_details_in(i).org_id||' '||
                                nvl(l_onhand_details_in(i).organization_id,0)||' '||nvl(to_char(l_onhand_details_in(i).subinventory_code),'-'));

          for rec in (select msib.inventory_item_id, ood.ORGANIZATION_ID, ood.OPERATING_UNIT, msi.secondary_inventory_name
                        from org_organization_definitions ood,
                             mtl_secondary_inventories msi,
                             mtl_system_items_b msib
                       where msib.organization_id = ood.ORGANIZATION_ID
                         and ood.ORGANIZATION_ID = msi.organization_id
                         and msi.attribute11 = 'Y'
                         and msib.inventory_item_id = l_onhand_details_in(i).inventory_item_id
                         and ood.OPERATING_UNIT = l_onhand_details_in(i).org_id
                         and ood.ORGANIZATION_ID = nvl(l_onhand_details_in(i).organization_id, ood.ORGANIZATION_ID)
                         and msi.secondary_inventory_name = nvl(l_onhand_details_in(i).subinventory_code, msi.secondary_inventory_name)
                         and nvl(msi.disable_date,trunc(sysdate)) >= trunc(sysdate))
          loop
            write_log('5. '||p_onhand_type||' '||rec.inventory_item_id||' '|| rec.organization_id||' '|| rec.secondary_inventory_name);

            if p_onhand_type in ('A','R') then
              l_reservable_quantity := l_reservable_quantity + xxinv_utils_pkg.get_avail_to_reserve(p_inventory_item_id => rec.inventory_item_id,
                                                                                                    p_organization_id => rec.organization_id,
                                                                                                    p_subinventory =>  rec.secondary_inventory_name);
            end if;

            if p_onhand_type in ('A','T') then
              l_transactable_quantity := l_transactable_quantity + xxinv_utils_pkg.get_avail_to_transact(p_inventory_item_id => rec.inventory_item_id,
                                                                                                         p_organization_id => rec.organization_id,
                                                                                                         p_subinventory => rec.secondary_inventory_name);
            end if;

             write_log('5.1 '||l_reservable_quantity);
          end loop;
          write_log('6. ');
        --end if;

        l_onhand_details_in(i).reservable_quantity := l_reservable_quantity;
        l_onhand_details_in(i).transactable_quantity := l_transactable_quantity;
      end if;
    END LOOP;

    --CHG0042879 # STRATAFORCE condition added
  ElsIf l_source_system = 'STRATAFORCE' then
       strataforce_onhand_request(p_onhand_details      => l_onhand_details_in,
                                  p_global_availibility => p_global_availibility,
                                  p_car_stock_availability => p_car_stock_availability,
                                  p_source_system       => l_source_system,
                                  p_onhand_type         => p_onhand_type
                                  );
   End If;
    x_onhand_details := l_onhand_details_in;
    x_status := 'S';
  EXCEPTION
    WHEN OTHERS THEN
      x_onhand_details := null;
      x_status := 'E';
      x_status_message := 'UNEXPECTED ERROR: '||sqlerrm;
      write_log(x_status_message);
  END request_onhand_quantity;

END xxinv_soa_onhand_pkg;
/
