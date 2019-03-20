CREATE OR REPLACE PACKAGE BODY xxhz_soa_api_pkg IS

  --g_user_name          VARCHAR2(100) := 'SALESFORCE';
  g_resp_name          VARCHAR2(200) := 'AR Super User, SSYS'; --'Oracle Customer Data Librarian Superuser'; -- CHG0040057 - By Adi Safin, No S3,No CDH
  g_resp_appl          VARCHAR2(100) := 'AR'; --'IMC';  -- CHG0040057 - By Adi Safin, No S3,No CDH
  g_debug              BOOLEAN := TRUE;
  g_created_by_module  VARCHAR2(20);
  g_customer_type      VARCHAR2(10) := 'R'; --Customer type is External for all SFDC Customer
  g_sales_channel_code VARCHAR2(15) := 'DIRECT'; --Sales Channel is DIRECT for all SFDC Customer
  g_is_session_set     BOOLEAN := FALSE;
  g_old_sfdc_source    VARCHAR2(100) := 'SFDC';
  --User Defined Exception
  user_not_valid_exp    EXCEPTION;
  no_rec_to_process_exp EXCEPTION;
  -- Created : 11/05/2016 2:37:10 PM
  -- Purpose :
  --Added By   Lingaraj
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         :                                                                                                       *
  * Name                : write_log_message                                                                                                *
  * Script Name         : xxhz_soa_api_pkg.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will Write log Messages in DBMS Output if Called from PL/SQL Block
                           & write log in concurrent Program Log, if Called in a Concurrent program
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     23/02/2017  L.Sarangi          CHG0040057 - New Account, Contact, Site and check duplication Interfaces between SFDC and Oracle                                                                                      *
  *                                         This Procedure will help to log the Process
  * 1.1      12/13/2017  Diptasurjya        CHG0042044 - upsert_account Make calls compatiable with Strataforce
  * 1.2       03/NOV/2017 Piyali Bhowmick   CHG0041658- Submit the program DQM Synchronization Program automatically after SF interface complete
  * 1.3      18/02/2018  Lingaraj           CHG0042044   - find_match_accounts Modified to allow only results
  *                                         having Account ID
  * 1.4      4.Sep.2018  Llingaraj          CHG0043843 - SFDC to Oracle interface- add new field- customer category
  * 1.5      12.Nov.2018 Lingaraj           CHG0042632 - SFDC2OA - Location - Sites  interface ( upsert and find)
  * 1.5.1    16.1.19     yuval tal          CHG0042632  create_location/get_territory_org_info/get_territory_code logic change 
                                                        upsertSite : submit dql prog / upsert Contact submit dqm prod 
  *******************************************************************************************************************************************/
  PROCEDURE write_log_message(p_msg        VARCHAR2,
		      p_blank_line VARCHAR2 DEFAULT 'N') IS
  BEGIN
    IF g_debug = TRUE THEN
    
      --Need to find a Better Solution
      -- This Will Create a New Blank Line Before the Actual message Print.
      IF p_blank_line = 'Y' THEN
        IF fnd_global.conc_request_id = -1 THEN
          dbms_output.put_line(chr(10));
        ELSE
          fnd_file.put_line(fnd_file.log, chr(10));
        END IF;
      END IF;
      IF fnd_global.conc_request_id = -1 THEN
        dbms_output.put_line(p_msg);
      ELSE
        fnd_file.put_line(fnd_file.log, p_msg);
      END IF;
    END IF;
  END write_log_message;

  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : set_global_variables                                                                                                *
  * Script Name         : xxhz_soa_api_pkg.pkb                                                                                        *
  *                                                                                                                                         *
  * Purpose             :  This procedure will set the global variables depend on the Source of Call
  
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     26/02/2017  Lingaraj Sarangi   Initial version                                                                                      *
  ******************************************************************************************************************************************/
  /*PROCEDURE set_global_variables(p_source IN VARCHAR2) IS
  BEGIN
    --  IF p_source = 'SFDC' THEN
    g_created_by_module  := 'SALESFORCE';
    g_customer_type      := 'R'; --Customer type is External for all SFDC Customer
    g_sales_channel_code := 'DIRECT'; --Sales Channel is DIRECT for all SFDC Customer
    --  END IF
  END set_global_variables;*/

  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : set_global_variables                                                                                                *
  * Script Name         : xxhz_soa_api_pkg.pkb                                                                                        *
  *                                                                                                                                         *
  * Purpose             :  This procedure will set the global variables depend on the Source of Call
  
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     26/02/2017  Lingaraj Sarangi   Initial version     
   -- 1.1     16.1.19     yuval tal         CHG0042632 add substr                                                                                      *
  ******************************************************************************************************************************************/
  PROCEDURE get_territory_org_info(p_country        IN VARCHAR2,
		           x_territory_code OUT VARCHAR2,
		           x_org_id         OUT NUMBER,
		           x_ou_unit_name   OUT VARCHAR2,
		           x_error_code     OUT VARCHAR2,
		           x_error_msg      OUT VARCHAR2) IS
    xxrecord_not_found EXCEPTION;
  BEGIN
    x_error_code := fnd_api.g_ret_sts_success;
    --Fetch territory_code
    BEGIN
      SELECT territory_code
      INTO   x_territory_code
      FROM   fnd_territories_vl t
      WHERE  upper(territory_short_name) = upper(p_country) or 
      territory_code =substr(upper(p_country), 1, 2) and rownum=1; -- CHG0042632;
    EXCEPTION
      WHEN no_data_found THEN
        x_error_msg := 'Territory_Code Not Found for Country :' ||
	           p_country;
        RAISE xxrecord_not_found;
    END;
    --Fetch Operating Unit Id
    BEGIN
      SELECT to_number(attribute1)
      INTO   x_org_id
      FROM   fnd_lookup_values_vl
      WHERE  lookup_type = 'XXSERVICE_COUNTRIES_SECURITY'
      AND    lookup_code = x_territory_code;
    
      --Fetch Operating Unit  Name
    
      SELECT NAME
      INTO   x_ou_unit_name
      FROM   hr_operating_units
      WHERE  organization_id = x_org_id;
    EXCEPTION
      WHEN no_data_found THEN
        x_error_msg := 'The chosen Country is not associated with an operating unit.';
        RAISE xxrecord_not_found;
    END;
  
    write_log_message('Territory_Code / Operating Unit Id / Operating Unit Name:' ||
	          x_territory_code || '/' || x_org_id || '/' ||
	          x_ou_unit_name);
  
  EXCEPTION
    WHEN xxrecord_not_found THEN
      x_error_code := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_error_code := fnd_api.g_ret_sts_error;
      x_error_msg  := SQLERRM;
  END get_territory_org_info;
  ------
  FUNCTION get_salutation_code(p_salutation IN VARCHAR2) RETURN VARCHAR2 IS
    l_salutation_code VARCHAR2(20);
  BEGIN
    SELECT lookup_code
    INTO   l_salutation_code
    FROM   fnd_lookup_values
    WHERE  lookup_type = 'CONTACT_TITLE'
    AND    LANGUAGE = userenv('LANG')
    AND    upper(meaning) = TRIM(upper(p_salutation))
    AND    nvl(enabled_flag, 'N') = 'Y'
    AND    rownum = 1;
  
    RETURN l_salutation_code;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_salutation_code;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         :                                                                                                       *
  * Name                : set_my_session                                                                                                *
  * Script Name         : xxhz_soa_api_pkg.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  Set user,responsibility and application
  
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     23/02/2017  L.Sarangi          CHG0040057 - New Account, Contact, Site and check duplication Interfaces between SFDC and Oracle                                                                                      *
  *                                         This Procedure will help to Set user,responsibility and application                            *
  * 1.1      12/13/2017  Diptasurjya        CHG0042044 - Change procedure to be compatiable with Strataforce calls also                      *
  ******************************************************************************************************************************************/
  PROCEDURE set_my_session( --p_username       IN VARCHAR2,  -- CHG0042044 - Commented Dipta
		   p_source         IN VARCHAR2, -- CHG0042044 - Added Dipta
		   p_status_out     OUT VARCHAR2,
		   p_status_msg_out OUT VARCHAR2) IS
    l_resp_id      NUMBER;
    l_resp_appl_id NUMBER;
    l_user_id      NUMBER;
  
    l_request_source_user NUMBER;
    l_source              VARCHAR2(20);
  BEGIN
    write_log_message('**Program Entered : xxhz_soa_api_pkg.set_my_session Procedure',
	          'Y');
    p_status_out := fnd_api.g_ret_sts_success;
    --When Source is SFDC the Source will be changed to Sales Force
    l_source := (CASE
	      WHEN p_source = 'SFDC' THEN
	       'SALESFORCE'
	      ELSE
	       p_source
	    END);
    /* CHG0042044 - Dipta Start fetching details based on source */
    BEGIN
      SELECT attribute2,
	 attribute6
      INTO   l_request_source_user,
	 g_created_by_module
      FROM   fnd_flex_values     ffv,
	 fnd_flex_value_sets ffvs
      WHERE  ffvs.flex_value_set_name = 'XXSSYS_EVENT_TARGET_NAME'
      AND    ffvs.flex_value_set_id = ffv.flex_value_set_id
      AND    upper(ffv.flex_value) = upper(l_source)
      AND    ffv.enabled_flag = 'Y'
      AND    SYSDATE BETWEEN nvl(ffv.start_date_active, SYSDATE - 1) AND
	 nvl(ffv.end_date_active, SYSDATE + 1);
    
      IF l_request_source_user IS NULL OR g_created_by_module IS NULL THEN
        p_status_out     := fnd_api.g_ret_sts_error;
        p_status_msg_out := 'ERROR: Source:' || l_source ||
		    ' defined in valueset XXSSYS_EVENT_TARGET_NAME does not have user and/or HZ Created By defined';
        write_log_message('**Program Exited : xxhz_soa_api_pkg.set_my_session Procedure with Error :' ||
		  p_status_msg_out);
        RETURN;
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        p_status_out     := fnd_api.g_ret_sts_error;
        p_status_msg_out := 'ERROR: Source:' || l_source ||
		    ' is not a valid target defined in valueset XXSSYS_EVENT_TARGET_NAME';
        write_log_message('**Program Exited : xxhz_soa_api_pkg.set_my_session Procedure with Error :' ||
		  p_status_msg_out);
        RETURN;
    END;
    /* CHG0042044 - Dipta end */
  
    --  IF p_source = 'SFDC' THEN
    --g_created_by_module  := 'SALESFORCE';  -- CHG0042044 - Dipta commented
    g_customer_type      := 'R'; --Customer type is External for all SFDC Customer
    g_sales_channel_code := 'DIRECT'; --Sales Channel is DIRECT for all SFDC Customer
    --  END IF
  
    SELECT fuser.user_id,
           frv.application_id,
           frv.responsibility_id
    INTO   l_user_id,
           l_resp_id,
           l_resp_appl_id
    FROM   fnd_user              fuser,
           fnd_user_resp_groups  furg,
           fnd_responsibility_vl frv
    WHERE  1 = 1
    AND    fuser.user_id = furg.user_id
    AND    frv.responsibility_id = furg.responsibility_id
    AND    (to_char(fuser.end_date) IS NULL OR fuser.end_date > SYSDATE)
    AND    (to_char(furg.end_date) IS NULL OR furg.end_date > SYSDATE)
          --AND    fuser.user_name = g_user_name  -- CHG0042044 - Dipta commented
    AND    fuser.user_id = l_request_source_user -- CHG0042044 - Dipta added
    AND    frv.responsibility_name = g_resp_name;
  
    --Initialize Apps
    initialize_apps(l_user_id, l_resp_appl_id, l_resp_id);
  
    g_is_session_set := TRUE;
  
    write_log_message('**Program Exited : xxhz_soa_api_pkg.set_my_session Procedure');
  EXCEPTION
    WHEN no_data_found THEN
      p_status_out     := fnd_api.g_ret_sts_error;
      p_status_msg_out := 'ERROR: Validating user responsibility mapping: User' ||
		  l_request_source_user || ' Responsibility:' ||
		  g_resp_name ||
		  ' assignment does not exist in Oracle.';
      write_log_message('**Program Exited : xxhz_soa_api_pkg.set_my_session Procedure with Error :' ||
		p_status_msg_out);
    WHEN OTHERS THEN
      p_status_out     := fnd_api.g_ret_sts_error; --Unexpected Error
      p_status_msg_out := 'ERROR: While fetching user details :' || SQLERRM;
      write_log_message('**Program Exited : xxhz_soa_api_pkg.set_my_session Procedure with Error :' ||
		p_status_msg_out);
  END set_my_session;
  -------
  FUNCTION get_contact_point_obj_ver(p_contct_point_id NUMBER) RETURN NUMBER IS
    l_objvernum NUMBER;
  BEGIN
    SELECT object_version_number
    INTO   l_objvernum
    FROM   hz_contact_points
    WHERE  contact_point_id = p_contct_point_id;
  
    RETURN l_objvernum;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RETURN NULL;
  END get_contact_point_obj_ver;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041891 - This function checks if Customer Account ID/Number is valid
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  12/05/2017  Diptasurjya Chatterjee (TCS)    CHG0042044 - Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION fetch_customer_account_id(p_cust_account_id     IN NUMBER,
			 p_cust_account_number IN VARCHAR2)
    RETURN NUMBER IS
    l_cust_account_id NUMBER := 0;
  BEGIN
    SELECT hca.cust_account_id
    INTO   l_cust_account_id
    FROM   hz_cust_accounts hca
    WHERE  hca.cust_account_id =
           nvl(p_cust_account_id, hca.cust_account_id)
    AND    hca.account_number =
           nvl(p_cust_account_number, hca.account_number)
    AND    hca.status = 'A';
  
    RETURN l_cust_account_id;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041891 - This function checks if Customer Account ID/Number is valid
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  12/05/2017  Diptasurjya Chatterjee (TCS)    CHG0042044 - Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION fetch_customer_account_number(p_cust_account_id IN NUMBER)
    RETURN VARCHAR2 IS
    l_cust_account_num VARCHAR2(30) := 0;
  BEGIN
    SELECT hca.account_number
    INTO   l_cust_account_num
    FROM   hz_cust_accounts hca
    WHERE  hca.cust_account_id = p_cust_account_id
    AND    hca.status = 'A';
  
    RETURN l_cust_account_num;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: get_territory_code
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  16.1.19    yuval tal                       CHG0042632 add substr
  -- --------------------------------------------------------------------------------------------

  FUNCTION get_territory_code(p_country IN VARCHAR2) RETURN VARCHAR2 IS
    l_territory_code VARCHAR2(10);
  BEGIN
  
    SELECT territory_code
    INTO   l_territory_code
    FROM   fnd_territories_vl t
    WHERE  upper(territory_short_name) = substr(upper(p_country), 1, 2); -- yuval 
  
    RETURN l_territory_code;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RETURN NULL;
  END get_territory_code;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042044
  --          This function willl return Customer Category Code from Lookup
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  4.Spe.18   Lingaraj                       CHG0042044 - Initial build
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_customer_category_code(p_category_code IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_category_code VARCHAR2(50);
  BEGIN
    SELECT lookup_code
    INTO   l_category_code
    FROM   fnd_lookup_values flv
    WHERE  flv.lookup_type = 'CUSTOMER_CATEGORY'
    AND    flv.language = 'US'
    AND    upper(flv.attribute2) = upper(p_category_code)
    AND    nvl(flv.attribute3, 'N') = 'Y';
  
    RETURN l_category_code;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN p_category_code;
    WHEN too_many_rows THEN
      raise_application_error(-20101,
		      'Too Many Rows Exception in xxhz_soa_api_pkg.get_customer_category_code()' ||
		      ' function. More then one CUSTOMER_CATEGORY found for value :' ||
		      p_category_code);
  END get_customer_category_code;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042044
  --          This function willl return Customer Category Code from Lookup
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  4.Spe.18   Lingaraj                       CHG0042044 - Initial build
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_sales_channel_code(p_category_code IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_sales_channel_code VARCHAR2(20);
  BEGIN
    IF p_category_code = 'DISTRIBUTOR' THEN
      l_sales_channel_code := 'INDIRECT';
    ELSIF p_category_code = 'CUSTOMER' THEN
      l_sales_channel_code := 'DIRECT';
    ELSE
      l_sales_channel_code := 'DIRECT';
      write_log_message('Category_code:' || p_category_code ||
		' is not in (CUSTOMER / DISTRIBUTOR), sales_channel_code was updated to DIRECT');
    END IF;
    RETURN l_sales_channel_code;
  END get_sales_channel_code;

  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : upsert_code_assignment                                                                                                *
  * Script Name         : xxhz_soa_api_pkg.pkb                                                                                        *
  *                                                                                                                                         *
  * Purpose             :  This procedure will Disable all the active Industrial Classifications and add the new Industrial Classifications
  
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     27/02/2017  Lingaraj Sarangi   Initial version                                                                                      *
  ******************************************************************************************************************************************/
  PROCEDURE upsert_code_assignment(p_class_code    IN VARCHAR2,
		           p_party_id      IN NUMBER,
		           x_return_status OUT NOCOPY VARCHAR2,
		           x_msg_data      OUT NOCOPY VARCHAR2) IS
    -- Fetch all the active Industry
    CURSOR cur_active_ic IS
      SELECT *
      FROM   hz_code_assignments
      WHERE  1 = 1
      AND    owner_table_name = 'HZ_PARTIES'
      AND    owner_table_id = p_party_id
      AND    class_category = 'Objet Business Type'
      AND    status = 'A';
  
    l_code_assignment_rec   hz_classification_v2pub.code_assignment_rec_type;
    l_class_code            hz_class_code_denorm.class_code%TYPE;
    l_msg_count             NUMBER;
    l_code_assignment_id    NUMBER;
    l_object_version_number NUMBER;
    l_class_code_exists     VARCHAR2(1) := 'N';
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.upsert_code_assignment Procedure',
	          'Y');
    x_return_status := fnd_api.g_ret_sts_success;
  
    -- Validate the New Class Code
    IF p_class_code IS NOT NULL THEN
      SELECT class_code
      INTO   l_class_code
      FROM   hz_class_code_denorm
      WHERE  LANGUAGE = userenv('LANG')
	--and Upper(Class_Code) = Upper(p_class_code)
      AND    class_code = p_class_code
      AND    enabled_flag = 'Y'
      AND    nvl(end_date_active, (SYSDATE + 1)) > trunc(SYSDATE);
    END IF;
  
    --Disable Any Existing Industrial Classifications for the Party Id
    FOR rec IN cur_active_ic LOOP
    
      IF rec.class_code = nvl(l_class_code, '-1') THEN
        l_class_code_exists := 'Y';
        CONTINUE;
      END IF;
    
      l_code_assignment_rec.code_assignment_id := rec.code_assignment_id; --NUMBER
      l_code_assignment_rec.status             := 'I';
      l_object_version_number                  := rec.object_version_number;
      l_code_assignment_rec.end_date_active    := SYSDATE;
      BEGIN
        hz_classification_v2pub.update_code_assignment(p_init_msg_list         => fnd_api.g_true, --In Param
				       p_code_assignment_rec   => l_code_assignment_rec, --In Param HZ_CLASSIFICATION_V2PUB.CODE_ASSIGNMENT_REC_TYPE
				       p_object_version_number => l_object_version_number, -- In / Out Param  NUMBER,
				       x_return_status         => x_return_status, --Out Param VARCHAR2
				       x_msg_count             => l_msg_count, --Out Param NUMBER
				       x_msg_data              => x_msg_data --Out Param VARCHAR2
				       );
      
        IF x_return_status != fnd_api.g_ret_sts_success THEN
          write_log_message('Disabling old Industry failed with error :' ||
		    x_msg_data);
          write_log_message('Program Exited : xxhz_soa_api_pkg.upsert_code_assignment Procedure With Error');
          RETURN;
        END IF;
      
      END;
    END LOOP;
  
    IF l_class_code_exists = 'N' AND l_class_code IS NOT NULL THEN
      --If new Class Code is Not Available Then Create
      l_code_assignment_rec.code_assignment_id := NULL; --       NUMBER
      l_code_assignment_rec.status             := 'A';
      l_code_assignment_rec.owner_table_name   := 'HZ_PARTIES';
      l_code_assignment_rec.owner_table_id     := p_party_id;
      l_code_assignment_rec.class_category     := 'Objet Business Type';
      l_code_assignment_rec.class_code         := l_class_code;
      l_code_assignment_rec.primary_flag       := 'N';
      l_code_assignment_rec.start_date_active  := SYSDATE;
      l_code_assignment_rec.end_date_active    := NULL;
      l_code_assignment_rec.created_by_module  := g_created_by_module;
    
      --Validate Class Code
      hz_classification_v2pub.create_code_assignment(p_init_msg_list       => fnd_api.g_true, --In Param
				     p_code_assignment_rec => l_code_assignment_rec, --In Param
				     x_return_status       => x_return_status, --Out Param
				     x_msg_count           => l_msg_count, --Out Param
				     x_msg_data            => x_msg_data, --Out Param
				     x_code_assignment_id  => l_code_assignment_id --Out Param
				     );
    
      write_log_message('hz_classification_v2pub.create_code_assignment API Call Status :' ||
		x_return_status || '; Messsga Count:' ||
		x_return_status || ';Error Message:' || x_msg_data);
    
      IF x_return_status = fnd_api.g_ret_sts_success THEN
        write_log_message('Industrial Classification Created for Party Id :' ||
		  p_party_id || ' and Code assignment Id :' ||
		  l_code_assignment_id);
        write_log_message('Query to Verify :' ||
		  'Select * from HZ_CODE_ASSIGNMENTS where OWNER_TABLE_NAME =' || '''' ||
		  'HZ_PARTIES' || '''' || ' and OWNER_TABLE_ID = ' ||
		  l_code_assignment_id,
		  'N');
      END IF;
    END IF;
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.upsert_code_assignment Procedure');
  
  EXCEPTION
    WHEN no_data_found THEN
      x_return_status := 'E';
      x_msg_data      := p_class_code ||
		 ' is not a valid Industrial Classifications Code. Please Validate in the Oracle apps Table HZ_CLASS_CODE_DENORM.';
    WHEN OTHERS THEN
      x_return_status := 'U';
      x_msg_data      := SQLERRM;
  END upsert_code_assignment;
  /******************************************************************************************************************************************
  * Type                : Package                                                                                                          *
  * Module Name         : AR_CUSTOMERS                                                                                                     *
  * Name                : xxhz_api_pkg                                                                                           *
  * Script Name         : xxhz_api_pkg.pks                                                                                       *
  * Procedure           : 1.create_person                                                                                             *
                          2.update_person
                          3.update_organization
                          4.create_account
                          5.update_account
                          6.create_party_site
                          7.upsert_account
                          8.upsert_contact
                          9.upsert_sites
                          10.create_account
                          11.update_account
                          12.create_contact_point
                          13.update_contact_point
                          14.create_contact
                          15.update_contact
                          16.create_account_role
                          17.create_acct_site
                          18.update_acct_site
                          19.create_acct_site_use
                          20.update_acct_site_use                                                                                                                *                                                                                                                                            *
  * Purpose             : This script is used to create Package "xxhz_api_pkg" in APPS schema,                                   *
                                                                                                                                           *
  * HISTORY                                                                                                                                *
  * =======                                                                                                                                *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                       *
  * -------  ----------- ---------------    ------------------------------------                                                              *
  * 1.00     11/05/2016  Somnath Dawn               Draft version                                                                                     *
  ******************************************************************************************************************************************/
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : FindMatchParty                                                                                                      *
  * Name                : find_match_accounts                                                                                                *
  * Script Name         : xxhz_api_pkg.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             : This Procedure will find the party details as per the user input from SFDC                                  *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     11/05/2016  Somnath Dawn                Initial version
  * 1.1      18/02/2018  Lingaraj Sarangi   CHG0042044  - Remove Match account from Output
  *                                         for which Account Id not found                                                                                   *
  ******************************************************************************************************************************************/

  PROCEDURE find_match_accounts(p_source           IN VARCHAR2,
		        p_accounts_in      IN xxobjt.xxhz_account_match_req_rec,
		        p_accounts_out     OUT xxobjt.xxhz_accounts_match_resp_tab,
		        p_status           OUT VARCHAR2,
		        p_message          OUT VARCHAR2,
		        p_soa_reference_id IN NUMBER) IS
    l_party_rec       hz_party_search.party_search_rec_type;
    l_site_list       hz_party_search.party_site_list;
    l_cont_list       hz_party_search.contact_list;
    l_cont_point_list hz_party_search.contact_point_list;
    l_account_name    hz_cust_accounts_all.account_name%TYPE;
    l_return_id       NUMBER;
    l_num_matches     NUMBER;
    l_ret_status      VARCHAR2(2000);
    l_territory_code  fnd_territories_vl.territory_code%TYPE;
    l_cust_account_id NUMBER;
    l_account_number  VARCHAR2(30);
    l_msg_count       NUMBER;
    l_msg_data        VARCHAR2(2000);
    l_rule_id         NUMBER;
    -- k                       NUMBER := 0;
    l_account_resp_rec      xxhz_accounts_match_resp_rec;
    l_account_dupl_resp_tab xxhz_accounts_match_resp_tab := xxhz_accounts_match_resp_tab();
  
    CURSOR party_cur(p_search_context_id IN NUMBER) IS
      SELECT hp.party_name,
	 hp.party_type,
	 hp.country,
	 hp.address1 || ',' || hp.city || ',' || hp.state || ',' ||
	 hp.postal_code address,
	 hp.duns_number,
	 hp.url,
	 hp.primary_phone_number,
	 hmpg.party_id,
	 hmpg.score,
	 (SELECT hca.sales_channel_code
	  FROM   hz_cust_accounts hca
	  WHERE  hca.party_id = hp.party_id
	  AND    hca.status = 'A'
	  AND    rownum = 1) sales_channel,
	 
	 (SELECT hca.attribute19
	  FROM   hz_cust_accounts hca
	  WHERE  hca.party_id = hp.party_id
	  AND    hca.status = 'A'
	  AND    rownum = 1) cross_industry,
	 
	 (SELECT hca.attribute16
	  FROM   hz_cust_accounts hca
	  WHERE  hca.party_id = hp.party_id
	  AND    hca.status = 'A'
	  AND    rownum = 1) institution_type,
	 
	 (SELECT hou.name
	  FROM   hr_operating_units hou
	  WHERE  to_char(hou.organization_id) = hp.attribute3) cust_support_operating_unit,
	 
	 /*(SELECT xxssys_imc_sales_channel
                FROM ar_xxssys_imc_acct_agv   a,
                     hz_organization_profiles b
               WHERE b.organization_profile_id = a.organization_profile_id(+)
                 AND b.party_id = hmpg.party_id
                 AND nvl(b.effective_end_date,
                         trunc(SYSDATE)) >= trunc(SYSDATE)) sales_channel,
             (SELECT xxssys_imc_cross_industry
                FROM ar_xxssys_imc_acct_agv   a,
                     hz_organization_profiles b
               WHERE b.organization_profile_id = a.organization_profile_id(+)
                 AND b.party_id = hmpg.party_id
                 AND nvl(b.effective_end_date,
                         trunc(SYSDATE)) >= trunc(SYSDATE)) cross_industry,
             (SELECT xxssys_imc_institute_type
                FROM ar_xxssys_imc_acct_agv   a,
                     hz_organization_profiles b
               WHERE b.organization_profile_id = a.organization_profile_id(+)
                 AND b.party_id = hmpg.party_id
                 AND nvl(b.effective_end_date,
                         trunc(SYSDATE)) >= trunc(SYSDATE)) institution_type,
             (SELECT xxssys_imc_sfdc_cust_supp_ou
                FROM ar_xxssys_imc_sam_c_agv
               WHERE organization_profile_id =
                     (SELECT organization_profile_id
                        FROM hz_organization_profiles
                       WHERE nvl(effective_end_date,
                                 trunc(SYSDATE)) >= trunc(SYSDATE)
                         AND party_id = hmpg.party_id)) cust_support_operating_unit,*/ --  CHG0040057 - Adi Safin . Need to revise Since no CDH.
	 hmpg.search_context_id
      FROM   hz_matched_parties_gt hmpg,
	 hz_parties            hp
      WHERE  hmpg.search_context_id = p_search_context_id
      AND    hp.party_id = hmpg.party_id
      AND    party_type = 'ORGANIZATION';
  
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.find_match_accounts Procedure',
	          'Y');
    p_status := fnd_api.g_ret_sts_success;
    initialize_apps(NULL, NULL, NULL);
  
    l_account_resp_rec := xxhz_accounts_match_resp_rec(NULL,
				       NULL,
				       NULL,
				       NULL);
  
    l_rule_id := fnd_profile.value('HZ_ORG_DUP_PREV_MATCHRULE');
  
    IF p_accounts_in.account_name IS NOT NULL THEN
      l_party_rec.party_all_names := p_accounts_in.account_name;
      --      l_party_rec.all_account_names := p_accounts_in.account_name;
    END IF;
    IF p_accounts_in.duns_num IS NOT NULL THEN
      l_party_rec.duns_number_c := p_accounts_in.duns_num;
    END IF;
    IF p_accounts_in.account_name_local IS NOT NULL THEN
      l_party_rec.organization_name_phonetic := p_accounts_in.account_name_local;
    END IF;
    IF p_accounts_in.phone IS NOT NULL THEN
      --l_cont_point_list(1).phone_number := p_accounts_in.phone;
      l_cont_point_list(1).contact_point_type := 'PHONE';
      l_cont_point_list(1).flex_format_phone_number := p_accounts_in.phone;
    END IF;
    IF p_accounts_in.ship_address IS NOT NULL THEN
      l_site_list(1).address := p_accounts_in.ship_address;
    END IF;
    IF p_accounts_in.ship_city IS NOT NULL THEN
      l_site_list(1).city := p_accounts_in.ship_city;
    END IF;
  
    IF p_accounts_in.ship_country IS NOT NULL THEN
      l_territory_code := get_territory_code(p_accounts_in.ship_country);
    
      IF l_territory_code IS NOT NULL THEN
        l_site_list(1).country := l_territory_code;
      END IF;
    END IF;
  
    IF p_accounts_in.ship_county IS NOT NULL THEN
      l_site_list(1).county := p_accounts_in.ship_county;
    END IF;
    IF p_accounts_in.ship_state IS NOT NULL THEN
      l_site_list(1).state := p_accounts_in.ship_state;
    END IF;
    IF p_accounts_in.postal_code IS NOT NULL THEN
      l_site_list(1).postal_code := p_accounts_in.postal_code;
    END IF;
  
    hz_party_search.find_party_details(p_init_msg_list      => fnd_api.g_true,
			   p_rule_id            => l_rule_id,
			   p_party_search_rec   => l_party_rec,
			   p_party_site_list    => l_site_list,
			   p_contact_list       => l_cont_list,
			   p_contact_point_list => l_cont_point_list,
			   p_restrict_sql       => NULL,
			   p_match_type         => NULL,
			   p_search_merged      => 'N',
			   x_search_ctx_id      => l_return_id,
			   x_num_matches        => l_num_matches,
			   x_return_status      => l_ret_status,
			   x_msg_count          => l_msg_count,
			   x_msg_data           => l_msg_data);
    p_status  := l_ret_status;
    p_message := l_msg_data;
  
    write_log_message('l_return_status:' || l_ret_status);
    write_log_message('l_num_matches:' || l_num_matches);
    write_log_message('l_return_id:' || l_return_id);
  
    FOR r IN party_cur(l_return_id) LOOP
      l_cust_account_id  := NULL;
      l_account_name     := NULL;
      l_account_number   := NULL;
      l_account_resp_rec := xxhz_accounts_match_resp_rec(NULL,
				         NULL,
				         NULL,
				         NULL);
      --CHG0042044 - Code modified to restrict Result not having Account Id.
      BEGIN
        SELECT cust_account_id,
	   account_name,
	   account_number
        INTO   l_cust_account_id,
	   l_account_name,
	   l_account_number
        FROM   hz_cust_accounts_all
        WHERE  party_id = r.party_id
        AND    status = 'A';
      
        IF l_cust_account_id IS NOT NULL THEN
          l_account_resp_rec.account_id       := l_cust_account_id;
          l_account_resp_rec.account_number   := l_account_number;
          l_account_resp_rec.account_name     := r.party_name;
          l_account_resp_rec.match_percentage := r.score;
        
          l_account_dupl_resp_tab.extend;
          l_account_dupl_resp_tab(l_account_dupl_resp_tab.count) := l_account_resp_rec;
        END IF;
      
      EXCEPTION
        WHEN no_data_found THEN
          l_account_resp_rec.account_id := NULL;
        WHEN too_many_rows THEN
          p_status  := fnd_api.g_ret_sts_error;
          p_message := 'Multiple Account Found';
        WHEN OTHERS THEN
          p_status  := fnd_api.g_ret_sts_error;
          p_message := p_message || chr(10) ||
	           'Unexpected Error while fetching Account Number for party_id ' ||
	           r.party_id;
      END;
    
    END LOOP;
  
    p_accounts_out := l_account_dupl_resp_tab;
  
    write_log_message('l_account_dupl_resp_tab.COUNT=' ||
	          l_account_dupl_resp_tab.count);
  
    FOR z IN 1 .. l_account_dupl_resp_tab.count LOOP
      write_log_message('Account Name=' || p_accounts_out(z).account_name);
      write_log_message('Score=' || p_accounts_out(z).match_percentage);
      write_log_message('---------------------------------------------');
    END LOOP;
  
    IF l_ret_status <> fnd_api.g_ret_sts_success THEN
      IF l_msg_count > 1 THEN
        FOR i IN 1 .. l_msg_count LOOP
          write_log_message(i || '.' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
			           1,
			           255));
        END LOOP;
      END IF;
    END IF;
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.find_match_accounts Procedure');
  END find_match_accounts;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : FindMatchSite                                                                                                      *
  * Name                : find_match_sites                                                                                                *
  * Script Name         : xxhz_api_pkg.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             : This Procedure will find the party details as per the user input from SFDC                                       *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     11/05/2016  Somnath Dawn                Initial version     
  *  1.1     12-Nov-2018 Lingaraj           CHG0042632 - SFDC2OA - Location - Sites  interface ( upsert and find)
  *                                         This is Procedure is now Obsolete , Please Use find_match_sites                                                                                 *
  ******************************************************************************************************************************************/

  PROCEDURE find_match_sites_old(p_source           IN VARCHAR2,
		         p_sites_in         IN OUT xxobjt.xxhz_site_match_req_rec,
		         p_sites_out        OUT xxobjt.xxhz_site_match_resp_tab,
		         p_status           OUT VARCHAR2,
		         p_message          OUT VARCHAR2,
		         p_soa_reference_id IN NUMBER) IS
  
    l_party_rec          hz_party_search.party_search_rec_type;
    l_site_list          hz_party_search.party_site_list;
    l_cont_list          hz_party_search.contact_list;
    l_cont_point_list    hz_party_search.contact_point_list;
    l_county             hz_locations.county%TYPE;
    l_country            hz_locations.country%TYPE;
    l_address1           hz_locations.address1%TYPE;
    l_city               hz_locations.city%TYPE;
    l_state              hz_locations.state%TYPE;
    l_acct_number        hz_cust_accounts_all.account_number%TYPE;
    l_territory_code     fnd_territories_vl.territory_code%TYPE;
    l_return_id          NUMBER;
    l_num_matches        NUMBER;
    l_cust_account_id    NUMBER;
    l_party_id           NUMBER;
    l_ret_status         VARCHAR2(2000);
    l_msg_count          NUMBER;
    l_msg_data           VARCHAR2(2000);
    l_rule_id            NUMBER;
    l_party_name         VARCHAR2(200);
    l_site_resp_rec      xxhz_site_match_resp_rec;
    l_site_dupl_resp_tab xxhz_site_match_resp_tab := xxhz_site_match_resp_tab();
  
    CURSOR party_site_cur(p_ctx_id   IN NUMBER,
		  p_party_id IN NUMBER) IS
      SELECT *
      FROM   hz_matched_party_sites_gt
      WHERE  search_context_id = p_ctx_id
      AND    party_id = nvl(p_party_id, party_id);
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.find_match_sites Procedure',
	          'Y');
    p_status := fnd_api.g_ret_sts_success;
    --initialize_apps(NULL, NULL, NULL);
  
    l_site_resp_rec := xxhz_site_match_resp_rec(NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL);
    -----------------------------------Converting ID's----------------------------------------
    IF p_sites_in.account_id IS NOT NULL THEN
      l_cust_account_id := p_sites_in.account_id;
      -- p_sites_in.account_id := xxcust_convert_xref_pkg.convert_allied_to_s3('ACCT-NUMBER',p_sites_in.account_id); --CHG0040057 -  Remark By Adi Safin, No S3
    END IF;
    --------------------------------End of Converting ID's------------------------------------
  
    /* SELECT match_rule_id
    INTO   l_rule_id
    FROM   hz_match_rules_vl
    WHERE  rule_name = 'XXSSYS: Customer Simple Search Rule';*/
  
    l_rule_id := fnd_profile.value('HZ_ORG_DUP_PREV_MATCHRULE');
  
    IF p_sites_in.account_id IS NULL THEN
      p_status  := fnd_api.g_ret_sts_error;
      p_message := 'Please provide the account ID';
    END IF;
  
    IF p_sites_in.account_id IS NOT NULL THEN
      BEGIN
        SELECT account_number,
	   party_id
        INTO   l_acct_number,
	   l_party_id
        FROM   hz_cust_accounts_all
        WHERE  cust_account_id = p_sites_in.account_id;
        l_party_rec.all_account_numbers := l_acct_number;
      EXCEPTION
        WHEN OTHERS THEN
          l_acct_number := NULL;
          l_party_id    := NULL;
      END;
      IF p_sites_in.site_address IS NOT NULL THEN
        l_site_list(1).address := p_sites_in.site_address;
      END IF;
      IF p_sites_in.site_city IS NOT NULL THEN
        l_site_list(1).city := p_sites_in.site_city;
      END IF;
      IF p_sites_in.state IS NOT NULL THEN
        l_site_list(1).state := p_sites_in.state;
      END IF;
      IF p_sites_in.site_postal_code IS NOT NULL THEN
        l_site_list(1).postal_code := p_sites_in.site_postal_code;
      END IF;
      IF p_sites_in.site_county IS NOT NULL THEN
        l_site_list(1).county := p_sites_in.site_county;
      END IF;
      IF p_sites_in.site_country IS NOT NULL THEN
        l_territory_code := get_territory_code(p_sites_in.site_country);
      
        IF l_territory_code IS NOT NULL THEN
          l_site_list(1).country := l_territory_code;
        END IF;
        /*BEGIN
          SELECT territory_code
          INTO   l_territory_code
          FROM   fnd_territories_vl t
          WHERE  upper(territory_short_name) =
                 upper(p_sites_in.site_country);
          l_site_list(1).country := l_territory_code;
        EXCEPTION
          WHEN OTHERS THEN
                    l_territory_code := NULL;
        END;*/
      END IF;
    
      hz_party_search.find_party_details(p_init_msg_list      => fnd_api.g_true,
			     p_rule_id            => l_rule_id,
			     p_party_search_rec   => l_party_rec,
			     p_party_site_list    => l_site_list,
			     p_contact_list       => l_cont_list,
			     p_contact_point_list => l_cont_point_list,
			     p_restrict_sql       => NULL,
			     p_match_type         => NULL,
			     p_search_merged      => 'N',
			     x_search_ctx_id      => l_return_id,
			     x_num_matches        => l_num_matches,
			     x_return_status      => l_ret_status,
			     x_msg_count          => l_msg_count,
			     x_msg_data           => l_msg_data);
    
      write_log_message('  hz_party_search.find_party_details API Call Status / Error Message :' ||
		l_ret_status || '/Error :' || l_msg_data);
      write_log_message('  Match Count :' || l_num_matches);
    
      p_status := l_ret_status;
    
      FOR j IN party_site_cur(l_return_id, l_party_id) LOOP
        BEGIN
          SELECT hp.party_name,
	     hl.county,
	     hl.country,
	     hl.address1,
	     hl.city,
	     hl.state
          INTO   l_party_name,
	     l_county,
	     l_country,
	     l_address1,
	     l_city,
	     l_state
          FROM   hz_party_sites hps,
	     hz_parties     hp,
	     hz_locations   hl
          WHERE  hps.location_id = hl.location_id
          AND    hp.party_id = hps.party_id
          AND    hps.party_site_id = j.party_site_id
          AND    party_type = 'ORGANIZATION';
        
          l_site_dupl_resp_tab.extend;
          l_site_resp_rec.account_id := l_cust_account_id;
        
          l_site_resp_rec.account_name := l_party_name;
          l_site_resp_rec.site_address := l_address1;
          l_site_resp_rec.site_id := j.party_site_id;
          l_site_resp_rec.site_city := l_city;
          l_site_resp_rec.site_county := l_county;
          l_site_resp_rec.site_country := l_country;
          l_site_resp_rec.state := l_state;
          l_site_resp_rec.match_percentage := j.score;
          l_site_dupl_resp_tab(l_site_dupl_resp_tab.count) := l_site_resp_rec;
        
        EXCEPTION
          WHEN OTHERS THEN
	write_log_message('Error in party site loop=' || SQLERRM);
        END;
      END LOOP;
    
      p_sites_out := l_site_dupl_resp_tab;
    
    END IF;
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.find_match_sites Procedure');
  END find_match_sites_old;

  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : FindMatchSite                                                                                                      *
  * Name                : find_match_sites                                                                                                *
  * Script Name         : xxhz_api_pkg.pkb                                                                                                  *                                                                                                                                            *
  * Purpose             : This Procedure will find the party details as per the user input from SFDC                                       
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.0     12-Nov-2018 Lingaraj           CHG0042632 - SFDC2OA - Location - Sites  interface ( upsert and find)
  *                                         
  ******************************************************************************************************************************************/
  PROCEDURE find_match_sites(p_source           IN VARCHAR2,
		     p_sites_in         IN OUT xxobjt.xxhz_site_match_req_rec,
		     p_sites_out        OUT xxobjt.xxhz_site_match_resp_tab,
		     p_status           OUT VARCHAR2,
		     p_message          OUT VARCHAR2,
		     p_soa_reference_id IN NUMBER,
		     p_debug            IN VARCHAR2 DEFAULT 'N') IS
  
    --l_party_rec          hz_party_search.party_search_rec_type;
    l_site_list          hz_party_search.party_site_list;
    l_cont_list          hz_party_search.contact_list;
    l_cont_point_list    hz_party_search.contact_point_list;
    l_county             hz_locations.county%TYPE;
    l_country            hz_locations.country%TYPE;
    l_address1           hz_locations.address1%TYPE;
    l_city               hz_locations.city%TYPE;
    l_state              hz_locations.state%TYPE;
    l_acct_number        hz_cust_accounts_all.account_number%TYPE;
    l_territory_code     fnd_territories_vl.territory_code%TYPE;
    l_return_id          NUMBER;
    l_num_matches        NUMBER;
    l_cust_account_id    NUMBER;
    l_party_id           NUMBER;
    l_ret_status         VARCHAR2(2000);
    l_msg_count          NUMBER;
    l_msg_data           VARCHAR2(2000);
    l_rule_id            NUMBER;
    l_party_name         VARCHAR2(200);
    l_site_resp_rec      xxhz_site_match_resp_rec;
    l_site_dupl_resp_tab xxhz_site_match_resp_tab := xxhz_site_match_resp_tab();
    l_st_out             VARCHAR2(1000);
    l_msg_out            VARCHAR2(1000);
    custom_err_exp EXCEPTION;
  
    CURSOR party_site_cur(p_ctx_id   IN NUMBER,
		  p_party_id IN NUMBER) IS
      SELECT gt.*,
	 (SELECT party_type
	  FROM   hz_party_sites hps,
	         hz_parties     hp
	  WHERE  hp.party_id = hps.party_id
	  AND    hps.party_site_id = gt.party_site_id
	  AND    party_type = 'ORGANIZATION'
	  AND    rownum = 1) party_type
      FROM   hz_matched_party_sites_gt gt
      WHERE  gt.search_context_id = p_ctx_id
      AND    gt.party_id = nvl(p_party_id, gt.party_id);
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.find_match_sites Procedure');
    p_status := fnd_api.g_ret_sts_success;
  
    mo_global.init('AR');
  
    IF p_sites_in.account_number IS NULL AND p_sites_in.account_id IS NULL THEN
      p_status  := fnd_api.g_ret_sts_error;
      p_message := 'Please provide Customer Account Number Or Account ID.';
      RAISE custom_err_exp;
    ELSE
      BEGIN
        SELECT cust_account_id,
	   account_number,
	   party_id
        INTO   l_cust_account_id,
	   l_acct_number,
	   l_party_id
        FROM   hz_cust_accounts_all hca
        WHERE  hca.account_number =
	   nvl(p_sites_in.account_number, hca.account_number)
        AND    hca.cust_account_id =
	   nvl(p_sites_in.account_id, hca.cust_account_id);
      
        --l_party_rec.all_account_numbers := l_acct_number;
      
      EXCEPTION
        WHEN no_data_found THEN
          p_message := 'Account ID:' || p_sites_in.account_id ||
	           ' and Accoun Number :' || p_sites_in.account_number ||
	           ', is not a Vallid Cutomer Account ID / Number.';
          p_status  := fnd_api.g_ret_sts_error;
          RAISE custom_err_exp;
      END;
    END IF;
  
    l_rule_id := fnd_profile.value('HZ_ORG_DUP_PREV_MATCHRULE');
  
    IF l_rule_id IS NULL THEN
      p_status  := fnd_api.g_ret_sts_error;
      p_message := 'Please Set Profile Value for HZ_ORG_DUP_PREV_MATCHRULE.';
      RAISE custom_err_exp;
    END IF;
  
    IF l_cust_account_id IS NOT NULL THEN
    
      IF p_sites_in.site_address IS NOT NULL THEN
        l_site_list(1).address := p_sites_in.site_address;
      END IF;
    
      IF p_sites_in.site_city IS NOT NULL THEN
        l_site_list(1).city := p_sites_in.site_city;
      END IF;
    
      IF p_sites_in.state IS NOT NULL THEN
        l_site_list(1).state := p_sites_in.state;
      END IF;
    
      IF p_sites_in.site_postal_code IS NOT NULL THEN
        l_site_list(1).postal_code := p_sites_in.site_postal_code||'%';
      END IF;
    
      IF p_sites_in.site_county IS NOT NULL THEN
        l_site_list(1).county := p_sites_in.site_county;
      END IF;
    
      IF p_sites_in.site_country IS NOT NULL THEN
        l_territory_code := get_territory_code(p_sites_in.site_country);
      
        IF l_territory_code IS NOT NULL THEN
          l_site_list(1).country := l_territory_code;
        END IF;
      
      END IF;
    
      IF p_sites_in.site_name IS NOT NULL THEN
        l_site_list(1).party_site_name := p_sites_in.site_name;
      END IF;
    
      hz_party_search.get_matching_party_sites(p_init_msg_list      => fnd_api.g_true, -- IN      VARCHAR2:= FND_API.G_FALSE,
			           p_rule_id            => l_rule_id, -- IN      NUMBER,
			           p_party_id           => l_party_id, -- IN      NUMBER,
			           p_party_site_list    => l_site_list, -- IN      PARTY_SITE_LIST,
			           p_contact_point_list => l_cont_point_list, -- IN      CONTACT_POINT_LIST,
			           p_restrict_sql       => NULL, -- IN      VARCHAR2,
			           p_match_type         => NULL, -- IN      VARCHAR2,
			           x_search_ctx_id      => l_return_id, -- OUT     NUMBER,
			           x_num_matches        => l_num_matches, -- OUT     NUMBER,
			           x_return_status      => l_ret_status, -- OUT     VARCHAR2,
			           x_msg_count          => l_msg_count, -- OUT     NUMBER,
			           x_msg_data           => l_msg_data -- OUT     VARCHAR2                       
			           );
    
      p_status := l_ret_status;
    
      IF p_status != fnd_api.g_ret_sts_success THEN
        IF l_msg_count > 1 THEN
          FOR i IN 1 .. l_msg_count LOOP
	p_message := p_message || chr(10) || '(' || i || ')' ||
		 substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
		        1,
		        255);
          END LOOP;
        ELSE
          p_message := l_msg_data;
        END IF;
        p_message := 'Unexpected Error in hz_party_search.get_matching_party_sites Api Call.' ||
	         p_message;
        RAISE custom_err_exp;
      END IF;
    
      IF p_debug = 'Y' THEN
        write_log_message('hz_party_search.get_matching_party_sites API Call Status / Error Message :' ||
		  p_status || '/Error :' || p_message);
        write_log_message('  Match Count :' || l_num_matches);
      END IF;
    
      FOR j IN party_site_cur(l_return_id, l_party_id) LOOP
        IF j.party_type = 'ORGANIZATION' THEN
          l_site_dupl_resp_tab.extend;
          l_site_resp_rec := xxhz_site_match_resp_rec(NULL,
				      NULL,
				      NULL,
				      NULL,
				      NULL,
				      NULL,
				      NULL,
				      NULL,
				      NULL,
				      NULL,
				      NULL,
				      NULL,
				      NULL,
				      NULL,
				      NULL,
				      NULL,
				      NULL,
				      NULL,
				      NULL,
				      NULL,
				      NULL,
				      NULL);
          BEGIN
	SELECT xsdv.cust_account_id,
	       xsdv.account_number,
	       xsdv.party_name,
	       xsdv.oracle_site_id,
	       xsdv.site_address,
	       xsdv.site_city,
	       xsdv.site_county,
	       xsdv.site_state,
	       xsdv.site_country,
	       xsdv.site_postal_code,
	       xsdv.oracle_site_number,
	       xsdv.location_name,
	       xsdv.site_usage,
	       xsdv.bill_site_use_id,
	       xsdv.ship_site_use_id,
	       xsdv.location_id,
	       xsdv.shipping_method,
	       xsdv.site_status,
	       j.score,
	       xsdv.org_id,
	       xxhz_util.get_operating_unit_name(xsdv.org_id)
	INTO   l_site_resp_rec.account_id,
	       l_site_resp_rec.account_number,
	       l_site_resp_rec.account_name,
	       l_site_resp_rec.site_id,
	       l_site_resp_rec.site_address,
	       l_site_resp_rec.site_city,
	       l_site_resp_rec.site_county,
	       l_site_resp_rec.state,
	       l_site_resp_rec.site_country,
	       l_site_resp_rec.site_postal_code,
	       l_site_resp_rec.site_number,
	       l_site_resp_rec.location_name,
	       l_site_resp_rec.site_usage,
	       l_site_resp_rec.oe_bill_site_use_id,
	       l_site_resp_rec.oe_ship_site_use_id,
	       l_site_resp_rec.oe_location_id,
	       l_site_resp_rec.shipping_method,
	       l_site_resp_rec.site_status,
	       l_site_resp_rec.match_percentage,
	       l_site_resp_rec.org_id,
	       l_site_resp_rec.org_name
	FROM   xxhz_site_dtl_v xsdv
	WHERE  xsdv.party_site_id = j.party_site_id
	AND    xsdv.party_type = 'ORGANIZATION'
	AND    xsdv.org_id IN
	       (SELECT to_number(external_key__c)
	         FROM   xxsf2_operating_unit); --Send Response for Only OU available in STRAFORCE                   
          
	l_site_dupl_resp_tab(l_site_dupl_resp_tab.count) := l_site_resp_rec;
          
          EXCEPTION
	WHEN no_data_found THEN
	  NULL;
	WHEN OTHERS THEN
	  l_site_resp_rec.account_id := l_cust_account_id;
	  l_site_resp_rec.account_number := l_acct_number;
	  l_site_resp_rec.site_id := j.party_site_id;
	  l_site_resp_rec.match_percentage := j.score;
	  l_site_resp_rec.message := 'Unexpected Error during select of xxhz_site_dtl_v View:' ||
			     SQLERRM;
	  l_site_dupl_resp_tab(l_site_dupl_resp_tab.count) := l_site_resp_rec;
	
	  write_log_message('Error in party site loop for site ID = ' ||
		        j.party_site_id || '.' || SQLERRM);
          END;
        END IF;
      END LOOP;
    
      p_sites_out := l_site_dupl_resp_tab;
    
    END IF;
  
    IF p_debug = 'Y' THEN
      FOR i IN 1 .. l_site_dupl_resp_tab.count() LOOP
        write_log_message('------------------------------------------------');
        write_log_message('Record Number   :' || i);
        write_log_message('account_id      :' || l_site_dupl_resp_tab(i)
		  .account_id);
        write_log_message('account_number  :' || l_site_dupl_resp_tab(i)
		  .account_number);
        write_log_message('account_name    :' || l_site_dupl_resp_tab(i)
		  .account_name);
        write_log_message('site_id         :' || l_site_dupl_resp_tab(i)
		  .site_id);
        write_log_message('site_address    :' || l_site_dupl_resp_tab(i)
		  .site_address);
        write_log_message('site_city       :' || l_site_dupl_resp_tab(i)
		  .site_city);
        write_log_message('state           :' || l_site_dupl_resp_tab(i)
		  .state);
        write_log_message('site_country    :' || l_site_dupl_resp_tab(i)
		  .site_country);
        write_log_message('site_postal_code:' || l_site_dupl_resp_tab(i)
		  .site_postal_code);
        write_log_message('site_number     :' || l_site_dupl_resp_tab(i)
		  .site_number);
        write_log_message('location_name   :' || l_site_dupl_resp_tab(i)
		  .location_name);
        write_log_message('site_usage      :' || l_site_dupl_resp_tab(i)
		  .site_usage);
        write_log_message('site_status     :' || l_site_dupl_resp_tab(i)
		  .site_status);
        write_log_message('shipping_method :' || l_site_dupl_resp_tab(i)
		  .shipping_method);
        write_log_message('bill_site_use_id:' || l_site_dupl_resp_tab(i)
		  .oe_bill_site_use_id);
        write_log_message('ship_site_use_id:' || l_site_dupl_resp_tab(i)
		  .oe_ship_site_use_id);
        write_log_message('location_id     :' || l_site_dupl_resp_tab(i)
		  .oe_location_id);
        write_log_message('ORG_ID          :' || l_site_dupl_resp_tab(i)
		  .org_id);
        write_log_message('ORG_NAME          :' || l_site_dupl_resp_tab(i)
		  .org_name);
        write_log_message('match_percentage:' || l_site_dupl_resp_tab(i)
		  .match_percentage);
        write_log_message('message         :' || l_site_dupl_resp_tab(i)
		  .message);
        write_log_message('------------------------------------------------');
      END LOOP;
    
      write_log_message('Program Exited : xxhz_soa_api_pkg.find_match_sites Procedure');
    END IF;
  EXCEPTION
    WHEN custom_err_exp THEN
      write_log_message(p_message);
    WHEN OTHERS THEN
      write_log_message(SQLERRM);
      p_message := 'Unexpected Error in find_match_sites :' || SQLERRM;
      p_status  := 'E';
  END find_match_sites;

  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : create_person                                                                                                *
  * Script Name         : xxhz_api_pkg.pkb                                                                                        *
  *                                                                                                                                         *
  * Purpose             :  This procedure will call the hz_party_v2pub.create_person api to create Person in
                           S3 system with the same data of SFDC environment. This api will populate all the
                           person data to the Legacy system                                                                                                             *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     11/05/2016  Somnath Dawn                Initial version                                                                                      *
  ******************************************************************************************************************************************/
  PROCEDURE create_person(p_person_record IN hz_party_v2pub.person_rec_type,
		  p_party_id      OUT NUMBER,
		  p_api_status    OUT VARCHAR2,
		  p_error_msg     OUT VARCHAR2) IS
    l_new_subject_id NUMBER;
    l_party_number   NUMBER;
    l_profile_id     NUMBER;
    l_return_status  VARCHAR2(10);
    l_msg_count      NUMBER;
    l_msg_data       VARCHAR2(6000);
    l_error_msg      VARCHAR2(6000);
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.create_person Procedure',
	          'Y');
  
    hz_party_v2pub.create_person(p_init_msg_list => fnd_api.g_true, -- Added on 29.03.17 By Lingaraj
		         p_person_rec    => p_person_record, -- In Param
		         x_party_id      => p_party_id, --Out Param
		         x_party_number  => l_party_number, --Out Param
		         x_profile_id    => l_profile_id, --Out Param
		         x_return_status => p_api_status, --Out Param
		         x_msg_count     => l_msg_count, --Out Param
		         x_msg_data      => l_msg_data); --Out Param
  
    --p_party_id   := l_new_subject_id;
    --p_api_status := l_return_status;
  
    IF l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
        /*write_log_message(i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
        1,
        255));*/
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
	           substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
		      1,
		      255);
      
      END LOOP;
      l_msg_data := l_msg_data || '.' || l_error_msg;
    END IF;
  
    IF g_debug = TRUE THEN
      write_log_message('l_party_id = ' || p_party_id || ' Party Number=' ||
		l_party_number);
      write_log_message('Create Person p_api_status=' || l_return_status);
      write_log_message('Create Person l_msg_data = ' || l_msg_data);
    END IF;
  
    p_error_msg := l_msg_data;
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.create_person Procedure');
  END create_person;
  /******************************************************************************************************************************************
    * Type                : Procedure                                                                                                         *
    * Module Name         : AR_CUSTOMERS                                                                                                      *
    * Name                : update_person                                                                                                *
    * Script Name         : xxhz_api_pkg.pkb                                                                                        *
    *                                                                                                                                         *
                                                                                                                                              *                                                                                                                                            *
    * Purpose             :  This procedure will call the hz_party_v2pub.update_person api to update the Person in
                             S3 system with the same data of SFDC environment. This api will populate all the
                             updated person data to the Legacy system                                                                                                       *
                                                                                                                                              *
    * HISTORY                                                                                                                                 *
    * =======                                                                                                                                 *
    * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
    * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     11/05/2016  Somnath Dawn                Initial version                                                                                      *
    ******************************************************************************************************************************************/
  PROCEDURE update_person(p_person_record IN hz_party_v2pub.person_rec_type,
		  p_obj_version   IN OUT NOCOPY NUMBER,
		  p_api_status    OUT VARCHAR2,
		  p_error_msg     OUT VARCHAR2) IS
    l_profile_id NUMBER;
    --l_return_status      VARCHAR2(10);
    l_msg_count NUMBER;
    --l_msg_data           VARCHAR2(4000);
    l_error_msg VARCHAR2(4000);
    --l_obj_version_number NUMBER;
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.update_person Procedure',
	          'Y');
    --l_obj_version_number := p_obj_version;
    hz_party_v2pub.update_person(p_person_rec                  => p_person_record,
		         p_party_object_version_number => p_obj_version,
		         x_profile_id                  => l_profile_id,
		         x_return_status               => p_api_status,
		         x_msg_count                   => l_msg_count,
		         x_msg_data                    => p_error_msg);
  
    --p_api_status := l_return_status;
    --p_error_msg  := l_msg_data;
  
    IF l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
        /*write_log_message(i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
        1,
        255));*/
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
	           substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
		      1,
		      255);
      END LOOP;
      p_error_msg := p_error_msg || '.' || l_error_msg;
    END IF;
  
    write_log_message('hz_party_v2pub.update_person API Call Status / Error Message :' ||
	          p_api_status || '/Error:' || p_error_msg);
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.update_person Procedure');
  EXCEPTION
    WHEN OTHERS THEN
      write_log_message('Unexpected error in xxhz_soa_api_pkg.update_person :' ||
		SQLERRM);
  END update_person;

  /******************************************************************************************************************************************
    * Type                : Procedure                                                                                                         *
    * Module Name         : AR_CUSTOMERS                                                                                                      *
    * Name                : update_organization                                                                                                *
    * Script Name         : xxhz_api_pkg.pkb                                                                                        *
    *                                                                                                                                         *
                                                                                                                                              *                                                                                                                                            *
    * Purpose             :  This procedure will call the hz_party_v2pub.update_organization api to update
                             organization type party in S3 system with the same data of SFDC environment. This api will update all the
                             Organization type party data to the S3 system collected through the SOA Integration view
                                                                                                                        *
                                                                                                                                              *
    * HISTORY                                                                                                                                 *
    * =======                                                                                                                                 *
    * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
    * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     11/05/2016  Somnath Dawn                Initial version                                                                                      *
    ******************************************************************************************************************************************/

  PROCEDURE update_organization(p_organization_record   IN hz_party_v2pub.organization_rec_type,
		        p_party_obj_version_num IN NUMBER,
		        p_api_status            OUT VARCHAR2,
		        p_error_msg             OUT VARCHAR2) IS
    l_return_status         VARCHAR2(10);
    l_msg_count             NUMBER;
    l_msg_data              VARCHAR2(1000);
    x_profile_id            NUMBER;
    l_error_msg             VARCHAR2(4000);
    l_party_obj_version_num NUMBER := p_party_obj_version_num;
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.update_organization Procedure',
	          'Y');
    hz_party_v2pub.update_organization(p_organization_rec            => p_organization_record,
			   p_party_object_version_number => l_party_obj_version_num,
			   x_profile_id                  => x_profile_id,
			   x_return_status               => l_return_status,
			   x_msg_count                   => l_msg_count,
			   x_msg_data                    => l_msg_data);
  
    p_api_status := l_return_status;
    p_error_msg  := l_msg_data;
    IF l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
        /*write_log_message(i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
        1,
        255));*/
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
	           substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
		      1,
		      255);
      END LOOP;
      p_error_msg := l_error_msg;
    END IF;
    write_log_message('Program Exited : xxhz_soa_api_pkg.update_organization Procedure');
  EXCEPTION
    WHEN OTHERS THEN
      write_log_message('Unexpected error in xxhz_soa_api_pkg.update_organization: ' ||
		SQLERRM);
  END update_organization;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : create_location                                                                                                *
  * Script Name         : xxhz_api_pkg.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the HZ_LOCATION_V2PUB.CREATE_LOCATION api to create party location
                           in S3 system with the same data of SFDC environment. This api will create the
                           party location to the S3 system collected through the SOA Integration
                                                                                                                      *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     11/05/2016  Somnath Dawn        initial version     
  -- 1.1     16.1.19     yuval tal           CHG0042632 US state name logic change                                                                                *
  ******************************************************************************************************************************************/
  PROCEDURE create_location(p_location_record IN OUT hz_location_v2pub.location_rec_type,
		    p_location_id     OUT NUMBER,
		    p_api_status      OUT VARCHAR2,
		    p_error_msg       OUT VARCHAR2) IS
    l_location_id NUMBER;
    lx_api_status VARCHAR2(1);
    lx_error_msg  VARCHAR2(1000);
    l_msg_count   NUMBER;
    l_msg_data    VARCHAR2(6000);
    l_state_name  VARCHAR2(240) := p_location_record.state;
    l_state_code  VARCHAR2(20) := NULL;
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.create_location Procedure');
    -----------------------------------------
    -- Verify the State Code if Country is US
    -----------------------------------------
    IF p_location_record.country = 'US' THEN
      l_state_code := l_state_name; -- yuval 16.1.19
      l_state_name := NULL; --- yuval  16.1.19
      get_usa_state_code_or_name(p_state_name => l_state_name, --in out --  
		         p_state_code => l_state_code, --l_state_code, 
		         x_api_status => p_api_status, --Out
		         x_error_msg  => p_error_msg);
      IF p_api_status != fnd_api.g_ret_sts_success THEN
        RETURN;
      ELSE
        -- If State Code found Then
        p_location_record.state := l_state_code;
      END IF;
    END IF;
    ---------------------------------------------------
    -- Calling Create Location API .
    ---------------------------------------------------
    hz_location_v2pub.create_location(p_init_msg_list => fnd_api.g_true,
			  p_location_rec  => p_location_record, --In Param
			  x_location_id   => p_location_id, --Out Param
			  x_return_status => p_api_status,
			  x_msg_count     => l_msg_count,
			  x_msg_data      => p_error_msg);
  
    write_log_message('Create Location p_api_status & Error Message =' ||
	          p_api_status || '/Error Messsage :' || p_error_msg);
  
    IF l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
        /*write_log_message(i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
        1,
        255));*/
        l_msg_data := l_msg_data || '(' || i || ')' ||
	          substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
		     1,
		     255);
      END LOOP;
      write_log_message(l_msg_data);
    END IF;
  
    IF p_api_status != fnd_api.g_ret_sts_success THEN
      p_error_msg := p_error_msg || '.' || l_msg_data;
    ELSIF p_api_status = fnd_api.g_ret_sts_success AND
          p_location_record.country = 'US' THEN
      ---------------------------------------------------
      -- If Country = US, then Avalara verifies the Address and try to correct the address
      -- if not possiable, rejects the Address Creation
      -- OA2SFDC send back the Corrected Address incase Country is US
      ---------------------------------------------------
      BEGIN
        SELECT substr((address1 ||
	          decode(address2, NULL, '', ',' || address2) ||
	          decode(address3, NULL, '', ',' || address3) ||
	          decode(address4, NULL, '', ',' || address4)),
	          1,
	          240) address,
	   city,
	   state,
	   postal_code,
	   county
        INTO   p_location_record.address1,
	   p_location_record.city,
	   l_state_code,
	   --p_location_record.state,
	   p_location_record.postal_code,
	   p_location_record.county
        FROM   hz_locations
        WHERE  location_id = p_location_id;
      
        --Set State Name
        l_state_name := NULL;
        get_usa_state_code_or_name(p_state_name => l_state_name, --in out
		           p_state_code => l_state_code,
		           x_api_status => lx_api_status, --Out
		           x_error_msg  => lx_error_msg);
        IF lx_api_status != fnd_api.g_ret_sts_success THEN
          p_error_msg := p_error_msg || lx_error_msg;
          RETURN;
        ELSE
          -- If State Code found Then
          p_location_record.state := l_state_name;
        END IF;
      
      EXCEPTION
        WHEN no_data_found THEN
          NULL;
      END;
    END IF;
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.create_location Procedure');
  EXCEPTION
    WHEN OTHERS THEN
      p_api_status := fnd_api.g_ret_sts_error;
      p_error_msg  := 'Unexpected Error in xxhz_soa_api_pkg.create_location :' ||
	          SQLERRM;
      write_log_message('Program Exited : xxhz_soa_api_pkg.create_location Procedure With Error :' ||
		p_error_msg);
  END create_location;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Conversion Name     :                                                                                                                   *
  * Name                : update_location                                                                                                        *
  * Script Name         : xxhz_api_pkg.pkb                                                                                                    *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             : This Procedure is Used to Update Location in S3 Environment if there is any modification                              *
                          of Location Entity in SFDC Environment.                                                                             *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                     *
  * -------  ----------- ---------------    ------------------------------------                                                            *
  * 1.00     11/05/2016  Somnath Dawn                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE update_location(p_location_rec          IN OUT hz_location_v2pub.location_rec_type,
		    p_object_version_number IN OUT NOCOPY NUMBER,
		    p_api_status            OUT VARCHAR2,
		    p_error_msg             OUT VARCHAR2) IS
  
    lx_api_status VARCHAR2(1);
    lx_error_msg  VARCHAR2(1000);
    l_msg_count   NUMBER;
    l_error_msg   VARCHAR2(4000);
    l_state_name  VARCHAR2(240) := p_location_rec.state;
    l_state_code  VARCHAR2(20) := NULL;
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.update_location Procedure');
    ---------------------------------------
    --Get Object version number if supplied
    ----------------------------------------
    IF p_object_version_number IS NULL THEN
      BEGIN
        SELECT object_version_number
        INTO   p_object_version_number
        FROM   hz_locations
        WHERE  location_id = p_location_rec.location_id;
      EXCEPTION
        WHEN OTHERS THEN
          p_api_status := fnd_api.g_ret_sts_error;
          l_error_msg  := 'Unexpected Error in xxhz_soa_api_pkg.update_location :' ||
		  'Error During Location Object version fetch.' ||
		  SQLERRM;
          RETURN;
      END;
    END IF;
    -----------------------------------------
    -- Verify the State Code if Country is US
    -----------------------------------------
    IF p_location_rec.country = 'US' THEN
      get_usa_state_code_or_name(p_state_name => l_state_name, --in out
		         p_state_code => l_state_code,
		         x_api_status => p_api_status, --Out
		         x_error_msg  => p_error_msg);
      IF p_api_status != fnd_api.g_ret_sts_success THEN
        RETURN;
      ELSE
        -- If State Code found Then
        p_location_rec.state := l_state_code;
      END IF;
    END IF;
  
    ---------------------------------------------------
    -- Calling Update Location API .
    ---------------------------------------------------
    hz_location_v2pub.update_location(p_init_msg_list         => fnd_api.g_false,
			  p_location_rec          => p_location_rec,
			  p_object_version_number => p_object_version_number, --In Out Param
			  x_return_status         => p_api_status,
			  x_msg_count             => l_msg_count,
			  x_msg_data              => p_error_msg);
  
    IF l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
        l_error_msg := l_error_msg || '(' || i || ')' ||
	           substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
		      1,
		      255);
      
      END LOOP;
      p_error_msg := p_error_msg || '.' || l_error_msg;
    END IF;
  
    write_log_message('-----------hz_location_v2pub.update_location API Status :' ||
	          p_api_status || chr(10) || p_error_msg);
  
    IF p_api_status = fnd_api.g_ret_sts_success AND
       p_location_rec.country = 'US' THEN
      ---------------------------------------------------
      -- If Country = US, then Avalara verifies the Address and try to correct the address
      -- if not possiable, rejects the Address Creation or Updation
      -- OA2SFDC send back the Corrected Address incase Country is US
      ---------------------------------------------------
      BEGIN
        SELECT substr((address1 ||
	          decode(address2, NULL, '', ',' || address2) ||
	          decode(address3, NULL, '', ',' || address3) ||
	          decode(address4, NULL, '', ',' || address4)),
	          1,
	          240) address,
	   city,
	   state,
	   postal_code,
	   county
        INTO   p_location_rec.address1,
	   p_location_rec.city,
	   --p_location_rec.state,
	   l_state_code,
	   p_location_rec.postal_code,
	   p_location_rec.county
        FROM   hz_locations
        WHERE  location_id = p_location_rec.location_id
        AND    object_version_number = p_object_version_number;
      
        --Set State Name
        l_state_name := NULL;
        get_usa_state_code_or_name(p_state_name => l_state_name, --in out
		           p_state_code => l_state_code,
		           x_api_status => lx_api_status, --Out
		           x_error_msg  => lx_error_msg --out
		           );
        IF lx_api_status = fnd_api.g_ret_sts_success THEN
          p_location_rec.state := l_state_name;
        ELSE
          p_error_msg := p_error_msg || lx_error_msg;
        END IF;
      
      EXCEPTION
        WHEN no_data_found THEN
          NULL;
      END;
    END IF;
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.update_location Procedure');
  EXCEPTION
    WHEN OTHERS THEN
      p_api_status := fnd_api.g_ret_sts_error;
      l_error_msg  := 'Unexpected Error in xxhz_soa_api_pkg.update_location :' ||
	          SQLERRM;
      write_log_message(l_error_msg);
  END update_location;

  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : create_party_site                                                                                                *
  * Script Name         : xxhz_api_pkg.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_party_site_v2pub.create_party_site api to create party Site
                           in S3 system with the same data of SFDC environment. This api will create the
                           party site to the S3 system collected through the SOA Integration
                                                                                                                      *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)           DESCRIPTION                                                                                        *
  * -------  ----------- ---------------     ------------------------------------                                                               *
  * 1.00     11/05/2016  Somnath Dawn        Initial version
  * 1.1      21.03.2017  Lingaraj Sarangi    CHG0040057 - Adding p_party_site_number as Output Parameter                                    *
  ******************************************************************************************************************************************/
  PROCEDURE create_party_site(p_party_site_record IN hz_party_site_v2pub.party_site_rec_type,
		      p_party_site_id     OUT NUMBER,
		      p_party_site_number OUT hz_party_sites.party_site_number%TYPE,
		      p_api_status        OUT VARCHAR2,
		      p_error_msg         OUT VARCHAR2) IS
    --x_party_site_id     NUMBER;
    --x_party_site_number hz_party_sites.party_site_number%TYPE;
    --l_return_status     VARCHAR2(10);
    l_msg_count NUMBER;
    l_msg_data  VARCHAR2(1000);
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.create_party_site Procedure');
  
    hz_party_site_v2pub.create_party_site(p_init_msg_list     => fnd_api.g_true,
			      p_party_site_rec    => p_party_site_record,
			      x_party_site_id     => p_party_site_id, -- Modified on 21.03.2017
			      x_party_site_number => p_party_site_number, -- Modified on 21.03.2017
			      x_return_status     => p_api_status, -- Modified on 21.03.2017
			      x_msg_count         => l_msg_count,
			      x_msg_data          => p_error_msg); -- Modified on 21.03.2017
    --p_api_status    := l_return_status;
    --p_party_site_id := x_party_site_id;
  
    IF l_msg_count > 1 AND g_debug = TRUE THEN
      -- Modified on 21.03.2017
      FOR i IN 1 .. l_msg_count LOOP
        write_log_message(i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
			          1,
			          255));
      
      END LOOP;
    END IF;
    --p_error_msg := l_msg_data;
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.create_party_site Procedure');
  EXCEPTION
    WHEN OTHERS THEN
      p_api_status := 'E';
      p_error_msg  := SQLERRM;
  END create_party_site;

  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : upsert_account                                                                                                *
  * Script Name         : xxhz_soa_api_pkg.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will be called through SOA integration to create/update the accounts
                           in S3 system with the same data of SFDC environment. This procedure will create the
                           accounts to the S3 system collected through the SOA Integration
  * Change Number       : CHG0040057 - New Account, Contact, Site and check duplication Interfaces between SFDC and Oracle                                                                                                                    *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                     *
  * -------  ----------- ---------------    ------------------------------------                                                            *
  * 1.00     11/05/2016  Somnath Dawn       Initial version
  * 1.1      25/02/2017  Lingaraj Sarangi   CHG0040057 -
  * 1.2      12/13/2017  Diptasurjya        CHG0042044 - Make calls compatiable with Strataforce                                            *
  * 1.3      4.Sep.2018  Lingaraj          CHG0043843 - SFDC to Oracle interface- add new field- customer category                         *
  * 1.4      20.Nov.2018 Lingaraj           CHG0042632 - CTASK0039365 - Sync Location to Strataforce
  ******************************************************************************************************************************************/
  PROCEDURE upsert_account(p_source           IN VARCHAR2,
		   p_soa_reference_id IN NUMBER,
		   p_account_in       IN OUT xxobjt.xxhz_accounts_tab,
		   p_account_out      OUT xxobjt.xxhz_accounts_tab,
		   p_status           OUT VARCHAR2,
		   p_message          OUT VARCHAR2) IS
    l_org_record           hz_party_v2pub.organization_rec_type;
    l_cust_account_record  hz_cust_account_v2pub.cust_account_rec_type;
    l_cust_prof_record     hz_customer_profile_v2pub.customer_profile_rec_type;
    l_contact_point_record hz_contact_point_v2pub.contact_point_rec_type;
    l_edi_rec              hz_contact_point_v2pub.edi_rec_type;
    l_email_rec            hz_contact_point_v2pub.email_rec_type;
    l_phone_rec            hz_contact_point_v2pub.phone_rec_type;
    l_telex_rec            hz_contact_point_v2pub.telex_rec_type;
    l_web_rec              hz_contact_point_v2pub.web_rec_type;
    l_object_version_num   NUMBER;
    l_party_id             NUMBER;
    l_cust_account_id      NUMBER;
    l_contact_point_id     NUMBER;
    l_resp_id              NUMBER;
    l_resp_appl_id         NUMBER;
    l_user_id              NUMBER;
    l_contct_pnt_vrsn_num  NUMBER;
    l_main_status          VARCHAR2(1) := NULL; --S/E/U(SUCCESS/ERROR/UNEXPECTED ERROR)
    l_account_status       VARCHAR2(10) := NULL;
    l_main_err_msg         VARCHAR2(4000) := NULL;
    l_api_status           VARCHAR2(10) := NULL;
    l_error_msg            VARCHAR2(4000) := NULL;
    x_status               VARCHAR2(1) := NULL; --S/E/U(SUCCESS/ERROR/UNEXPECTED ERROR)
    x_message              VARCHAR2(4000) := NULL;
    l_rec_err_msg          VARCHAR2(4000);
    l_dumy_out_num         NUMBER;
    l_dumy_out_num1        NUMBER;
    l_account_number       hz_cust_accounts_all.account_number%TYPE;
    --l_record_count        NUMBER;
    l_cust_out_rec xxhz_accounts_rec;
    l_cust_out_tab xxhz_accounts_tab := xxhz_accounts_tab();
  
    l_contact_in_rec xxhz_contact_rec;
    l_contact_in_tab xxhz_contact_tab := xxhz_contact_tab();
  
    l_sites_in_rec  xxhz_site_rec;
    l_sites_in_tab  xxhz_site_tab := xxhz_site_tab();
    l_sites_out_tab xxhz_site_tab := xxhz_site_tab();
  
    l_contact_out_tab xxhz_contact_tab := xxhz_contact_tab();
  
    l_errbuf           VARCHAR2(4000); -- CHG0041658
    l_retcode          VARCHAR2(10); -- CHG0041658
    l_xxssys_event_rec xxssys_events%ROWTYPE; --CHG0042632 - CTASK0039365
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.UPSERT_ACCOUNT Procedure');
  
    --This will Set all required Global Variables , which going to change depend on the Source
    --set_global_variables(p_source);
  
    p_status := fnd_api.g_ret_sts_success; /*Procedure Out Status Set to Success*/
    --Get the User details & initilize Apps for Processing the Record
    set_my_session( --p_username       => NULL, --In Param -- CHG0042044 - Dipta commented
	       p_source         => p_source, -- CHG0042044 - Dipta added
	       p_status_out     => p_status, --Out Param
	       p_status_msg_out => p_message --Out Param
	       );
  
    IF p_status != fnd_api.g_ret_sts_success THEN
      RAISE user_not_valid_exp;
    END IF;
  
    --l_record_count := p_account_in.count;
    --If the Input Parameter Contains any Record, it will proceed furthur else raise an Exception
    IF p_account_in.count > 0 THEN
      write_log_message('****No of account in p_account_in :' ||
		p_account_in.count);
    ELSE
      p_message := 'Parameter p_account_in does not contain any Account information for Process.';
      RAISE no_rec_to_process_exp;
    END IF;
  
    --Start the Process of the Account Records
    FOR i IN 1 .. p_account_in.count LOOP
      l_main_status                  := fnd_api.g_ret_sts_success;
      l_rec_err_msg                  := NULL;
      l_org_record                   := NULL;
      l_cust_account_record          := NULL;
      l_cust_prof_record             := NULL;
      l_phone_rec                    := NULL;
      l_telex_rec                    := NULL;
      l_web_rec                      := NULL;
      l_edi_rec                      := NULL;
      l_email_rec                    := NULL;
      l_phone_rec.phone_area_code    := NULL;
      l_phone_rec.phone_country_code := NULL;
      l_account_number               := NULL;
      l_account_status               := NULL;
      l_cust_account_id              := NULL;
      l_cust_out_rec                 := xxhz_accounts_rec(NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL,
				          NULL); --25 Variables  -- CHG0042044 added extra null
    
      --l_cust_out_tab is of xxhz_accounts_tab Type
      l_cust_out_tab.extend;
      /*
      -- Not Validating the ID's against the System, If the Id's are not available , then it will failed by the API.
      -----------------------------------Converting ID's----------------------------------------
      IF p_account_in(i).account_id IS NOT NULL THEN
        l_cust_out_rec.account_id := p_account_in(i).account_id;
        --        p_account_in(i).account_id := xxcust_convert_xref_pkg.convert_allied_to_s3('ACCT-NUMBER',p_account_in(i).account_id); -- CHG0040057 -  Remark By Adi Safin, No S3
      
      END IF;
      
      IF p_account_in(i).oe_email_contact_point_id IS NOT NULL THEN
        l_cust_out_rec.oe_email_contact_point_id := p_account_in(i)
                                                    .oe_email_contact_point_id;
        --        p_account_in(i).oe_email_contact_point_id := xxcust_convert_xref_pkg.convert_allied_to_s3('ACCT-CONTACTS',p_account_in(i).oe_email_contact_point_id); --  CHG0040057 - Remark By Adi Safin, No S3
      
      END IF;
      
      IF p_account_in(i).oe_fax_contact_point_id IS NOT NULL THEN
        l_cust_out_rec.oe_fax_contact_point_id := p_account_in(i)
                                                  .oe_fax_contact_point_id;
        --        p_account_in(i).oe_fax_contact_point_id := xxcust_convert_xref_pkg.convert_allied_to_s3('ACCT-CONTACTS',p_account_in(i).oe_fax_contact_point_id);-- CHG0040057 - Remark By Adi Safin, No S3
      
      END IF;
      
      IF p_account_in(i).oe_phone_contact_point_id IS NOT NULL THEN
        l_cust_out_rec.oe_phone_contact_point_id := p_account_in(i)
                                                    .oe_phone_contact_point_id;
        --        p_account_in(i).oe_phone_contact_point_id := xxcust_convert_xref_pkg.convert_allied_to_s3('ACCT-CONTACTS',p_account_in(i).oe_phone_contact_point_id); -- CHG0040057 - Remark By Adi Safin, No S3
      
      END IF;
      
      IF p_account_in(i).oe_web_contact_point_id IS NOT NULL THEN
        l_cust_out_rec.oe_web_contact_point_id := p_account_in(i)
                                                  .oe_web_contact_point_id;
        --        p_account_in(i).oe_web_contact_point_id := xxcust_convert_xref_pkg.convert_allied_to_s3('ACCT-CONTACTS',p_account_in(i).oe_web_contact_point_id); -- CHG0040057 - Remark By Adi Safin, No S3
      
      END IF;
      
      IF p_account_in(i).oe_mobile_contact_point_id IS NOT NULL THEN
        l_cust_out_rec.oe_mobile_contact_point_id := p_account_in(i)
                                                     .oe_mobile_contact_point_id;
        --        p_account_in(i).oe_mobile_contact_point_id := xxcust_convert_xref_pkg.convert_allied_to_s3('ACCT-CONTACTS',p_account_in(i).oe_mobile_contact_point_id); -- CHG0040057 - Remark By Adi Safin, No S3
      
      END IF;*/
      --------------------------------End of Converting ID's------------------------------------
      l_cust_out_rec.account_id                 := p_account_in(i)
				   .account_id;
      l_cust_out_rec.oe_email_contact_point_id  := p_account_in(i)
				   .oe_email_contact_point_id;
      l_cust_out_rec.oe_fax_contact_point_id    := p_account_in(i)
				   .oe_fax_contact_point_id;
      l_cust_out_rec.oe_phone_contact_point_id  := p_account_in(i)
				   .oe_phone_contact_point_id;
      l_cust_out_rec.oe_web_contact_point_id    := p_account_in(i)
				   .oe_web_contact_point_id;
      l_cust_out_rec.oe_mobile_contact_point_id := p_account_in(i)
				   .oe_mobile_contact_point_id;
    
      /* CHG0042044 - Start Validate account_ID and account_number - Dipta*/
      IF p_account_in(i)
       .account_id IS NULL AND p_account_in(i).account_number IS NOT NULL THEN
        BEGIN
          p_account_in(i).account_id := fetch_customer_account_id(NULL,
					      p_account_in(i)
					      .account_number);
        EXCEPTION
          WHEN no_data_found THEN
	l_cust_out_rec.error_code := fnd_api.g_ret_sts_error; -- If Return Value U, then Also the Value Returned in E
	l_cust_out_rec.error_msg := 'VALIDATION ERROR: Customer account number: ' || p_account_in(i)
			   .account_number || ' is not valid';
	l_cust_out_tab(l_cust_out_tab.count) := l_cust_out_rec;
	CONTINUE;
        END;
      END IF;
      /* CHG0042044 - End */
    
      l_org_record.organization_name := p_account_in(i).account_name;
      -- In Case of Update need to Null , need to Pass fnd_api.g_null_char for DUNS number.
      l_org_record.duns_number_c              := nvl(p_account_in(i)
				     .duns_number,
				     fnd_api.g_null_char);
      l_org_record.sic_code                   := p_account_in(i).sic_code; -- CHG0042044
      l_cust_account_record.account_name      := p_account_in(i)
				 .account_name;
      l_org_record.organization_name_phonetic := p_account_in(i)
				 .account_name_local;
      /* Commented on CHG0043843
      l_org_record.party_rec.category_code    := 'CUSTOMER';
      */
    
      --New Account Need to Create if the Account ID is not Provided
      IF p_account_in(i).account_id IS NULL THEN
        l_org_record.created_by_module          := g_created_by_module; -- CHG0040057 - Change By Adi Safin
        l_cust_account_record.created_by_module := g_created_by_module; -- CHG0040057 - Change By Adi Safin
        l_cust_account_record.customer_type     := g_customer_type; --'R'; --Customer type is External for all SFDC Customer
        /* --Commented for CHG0043843
        l_cust_account_record.sales_channel_code := g_sales_channel_code; --'DIRECT'; --Sales Channel is DIRECT for all SFDC Customer
        */
        IF upper(p_source) = g_old_sfdc_source THEN
          -- CHG0042044
          l_cust_account_record.attribute4     := p_account_in(i)
				  .source_reference_id;
          l_org_record.party_rec.category_code := 'CUSTOMER'; --Added on CHG0043843
        ELSE
          --Begin Get Customer Category Code # CHG0043843
        
          BEGIN
	l_org_record.party_rec.category_code := get_customer_category_code(p_account_in(i)
						       .category_code);
          EXCEPTION
	WHEN OTHERS THEN
	  l_cust_out_rec.error_code := fnd_api.g_ret_sts_error; -- If Return Value U, then Also the Value Returned in E
	  l_cust_out_rec.error_msg := 'VALIDATION ERROR: Customer Category Code : ' || p_account_in(i)
			     .category_code ||
			      ' is not valid. sql error :' ||
			      SQLERRM;
	  l_cust_out_tab(l_cust_out_tab.count) := l_cust_out_rec;
	  CONTINUE;
          END;
          --End Get Customer Category Code # CHG0043843
        END IF; -- CHG0042044
        --sales_channel_code Depends on  category_code
        --sales_channel_code Logic Added # CHG0043843
        l_cust_account_record.sales_channel_code := get_sales_channel_code(upper(l_org_record.party_rec.category_code));
      
        l_cust_account_record.attribute14 := p_account_in(i).department;
        l_cust_account_record.attribute16 := p_account_in(i)
			         .institution_type;
        l_cust_account_record.attribute19 := nvl(p_account_in(i)
				 .cross_industry,
				 fnd_api.g_null_char);
      
        l_api_status := NULL;
        l_error_msg  := NULL;
        l_party_id   := NULL;
        --Create Account
        create_account(p_org_record          => l_org_record, --in Param
	           p_cust_account_record => l_cust_account_record, --in Param
	           p_cust_prof_record    => l_cust_prof_record, --in Param
	           p_cust_account_id     => l_cust_account_id, --Out Param
	           p_party_id            => l_party_id, --Out Param
	           p_api_status          => l_api_status, --Out Param
	           p_error_msg           => l_error_msg --Out Param
	           );
      
        --If Account Creation Error Out then Update the Record and skip to the Next Record
        IF l_api_status != fnd_api.g_ret_sts_success THEN
          l_main_status             := fnd_api.g_ret_sts_error;
          l_main_err_msg            := l_error_msg;
          l_cust_out_rec.error_code := fnd_api.g_ret_sts_error; -- If Return Value U, then Also the Value Returned in E
          l_cust_out_rec.error_msg  := substr(l_error_msg, 1, 4000);
        
          l_cust_out_tab(l_cust_out_tab.count) := l_cust_out_rec;
          CONTINUE; --Skip to the Next Account Record
        ELSE
          BEGIN
	SELECT account_number,
	       status
	INTO   l_account_number,
	       l_account_status
	FROM   hz_cust_accounts_all
	WHERE  cust_account_id = l_cust_account_id;
          
	IF g_debug = TRUE THEN
	  write_log_message('**** l_party_id        :' || l_party_id);
	  write_log_message('**** Account Number    :' ||
		        l_account_number);
	  write_log_message('**** Account Status    :' ||
		        l_account_status);
	  write_log_message('**** l_api_status      :' || l_api_status);
	  write_log_message('**** l_error_msg       :' || l_error_msg);
	END IF;
          EXCEPTION
	WHEN no_data_found THEN
	  l_account_number := NULL;
	  l_account_status := NULL;
	WHEN OTHERS THEN
	  l_account_number := NULL;
	  l_account_status := NULL;
          END;
          write_log_message('**** CUST_ACCOUNT_ID :' || l_cust_account_id);
          /*write_log_message('Query to Verify: SELECT account_number,status
          FROM   hz_cust_accounts_all
          WHERE  cust_account_id = :cust_account_id');*/
        
          IF l_account_number IS NULL OR
	 l_account_number = fnd_api.g_null_char THEN
	l_cust_out_rec.error_code := fnd_api.g_ret_sts_error;
	l_cust_out_rec.error_msg := 'Failed To Create Account, but API returned Status Success.';
	l_cust_out_tab(l_cust_out_tab.count) := l_cust_out_rec;
	CONTINUE;
          END IF;
        
          l_rec_err_msg                 := l_rec_err_msg ||
			       'Account created successfully.';
          l_cust_out_rec.error_code     := fnd_api.g_ret_sts_success;
          l_cust_out_rec.account_id     := l_cust_account_id;
          l_cust_out_rec.account_number := l_account_number;
        END IF;
      
        IF l_api_status = fnd_api.g_ret_sts_success THEN
        
          --Create Industrial Classification (New Account Creation Case)
          IF p_account_in(i).industry IS NOT NULL THEN
	l_api_status := NULL;
	l_error_msg  := NULL;
	upsert_code_assignment(p_class_code    => p_account_in(i)
				      .industry, --In Param
		           p_party_id      => l_party_id, --In Param
		           x_return_status => l_api_status, --Out Param
		           x_msg_data      => l_error_msg --Out Param
		           );
          
	IF l_api_status != fnd_api.g_ret_sts_success THEN
	  write_log_message('Code assignment failed for Industrial Classification With Error : ' ||
		        l_error_msg);
	  l_rec_err_msg := l_rec_err_msg ||
		       'Code assignment failed for Industrial Classification.';
	END IF;
          
          END IF;
        
          l_contact_point_record.created_by_module := g_created_by_module; -- CHG0040057 - Change By Adi Safin
          l_contact_point_record.owner_table_name  := 'HZ_PARTIES';
          l_contact_point_record.owner_table_id    := l_party_id;
          ---------------------------NEW CODE----------------------------------------------------
          l_api_status := NULL;
          l_error_msg  := NULL;
          upsert_contact_point(p_phone_num             => p_account_in(i)
				          .phone, --  IN VARCHAR2, -- Send Phone Number
		       p_mobile_num            => NULL, --  IN VARCHAR2, -- Send  Mobile  Number
		       p_fax_num               => p_account_in(i).fax, --  IN VARCHAR2, -- Send  Fax  Number
		       p_email_address         => NULL, --  IN VARCHAR2,
		       p_web                   => p_account_in(i)
				          .website,
		       p_relationship_party_id => l_party_id, --IN NUMBER,
		       ----
		       x_oe_phone_contact_point_id  => l_cust_out_rec.oe_phone_contact_point_id, --IN OUT NOCOPY NUMBER,
		       x_oe_mobile_contact_point_id => l_dumy_out_num, --IN OUT NOCOPY NUMBER,
		       x_oe_fax_contact_point_id    => l_cust_out_rec.oe_fax_contact_point_id, --IN OUT NOCOPY NUMBER,
		       x_oe_email_contact_point_id  => l_dumy_out_num1, --IN OUT NOCOPY NUMBER,
		       x_oe_web_contact_point_id    => l_cust_out_rec.oe_web_contact_point_id, --IN OUT NOCOPY NUMBER,
		       ----
		       x_api_status => l_api_status, -- IN OUT NOCOPY VARCHAR2,
		       x_error_msg  => l_error_msg -- IN OUT NOCOPY VARCHAR2
		       );
          IF l_api_status != fnd_api.g_ret_sts_success THEN
	l_main_status  := fnd_api.g_ret_sts_error;
	l_main_err_msg := l_error_msg;
          END IF;
        
        END IF;
        l_cust_out_rec.account_id  := l_cust_account_id;
        l_cust_out_rec.duns_number := p_account_in(i).duns_number;
      
      ELSE
        ----------------------------------------
        --Update Existing Account Information
        ----------------------------------------
        l_cust_account_id         := p_account_in(i).account_id;
        l_cust_out_rec.account_id := l_cust_account_id;
      
        l_cust_account_record.created_by_module := NULL;
        l_org_record.created_by_module          := NULL;
        l_cust_account_record.cust_account_id   := l_cust_account_id;
        l_cust_account_record.attribute19       := nvl(p_account_in(i)
				       .cross_industry,
				       fnd_api.g_null_char);
        l_cust_account_record.attribute14       := nvl(p_account_in(i)
				       .department,
				       fnd_api.g_null_char);
        l_cust_account_record.attribute16       := nvl(p_account_in(i)
				       .institution_type,
				       fnd_api.g_null_char);
        --Begin CHG0043843
        IF upper(p_source) = g_old_sfdc_source THEN
          l_org_record.party_rec.category_code := p_account_in(i)
				  .category_code;
        ELSE
          BEGIN
	l_org_record.party_rec.category_code := get_customer_category_code(p_account_in(i)
						       .category_code);
          EXCEPTION
	WHEN OTHERS THEN
	  l_cust_out_rec.error_code := fnd_api.g_ret_sts_error; -- If Return Value U, then Also the Value Returned in E
	  l_cust_out_rec.error_msg := 'VALIDATION ERROR: Customer Category Code : ' || p_account_in(i)
			     .category_code ||
			      ' is not valid. sql error :' ||
			      SQLERRM;
	  l_cust_out_tab(l_cust_out_tab.count) := l_cust_out_rec;
	  CONTINUE;
          END;
        END IF;
        l_cust_account_record.sales_channel_code := get_sales_channel_code(upper(l_org_record.party_rec.category_code));
        --End CHG0043843
        IF l_cust_account_id IS NOT NULL THEN
          BEGIN
	SELECT hp.object_version_number,
	       hp.party_id,
	       hcaa.account_number,
	       hcaa.status
	INTO   l_object_version_num,
	       l_party_id,
	       l_account_number,
	       l_account_status
	FROM   hz_cust_accounts_all hcaa,
	       hz_parties           hp
	WHERE  hp.party_id = hcaa.party_id
	AND    hcaa.cust_account_id = l_cust_account_id;
          EXCEPTION
	WHEN OTHERS THEN
	  l_object_version_num := NULL;
	  l_party_id           := NULL;
          END;
        
          write_log_message('**** l_party_id        :' || l_party_id);
          write_log_message('**** Account Number    :' || l_account_number);
          write_log_message('**** Account Status    :' || l_account_status);
          write_log_message('**** CUST_ACCOUNT_ID   :' ||
		    l_cust_account_id);
        
          ----------------------------------------------------------------
          --Create / Update Industrial Classification (Account Updation Case)
          -- Create new if not exists
          -- Or Disable Old and Create New
          -- Or Disbale Old if No Value to Update
          -----------------------------------------------------------------
          l_api_status := NULL;
          l_error_msg  := NULL;
          IF /*p_account_in(i).industry IS NOT NULL AND*/
           l_party_id IS NOT NULL THEN
	upsert_code_assignment(p_class_code    => p_account_in(i)
				      .industry, --In Param
		           p_party_id      => l_party_id, --In Param
		           x_return_status => l_api_status, --Out Param
		           x_msg_data      => l_error_msg --Out Param
		           );
          
	IF l_api_status != fnd_api.g_ret_sts_success THEN
	  write_log_message('Code assignment failed for Industrial Classification With Error : ' ||
		        l_error_msg);
	  l_rec_err_msg := l_rec_err_msg ||
		       'Code assignment failed for Industrial Classification.';
	END IF;
          END IF;
        
          IF l_object_version_num IS NOT NULL THEN
	l_api_status                    := NULL;
	l_error_msg                     := NULL;
	l_org_record.party_rec.party_id := l_party_id;
	update_organization(p_organization_record   => l_org_record,
		        p_party_obj_version_num => l_object_version_num,
		        p_api_status            => l_api_status,
		        p_error_msg             => l_error_msg);
          END IF;
        
          IF l_api_status != fnd_api.g_ret_sts_success THEN
	l_main_status  := fnd_api.g_ret_sts_error;
	l_main_err_msg := l_error_msg;
          END IF;
        
          IF l_api_status = fnd_api.g_ret_sts_success THEN
	update_account(l_cust_account_record,
		   l_cust_prof_record,
		   l_api_status,
		   l_error_msg);
          END IF;
        
          IF l_api_status != fnd_api.g_ret_sts_success THEN
	l_main_status             := fnd_api.g_ret_sts_error;
	l_main_err_msg            := l_error_msg;
	l_cust_out_rec.error_code := fnd_api.g_ret_sts_error;
          ELSE
	l_cust_out_rec.error_code := fnd_api.g_ret_sts_success;
          END IF;
        
          --Updating UDA---
          /*process_uda(l_cust_account_id,
          p_account_in(i).industry,
          p_account_in(i).cross_industry,
          p_account_in(i).institution_type,
          p_account_in(i).department,
          l_api_status,
          l_error_msg);*/ -- CHG0040057 - Remark By Adi Safin, No S3, No CDH, No UDA
        END IF;
      
        --------------------------------------------
        --Updating Contact Points for Organization
        --------------------------------------------
        ---------------------------NEW CODE----------------------------------------------------
        l_api_status                             := NULL;
        l_error_msg                              := NULL;
        l_cust_out_rec.oe_phone_contact_point_id := p_account_in(i)
				    .oe_phone_contact_point_id;
        l_cust_out_rec.oe_fax_contact_point_id   := p_account_in(i)
				    .oe_fax_contact_point_id;
        l_cust_out_rec.oe_web_contact_point_id   := p_account_in(i)
				    .oe_web_contact_point_id;
      
        upsert_contact_point(p_phone_num             => p_account_in(i)
				        .phone, --  IN VARCHAR2, -- Send Phone Number
		     p_mobile_num            => NULL, --  IN VARCHAR2, -- Send  Mobile  Number
		     p_fax_num               => p_account_in(i).fax, --  IN VARCHAR2, -- Send  Fax  Number
		     p_email_address         => NULL, --  IN VARCHAR2,
		     p_web                   => p_account_in(i)
				        .website,
		     p_relationship_party_id => l_party_id, --IN NUMBER,
		     ----
		     x_oe_phone_contact_point_id  => l_cust_out_rec.oe_phone_contact_point_id, --IN OUT NOCOPY NUMBER,
		     x_oe_mobile_contact_point_id => l_dumy_out_num, --IN OUT NOCOPY NUMBER,
		     x_oe_fax_contact_point_id    => l_cust_out_rec.oe_fax_contact_point_id, --IN OUT NOCOPY NUMBER,
		     x_oe_email_contact_point_id  => l_dumy_out_num1, --IN OUT NOCOPY NUMBER,
		     x_oe_web_contact_point_id    => l_cust_out_rec.oe_web_contact_point_id, --IN OUT NOCOPY NUMBER,
		     ----
		     x_api_status => l_api_status, -- IN OUT NOCOPY VARCHAR2,
		     x_error_msg  => l_error_msg -- IN OUT NOCOPY VARCHAR2
		     );
        IF l_api_status != fnd_api.g_ret_sts_success THEN
          l_main_status  := fnd_api.g_ret_sts_error;
          l_main_err_msg := l_error_msg;
        END IF;
        ---------------------------------------------------------------------------------------
      
        -----------------------End of Updating Contact Points for Organization-------
      END IF;
    
      -------------------------------------------------------------
      -- Create or Update Contact Points By Calling UPSERT_CONTACTS
      -------------------------------------------------------------
      IF p_account_in(i).contact_xxhz_contact_tab.count > 0 THEN
        --Directly Assigning the Contacts Array of Records to Local Contat Array Table
        l_contact_in_tab := p_account_in(i).contact_xxhz_contact_tab;
      
        ---Assign the Account ID to Contact
        FOR k IN 1 .. l_contact_in_tab.count LOOP
          IF l_contact_in_tab(k).contact_id IS NULL THEN
	l_contact_in_tab(k).account_id := l_cust_account_id;
          END IF;
        END LOOP;
      
        upsert_contact(p_source           => p_source,
	           p_soa_reference_id => p_soa_reference_id,
	           p_contacts_in      => l_contact_in_tab,
	           p_contacts_out     => l_contact_out_tab,
	           p_status           => x_status,
	           p_message          => x_message);
      END IF;
    
      IF p_account_in(i).site_xxhz_site_tab.count > 0 THEN
        --Directly Assigning the Sites Array of Records to Local Site Array Table
        l_sites_in_tab := p_account_in(i).site_xxhz_site_tab;
        ---Assign the Account ID to Sites
        FOR k IN 1 .. l_sites_in_tab.count LOOP
          IF l_sites_in_tab(k).account_id IS NULL THEN
	l_sites_in_tab(k).account_id := l_cust_account_id;
          END IF;
        END LOOP;
      
        upsert_sites(p_source           => p_source,
	         p_soa_reference_id => p_soa_reference_id,
	         p_sites_in         => l_sites_in_tab,
	         p_sites_out        => l_sites_out_tab,
	         p_status           => x_status,
	         p_message          => x_message);
      
        IF x_status = fnd_api.g_ret_sts_success THEN
          IF l_sites_out_tab.count > 0 THEN
	l_cust_out_rec.ou_id := l_sites_out_tab(1).operating_unit;
          
	--Start CHG0042632 - CTASK0039365 - Sync Location to Strataforce
	IF upper(p_source) = 'STRATAFORCE' THEN
	  FOR i IN 1 .. l_sites_out_tab.count LOOP
	    IF l_sites_out_tab(i).error_code = 'S' AND l_sites_out_tab(i)
	       .site_id IS NOT NULL THEN
	      l_xxssys_event_rec                 := NULL;
	      l_xxssys_event_rec.target_name     := 'STRATAFORCE';
	      l_xxssys_event_rec.entity_name     := 'SITE';
	      l_xxssys_event_rec.entity_id       := l_sites_out_tab(i)
				        .site_id;
	      l_xxssys_event_rec.entity_code     := l_sites_out_tab(i)
				        .site_number;
	      l_xxssys_event_rec.event_name      := 'XXHZ_SOA_API_PKG.UPSERT_ACCOUNT';
	      l_xxssys_event_rec.last_updated_by := fnd_global.user_id;
	      l_xxssys_event_rec.created_by      := fnd_global.user_id;
	    
	      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
	    END IF;
	  END LOOP;
	END IF;
	--End CHG0042632 - CTASK0039365 - Sync Location to Strataforce
          END IF;
        END IF;
        --End If;
        --Added on 22.03.2017  Assign the OU ID
      
      END IF;
      -------------------------End of Assigning Site Record----------------------------
      IF l_account_status = 'A' THEN
        l_account_status := 'Active';
      END IF;
      IF l_account_status = 'I' THEN
        l_account_status := 'Inactive';
      END IF;
    
      l_cust_out_rec.source_reference_id := p_account_in(i)
			        .source_reference_id;
      l_cust_out_rec.account_name        := p_account_in(i).account_name;
      l_cust_out_rec.account_number      := l_account_number;
      l_cust_out_rec.oracle_status       := l_account_status;
      l_cust_out_rec.account_name_local  := p_account_in(i)
			        .account_name_local;
      l_cust_out_rec.fax                 := p_account_in(i).fax;
      l_cust_out_rec.industry            := p_account_in(i).industry;
      l_cust_out_rec.phone               := p_account_in(i).phone;
      l_cust_out_rec.website             := p_account_in(i).website;
      l_cust_out_rec.institution_type    := p_account_in(i).institution_type;
      l_cust_out_rec.cross_industry      := p_account_in(i).cross_industry;
      l_cust_out_rec.duns_number         := p_account_in(i).duns_number;
      l_cust_out_rec.department          := p_account_in(i).department;
    
      l_cust_out_rec.oe_email_contact_point_id := p_account_in(i)
				  .oe_email_contact_point_id;
      l_cust_out_rec.oe_mobile_contact_point_id := p_account_in(i)
				   .oe_mobile_contact_point_id;
      l_cust_out_rec.contact_xxhz_contact_tab := l_contact_out_tab;
      l_cust_out_rec.site_xxhz_site_tab := l_sites_out_tab;
      l_cust_out_tab(l_cust_out_tab.count) := l_cust_out_rec;
    
    END LOOP;
  
    p_account_out := l_cust_out_tab;
    p_status      := l_main_status;
    p_message     := l_main_err_msg;
    COMMIT;
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.UPSERT_ACCOUNT Procedure');
  
    IF (p_status = 'S') THEN
      -- CHG0041658
    
      submit_dqm_program(errbuf             => l_errbuf,
		 retcode            => l_retcode,
		 p_soa_reference_id => p_soa_reference_id);
    
    END IF;
  
  EXCEPTION
    WHEN user_not_valid_exp THEN
      p_status := fnd_api.g_ret_sts_error;
      write_log_message('Program Exited : xxhz_soa_api_pkg.UPSERT_ACCOUNT Procedure with Error :' ||
		p_message);
    WHEN no_rec_to_process_exp THEN
      p_status := fnd_api.g_ret_sts_error;
      write_log_message('Program Exited : xxhz_soa_api_pkg.UPSERT_ACCOUNT Procedure with Error :' ||
		p_message);
    WHEN OTHERS THEN
      p_status  := fnd_api.g_ret_sts_error;
      p_message := SQLERRM;
      write_log_message('Program Exited : xxhz_soa_api_pkg.UPSERT_ACCOUNT Procedure with Error :' ||
		p_message);
  END upsert_account;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : upsert_contact                                                                                                *
  * Script Name         : xxhz_api_pkg.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will be called through SOA integration to create/update the Contacts
                           in S3 system with the same data of SFDC environment. This procedure will create the
                           Contacts to the S3 system collected through the SOA Integration
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     11/05/2016  Somnath Dawn                Initial version
  * 1.1      12/13/2017  Diptasurjya        CHG0042044 - Make calls compatiable with Strataforce   
   .1.1.1    17.01.2019  yuval tal          CHG0042632  -- add dqp prog submission                                             *
  ******************************************************************************************************************************************/
  PROCEDURE upsert_contact(p_source           IN VARCHAR2,
		   p_soa_reference_id IN NUMBER,
		   p_contacts_in      IN OUT xxobjt.xxhz_contact_tab,
		   p_contacts_out     OUT xxobjt.xxhz_contact_tab,
		   p_status           OUT VARCHAR2,
		   p_message          OUT VARCHAR2) IS
    person_rec              hz_party_v2pub.person_rec_type;
    location_rec            hz_location_v2pub.location_rec_type;
    party_site_rec          hz_party_site_v2pub.party_site_rec_type;
    org_contact_rec         hz_party_contact_v2pub.org_contact_rec_type;
    rec_cust_acc_role       hz_cust_account_role_v2pub.cust_account_role_rec_type;
    contact_point_record    hz_contact_point_v2pub.contact_point_rec_type;
    email_rec               hz_contact_point_v2pub.email_rec_type;
    phone_rec               hz_contact_point_v2pub.phone_rec_type;
    l_territory_code        fnd_territories_vl.territory_code%TYPE;
    l_object_id             NUMBER;
    l_relationship_party_id NUMBER;
    l_person_party_id       NUMBER;
    x_org_contact_id        NUMBER;
    l_rel_party_id          NUMBER;
    l_person_obj_versn_num  NUMBER;
    l_location_id           NUMBER;
    l_resp_id               NUMBER;
    l_resp_appl_id          NUMBER;
    l_user_id               NUMBER;
    l_location_vrsn_num     NUMBER;
    l_psrty_site_vrsn_num   NUMBER;
    l_contact_point_id      NUMBER;
    l_contct_pnt_vrsn_num   NUMBER;
    l_party_id              NUMBER;
    l_party_site_id         NUMBER;
    l_api_status            VARCHAR2(10);
    l_error_msg             VARCHAR2(4000);
    l_main_status           VARCHAR2(10);
    l_main_err_msg          VARCHAR2(500);
    l_party_site_number     hz_party_sites.party_site_number%TYPE;
    l_cust_account_role_id  NUMBER;
    l_record_count          NUMBER;
    l_contact_out_rec       xxhz_contact_rec;
    l_contact_out_tab       xxhz_contact_tab := xxhz_contact_tab();
    l_steps                 VARCHAR2(2000);
    l_continuetonextstep    BOOLEAN;
    l_org_contact_obj_ver   NUMBER;
    l_org_contact_job_title VARCHAR2(100);
    
     l_errbuf           VARCHAR2(4000); -- 
    l_retcode          VARCHAR2(10); -- 
    
    --User Defined Exception
    -- user_not_valid_exp EXCEPTION;
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.upsert_contact Procedure');
  
    p_status := fnd_api.g_ret_sts_success;
  
    --This will Set all required Global Variables , which going to change depend on the Source
    --set_global_variables(p_source);
    --Get the User details & initilize Apps for Processing the Record
    IF g_is_session_set = FALSE THEN
      set_my_session( --p_username       => NULL, --In Param -- CHG0042044 - Dipta commented
	         p_source         => p_source, -- CHG0042044 - Dipta added
	         p_status_out     => p_status, --Out Param
	         p_status_msg_out => p_message --Out Param
	         );
    
      IF p_status != fnd_api.g_ret_sts_success THEN
        RAISE user_not_valid_exp;
      END IF;
    END IF;
  
    l_record_count := p_contacts_in.count;
    FOR i IN 1 .. l_record_count LOOP
      l_main_status                := fnd_api.g_ret_sts_success;
      person_rec                   := NULL;
      location_rec                 := NULL;
      party_site_rec               := NULL;
      org_contact_rec              := NULL;
      rec_cust_acc_role            := NULL;
      phone_rec.phone_area_code    := NULL;
      phone_rec.phone_country_code := NULL;
      l_continuetonextstep         := TRUE;
      l_cust_account_role_id       := NULL;
      l_org_contact_obj_ver        := fnd_api.g_miss_num;
      l_org_contact_job_title      := fnd_api.g_miss_char;
      l_contact_out_rec            := xxhz_contact_rec(NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL,
				       NULL -- CHG0042044 - added extra null
				       );
      l_contact_out_rec            := p_contacts_in(i);
    
      l_contact_out_tab.extend;
    
      /* CHG0042044 - Start Validate account_ID and account_number - Dipta*/
      IF l_contact_out_rec.account_id IS NULL AND
         l_contact_out_rec.account_number IS NULL THEN
        l_contact_out_rec.error_code := fnd_api.g_ret_sts_error;
        l_contact_out_rec.error_msg  := 'VALIDATION ERROR: Both Customer Account Number and account id is not having any value';
      
        l_contact_out_tab(l_contact_out_tab.count) := l_contact_out_rec;
        CONTINUE;
      END IF;
    
      IF l_contact_out_rec.account_id IS NULL AND
         l_contact_out_rec.account_number IS NOT NULL THEN
        BEGIN
          l_contact_out_rec.account_id := fetch_customer_account_id(NULL,
					        l_contact_out_rec.account_number);
        EXCEPTION
          WHEN no_data_found THEN
	l_contact_out_rec.error_code := fnd_api.g_ret_sts_error; -- If Return Value U, then Also the Value Returned in E
	l_contact_out_rec.error_msg := 'VALIDATION ERROR: Customer account number: ' ||
			       l_contact_out_rec.account_number ||
			       ' is not valid';
	l_contact_out_tab(l_contact_out_tab.count) := l_contact_out_rec;
	CONTINUE;
        END;
      END IF;
      IF l_contact_out_rec.account_id IS NOT NULL AND
         l_contact_out_rec.account_number IS NULL THEN
        l_contact_out_rec.account_number := fetch_customer_account_number(l_contact_out_rec.account_id);
      END IF;
      /* CHG0042044 - End */
    
      -- l_steps := l_steps ||'Title :'||p_contacts_in(i).title;
      -- l_steps := l_steps ||'person_pre_name_adjunct:'||upper(p_contacts_in(i).salutation)||';';
      org_contact_rec.job_title := p_contacts_in(i).title;
    
      person_rec.person_first_name := nvl(p_contacts_in(i).first_name,
			      fnd_api.g_null_char);
      person_rec.person_last_name  := nvl(p_contacts_in(i).last_name,
			      fnd_api.g_null_char);
      --------------
      ---Verify the person_pre_name_adjunct Having Lookup Code or Not
      --------------
      IF p_contacts_in(i).salutation IS NOT NULL THEN
        IF get_salutation_code(p_contacts_in(i).salutation) IS NOT NULL THEN
          person_rec.person_pre_name_adjunct := get_salutation_code(p_contacts_in(i)
					        .salutation);
        
        ELSIF get_salutation_code(p_contacts_in(i).salutation) IS NULL THEN
          l_main_status  := fnd_api.g_ret_sts_error;
          l_main_err_msg := 'lookup code not found  for salutation : ' || p_contacts_in(i)
		   .salutation ||
		    '.Please check Oracle apps lookup_type CONTACT_TITLE in fnd_lookup_values Table';
        END IF;
      ELSE
        person_rec.person_pre_name_adjunct := fnd_api.g_null_char;
      END IF;
    
      person_rec.person_name_suffix := p_contacts_in(i).suffix; -- CHG0042044 add suffix for person if received as input
    
      IF p_contacts_in(i).country IS NOT NULL THEN
        l_territory_code := get_territory_code(p_contacts_in(i).country);
      
        IF l_territory_code IS NOT NULL THEN
          location_rec.country := l_territory_code;
        END IF;
      
      END IF;
    
      location_rec.address1 := nvl(p_contacts_in(i).address_1,
		           fnd_api.g_null_char);
      location_rec.city     := nvl(p_contacts_in(i).city,
		           fnd_api.g_null_char);
      location_rec.state    := nvl(p_contacts_in(i).state_or_region,
		           fnd_api.g_null_char);
    
      location_rec.postal_code := nvl(p_contacts_in(i)
			  .zipcode_or_postal_code,
			  fnd_api.g_null_char);
    
      IF p_contacts_in(i)
       .contact_id IS NULL AND l_main_status = fnd_api.g_ret_sts_success THEN
        person_rec.created_by_module           := g_created_by_module; --'TCA_V1_API';
        location_rec.created_by_module         := g_created_by_module; --'TCA_V1_API';
        party_site_rec.created_by_module       := g_created_by_module; --'TCA_V1_API';
        org_contact_rec.created_by_module      := g_created_by_module; --'TCA_V1_API';
        contact_point_record.created_by_module := g_created_by_module; --'TCA_V1_API';
      
        org_contact_rec.party_rel_rec.object_table_name  := 'HZ_PARTIES';
        org_contact_rec.party_rel_rec.subject_table_name := 'HZ_PARTIES';
        org_contact_rec.party_rel_rec.relationship_code  := 'CONTACT_OF';
        org_contact_rec.party_rel_rec.relationship_type  := 'CONTACT';
        org_contact_rec.party_rel_rec.object_type        := 'ORGANIZATION';
        org_contact_rec.party_rel_rec.subject_type       := 'PERSON';
      
        contact_point_record.owner_table_name := 'HZ_PARTIES';
        --------
        create_person(person_rec, l_party_id, l_api_status, l_error_msg);
      
        IF l_api_status != fnd_api.g_ret_sts_success THEN
          l_main_status  := fnd_api.g_ret_sts_error;
          l_main_err_msg := l_error_msg;
        END IF;
      
        l_steps := l_steps || 'create_person Call Status:' || l_api_status ||
	       l_error_msg || 'PartyID' || l_party_id ||
	       ';person_rec.person_pre_name_adjunct:' ||
	       person_rec.person_pre_name_adjunct || ';';
        write_log_message('**create_person Procedure Call Status : -------');
      
        write_log_message('l_api_status :' || l_api_status, 'N');
        write_log_message('l_error_msg :' || l_error_msg, 'N');
        write_log_message('----------------------------------------------------');
      
        IF p_contacts_in(i)
         .address_1 IS NOT NULL AND p_contacts_in(i).country IS NOT NULL THEN
          l_api_status := NULL;
          l_error_msg  := NULL;
          write_log_message('Before Calling Creat_Location Procedure');
          create_location(p_location_record => location_rec, --In Param
		  p_location_id     => l_location_id, --Out Param
		  p_api_status      => l_api_status, --Out Param
		  p_error_msg       => l_error_msg --Out Param
		  );
        
          IF g_debug = TRUE THEN
	write_log_message('location p_api_status =' || l_api_status);
	write_log_message('location p_error_msg  =' || l_error_msg);
	write_log_message('location p_location_id=' || l_location_id);
          END IF;
        
          IF l_api_status != fnd_api.g_ret_sts_success THEN
	l_main_status  := fnd_api.g_ret_sts_error;
	l_main_err_msg := l_error_msg;
          ELSIF l_api_status = fnd_api.g_ret_sts_success AND
	    location_rec.country = 'US' THEN
	------------------------------------------------------
	-- If Location Creation Successfull and Country is US
	-- Assign the Address back to the Output Record \.
	-- Avalara Corrects US Address in Case of Wrong Address
	-------------------------------------------------------
	l_contact_out_rec.address_1 := location_rec.address1;
	l_contact_out_rec.city      := location_rec.city;
	--l_contact_out_rec.country   := location_rec.country;
	l_contact_out_rec.county                 := location_rec.county;
	l_contact_out_rec.state_or_region        := location_rec.state;
	l_contact_out_rec.zipcode_or_postal_code := location_rec.postal_code;
          END IF;
        
        END IF;
      
       
      
        --l_steps := l_steps || 'Create Location Status:'||l_api_status||';';
        BEGIN
          SELECT party_id
          INTO   l_object_id
          FROM   hz_cust_accounts_all
          WHERE  cust_account_id = l_contact_out_rec.account_id;
          --p_contacts_in(i).account_id;   -- Modified asd per CHG0042044
        EXCEPTION
          WHEN no_data_found THEN
	l_object_id := NULL;
          WHEN OTHERS THEN
	l_object_id := NULL;
        END;
      
        --l_steps := l_steps ||'l_object_id is:'||l_object_id||';Party ID:'||l_party_id||';';
        org_contact_rec.party_rel_rec.subject_id := l_party_id;
        org_contact_rec.party_rel_rec.object_id  := l_object_id;
      
        IF l_object_id IS NOT NULL AND
           l_main_status = fnd_api.g_ret_sts_success THEN
        
          create_contact(org_contact_rec,
		 l_relationship_party_id,
		 x_org_contact_id,
		 l_api_status,
		 l_error_msg);
          --l_steps := l_steps ||'Create Contact Call Status:'||l_api_status||';';
          write_log_message('create contact status=' || l_api_status);
          write_log_message('create contact error message=' || l_error_msg);
          write_log_message('l_relationship_party_id=' ||
		    l_relationship_party_id);
        
          IF l_api_status != fnd_api.g_ret_sts_success THEN
	l_main_status  := fnd_api.g_ret_sts_error;
	l_main_err_msg := l_error_msg;
          END IF;
        
          write_log_message('Contact p_api_status=' || l_api_status);
          write_log_message('Contact  p_error_msg=' || l_error_msg);
          write_log_message('Contact  x_org_contact_id=' ||
		    x_org_contact_id);
        
          IF l_api_status = fnd_api.g_ret_sts_success AND
	 l_location_id IS NOT NULL THEN
	party_site_rec.location_id := l_location_id;
	party_site_rec.party_id    := l_relationship_party_id;
          
	create_party_site(p_party_site_record => party_site_rec, --In Param
		      p_party_site_id     => l_party_site_id, --Out Param
		      p_party_site_number => l_party_site_number, --out Param
		      p_api_status        => l_api_status, --Out Param
		      p_error_msg         => l_error_msg --Out Param
		      );
	l_steps := l_steps || 'create_party_site Call Status :' ||
	           l_api_status || ';';
	write_log_message('Party Site  l_api_status=' || l_api_status);
	write_log_message('Party Site  l_error_msg=' || l_error_msg);
          END IF;
        
          IF l_api_status != fnd_api.g_ret_sts_success THEN
	l_main_status  := fnd_api.g_ret_sts_error;
	l_main_err_msg := l_error_msg;
          END IF;
        
        END IF;
      
        IF l_object_id IS NOT NULL AND
           l_api_status = fnd_api.g_ret_sts_success THEN
        
          rec_cust_acc_role.cust_account_id := l_contact_out_rec.account_id;
          --p_contacts_in(i).account_id; --Modifed as per CHG0042044
          IF p_source = g_old_sfdc_source THEN
	-- CHG0042044
	rec_cust_acc_role.attribute1 := p_contacts_in(i)
			        .source_reference_id;
          END IF; -- CHG0042044
        
          create_account_role(rec_cust_acc_role,
		      l_relationship_party_id,
		      l_cust_account_role_id,
		      l_api_status,
		      l_error_msg);
          --l_steps := l_steps ||'create_account_role Call Status :'||l_api_status;
        END IF;
      
        IF l_api_status != fnd_api.g_ret_sts_success THEN
          l_main_status  := fnd_api.g_ret_sts_error;
          l_main_err_msg := l_error_msg;
        END IF;
        ----------------------------------
        --Create Contct Points Start
        ----------------------------------
        IF l_api_status = fnd_api.g_ret_sts_success THEN
          --contact_point_record.owner_table_id := l_relationship_party_id;
          --------------New Code ------------------------------------------------------------
          /*l_api_status := NULL;
          l_error_msg  := NULL;*/
          upsert_contact_point(p_phone_num             => p_contacts_in(i)
				          .phone, --  IN VARCHAR2, -- Send Phone Number
		       p_mobile_num            => p_contacts_in(i)
				          .mobile, --  IN VARCHAR2, -- Send  Mobile  Number
		       p_fax_num               => p_contacts_in(i).fax, --  IN VARCHAR2, -- Send  Fax  Number
		       p_email_address         => p_contacts_in(i)
				          .email, --  IN VARCHAR2,
		       p_web                   => NULL,
		       p_relationship_party_id => l_relationship_party_id, --IN NUMBER,
		       ----
		       x_oe_phone_contact_point_id  => l_contact_out_rec.oe_phone_contact_point_id, --IN OUT NOCOPY NUMBER,
		       x_oe_mobile_contact_point_id => l_contact_out_rec.oe_mobile_contact_point_id, --IN OUT NOCOPY NUMBER,
		       x_oe_fax_contact_point_id    => l_contact_out_rec.oe_fax_contact_point_id, --IN OUT NOCOPY NUMBER,
		       x_oe_email_contact_point_id  => l_contact_out_rec.oe_email_contact_point_id, --IN OUT NOCOPY NUMBER,
		       x_oe_web_contact_point_id    => l_contact_out_rec.oe_web_contact_point_id, --IN OUT NOCOPY NUMBER,
		       ----
		       x_api_status => l_api_status, -- IN OUT NOCOPY VARCHAR2,
		       x_error_msg  => l_error_msg -- IN OUT NOCOPY VARCHAR2
		       );
          IF l_api_status != fnd_api.g_ret_sts_success THEN
	l_main_status  := fnd_api.g_ret_sts_error;
	l_main_err_msg := l_error_msg;
          END IF;
        
          --------------------------------------------------------------------------------------
        
        END IF;
      
        l_contact_out_rec.oe_person_party_id  := l_party_id;
        l_contact_out_rec.oe_location_id      := l_location_id;
        l_contact_out_rec.oe_contact_party_id := l_relationship_party_id;
        l_contact_out_rec.contact_id          := l_cust_account_role_id;
        l_contact_out_rec.status := (CASE
			  WHEN l_cust_account_role_id IS NOT NULL THEN
			   'Active'
			  ELSE
			   l_contact_out_rec.status
			END);
      
      ELSE
        ------------------------------------------------------------------------------
        --Update Contact , Else Part
        write_log_message('Contact Id is Available , Update Contact information');
        -------------------------------------------------------------------------------
        BEGIN
          -----------------------------------------------------------------------------
          --Get Relationship Party Id & Person Party Id for Account ID and Contact Id.
          -----------------------------------------------------------------------------
          SELECT hr.party_id,
	     subject_id,
	     hr.relationship_id
          INTO   l_rel_party_id,
	     l_person_party_id,
	     l_relationship_party_id
          FROM   hz_relationships      hr,
	     hz_cust_account_roles hcar
          WHERE  relationship_code = 'CONTACT_OF'
          AND    hr.party_id = hcar.party_id
          AND    hcar.cust_account_id = l_contact_out_rec.account_id --p_contacts_in(i).account_id --Modified as per CHG0042044
          AND    hcar.cust_account_role_id = p_contacts_in(i).contact_id; --Yuval renamed it as contact_id instead of cust account role id
        
          SELECT object_version_number
          INTO   l_person_obj_versn_num
          FROM   hz_parties
          WHERE  party_id = l_person_party_id;
        
          BEGIN
	SELECT org_contact_id,
	       job_title,
	       object_version_number
	INTO   org_contact_rec.org_contact_id,
	       l_org_contact_job_title,
	       l_org_contact_obj_ver
	FROM   hz_org_contacts
	WHERE  party_relationship_id = l_relationship_party_id;
          EXCEPTION
	WHEN no_data_found THEN
	  org_contact_rec.org_contact_id := NULL;
	  l_org_contact_job_title        := NULL;
	  l_org_contact_obj_ver          := NULL;
          END;
        
          BEGIN
	SELECT location_id,
	       object_version_number
	INTO   l_location_id,
	       l_psrty_site_vrsn_num
	FROM   hz_party_sites
	WHERE  party_id = l_rel_party_id;
          EXCEPTION
	WHEN no_data_found THEN
	  l_location_id         := NULL;
	  l_psrty_site_vrsn_num := NULL;
	WHEN OTHERS THEN
	  l_location_id         := NULL;
	  l_psrty_site_vrsn_num := NULL;
          END;
        
          BEGIN
	SELECT object_version_number
	INTO   l_location_vrsn_num
	FROM   hz_locations
	WHERE  location_id = l_location_id;
          EXCEPTION
	WHEN OTHERS THEN
	  l_location_vrsn_num := NULL;
          END;
        
          IF l_contact_out_rec.status IS NULL THEN
	l_contact_out_rec.status := 'Active';
          END IF;
        EXCEPTION
          WHEN no_data_found THEN
	l_rel_party_id       := NULL;
	l_person_party_id    := NULL;
	l_continuetonextstep := FALSE;
	l_main_status        := fnd_api.g_ret_sts_error;
	l_main_err_msg       := SQLERRM;
        END;
        -----------------------------------------------------------------
        --Disable Contact (HZ_CUST_ACCOUNT_ROLES) if Status is 'Inactive'
        -----------------------------------------------------------------
        IF l_continuetonextstep = TRUE AND
           upper(nvl(p_contacts_in(i).status, 'Active')) = 'INACTIVE' AND
           l_rel_party_id IS NOT NULL THEN
          l_continuetonextstep                   := FALSE;
          rec_cust_acc_role.cust_account_role_id := p_contacts_in(i)
				    .contact_id;
          rec_cust_acc_role.status               := 'I';
        
          l_api_status := NULL;
          l_error_msg  := NULL;
          update_account_role(p_cust_account_role_record => rec_cust_acc_role,
		      p_api_status               => l_api_status,
		      p_error_msg                => l_error_msg);
        
          l_contact_out_rec.error_code := l_api_status;
          l_contact_out_rec.error_msg  := l_error_msg;
          l_main_status                := l_api_status;
        END IF;
      
        IF l_continuetonextstep = TRUE THEN
          person_rec.party_rec.party_id := l_person_party_id;
          l_api_status                  := NULL;
          l_error_msg                   := NULL;
          update_person(p_person_record => person_rec, --IN Param
		p_obj_version   => l_person_obj_versn_num, --IN Param
		p_api_status    => l_api_status, --OUT Param
		p_error_msg     => l_error_msg --OUT Param
		);
        
          IF l_api_status != fnd_api.g_ret_sts_success THEN
	l_main_status  := fnd_api.g_ret_sts_error;
	l_main_err_msg := l_error_msg;
          END IF;
        
          write_log_message('Update person Call Status / Message = ' ||
		    l_api_status || '/' || l_error_msg);
        
          --Location Update , If not available Create
          IF l_location_id IS NOT NULL THEN
	location_rec.location_id := l_location_id;
	l_api_status             := NULL;
	l_error_msg              := NULL;
          
	update_location(p_location_rec          => location_rec, -- IN Param
		    p_object_version_number => l_location_vrsn_num, -- IN Param
		    p_api_status            => l_api_status, -- OUT Param
		    p_error_msg             => l_error_msg -- OUT Param
		    );
          ELSIF l_location_id IS NULL THEN
	location_rec.created_by_module := g_created_by_module; --'TCA_V1_API';
	l_api_status                   := NULL;
	l_error_msg                    := NULL;
          
	create_location(p_location_record => location_rec, --IN/OUT Param
		    p_location_id     => l_location_id, --OUT Param
		    p_api_status      => l_api_status, --OUT Param
		    p_error_msg       => l_error_msg); --OUT Param
          END IF;
        
          IF l_api_status != fnd_api.g_ret_sts_success THEN
	l_main_status  := fnd_api.g_ret_sts_error;
	l_main_err_msg := l_error_msg;
          
          ELSIF l_api_status = fnd_api.g_ret_sts_success AND
	    location_rec.country = 'US' THEN
	------------------------------------------------------
	-- If Location Creation Successfull and Country is US
	-- Assign the Address back to the Output Record,
	-- So that SFDC can Receive the Corrected Address.
	-- Avalara Corrects US Address in Case of Wrong Address
	-------------------------------------------------------
	l_contact_out_rec.address_1 := location_rec.address1;
	l_contact_out_rec.city      := location_rec.city;
	-- l_contact_out_rec.country   := location_rec.country;
	l_contact_out_rec.county                 := location_rec.county;
	l_contact_out_rec.state_or_region        := location_rec.state;
	l_contact_out_rec.zipcode_or_postal_code := location_rec.postal_code;
          END IF;
        
          --Update Org Contact
          IF org_contact_rec.org_contact_id IS NOT NULL AND
	 nvl(org_contact_rec.job_title, '~') !=
	 nvl(l_org_contact_job_title, '~') THEN
	update_contact(p_contact_record           => org_contact_rec, -- In
		   p_contact_obj_version_num  => l_org_contact_obj_ver, --In
		   p_relation_obj_version_num => fnd_api.g_miss_num, -- IN
		   p_party_obj_version_num    => fnd_api.g_miss_num, -- in
		   p_api_status               => l_api_status,
		   p_error_msg                => l_error_msg);
	IF l_api_status != fnd_api.g_ret_sts_success THEN
	  write_log_message('Update Org Contact Status :' ||
		        l_error_msg || '.' || l_error_msg);
	
	END IF;
          END IF;
          /*Else
          l_main_status := fnd_api.g_ret_sts_error;*/
        END IF;
      
        IF l_main_status = fnd_api.g_ret_sts_success AND
           l_continuetonextstep = TRUE THEN
          --contact_point_record.owner_table_id := l_rel_party_id;
          --------------New Code ------------------------------------------------------------
          l_api_status                                 := NULL;
          l_error_msg                                  := NULL;
          l_contact_out_rec.oe_phone_contact_point_id  := p_contacts_in(i)
				          .oe_phone_contact_point_id;
          l_contact_out_rec.oe_mobile_contact_point_id := p_contacts_in(i)
				          .oe_mobile_contact_point_id;
          l_contact_out_rec.oe_fax_contact_point_id    := p_contacts_in(i)
				          .oe_fax_contact_point_id;
          l_contact_out_rec.oe_email_contact_point_id  := p_contacts_in(i)
				          .oe_email_contact_point_id;
        
          upsert_contact_point(p_phone_num             => p_contacts_in(i)
				          .phone, --  IN VARCHAR2, -- Send Phone Number
		       p_mobile_num            => p_contacts_in(i)
				          .mobile, --  IN VARCHAR2, -- Send  Mobile  Number
		       p_fax_num               => p_contacts_in(i).fax, --  IN VARCHAR2, -- Send  Fax  Number
		       p_email_address         => p_contacts_in(i)
				          .email, --  IN VARCHAR2,
		       p_web                   => NULL,
		       p_relationship_party_id => l_rel_party_id, --IN NUMBER,
		       ----
		       x_oe_phone_contact_point_id  => l_contact_out_rec.oe_phone_contact_point_id, --IN OUT NOCOPY NUMBER,
		       x_oe_mobile_contact_point_id => l_contact_out_rec.oe_mobile_contact_point_id, --IN OUT NOCOPY NUMBER,
		       x_oe_fax_contact_point_id    => l_contact_out_rec.oe_fax_contact_point_id, --IN OUT NOCOPY NUMBER,
		       x_oe_email_contact_point_id  => l_contact_out_rec.oe_email_contact_point_id, --IN OUT NOCOPY NUMBER,
		       x_oe_web_contact_point_id    => l_contact_out_rec.oe_web_contact_point_id, --IN OUT NOCOPY NUMBER,
		       ----
		       x_api_status => l_api_status, -- IN OUT NOCOPY VARCHAR2,
		       x_error_msg  => l_error_msg -- IN OUT NOCOPY VARCHAR2
		       );
        
          IF l_api_status != fnd_api.g_ret_sts_success THEN
	l_main_status  := fnd_api.g_ret_sts_error;
	l_main_err_msg := l_error_msg;
          END IF;
          --------------------------------------------------------------------------------------
        
        END IF;
      END IF;
    
      write_log_message('End Of Loop Main Status :' || l_main_status);
      write_log_message('End Of Loop l_contact_out_rec.error_code Status :' ||
		l_contact_out_rec.error_code);
      l_contact_out_rec.error_code := (CASE l_main_status
			    WHEN fnd_api.g_ret_sts_success THEN
			     fnd_api.g_ret_sts_success
			    ELSE
			     fnd_api.g_ret_sts_error
			  END);
      l_contact_out_rec.error_msg := l_contact_out_rec.error_msg ||
			 substr(l_main_err_msg, 1, 999); -- || l_steps;
      l_contact_out_tab(l_contact_out_tab.count) := l_contact_out_rec;
      write_log_message('End Of Loop l_contact_out_rec.error_code Status :' ||
		l_contact_out_rec.error_code);
    END LOOP;
  
    p_contacts_out := l_contact_out_tab;
    p_status       := fnd_api.g_ret_sts_success;
    --p_message      := l_main_err_msg;
    COMMIT;
    write_log_message('Program Exited : xxhz_soa_api_pkg.upsert_contact Procedure');
 

 --- dqm submission CHG0042632
    IF (p_status = 'S') THEN
   
    
      submit_dqm_program(errbuf             => l_errbuf,
		 retcode            => l_retcode,
		 p_soa_reference_id => p_soa_reference_id);
    
    END IF;
    
  EXCEPTION
    WHEN user_not_valid_exp THEN
      p_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      p_status  := fnd_api.g_ret_sts_error;
      p_message := 'Program Exited : xxhz_soa_api_pkg.upsert_contact Procedure With Error :' ||
	       SQLERRM;
      --??????Rollback to Save Point
  END upsert_contact;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : upsert_sites                                                                                                *
  * Script Name         : xxhz_api_pkg.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will be called through SOA integration to create/update the Sites
                           in S3 system with the same data of SFDC environment. This procedure will create the
                           Sites to the S3 system collected through the SOA Integration
                                                                                                                      *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     11/05/2016  Somnath Dawn                Initial version
  * 1.1      12/13/2017  Diptasurjya        CHG0042044 - Make calls compatiable with Strataforce                                              *
  * 1.2      29/06/2018  Lingaraj           CHG0042044 - Update Site fix     
  * 1.3      13/11/2018  Lingaraj           CHG0042632 - SFDC2OA - Location - Sites  interface   
  * 1.3.1    17.01.2019  yuval tal          CHG0042632  -- add dqp prog submission                                     *
  ******************************************************************************************************************************************/

  PROCEDURE upsert_sites(p_source           IN VARCHAR2,
		 p_soa_reference_id IN NUMBER,
		 p_sites_in         IN OUT xxobjt.xxhz_site_tab,
		 p_sites_out        OUT xxobjt.xxhz_site_tab,
		 p_status           OUT VARCHAR2,
		 p_message          OUT VARCHAR2) IS
    cust_acct_site_rec  hz_cust_account_site_v2pub.cust_acct_site_rec_type;
    location_rec        hz_location_v2pub.location_rec_type;
    party_site_rec      hz_party_site_v2pub.party_site_rec_type;
    cust_site_use_rec   hz_cust_account_site_v2pub.cust_site_use_rec_type;
    x_location_id       NUMBER := NULL;
    l_party_id          NUMBER;
    l_party_site_id     NUMBER;
    l_org_id            NUMBER := NULL;
    l_cust_acct_site_id NUMBER;
    l_site_use_id       NUMBER;
    l_ou_unit           VARCHAR2(100);
    --l_site_use_code     VARCHAR2(100);
    l_api_status        VARCHAR2(10);
    l_error_msg         VARCHAR2(6000);
    l_site_use          VARCHAR2(100) := NULL;
    l_territory_code    fnd_territories_vl.territory_code%TYPE;
    l_record_count      NUMBER;
    l_loop_count        NUMBER := 1;
    l_sites_out_rec     xxhz_site_rec;
    l_sites_out_tab     xxhz_site_tab := xxhz_site_tab();
    l_continue_flag     NUMBER;
    l_user_id           NUMBER;
    l_resp_id           NUMBER;
    l_resp_appl_id      NUMBER;
    l_temp              VARCHAR2(1000);
    l_party_site_number hz_party_sites.party_site_number%TYPE;
    l_obj_ver           NUMBER; --CHG0042044
    
    
    l_errbuf           VARCHAR2(4000); -- 
    l_retcode          VARCHAR2(10); -- 
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.upsert_sites Procedure');
  
    p_status := fnd_api.g_ret_sts_success;
  
    -------------------------------------------------------------------------------------------
    --This will Set all required Global Variables , which going to change depend on the Source
    --Get the User details & initilize Apps for Processing the Record
    -------------------------------------------------------------------------------------------
    IF g_is_session_set = FALSE THEN
      set_my_session( --p_username       => NULL, --In Param -- CHG0042044 - Dipta commented
	         p_source         => p_source, -- CHG0042044 - Dipta added
	         p_status_out     => p_status, --Out Param
	         p_status_msg_out => p_message --Out Param
	         );
    
      IF p_status != fnd_api.g_ret_sts_success THEN
        RAISE user_not_valid_exp;
      END IF;
    END IF;
  
    l_record_count := p_sites_in.count;
    write_log_message('  No Of Site Records Available : ' ||
	          l_record_count);
  
    FOR i IN 1 .. l_record_count LOOP
      l_continue_flag     := 1;
      location_rec        := NULL;
      party_site_rec      := NULL;
      cust_acct_site_rec  := NULL;
      cust_site_use_rec   := NULL;
      l_site_use          := NULL;
      x_location_id       := NULL;
      l_org_id            := NULL;
      l_ou_unit           := NULL;
      l_territory_code    := NULL;
      l_party_id          := NULL;
      l_cust_acct_site_id := NULL; --Added on 20.03.17
      l_api_status        := NULL; --Added on 20.03.17
      l_error_msg         := NULL; --Added on 20.03.17
      l_party_site_number := NULL;
      l_sites_out_rec     := xxhz_site_rec(NULL,
			       NULL,
			       NULL,
			       NULL,
			       NULL,
			       NULL,
			       NULL,
			       NULL,
			       NULL,
			       NULL,
			       NULL,
			       NULL,
			       NULL,
			       NULL,
			       NULL,
			       NULL,
			       NULL,
			       NULL,
			       NULL,
			       NULL -- CHG0042044 - Add extra NULL for account_number
			       );
      l_sites_out_rec     := p_sites_in(i);
      l_sites_out_tab.extend;
    
      /* CHG0042044 - Start Validate account_ID and account_number - Dipta*/
      IF l_sites_out_rec.account_id IS NULL AND
         l_sites_out_rec.account_number IS NOT NULL THEN
        BEGIN
          l_sites_out_rec.account_id := fetch_customer_account_id(NULL,
					      l_sites_out_rec.account_number);
        EXCEPTION
          WHEN OTHERS THEN
	-- If Return Value U, then Also the Value Returned in E 
	l_sites_out_rec.error_code := fnd_api.g_ret_sts_error;
	l_sites_out_rec.error_msg := 'VALIDATION ERROR: Customer account number: ' ||
			     l_sites_out_rec.account_number ||
			     ' is not valid.' || SQLERRM;
	l_sites_out_tab(l_sites_out_tab.count) := l_sites_out_rec;
	CONTINUE;
        END;
      END IF;
    
      IF l_sites_out_rec.account_id IS NOT NULL AND
         l_sites_out_rec.account_number IS NULL THEN
        BEGIN
          l_sites_out_rec.account_number := fetch_customer_account_number(l_sites_out_rec.account_id);
        EXCEPTION
          WHEN OTHERS THEN
	l_sites_out_rec.error_code := fnd_api.g_ret_sts_error;
	l_sites_out_rec.error_msg := 'VALIDATION ERROR: Customer account id: ' ||
			     l_sites_out_rec.account_id ||
			     ' is not valid.' || SQLERRM;
	l_sites_out_tab(l_sites_out_tab.count) := l_sites_out_rec;
	CONTINUE;
        END;
      END IF;
      /* CHG0042044 - End */
    
      /*Get the Territory Name from the Country Name
        Example:For Country : Israel ,territory_code is : IL
        This going to be Use during Location Creation
      */
      IF p_sites_in(i).country IS NOT NULL THEN
        -- get_territory_org_info Procedure Added on 20.03.17
        --Get territory_code , Operating Unit Id , Operating Unit Name
        get_territory_org_info(p_country        => p_sites_in(i).country, -- IN Param
		       x_territory_code => l_territory_code, --Out Param
		       x_org_id         => l_org_id, --Out Param
		       x_ou_unit_name   => l_ou_unit, --Out Param
		       x_error_code     => l_api_status, --Out Param
		       x_error_msg      => l_error_msg --Out Param
		       );
        write_log_message('get_territory_org_info Procedure Status / Error Msg :' ||
		  l_api_status || '/Error Msg :' || l_error_msg);
      
        IF l_api_status = fnd_api.g_ret_sts_success THEN
          location_rec.country := l_territory_code;
        ELSE
          l_continue_flag            := 0;
          l_sites_out_rec.error_code := fnd_api.g_ret_sts_error;
          l_sites_out_rec.error_msg  := l_error_msg;
        END IF;
      END IF;
    
      IF p_sites_in(i).site_usage = 'Bill To/Ship To' THEN
        l_loop_count := 2;
      ELSE
        l_loop_count := 1; --Added By Lingaraj
      END IF;
    
      IF l_api_status = fnd_api.g_ret_sts_success THEN
        --Added 03.04.17, If territory Code & OU Mapping Found Then proceed
        FOR j IN 1 .. l_loop_count LOOP
          l_site_use := NULL;
        
          IF p_sites_in(i).site_usage = 'Bill To/Ship To' THEN
	IF j = 1 THEN
	  --cust_site_use_rec.site_use_code := 'SHIP_TO';
	  l_site_use := 'SHIP_TO';
	END IF;
	IF j = 2 THEN
	  --cust_site_use_rec.site_use_code := 'BILL_TO';
	  l_site_use := 'BILL_TO';
	END IF;
          ELSE
	IF p_sites_in(i).site_usage = 'Ship To' THEN
	  l_site_use := 'SHIP_TO';
	END IF;
	IF p_sites_in(i).site_usage = 'Bill To' THEN
	  l_site_use := 'BILL_TO';
	END IF;
	--cust_site_use_rec.site_use_code := l_site_use;
          END IF;
        
          cust_site_use_rec.site_use_code := l_site_use; --Added on 17.04.17
        
          IF p_sites_in(i).site_id IS NULL THEN
	location_rec.created_by_module := g_created_by_module; --'TCA_V1_API';
	location_rec.county            := p_sites_in(i).county;
	location_rec.address1          := p_sites_in(i).address;
	location_rec.city              := p_sites_in(i).city;
          
	location_rec.postal_code := p_sites_in(i).zipcode_or_postal_code;
	location_rec.state       := p_sites_in(i).state_or_region;
          
	--Create SHIP_TO Location
	IF j = 1 THEN
	  create_location(p_location_record => location_rec, --In/OUT Param
		      p_location_id     => x_location_id, --Out Param
		      p_api_status      => l_api_status, --Out Param
		      p_error_msg       => l_error_msg --Out Param
		      );
	  write_log_message('Create SHIP_TO Location API Status / Message :' ||
		        l_api_status || '/Error Msg:' ||
		        l_error_msg);
	
	  --Below If Added on 20th March 17 By Lingaraj                                                                   ||'/Error Msg:'||l_error_msg);
	  IF l_api_status = fnd_api.g_ret_sts_success THEN
	    party_site_rec.location_id := x_location_id;
	  
	    ------------------------------------------------
	    --Assign Corrected Address, If Country is US
	    --Address Corrected by Avalara, During Creation
	    ------------------------------------------------
	    IF location_rec.country = 'US' THEN
	      l_sites_out_rec.address                := location_rec.address1;
	      l_sites_out_rec.city                   := location_rec.city;
	      l_sites_out_rec.county                 := location_rec.county;
	      l_sites_out_rec.state_or_region        := location_rec.state;
	      l_sites_out_rec.zipcode_or_postal_code := location_rec.postal_code;
	    END IF;
	  END IF;
	
	  p_status := l_api_status;
	END IF;
          
	--???????????If Location Creation Failed Then ?????????????????
	--p_status := l_api_status; -- Commented on 20.03.17
          
	party_site_rec.party_site_name := p_sites_in(i).site_name;
	--party_site_rec.location_id       := x_location_id; -- Commented on 20.03.17
	party_site_rec.created_by_module := g_created_by_module; --'TCA_V1_API';
          
	IF l_api_status = fnd_api.g_ret_sts_success THEN
	  BEGIN
	  
	    SELECT party_id
	    INTO   l_party_id
	    FROM   hz_cust_accounts_all
	    WHERE  cust_account_id = l_sites_out_rec.account_id; --CHG0042632 
	    --p_sites_in(i).account_id;
	  
	    party_site_rec.party_id := l_party_id;
	  
	    IF j = 1 THEN
	      create_party_site(p_party_site_record => party_site_rec, --In Param
			p_party_site_id     => l_party_site_id, --Out Param
			p_party_site_number => l_party_site_number, --Out Param-- Added on 21.03.2017
			p_api_status        => l_api_status, --Out Param
			p_error_msg         => l_error_msg --Out Param
			);
	      write_log_message('party_site API Status=' ||
			l_api_status);
	      write_log_message('party_site API msg=' || l_error_msg);
	    END IF;
	  
	    cust_acct_site_rec.cust_account_id   :=  --p_sites_in(i) --CHG0042632
	     l_sites_out_rec.account_id;
	    cust_acct_site_rec.party_site_id     := l_party_site_id;
	    cust_acct_site_rec.created_by_module := g_created_by_module; --'TCA_V1_API';
	    IF p_source = g_old_sfdc_source THEN
	      -- CHG0042044
	      cust_acct_site_rec.attribute1 := p_sites_in(i)
				   .source_reference_id;
	    END IF; -- CHG0042044
	    --cust_acct_site_rec.customer_category_code := 'CUSTOMER';-- To Default the Value HZ_PARTIES.CATEGORY_CODE
	    --Added on 14.03.17 By Lingaraj
	    IF l_org_id IS NOT NULL THEN
	      cust_acct_site_rec.org_id := l_org_id;
	    
	      mo_global.init(g_resp_appl);
	      mo_global.set_org_context(l_org_id, NULL, g_resp_appl);
	      mo_global.set_policy_context('S', l_org_id);
	    END IF;
	  
	    IF l_continue_flag = 1 THEN
	      IF j = 1 THEN
	        create_acct_site(p_cust_acct_site_rec => cust_acct_site_rec, --In Param
			 p_cust_acct_site_id  => l_cust_acct_site_id, --Out Param
			 p_api_status         => l_api_status, --Out Param
			 p_error_msg          => l_error_msg); --Out Param
	      
	        write_log_message('create_acct_site API Status/Errmsg/p_cust_acct_site_id=' ||
			  l_api_status || '/ErrorMsg :' ||
			  l_error_msg ||
			  '/cust_acct_site_id :' ||
			  l_cust_acct_site_id);
	      END IF;
	      --?????????????If create_acct_site Failed ????????????????????
	    
	      IF p_sites_in(i).site_usage IS NOT NULL THEN
	        cust_site_use_rec.cust_acct_site_id := l_cust_acct_site_id;
	        cust_site_use_rec.created_by_module := g_created_by_module; --'TCA_V2_API';
	        cust_site_use_rec.location          := x_location_id;
	      
	        create_acct_site_use(p_cust_site_use_rec => cust_site_use_rec,
			     p_site_use_id       => l_site_use_id,
			     p_api_status        => l_api_status,
			     p_error_msg         => l_error_msg);
	      
	        write_log_message('cust_site_use_rec.site_use_code=' ||
			  cust_site_use_rec.site_use_code);
	        write_log_message('create_acct_site API Status/Errmsg=' ||
			  l_api_status || '/ErrorMsg :' ||
			  l_error_msg);
	        --?????????If create_acct_site_use Fails Then ????????????????????
	        IF cust_site_use_rec.site_use_code = 'BILL_TO' THEN
	          l_sites_out_rec.oe_bill_site_use_id := l_site_use_id;
	          -- l_sites_out_rec.oe_ship_site_use_id := NULL;
	        END IF;
	      
	        IF cust_site_use_rec.site_use_code = 'SHIP_TO' THEN
	          l_sites_out_rec.oe_ship_site_use_id := l_site_use_id;
	          --     l_sites_out_rec.oe_bill_site_use_id := NULL;
	        END IF;
	      
	        p_status := l_api_status;
	      END IF;
	      /* insert_site_sfid_uda(l_cust_acct_site_id,
                  p_sites_in(i).source_reference_id,
                  l_api_status,
                  l_error_msg);*/
	    END IF;
	  
	  EXCEPTION
	    WHEN OTHERS THEN
	      write_log_message('Here is an error ' || SQLERRM);
	      p_status    := fnd_api.g_ret_sts_error;
	      l_error_msg := l_temp || ':' || SQLERRM;
	  END;
	END IF;
          
	l_sites_out_rec.site_id        := l_cust_acct_site_id;
	l_sites_out_rec.status := (CASE
			    WHEN l_cust_acct_site_id IS NOT NULL THEN
			     'Active'
			    ELSE
			     l_sites_out_rec.status
			  END);
	l_sites_out_rec.site_number    := l_party_site_number;
	l_sites_out_rec.address        := nvl(l_sites_out_rec.address,
				  p_sites_in(i).address);
	l_sites_out_rec.operating_unit := l_ou_unit;
	l_sites_out_rec.oe_location_id := x_location_id;
	l_sites_out_rec.site_usage     := p_sites_in(i).site_usage;
	--          l_sites_out_rec.oe_party_site_id := l_party_site_id;
	------------------------------------
	-- If Site Update ,Site Id available
	------------------------------------
          ELSE
	BEGIN
	  BEGIN
	    SELECT org_id
	    INTO   l_org_id
	    FROM   hz_cust_acct_sites_all
	    WHERE  cust_acct_site_id = p_sites_in(i).site_id;
	  
	    l_sites_out_rec.operating_unit := l_org_id;
	  EXCEPTION
	    WHEN OTHERS THEN
	      l_error_msg := 'This Site does not exist.';
	      p_status    := fnd_api.g_ret_sts_error;
	  END;
	
	  mo_global.init(g_resp_appl);
	  mo_global.set_org_context(l_org_id, NULL, g_resp_appl);
	  mo_global.set_policy_context('S', l_org_id);
	
	  cust_site_use_rec.cust_acct_site_id := p_sites_in(i).site_id;
	  --cust_site_use_rec.created_by_module := g_created_by_module; --commented for CHG0042632
	
	  cust_site_use_rec.location := p_sites_in(i).oe_location_id; -- Added by Lingaraj 6.04.17
	  --cust_site_use_rec.site_use_id := p_sites_in(i).OE_Ship_Site_Use_ID;--commented for CHG0042632
	  IF p_sites_in(i)
	   .site_usage IS NOT NULL AND l_org_id IS NOT NULL THEN
	    IF p_sites_in(i).site_usage = 'Bill To/Ship To' THEN
	      BEGIN
	        SELECT site_use_code
	        INTO   l_site_use
	        FROM   hz_cust_site_uses_all
	        WHERE  cust_acct_site_id = p_sites_in(i).site_id;
	      EXCEPTION
	        WHEN no_data_found THEN
	          IF j = 1 THEN
		l_site_use                      := 'SHIP_TO';
		cust_site_use_rec.site_use_code := 'SHIP_TO';
	          END IF;
	        WHEN OTHERS THEN
	          l_site_use := NULL;
	      END;
	    END IF; --Added  CHG0042632
	    IF l_site_use = 'SHIP_TO' THEN
	      cust_site_use_rec.site_use_code := 'SHIP_TO';
	      cust_site_use_rec.site_use_id   := p_sites_in(i)
				     .oe_ship_site_use_id; --Added  CHG0042632
	    END IF;
	    IF l_site_use = 'BILL_TO' THEN
	      cust_site_use_rec.site_use_code := 'BILL_TO';
	      cust_site_use_rec.site_use_id   := p_sites_in(i)
				     .oe_bill_site_use_id; --Added  CHG0042632
	    END IF;
	  
	    --END IF;commented for CHG0042632
	  
	    --Begin CHG0042044 Update Location Details
	    location_rec  := NULL;
	    x_location_id := NULL;
	    l_obj_ver     := NULL;
	    IF p_sites_in(i).country IS NOT NULL THEN
	      l_territory_code := NULL;
	      l_org_id         := NULL;
	      l_ou_unit        := NULL;
	      get_territory_org_info(p_country        => p_sites_in(i)
					 .country, -- IN Param
			     x_territory_code => l_territory_code, --Out Param
			     x_org_id         => l_org_id, --Out Param
			     x_ou_unit_name   => l_ou_unit, --Out Param
			     x_error_code     => l_api_status, --Out Param
			     x_error_msg      => l_error_msg --Out Param
			     );
	      write_log_message('get_territory_org_info Procedure Status / Error Msg :' ||
			l_api_status || '/Error Msg :' ||
			l_error_msg);
	    
	      IF l_api_status = fnd_api.g_ret_sts_success THEN
	        location_rec.country := l_territory_code;
	        --location_rec.created_by_module := g_created_by_module;--commented for CHG0042632
	        location_rec.county      := p_sites_in(i).county;
	        location_rec.address1    := p_sites_in(i).address;
	        location_rec.city        := p_sites_in(i).city;
	        location_rec.postal_code := p_sites_in(i)
				.zipcode_or_postal_code;
	        location_rec.state       := p_sites_in(i)
				.state_or_region;
	        location_rec.location_id := p_sites_in(i).oe_location_id;
	      
	        update_location(p_location_rec          => location_rec,
			p_object_version_number => l_obj_ver,
			p_api_status            => l_api_status,
			p_error_msg             => l_error_msg);
	        ------------------------------------------------
	        --Assign Corrected Address, If Country is US
	        --Address Corrected by Avalara, During Creation
	        ------------------------------------------------
	        IF location_rec.country = 'US' THEN
	          l_sites_out_rec.address                := location_rec.address1;
	          l_sites_out_rec.city                   := location_rec.city;
	          l_sites_out_rec.county                 := location_rec.county;
	          l_sites_out_rec.state_or_region        := location_rec.state;
	          l_sites_out_rec.zipcode_or_postal_code := location_rec.postal_code;
	        END IF;
	      
	      ELSE
	        l_sites_out_rec.error_code := fnd_api.g_ret_sts_error;
	        l_sites_out_rec.error_msg  := l_error_msg;
	      END IF;
	    END IF;
	  
	    write_log_message('update_location API Status / Message :' ||
		          l_api_status || '/Error Msg:' ||
		          l_error_msg);
	    --End CHG0042044--------------------------------
	  
	    IF l_site_use IS NOT NULL AND l_org_id IS NOT NULL AND
	       l_api_status = fnd_api.g_ret_sts_success THEN
	      /* create_acct_site_use(cust_site_use_rec,
                  l_site_use_id,
                  l_api_status,
                  l_error_msg);*/
	      l_obj_ver := NULL;
	      update_acct_site_use(cust_site_use_rec,
			   l_obj_ver,
			   l_api_status,
			   l_error_msg); --CHG0042044
	      write_log_message('update_acct_site_use :' ||
			l_api_status || '/' || l_error_msg);
	    
	      p_status := l_api_status; -- Added by Lingaraj 15th March 17
	    
	      IF cust_site_use_rec.site_use_code = 'BILL_TO' THEN
	        l_sites_out_rec.oe_bill_site_use_id := p_sites_in(i)
				           .oe_bill_site_use_id; --CHG0042044
	      END IF;
	    
	      IF cust_site_use_rec.site_use_code = 'SHIP_TO' THEN
	        l_sites_out_rec.oe_ship_site_use_id := p_sites_in(i)
				           .oe_ship_site_use_id; --CHG0042044
	      END IF;
	    
	    END IF;
	    --p_status := l_api_status; -- Commnted By Lingaraj on 15th March 17
	    write_log_message('acct_site_use API Status=' ||
		          l_api_status);
	    write_log_message('acct_site_use API msg=' || l_error_msg);
	    l_sites_out_rec.site_id := p_sites_in(i).site_id;
	  
	  END IF;
	EXCEPTION
	  WHEN OTHERS THEN
	    write_log_message('Error while adding new site use' ||
		          SQLERRM);
	END;
          
          END IF;
        
        END LOOP;
      ELSE
        p_status := l_api_status;
      END IF;
    
      l_sites_out_rec.error_code := (CASE p_status
			  WHEN fnd_api.g_ret_sts_success THEN
			   fnd_api.g_ret_sts_success
			  ELSE
			   fnd_api.g_ret_sts_error
			END);
      l_sites_out_rec.error_msg := substr(l_error_msg, 1, 100); -- Need to increase Size of the Error Message?????????
      l_sites_out_rec.operating_unit := to_char(l_org_id); --Added On 20-March-17 , SF  Requested that this Should Contain ORGID
      l_sites_out_tab(l_sites_out_tab.count) := l_sites_out_rec;
    
    END LOOP;
  
    IF l_record_count > 0 THEN
      p_sites_out := l_sites_out_tab;
    END IF;
  
    COMMIT; --????If Commit is There Should I Rollback on Error  or Commit Should be on Each Site Level??????
    write_log_message('Program Exited : xxhz_soa_api_pkg.upsert_sites Procedure');
  
    p_status := fnd_api.g_ret_sts_success; -- Added by Lingaraj 15th March 17
    
    
     
      --- dqm submission CHG0042632
     IF (p_status = 'S') THEN
    
    
      submit_dqm_program(errbuf             => l_errbuf,
		 retcode            => l_retcode,
		 p_soa_reference_id => p_soa_reference_id);
    
    END IF;
    
  EXCEPTION
    WHEN user_not_valid_exp THEN
      p_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      p_status  := fnd_api.g_ret_sts_error;
      p_message := SQLERRM;
      --Rollback;-- Added By Lingaraj 15th March 17 -?????/Rollback to Save Point?????
  END upsert_sites;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : create_account                                                                                                *
  * Script Name         : xxhz_api_pkg.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_cust_account_v2pub.create_cust_account api to create customer account
                           in S3 system with the same data of SFDC environment. This api will create the
                           customer account to the S3 system collected through SOA Integration
                                                                                                                      *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     11/05/2016  Somnath Dawn                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE create_account(p_org_record          IN hz_party_v2pub.organization_rec_type,
		   p_cust_account_record IN hz_cust_account_v2pub.cust_account_rec_type,
		   p_cust_prof_record    IN hz_customer_profile_v2pub.customer_profile_rec_type,
		   p_cust_account_id     OUT NUMBER,
		   p_party_id            OUT NUMBER,
		   p_api_status          OUT VARCHAR2,
		   p_error_msg           OUT VARCHAR2) IS
  
    l_error_msg       VARCHAR2(4000);
    x_cust_account_id hz_cust_accounts_all.cust_account_id%TYPE;
    x_account_number  hz_cust_accounts_all.account_number%TYPE;
  
    x_party_id      hz_parties.party_id%TYPE;
    x_party_number  NUMBER;
    x_profile_id    NUMBER;
    x_return_status VARCHAR2(255) := 'N';
    x_msg_count     NUMBER;
    x_msg_data      VARCHAR2(255);
  
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.create_account Procedure',
	          'Y');
    hz_cust_account_v2pub.create_cust_account(p_init_msg_list        => fnd_api.g_true,
			          p_cust_account_rec     => p_cust_account_record,
			          p_organization_rec     => p_org_record,
			          p_customer_profile_rec => p_cust_prof_record,
			          p_create_profile_amt   => fnd_api.g_true,
			          x_cust_account_id      => x_cust_account_id,
			          x_account_number       => x_account_number,
			          x_party_id             => x_party_id,
			          x_party_number         => x_party_number,
			          x_profile_id           => x_profile_id,
			          x_return_status        => x_return_status,
			          x_msg_count            => x_msg_count,
			          x_msg_data             => x_msg_data);
  
    p_cust_account_id := x_cust_account_id;
    p_party_id        := x_party_id;
    p_api_status      := x_return_status;
    write_log_message('party id ' || x_party_id);
    write_log_message('x_return_status = ' || x_return_status);
  
    write_log_message('x_msg_count = ' || to_char(x_msg_count));
    write_log_message('x_msg_data = ' || x_msg_data);
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        write_log_message(i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
			          1,
			          255));
      
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
	           substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
		      1,
		      255);
      END LOOP;
    END IF;
    p_error_msg := x_msg_data;
    write_log_message('Program Exited : xxhz_soa_api_pkg.create_account Procedure');
  EXCEPTION
    WHEN OTHERS THEN
      write_log_message('Unexpected error in xxhz_soa_api_pkg.create_account: ' ||
		SQLERRM);
  END create_account;
  /******************************************************************************************************************************************
   * Type                : Procedure                                                                                                         *
   * Module Name         : AR_CUSTOMERS                                                                                                      *
   * Name                : update_account                                                                                                *
   * Script Name         : xxhz_api_pkg.pkb                                                                                        *
   *                                                                                                                                         *
                                                                                                                                             *                                                                                                                                            *
   * Purpose             :  This procedure will call the hz_cust_account_v2pub.update_cust_account api to update
                            customer account in S3 system with the same data of SFDC environment. This api will update
                            the customer account to the Legacy system collected through the SOA Integration
                                                                                                                       *
                                                                                                                                             *
   * HISTORY                                                                                                                                 *
   * =======                                                                                                                                 *
   * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
   * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     11/05/2016  Somnath Dawn                Initial version                                                                                      *
   ******************************************************************************************************************************************/

  PROCEDURE update_account(p_cust_account_record IN hz_cust_account_v2pub.cust_account_rec_type,
		   p_cust_prof_record    IN hz_customer_profile_v2pub.customer_profile_rec_type,
		   p_api_status          OUT VARCHAR2,
		   p_error_msg           OUT VARCHAR2) IS
    l_account_obj_version_num NUMBER;
    l_error_msg               VARCHAR2(4000);
    l_return_status           VARCHAR2(10);
    l_msg_count               NUMBER;
    l_msg_data                VARCHAR2(1000);
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.update_account Procedure',
	          'Y');
    SELECT object_version_number
    INTO   l_account_obj_version_num
    FROM   hz_cust_accounts_all
    WHERE  cust_account_id = p_cust_account_record.cust_account_id;
    hz_cust_account_v2pub.update_cust_account(p_init_msg_list         => fnd_api.g_true,
			          p_cust_account_rec      => p_cust_account_record,
			          p_object_version_number => l_account_obj_version_num,
			          x_return_status         => l_return_status,
			          x_msg_count             => l_msg_count,
			          x_msg_data              => l_msg_data);
    p_api_status := l_return_status;
    write_log_message('Update account l_return_status = ' ||
	          l_return_status);
  
    write_log_message('l_msg_count = ' || to_char(l_msg_count));
    write_log_message('l_msg_data = ' || l_msg_data);
    IF l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
        write_log_message(i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
			          1,
			          255));
      
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
	           substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
		      1,
		      255);
      END LOOP;
    
    END IF;
    p_error_msg := l_msg_data;
    write_log_message('Program Exited : xxhz_soa_api_pkg.update_account Procedure');
  EXCEPTION
    WHEN OTHERS THEN
      p_error_msg := 'Unexpected error in xxhz_soa_api_pkg.update_account Procedure : ' ||
	         SQLERRM;
      write_log_message(p_error_msg);
  END update_account;
  ---------------------------------------------------------------------------------------------
  --Added on 10th April 2017
  --(i) If Fax available and Contact Point Id not available then , new Contact Point ID will be created for FAX.
  --(ii) If Both the Values available, then it will Update the Fax to the Existing Contact Point ID.
  --(iii) If Contact Point ID available but Fax value not available , It will Disable the Fax Contact POint ID and During return the ID will be null to SFDC
  ----------------------------------------------------------------------------------------------
  PROCEDURE upsert_contact_point(p_phone_num             IN VARCHAR2, -- Send Phone Number
		         p_mobile_num            IN VARCHAR2, -- Send  Mobile  Number
		         p_fax_num               IN VARCHAR2, -- Send  Fax  Number
		         p_email_address         IN VARCHAR2,
		         p_web                   IN VARCHAR2,
		         p_relationship_party_id IN NUMBER,
		         p_owner_table_name      IN VARCHAR2 DEFAULT 'HZ_PARTIES',
		         ---
		         x_oe_phone_contact_point_id  IN OUT NOCOPY NUMBER,
		         x_oe_mobile_contact_point_id IN OUT NOCOPY NUMBER,
		         x_oe_fax_contact_point_id    IN OUT NOCOPY NUMBER,
		         x_oe_email_contact_point_id  IN OUT NOCOPY NUMBER,
		         x_oe_web_contact_point_id    IN OUT NOCOPY NUMBER,
		         ----
		         x_api_status IN OUT NOCOPY VARCHAR2,
		         x_error_msg  IN OUT NOCOPY VARCHAR2) IS
    person_rec              hz_party_v2pub.person_rec_type;
    location_rec            hz_location_v2pub.location_rec_type;
    party_site_rec          hz_party_site_v2pub.party_site_rec_type;
    org_contact_rec         hz_party_contact_v2pub.org_contact_rec_type;
    rec_cust_acc_role       hz_cust_account_role_v2pub.cust_account_role_rec_type;
    l_contact_point_record  hz_contact_point_v2pub.contact_point_rec_type;
    l_email_rec             hz_contact_point_v2pub.email_rec_type;
    l_phone_rec             hz_contact_point_v2pub.phone_rec_type;
    l_web_rec               hz_contact_point_v2pub.web_rec_type;
    l_territory_code        fnd_territories_vl.territory_code%TYPE;
    l_object_id             NUMBER;
    l_relationship_party_id NUMBER;
    l_person_party_id       NUMBER;
    x_org_contact_id        NUMBER;
    l_rel_party_id          NUMBER;
    l_person_obj_versn_num  NUMBER;
    l_location_id           NUMBER;
    l_resp_id               NUMBER;
    l_resp_appl_id          NUMBER;
    l_user_id               NUMBER;
    l_location_vrsn_num     NUMBER;
    l_psrty_site_vrsn_num   NUMBER;
    --l_contact_point_id      NUMBER;
    l_contct_pnt_vrsn_num  NUMBER;
    l_party_id             NUMBER;
    l_party_site_id        NUMBER;
    l_api_status           VARCHAR2(10);
    l_error_msg            VARCHAR2(4000);
    l_main_status          VARCHAR2(10);
    l_main_err_msg         VARCHAR2(500);
    l_party_site_number    hz_party_sites.party_site_number%TYPE;
    l_cust_account_role_id NUMBER;
    l_record_count         NUMBER;
    l_contact_out_rec      xxhz_contact_rec;
    l_contact_out_tab      xxhz_contact_tab := xxhz_contact_tab();
  
    l_phone_line_type    VARCHAR2(10);
    l_contact_point_type VARCHAR2(10);
    l_contact_point_id   NUMBER;
    l_objvernum          NUMBER;
    l_progress           BOOLEAN := FALSE;
    l_action             VARCHAR2(7);
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.upsert_contact_point Procedure');
    x_api_status                                 := fnd_api.g_ret_sts_success;
    x_error_msg                                  := '';
    l_phone_rec                                  := NULL;
    l_email_rec                                  := NULL;
    l_web_rec                                    := NULL;
    l_contact_point_record.created_by_module     := g_created_by_module;
    l_contact_point_record.owner_table_name      := p_owner_table_name; -- Default Value 'HZ_PARTIES'
    l_contact_point_record.contact_point_purpose := 'BUSINESS';
    l_contact_point_record.owner_table_id        := p_relationship_party_id;
    l_contact_point_record.contact_point_type    := 'PHONE';
    l_contact_point_record.status                := 'A';
    ---------------------------------------
    -- Create or Update PHONE Contact Point
    ---------------------------------------
    IF p_phone_num IS NOT NULL OR x_oe_phone_contact_point_id IS NOT NULL THEN
      /*l_error_msg  := NULL;
      l_api_status := NULL;*/
      l_contact_point_record.primary_flag     := 'Y';
      l_contact_point_record.contact_point_id := x_oe_phone_contact_point_id;
      l_contact_point_record.status           := 'A';
      ---
      l_phone_rec.phone_area_code    := fnd_api.g_null_char;
      l_phone_rec.phone_country_code := fnd_api.g_null_char;
      l_phone_rec.phone_number       := p_phone_num;
      l_phone_rec.phone_line_type    := 'GEN';
    
      IF x_oe_phone_contact_point_id IS NULL THEN
        --Create Phone Contact Point
        l_action := 'Create';
        create_contact_point(p_contact_point_record => l_contact_point_record,
		     p_phone_record         => l_phone_rec,
		     p_api_status           => l_api_status,
		     p_error_msg            => l_error_msg,
		     p_contact_point_id     => x_oe_phone_contact_point_id);
      
      ELSE
        --Update Phone Contact Point
        l_action := 'Update';
        --Disable Contact POint ID Avaialble but Phone Number null
        IF x_oe_phone_contact_point_id IS NOT NULL AND p_phone_num IS NULL THEN
          l_contact_point_record.status       := 'I';
          l_contact_point_record.primary_flag := 'N';
          l_phone_rec                         := NULL;
          l_action                            := 'Delete';
        END IF;
      
        l_objvernum := get_contact_point_obj_ver(x_oe_phone_contact_point_id);
        update_contact_point(p_contact_point_record => l_contact_point_record,
		     p_phone_record         => l_phone_rec,
		     p_obj_version          => l_objvernum,
		     p_api_status           => l_api_status,
		     p_error_msg            => l_error_msg);
      END IF;
    
      IF l_api_status != fnd_api.g_ret_sts_success THEN
        x_error_msg := x_error_msg || '.Error In ' || l_action ||
	           ' PHONE Contact Point :' || l_error_msg;
      ELSIF l_api_status = fnd_api.g_ret_sts_success AND
	l_action = 'Delete' THEN
        x_oe_phone_contact_point_id := NULL;
      END IF;
      write_log_message('Action :' || l_action);
      write_log_message('Phone Contact Point  Creation API STATUS : ' ||
		l_api_status);
      write_log_message('Phone Contact Point  Creation ERROR Message: ' ||
		x_error_msg);
      write_log_message('Phone Contact Point  Creation New Contact Point ID : ' ||
		x_oe_phone_contact_point_id);
    END IF;
  
    ----------------------------------------
    -- Create or Update MOBILE Contact Point
    ----------------------------------------
    IF p_mobile_num IS NOT NULL OR x_oe_mobile_contact_point_id IS NOT NULL THEN
      /*l_error_msg  := NULL;
      l_api_status := NULL;*/
      l_contact_point_record.primary_flag     := 'N';
      l_contact_point_record.contact_point_id := x_oe_mobile_contact_point_id;
      l_contact_point_record.status           := 'A';
      ---
      l_phone_rec.phone_area_code    := fnd_api.g_null_char;
      l_phone_rec.phone_country_code := fnd_api.g_null_char;
      l_phone_rec.phone_number       := p_mobile_num;
      l_phone_rec.phone_line_type    := 'MOBILE';
    
      IF x_oe_mobile_contact_point_id IS NULL THEN
        --Create Mobile Contact Point
        l_action := 'Create';
        create_contact_point(p_contact_point_record => l_contact_point_record,
		     p_phone_record         => l_phone_rec,
		     p_api_status           => l_api_status,
		     p_error_msg            => l_error_msg,
		     p_contact_point_id     => x_oe_mobile_contact_point_id);
      
      ELSE
        --Update MOBILE Contact Point
        l_action := 'Update';
        --Disable Contact POint ID Avaialble but Phone Number null
        IF x_oe_mobile_contact_point_id IS NOT NULL AND
           p_mobile_num IS NULL THEN
          l_contact_point_record.status := 'I';
          l_phone_rec                   := NULL;
          l_action                      := 'Delete';
        END IF;
        l_objvernum := get_contact_point_obj_ver(x_oe_mobile_contact_point_id);
        update_contact_point(p_contact_point_record => l_contact_point_record,
		     p_phone_record         => l_phone_rec,
		     p_obj_version          => l_objvernum,
		     p_api_status           => l_api_status,
		     p_error_msg            => l_error_msg);
      
      END IF;
      IF l_api_status != fnd_api.g_ret_sts_success THEN
        x_error_msg := x_error_msg || '.Error In ' || l_action ||
	           ' MOBILE Contact Point :' || l_error_msg;
      ELSIF l_api_status = fnd_api.g_ret_sts_success AND
	l_action = 'Delete' THEN
        x_oe_mobile_contact_point_id := NULL;
      END IF;
      write_log_message('Action :' || l_action);
      write_log_message('MOBILE Contact Point  Creation API STATUS : ' ||
		l_api_status);
      write_log_message('MOBILE Contact Point  Creation ERROR Message: ' ||
		x_error_msg);
      write_log_message('MOBILE Contact Point  Creation New Contact Point ID : ' ||
		x_oe_mobile_contact_point_id);
    END IF;
  
    -------------------------------------
    -- Create or Update FAX Contact Point
    -------------------------------------
    IF p_fax_num IS NOT NULL OR x_oe_fax_contact_point_id IS NOT NULL THEN
      /*l_error_msg  := NULL;
      l_api_status := NULL;*/
      l_contact_point_record.primary_flag     := 'N';
      l_contact_point_record.contact_point_id := x_oe_fax_contact_point_id;
      l_contact_point_record.status           := 'A';
      ---
      l_phone_rec.phone_area_code    := fnd_api.g_null_char;
      l_phone_rec.phone_country_code := fnd_api.g_null_char;
      l_phone_rec.phone_number       := p_fax_num;
      l_phone_rec.phone_line_type    := 'FAX';
    
      IF x_oe_fax_contact_point_id IS NULL THEN
        -- Create Fax Contact Point
        l_action := 'Create';
        create_contact_point(p_contact_point_record => l_contact_point_record,
		     p_phone_record         => l_phone_rec,
		     p_api_status           => l_api_status,
		     p_error_msg            => l_error_msg,
		     p_contact_point_id     => x_oe_fax_contact_point_id);
      
      ELSE
        --Update FAX Contact Point
        l_action := 'Update';
        --Disable Contact POint ID Avaialble but Phone Number null
        IF x_oe_fax_contact_point_id IS NOT NULL AND p_fax_num IS NULL THEN
          l_contact_point_record.status := 'I';
          l_phone_rec                   := NULL;
          l_action                      := 'Delete';
        END IF;
      
        l_objvernum := get_contact_point_obj_ver(x_oe_fax_contact_point_id);
        update_contact_point(p_contact_point_record => l_contact_point_record,
		     p_phone_record         => l_phone_rec,
		     p_obj_version          => l_objvernum,
		     p_api_status           => l_api_status,
		     p_error_msg            => l_error_msg);
      END IF;
    
      IF l_api_status != fnd_api.g_ret_sts_success THEN
        x_error_msg := x_error_msg || '.Error In ' || l_action ||
	           ' FAX  Contact Point :' || l_error_msg;
      ELSIF l_api_status = fnd_api.g_ret_sts_success AND
	l_action = 'Delete' THEN
        x_oe_fax_contact_point_id := NULL;
      END IF;
    
      write_log_message('Action :' || l_action);
      write_log_message('FAX Contact Point  Creation API STATUS : ' ||
		l_api_status);
      write_log_message('FAX Contact Point  Creation ERROR Message: ' ||
		l_error_msg);
      write_log_message('FAX Contact Point  Creation New Contact Point ID : ' ||
		x_oe_fax_contact_point_id);
    END IF;
  
    -----------------------------------------------
    -- Create or Update Email Address Contact Point
    -----------------------------------------------
    IF p_email_address IS NOT NULL OR
       x_oe_email_contact_point_id IS NOT NULL THEN
      /*l_error_msg  := NULL;
      l_api_status := NULL;*/
      l_contact_point_record.contact_point_type := 'EMAIL';
      l_contact_point_record.primary_flag       := 'N';
      l_contact_point_record.contact_point_id   := x_oe_email_contact_point_id;
      l_contact_point_record.status             := 'A';
      ---
      l_email_rec.email_address := p_email_address;
      l_email_rec.email_format  := 'MAILHTML';
    
      IF x_oe_email_contact_point_id IS NULL THEN
        --Create Email Address Contact Point
        l_action := 'Create';
        create_contact_point(p_contact_point_record => l_contact_point_record,
		     p_email_record         => l_email_rec,
		     p_api_status           => l_api_status,
		     p_error_msg            => l_error_msg,
		     p_contact_point_id     => x_oe_email_contact_point_id);
      
      ELSE
        --Update Email Address Contact Point
        l_action := 'Update';
        --Disable Contact POint ID Avaialble but Phone Number null
        IF x_oe_email_contact_point_id IS NOT NULL AND
           p_email_address IS NULL THEN
          l_contact_point_record.status := 'I';
          l_email_rec                   := NULL;
          l_action                      := 'Delete';
        END IF;
        l_objvernum := get_contact_point_obj_ver(x_oe_email_contact_point_id);
        update_contact_point(p_contact_point_record => l_contact_point_record,
		     p_email_record         => l_email_rec,
		     p_obj_version          => l_objvernum,
		     p_api_status           => l_api_status,
		     p_error_msg            => l_error_msg);
      
      END IF;
    
      IF l_api_status != fnd_api.g_ret_sts_success THEN
        x_error_msg := x_error_msg || '.Error In ' || l_action ||
	           ' EMAIL ADDRESS Contact Point :' || l_error_msg;
      ELSIF l_api_status = fnd_api.g_ret_sts_success AND
	l_action = 'Delete' THEN
        x_oe_email_contact_point_id := NULL;
      END IF;
    
      write_log_message('Action :' || l_action);
      write_log_message('EMAIL Contact Point  Creation API STATUS : ' ||
		l_api_status);
      write_log_message('EMAIL Contact Point  Creation ERROR Message: ' ||
		x_error_msg);
      write_log_message('EMAIL Contact Point  Creation New Contact Point ID : ' ||
		x_oe_email_contact_point_id);
    END IF;
  
    ---------------------------------------
    -- Create or Update WEB Contact Point
    ---------------------------------------
    IF p_web IS NOT NULL OR x_oe_web_contact_point_id IS NOT NULL THEN
      /*l_error_msg  := NULL;
      l_api_status := NULL;*/
      l_contact_point_record.contact_point_type    := 'WEB';
      l_contact_point_record.contact_point_purpose := 'HOMEPAGE';
      l_contact_point_record.primary_flag          := 'N';
      l_contact_point_record.contact_point_id      := x_oe_web_contact_point_id;
      l_contact_point_record.status                := 'A';
      ---
      l_web_rec.url      := p_web;
      l_web_rec.web_type := 'HTTP';
    
      IF x_oe_web_contact_point_id IS NULL THEN
        --Create Phone Contact Point
        l_action := 'Create';
        create_contact_point(p_contact_point_record => l_contact_point_record,
		     p_web_record           => l_web_rec,
		     p_api_status           => l_api_status,
		     p_error_msg            => l_error_msg,
		     p_contact_point_id     => x_oe_web_contact_point_id);
      
      ELSE
        --Update Phone Contact Point
        l_action := 'Update';
        --Disable Contact POint ID Avaialble but Phone Number null
        IF x_oe_web_contact_point_id IS NOT NULL AND p_web IS NULL THEN
          l_contact_point_record.status := 'I';
          l_web_rec                     := NULL;
          l_action                      := 'Delete';
        END IF;
        l_objvernum := get_contact_point_obj_ver(x_oe_web_contact_point_id);
        update_contact_point(p_contact_point_record => l_contact_point_record,
		     p_web_record           => l_web_rec,
		     p_obj_version          => l_objvernum,
		     p_api_status           => l_api_status,
		     p_error_msg            => l_error_msg);
      END IF;
    
      IF l_api_status != fnd_api.g_ret_sts_success THEN
        x_error_msg := x_error_msg || '.Error In ' || l_action ||
	           ' PHONE Contact Point :' || l_error_msg;
      ELSIF l_api_status = fnd_api.g_ret_sts_success AND
	l_action = 'Delete' THEN
        x_oe_web_contact_point_id := NULL;
      END IF;
    
      write_log_message('Action :' || l_action);
      write_log_message('WEB Contact Point  Creation API STATUS : ' ||
		l_api_status);
      write_log_message('WEB Contact Point  Creation ERROR Message: ' ||
		x_error_msg);
      write_log_message('WEB Contact Point  Creation New Contact Point ID : ' ||
		x_oe_web_contact_point_id);
    END IF;
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.upsert_contact_point Procedure');
  EXCEPTION
    WHEN OTHERS THEN
      x_api_status := fnd_api.g_ret_sts_error;
      x_error_msg  := x_error_msg || '.' || SQLERRM;
      write_log_message('Program Exited : xxhz_soa_api_pkg.upsert_contact_point Procedure with Error :' ||
		SQLERRM);
  END upsert_contact_point;
  /******************************************************************************************************************************************
   * Type                : Procedure                                                                                                         *
   * Module Name         : AR_CUSTOMERS                                                                                                      *
   * Name                : create_contact_point                                                                                                *
   * Script Name         : xxhz_api_pkg.pkb                                                                                        *
   *                                                                                                                                         *
                                                                                                                                             *                                                                                                                                            *
   * Purpose             :  This procedure will call the hz_contact_point_v2pub.create_contact_point api to create
                            contact point in S3 system with the same data of SFDC environment. This api will create
                            the contact point to the S3 system collected through the SOA Integration
                                                                                                                       *
                                                                                                                                             *
   * HISTORY                                                                                                                                 *
   * =======                                                                                                                                 *
   * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
   * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     11/05/2016  Somnath Dawn                Initial version                                                                                      *
   ******************************************************************************************************************************************/

  PROCEDURE create_contact_point(p_contact_point_record IN hz_contact_point_v2pub.contact_point_rec_type,
		         p_edi_record           IN hz_contact_point_v2pub.edi_rec_type,
		         p_email_record         IN hz_contact_point_v2pub.email_rec_type,
		         p_phone_record         IN hz_contact_point_v2pub.phone_rec_type,
		         p_telex_record         IN hz_contact_point_v2pub.telex_rec_type,
		         p_web_record           IN hz_contact_point_v2pub.web_rec_type,
		         p_api_status           OUT VARCHAR2,
		         p_error_msg            OUT VARCHAR2,
		         p_contact_point_id     OUT NUMBER) IS
    x_return_status         VARCHAR2(20);
    x_msg_count             NUMBER;
    x_msg_data              VARCHAR2(2000);
    x_contact_point_id      NUMBER;
    l_num_user_id           NUMBER := fnd_global.user_id;
    l_num_responsibility_id NUMBER := apps.fnd_global.resp_appl_id;
    l_num_applicaton_id     NUMBER := apps.fnd_global.resp_id;
    l_conc_request_id       NUMBER := fnd_global.conc_request_id;
    l_num_user_id           NUMBER := fnd_global.user_id;
    l_num_responsibility_id NUMBER := fnd_global.resp_id;
    l_num_applicaton_id     NUMBER := fnd_global.resp_appl_id;
    l_conc_request_id       NUMBER := fnd_global.conc_request_id;
    e_finding_cust_accnt_id EXCEPTION;
  
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.create_contact_point Procedure :' ||
	          p_contact_point_record.contact_point_type,
	          'Y');
  
    p_api_status := fnd_api.g_ret_sts_success;
    p_error_msg  := NULL;
  
    hz_contact_point_v2pub.create_contact_point(p_init_msg_list     => fnd_api.g_true,
				p_contact_point_rec => p_contact_point_record,
				p_edi_rec           => p_edi_record,
				p_email_rec         => p_email_record,
				p_phone_rec         => p_phone_record,
				p_telex_rec         => p_telex_record,
				p_web_rec           => p_web_record,
				x_contact_point_id  => x_contact_point_id,
				x_return_status     => x_return_status,
				x_msg_count         => x_msg_count,
				x_msg_data          => x_msg_data);
    p_api_status       := x_return_status;
    p_error_msg        := x_msg_data;
    p_contact_point_id := x_contact_point_id;
  
    write_log_message('Contact Point p_api_status=' || x_return_status);
    write_log_message('Contact Point p_error_msg=' || x_msg_data);
  
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        write_log_message(i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
			          1,
			          255));
      
      END LOOP;
      p_error_msg := x_msg_data;
    END IF;
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.create_contact_point Procedure');
  EXCEPTION
    WHEN OTHERS THEN
      p_error_msg := 'Unexpected error in xxhz_soa_api_pkg.create_contact_point :' ||
	         SQLERRM;
      write_log_message(p_error_msg);
  END create_contact_point;
  /******************************************************************************************************************************************
   * Type                : Procedure                                                                                                         *
   * Module Name         : AR_CUSTOMERS                                                                                                      *
   * Name                : update_contact_point                                                                                                *
   * Script Name         : xxhz_api_pkg.pkb                                                                                        *
   *                                                                                                                                         *
                                                                                                                                             *                                                                                                                                            *
   * Purpose             :  This procedure will call the hz_contact_point_v2pub.update_contact_point api to update
                            contact point in S3 system with the same data of SFDC environment. This api will update
                            the contact point to the S3 system collected through the SOA Integration
                                                                                                                       *
                                                                                                                                             *
   * HISTORY                                                                                                                                 *
   * =======                                                                                                                                 *
   * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
   * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     11/05/2016  Somnath Dawn                Initial version                                                                                      *
   ******************************************************************************************************************************************/

  PROCEDURE update_contact_point(p_contact_point_record IN hz_contact_point_v2pub.contact_point_rec_type,
		         p_edi_record           IN hz_contact_point_v2pub.edi_rec_type,
		         p_email_record         IN hz_contact_point_v2pub.email_rec_type,
		         p_phone_record         IN hz_contact_point_v2pub.phone_rec_type,
		         p_telex_record         IN hz_contact_point_v2pub.telex_rec_type,
		         p_web_record           IN hz_contact_point_v2pub.web_rec_type,
		         p_obj_version          IN NUMBER,
		         p_api_status           OUT VARCHAR2,
		         p_error_msg            OUT VARCHAR2) IS
    l_object_version_number NUMBER;
    x_return_status         VARCHAR2(20);
    x_msg_data              VARCHAR2(2000);
    x_msg_count             NUMBER;
    l_error_msg             VARCHAR2(4000);
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.update_contact_point Procedure :' ||
	          p_contact_point_record.contact_point_type,
	          'Y');
    /*fnd_global.apps_initialize(user_id      => g_num_user_id,
    resp_id      => g_num_resp_id,
    resp_appl_id => g_num_application_id);*/ -- Commented on 06.04.17 by Lingaraj
    l_object_version_number := p_obj_version;
    p_api_status            := fnd_api.g_ret_sts_success;
    p_error_msg             := NULL;
    --p_phone_record.phone_area_code    := fnd_api.g_null_num;
    --  p_phone_record.phone_country_code := fnd_api.g_null_num;
    hz_contact_point_v2pub.update_contact_point(p_init_msg_list         => fnd_api.g_true,
				p_contact_point_rec     => p_contact_point_record,
				p_edi_rec               => p_edi_record,
				p_email_rec             => p_email_record,
				p_phone_rec             => p_phone_record,
				p_telex_rec             => p_telex_record,
				p_web_rec               => p_web_record,
				p_object_version_number => l_object_version_number,
				x_return_status         => x_return_status,
				x_msg_count             => x_msg_count,
				x_msg_data              => x_msg_data);
  
    p_api_status := x_return_status;
    write_log_message('Update Contact Point l_return_status = ' ||
	          x_return_status);
  
    write_log_message('l_msg_count = ' || to_char(x_msg_count));
    write_log_message('l_msg_data = ' || x_msg_data);
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        write_log_message(i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
			          1,
			          255));
      
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
	           substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
		      1,
		      255);
      END LOOP;
    
    END IF;
    p_error_msg := x_msg_data;
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.update_contact_point Procedure');
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_msg := 'Unexpected error in xxhz_soa_api_pkg.update_contact_point Procedure :' ||
	         SQLERRM;
      write_log_message(p_error_msg);
  END update_contact_point;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : create_contact                                                                                                *
  * Script Name         : xxhz_api_pkg.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_party_contact_v2pub.create_org_contact api to Create
                           contact at organization level in S3 system with the same data of SFDC environment. This api will create
                           the contact to the S3 system collected through the SOA Integration
                                                                                                                      *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     11/05/2016  Somnath Dawn                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE create_contact(p_contact_record        IN hz_party_contact_v2pub.org_contact_rec_type,
		   p_relationship_party_id OUT VARCHAR2,
		   p_org_contact_id        OUT NUMBER,
		   p_api_status            OUT VARCHAR2,
		   p_error_msg             OUT VARCHAR2) IS
    x_org_contact_id NUMBER;
    x_party_rel_id   NUMBER;
    x_party_id       NUMBER;
    x_party_number   NUMBER;
    x_return_status  VARCHAR2(10);
    x_msg_count      NUMBER;
    x_msg_data       VARCHAR2(2000);
    l_error_msg      VARCHAR2(4000);
  
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.create_contact Procedure',
	          'Y');
    /*fnd_global.apps_initialize(user_id      => g_num_user_id,
    resp_id      => g_num_resp_id,
    resp_appl_id => g_num_application_id);*/ -- Commented on 06.04.17 by Lingaraj
  
    hz_party_contact_v2pub.create_org_contact(p_init_msg_list   => fnd_api.g_true,
			          p_org_contact_rec => p_contact_record,
			          x_org_contact_id  => x_org_contact_id,
			          x_party_rel_id    => x_party_rel_id,
			          x_party_id        => x_party_id,
			          x_party_number    => x_party_number,
			          x_return_status   => x_return_status,
			          x_msg_count       => x_msg_count,
			          x_msg_data        => x_msg_data);
  
    p_api_status            := x_return_status;
    p_relationship_party_id := x_party_id;
    p_org_contact_id        := x_org_contact_id;
  
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        write_log_message(i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
			          1,
			          255));
      
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
	           substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
		      1,
		      255);
      END LOOP;
    END IF;
    p_error_msg := x_msg_data;
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.create_contact Procedure');
  END create_contact;
  /******************************************************************************************************************************************
   * Type                : Procedure                                                                                                         *
   * Module Name         : AR_CUSTOMERS                                                                                                      *
   * Name                : update_contact                                                                                                *
   * Script Name         : xxhz_api_pkg.pkb                                                                                        *
   *                                                                                                                                         *
                                                                                                                                             *                                                                                                                                            *
   * Purpose             :  This procedure will call the hz_party_contact_v2pub.update_org_contact api to update the
                            contact in S3 system with the same data of SFDC environment. This api will update
                            the contact to the S3 system collected through the SOA Integration
                                                                                                                       *
                                                                                                                                             *
   * HISTORY                                                                                                                                 *
   * =======                                                                                                                                 *
   * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
   * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     11/05/2016  Somnath Dawn                Initial version                                                                                      *
   ******************************************************************************************************************************************/

  PROCEDURE update_contact(p_contact_record           IN hz_party_contact_v2pub.org_contact_rec_type,
		   p_contact_obj_version_num  IN NUMBER,
		   p_relation_obj_version_num IN NUMBER,
		   p_party_obj_version_num    IN NUMBER,
		   p_api_status               OUT VARCHAR2,
		   p_error_msg                OUT VARCHAR2) IS
    x_return_status            VARCHAR2(10);
    x_msg_count                NUMBER;
    x_msg_data                 VARCHAR2(2000);
    l_error_msg                VARCHAR2(4000);
    l_contact_obj_version_num  NUMBER := p_contact_obj_version_num;
    l_relation_obj_version_num NUMBER := p_relation_obj_version_num;
    l_party_obj_version_num    NUMBER := p_party_obj_version_num;
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.update_contact Procedure',
	          'Y');
    /*fnd_global.apps_initialize(user_id      => g_num_user_id,
    resp_id      => g_num_resp_id,
    resp_appl_id => g_num_application_id);*/ -- Commented on 06.04.17 by Lingaraj
    write_log_message('Updating Contact....');
    hz_party_contact_v2pub.update_org_contact(p_org_contact_rec             => p_contact_record,
			          p_cont_object_version_number  => l_contact_obj_version_num,
			          p_rel_object_version_number   => l_relation_obj_version_num,
			          p_party_object_version_number => l_party_obj_version_num,
			          x_return_status               => x_return_status,
			          x_msg_count                   => x_msg_count,
			          x_msg_data                    => x_msg_data);
    p_api_status := x_return_status;
  
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        write_log_message(i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
			          1,
			          255));
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
	           substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
		      1,
		      255);
      END LOOP;
    
    END IF;
    p_error_msg := x_msg_data;
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.update_contact Procedure');
  END update_contact;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : create_account_role                                                                                                *
  * Script Name         : xxhz_api_pkg.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_cust_account_role_v2pub.create_cust_account_role api to
                           create the contact at account level in S3 system with the same data of SFDC environment.
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     11/05/2016  Somnath Dawn                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE create_account_role(p_cust_account_role_record IN OUT hz_cust_account_role_v2pub.cust_account_role_rec_type,
		        p_relationship_party_id    IN VARCHAR2,
		        p_cust_account_role_id     OUT NUMBER,
		        p_api_status               OUT VARCHAR2,
		        p_error_msg                OUT VARCHAR2) IS
    x_return_status        VARCHAR2(10);
    x_msg_count            NUMBER;
    x_msg_data             VARCHAR2(2000);
    x_cust_account_role_id NUMBER;
    l_error_msg            VARCHAR2(4000);
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.create_account_role Procedure',
	          'Y');
    /*fnd_global.apps_initialize(user_id      => g_num_user_id,
    resp_id      => g_num_resp_id,
    resp_appl_id => g_num_application_id);*/ -- Commented on 06.04.17 by Lingaraj
  
    BEGIN
      p_cust_account_role_record.party_id          := p_relationship_party_id;
      p_cust_account_role_record.role_type         := 'CONTACT';
      p_cust_account_role_record.created_by_module := g_created_by_module; --'TCA_V1_API';
      hz_cust_account_role_v2pub.create_cust_account_role(fnd_api.g_true,
				          p_cust_account_role_record,
				          x_cust_account_role_id,
				          x_return_status,
				          x_msg_count,
				          x_msg_data);
    
      p_cust_account_role_id := x_cust_account_role_id;
      write_log_message('Creating Role..');
      write_log_message('Creating Role Status=' || x_return_status);
      write_log_message('Creating Role message=' || x_msg_data);
      IF x_msg_count > 1 THEN
        FOR i IN 1 .. x_msg_count LOOP
          write_log_message(i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
				1,
				255));
        
          l_error_msg := l_error_msg || chr(10) || i || '. ' ||
		 substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
		        1,
		        255);
        END LOOP;
        p_error_msg := l_error_msg;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        write_log_message('Contact at Account level is not created....');
    END;
    p_api_status := x_return_status;
  
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        write_log_message(i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
			          1,
			          255));
      
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
	           substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
		      1,
		      255);
      END LOOP;
    END IF;
    p_error_msg := x_msg_data;
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.create_account_role Procedure');
  END create_account_role;
  --update_account_role
  PROCEDURE update_account_role(p_cust_account_role_record IN hz_cust_account_role_v2pub.cust_account_role_rec_type,
		        p_api_status               OUT NOCOPY VARCHAR2,
		        p_error_msg                OUT NOCOPY VARCHAR2) IS
    l_msg_count NUMBER;
    -- l_msg_data             VARCHAR2(2000);
    l_cust_account_role_id  NUMBER;
    l_error_msg             VARCHAR2(4000);
    l_obj_ver_num           NUMBER;
    l_cust_account_role_rec hz_cust_account_role_v2pub.cust_account_role_rec_type;
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.Update_account_role Procedure',
	          'Y');
    ---------------------------------------------------------------
    --If Status is 'I', Get the Lastest Updated Record from Data Base
    ---------------------------------------------------------------
    IF p_cust_account_role_record.status = 'I' THEN
      hz_cust_account_role_v2pub.get_cust_account_role_rec(p_init_msg_list         => fnd_api.g_true,
				           p_cust_account_role_id  => p_cust_account_role_record.cust_account_role_id,
				           x_cust_account_role_rec => l_cust_account_role_rec, -- Out
				           x_return_status         => p_api_status,
				           x_msg_count             => l_msg_count,
				           x_msg_data              => p_error_msg);
      write_log_message(' Call to get_cust_account_role_rec Status / Error :' ||
		p_api_status || '/' || p_error_msg);
      IF p_api_status = fnd_api.g_ret_sts_success THEN
        l_cust_account_role_rec.status := 'I';
        --Get the Object Version Number.
        SELECT object_version_number
        INTO   l_obj_ver_num
        FROM   hz_cust_account_roles
        WHERE  cust_account_role_id =
	   p_cust_account_role_record.cust_account_role_id;
      
        --Inactivate cust_account_role
        --Table Name : hz_cust_account_roles
        hz_cust_account_role_v2pub.update_cust_account_role(p_init_msg_list         => fnd_api.g_true,
					p_cust_account_role_rec => l_cust_account_role_rec,
					p_object_version_number => l_obj_ver_num,
					x_return_status         => p_api_status,
					x_msg_count             => l_msg_count,
					x_msg_data              => p_error_msg);
      
        write_log_message(' Call to update_cust_account_role Status / Error :' ||
		  p_api_status || '/' || p_error_msg);
      END IF;
    END IF;
  
    IF p_api_status = fnd_api.g_ret_sts_error AND l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
      
        p_error_msg := p_error_msg || chr(10) || i || '. ' ||
	           substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
		      1,
		      255);
      END LOOP;
      write_log_message('Error :' || p_error_msg);
    END IF;
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.Update_account_role Procedure');
  EXCEPTION
    WHEN OTHERS THEN
      p_api_status := fnd_api.g_ret_sts_error;
      p_error_msg  := p_error_msg || '.Exception:' || SQLERRM;
      write_log_message('Program Exited : xxhz_soa_api_pkg.Update_account_role Procedure with Exception :' ||
		p_error_msg);
  END update_account_role;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Conversion Name     :                                                                                                                   *
  * Name                : CREATE_ACCT_SITE                                                                                                  *
  * Script Name         : xxhz_api_pkg.pkb                                                                                              *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             : This Procedure is Used to Create Account Site in S3 Environment                                               *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                     *
  * -------  ----------- ---------------    ------------------------------------                                                            *
  * 1.00     11/05/2016  Somnath Dawn                Initial version                                                                                      *
  ******************************************************************************************************************************************/
  PROCEDURE create_acct_site(p_cust_acct_site_rec IN hz_cust_account_site_v2pub.cust_acct_site_rec_type,
		     p_cust_acct_site_id  OUT NUMBER,
		     p_api_status         OUT VARCHAR2,
		     p_error_msg          OUT VARCHAR2) IS
  
    -- Local Variable Declaration .
    x_cust_acct_site_id NUMBER;
    x_return_status     VARCHAR2(10);
    x_msg_count         NUMBER;
    x_msg_data          VARCHAR2(4000);
    l_error_msg         VARCHAR2(4000);
  
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.create_acct_site Procedure');
  
    hz_cust_account_site_v2pub.create_cust_acct_site(p_init_msg_list      => fnd_api.g_true,
				     p_cust_acct_site_rec => p_cust_acct_site_rec,
				     x_cust_acct_site_id  => x_cust_acct_site_id,
				     x_return_status      => x_return_status,
				     x_msg_count          => x_msg_count,
				     x_msg_data           => x_msg_data);
    p_cust_acct_site_id := x_cust_acct_site_id;
    p_api_status        := x_return_status;
    p_error_msg         := x_msg_data;
  
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        write_log_message(i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
			          1,
			          255));
      
      END LOOP;
    
    END IF;
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.create_acct_site Procedure');
  EXCEPTION
    WHEN OTHERS THEN
      l_error_msg := 'Unexpected Error in xxhz_soa_api_pkg.create_acct_site Procedure :' ||
	         SQLERRM;
      write_log_message(l_error_msg);
  END create_acct_site;

  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Conversion Name     :                                                                                                                   *
  * Name                : UPDATE_ACCT_SITE                                                                                                 *
  * Script Name         : xxhz_api_pkg.pkb                                                                                *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             : This Procedure is Used to Update Location in S3 Environment if there is Modification                              *
                          of Location Entity in S3 Environment.                                                                             *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                     *
  * -------  ----------- ---------------    ------------------------------------                                                            *
  * 1.00     11/05/2016  Somnath Dawn                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE update_acct_site(p_cust_acct_site_rec    IN hz_cust_account_site_v2pub.cust_acct_site_rec_type,
		     p_object_version_number IN OUT NOCOPY NUMBER,
		     p_api_status            OUT VARCHAR2,
		     p_error_msg             OUT VARCHAR2) IS
    --x_return_status         VARCHAR2(10);
    l_msg_count NUMBER;
    l_msg_data  VARCHAR2(4000);
    --l_object_version_number NUMBER := p_object_version_number;
    l_error_msg VARCHAR2(4000);
  
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.update_acct_site Procedure',
	          'Y');
  
    hz_cust_account_site_v2pub.update_cust_acct_site(p_init_msg_list         => fnd_api.g_true,
				     p_cust_acct_site_rec    => p_cust_acct_site_rec,
				     p_object_version_number => p_object_version_number,
				     x_return_status         => p_api_status,
				     x_msg_count             => l_msg_count,
				     x_msg_data              => p_error_msg);
  
    --p_api_status := x_return_status;
    --p_error_msg  := x_msg_data;
  
    IF l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
        /*write_log_message(i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
        1,
        255));*/
        l_msg_data := l_msg_data || '(' || i || ')' ||
	          substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
		     1,
		     255);
      
      END LOOP;
    
      IF p_api_status != fnd_api.g_ret_sts_success THEN
        p_error_msg := p_error_msg || '.' || l_msg_data;
      END IF;
    
    END IF;
    IF g_debug = TRUE THEN
      write_log_message('Updating Cust account site...');
      write_log_message('Return Status = ' || p_api_status);
      write_log_message('Message Count = ' || to_char(l_msg_count));
      write_log_message('Error Message = ' || p_error_msg);
    END IF;
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.update_acct_site Procedure');
  EXCEPTION
    WHEN OTHERS THEN
      l_error_msg := 'Unexpected Error in xxhz_soa_api_pkg.update_acct_site Procedure :' ||
	         SQLERRM;
      write_log_message(l_error_msg);
  END update_acct_site;
  /******************************************************************************************************************************************
   * Type                : Procedure                                                                                                         *
   * Conversion Name     :                                                                                                                   *
   * Name                : CREATE_ACCT_SITE_USE                                                                                              *
   * Script Name         : xxhz_api_pkg.pkb                                                                                           *
   *                                                                                                                                         *
                                                                                                                                             *
   * Purpose             : This Procedure is Used to Create Account Site in Legacy Environment.                                              *
                                                                                                                                             *
   * HISTORY                                                                                                                                 *
   * =======                                                                                                                                 *
   * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                     *
   * -------  ----------- ---------------    ------------------------------------                                                            *
  * 1.00     11/05/2016  Somnath Dawn                Initial version                                                                                      *
   ******************************************************************************************************************************************/

  PROCEDURE create_acct_site_use(p_cust_site_use_rec IN hz_cust_account_site_v2pub.cust_site_use_rec_type,
		         p_site_use_id       OUT NUMBER,
		         p_api_status        OUT VARCHAR2,
		         p_error_msg         OUT VARCHAR2) IS
  
    l_msg_count             NUMBER;
    l_msg_data              VARCHAR2(4000);
    l_error_msg             VARCHAR2(4000);
    xx_customer_profile_rec hz_customer_profile_v2pub.customer_profile_rec_type;
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg.create_acct_site_use Procedure',
	          'Y');
    --write_log_message('Location Name :'|| p_cust_site_use_rec.location);
    hz_cust_account_site_v2pub.create_cust_site_use(p_init_msg_list        => fnd_api.g_true,
				    p_cust_site_use_rec    => p_cust_site_use_rec,
				    p_customer_profile_rec => xx_customer_profile_rec,
				    p_create_profile       => '',
				    p_create_profile_amt   => '',
				    x_site_use_id          => p_site_use_id,
				    x_return_status        => p_api_status,
				    x_msg_count            => l_msg_count,
				    x_msg_data             => p_error_msg);
  
    IF l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
        /*write_log_message(i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
        1,
        255));*/
        l_msg_data := l_msg_data || '(' || i || ')' ||
	          substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
		     1,
		     255);
      
      END LOOP;
    
      IF p_api_status != fnd_api.g_ret_sts_success THEN
        p_error_msg := p_error_msg || '.' || l_msg_data;
      END IF;
    END IF;
  
    IF g_debug = TRUE THEN
      write_log_message('hz_cust_account_site_v2pub.create_cust_site_use API Call Status / Message :' ||
		p_api_status || '/' || p_error_msg);
      write_log_message('x_site_use_id               =' || p_site_use_id);
      write_log_message('x_msg_count                 =' ||
		to_char(l_msg_count));
    END IF;
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.create_acct_site_use Procedure');
  EXCEPTION
    WHEN OTHERS THEN
      l_error_msg  := 'Unexpected Error in xxhz_soa_api_pkg.create_acct_site_use Procedure :' ||
	          SQLERRM;
      p_api_status := fnd_api.g_ret_sts_error;
      write_log_message(l_error_msg);
  END create_acct_site_use;

  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Conversion Name     :                                                                                                                   *
  * Name                : UPDATE_ACCT_SITE_USE                                                                                              *
  * Script Name         : xxhz_api_pkg.pkb                                                                                          *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             : This Procedure is Used to Update Location in S3 Environment if there is Modification                              *
                          of Location Entity in S3 Environment.                                                                             *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                     *
  * -------  ----------- ---------------    ------------------------------------                                                            *
  * 1.00     11/05/2016  Somnath Dawn                Initial version
  * 1.1      29.06.2018  Lingaraj                    CHG0042044- Account interface SFDC2Oracle                                                                                       *
  ******************************************************************************************************************************************/

  PROCEDURE update_acct_site_use(p_cust_site_use_rec     IN hz_cust_account_site_v2pub.cust_site_use_rec_type,
		         p_object_version_number IN OUT NOCOPY NUMBER,
		         p_api_status            OUT VARCHAR2,
		         p_error_msg             OUT VARCHAR2) IS
    l_msg_count NUMBER := 0;
    l_msg_data  VARCHAR2(4000);
  BEGIN
    write_log_message('  Program Entered : xxhz_soa_api_pkg.update_acct_site_use Procedure');
    --Begin CHG0042044
    BEGIN
      SELECT object_version_number
      INTO   p_object_version_number
      FROM   hz_cust_site_uses_all
      WHERE  cust_acct_site_id = p_cust_site_use_rec.cust_acct_site_id
      AND    site_use_id = p_cust_site_use_rec.site_use_id;
    EXCEPTION
      WHEN OTHERS THEN
        p_error_msg  := 'Unexpected error in xxhz_soa_api_pkg.update_acct_site_use Procedure: ' ||
		'Error During fetching of hz_cust_site_uses_all.object_version_number.' ||
		SQLERRM;
        p_api_status := fnd_api.g_ret_sts_error;
        RETURN;
    END;
    --End CHG0042044
    hz_cust_account_site_v2pub.update_cust_site_use(p_init_msg_list         => fnd_api.g_true,
				    p_cust_site_use_rec     => p_cust_site_use_rec,
				    p_object_version_number => p_object_version_number,
				    x_return_status         => p_api_status,
				    x_msg_count             => l_msg_count,
				    x_msg_data              => p_error_msg);
  
    IF l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
        l_msg_data := l_msg_data || '(' || i || ')' ||
	          substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
		     1,
		     255);
      
      END LOOP;
    
      IF p_api_status != fnd_api.g_ret_sts_success THEN
        p_error_msg := p_error_msg || '.' || l_msg_data;
      END IF;
    END IF;
  
    write_log_message(' hz_cust_account_site_v2pub.update_cust_site_use API Call Status / Message :' ||
	          p_api_status || '/' || p_error_msg);
  
    write_log_message('Program Exited : xxhz_soa_api_pkg.update_acct_site_use Procedure');
  EXCEPTION
    WHEN OTHERS THEN
      p_api_status := fnd_api.g_ret_sts_error;
      p_error_msg  := 'Unexpected error in xxhz_soa_api_pkg.update_acct_site_use Procedure: ' ||
	          SQLERRM;
      write_log_message(p_error_msg);
  END update_acct_site_use;
  /******************************************************************************************************************************************
   * Type                : Procedure                                                                                                         *
   * Conversion Name     :                                                                                                                   *
   * Name                : process_uda                                                                                              *
   * Script Name         : xxhz_api_pkg.pkb                                                                                          *
   *                                                                                                                                         *
                                                                                                                                             *                                                                                                                                            *
   * Purpose             : This Procedure is Used to Update UDA information in S3 Environment                                                *
                                                                                                                                             *
   * HISTORY                                                                                                                                 *
   * =======                                                                                                                                 *
   * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                     *
   * -------  ----------- ---------------    ------------------------------------                                                            *
  * 1.00     11/05/2016  Somnath Dawn                Initial version                                                                                      *
   ******************************************************************************************************************************************/
  /*
  PROCEDURE process_uda(p_cust_account_id IN NUMBER,
                        p_indus_class_cat IN VARCHAR2,
                        p_cross_industry  IN VARCHAR2,
                        p_institute_type  IN VARCHAR2,
                        p_department      IN VARCHAR2,
                        p_return_status   OUT VARCHAR2,
                        p_error_msg       OUT VARCHAR2) IS
    l_user_attr_data_table    ego_user_attr_data_table;
    l_user_attr_row_table     ego_user_attr_row_table;
    l_application_id          NUMBER := 0;
    l_attr_group_id           NUMBER := 0;
    l_errorcode               NUMBER := 0;
    l_msg_count               NUMBER;
    l_return_status           VARCHAR2(100);
    l_msg_data                VARCHAR2(2000);
    l_failed_row_id_list      VARCHAR2(10000);
    l_organization_profile_id NUMBER;
    x_return_status           VARCHAR2(10);
    x_msg_data                VARCHAR2(1000);
    l_errors_tbl              error_handler.error_tbl_type;
  
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg. Procedure');
    ----------------------
    -- Get Application Id
    -----------------------
    BEGIN
      SELECT application_id
      INTO   l_application_id
      FROM   apps.fnd_application
      WHERE  application_short_name = 'AR'; -- This requires AR application id
  
      write_log_message('application_id = ' || l_application_id);
  
    EXCEPTION
      WHEN no_data_found THEN
        write_log_message('No Data Found While Fetching Application ID');
      WHEN OTHERS THEN
        write_log_message('An Unexpected Error Occured While Fetching The Application ID');
    END;
  
    ---------------------------
    -- Get Profile Id
    ---------------------------
    BEGIN
  
      SELECT hop.organization_profile_id
      INTO   l_organization_profile_id
      FROM   hz_organization_profiles hop,
             hz_cust_accounts_all     hca
      WHERE  hca.party_id = hop.party_id
      AND    hop.effective_end_date IS NULL
      AND    hca.cust_account_id = p_cust_account_id;
  
      write_log_message('ORGANIZATION_PROFILE_ID = ' ||
                           l_organization_profile_id);
  
    EXCEPTION
      WHEN no_data_found THEN
        write_log_message('No Data Found While Fetching ORGANIZATION_PROFILE_ID');
  
      WHEN OTHERS THEN
        write_log_message('An Unexpected Error Occured While Fetching The ORGANIZATION_PROFILE_ID');
    END;
  
    ---------------------------------------------------------------
    -- Finding the Attribute Group Id for Customer Information DFF.
    ---------------------------------------------------------------
  
    SELECT DISTINCT a.attr_group_id
    INTO   l_attr_group_id
    FROM   ego_attr_groups_v a
    WHERE  a.attr_group_name = 'XXSSYS_IMC_ACCT_INFO' -- This is attribute group internal name - this will be unchanged till production
    AND    a.attr_group_type = 'HZ_ORG_PROFILES_GROUP'; -- Remains unchanged
  
    write_log_message('attr_group_id=' || l_attr_group_id);
  
    l_user_attr_row_table := ego_user_attr_row_table(ego_user_attr_row_obj(1,
                                                                           l_attr_group_id,
                                                                           l_application_id,
                                                                           'HZ_ORG_PROFILES_GROUP',
                                                                           'XXSSYS_IMC_ACCT_INFO',
                                                                           NULL,
                                                                           NULL,
                                                                           NULL,
                                                                           NULL,
                                                                           NULL,
                                                                           NULL,
                                                                           ego_user_attrs_data_pvt.g_sync_mode));
  
    l_user_attr_data_table := ego_user_attr_data_table(ego_user_attr_data_obj(1,
                                                                              'XXSSYS_IMC_INDUS_CLASS_CAT',
                                                                              p_indus_class_cat,
                                                                              NULL,
                                                                              NULL,
                                                                              NULL,
                                                                              NULL,
                                                                              NULL),
                                                       ego_user_attr_data_obj(1,
                                                                              'XXSSYS_IMC_CROSS_INDUSTRY',
                                                                              p_cross_industry,
                                                                              NULL,
                                                                              NULL,
                                                                              NULL,
                                                                              NULL,
                                                                              NULL),
                                                       ego_user_attr_data_obj(1,
                                                                              'XXSSYS_IMC_INSTITUTE_TYPE',
                                                                              p_institute_type,
                                                                              NULL,
                                                                              NULL,
                                                                              NULL,
                                                                              NULL,
                                                                              NULL),
                                                       ego_user_attr_data_obj(1,
                                                                              'XXSSYS_IMC_DEPT',
                                                                              p_department,
                                                                              NULL,
                                                                              NULL,
                                                                              NULL,
                                                                              NULL,
                                                                              NULL));
  
    BEGIN
      -- Calling the API to Process Org Records
      hz_extensibility_pub.process_organization_record(p_api_version           => 1.0,
                                                       p_org_profile_id        => l_organization_profile_id,
                                                       p_attributes_row_table  => l_user_attr_row_table,
                                                       p_attributes_data_table => l_user_attr_data_table,
                                                       p_debug_level           => 3,
                                                       p_commit                => fnd_api.g_true,
                                                       x_failed_row_id_list    => l_failed_row_id_list,
                                                       x_return_status         => l_return_status,
                                                       x_errorcode             => l_errorcode,
                                                       x_msg_count             => l_msg_count,
                                                       x_msg_data              => l_msg_data);
      p_error_msg := l_msg_data;
  
      IF (length(l_failed_row_id_list) > 0) THEN
        BEGIN
          error_handler.get_message_list(l_errors_tbl);
          FOR i IN 1 .. l_errors_tbl.count LOOP
            l_msg_data := l_errors_tbl(i).message_text;
            write_log_message('ERROR in process UDA=' || l_msg_data);
          END LOOP;
        END;
  
      ELSIF (l_return_status = 'S') THEN
        write_log_message('SUCCESS');
      END IF;
  
    EXCEPTION
      WHEN OTHERS THEN
        write_log_message('Exception in API');
    END;
  END process_uda;
  */
  /******************************************************************************************************************************************
   * Type                : Procedure                                                                                                         *
   * Conversion Name     :                                                                                                                   *
   * Name                : process_uda                                                                                              *
   * Script Name         : xxhz_api_pkg.pkb                                                                                          *
   *                                                                                                                                         *
                                                                                                                                             *                                                                                                                                            *
   * Purpose             : This Procedure is Used to Update UDA information in S3 Environment                                                *
                                                                                                                                             *
   * HISTORY                                                                                                                                 *
   * =======                                                                                                                                 *
   * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                     *
   * -------  ----------- ---------------    ------------------------------------                                                            *
  * 1.00     11/05/2016  Somnath Dawn                Initial version                                                                                      *
   ******************************************************************************************************************************************/

  /*PROCEDURE insert_acc_sfid_uda(p_cust_account_id IN NUMBER,
                                p_acc_sfid        IN VARCHAR2,
                                p_return_status   OUT VARCHAR2,
                                p_error_msg       OUT VARCHAR2) IS
    l_user_attr_data_table    ego_user_attr_data_table;
    l_user_attr_row_table     ego_user_attr_row_table;
    l_application_id          NUMBER := 0;
    l_attr_group_id           NUMBER := 0;
    l_errorcode               NUMBER := 0;
    l_msg_count               NUMBER;
    l_return_status           VARCHAR2(100);
    l_msg_data                VARCHAR2(2000);
    l_failed_row_id_list      VARCHAR2(10000);
    l_organization_profile_id NUMBER;
    x_return_status           VARCHAR2(10);
    x_msg_data                VARCHAR2(1000);
    l_errors_tbl              error_handler.error_tbl_type;
  
  BEGIN
    write_log_message('Program Entered : xxhz_soa_api_pkg. Procedure');
    p_return_status := 'S';
    ----------------------
    -- Get Application Id
    -----------------------
    BEGIN
      SELECT application_id
      INTO   l_application_id
      FROM   apps.fnd_application
      WHERE  application_short_name = 'AR'; -- This requires AR application id
  
      write_log_message('application_id = ' || l_application_id);
  
    EXCEPTION
      WHEN no_data_found THEN
        write_log_message('No Data Found While Fetching Application ID');
      WHEN OTHERS THEN
        write_log_message('An Unexpected Error Occured While Fetching The Application ID');
    END;
  
    ---------------------------
    -- Get Profile Id
    ---------------------------
    BEGIN
  
      SELECT hop.organization_profile_id
      INTO   l_organization_profile_id
      FROM   hz_organization_profiles hop,
             hz_cust_accounts_all     hca
      WHERE  hca.party_id = hop.party_id
      AND    hop.effective_end_date IS NULL
      AND    hca.cust_account_id = p_cust_account_id;
  
      write_log_message('ORGANIZATION_PROFILE_ID = ' ||
                           l_organization_profile_id);
  
    EXCEPTION
      WHEN no_data_found THEN
        write_log_message('No Data Found While Fetching ORGANIZATION_PROFILE_ID');
  
      WHEN OTHERS THEN
        write_log_message('An Unexpected Error Occured While Fetching The ORGANIZATION_PROFILE_ID');
    END;
  
    ---------------------------------------------------------------
    -- Finding the Attribute Group Id for Customer Information DFF.
    ---------------------------------------------------------------
  
    SELECT DISTINCT a.attr_group_id
    INTO   l_attr_group_id
    FROM   ego_attr_groups_v a
    WHERE  a.attr_group_name = 'XXSSYS_IMC_CUST_ADDL_INFO' -- This is attribute group internal name - this will be unchanged till production
    AND    a.attr_group_type = 'HZ_ORG_PROFILES_GROUP'; -- Remains unchanged
  
    write_log_message('attr_group_id=' || l_attr_group_id);
  
    l_user_attr_row_table := ego_user_attr_row_table(ego_user_attr_row_obj(1,
                                                                           l_attr_group_id,
                                                                           l_application_id,
                                                                           'HZ_ORG_PROFILES_GROUP',
                                                                           'XXSSYS_IMC_CUST_ADDL_INFO',
                                                                           NULL,
                                                                           NULL,
                                                                           NULL,
                                                                           NULL,
                                                                           NULL,
                                                                           NULL,
                                                                           ego_user_attrs_data_pvt.g_sync_mode));
  
    l_user_attr_data_table := ego_user_attr_data_table(ego_user_attr_data_obj(1,
                                                                              'XXSSYS_IMC_SFDC_ACCT_ID',
                                                                              p_acc_sfid,
                                                                              NULL,
                                                                              NULL,
                                                                              NULL,
                                                                              NULL,
                                                                              NULL));
  
    BEGIN
      -- Calling the API to Process Org Records
      hz_extensibility_pub.process_organization_record(p_api_version           => 1.0,
                                                       p_org_profile_id        => l_organization_profile_id,
                                                       p_attributes_row_table  => l_user_attr_row_table,
                                                       p_attributes_data_table => l_user_attr_data_table,
                                                       p_debug_level           => 3,
                                                       p_commit                => fnd_api.g_true,
                                                       x_failed_row_id_list    => l_failed_row_id_list,
                                                       x_return_status         => l_return_status,
                                                       x_errorcode             => l_errorcode,
                                                       x_msg_count             => l_msg_count,
                                                       x_msg_data              => l_msg_data);
      p_error_msg := l_msg_data;
  
      IF (length(l_failed_row_id_list) > 0) THEN
        BEGIN
          error_handler.get_message_list(l_errors_tbl);
          FOR i IN 1 .. l_errors_tbl.count LOOP
            l_msg_data := l_errors_tbl(i).message_text;
            write_log_message('ERROR in Account SF=' || l_msg_data);
          END LOOP;
        END;
  
      ELSIF (l_return_status = 'S') THEN
        write_log_message('SUCCESS');
      END IF;
  
    EXCEPTION
      WHEN OTHERS THEN
        write_log_message('Exception in API');
    END;
  END insert_acc_sfid_uda;*/

  /******************************************************************************************************************************************
   * Type                : Procedure                                                                                                         *
   * Conversion Name     :                                                                                                                   *
   * Name                : process_uda                                                                                              *
   * Script Name         : xxhz_api_pkg.pkb                                                                                          *
   *                                                                                                                                         *
                                                                                                                                             *                                                                                                                                            *
   * Purpose             : This Procedure is Used to Update UDA information in S3 Environment                                                *
                                                                                                                                             *
   * HISTORY                                                                                                                                 *
   * =======                                                                                                                                 *
   * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                     *
   * -------  ----------- ---------------    ------------------------------------                                                            *
  * 1.00     11/05/2016  Somnath Dawn                Initial version                                                                                      *
   ******************************************************************************************************************************************/

  /*PROCEDURE insert_site_sfid_uda(p_cust_acc_site_id IN NUMBER,
                                 p_site_sfid        IN VARCHAR2,
                                 p_return_status    OUT VARCHAR2,
                                 p_error_msg        OUT VARCHAR2) IS
    l_user_attr_data_table    ego_user_attr_data_table;
    l_user_attr_row_table     ego_user_attr_row_table;
    l_application_id          NUMBER := 0;
    l_attr_group_id           NUMBER := 0;
    l_errorcode               NUMBER := 0;
    l_msg_count               NUMBER;
    l_return_status           VARCHAR2(100);
    l_msg_data                VARCHAR2(2000);
    l_failed_row_id_list      VARCHAR2(10000);
    l_organization_profile_id NUMBER;
    x_return_status           VARCHAR2(10);
    x_msg_data                VARCHAR2(1000);
    l_errors_tbl              error_handler.error_tbl_type;
    l_org_id                  NUMBER;
    l_s3_party_site_id        NUMBER;
  
  BEGIN
   write_log_message('Program Entered : xxhz_soa_api_pkg. Procedure');
    ----------------------
    -- Get Application Id
    -----------------------
    BEGIN
      SELECT application_id
      INTO   l_application_id
      FROM   apps.fnd_application
      WHERE  application_short_name = 'AR'; -- This requires AR application id
  
      write_log_message('application_id = ' || l_application_id);
  
    EXCEPTION
      WHEN no_data_found THEN
        write_log_message('No Data Found While Fetching Application ID');
      WHEN OTHERS THEN
        write_log_message('An Unexpected Error Occured While Fetching The Application ID');
    END;
  
    ---------------------------
    -- Get Party Site Id
    ---------------------------
    BEGIN
  
      SELECT party_site_id,
             org_id
      INTO   l_s3_party_site_id,
             l_org_id
      FROM   hz_cust_acct_sites_all
      WHERE  cust_acct_site_id = p_cust_acc_site_id;
  
      write_log_message('ORGANIZATION_PROFILE_ID = ' ||
                           l_organization_profile_id);
  
    EXCEPTION
      WHEN no_data_found THEN
        write_log_message('No Data Found While Fetching ORGANIZATION_PROFILE_ID');
  
      WHEN OTHERS THEN
        write_log_message('An Unexpected Error Occured While Fetching The ORGANIZATION_PROFILE_ID');
    END;
    ---------------------------------------------------------------
    -- Finding the Attribute Group Id
    ---------------------------------------------------------------
  
    BEGIN
      SELECT DISTINCT a.attr_group_id
      INTO   l_attr_group_id
      FROM   ego_attr_groups_v a
      WHERE  a.attr_group_name = 'XXSSYS_IMC_SITE_INFO'
      AND    a.attr_group_type = 'HZ_PARTY_SITES_GROUP';
    END;
  
    write_log_message('attr_group_id=' || l_attr_group_id);
  
    l_user_attr_row_table := ego_user_attr_row_table(ego_user_attr_row_obj(1 --ROW_IDENTIFIER - IDENTIFIES THE ROW NUMBER WITHIN THE TABLE
                                                                          ,
                                                                           l_attr_group_id --ATTR_GROUP_ID
                                                                          ,
                                                                           l_application_id --ATTR_GROUP_APP_ID
                                                                          ,
                                                                           'HZ_PARTY_SITES_GROUP' --r_get_cust_info.attr_group_type   --ATTR_GROUP_TYPE
                                                                          ,
                                                                           'XXSSYS_IMC_SITE_INFO' --r_get_cust_info.attr_group1_name  --ATTR_GROUP_NAME
                                                                          ,
                                                                           NULL,
                                                                           NULL --DATA_LEVEL_1
                                                                          ,
                                                                           NULL --DATA_LEVEL_2
                                                                          ,
                                                                           NULL --DATA_LEVEL_3
                                                                          ,
                                                                           NULL,
                                                                           NULL,
                                                                           ego_user_attrs_data_pvt.g_sync_mode --TRANSACTION_TYPE ( THIS CONTROL THE MODE(CREATE/UPDATE/DELETE)
                                                                           ));
  
    l_user_attr_data_table := ego_user_attr_data_table(ego_user_attr_data_obj(1,
                                                                              'XXSSYS_IMC_OPERATING_UNIT',
                                                                              to_char(l_org_id) --CHANGE THE VALUE HERE
                                                                             ,
                                                                              NULL --CHANGE THE VALUE HERE
                                                                             ,
                                                                              NULL,
                                                                              NULL --CHANGE THE VALUE HERE
                                                                             ,
                                                                              NULL,
                                                                              NULL),
  
                                                       ego_user_attr_data_obj(1,
                                                                              'XXSSYS_IMC_SFDC_ID',
                                                                              p_site_sfid --CHANGE THE VALUE HERE
                                                                             ,
                                                                              NULL --CHANGE THE VALUE HERE
                                                                             ,
                                                                              NULL,
                                                                              NULL --CHANGE THE VALUE HERE
                                                                             ,
                                                                              NULL,
                                                                              NULL));
  
    BEGIN
      -- Calling the API
      hz_extensibility_pub.process_partysite_record(p_api_version           => 1.0,
                                                    p_party_site_id         => l_s3_party_site_id,
                                                    p_attributes_row_table  => l_user_attr_row_table,
                                                    p_attributes_data_table => l_user_attr_data_table,
                                                    p_debug_level           => 3,
                                                    p_commit                => fnd_api.g_true,
                                                    x_failed_row_id_list    => l_failed_row_id_list,
                                                    x_return_status         => l_return_status,
                                                    x_errorcode             => l_errorcode,
                                                    x_msg_count             => l_msg_count,
                                                    x_msg_data              => l_msg_data);
      p_error_msg := l_msg_data;
  
      IF (length(l_failed_row_id_list) > 0) THEN
        BEGIN
          error_handler.get_message_list(l_errors_tbl);
  
          FOR i IN 1 .. l_errors_tbl.count LOOP
                      l_msg_data := l_errors_tbl(i).message_text;
                      write_log_message('ERROR in Site SF=' || l_msg_data);
          END LOOP;
        END;
  
      ELSIF (l_return_status = 'S') THEN
        write_log_message('SUCCESS');
  
      END IF;
  
    EXCEPTION
      WHEN OTHERS THEN
        write_log_message('Exception in API');
    END;
  END insert_site_sfid_uda;*/

  /******************************************************************************************************************************************
   * Type                : Procedure                                                                                                         *
   * Conversion Name     :                                                                                                                   *
   * Name                : initialize_apps                                                                                              *
   * Script Name         : xxhz_api_pkg.pkb                                                                                          *
   *                                                                                                                                         *
                                                                                                                                             *                                                                                                                                            *
   * Purpose             : This Procedure is Used for apps initialization                                              *
                                                                                                                                             *
   * HISTORY                                                                                                                                 *
   * =======                                                                                                                                 *
   * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                     *
   * -------  ----------- ---------------    ------------------------------------                                                            *
  * 1.00     11/05/2016  Somnath Dawn                Initial version                                                                                      *
   ******************************************************************************************************************************************/
  PROCEDURE initialize_apps(p_user_id           IN NUMBER,
		    p_application_id    IN NUMBER,
		    p_responsibility_id IN NUMBER) IS
  BEGIN
    write_log_message('**Program Entered : xxhz_soa_api_pkg.initialize_apps Procedure',
	          'Y');
  
    fnd_global.apps_initialize(user_id      => p_user_id,
		       resp_id      => p_responsibility_id,
		       resp_appl_id => p_application_id);
  
    write_log_message('**Program Exited : xxhz_soa_api_pkg.initialize_apps Procedure');
  END initialize_apps;
  /******************************************************************************************************************
    * Type                : Procedure                                                                                 *
    * Name                : get_usa_state_code_or_name                                                                         *
    * Input Parameters    :                                                                                           *
    * Purpose             : This procedure is used for getting USA State Code and Name                                         *
    ******************************************************************************************************************
    * HISTORY                                                                                                                                 *
    * =======                                                                                                                                 *
    * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
    * -------  ----------- ---------------    ------------------------------------                                                               *
    *  1.00    27/06/2017  Lingaraj Sarangi   Initial version
    *
    *****************************************************************************************************************************************
  */
  PROCEDURE get_usa_state_code_or_name(p_state_name IN OUT VARCHAR2,
			   p_state_code IN OUT VARCHAR2,
			   x_api_status OUT VARCHAR2,
			   x_error_msg  OUT VARCHAR2) IS
  BEGIN
    x_api_status := fnd_api.g_ret_sts_success;
    IF p_state_name IS NOT NULL OR p_state_code IS NOT NULL THEN
    
      SELECT lookup_code,
	 meaning
      INTO   p_state_code,
	 p_state_name
      FROM   fnd_common_lookups
      WHERE  lookup_type = 'US_STATE'
      AND    upper(meaning) = upper(nvl(p_state_name, meaning))
      AND    lookup_code = nvl(p_state_code, lookup_code);
    
    END IF;
  EXCEPTION
    WHEN no_data_found THEN
      x_api_status := fnd_api.g_ret_sts_error;
      x_error_msg  := 'No State Name or Code found for State Name :' ||
	          p_state_name || ' And State Code :' || p_state_code;
  END get_usa_state_code_or_name;

  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *                                                                                                *
  * Name                : submit_DQM_program                                                                                                *                                                                                                                            *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will  submit program "DQM Synchronization Program" automatically
                          which will run from responsibilty ??Trading Community Manager ?? with  User SCHEDULER .
                           only after  Account interface is completed sucessfully
  
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.0     03/11/2017  Piyali Bhowmick                Initial version
                                              CHG0041658- Submit the program DQM Synchronization Program
                                              automatically after SF interface complete                                                                                    *
  ******************************************************************************************************************************************/

  PROCEDURE submit_dqm_program(errbuf             OUT NOCOPY VARCHAR2,
		       retcode            OUT NOCOPY VARCHAR2,
		       p_soa_reference_id IN NUMBER) IS
  
    l_user_id    NUMBER;
    l_resp_id    NUMBER;
    l_appl_id    NUMBER;
    l_request_id NUMBER;
  
  BEGIN
  
    retcode := 0;
    errbuf  := NULL;
  
    SELECT frt.responsibility_id,
           frt.application_id,
           fu.user_id
    INTO   l_resp_id,
           l_appl_id,
           l_user_id
    FROM   fnd_responsibility_tl frt,
           fnd_user              fu
    WHERE  frt.responsibility_name = 'Trading Community Manager'
    AND    frt.language = 'US'
    AND    fu.user_name = 'SCHEDULER';
  
    fnd_global.apps_initialize(user_id      => l_user_id,
		       resp_id      => l_resp_id,
		       resp_appl_id => l_appl_id);
  
    --Submitting Concurrent Request
  
    l_request_id := fnd_request.submit_request(application => 'AR', -- Application Short Name
			           program     => 'ARHDQSYN', -- Program Short Name
			           description => 'DQM Synchronization Program', -- Any Meaningful Description
			           start_time  => SYSDATE, -- Start Time
			           sub_request => FALSE, -- Subrequest Default False
			           argument1   => NULL,
			           argument2   => NULL);
  
    COMMIT;
  
    IF l_request_id = 0 THEN
    
      xxobjt_wf_mail.send_mail_text(p_to_role     => 'SYSADMIN',
			p_subject     => 'SOA Upsert Account failure Flow Id='||p_soa_reference_id,
			p_body_text   => 'Error submit DQM Synchronization Program , Flow Id= soa_reference_id  ' ||
				     p_soa_reference_id ||
				     chr(10) ||
				     fnd_message.get,
			p_err_code    => retcode,
			p_err_message => errbuf);
    
    ELSIF l_request_id > 0 THEN
    
      errbuf := 'Successfully Submitted the Concurrent Request: ' ||
	    l_request_id;
    END IF;
  
  EXCEPTION
  
    WHEN OTHERS THEN
    
      retcode := 2;
      errbuf  := SQLERRM;
    
  END submit_dqm_program;
END xxhz_soa_api_pkg;
/
