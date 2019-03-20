create or replace package body xxssys_strataforce_valid_pkg AS
  ----------------------------------------------------------------------------
  --  name:            xxssys_strataforce_valid_pkg
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   11/20/2017
  ----------------------------------------------------------------------------
  --  purpose :        CHG0041829 - Generic package to handle all entity validation
  --                                functions for new Salesforce platform
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  11/20/2017  Diptasurjya Chatterjee(TCS)  CHG0041829 - initial build
  --  1.1  23/05/2018  Lingaraj (TCS)               CHG0042874 - Field Service Usage interface from salesforce to Oracle
  --  1.2  31-Dec-2018 Lingaraj                     CHG0044757 - CTASK0039880
  --                                                events with  party type in 'ORGANIZATION' & 'PERSON'.
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name            Description
  -- 1.0  11/20/2017  Diptasurjya     Initial Creation for CHG0041829.
  --                  Chatterjee
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE write_log(p_msg VARCHAR2) IS
  BEGIN

    IF g_log = 'Y' AND 'xxssys.' || g_api_name || g_log_program_unit LIKE
       lower(g_log_module) THEN
      fnd_log.string(log_level => fnd_log.level_unexpected,
                     module    => 'xxssys.' || g_api_name ||
                                  g_log_program_unit,
                     message   => p_msg);
    END IF;
  END write_log;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function will be used to perform all required validation for items being interfaced
  --          to Strataforce
  -- --------------------------------------------------------------------------------------------
  -- Usage: DFF ATTRIBUTE2 for Valueset XXSSYS_EVENT_ENTITY_NAME against target STRATAFORCE
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee(TCS)   Initial Build
  -- --------------------------------------------------------------------------------------------
  function validate_item(P_OLD_ITEM_REC mtl_system_items_b%ROWTYPE,
                         P_NEW_ITEM_REC mtl_system_items_b%ROWTYPE)
    return varchar2 is
    l_organization_id number;

    l_valid varchar2(1) := 'Y';
  begin
    -- Validate organization
    l_organization_id := nvl(P_NEW_ITEM_REC.Organization_Id,
                             P_OLD_ITEM_REC.Organization_Id);

    if l_organization_id = xxinv_utils_pkg.get_master_organization_id then
      l_valid := 'Y';
    else
      return 'N';
    end if;

    -- Validate customer order enabed flag
    if P_NEW_ITEM_REC.Customer_Order_Enabled_Flag = 'Y' or
       (P_NEW_ITEM_REC.Customer_Order_Enabled_Flag = 'N' and
       P_OLD_ITEM_REC.Customer_Order_Enabled_Flag = 'Y') then
      l_valid := 'Y';
    else
      return 'N';
    end if;

    return l_valid;
  end validate_item;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function will be used to check if Customer account is transferrable to Strataforce
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee(TCS)   Initial Build
  -- 1.1  31-Dec-2018 Lingaraj                     CHG0044757 - CTASK0039880
  --                                                events with  party type in 'ORGANIZATION' & 'PERSON'.
  -- --------------------------------------------------------------------------------------------
  function is_account_sf_valid(p_cust_account_id number) return varchar2 is
    l_is_valid varchar2(1) := 'N';
  begin

    select 'Y'
      into l_is_valid
      from hz_cust_accounts hca, hz_parties p
     where hca.cust_account_id = p_cust_account_id
       and p.party_id = hca.party_id
       and p.party_type in ('ORGANIZATION','PERSON');--CHG0044757 - CTASK0039880
    return l_is_valid;
  exception
    when no_data_found then
      return 'N';
  end is_account_sf_valid;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function will be used to perform all required validation for Customer accounts
  --          being interfaced to Strataforce
  -- --------------------------------------------------------------------------------------------
  -- Usage: DFF ATTRIBUTE2 for Valueset XXSSYS_EVENT_ENTITY_NAME against target STRATAFORCE
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee(TCS)   Initial Build
  -- --------------------------------------------------------------------------------------------
  function validate_account(P_SUB_ENTITY_CODE varchar2,
                            P_ENTITY_ID       number,
                            P_ENTITY_CODE     varchar2) return varchar2 is
    /* Start Code Assignment variables */
    l_class_category varchar2(30);
    /* End Code Assignment variables */

    /* Start relationship variables */
    l_relation_code     varchar2(30);
    l_relationship_type varchar2(30);
    l_object_table_name varchar2(30);
    l_object_type       varchar2(30);
    l_subject_type      varchar2(30);
    /* End relationship variables */

    l_relationship_valid    varchar2(1) := 'Y';
    l_code_assignment_valid varchar2(1) := 'Y';
    l_account_valid         varchar2(1);
    l_party_type            varchar2(30);
    l_count                 NUMBER;
  begin
    if P_SUB_ENTITY_CODE = 'CODE_ASSIGNMENT' then
      begin
        select hca.class_category
          into l_class_category
          from hz_code_assignments hca
         where hca.code_assignment_id = P_ENTITY_ID;
      exception
        when no_data_found then
          l_code_assignment_valid := 'N';
      end;

      if 'Objet Business Type' = l_class_category then
        l_code_assignment_valid := 'Y';
      end if;

      return l_code_assignment_valid;

    elsif P_SUB_ENTITY_CODE = 'RELATIONSHIP' then
      --begin
      For rec in (select hr.relationship_code,
                             hr.relationship_type,
                             hr.object_table_name,
                             hr.object_type,
                             hr.subject_type
                        from hz_relationships hr
                       where hr.relationship_id = P_ENTITY_ID
                       and   hr.relationship_type <> 'CONTACT'
                       )
       Loop
          if rec.relationship_code = 'GLOBAL_ULTIMATE_OF' and
             rec.relationship_type = 'XX_OBJ_GLOBAL' and
             rec.object_table_name = 'HZ_PARTIES' and
             rec.object_type = 'ORGANIZATION' and
             rec.subject_type = 'ORGANIZATION'
          Then
            return 'Y';
          end if;
       End Loop;

       return 'N';

    ElsIf P_SUB_ENTITY_CODE = 'PARTY' Then
      Begin
        select party_type
          into l_party_type
          from hz_parties
         where party_type in ('ORGANIZATION', 'PERSON')
           and party_id = P_ENTITY_ID;

        If l_party_type = 'ORGANIZATION' Then
          Return 'Y';
        Else
          SELECT count(*)
            into l_count
            FROM hz_cust_accounts      hca,
                 hz_parties            hp_cont,
                 hz_relationships      hr,
                 hz_cust_account_roles hcar
           WHERE hp_cont.party_id = P_ENTITY_ID
             AND hcar.cust_account_id = hca.cust_account_id
             AND hcar.role_type = 'CONTACT'
             AND hcar.party_id = hr.party_id
             AND hcar.cust_acct_site_id IS NULL
             AND hp_cont.party_id = hr.subject_id
             AND hr.subject_type = 'PERSON'
             AND hr.object_type = 'ORGANIZATION'
             AND hr.relationship_code = 'CONTACT_OF'
             AND hca.party_id = hr.object_id;

          If l_count > 0 Then
            Return 'Y';
          Else
            Return 'N';
          End If;
        End If;
      Exception
        When No_data_found Then
          Return 'N';
      End;

    elsif nvl(P_SUB_ENTITY_CODE, 'XX') = 'XX' then
      l_account_valid := is_account_sf_valid(P_ENTITY_ID);
      return l_account_valid;
    end if;
  end validate_account;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function will be used to perform all required validation for Customer contacts
  --          being interfaced to Strataforce
  -- --------------------------------------------------------------------------------------------
  -- Usage: DFF ATTRIBUTE2 for Valueset XXSSYS_EVENT_ENTITY_NAME against target STRATAFORCE
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee(TCS)   Initial Build
  -- --------------------------------------------------------------------------------------------
  function validate_contact(P_SUB_ENTITY_CODE varchar2,
                            P_ENTITY_ID       number,
                            P_ENTITY_CODE     varchar2) return varchar2 is
    ---------------------------------
    --
    ---------------------------------
    cursor customer_cur(c_entity_id number) is
      SELECT 'Y'
        FROM hz_cust_accounts      cust_acc,
             hz_cust_account_roles cust_roles,
             hz_relationships      cust_rel,
             hz_parties            cust_party,
             hz_org_contacts       cust_cont,
             hz_parties            party
       WHERE cust_cont.status = 'A'
         AND cust_acc.cust_account_id = cust_roles.cust_account_id
         AND cust_acc.status = 'A'
         AND cust_roles.role_type = 'CONTACT'
         AND cust_roles.cust_acct_site_id IS NULL
         AND cust_roles.party_id = cust_rel.party_id
         AND cust_rel.subject_type = 'PERSON'
         AND cust_rel.subject_id = cust_party.party_id
         AND cust_cont.party_relationship_id = cust_rel.relationship_id
         AND party.party_type = 'ORGANIZATION'
         AND cust_acc.party_id = party.party_id
         AND cust_roles.cust_account_role_id = c_entity_id;

    /* Start Contact Point variables */
    l_owner_table_name   varchar2(30);
    l_contact_point_type varchar2(30);
    /* End Contact Point variables */

    l_contact_point_valid varchar2(1) := 'Y';
  begin
    if P_SUB_ENTITY_CODE = 'CONTACT_POINT' then
      begin
        select hcp.owner_table_name, hcp.contact_point_type
          into l_owner_table_name, l_contact_point_type
          from hz_contact_points hcp
         where hcp.contact_point_id = P_ENTITY_ID;
      exception
        when no_data_found then
          l_contact_point_valid := 'N';
      end;

      if 'HZ_PARTIES' = l_owner_table_name and
         l_contact_point_type in ('PHONE', 'EMAIL', 'WEB') then
        l_contact_point_valid := 'Y';
      end if;
    Else
      -- check contact relate to valid account (party type= organization )
      open customer_cur(P_ENTITY_ID);
      fetch customer_cur
        into l_contact_point_valid;

      close customer_cur;

      -- l_contact_point_valid := 'Y';
    end if;

    return nvl(l_contact_point_valid, 'N');
  end validate_contact;
  --
  function validate_product_option(P_INVENTORY_ITEM_ID NUMBER)
    Return Varchar2 IS
    l_notOptionalCnt NUMBER := 0;
  Begin
    select COUNT(1)
      INTO l_notOptionalCnt
      from BOM_BILL_OF_MATERIALS_V bbo, BOM_INVENTORY_COMPONENTS_V bic
     where bbo.assembly_item_id = P_INVENTORY_ITEM_ID
       AND bbo.organization_id = 91
       AND bbo.bill_sequence_id = bic.bill_sequence_id
       AND bic.optional = 1 -- 1 is TRUE , 2 is Flase
       AND bic.impl_cb = 1; -- Component Implemented (1) Implemented (2) Not Implemented

    If l_notOptionalCnt > 0 Then
      Return 'N';
    Else
      Return 'Y';
    End If;

  End validate_product_option;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042874 - Field Service Usage interface from salesforce to Oracle
  --
  --
  -- --------------------------------------------------------------------------------------------
  -- Usage: Called from get_material_trx_info to Validate Table Type Data
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  23/05/2018  Lingaraj(TCS)                 CHG0042874-Initial Build
  -- --------------------------------------------------------------------------------------------
  procedure validate_material_trx_info(p_source        in varchar2,
                                       p_tab           in out xxobjt.xxssys_material_tab_type,
                                       p_out_err_code     out varchar2,  --S/E
                                       p_out_err_message  out varchar2
                                      )
  is
    l_validation_status varchar2(1);
    l_validation_message varchar2(500);
    l_inv_org_id         org_organization_definitions.organization_id%type;
    l_inv_org_code       org_organization_definitions.organization_code%type;
    l_item_id            mtl_system_items_b.inventory_item_id%type;
    l_item_code          mtl_system_items_b.segment1%type;
    l_subinv_code        mtl_secondary_inventories.secondary_inventory_name%type;
    l_primary_uom_code   mtl_system_items_b.primary_uom_code%type;
    l_cost_of_sales_acct mtl_system_items_b.cost_of_sales_account%type;
    l_requester_userid   number;
    l_master_inv_org_id  number := xxinv_utils_pkg.get_master_organization_id;
  begin

    p_out_err_code := 'S';
    --get User Id respective to the source
    BEGIN
      SELECT ffv.attribute2
      INTO   l_requester_userid
      FROM   fnd_flex_values     ffv,
	         fnd_flex_value_sets ffvs
      WHERE  ffvs.flex_value_set_name = 'XXSSYS_EVENT_TARGET_NAME'
      AND    ffvs.flex_value_set_id   = ffv.flex_value_set_id
      AND    upper(ffv.flex_value) = upper(p_source)
      AND    ffv.enabled_flag = 'Y'
      AND    trunc(SYSDATE) BETWEEN nvl(ffv.start_date_active, trunc(SYSDATE) - 1)
	                         And   nvl(ffv.end_date_active, trunc(SYSDATE) + 1);

      If l_requester_userid IS NULL Then
        p_out_err_code     := 'E';
        p_out_err_message := 'VALIDATION ERROR: Source:' || p_source ||
		                     ' defined in valueset XXSSYS_EVENT_TARGET_NAME does not have user.';
        return;
      End If;

    Exception
      WHEN no_data_found THEN
        p_out_err_code     := 'E';
        p_out_err_message := 'VALIDATION ERROR: Source:' || p_source ||
		                     ' defined in valueset XXSSYS_EVENT_TARGET_NAME does not have user.';
        return;
    End;


    FOR i IN p_tab.first .. p_tab.last LOOP
     Begin
      l_validation_status := 'S';
      l_validation_message:= '';
      l_item_id           := null;
      l_item_code         := '';

      -- Inventory Organization validation
      if p_tab(i).organization_code is not null or p_tab(i).organization_id is not null then
        begin
          select ood.organization_id, ood.organization_code
            into l_inv_org_id, l_inv_org_code
            from org_organization_definitions ood
           where ood.organization_code = nvl(p_tab(i).organization_code, ood.organization_code)
             and ood.organization_id   = nvl(p_tab(i).organization_id, ood.organization_id);

          if p_tab(i).organization_id is null then
            p_tab(i).organization_id := l_inv_org_id;
          end if;

          if p_tab(i).organization_code is null then
            p_tab(i).organization_code := l_inv_org_code;
          end if;

        exception when no_data_found then
          l_validation_status := 'E';
          l_validation_message := 'VALIDATION ERROR: Inventory organization Name or Inventory Organization ID is not valid'||chr(13);
        end;
      Else-- If no value in organization_code / organization_id
          l_validation_status := 'E';
          l_validation_message := 'VALIDATION ERROR: Either Inventory organization Name or Inventory Organization ID is mandatory.'||chr(13);
      end if;


      -- Item validation
      if p_tab(i).item_code is null and p_tab(i).inventory_item_id is null then
        l_validation_status := 'E';
        l_validation_message := l_validation_message||'VALIDATION ERROR: Either Item code or Item ID is mandatory.'||chr(13);
      else
        begin
          select msib.inventory_item_id , msib.segment1 , msib.primary_uom_code
            into l_item_id , l_item_code , l_primary_uom_code
            from mtl_system_items_b msib
           where msib.segment1          = nvl(p_tab(i).item_code, msib.segment1)
             and msib.inventory_item_id = nvl(p_tab(i).inventory_item_id, msib.inventory_item_id)
             and msib.organization_id   = l_master_inv_org_id;

          if p_tab(i).inventory_item_id is null then
            p_tab(i).inventory_item_id := l_item_id;
          end if;

          if p_tab(i).item_code is null then
            p_tab(i).item_code := l_item_code;
          end if;

        exception when no_data_found then
          l_validation_status := 'E';
          l_validation_message := l_validation_message||'VALIDATION ERROR: Item code or Item ID is not valid'||chr(13);
        end;
      end if;

      -- Sub-Inventory validation
      if p_tab(i).subinventory_code is  null Then
         l_validation_status := 'E';
         l_validation_message := l_validation_message||'VALIDATION ERROR: Subinventory code is mandatory.'||chr(13);
      ElsIf p_tab(i).subinventory_code is not null and p_tab(i).organization_id is not null then
        begin
          select msi.secondary_inventory_name
            into l_subinv_code
            from mtl_secondary_inventories msi
           where msi.secondary_inventory_name = p_tab(i).subinventory_code
             and msi.organization_id          = p_tab(i).organization_id;

        exception when no_data_found then
          l_validation_status := 'E';
          l_validation_message := l_validation_message||'VALIDATION ERROR: Subinventory code is not valid'||chr(13);
        end;
      end if;

      -- Transaction Quantity validation
      if p_tab(i).quantity_trx is  null or p_tab(i).quantity_trx = 0 Then
         l_validation_status := 'E';
         l_validation_message := l_validation_message||'VALIDATION ERROR: quantity_trx is mandatory.'||chr(13);
      Else
         If sign (p_tab(i).quantity_trx) = 1 and upper(p_source) = 'STRATAFORCE' Then
             p_tab(i).quantity_trx := p_tab(i).quantity_trx *(-1);
         End if;
      end if;

      --TRANSACTION_UOM validation and Set Value
      if p_tab(i).transaction_uom is null Then
         p_tab(i).transaction_uom := l_primary_uom_code;
      End If;

      -- COST_OF_SALES_ACCOUNT_ID validation
      if p_tab(i).cost_of_sales_account_id is null
       and p_tab(i).organization_id    is not null
       and p_tab(i).inventory_item_id  is not null
      then
        Begin
           SELECT msib.cost_of_sales_account
            INTO   p_tab(i).cost_of_sales_account_id
            FROM   mtl_system_items_b msib
            WHERE  msib.inventory_item_id = p_tab(i).inventory_item_id
            AND    msib.organization_id   = p_tab(i).organization_id;
        Exception
        When no_data_found then
           l_validation_status := 'E';
           l_validation_message := l_validation_message||'VALIDATION ERROR: valid cost of sales account not found.'||chr(13);
        End;
      end if;

      -- Revision Validation and Set Value
      If p_tab(i).revision is null
      Then
        If    p_tab(i).item_code         is not null
          and p_tab(i).inventory_item_id is not null
          and p_tab(i).organization_id   is not null
          and p_tab(i).subinventory_code is not null
          and xxinv_trx_in_pkg.is_revision_control(p_tab(i).item_code , p_tab(i).organization_id) = 'Y'
        Then
            Begin
                SELECT MIN(moqd.revision) into p_tab(i).revision
              FROM mtl_onhand_quantities_detail moqd,
                   mtl_system_items_b           msib
              WHERE moqd.organization_id  = msib.organization_id
               AND moqd.inventory_item_id = msib.inventory_item_id
               AND moqd.subinventory_code = p_tab(i).subinventory_code
               AND msib.organization_id   = p_tab(i).organization_id
               AND msib.inventory_item_id = p_tab(i).inventory_item_id;

            Exception
            When no_data_found then
               l_validation_status := 'E';
               l_validation_message := l_validation_message||'VALIDATION ERROR: Error During quering Revison :'||
                                       sqlerrm||'.'||chr(13);
            End;
        End If;
      End If;


      /*check_quantity_available(p_tab(i).organization_id,
		       p_tab(i).subinventory_code,
		       p_tab(i).inventory_item_id,
		       p_tab(i).revision,
		       abs(p_tab(i).quantity_trx),
		       p_tab(i).err_code,
		       p_tab(i).err_message);*/

      p_tab(i).user_id     := l_requester_userid;
      p_tab(i).err_code    := l_validation_status;
      p_tab(i).err_message := l_validation_message;
     Exception
     When Others Then
          p_tab(i).err_code    := 'E';
          p_tab(i).err_message := 'UNEXPECTED ERROR :'||SQLERRM;
     End;
    END LOOP;

  Exception
    When Others Then
      p_out_err_code    := 'E';
      p_out_err_message := SQLERRM;
  End validate_material_trx_info;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042874 - Field Service Usage interface from salesforce to Oracle
  --          This Procedure will be Call By SOA
  --  Composite Name :
  --  InterFace Type : SFDC to Oracle
  -- --------------------------------------------------------------------------------------------
  -- Usage:
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  23/05/2018  Lingaraj(TCS)                 CHG0042874-Initial Build
  -- --------------------------------------------------------------------------------------------
  Procedure get_material_trx_info(p_source     in   varchar2,
                                  p_tab        in   out xxobjt.xxssys_material_tab_type,
                                  p_out_err_code    out varchar2,  --S/E
                                  p_out_err_message out varchar2
                                 )
  is
  begin
      p_out_err_code := 'S';

      write_log('get_material_trx_info: No Of Records:'||p_tab.count());

      If p_tab.count = 0 Then
        p_out_err_code    := 'S';
        p_out_err_message := 'No data passed to get_material_trx_info';
        return;
      End If;

    -- Call Validate procedure
    validate_material_trx_info(p_source          => p_source,    --In
                               p_tab             => p_tab,       -- in out
                               p_out_err_code    => p_out_err_code,   -- out
                               p_out_err_message => p_out_err_message --out
                               );

    If  nvl(p_out_err_code,'S') = 'S' Then
       null;
    End If;

  Exception
    When Others Then
      p_out_err_code    := 'E';
      p_out_err_message := SQLERRM;
  End get_material_trx_info;

END xxssys_strataforce_valid_pkg;
/
