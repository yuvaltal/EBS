CREATE OR REPLACE PACKAGE BODY xxobjt_oa2sf_interface_pkg IS
  --------------------------------------------------------------------
  --  name:            XXOBJT_OA2SF_INTERFACE_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.1
  --  creation date:   01/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        CUST352 - Oracle Interface with SFDC
  --                   This package Handle all procedure that transfer
  --                   data from oracle to SF.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  01/09/2010  Dalit A. Raviv    initial build
  --  1.1  2/1/2014    Dalit A. Raviv    CR1215 modify insert_into_interface
  --                   yuval tal         modify get_product_sf_id,upd_oracle_sf_id
  --  1.2  03/02/2014  Vitaly            Two procedures are added ( get_source_view_data , source_data_query )
  --  1.3  26/11/2014  Dalit A. Raviv    CHG0033803 submit_pull_requestset modify
  --  1.4  08/01/2015  Michal Tzvik      CHG00340083
  --                                     - Add function purge_objct_interface_tables
  --                                     - PROCEDURE upd_oracle_sf_id: don't update who columns
  --  1.5  15/02/2015  Dalit A. Raviv    CHG0034398 function get_order_hold (release_flag)
  --                                                procedure sync_item_on_hand (product)
  --                                                function  is _relate_to_sf and is_valid_to_sf (product)
  --  1.6  08/03/2015  Dalit A. Raviv    CHG0034789 - procedure sync_item_on_hand (SF On Hand send t.inventory_item_id instead of p_item_id )
  --  1.7  12/03/2015  Dalit A. Raviv    CHG0034735 procedures handle_events, handle_asset_event
  --                                     add asset event
  -- 1.8   06/04/2015  yuval tal         CHG0034805 - modify is_valid_to_sf add subinv is valid logic
  --                                                  modify  sync_item_on_hand
  -- 1.9   26/05/2015  Michal Tzvik      CHG0035139 - update function purge_objct_interface_tables
  --                                        if p_status = ERR then don't delete latest record of each source and source_id
  -- 2.0   28/03/2017  Lingaraj Sarangi  CHG0040422 - Account interface - Internal account flag and bug fix for Sites not sync to SFDC
  --                                     is_valid_to_sf adding nvl (hca.attribute5,'Y') to case entities ?CUST_ACC_SITE? and ?SITE_USE?.
  -- 2.1   06/04/2017  Lingaraj Sarangi  CHG0040057 - New SFDC TO Oracle Customer Interface
  -- 2.2   9.10.17     yuval  tal        CHG0041509 - add is_account_merged
  --                                                   modify is_valid_to_sf
  -- 2.3   2.4.18      yuval tal         CHG0042619 - modify handle_asset_event
  --2.3    11.2.18     yuval tal         CHG0042336 - add currency event for strataforce
  -- 2.4   12.12.18    yuval tal         CHGXXX       eliminate insert event for old interface table (old salesforce is shut down )
  --------------------------------------------------------------------

  g_user_id        NUMBER := 4290;
  g_sf_date_format VARCHAR2(20) := 'YYYY-MM-DD~HH:MI:SS'; -- 2010-10-10T08:51:54.000Z

  --------------------------------------------------------
  -- get_sf_format
  -- get sf dormat for update usage
  ----------------------------------------------------------
  FUNCTION get_sf_format(p_date DATE) RETURN VARCHAR2 IS
  BEGIN
    IF p_date IS NULL THEN
      RETURN NULL;
    ELSE
      RETURN REPLACE(to_char(p_date, g_sf_date_format), '~', 'T') || '.000Z';
    END IF;
  END;

  --------------------------------------------------------------------
  --  name:            upd_product_sf_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/01/2014
  --------------------------------------------------------------------
  --  purpose :        procedure will update item cross refference with SF_id
  --                   if it is not exists create by API cress ref.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/01/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE upd_product_sf_id(p_source_id IN NUMBER,
		      p_sf_id     IN VARCHAR2,
		      p_err_code  OUT VARCHAR2,
		      p_err_msg   OUT VARCHAR2) IS

    l_exists        VARCHAR2(1) := 'N';
    l_xref_table    mtl_cross_references_pub.xref_tbl_type;
    l_return_status VARCHAR2(240);
    l_msg_count     NUMBER;
    l_message_list  error_handler.error_tbl_type;
    l_message       VARCHAR2(2000) := NULL;

  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;

    SELECT user_id
    INTO   g_user_id
    FROM   fnd_user
    WHERE  user_name = 'SALESFORCE';

    BEGIN
      SELECT 'Y'
      INTO   l_exists
      FROM   mtl_cross_references_b mcr
      WHERE  mcr.cross_reference_type = 'SF'
      AND    mcr.cross_reference = 'Y'
      AND    mcr.inventory_item_id = p_source_id
      AND    rownum = 1;

      IF l_exists = 'Y' THEN
        UPDATE mtl_cross_references_b mcr
        SET    mcr.attribute1       = p_sf_id,
	   mcr.last_update_date = SYSDATE,
	   mcr.last_updated_by  = g_user_id
        WHERE  mcr.cross_reference_type = 'SF'
        AND    mcr.cross_reference = 'Y'
        AND    mcr.inventory_item_id = p_source_id
        AND    nvl(mcr.attribute1, '-') ! = p_sf_id;
        COMMIT;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        l_xref_table(1).transaction_type := 'CREATE';
        l_xref_table(1).inventory_item_id := p_source_id; --104028;
        l_xref_table(1).cross_reference_type := 'SF';
        l_xref_table(1).cross_reference := 'Y';
        l_xref_table(1).org_independent_flag := 'Y';
        l_xref_table(1).description := 'SF';
        l_xref_table(1).attribute1 := p_sf_id; --'Dalit test';
        l_xref_table(1).created_by := g_user_id;

        mtl_cross_references_pub.process_xref(p_api_version   => 1.0,
			          p_init_msg_list => fnd_api.g_true,
			          p_commit        => fnd_api.g_false,
			          p_xref_tbl      => l_xref_table,
			          x_return_status => l_return_status,
			          x_msg_count     => l_msg_count,
			          x_message_list  => l_message_list);

        IF (l_return_status = fnd_api.g_ret_sts_success) THEN
          --COMMIT;
          NULL;
        ELSE
          FOR i IN 1 .. l_message_list.count LOOP
	dbms_output.put_line(l_message_list(i).message_text);
	IF l_message IS NULL THEN
	  l_message := l_message_list(i).message_text;
	ELSE
	  l_message := substr(l_message || ' - ' || l_message_list(i)
		          .message_text,
		          1,
		          1990);
	END IF;
          END LOOP;
          p_err_code := 2;
          p_err_msg  := l_message;
          --ROLLBACK;
        END IF;
    END;
  END upd_product_sf_id;

  --------------------------------------------------------------------
  --  name:            is_relate_to_sf
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that check by entity name
  --                   if entity relate to sales force
  --                   for example att4 = Y for party/ cust_account
  --  Return:          Y relate to SF
  --                   N not relate to SF
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05/09/2010  Dalit A. Raviv    initial build
  --  1.1  18/10/2010  Dalit A. Raviv    change logic for keeping SF_id
  --                                     for PRODUCT (use to be on item catalog,
  --                                     now change to item cross reference)
  --  1.2  15/02/2015  Dalit A. Raviv    CHG0034398 - SFDC modifications, change logic for PRODUCTS
  --------------------------------------------------------------------
  FUNCTION is_relate_to_sf(p_source_id    IN NUMBER,
		   p_source_name  IN VARCHAR2,
		   p_process_mode IN VARCHAR2) RETURN VARCHAR2 IS

    l_relate VARCHAR2(10) := NULL;
  BEGIN
    -- check source name
    IF p_source_name = 'ACCOUNT' THEN
      -- check process mode
      -- if insert we do not have yet SF_id so the check is if need to transfer to SF
      -- if update we allready have SF_id so need to check that.
      IF p_process_mode = 'INSERT' THEN
        SELECT 'Y'
        INTO   l_relate
        FROM   hz_cust_accounts
        WHERE  attribute5 = 'Y'
        AND    party_id = p_source_id
        AND    rownum = 1;
      ELSE
        SELECT 'Y'
        INTO   l_relate
        FROM   hz_cust_accounts
        WHERE  attribute4 IS NOT NULL
        AND    party_id = p_source_id
        AND    rownum = 1;
      END IF;
    ELSIF p_source_name = 'SITE' THEN
      -- if new cust acct site check if the account is transfer to SF
      -- else update look at att1 of the cust_acct_site level
      IF p_process_mode = 'INSERT' THEN
        SELECT 'Y'
        INTO   l_relate
        FROM   hz_cust_acct_sites_all hcas,
	   hz_cust_accounts       hca
        WHERE  hca.cust_account_id = hcas.cust_account_id
	  --AND hca.attribute5       = 'Y'
        AND    hca.attribute4 IS NOT NULL
        AND    hcas.cust_acct_site_id = p_source_id
        AND    rownum = 1;
      ELSE
        SELECT 'Y'
        INTO   l_relate
        FROM   hz_cust_acct_sites_all hcas
        WHERE  attribute1 IS NOT NULL
        AND    hcas.cust_acct_site_id = p_source_id
        AND    rownum = 1;
      END IF;
    ELSIF p_source_name = 'INSTALL_BASE' THEN
      IF p_process_mode = 'INSERT' THEN
        SELECT 'Y'
        INTO   l_relate
        FROM   hz_cust_accounts hca
        WHERE  hca.party_id = p_source_id
        AND    hca.attribute4 IS NOT NULL
        AND    rownum = 1;
      ELSE
        SELECT 'Y'
        INTO   l_relate
        FROM   csi_counter_associations cca,
	   csi_item_instances       cii
        WHERE  cii.instance_id = cca.source_object_id
        AND    cca.counter_id = p_source_id
        AND    cii.attribute12 IS NOT NULL;
      END IF;
    ELSIF p_source_name = 'PRODUCT' THEN

      SELECT 'Y'
      INTO   l_relate
      FROM   mtl_system_items_b msib
      WHERE  msib.customer_order_enabled_flag = 'Y'
      AND    msib.organization_id = 91
	-- 1.2 15/02/2015 Dalit A. Raviv CHG0034398
	--AND  msib.inventory_item_status_code NOT IN ('XX_DISCONT', 'Obsolete', 'Inactive')
      AND    msib.inventory_item_status_code NOT IN
	 (SELECT fv.flex_value
	   FROM   fnd_flex_values_vl  fv,
	          fnd_flex_value_sets fvs
	   WHERE  fv.flex_value_set_id = fvs.flex_value_set_id
	   AND    fvs.flex_value_set_name LIKE
	          'XXSSYS_SF_EXCLUDE_ITEM_STATUS'
	   AND    nvl(fv.enabled_flag, 'N') = 'Y'
	   AND    trunc(SYSDATE) BETWEEN
	          nvl(fv.start_date_active, SYSDATE - 1) AND
	          nvl(fv.end_date_active, SYSDATE + 1))
      AND    msib.inventory_item_id = to_number(p_source_id);

    ELSIF p_source_name = 'PRICE_ENTRY' THEN
      IF p_process_mode = 'INSERT' THEN
        -- product (item) will mark for SF at cross reference
        -- and not at the catalog.
        SELECT 'Y'
        INTO   l_relate
        FROM   mtl_cross_references_b mcr
        WHERE  mcr.cross_reference_type = 'SF'
        AND    mcr.cross_reference = 'Y'
        AND    mcr.attribute1 IS NOT NULL
        AND    mcr.inventory_item_id = p_source_id;
        /*SELECT 'Y'
         INTO l_relate
         FROM mtl_descriptive_elements e,
              mtl_item_catalog_groups  g,
              mtl_descr_element_values v
        WHERE v.element_name = e.element_name
          AND v.inventory_item_id = p_source_id
          AND g.item_catalog_group_id = e.item_catalog_group_id
          AND g.segment1 = 'SF Catalog'
          AND v.element_name = 'SF Item ID'
          AND v.element_value IS NOT NULL;*/
      END IF;
    END IF; -- p_source_name

    RETURN l_relate;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END is_relate_to_sf;

  --------------------------------------------------------------------
  --  name:            is_source_id_exist
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Function that check if there is row at interface
  --                   as NEW and yet did not transfer to SF
  --  Return:          Y if exist
  --                   N if not
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION is_source_id_exist(p_source_id   IN VARCHAR2,
		      p_source_name IN VARCHAR2) RETURN VARCHAR2 IS

    l_exist VARCHAR2(10) := NULL;

  BEGIN
    SELECT 'Y'
    INTO   l_exist
    FROM   xxobjt_oa2sf_interface xosi
    WHERE  xosi.source_id = p_source_id
    AND    xosi.status = 'NEW'
    AND    xosi.source_name = p_source_name;

    RETURN l_exist;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END is_source_id_exist;

  --------------------------------------------------------------------
  --  name:            is_valid_order_type
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   4.3.14
  --------------------------------------------------------------------
  --  purpose :        check if order type valid for sf sync
  --  Return:          Y if valid
  --                   N if not valid
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  4.3.14  yuval tal    initial build
  --------------------------------------------------------------------
  FUNCTION is_valid_order_type(p_order_type_id IN NUMBER) RETURN VARCHAR2 IS

    CURSOR c IS
      SELECT 'Y'
      FROM   oe_transaction_types_all t
      WHERE  t.attribute14 IS NULL
      AND    t.transaction_type_id = p_order_type_id;
    l_exist VARCHAR2(10) := NULL;

  BEGIN
    OPEN c;
    FETCH c
      INTO l_exist;
    CLOSE c;

    RETURN nvl(l_exist, 'N');

  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END;

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
  --  1.1  01/01/2014  Dalit A. Raviv    CUST776 - Customer support SF-OA interfaces
  --                                     CR 1215 - Customer support SF-OA interfaces
  --  1.2  06/04/2017  Lingaraj Sarangi  CHG0040057 - New Account, Contact, Site and
  --                                     check duplication Interfaces between SFDC and Oracle
  -- 1.3  12.12.18     yuval tal         CHG0042734 eliminate insert event for old interface table 
  --------------------------------------------------------------------
  PROCEDURE insert_into_interface(p_oa2sf_rec IN t_oa2sf_rec,
		          p_err_code  OUT VARCHAR2,
		          p_err_msg   OUT VARCHAR2) IS

    --l_oracle_event_id NUMBER := NULL;
    --l_process_mode    VARCHAR2(30) := NULL;
    --  1.1  01/01/2014  Dalit A. Raviv
    l_source_id_exist VARCHAR2(1) := 'N';
  BEGIN
  
  IF NVL(fnd_profile.value ('XXOBJT_OA2SF_INT_EVENTS_ACTIVE'),'Y') ='N' THEN 
      return ; -- CHG0042734 added for startaforce project (old salsforce will be shutdown ) 
  END IF;
  
    -- 1.1  01/01/2014  Dalit A. Raviv
    -- add check if there is allready row exists with this status, and source

    l_source_id_exist := xxobjt_oa2sf_interface_pkg.is_source_id_exist(p_source_id   => p_oa2sf_rec.source_id,
					           p_source_name => p_oa2sf_rec.source_name);

    IF l_source_id_exist = 'N' THEN

      /*SELECT user_id
      INTO   g_user_id
      FROM   fnd_user
      WHERE  user_name = 'SALESFORCE';*/ -- v1.2 Commented on 06-Apr-2017 for  CHG0040057
      --  1.1  01/01/2014  Dalit A. Raviv
      /* no need for this with the new BPEL
      IF p_oa2sf_rec.sf_id IS NOT NULL THEN
        l_process_mode := 'UPDATE';
      ELSE
        l_process_mode := 'INSERT';
      END IF;*/

      /*SELECT xxobjt_oa2sf_interface_id_s.NEXTVAL
      INTO   l_oracle_event_id
      FROM   dual;*/

      INSERT INTO xxobjt_oa2sf_interface
        (oracle_event_id,
         batch_id,
         bpel_instance_id,
         status,
         process_mode,
         source_id,
         source_id2,
         source_name,
         sf_id,
         sf_err_code,
         sf_err_msg,
         oa_err_code,
         oa_err_msg,
         last_update_date,
         last_updated_by,
         last_update_login,
         creation_date,
         created_by)
      VALUES
        ( /*l_oracle_event_id*/xxobjt_oa2sf_interface_id_s.nextval,
         NULL, -- p_oa2sf_rec.batch_id,
         NULL, -- p_oa2sf_rec.bpel_instance_id,
         nvl(p_oa2sf_rec.status, 'NEW'),
         p_oa2sf_rec.process_mode,
         p_oa2sf_rec.source_id,
         p_oa2sf_rec.source_id2,
         p_oa2sf_rec.source_name,
         NULL, -- p_oa2sf_rec.sf_id,
         NULL, -- p_oa2sf_rec.sf_err_code,
         NULL, -- p_oa2sf_rec.sf_err_msg,
         NULL, -- p_oa2sf_rec.oa_err_code,
         NULL, -- p_oa2sf_rec.oa_err_msg,
         SYSDATE,
         fnd_global.user_id, --g_user_id,-- v1.2 Updated on 06-Apr-2017 for  CHG0040057
         -1,
         SYSDATE,
         fnd_global.user_id --g_user_id -- v1.2 Updated on 06-Apr-2017 for  CHG0040057
         );
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - insert_into_interface - ' ||
	        substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - insert_into_interface - ' ||
		   substr(SQLERRM, 1, 240));
  END insert_into_interface;

  --------------------------------------------------------------------
  --  name:            retry
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   01/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that will update interface tbl to
  --                   status = NEW , Bpel_instance_id = null and
  --                   batch_id = null.
  --                   When get error at specific row , handle the data
  --                   and now want to send it back to SF.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  01/09/2010  Dalit A. Raviv    initial build
  --  1.1  06/04/2017  Lingaraj Sarangi  CHG0040057 - New Account, Contact, Site and
  --                                     check duplication Interfaces between SFDC and Oracle
  --------------------------------------------------------------------
  PROCEDURE retry(p_id       IN NUMBER,
	      p_err_code OUT VARCHAR2,
	      p_err_msg  OUT VARCHAR2) IS

    PRAGMA AUTONOMOUS_TRANSACTION;

  BEGIN
    /*SELECT user_id
    INTO   g_user_id
    FROM   fnd_user
    WHERE  user_name = 'SALESFORCE';*/ -- v1.1 Commented on 06-Apr-2017 for  CHG0040057

    UPDATE xxobjt_oa2sf_interface xosi
    SET    xosi.bpel_instance_id = NULL,
           xosi.status           = 'NEW',
           xosi.batch_id         = NULL,
           xosi.oa_err_code      = NULL, --
           xosi.oa_err_msg       = NULL, --
           xosi.sf_err_code      = NULL, --
           xosi.sf_err_msg       = NULL, --
           xosi.last_update_date = SYSDATE,
           xosi.last_updated_by  = fnd_global.user_id, --g_user_id,-- v1.2 Updated on 06-Apr-2017 for  CHG0040057
           xosi.oa_request       = NULL
    WHERE  xosi.oracle_event_id = p_id;

    COMMIT;

    p_err_code := 0;
    p_err_msg  := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - retry - ' || substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - retry - ' || substr(SQLERRM, 1, 240));
  END retry;

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
  --  1.1  06/04/2017  Lingaraj Sarangi  CHG0040057 - New Account, Contact, Site and
  --                                     check duplication Interfaces between SFDC and Oracle
  --------------------------------------------------------------------
  PROCEDURE upd_system_err(p_batch_id IN NUMBER,
		   p_err_code IN OUT VARCHAR2,
		   p_err_msg  IN OUT VARCHAR2) IS

    PRAGMA AUTONOMOUS_TRANSACTION;

  BEGIN
    /*SELECT user_id
    INTO   g_user_id
    FROM   fnd_user
    WHERE  user_name = 'SALESFORCE';*/ -- v1.1 Commented on 06-Apr-2017 for  CHG0040057

    UPDATE xxobjt_oa2sf_interface xosi
    SET    xosi.oa_err_code      = p_err_code,
           xosi.oa_err_msg       = p_err_msg,
           xosi.last_update_date = SYSDATE,
           xosi.last_updated_by  = fnd_global.user_id, --g_user_id, -- v1.1 Updated on 06-Apr-2017 for  CHG0040057
           xosi.status           = 'ERROR'
    WHERE  xosi.batch_id = p_batch_id
    AND    xosi.status = 'IN_PROCESS';
    COMMIT;
    dbms_output.put_line('p_batch_id - ' || p_batch_id);
    p_err_code := 0;
    p_err_msg  := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - upd_system_err- ' || substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - upd_system_err - ' ||
		   substr(SQLERRM, 1, 240));
  END upd_system_err;

  --------------------------------------------------------------------
  --  name:            upd_oracle_sf_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/01/2014 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        update sf id  in oracle entity record  for all records in the same bpel process
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/01/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE upd_oracle_sf_id(p_bpel_instance_id IN NUMBER,
		     p_err_code         OUT VARCHAR2,
		     p_err_msg          OUT VARCHAR2) IS

    CURSOR c IS
      SELECT i.sf_id,
	 i.source_name,
	 i.oracle_event_id,
	 i.source_id
      FROM   xxobjt_oa2sf_interface i
      WHERE  i.bpel_instance_id = p_bpel_instance_id;

    l_err_code VARCHAR2(100);
    l_err_msg  VARCHAR2(2000);
  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;
    FOR r IN c LOOP
      l_err_code := NULL;
      l_err_msg  := NULL;
      upd_oracle_sf_id(p_source_name     => r.source_name, -- i v
	           p_sf_id           => r.sf_id, -- i v
	           p_source_id       => r.source_id, -- i n
	           p_oracle_event_id => r.oracle_event_id, -- i n
	           p_err_code        => l_err_code, -- o v
	           p_err_msg         => l_err_msg); -- o v
      p_err_code := l_err_code;
      p_err_msg  := l_err_msg;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Err - upd_oracle_sf_id ' || SQLERRM;
  END;

  --------------------------------------------------------------------
  --  name:            upd_oracle_sf_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   01/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :    update sf id  in oracle entity record
  --

  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  01/09/2010  Dalit A. Raviv    initial build
  --  1.1  18/10/2010  Dalit A. Raviv    change logic for keeping SF_id
  --                                     for PRODUCT (use to be on item catalog,
  --                                     now change to item cross reference)
  --  1.2 5.1.2014     yuval tall        CR 1215 add SUBINV update
  --                   Dalit A. Raviv    Change logic for Product
  --  1.3 11.01.2015   Michal Tzvik      CHG0034083 : don't update who columns
  --------------------------------------------------------------------
  PROCEDURE upd_oracle_sf_id(p_source_name     IN VARCHAR2,
		     p_sf_id           IN VARCHAR2,
		     p_source_id       IN VARCHAR2,
		     p_oracle_event_id IN NUMBER,
		     p_err_code        OUT VARCHAR2,
		     p_err_msg         OUT VARCHAR2) IS

    PRAGMA AUTONOMOUS_TRANSACTION;
    l_message VARCHAR2(500);
    l_exception EXCEPTION;
  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;
    --'ACCOUNT'/'SITE'/'INSTALL_BASE'/'PRODUCT'/'PRICE_BOOK/SUBINV/PRICE_ENTRY'

    SELECT user_id
    INTO   g_user_id
    FROM   fnd_user
    WHERE  user_name = 'SALESFORCE';

    CASE p_source_name

      WHEN 'ITEMREV' THEN

        UPDATE mtl_item_revisions_b t
        SET    t.attribute10      = p_sf_id,
	   t.last_update_date = SYSDATE,
	   t.last_updated_by  = g_user_id
        WHERE  t.revision_id = to_number(p_source_id)
        AND    nvl(t.attribute10, '-') != p_sf_id;

      WHEN 'CONTACT' THEN

        UPDATE hz_cust_account_roles t
        SET    t.attribute1       = p_sf_id,
	   t.last_update_date = SYSDATE,
	   t.last_updated_by  = g_user_id
        WHERE  t.cust_account_role_id = to_number(p_source_id)
        AND    nvl(t.attribute1, '-') != p_sf_id;

      WHEN 'SUBINV' THEN
        UPDATE mtl_secondary_inventories t
        SET    t.attribute12      = p_sf_id,
	   t.last_update_date = SYSDATE,
	   t.last_updated_by  = g_user_id
        WHERE  nvl(t.attribute12, '-') != p_sf_id
        AND    t.organization_id =
	   substr(p_source_id, 1, instr(p_source_id, '|') - 1)
        AND    t.secondary_inventory_name =
	   substr(p_source_id, instr(p_source_id, '|') + 1);

      WHEN 'ACCOUNT' THEN
        UPDATE hz_cust_accounts hca
        SET    hca.attribute4       = p_sf_id,
	   hca.last_update_date = SYSDATE,
	   hca.last_updated_by  = g_user_id
        WHERE  hca.cust_account_id = to_number(p_source_id)
        AND    nvl(hca.attribute4, '-') != p_sf_id;
      WHEN 'SITE' THEN
        UPDATE hz_cust_acct_sites_all hcas
        SET    hcas.attribute1       = p_sf_id,
	   hcas.last_update_date = SYSDATE,
	   hcas.last_updated_by  = g_user_id
        WHERE  hcas.cust_acct_site_id = to_number(p_source_id)
        AND    nvl(hcas.attribute1, '-') ! = p_sf_id;
      WHEN 'INSTALL_BASE' THEN
        UPDATE csi_item_instances cii
        SET    cii.attribute12      = p_sf_id,
	   cii.last_update_date = SYSDATE,
	   cii.last_updated_by  = g_user_id
        WHERE  cii.instance_id = to_number(p_source_id)
        AND    nvl(cii.attribute12, '-') ! = p_sf_id;
      WHEN 'PRICE_ENTRY' THEN
        UPDATE qp_list_lines qll
        SET    qll.attribute1 = p_sf_id
        /* CHG0034083 11.01.2015 Michal Tzvik: don't update who columns
        qll.last_update_date = SYSDATE,
        qll.last_updated_by  = g_user_id*/
        WHERE  qll.list_line_id = to_number(p_source_id)
        AND    nvl(qll.attribute1, '-') ! = p_sf_id;
      WHEN 'PRICE_BOOK' THEN
        UPDATE qp_list_headers_all_b qlh
        SET    qlh.attribute5 = p_sf_id
        /* CHG0034083 11.01.2015 Michal Tzvik: don't update who columns
        qll.last_update_date = SYSDATE,
        qll.last_updated_by  = g_user_id*/
        WHERE  qlh.list_header_id = to_number(p_source_id)
        AND    nvl(qlh.attribute5, '-') ! = p_sf_id;
      WHEN 'PRODUCT' THEN
        -- 06/01/2014 Dalit A. Raviv
        -- check if exists update if not create with API
        upd_product_sf_id(p_source_id, -- i n
		  p_sf_id, -- i v
		  p_err_code, -- o v
		  l_message); -- o v

        IF p_err_code <> 0 THEN
          ROLLBACK;
          RAISE l_exception; ----------------
        END IF;
      ELSE
        p_err_code := 1;
        l_message  := 'No entity found for updating sf id';
        RAISE l_exception;
    END CASE;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      SELECT user_id
      INTO   g_user_id
      FROM   fnd_user
      WHERE  user_name = 'SALESFORCE';
      -- in case the upadet did not accoured.
      l_message := substr(SQLERRM, 1, 240);
      UPDATE xxobjt_oa2sf_interface xosi
      SET    xosi.oa_err_code      = 1,
	 xosi.oa_err_msg       = 'Problem to upd sf_id in oracle - ' ||
			 l_message,
	 xosi.last_update_date = SYSDATE,
	 xosi.last_updated_by  = g_user_id
      WHERE  xosi.oracle_event_id = p_oracle_event_id; --p_id
      COMMIT;
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - upd_oracle_sf_id - ' ||
	        substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - upd_oracle_sf_id - ' ||
		   substr(SQLERRM, 1, 240));
  END upd_oracle_sf_id;

  --------------------------------------------------------------------
  --  name:            GET_UPDATE_STRING_XML
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   01/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  01/09/2010  YUVAL TAL    initial build : concate function
  --------------------------------------------------------------------
  FUNCTION get_update_string_xml(p_value         VARCHAR2,
		         p_sf_field_name VARCHAR2,
		         p_null_display  BOOLEAN DEFAULT TRUE)
    RETURN VARCHAR2 IS
  BEGIN
    IF p_value IS NULL AND NOT p_null_display THEN
      RETURN NULL;
    ELSE

      RETURN '<UPDATE_FIELDS> <FIELD_NAME>' || p_sf_field_name || '</FIELD_NAME> <FIELD_VALUE>' || dbms_xmlgen.convert(p_value,
									           0) || '</FIELD_VALUE> </UPDATE_FIELDS> ';
    END IF;
  END;

  --------------------------------------------------------------------
  --  name:            get_sf_owner_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/10/2010 1:30:11 PM
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
  --  1.0  05/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_sf_owner_id(p_postal_code  IN VARCHAR2,
		   p_city         IN VARCHAR2,
		   p_county       IN VARCHAR2,
		   p_state_code   IN VARCHAR2,
		   p_country_code IN VARCHAR2) RETURN VARCHAR2 IS

    l_sf_owner_id VARCHAR2(250) := NULL;
  BEGIN
    -- postal_code
    -- if got postal code value but did not find any then continue check
    IF p_postal_code IS NOT NULL THEN
      BEGIN
        SELECT sf_user.meaning sf_owner_id --owner.attribute7    owner_name
        INTO   l_sf_owner_id
        FROM   fnd_lookup_values owner,
	   fnd_lookup_values sf_user
        WHERE  owner.lookup_type = 'XXASN_OWNER_ASSIGNMENT'
        AND    sf_user.lookup_type = 'XXASN_SF_USERS'
        AND    owner.attribute7 = sf_user.description
        AND    owner.language = 'US'
        AND    sf_user.language = 'US'
        AND    p_postal_code BETWEEN owner.attribute5 AND owner.attribute6
        AND    p_country_code = 'US'
        AND    rownum = 1
        --between to_number(owner.attribute5) and to_number(owner.attribute6)
        ORDER  BY to_number(owner.lookup_code);

        RETURN l_sf_owner_id;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END IF;

    -- city
    IF p_city IS NOT NULL THEN
      BEGIN
        SELECT sf_user.meaning sf_owner_id
        INTO   l_sf_owner_id
        FROM   fnd_lookup_values owner,
	   fnd_lookup_values sf_user
        WHERE  owner.lookup_type = 'XXASN_OWNER_ASSIGNMENT'
        AND    sf_user.lookup_type = 'XXASN_SF_USERS'
        AND    owner.attribute7 = sf_user.description
        AND    owner.language = 'US'
        AND    sf_user.language = 'US'
        AND    owner.attribute4 = p_city
        AND    owner.attribute5 IS NULL
        AND    rownum = 1
        ORDER  BY to_number(owner.lookup_code);

        RETURN l_sf_owner_id;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END IF;

    -- county
    IF p_county IS NOT NULL THEN
      BEGIN
        SELECT sf_user.meaning sf_owner_id
        INTO   l_sf_owner_id
        FROM   fnd_lookup_values owner,
	   fnd_lookup_values sf_user
        WHERE  owner.lookup_type = 'XXASN_OWNER_ASSIGNMENT'
        AND    sf_user.lookup_type = 'XXASN_SF_USERS'
        AND    owner.attribute7 = sf_user.description
        AND    owner.language = 'US'
        AND    sf_user.language = 'US'
        AND    owner.attribute3 = p_county
        AND    owner.attribute4 IS NULL
        AND    owner.attribute5 IS NULL
        AND    rownum = 1
        ORDER  BY to_number(owner.lookup_code);

        RETURN l_sf_owner_id;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END IF;

    -- state_code
    IF p_state_code IS NOT NULL THEN
      BEGIN
        SELECT sf_user.meaning sf_owner_id
        INTO   l_sf_owner_id
        FROM   fnd_lookup_values owner,
	   fnd_lookup_values sf_user
        WHERE  owner.lookup_type = 'XXASN_OWNER_ASSIGNMENT'
        AND    sf_user.lookup_type = 'XXASN_SF_USERS'
        AND    owner.attribute7 = sf_user.description
        AND    owner.language = 'US'
        AND    sf_user.language = 'US'
        AND    owner.attribute2 = p_state_code
        AND    owner.attribute3 IS NULL
        AND    owner.attribute4 IS NULL
        AND    owner.attribute5 IS NULL
        AND    rownum = 1
        ORDER  BY to_number(owner.lookup_code);

        RETURN l_sf_owner_id;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END IF;

    -- country_code
    IF p_country_code IS NOT NULL THEN
      BEGIN
        SELECT sf_user.meaning sf_owner_id
        INTO   l_sf_owner_id
        FROM   fnd_lookup_values owner,
	   fnd_lookup_values sf_user
        WHERE  owner.lookup_type = 'XXASN_OWNER_ASSIGNMENT'
        AND    sf_user.lookup_type = 'XXASN_SF_USERS'
        AND    owner.attribute7 = sf_user.description
        AND    owner.language = 'US'
        AND    sf_user.language = 'US'
        AND    owner.attribute1 = p_country_code
        AND    owner.attribute2 IS NULL
        AND    owner.attribute3 IS NULL
        AND    owner.attribute4 IS NULL
        AND    owner.attribute5 IS NULL
        AND    rownum = 1
        ORDER  BY to_number(owner.lookup_code);

        RETURN l_sf_owner_id;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END IF;

    RETURN NULL;
  EXCEPTION
    WHEN OTHERS THEN

      dbms_output.put_line('err - ' || SQLERRM);
      RETURN NULL;
  END get_sf_owner_id;

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
  --  1.1  18/10/2010  Dalit A. Raviv    change logic for keeping SF_id
  --                                     for PRODUCT (use to be on item catalog,
  --                                     now change to item cross reference)
  -- 1.2  5.1.2014   yuval tal modify logic : call proc get_entity_sf_id
  --------------------------------------------------------------------
  FUNCTION get_product_sf_id(p_source_id IN NUMBER) RETURN VARCHAR2 IS

  BEGIN

    RETURN get_entity_sf_id('PRODUCT', p_source_id);

  END get_product_sf_id;*/

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
  FUNCTION get_price_list_header_is_sf(p_source_id IN NUMBER) RETURN VARCHAR2 IS

    l_relate VARCHAR2(1) := NULL;

  BEGIN
    SELECT 'Y'
    INTO   l_relate
    FROM   qp_list_headers_all_b b,
           qp_list_lines         l
    WHERE  b.list_header_id = l.list_header_id
    AND    l.list_line_id = p_source_id -- will be :NEW.list_header_id
    AND    b.attribute6 = 'Y'
    AND    rownum = 1;

    RETURN l_relate;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END get_price_list_header_is_sf;

  --------------------------------------------------------------------
  --  name:            get_oa_request
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   13/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        procedure that will update oA2SF interface tbl
  --                   with the data send from Oracle to SF for specific
  --                   oracle_event_id.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/10/2010  YUVAL TAL    initial build
  --------------------------------------------------------------------
  /*  FUNCTION get_oa_request(p_oracle_event_id IN NUMBER, p_source VARCHAR2)
    RETURN VARCHAR2 IS

    l_str      VARCHAR2(2500);
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(2500);
  BEGIN

    xxobjt_oa2sf_interface_pkg.upd_oa_request(p_oracle_event_id => p_oracle_event_id,
                                              p_source          => p_source,
                                              p_oa_request_str  => l_str,
                                              p_err_code        => l_err_code,
                                              p_err_msg         => l_err_msg);

    RETURN l_str;

  END;*/

  --------------------------------------------------------------------
  --  name:            Handle_InProcess_rows
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        procedure will handle all rows that stay at status
  --                   in process when finish the batch.
  --                   This procedure will update interface OA2SF tbl
  --                   status to ERROR and will set OA_err to - No_data_found please contact sysadmin.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE handle_inprocess_rows(p_batch_id IN NUMBER,
		          p_err_code OUT VARCHAR2,
		          p_err_desc OUT VARCHAR2) IS
    /*
        CURSOR get_inprocess_pop_c IS
          SELECT *
            FROM xxobjt_oa2sf_interface i
           WHERE i.status = 'IN_PROCESS'
             AND i.batch_id = p_batch_id;

        l_count   NUMBER := 0;
        l_view    VARCHAR2(150) := NULL;
        l_message VARCHAR2(250) := NULL;
    */
  BEGIN
    /*
        FOR get_inprocess_pop_r IN get_inprocess_pop_c LOOP
          l_count   := 0;
          l_view    := NULL;
          l_message := NULL;
          CASE get_inprocess_pop_r.source_name
            WHEN 'CUST360_VIEW' THEN
              SELECT COUNT(cust.party_id)
                INTO l_count
                FROM xxobjt_oa2sf_interface     xxint,
                     xxobjt_oa2sf_customer360_v cust
               WHERE cust.party_id = xxint.source_id
                 AND xxint.oracle_event_id =
                     get_inprocess_pop_r.oracle_event_id;

              l_view := 'xxobjt_oa2sf_customer360_v';
            WHEN 'ACCOUNT' THEN
              SELECT COUNT(acc.oracle_account_id)
                INTO l_count
                FROM xxobjt_oa2sf_interface         xxint,
                     xxobjt_oa2sf_account_details_v acc
               WHERE acc.oracle_account_id = xxint.source_id
                 AND xxint.oracle_event_id =
                     get_inprocess_pop_r.oracle_event_id;

              l_view := 'xxobjt_oa2sf_account_details_v';
            WHEN 'SITE' THEN
              SELECT COUNT(t.oracle_site_id)
                INTO l_count
                FROM xxobjt_oa2sf_interface      xxint,
                     xxobjt_oa2sf_site_details_v t
               WHERE t.oracle_site_id = xxint.source_id
                 AND xxint.oracle_event_id =
                     get_inprocess_pop_r.oracle_event_id;

              l_view := 'xxobjt_oa2sf_site_details_v';
            WHEN 'PRICE_BOOK' THEN
              SELECT COUNT(t.oracle_price_book_id)
                INTO l_count
                FROM xxobjt_oa2sf_interface xxint, xxobjt_oa2sf_price_book_v t
               WHERE t.oracle_price_book_id = xxint.source_id
                 AND xxint.oracle_event_id =
                     get_inprocess_pop_r.oracle_event_id;

              l_view := 'xxobjt_oa2sf_price_book_v';
            WHEN 'INSTALL_BASE' THEN
              SELECT COUNT(t.oracle_asset_id)
                INTO l_count
                FROM xxobjt_oa2sf_interface      xxint,
                     xxobjt_oa2sf_install_base_v t
               WHERE t.oracle_asset_id = xxint.source_id
                 AND xxint.oracle_event_id =
                     get_inprocess_pop_r.oracle_event_id;

              l_view := 'xxobjt_oa2sf_install_base_v';
            WHEN 'PRODUCT' THEN
              SELECT COUNT(t.oa_product_id)
                INTO l_count
                FROM xxobjt_oa2sf_interface xxint, xxobjt_oa2sf_products_v t
               WHERE t.oa_product_id = xxint.source_id
                 AND xxint.oracle_event_id =
                     get_inprocess_pop_r.oracle_event_id;

              l_view := 'xxobjt_oa2sf_products_v';
            WHEN 'PRICE_ENTRY' THEN
              SELECT COUNT(t.oracle_list_line_id)
                INTO l_count
                FROM xxobjt_oa2sf_interface xxint, xxobjt_oa2sf_price_entry_v t
               WHERE t.oracle_list_line_id = xxint.source_id
                 AND xxint.oracle_event_id =
                     get_inprocess_pop_r.oracle_event_id;

              l_view := 'xxobjt_oa2sf_price_entry_v';
          END CASE;
          IF l_count = 0 THEN
            -- get message
            fnd_message.set_name('XXOBJT', 'XXOBJT_OA2SF_INPROCESS_NO_DATA');
            fnd_message.set_token('VIEW_NAME', l_view);
            l_message := fnd_message.get;
          ELSE
            -- get message
            fnd_message.set_name('XXOBJT', 'XXOBJT_OA2SF_INPROCESS_GENERAL');
            l_message := fnd_message.get;
          END IF;
          -- update table
          UPDATE xxobjt_oa2sf_interface i
             SET i.status           = 'ERROR',
                 i.oa_err_code      = 1,
                 i.oa_err_msg       = decode(l_count,0, l_message,i.oa_err_msg||chr(10)||l_message),
                 i.last_update_date = SYSDATE
           WHERE i.oracle_event_id = get_inprocess_pop_r.oracle_event_id;

          COMMIT;
        END LOOP;
    */
    UPDATE xxobjt_oa2sf_interface i
    SET    i.status      = 'ERROR',
           i.oa_err_code = 1,
           /*i.oa_err_msg       = decode(i.oa_err_msg, null,
           (decode(i.oa_request,null,'No Data Found - in view',
                   'General error - Please contact your System admin')),
           (decode(i.oa_request,null,i.oa_err_msg||chr(10)||'No Data Found - in view',
                   i.oa_err_msg||chr(10)||'General error - Please contact your System admin')) ),
           */
           i.oa_err_msg = CASE
		    WHEN i.oa_err_msg IS NULL AND
		         i.oa_request IS NULL THEN
		     'No Data Found - in view'
		    WHEN i.oa_err_msg IS NULL AND
		         i.oa_request IS NOT NULL THEN
		     'General error - Please contact your System admin'
		    WHEN i.oa_err_msg IS NOT NULL AND
		         i.oa_request IS NULL THEN
		     i.oa_err_msg || chr(10) ||
		     'No Data Found - in view'
		    WHEN i.oa_err_msg IS NOT NULL AND
		         i.oa_request IS NOT NULL THEN
		     i.oa_err_msg || chr(10) ||
		     'General error - Please contact your System admin'
		  END,
           i.last_update_date = SYSDATE
    WHERE  i.status = 'IN_PROCESS'
    AND    i.batch_id = p_batch_id;

    COMMIT;
    p_err_code := 0;
    p_err_desc := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_desc := 'Gen EXC - Handle_InProcess_rows ' ||
	        substr(SQLERRM, 1, 240);
  END handle_inprocess_rows;

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
		    p_entity_id VARCHAR2) RETURN VARCHAR2 IS
    l_sf_id VARCHAR2(250) := NULL;
  BEGIN
    CASE p_entity

      WHEN 'CS_REGION' THEN
        SELECT id
        INTO   l_sf_id
        FROM   xxsf_serv_cs_region__c t
        WHERE  t.name = p_entity_id
        AND    rownum = 1;

      WHEN 'OU' THEN
        SELECT id
        INTO   l_sf_id
        FROM   xxsf_serv_operating_unit__c t
        WHERE  t.org_id__c = to_number(p_entity_id);

      WHEN 'UPD_SO_HEADER' THEN
        SELECT id
        INTO   l_sf_id
        FROM   xxsf_serv_order__c t
        WHERE  t.oe_id__c = p_entity_id
        AND    rownum = 1;

      WHEN 'UPD_SO_LINE' THEN
        SELECT id
        INTO   l_sf_id
        FROM   xxsf_serv_line_item__c t
        WHERE  t.oe_id__c = p_entity_id
        AND    rownum = 1;

      WHEN 'SUBINV' THEN
        SELECT t.attribute12
        INTO   l_sf_id
        FROM   mtl_secondary_inventories t
        WHERE  t.organization_id =
	   substr(p_entity_id, 1, instr(p_entity_id, '|') - 1)
        AND    t.secondary_inventory_name =
	   substr(p_entity_id, instr(p_entity_id, '|') + 1);
      WHEN 'CONTACT' THEN

        SELECT attribute1
        INTO   l_sf_id
        FROM   hz_cust_account_roles t
        WHERE  t.cust_account_role_id = to_number(p_entity_id);

      WHEN 'ORG' THEN
        /* SELECT attribute6
         INTO l_sf_id
         FROM hr_all_organization_units t
        WHERE organization_id = to_number(p_entity_id);*/

        SELECT id
        INTO   l_sf_id
        FROM   xxsf_serv_inventory_org__c t
        WHERE  t.oe_id__c = to_number(p_entity_id);

      WHEN 'PAY_TERM' THEN
        SELECT id
        INTO   l_sf_id
        FROM   xxsf_serv_payment_term__c t
        WHERE  t.oe_id__c = p_entity_id
        AND    rownum = 1;

      WHEN 'FREIGHT_TERMS' THEN
        SELECT id
        INTO   l_sf_id
        FROM   xxsf_serv_freight_terms__c t
        WHERE  t.name = p_entity_id
        AND    rownum = 1;

      WHEN 'ACCOUNT' THEN
        SELECT hca.attribute4
        INTO   l_sf_id
        FROM   hz_cust_accounts hca
        WHERE  hca.cust_account_id = to_number(p_entity_id);
      WHEN 'SITE' THEN
        SELECT hcas.attribute1
        INTO   l_sf_id
        FROM   hz_cust_acct_sites_all hcas
        WHERE  hcas.cust_acct_site_id = to_number(p_entity_id);
      WHEN 'INSTALL_BASE' THEN
        SELECT cii.attribute12
        INTO   l_sf_id
        FROM   csi_item_instances cii
        WHERE  cii.instance_id = to_number(p_entity_id);
      WHEN 'PRICE_ENTRY' THEN
        SELECT qll.attribute1
        INTO   l_sf_id
        FROM   qp_list_lines qll
        WHERE  qll.list_line_id = to_number(p_entity_id);

      WHEN 'PRICE_BOOK' THEN
        SELECT qlh.attribute5
        INTO   l_sf_id
        FROM   qp_list_headers_all_b qlh
        WHERE  qlh.list_header_id = to_number(p_entity_id);
      WHEN 'PRODUCT' THEN
        SELECT mcr.attribute1
        INTO   l_sf_id
        FROM   mtl_cross_references_b mcr
        WHERE  mcr.inventory_item_id = to_number(p_entity_id)
	  --  AND mcr.cross_reference = 'Y'
        AND    mcr.cross_reference_type = 'SF';

      WHEN 'ITEMREV' THEN
        SELECT attribute10
        INTO   l_sf_id
        FROM   mtl_item_revisions_b t
        WHERE  t.revision_id = to_number(p_entity_id);
      WHEN 'CURRENCY' THEN

        SELECT id
        INTO   l_sf_id
        FROM   xxsf_currencytype t
        WHERE  t.isocode = p_entity_id
        AND    rownum = 1;

      WHEN 'OPPORTUNITY_NO' THEN
        SELECT id
        INTO   l_sf_id
        FROM   xxsf_opportunity t
        WHERE  t.opportunity_number__c = p_entity_id
        AND    rownum = 1;

      ELSE
        l_sf_id := NULL;
    END CASE;

    RETURN l_sf_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_entity_sf_id;

  --------------------------------------------------------------------
  --  name:            is_valid_to_sf
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/01/2014
  --------------------------------------------------------------------
  --  purpose :        CR 1215 - Customer support SF-OA interfaces
  --                   Party type should be ORGANIZATION
  --                   Cust account should be mark to transfer to SF (att5 = Y)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05/01/2014  Dalit A. Raviv    initial build
  --  1.1  15/02/2015  Dalit A. Raviv    CHG0034398 - SFDC modifications, change logic for PRODUCTS
  --  1.2  06/04/2015  yuval tal         CHG0034805 - add SUBINV is valid logic
  --  1.3  28/03/2017  Lingaraj Sarangi  CHG0040422 - Account interface - Internal account flag and bug fix for Sites not sync to SFDC
  --                                     adding nvl (hca.attribute5,'Y') to case entities ?CUST_ACC_SITE? and ?SITE_USE?.
  --1.4    9.10.17     yuval  tal        CHG0041509 - modify is_valid_to_sf
  --------------------------------------------------------------------
  FUNCTION is_valid_to_sf(p_entity    VARCHAR2,
		  p_entity_id VARCHAR2) RETURN NUMBER IS
    --l_flag number := null;
    l_entity_id NUMBER := NULL;
  BEGIN
    CASE p_entity
      WHEN 'CUST_ACC_SITE' THEN
        BEGIN
          SELECT hca.cust_account_id
          INTO   l_entity_id
          FROM   hz_parties       hp,
	     hz_cust_accounts hca
          WHERE  hca.party_id = hp.party_id
          AND    hp.party_type IN ('PERSON', 'ORGANIZATION')
          AND    nvl(hca.attribute5, 'Y') = 'Y' -------- 20/02/2014 Dalit -- NVL Added on 28.03.17 for CHG0040422
          AND    hca.cust_account_id = p_entity_id -- CHG0041509 originaly was hp.party_id
          AND    is_account_merged(hca.account_number) = 'N' ---- CHG0041509
          AND    rownum = 1;
        EXCEPTION
          WHEN OTHERS THEN
	l_entity_id := NULL;
        END;
      WHEN 'PRODUCT' THEN
        -- 1.1 15/02/2015 Dalit A. Raviv CHG0034398
        -- SF want to see inactive items too
        /*SELECT 1
        INTO   l_entity_id
        FROM   mtl_system_items_b msib
        WHERE  msib.customer_order_enabled_flag = 'Y'
        AND    msib.organization_id = 91
        AND    msib.inventory_item_status_code NOT IN ('XX_DISCONT', 'Obsolete', 'Inactive')
        AND    msib.inventory_item_id = to_number(p_entity_id);*/
        IF xxobjt_oa2sf_interface_pkg.is_relate_to_sf(to_number(p_entity_id),
				      'PRODUCT',
				      '') = 'Y' THEN
          l_entity_id := 1;
        ELSE
          l_entity_id := 0;
        END IF;

      WHEN 'SITE_USE' THEN
        BEGIN
          SELECT site.cust_acct_site_id
          INTO   l_entity_id
          FROM   hz_parties             hp,
	     hz_cust_accounts       hca,
	     hz_cust_acct_sites_all site
          WHERE  hca.party_id = hp.party_id
          AND    hca.cust_account_id = site.cust_account_id
          AND    hp.party_type IN ('PERSON', 'ORGANIZATION')
          AND    (nvl(hca.attribute5, 'Y') = 'Y' OR
	    hca.attribute4 IS NOT NULL) --NVL Added to hca.attribute5 on 28.03.17 for CHG0040422
          AND    site.cust_acct_site_id = p_entity_id
          AND    rownum = 1;

        EXCEPTION
          WHEN OTHERS THEN
	l_entity_id := NULL;
        END;
      WHEN 'LOCATION' THEN
        BEGIN
          SELECT site.cust_acct_site_id
          INTO   l_entity_id
          FROM   hz_parties             hp,
	     hz_cust_accounts       hca,
	     hz_cust_acct_sites_all site,
	     hz_party_sites         hps
          WHERE  hca.party_id = hp.party_id
          AND    hca.cust_account_id = site.cust_account_id
          AND    site.party_site_id = hps.party_site_id
          AND    hp.party_type IN ('PERSON', 'ORGANIZATION')
          AND    (hca.attribute5 = 'Y' OR hca.attribute4 IS NOT NULL)
          AND    hps.location_id = p_entity_id
          AND    rownum = 1;

        EXCEPTION
          WHEN OTHERS THEN
	l_entity_id := NULL;
        END;
      WHEN 'ACCOUNT' THEN
        BEGIN
          SELECT hca.cust_account_id
          INTO   l_entity_id
          FROM   hz_parties       hp,
	     hz_cust_accounts hca
          WHERE  hca.party_id = hp.party_id
          AND    hp.party_type IN ('PERSON', 'ORGANIZATION')
          AND    (hca.attribute5 = 'Y' OR hca.attribute4 IS NOT NULL)
          AND    hp.party_id = p_entity_id
          AND    is_account_merged(hca.account_number) = 'N'; -- CHG0041509

        EXCEPTION
          WHEN OTHERS THEN
	l_entity_id := NULL;
        END;
      WHEN 'PARTY' THEN
        BEGIN
          SELECT hp.party_id
          INTO   l_entity_id
          FROM   hz_parties hp
          WHERE  hp.party_id = p_entity_id
          AND    hp.party_type IN ('PERSON', 'ORGANIZATION');
        EXCEPTION
          WHEN OTHERS THEN
	l_entity_id := NULL;
        END;
      WHEN 'SUBINV' THEN
        BEGIN
          SELECT 1
          INTO   l_entity_id
          FROM   mtl_secondary_inventories ms
          WHERE  ms.secondary_inventory_name =
	     substr(p_entity_id, 1, instr(p_entity_id, '|') - 1)
          AND    ms.organization_id =
	     substr(p_entity_id, instr(p_entity_id, '|') + 1)
          AND    nvl(ms.disable_date, SYSDATE) > SYSDATE - 1
          AND    (ms.attribute11 = 'Y' OR
	    ms.secondary_inventory_name LIKE '%CAR');
        EXCEPTION
          WHEN OTHERS THEN
	l_entity_id := 0;
        END;

      ELSE
        RETURN NULL;
    END CASE;
    RETURN l_entity_id;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;

  END is_valid_to_sf;

  /*
        PROCEDURE upd_oracle_sf_id
  WHEN 'PRODUCT' THEN
          -- need to change to procedure
          -- check if exists update if not create with API
          UPDATE mtl_cross_references_b mcr
             SET mcr.attribute1       = p_sf_id,
                 mcr.last_update_date = SYSDATE,
                 mcr.last_updated_by  = g_user_id
           WHERE mcr.cross_reference_type = 'SF'
             AND mcr.cross_reference = 'Y'
             AND mcr.inventory_item_id = p_source_id;*/

  /*  --------------------------------------------------------------------
    --  name:            Get_sf_user_pass
    --  create by:       Dalit A. Raviv
    --  Revision:        1.0
    --  creation date:   13/10/2010 1:30:11 PM
    --------------------------------------------------------------------
    --  purpose :        procedure will get user password for Sales force
    --                   by environment.
    --------------------------------------------------------------------
    --  ver  date        name              desc
    --  1.0  13/10/2010  Dalit A. Raviv    initial build
    --------------------------------------------------------------------
    PROCEDURE get_sf_user_pass(p_user_name OUT VARCHAR2,
                               p_password  OUT VARCHAR2,
                               p_env       OUT VARCHAR2,
                               p_jndi_name OUT VARCHAR2,
                               p_err_code  OUT VARCHAR2,
                               p_err_msg   OUT VARCHAR2) IS

      l_env       VARCHAR2(20)  := NULL;
      l_user      VARCHAR2(150) := NULL;
      l_password  VARCHAR2(150) := NULL;
      l_jndi_name VARCHAR2(150) := NULL;
    BEGIN
      l_env := xxagile_util_pkg.get_bpel_domain;
      CASE
        WHEN l_env = 'production' THEN
          l_user      := fnd_profile.VALUE('XXOBJT_SF_PRODUCTION_USER');
          l_password  := fnd_profile.VALUE('XXOBJT_SF_PRODUCTION_PASSWORD');
          l_jndi_name := fnd_profile.value('XXOBJT_SF_PRODUCTION_JNDI_NAME');
        WHEN l_env = 'default' THEN
          l_user      := fnd_profile.VALUE('XXOBJT_SF_DEFAULT_USER');
          l_password  := fnd_profile.VALUE('XXOBJT_SF_DEFAULT_PASSWORD');
          l_jndi_name := fnd_profile.value('XXOBJT_SF_DEFAULT_JNDI_NAME');
      END CASE;
      p_user_name := l_user;
      p_password  := l_password;
      p_jndi_name := l_jndi_name;
      p_env       := l_env;
      p_err_code  := 0;
      p_err_msg   := NULL;
    EXCEPTION
      WHEN OTHERS THEN
        p_user_name := NULL;
        p_password  := NULL;
        p_env       := NULL;
        p_jndi_name := null;
        p_err_code  := 1;
        p_err_msg   := 'GEN EXC - Get_sf_user_pass - ' ||
                       substr(SQLERRM, 1, 240);

    END get_sf_user_pass;
  */

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
    RETURN VARCHAR2 IS
    CURSOR c IS
      SELECT source_name
      FROM   xxobjt_oa2sf_interface
      WHERE  oracle_event_id = p_oracle_event_id;
  BEGIN

    FOR i IN c LOOP
      CASE upper(p_type)
        WHEN 'TO' THEN
          CASE i.source_name

	WHEN 'ACCOUNT' THEN
	  RETURN 'yuval.tal@stratasys.com';
	WHEN 'SITE' THEN
	  RETURN 'yuval.tal@stratasys.com';
	WHEN 'CONTACT' THEN
	  RETURN 'yuval.tal@stratasys.com';
	WHEN 'SUBINV' THEN
	  RETURN 'yuval.tal@stratasys.com';
	WHEN 'REVISION' THEN
	  RETURN 'yuval.tal@stratasys.com';
	WHEN 'ONHAND' THEN
	  RETURN 'yuval.tal@stratasys.com';
	WHEN 'PRODUCT' THEN
	  RETURN 'yuval.tal@stratasys.com';
	ELSE
	  RETURN NULL;
          END CASE;
        WHEN 'CC' THEN
          CASE i.source_name

	WHEN 'ACCOUNT' THEN
	  RETURN 'yuval.tal@stratasys.com';
	WHEN 'SITE' THEN
	  RETURN 'yuval.tal@stratasys.com';
	WHEN 'CONTACT' THEN
	  RETURN 'yuval.tal@stratasys.com';
	WHEN 'SUBINV' THEN
	  RETURN 'yuval.tal@stratasys.com';
	WHEN 'REVISION' THEN
	  RETURN 'yuval.tal@stratasys.com';
	WHEN 'ONHAND' THEN
	  RETURN 'yuval.tal@stratasys.com';
	WHEN 'PRODUCT' THEN
	  RETURN 'yuval.tal@stratasys.com';

	ELSE
	  RETURN NULL;
          END CASE;
        ELSE
          RETURN NULL;
      END CASE;
    END LOOP;

  END;
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
    PIPELINED IS

    TYPE source_view_data_tab IS TABLE OF xxinv_source_view_data_rec INDEX BY BINARY_INTEGER;
    l_source_view_data_tab source_view_data_tab;

    l_source_view_data_rec xxinv_source_view_data_rec;

    CURSOR get_view_columns(p_view_name             VARCHAR2,
		    p_max_number_of_columns NUMBER) IS
      SELECT rownum,
	 columns_tab.column_name,
	 columns_tab.data_type
      FROM   (SELECT tc.column_name,
	         tc.data_type
	  FROM   dba_tab_columns tc
	  WHERE  tc.table_name = upper(p_view_name) ---cursor parameter
	  ORDER  BY tc.column_name) columns_tab
      WHERE  rownum <= nvl(p_max_number_of_columns, 50); ----cursor parameter 50 columns only

    v_max_number_of_columns NUMBER := 50; ----max 50 columns
    ---v_result                NUMBER;
    v_view_name       VARCHAR2(30);
    v_key_column_name VARCHAR2(30);

    TYPE columncurtyp IS REF CURSOR;
    v_columns_values_cursor   columncurtyp;
    v_select_stmt_str         VARCHAR2(3000);
    v_select_columns_stmt_str VARCHAR2(5000);

  BEGIN
    ---0--- Check parameter
    IF p_source_name IS NULL THEN
      RETURN;
    ELSE
      v_view_name       := xxobjt_general_utils_pkg.get_valueset_attribute(p_set_code       => 'XXOBJT_OA2SF_SOURCE_NAME',
						   p_code           => p_source_name, ---parameter
						   p_attribute_name => 'ATTRIBUTE1');
      v_key_column_name := xxobjt_general_utils_pkg.get_valueset_attribute(p_set_code       => 'XXOBJT_OA2SF_SOURCE_NAME',
						   p_code           => p_source_name, ---parameter
						   p_attribute_name => 'ATTRIBUTE2');

      -- dbms_output.put_line(v_view_name || ' ' || v_key_column_name);
    END IF;

    ---1--- Insert 'EMPTY' in all records of our temporary pl/sql table-------
    FOR i IN 1 .. v_max_number_of_columns LOOP
      l_source_view_data_tab(i).seq_no := i;
      l_source_view_data_tab(i).field_name := 'EMPTY';
      l_source_view_data_tab(i).field_value := 'EMPTY';
      l_source_view_data_tab(i).source_name := p_source_name;
      l_source_view_data_tab(i).source_id := p_source_id;
      l_source_view_data_tab(i).view_name := v_view_name;
    END LOOP;

    ---2--- Insert Actual Column Names into our temporary pl/sql table-------
    FOR view_column_rec IN get_view_columns(v_view_name,
			        v_max_number_of_columns) LOOP
      ------------- VIEW COLUMNS LOOP-------------
      l_source_view_data_tab(view_column_rec.rownum).field_name := view_column_rec.column_name;
      l_source_view_data_tab(view_column_rec.rownum).field_data_type := view_column_rec.data_type;
      ------the end of VIEW COLUMNS LOOP----------
    END LOOP;

    ---3--- Prepare list of selected columns for Dynamic SQL Select statement---
    FOR i IN 1 .. v_max_number_of_columns LOOP
      IF l_source_view_data_tab(i).field_name = 'EMPTY' THEN
        ---hard coded 'EMPTY' instead of actual column name---
        v_select_columns_stmt_str := v_select_columns_stmt_str ||
			 ',''EMPTY''';
      ELSE
        ---actual column_name-----
        v_select_columns_stmt_str := v_select_columns_stmt_str || ',' || l_source_view_data_tab(i)
			.field_name;
      END IF;
    END LOOP;
    v_select_columns_stmt_str := ltrim(v_select_columns_stmt_str, ',');
    -- dbms_output.put_line(v_select_columns_stmt_str || ' ' ||
    --    v_key_column_name);
    ---4--- Prepare Dynamic SQL Select statement---
    v_select_stmt_str := ' SELECT ' || v_select_columns_stmt_str ||
		 ' FROM ' || v_view_name || ' WHERE ' ||
		 v_key_column_name || '=:source_id' || ---bind variable inside
		 ' AND ROWNUM=1';

    ---5--- Execute Dynamic SQL Select statement---
    -- Open cursor  specify bind argument in USING clause:
    OPEN v_columns_values_cursor FOR v_select_stmt_str
      USING p_source_id;
    -- Fetch rows from result set one at a time:
    LOOP
      FETCH v_columns_values_cursor
        INTO l_source_view_data_tab(1).field_value,
	 l_source_view_data_tab(2).field_value,
	 l_source_view_data_tab(3).field_value,
	 l_source_view_data_tab(4).field_value,
	 l_source_view_data_tab(5).field_value,
	 l_source_view_data_tab(6).field_value,
	 l_source_view_data_tab(7).field_value,
	 l_source_view_data_tab(8).field_value,
	 l_source_view_data_tab(9).field_value,
	 l_source_view_data_tab(10).field_value,
	 l_source_view_data_tab(11).field_value,
	 l_source_view_data_tab(12).field_value,
	 l_source_view_data_tab(13).field_value,
	 l_source_view_data_tab(14).field_value,
	 l_source_view_data_tab(15).field_value,
	 l_source_view_data_tab(16).field_value,
	 l_source_view_data_tab(17).field_value,
	 l_source_view_data_tab(18).field_value,
	 l_source_view_data_tab(19).field_value,
	 l_source_view_data_tab(20).field_value,
	 l_source_view_data_tab(21).field_value,
	 l_source_view_data_tab(22).field_value,
	 l_source_view_data_tab(23).field_value,
	 l_source_view_data_tab(24).field_value,
	 l_source_view_data_tab(25).field_value,
	 l_source_view_data_tab(26).field_value,
	 l_source_view_data_tab(27).field_value,
	 l_source_view_data_tab(28).field_value,
	 l_source_view_data_tab(29).field_value,
	 l_source_view_data_tab(30).field_value,
	 l_source_view_data_tab(31).field_value,
	 l_source_view_data_tab(32).field_value,
	 l_source_view_data_tab(33).field_value,
	 l_source_view_data_tab(34).field_value,
	 l_source_view_data_tab(35).field_value,
	 l_source_view_data_tab(36).field_value,
	 l_source_view_data_tab(37).field_value,
	 l_source_view_data_tab(38).field_value,
	 l_source_view_data_tab(39).field_value,
	 l_source_view_data_tab(40).field_value,
	 l_source_view_data_tab(41).field_value,
	 l_source_view_data_tab(42).field_value,
	 l_source_view_data_tab(43).field_value,
	 l_source_view_data_tab(44).field_value,
	 l_source_view_data_tab(45).field_value,
	 l_source_view_data_tab(46).field_value,
	 l_source_view_data_tab(47).field_value,
	 l_source_view_data_tab(48).field_value,
	 l_source_view_data_tab(49).field_value,
	 l_source_view_data_tab(50).field_value;
      EXIT WHEN v_columns_values_cursor%NOTFOUND;
    END LOOP;
    -- Close cursor:
    CLOSE v_columns_values_cursor;

    ---6--- PIPE RESULTS -------------------------------------------------------
    FOR i IN 1 .. v_max_number_of_columns LOOP
      l_source_view_data_rec.seq_no          := l_source_view_data_tab(i)
				.seq_no;
      l_source_view_data_rec.field_name      := l_source_view_data_tab(i)
				.field_name;
      l_source_view_data_rec.field_data_type := l_source_view_data_tab(i)
				.field_data_type;
      l_source_view_data_rec.field_value     := l_source_view_data_tab(i)
				.field_value;
      l_source_view_data_rec.source_name     := l_source_view_data_tab(i)
				.source_name;
      l_source_view_data_rec.source_id       := l_source_view_data_tab(i)
				.source_id;
      l_source_view_data_rec.view_name       := l_source_view_data_tab(i)
				.view_name;

      PIPE ROW(l_source_view_data_rec);
    END LOOP;

    RETURN;

    -- EXCEPTION
    --  WHEN OTHERS THEN
    --   NULL;
  END get_source_view_data;
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
		      p_source_id   IN VARCHAR2) IS
    i NUMBER;
    CURSOR get_source_data IS
      SELECT seq_no,
	 field_name,
	 field_value,
	 source_name,
	 source_id,
	 view_name
      FROM   TABLE(xxobjt_oa2sf_interface_pkg.get_source_view_data(p_source_name, ---'ACCOUNT', ---
					       p_source_id ----'1786040' ---
					       ))
      WHERE  field_name <> 'EMPTY';

  BEGIN

    OPEN get_source_data;
    i := 1;
    LOOP
      FETCH get_source_data
        INTO source_data(i).seq_no,
	 source_data(i).field_name,
	 source_data(i).field_value,
	 source_data(i).source_name,
	 source_data(i).source_id,
	 source_data(i).view_name;
      EXIT WHEN get_source_data%NOTFOUND;
      i := i + 1;
    END LOOP;
  END source_data_query;

  --------------------------------------------------------------------
  --  name:            get_entity_oe_id
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   05/01/2014
  --------------------------------------------------------------------
  --  purpose :        CR 1215 - Customer support SF-OA interfaces
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05/01/2014  yuval tal         initial build
  --------------------------------------------------------------------

  FUNCTION get_entity_oe_id(p_entity VARCHAR2,
		    p_sf_id  VARCHAR2) RETURN VARCHAR2 IS
    l_oe_id VARCHAR2(250) := NULL;
  BEGIN
    CASE p_entity

      WHEN 'CS_REGION' THEN
        SELECT t.name
        INTO   l_oe_id
        FROM   xxsf_serv_cs_region__c t
        WHERE  id = p_sf_id
        AND    rownum = 1;

      WHEN 'OU' THEN
        SELECT t.org_id__c
        INTO   l_oe_id
        FROM   xxsf_serv_operating_unit__c t
        WHERE  id = p_sf_id;

      WHEN 'UPD_SO_HEADER' THEN
        SELECT t.oe_id__c
        INTO   l_oe_id
        FROM   xxsf_serv_order__c t
        WHERE  id = p_sf_id
        AND    rownum = 1;

      WHEN 'UPD_SO_LINE' THEN
        SELECT t.oe_id__c
        INTO   l_oe_id
        FROM   xxsf_serv_line_item__c t
        WHERE  id = p_sf_id
        AND    rownum = 1;

      WHEN 'CONTACT' THEN

        SELECT t.cust_account_role_id
        INTO   l_oe_id
        FROM   hz_cust_account_roles t
        WHERE  attribute1 = p_sf_id;

      WHEN 'ORG' THEN
        /* SELECT attribute6
         INTO l_sf_id
         FROM hr_all_organization_units t
        WHERE organization_id = to_number(p_entity_id);*/

        SELECT t.oe_id__c
        INTO   l_oe_id
        FROM   xxsf_serv_inventory_org__c t
        WHERE  id = p_sf_id;

      WHEN 'PAY_TERM' THEN
        SELECT t.oe_id__c
        INTO   l_oe_id
        FROM   xxsf_serv_payment_term__c t
        WHERE  id = p_sf_id
        AND    rownum = 1;

      WHEN 'FREIGHT_TERMS' THEN
        SELECT t.name
        INTO   l_oe_id
        FROM   xxsf_serv_freight_terms__c t
        WHERE  id = p_sf_id
        AND    rownum = 1;

      WHEN 'ACCOUNT' THEN
        SELECT hca.cust_account_id
        INTO   l_oe_id
        FROM   hz_cust_accounts hca
        WHERE  hca.attribute4 = p_sf_id;
      WHEN 'SITE' THEN
        SELECT hcas.cust_acct_site_id
        INTO   l_oe_id
        FROM   hz_cust_acct_sites_all hcas
        WHERE  hcas.attribute1 = p_sf_id;
      WHEN 'INSTALL_BASE' THEN
        SELECT cii.instance_id
        INTO   l_oe_id
        FROM   csi_item_instances cii
        WHERE  cii.attribute12 = p_sf_id;
      WHEN 'PRICE_ENTRY' THEN
        SELECT qll.list_line_id
        INTO   l_oe_id
        FROM   qp_list_lines qll
        WHERE  qll.attribute1 = p_sf_id;

      WHEN 'PRICE_BOOK' THEN
        SELECT qlh.list_header_id
        INTO   l_oe_id
        FROM   qp_list_headers_all_b qlh
        WHERE  qlh.attribute5 = p_sf_id;
      WHEN 'PRODUCT' THEN
        SELECT mcr.inventory_item_id
        INTO   l_oe_id
        FROM   mtl_cross_references_b mcr
        WHERE  mcr.attribute1 = p_sf_id
	  --  AND mcr.cross_reference = 'Y'
        AND    mcr.cross_reference_type = 'SF';

      WHEN 'ITEMREV' THEN
        SELECT t.revision_id
        INTO   l_oe_id
        FROM   mtl_item_revisions_b t
        WHERE  attribute10 = p_sf_id;
      WHEN 'CURRENCY' THEN

        SELECT t.isocode
        INTO   l_oe_id
        FROM   xxsf_currencytype t
        WHERE  id = p_sf_id
        AND    rownum = 1;

      WHEN 'OPPORTUNITY_NO' THEN
        SELECT t.opportunity_number__c
        INTO   l_oe_id
        FROM   xxsf_opportunity t
        WHERE  id = p_sf_id
        AND    rownum = 1;

      ELSE
        l_oe_id := NULL;
    END CASE;

    RETURN l_oe_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_entity_oe_id;

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
    l_inv_number VARCHAR2(240);
  BEGIN

    SELECT --  l.interface_line_attribute3,
    -- l.interface_line_attribute6,
     hh.trx_number -- inv number
    INTO   l_inv_number
    FROM   ra_customer_trx_lines_all l,
           ra_customer_trx_all       hh

    WHERE  hh.customer_trx_id = l.customer_trx_id
    AND    l.line_type = 'LINE'

    AND    l.interface_line_attribute6 = to_char(p_line_id);
    RETURN l_inv_number;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------------
  --  name:            get_order_hold
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   05/02/2014
  --------------------------------------------------------------------
  --  purpose :   CUST776 - Customer support SF-OA interfaces\CR 1215 - Customer support SF-OA interfaces
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/02/2014  yuval tal        initial build - used in view XXOBJT_OA2SF_ORDER_LINES_V
  --  1.1  15/02/2015  Dalit A. Raviv   CHG0034398 - we found that oracle not allways change  get_order_hold
  --                                    realesed_flag with Y eventhough the order had been released.
  --------------------------------------------------------------------
  FUNCTION get_order_hold(p_header_id NUMBER) RETURN VARCHAR2 IS
    l_hold_desc VARCHAR2(2000);
  BEGIN

    SELECT listagg(hold_name, ', ') within GROUP(ORDER BY header_id, line_id)
    INTO   l_hold_desc
    FROM   xx_oe_holds_history_v t
    WHERE  t.header_id = p_header_id
    AND    t.released_date IS NULL; -- CHG0034398
    --AND    t.released_flag = 'N';
    -- GROUP BY header_id, line_id;

    RETURN l_hold_desc;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'Error';
  END;

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
    -- GROUP BY header_id, line_id;

    RETURN l_hold_desc;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'Error';
  END;

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
  --  1.1  15/02/2015  Dalit A. Raviv    CHG0034398 - SFDC modifications, change logic for PRODUCTS
  --  1.2  08/03/2015  Dalit A. Raviv    CHG0034789 - SF On Hand send t.inventory_item_id instead of p_item_id
  --  1.3  06/04/2015  Yuval Tal         Add  xxobjt_oa2sf_interface_pkg.is_valid_to_sf
  --------------------------------------------------------------------
  PROCEDURE sync_item_on_hand(errbuf       OUT VARCHAR2,
		      retcode      OUT VARCHAR2,
		      p_hours_back IN NUMBER,
		      p_item_id    IN NUMBER) IS

    CURSOR pop_c(c_hours_back IN NUMBER) IS
      SELECT inventory_item_id
      FROM   (SELECT DISTINCT t.inventory_item_id
	  FROM   mtl_material_transactions t
	  WHERE  t.creation_date > SYSDATE - (c_hours_back / 24)
	  AND    (t.inventory_item_id = p_item_id OR p_item_id IS NULL)

	  AND    xxobjt_oa2sf_interface_pkg.is_valid_to_sf('SUBINV',
					   t.subinventory_code || '|' ||
					   t.organization_id) = 1);
    l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
    l_err_code  VARCHAR2(10) := 0;
    l_err_desc  VARCHAR2(2500) := NULL;
    l_count     NUMBER := 0;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    /*l_profile := xxobjt_general_utils_pkg.get_profile_value('XXOBJT_OA2SF_ONHAND_HOURS',
    'SITE',
    NULL); --fnd_profile.value('XXOBJT_OA2SF_ONHAND_HOURS');*/
    FOR pop_r IN pop_c( /*l_profile*/ p_hours_back) LOOP
      IF xxobjt_oa2sf_interface_pkg.is_relate_to_sf(pop_r.inventory_item_id,
				    'PRODUCT',
				    '') = 'Y' THEN
        l_err_code            := 0;
        l_err_desc            := NULL;
        l_oa2sf_rec.source_id := pop_r.inventory_item_id;

        l_oa2sf_rec.source_name := 'ONHAND';
        l_count                 := l_count + 1;
        xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				         p_err_code  => l_err_code, -- o v
				         p_err_msg   => l_err_desc); -- o v

        IF nvl(l_err_code, 0) <> 0 THEN
          errbuf  := 'Failed to insert row for oh-Hand qty - ' ||
	         substr(l_err_desc, 1, 240);
          retcode := 2;
        END IF;
      END IF;
    END LOOP;
    COMMIT;
    errbuf := 'Loaded ' || l_count || ' Items';
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Failed sync_item_on_hand - ' || substr(SQLERRM, 1, 240);
      retcode := 2;
  END sync_item_on_hand;

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
			   retcode OUT VARCHAR2) IS

    CURSOR c_rate IS
      SELECT *
      FROM   xxobjt_oa2sf_secondary_price_v t
      WHERE  t.sf_parent_price_list_id IS NOT NULL
      AND    t.sf_list_header_id IS NOT NULL;

    l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
    l_err_code  VARCHAR2(10) := 0;
    l_err_desc  VARCHAR2(2500) := NULL;
  BEGIN
    errbuf  := NULL;
    retcode := 0;

    FOR pop_r IN c_rate LOOP
      l_err_code              := 0;
      l_err_desc              := NULL;
      l_oa2sf_rec.source_id   := pop_r.parent_price_list_id || '-' ||
		         pop_r.list_header_id;
      l_oa2sf_rec.source_name := 'SEC_PRICEBOOK';
      xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				       p_err_code  => l_err_code, -- o v
				       p_err_msg   => l_err_desc); -- o v

      IF nvl(l_err_code, 0) <> 0 THEN
        errbuf  := 'Failed to insert row for sync_daily_rate - ' ||
	       substr(l_err_desc, 1, 240);
        retcode := 2;
      END IF;
    END LOOP;
    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Failed sync_daily_rate - ' || substr(SQLERRM, 1, 240);
      retcode := 2;
  END;

  --------------------------------------------------------------------
  --  name:            sync_daily_rate
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   06/01/2014
  --------------------------------------------------------------------
  --  purpose :        procedure will craete new records for bpel rate sync process
  --                   source=CUR_RATE source_id =to cuurency_code
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/01/2014  yuval tal    initial build
  --  1.1 11.2.18      yuval tal    CHG0042336 add event for strataforce
  --------------------------------------------------------------------
  PROCEDURE sync_daily_rate(errbuf  OUT VARCHAR2,
		    retcode OUT VARCHAR2) IS

    CURSOR c_rate IS
      SELECT *
      FROM   xxobjt_oa2sf_currency_v;

    l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
    l_err_code  VARCHAR2(10) := 0;
    l_err_desc  VARCHAR2(2500) := NULL;
  BEGIN
    errbuf  := NULL;
    retcode := 0;

    FOR pop_r IN c_rate LOOP
      l_err_code              := 0;
      l_err_desc              := NULL;
      l_oa2sf_rec.source_id   := pop_r.to_currency;
      l_oa2sf_rec.source_name := 'CUR_RATE';
      xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				       p_err_code  => l_err_code, -- o v
				       p_err_msg   => l_err_desc); -- o v

      IF nvl(l_err_code, 0) <> 0 THEN
        errbuf  := 'Failed to insert row for sync_daily_rate - ' ||
	       substr(l_err_desc, 1, 240);
        retcode := 2;
      END IF;

      --CHG0042336
      DECLARE

        l_xxssys_event_rec xxssys_events%ROWTYPE;

      BEGIN

        l_xxssys_event_rec             := NULL;
        l_xxssys_event_rec.target_name := 'STRATAFORCE';
        l_xxssys_event_rec.entity_name := 'CURRENCY';
        l_xxssys_event_rec.entity_code := pop_r.to_currency;

        l_xxssys_event_rec.event_name := 'xxobjt_oa2sf_interface_pkg.sync_daily_rate';

        --Insert strataforce event
        xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');

        --
      END;

    END LOOP;
    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Failed sync_daily_rate - ' || substr(SQLERRM, 1, 240);
      retcode := 2;
  END;

  --------------------------------------------------------------------
  --  name:   handle_order_header_event
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   03/03/2014
  --------------------------------------------------------------------
  --  purpose :   CUST776 - Customer support SF-OA interfaces\CR 1215 - Customer support SF-OA interfaces
  --              check if order valid for sync
  --              if Valid then  insert into interface table
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/03/2014  yuval tal        initial build
  --------------------------------------------------------------------
  PROCEDURE handle_order_header_event(errbuf       OUT VARCHAR2,
			  retcode      OUT VARCHAR2,
			  p_header_id  NUMBER,
			  p_event_name VARCHAR2) IS

    l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
    l_err_code  VARCHAR2(10) := 0;
    l_err_desc  VARCHAR2(2500) := NULL;

    CURSOR c_ord IS
      SELECT *
      FROM   oe_order_headers_all t
      WHERE  t.header_id = p_header_id;
  BEGIN
    errbuf  := NULL;
    retcode := 0;

    FOR i IN c_ord LOOP
      -- check sfdc order - update only order source = ?SERVICE SFDC?
      IF i.order_source_id = 1001 AND p_event_name = 'SO_HEADER_UPDATE' THEN
        l_err_code              := 0;
        l_err_desc              := NULL;
        l_oa2sf_rec.source_id   := i.header_id;
        l_oa2sf_rec.source_name := 'UPD_SO_HEADER';
        xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				         p_err_code  => l_err_code, -- o v
				         p_err_msg   => l_err_desc); -- o v

        IF nvl(l_err_code, 0) <> 0 THEN
          errbuf  := 'Failed to insert row for sync_order_header - ' ||
	         substr(l_err_desc, 1, 240);
          retcode := 2;
        END IF;
        COMMIT;
        EXIT;
        -- END IF;

        -- check upsert order mode
      ELSIF is_valid_order_type(i.order_type_id) = 'Y' AND
	i.flow_status_code != 'DRAFT' AND
	NOT
	 (p_event_name = 'SO_HEADER_CREATE' AND i.order_source_id = 1001) THEN

        l_err_code              := 0;
        l_err_desc              := NULL;
        l_oa2sf_rec.source_id   := i.header_id;
        l_oa2sf_rec.source_name := 'SO_HEADER';
        xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				         p_err_code  => l_err_code, -- o v
				         p_err_msg   => l_err_desc); -- o v

        IF nvl(l_err_code, 0) <> 0 THEN
          errbuf  := 'Failed to insert row for sync_order_header - ' ||
	         substr(l_err_desc, 1, 240);
          retcode := 2;
        END IF;
        COMMIT;
        EXIT;
      END IF;
    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Failed sync_daily_rate - ' || substr(SQLERRM, 1, 240);
      retcode := 2;
  END;

  --------------------------------------------------------------------
  --  name:    handle_order_line_event
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   03/03/2014
  --------------------------------------------------------------------
  --  purpose :   CUST776 - Customer support SF-OA interfaces\CR 1215 - Customer support SF-OA interfaces
  --              check if order line valid for sync
  --              if Valid then  insert into interface table
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/03/2014  yuval tal        initial build
  --------------------------------------------------------------------

  PROCEDURE handle_order_line_event(errbuf       OUT VARCHAR2,
			retcode      OUT VARCHAR2,
			p_line_id    NUMBER,
			p_event_name VARCHAR2) IS

    l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
    l_err_code  VARCHAR2(10) := 0;
    l_err_desc  VARCHAR2(2500) := NULL;

    CURSOR c_ord IS
      SELECT h.*
      FROM   oe_order_headers_all h,
	 oe_order_lines_all   l
      WHERE  h.header_id = l.header_id
      AND    l.line_id = p_line_id;
  BEGIN
    errbuf  := NULL;
    retcode := 0;

    FOR i IN c_ord LOOP
      -- check sfdc order - update only order source = ?SERVICE SFDC?
      IF i.order_source_id = 1001 AND
         p_event_name IN ('SO_LINE_CREATE', 'SO_LINE_UPDATE') THEN
        l_err_code              := 0;
        l_err_desc              := NULL;
        l_oa2sf_rec.source_id   := p_line_id;
        l_oa2sf_rec.source_name := 'UPD_SO_LINE'; -- BPEL UPDATE
        xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				         p_err_code  => l_err_code, -- o v
				         p_err_msg   => l_err_desc); -- o v

        IF nvl(l_err_code, 0) <> 0 THEN
          errbuf  := 'Failed to insert row for sync_order_line - ' ||
	         substr(l_err_desc, 1, 240);
          retcode := 2;
        END IF;
        COMMIT;
        -- END IF;

        -- check upsert line mode
      ELSIF is_valid_order_type(i.order_type_id) = 'Y' AND
	NOT
	 (p_event_name = 'SO_LINE_CREATE' AND i.order_source_id = 1001) THEN

        l_err_code              := 0;
        l_err_desc              := NULL;
        l_oa2sf_rec.source_id   := p_line_id;
        l_oa2sf_rec.source_name := 'SO_LINE'; -- BPEL UPSERT
        xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				         p_err_code  => l_err_code, -- o v
				         p_err_msg   => l_err_desc); -- o v

        IF nvl(l_err_code, 0) <> 0 THEN
          errbuf  := 'Failed to insert row for sync_order_header - ' ||
	         substr(l_err_desc, 1, 240);
          retcode := 2;
        END IF;
        COMMIT;
        EXIT;
      END IF;

    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Failed sync_order_line - ' || substr(SQLERRM, 1, 240);
      retcode := 2;
  END;

  --------------------------------------------------------------------
  --  name:    handle_ar_cust_trx_lines_event
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   03/03/2014
  --------------------------------------------------------------------
  --  purpose :   CUST776 - Customer support SF-OA interfaces\CR 1215 - Customer support SF-OA interfaces
  --              check if ar trx  valid for sync
  --              if Valid then  insert into interface table
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/03/2014  yuval tal        initial build
  --------------------------------------------------------------------

  PROCEDURE handle_ar_cust_trx_lines_event(errbuf            OUT VARCHAR2,
			       retcode           OUT VARCHAR2,
			       p_customer_trx_id NUMBER,
			       p_event_name      VARCHAR2) IS

    l_err_code VARCHAR2(10) := 0;
    -- l_err_desc   VARCHAR2(2500) := NULL;
    l_oe_line_id NUMBER;
    CURSOR c_ord IS
      SELECT l.interface_line_attribute6 -- inv number
      INTO   l_oe_line_id
      FROM   ra_customer_trx_lines_all l
      WHERE  l.customer_trx_line_id = p_customer_trx_id
      AND    l.line_type = 'LINE'
      AND    l.interface_line_context IN ('ORDER ENTRY', 'INTERCOMPANY');

  BEGIN
    errbuf  := NULL;
    retcode := 0;

    FOR i IN c_ord LOOP
      handle_order_line_event(errbuf,
		      l_err_code,
		      l_oe_line_id,
		      'SO_LINE_UPDATE');
      retcode := greatest(retcode, l_err_code);
    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Failed handle_ar_cust_trx_lines_event - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 2;
  END;

  --------------------------------------------------------------------
  --  name:    handle_om_hold_event
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   03/03/2014
  --------------------------------------------------------------------
  --  purpose :   CUST776 - Customer support SF-OA interfaces\CR 1215 - Customer support SF-OA interfaces
  --              check if hold id   valid for sync  order header/line
  --              if Valid then  insert into interface table
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/03/2014  yuval tal        initial build
  --------------------------------------------------------------------

  PROCEDURE handle_om_hold_event(errbuf          OUT VARCHAR2,
		         retcode         OUT VARCHAR2,
		         p_order_hold_id NUMBER,
		         p_event_name    VARCHAR2) IS

    --  l_err_code   VARCHAR2(10) := 0;
    --  l_err_desc   VARCHAR2(2500) := NULL;
    --  l_oe_line_id NUMBER;
    CURSOR c_ord IS
      SELECT *
      FROM   oe_order_holds_all l
      WHERE  l.order_hold_id = p_order_hold_id;

  BEGIN
    errbuf  := NULL;
    retcode := 0;

    FOR i IN c_ord LOOP
      IF i.line_id IS NOT NULL THEN
        handle_order_line_event(errbuf,
		        retcode,
		        i.line_id,
		        'SO_LINE_UPDATE');
      ELSE
        handle_order_header_event(errbuf,
		          retcode,
		          i.header_id,
		          'SO_HEADER_UPDATE');
      END IF;
    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Failed handle_om_hold_event - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 2;
  END;

  --------------------------------------------------------------------
  --  name:    handle_asset_event
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   03/03/2014
  --------------------------------------------------------------------
  --  purpose :   CUST776 - Customer support SF-OA interfaces\CR 1215 - Customer support SF-OA interfaces
  --             event name ='INSTALL_BASE_SHIPED'
  --              1. support syc install base sold to customer from stock (include  ib configuration)
  --              2. Transfer to SF install base in stock that marked manually

  -- event name = INSTALL_BASE_UPGRADE
  --              1. populate interface table with machine
  --              2. populate interface table with  related hasp of above machine
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/03/2014  yuval tal        initial build
  --  1.1  12/03/2015  Dalit A. Raviv   CHG0034735 - add event_name, add parameter
  -- 1.2  2.4.18      yuval tal         CHG0042619 - move att12 logic check  from db trigger XXCSI_I_PARTIES_H_BIR_TRG
  --------------------------------------------------------------------
  PROCEDURE handle_asset_event(errbuf        OUT VARCHAR2,
		       retcode       OUT VARCHAR2,
		       p_instance_id NUMBER,
		       p_event_name  VARCHAR2,
		       p_upgrade_kit VARCHAR2 DEFAULT NULL) IS

    l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
    l_err_code  VARCHAR2(10) := 0;
    l_err_desc  VARCHAR2(2500) := NULL;

    CURSOR c_asset(c_instance_id NUMBER) IS
      SELECT 1
      FROM   (SELECT cii.instance_id,
	         cii.serial_number,
	         msib.segment1,
	         msib.description
	  FROM   csi_i_parties_h        h,
	         csi_item_instances_h   hi,
	         csi_instance_details_v cid,
	         hz_parties             hp1,
	         hz_parties             hp2,
	         csi_item_instances     cii,
	         mtl_system_items_b     msib
	  WHERE  hi.transaction_id = h.transaction_id
	  AND    hi.instance_id = cii.instance_id
	  AND    cid.instance_id = cii.instance_id
	  AND    nvl(h.old_party_id, 10041) = hp1.party_id
	  AND    h.new_party_id = hp2.party_id
	  AND    nvl(h.old_party_id, 10041) <> h.new_party_id
	  AND    msib.organization_id = 91
	  AND    cii.inventory_item_id = msib.inventory_item_id
	  AND    nvl(h.old_party_id, 10041) = 10041
	  AND    cii.active_end_date IS NULL
	  AND    cii.serial_number IS NOT NULL
	  AND    cii.instance_status_id = 10002
	  UNION ALL
	  -- Created machines that marked manually by CS admin in Oracle.
	  SELECT cii.instance_id,
	         cii.serial_number,
	         msib.segment1,
	         msib.description
	  FROM   csi_item_instances cii,
	         mtl_system_items_b msib
	  WHERE  msib.organization_id = 91
	  AND    cii.inventory_item_id = msib.inventory_item_id
	  AND    cii.owner_party_id = 10041
	  AND    cii.active_end_date IS NULL
	  AND    cii.serial_number IS NOT NULL
	  AND    cii.attribute16 = 'Y')
      WHERE  instance_id = c_instance_id;

    -- check scrap has account alias issue transaction
    CURSOR c_scrap(c_instance_id NUMBER) IS
      SELECT 1
      FROM   mtl_material_transactions mmt,
	 mtl_unit_transactions     mut,
	 csi_item_instances        cii
      WHERE  mmt.transaction_type_id IN (1, 4, 8, 32, 31, 63)
      AND    mmt.inventory_item_id = mut.inventory_item_id
      AND    mmt.transaction_id = mut.transaction_id
      AND    mmt.organization_id = mut.organization_id
      AND    mut.serial_number IS NOT NULL
      AND    mut.serial_number = cii.serial_number
      AND    cii.instance_id = c_instance_id
      AND    cii.attribute12 IS NOT NULL; --CHG0042619

  BEGIN
    errbuf  := NULL;
    retcode := 0;

    CASE p_event_name
    -- CHG0034735 when event is MACHINE_UPGRADE attribute1 at the event table will hold
    -- the information of upgrade kit (product_id). at the view that will base on the interface
    -- tbl we will bring the name of the upgrade kit (product name)
      WHEN 'MACHINE_UPGRADE' THEN
        l_oa2sf_rec.process_mode := '';
        l_oa2sf_rec.source_id    := p_instance_id;
        l_oa2sf_rec.source_id2   := p_upgrade_kit; -- 1.1 12/03/2015 Dalit A. Raviv CHG0034735 - add handle for upgrade kit
        l_oa2sf_rec.source_name  := 'MACHINE_UPGRADE';
        xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				         p_err_code  => l_err_code, -- o v
				         p_err_msg   => l_err_desc);
      WHEN 'HASP_UPGRADE' THEN
        l_oa2sf_rec.process_mode := '';
        l_oa2sf_rec.source_id    := p_instance_id;
        l_oa2sf_rec.source_name  := 'HASP_UPGRADE';
        xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				         p_err_code  => l_err_code, -- o v
				         p_err_msg   => l_err_desc);
      WHEN 'INSTALL_BASE_SHIP' THEN
        FOR i IN c_asset(p_instance_id) LOOP
          l_oa2sf_rec.source_id := p_instance_id;
          --CHG0042619
          IF get_entity_sf_id('INSTALL_BASE', p_instance_id) IS NOT NULL THEN
	l_oa2sf_rec.source_name := 'MACHINE_RESHIP';
          ELSE
	l_oa2sf_rec.source_name := 'INSTALL_BASE';
          END IF;
          -- end CHG0042619
          xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				           p_err_code  => l_err_code, -- o v
				           p_err_msg   => l_err_desc);
        END LOOP;
      WHEN 'MACHINE_SCRAP' THEN
        FOR i IN c_scrap(p_instance_id) LOOP
          l_oa2sf_rec.process_mode := '';
          l_oa2sf_rec.source_id    := p_instance_id;
          l_oa2sf_rec.source_name  := 'MACHINE_SCRAP';
          xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				           p_err_code  => l_err_code, -- o v
				           p_err_msg   => l_err_desc);
        END LOOP;

    --  1.1 12/03/2015 Dalit A. Raviv CHG0034735 - add event_name
      WHEN 'MACHINE_RETURN' THEN
        l_oa2sf_rec.process_mode := '';
        l_oa2sf_rec.source_id    := p_instance_id;
        l_oa2sf_rec.source_name  := 'MACHINE_RETURN';
        xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				         p_err_code  => l_err_code, -- o v
				         p_err_msg   => l_err_desc);

      WHEN 'MACHINE_RESHIP' THEN
        l_oa2sf_rec.process_mode := '';
        l_oa2sf_rec.source_id    := p_instance_id;
        --CHG0042619
        IF get_entity_sf_id('INSTALL_BASE', p_instance_id) IS NOT NULL THEN
          l_oa2sf_rec.source_name := 'MACHINE_RESHIP';
        ELSE
          l_oa2sf_rec.source_name := 'INSTALL_BASE';
        END IF;
        -- end CHG0042619

        --  l_oa2sf_rec.source_name  := 'MACHINE_RESHIP';
        xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				         p_err_code  => l_err_code, -- o v
				         p_err_msg   => l_err_desc);
      ELSE
        NULL;
    END CASE;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Failed handle_asset_event - ' || substr(SQLERRM, 1, 240);
      retcode := 2;
  END;

  --------------------------------------------------------------------
  --  name:    handle_events
  --  create by:       YUVAL TAL
  --  Revision:        1.0
  --  creation date:   03/03/2014
  --------------------------------------------------------------------
  --  purpose :   CUST776 - Customer support SF-OA interfaces\CR 1215 - Customer support SF-OA interfaces
  --              look for all new events IN TABLE xxobjt_custom_events
  --              and split it if needed for unit handling
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/03/2014  yuval tal        initial build
  --  1.1  12/03/2015  Dalit A. Raviv   CHG0034735 - add event_name
  -------------------------------------------------------------------
  PROCEDURE handle_events(errbuf  OUT VARCHAR2,
		  retcode OUT VARCHAR2) IS

    CURSOR c_event IS
      SELECT *
      FROM   xxobjt_custom_events t
      -- WHERE t.creation_date > SYSDATE - 1 / 24
      WHERE  t.event_id >
	 nvl(fnd_profile.value('XXOA2SF_LAST_EVENT_ID'), 0)
      ORDER  BY t.event_id;
    l_err_code VARCHAR2(10);
    l_ret      BOOLEAN;
    l_event_id NUMBER;

    l_event_rec xxobjt_custom_events%ROWTYPE;
  BEGIN
    retcode := 0;
    fnd_file.put_line(fnd_file.log, 'Event     Event key');
    fnd_file.put_line(fnd_file.log, '--------------------');

    dbms_output.put_line('profile=' ||
		 fnd_profile.value('XXOA2SF_LAST_EVENT_ID'));
    FOR i IN c_event LOOP
      l_event_id := i.event_id;
      fnd_file.put_line(fnd_file.log,
		i.event_name || '        ' || i.event_key);
      l_event_rec := i;
      CASE i.event_name
        WHEN 'SO_HEADER_CREATE' THEN
          handle_order_header_event(errbuf,
			l_err_code,
			i.event_key,
			'SO_HEADER_CREATE');
        WHEN 'SO_HEADER_UPDATE' THEN
          handle_order_header_event(errbuf,
			l_err_code,
			i.event_key,
			'SO_HEADER_UPDATE');
        WHEN 'SO_LINE_CREATE' THEN
          handle_order_line_event(errbuf,
		          l_err_code,
		          i.event_key,
		          i.event_name);
        WHEN 'SO_LINE_UPDATE' THEN
          handle_order_line_event(errbuf,
		          l_err_code,
		          i.event_key,
		          i.event_name);
        WHEN 'SO_HOLD_CREATE' THEN
          handle_om_hold_event(errbuf,
		       l_err_code,
		       i.event_key,
		       i.event_name);
        WHEN 'SO_HOLD_UPDATE' THEN
          handle_om_hold_event(errbuf,
		       l_err_code,
		       i.event_key,
		       i.event_name);
        WHEN 'RA_TRX_CREATE' THEN
          handle_ar_cust_trx_lines_event(errbuf,
			     l_err_code,
			     i.event_key,
			     i.event_name);
          -- 1.1 12/03/2015 Dalit A. Raviv CHG0034735 add send attribute1
      -- when event is MACHINE_UPGRADE attribute1 at the event table will hold
      -- the information of upgrade kit (product_id)
        WHEN 'INSTALL_BASE_SHIP' THEN
          handle_asset_event(errbuf,
		     l_err_code,
		     i.event_key,
		     i.event_name,
		     NULL);
        WHEN 'INSTALL_BASE_UPGRADE' THEN
          handle_asset_event(errbuf,
		     l_err_code,
		     i.event_key,
		     i.event_name,
		     NULL);
          -- 1.1 12/03/2015 Dalit A. Raviv CHG0034735 add event to handle for asset.
        WHEN 'MACHINE_UPGRADE' THEN
          handle_asset_event(errbuf,
		     l_err_code,
		     i.event_key,
		     i.event_name,
		     i.attribute1);
        WHEN 'HASP_UPGRADE' THEN
          handle_asset_event(errbuf,
		     l_err_code,
		     i.event_key,
		     i.event_name,
		     NULL);
        WHEN 'MACHINE_SCRAP' THEN
          handle_asset_event(errbuf,
		     l_err_code,
		     i.event_key,
		     i.event_name,
		     NULL);
        WHEN 'MACHINE_RETURN' THEN
          handle_asset_event(errbuf,
		     l_err_code,
		     i.event_key,
		     i.event_name,
		     NULL);
        WHEN 'MACHINE_RESHIP' THEN
          handle_asset_event(errbuf,
		     l_err_code,
		     i.event_key,
		     i.event_name,
		     NULL);
          -- end 1.1
        ELSE
          NULL;
      END CASE;
      retcode := greatest(l_err_code, retcode);
    END LOOP;

    fnd_file.put_line(fnd_file.log, 'Last event id = ' || l_event_id);
    IF l_event_id IS NOT NULL THEN
      l_ret := fnd_profile_server.save(x_name       => 'XXOA2SF_LAST_EVENT_ID',
			   x_value      => l_event_id, --NULL,
			   x_level_name => 'SITE');
    END IF;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Failed xxobjt_oa2sf_interface_pkg.handle_events  - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 2;
  END;

  --------------------------------------------
  -- Check_quantity_available
  -- use in bpel materialTransfer : fieldServeiceUsage

  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/03/2014  yuval tal        initial build
  --------------------------------------------------------------------

  PROCEDURE check_quantity_available(p_organization_id   NUMBER,
			 p_subinventory_code VARCHAR2,
			 p_inventory_item_id NUMBER,
			 p_revision          VARCHAR2,
			 p_quantity          NUMBER,
			 p_err_code          OUT NUMBER,
			 p_err_message       OUT VARCHAR2) IS

    l_api_return_status VARCHAR2(1);
    l_qty_oh            NUMBER;
    l_qty_res_oh        NUMBER;
    l_qty_res           NUMBER;
    l_qty_sug           NUMBER;
    l_qty_att           NUMBER;
    l_qty_atr           NUMBER;
    l_msg_count         NUMBER;
    l_msg_data          VARCHAR2(1000);

    l_is_revision_control      NUMBER;
    l_is_lot_control           NUMBER;
    l_is_serial_control        NUMBER;
    l_is_revision_control_bool BOOLEAN;
    l_is_lot_control_bool      BOOLEAN;
    l_is_serial_control_bool   BOOLEAN;

  BEGIN
    p_err_code := 0;
    IF nvl(p_quantity, 0) = 0 THEN
      p_err_code    := 1;
      p_err_message := 'Quantity need to be greater then 0';
      RETURN;
    END IF;

    SELECT decode(nvl(t.lot_control_code, 1), 2, 1, 0) lot_control_code,
           decode(nvl(t.serial_number_control_code, 1), 1, 0, 1) serial_number_control_code,
           decode(nvl(t.revision_qty_control_code, 1), 2, 1, 0) revision_control_code
    INTO   l_is_lot_control,
           l_is_serial_control,
           l_is_revision_control
    FROM   mtl_system_items_b t
    WHERE  t.inventory_item_id = p_inventory_item_id
    AND    t.organization_id = 91;

    l_is_revision_control_bool := sys.diutil.int_to_bool(l_is_revision_control);
    l_is_lot_control_bool      := sys.diutil.int_to_bool(l_is_lot_control);
    l_is_serial_control_bool   := sys.diutil.int_to_bool(l_is_serial_control);
    -- fnd_global.apps_initialize(4290, 0, 0, 0);

    inv_quantity_tree_grp.clear_quantity_cache;

    -- dbms_output.put_line('Transaction Mode');

    inv_quantity_tree_pub.query_quantities(p_api_version_number  => 1.0,
			       p_init_msg_lst        => fnd_api.g_true,
			       x_return_status       => l_api_return_status,
			       x_msg_count           => l_msg_count,
			       x_msg_data            => l_msg_data,
			       p_organization_id     => p_organization_id,
			       p_inventory_item_id   => p_inventory_item_id,
			       p_tree_mode           => inv_quantity_tree_pub.g_transaction_mode,
			       p_onhand_source       => 3,
			       p_is_revision_control => l_is_revision_control_bool,
			       p_is_lot_control      => l_is_lot_control_bool,
			       p_is_serial_control   => l_is_serial_control_bool,
			       p_revision            => p_revision,
			       p_lot_number          => NULL,
			       p_subinventory_code   => p_subinventory_code,
			       p_locator_id          => NULL,
			       x_qoh                 => l_qty_oh,
			       x_rqoh                => l_qty_res_oh,
			       x_qr                  => l_qty_res,
			       x_qs                  => l_qty_sug,
			       x_att                 => l_qty_att,
			       x_atr                 => l_qty_atr);

    /*    dbms_output.put_line('Quantity on hand ======================> ' ||
                         to_char(l_qty_oh));
    dbms_output.put_line('Reservable quantity on hand ===============> ' ||
                         to_char(l_qty_res_oh));
    dbms_output.put_line('Quantity reserved =====================> ' ||
                         to_char(l_qty_res));
    dbms_output.put_line('Quantity suggested ====================> ' ||
                         to_char(l_qty_sug));
    dbms_output.put_line('Quantity Available To Transact ==============> ' ||
                         to_char(l_qty_att));
    dbms_output.put_line('Quantity Available To Reserve ==============> ' ||
                         to_char(l_qty_atr));*/

    IF nvl(l_api_return_status, 'x') != 'S' THEN
      p_err_code    := 1;
      p_err_message := 'Unable to calc onHand Quantity:' ||
	           substr(SQLERRM, 1, 255);
    ELSIF abs(p_quantity) > l_qty_att THEN
      p_err_code    := 1;
      p_err_message := 'Transaction Failed : Item ' ||
	           xxinv_utils_pkg.get_item_segment(p_inventory_item_id,
				        91) ||
	           ' no quantity available (available:' || l_qty_att ||
	           ' , requested:' || p_quantity || ')';
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := 'Unable to calc onHand Quantity:' ||
	           substr(SQLERRM, 1, 255);
  END;
  ---------------------------------------------------------------------
  -- get_item_dist_account_id
  -- use in bpel materialTransfer : fieldServeiceUsage
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/03/2014  yuval tal        initial build
  --------------------------------------------------------------------

  PROCEDURE get_item_dist_account_id(p_organization_id       NUMBER,
			 p_inventory_item_id     NUMBER,
			 p_cost_of_sales_account OUT NUMBER,
			 p_err_code              OUT NUMBER,
			 p_err_message           OUT VARCHAR2) IS
  BEGIN
    p_err_code := 0;

    SELECT t.cost_of_sales_account
    INTO   p_cost_of_sales_account
    FROM   mtl_system_items_b t
    WHERE  t.inventory_item_id = p_inventory_item_id
    AND    t.organization_id = p_organization_id;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
  END;

  ---------------------------------------------------------------------
  -- get_item_dist_account_id
  -- use in bpel materialTransfer : fieldServeiceUsage
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/03/2014  yuval tal        initial build
  --------------------------------------------------------------------
  PROCEDURE get_material_trx_info(p_err_code    OUT NUMBER,
		          p_err_message OUT VARCHAR2,
		          p_tab         IN OUT xxobjt_oa2sf_material_tab_type) IS
  BEGIN
    dbms_output.put_line('x' || p_tab.count);

    p_err_code := 0;

    IF p_tab.count = 0 THEN

      p_err_code    := 1;
      p_err_message := 'No data passed to get_material_trx_info';
      RETURN;
    END IF;

    FOR i IN p_tab.first .. p_tab.last LOOP
      IF p_tab(i).organization_id IS NULL THEN
        p_err_code    := 1;
        p_err_message := 'Line: ' || i ||
		 ' field organization_id is required';
        RETURN;
      END IF;

      IF p_tab(i).inventory_item_id IS NULL THEN
        p_err_code    := 1;
        p_err_message := 'Line: ' || i ||
		 ' field inventory_item_id is required';
        RETURN;
      END IF;

      IF p_tab(i).subinventory_code IS NULL THEN
        p_err_code    := 1;
        p_err_message := 'Line: ' || i ||
		 ' field subinventory_code is required';
        RETURN;
      END IF;

      IF p_tab(i).quantity_trx IS NULL THEN
        p_err_code    := 1;
        p_err_message := 'Line: ' || i || ' field quantity_trx is required';
        RETURN;
      END IF;

      dbms_output.put_line('x');
      p_tab(i).err_code := 0;
      --  p_tab(i).cost_of_sales_account := 5;

      get_item_dist_account_id(p_tab(i).organization_id,
		       p_tab(i).inventory_item_id,
		       p_tab(i).cost_of_sales_account,
		       p_tab(i).err_code,
		       p_tab(i).err_message);

      IF p_tab(i).err_code = 1 THEN
        p_err_code    := 1;
        p_err_message := p_tab(i).err_message;
        EXIT;
      END IF;

      check_quantity_available(p_tab(i).organization_id,
		       p_tab(i).subinventory_code,
		       p_tab(i).inventory_item_id,
		       p_tab(i).revision,
		       abs(p_tab(i).quantity_trx),
		       p_tab(i).err_code,
		       p_tab(i).err_message);

      IF p_tab(i).err_code = 1 THEN
        p_err_code    := 1;
        p_err_message := p_tab(i).err_message;
        EXIT;
      END IF;

    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;

  END;

  --------------------------------------------------------------------
  --  name:            submit_pull_requestset
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   02.06.14
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  02.06.14    yuval tal         initial build -- call from bpel process sf2oa_UtilServices
  --  1.1  26/11/2014  Dalit A. Raviv    CHG0033803 prevent from SFDC to call multiple times to accounts/sites/contac
  --------------------------------------------------------------------
  PROCEDURE submit_pull_requestset(p_source      VARCHAR2,
		           p_request_id  OUT NUMBER,
		           p_err_code    OUT VARCHAR2,
		           p_err_message OUT VARCHAR2) IS

    success BOOLEAN;
    l_count NUMBER;
    submit_failed EXCEPTION;
    l_err_code NUMBER := 0;
    l_err_msg  VARCHAR2(2500) := NULL;

  BEGIN
    p_err_code := 0;
    --  1.1  26/11/2014  Dalit A. Raviv CHG0033803
    -- check if the set or one of the program in the set is in phase running or Pause
    -- If yes do nothing, else submit the set.
    SELECT COUNT(1)
    INTO   l_count
    FROM   fnd_conc_req_summary_v v
    WHERE  program_short_name IN ('XXOBJTSF2OAINIT', 'XXOBJT_SF2OA_SET')
          --and    concurrent_program_id  in ( 274402, 141372)-- XXOBJT_SF2OA_SET/XX: SalesForce to Oracle Initiate Process
    AND    phase_code IN ('P', 'R') -- P = Pause R = Running
    AND    requestor = 'SALESFORCE';

    IF l_count > 0 THEN
      p_err_code    := 0;
      p_err_message := 'Program is already running or pending to run';
    ELSE
      fnd_global.apps_initialize(user_id      => 4290, -- SALESFORCE
		         resp_id      => 51137, -- CRM Service Super User Objet
		         resp_appl_id => 514); -- Support (obsolete)

      /* set the context for the request set XXOBJT_SF2OA_SET */
      IF p_source IS NULL THEN
        success := fnd_submit.set_request_set('XXOBJT', 'XXOBJT_SF2OA_SET');

        IF (success) THEN
          --  IF instr(upper(p_source), 'ACCOUNT') > 0 THEN
          /* submit program XXOBJTSF2OAINIT which is in stage STAGE1 */
          success := fnd_submit.submit_program('XXOBJT',
			           'XXOBJTSF2OAINIT',
			           'ACCOUNT',
			           'ACCOUNT',
			           chr(0));
          IF (NOT success) THEN
	RAISE submit_failed;
          END IF;
          --   END IF;

          --   IF instr(upper(p_source), 'CONTACT') > 0 THEN
          /* submit program XXOBJTSF2OAINIT which is in stage STAGE2  */
          success := fnd_submit.submit_program('XXOBJT',
			           'XXOBJTSF2OAINIT',
			           'CONTACT',
			           'CONTACT',
			           chr(0));
          IF (NOT success) THEN
	RAISE submit_failed;
          END IF;
          --  END IF;
          --  IF instr(upper(p_source), 'SITE') > 0 THEN
          /* submit program XXOBJTSF2OAINIT which is in stage STAGE1 */
          success := fnd_submit.submit_program('XXOBJT',
			           'XXOBJTSF2OAINIT',
			           'SITE',
			           'SITE',
			           chr(0));
          IF (NOT success) THEN
	RAISE submit_failed;
          END IF;
          --  END IF;
          /*  Submit the Request set  */
          p_request_id := fnd_submit.submit_set(NULL, FALSE);
          COMMIT;
        ELSE
          --  1.1  26/11/2014  Dalit A. Raviv CHG0033803
          RAISE submit_failed;
        END IF; -- success
      END IF; -- p_source
    END IF; -- l_count

  EXCEPTION
    --  1.1  26/11/2014  Dalit A. Raviv CHG0033803
    WHEN submit_failed THEN
      xxobjt_wf_mail.send_mail_text(p_to_role     => 'SYSADMIN', -- i v
			p_cc_mail     => NULL, -- i v
			p_bcc_mail    => NULL, -- i v
			p_subject     => 'Can not Submit request', -- i v
			p_body_text   => 'xxobjt_oa2sf_interface_pkg.submit_pull_requestset - ' ||
				     substr(fnd_message.get,
					1,
					240), -- i v
			p_att1_proc   => NULL, -- i v
			p_att2_proc   => NULL, -- i v
			p_att3_proc   => NULL, -- i v
			p_err_code    => l_err_code, -- o n
			p_err_message => l_err_msg); -- o v
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := fnd_message.get || ' ' || SQLERRM;
  END submit_pull_requestset;

  --------------------------------------------------------------------
  --  name:            purge_objct_interface_tables
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   07/01/2015
  --------------------------------------------------------------------
  --  purpose :        CHG00340083
  --                   Purge object interface tables
  --                   Concurrent executable:
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/01/2015  Michal Tzvik    initial build
  --  1.1  25/05/2015  Michal Tzvik    if p_status = ERR then don't delete latest record of each source and source_id
  --------------------------------------------------------------------
  PROCEDURE purge_objct_interface_tables(errbuf      OUT VARCHAR2,
			     retcode     OUT VARCHAR2,
			     p_days_back IN NUMBER,
			     p_status    IN VARCHAR2) IS

    l_cnt NUMBER := 0;
  BEGIN
    errbuf  := '';
    retcode := '0';

    fnd_file.put_line(fnd_file.log, 'Parameters:');
    fnd_file.put_line(fnd_file.log, '-----------');
    fnd_file.put_line(fnd_file.log, 'p_days_back:  ' || p_days_back);
    fnd_file.put_line(fnd_file.log, 'p_status:     ' || p_status);
    fnd_file.put_line(fnd_file.log, '');
    fnd_file.put_line(fnd_file.log, '');

    /* DELETE FROM xxobjt_oa2sf_interface xoi
    WHERE  1 = 1
    AND    xoi.creation_date < SYSDATE - p_days_back
    AND    xoi.status = nvl(p_status, xoi.status);*/
    -- 1.1  Michal Tzvik
    /*DELETE FROM xxobjt_oa2sf_interface xoi
    WHERE  1 = 1
    AND    xoi.creation_date < SYSDATE - p_days_back
    AND    xoi.status = nvl(p_status, xoi.status)
    AND    (xoi.status != 'ERR' OR
          xoi.oracle_event_id NOT IN
          (SELECT MAX(xoi1.oracle_event_id) -- keep(dense_rank FIRST ORDER BY xoi.creation_date)
             FROM   xxobjt_oa2sf_interface xoi1
             WHERE  xoi1.creation_date < SYSDATE - p_days_back
             AND    xoi1.status = 'ERR'
             AND    xoi1.source_name = xoi.source_name
             AND    xoi1.source_id = xoi.source_id));*/
    DELETE FROM xxobjt_oa2sf_interface xoi
    WHERE  1 = 1
    AND    xoi.creation_date < SYSDATE - p_days_back
    AND    xoi.status = nvl(p_status, xoi.status)
    AND    xoi.oracle_event_id IN
           (SELECT oracle_event_id
	 FROM   (SELECT oracle_event_id,
		    rank() over(PARTITION BY t.source_name, t.status, t.source_id, t.source_id2 ORDER BY t.creation_date DESC) rn
	         FROM   xxobjt_oa2sf_interface t
	         WHERE  status = nvl(p_status, t.status)
	         AND    t.creation_date < SYSDATE - p_days_back)
	 WHERE  rn >= 2 --AND ROWNUM<1000
	 );

    l_cnt := SQL%ROWCOUNT;
    COMMIT;
    IF l_cnt > 0 THEN
      fnd_file.put_line(fnd_file.log,
		l_cnt ||
		' interface lines were deleted successfully.');
    ELSE
      fnd_file.put_line(fnd_file.log, 'No line was deleted.');
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Unexpected error';
      retcode := '1';
      fnd_file.put_line(fnd_file.log, 'Unexpected error: ' || SQLERRM);
  END purge_objct_interface_tables;

  --------------------------------------------------------------------
  --  name:            is_account_merged
  --  Revision:        CHG0041509
  --  creation date:   21.11.17
  --------------------------------------------------------------------
  --  purpose :        avoid sync merged accounts return Y/N
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21.11.17   yuval tal         CHG0041509 initial build

  FUNCTION is_account_merged(p_account_number VARCHAR2) RETURN VARCHAR2 IS
    l_tmp VARCHAR2(1);
  BEGIN
    SELECT 'Y'
    INTO   l_tmp
    FROM   ra_customer_merge_headers /*xxobjt_oa2sf_acc_merge_v*/
    WHERE  duplicate_number = p_account_number;
    -- AND    status = 'I';

    RETURN l_tmp;

  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';

  END;
  ------------------------------------------------------------------------------------
  -- Ver      Who        When            Description
  -- -------  ---------  -------------   ---------------------------------------------
  -- 1.0      Roman.W    02/04/2018      CHG0042619 - Install base interface
  --                                                  from Oracle to salesforce
  ------------------------------------------------------------------------------------
  FUNCTION get_sf_parent_instance_id(parent_instance_id NUMBER) RETURN NUMBER IS
    -----------------------------
    --    Local Definition
    -----------------------------
    l_return_val NUMBER;
    -----------------------------
    --    Code Section
    -----------------------------
  BEGIN
    RETURN NULL;
  EXCEPTION
    WHEN OTHERS THEN
      l_return_val := NULL;

      RETURN l_return_val;

  END get_sf_parent_instance_id;

END xxobjt_oa2sf_interface_pkg;
/
