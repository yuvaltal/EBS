create or replace package body xxcust_document_submitter_pkg
-- =========================================================================================
-- Copyright(c) :
-- Application  : Custom Application
-- -----------------------------------------------------------------------------------------
-- Program name                             Creation Date    Original Ver    Created by
-- XXCUST_DOCUMENT_SUBMITTER_PKG            29-Dec-2016      1.0             Saugata
-- -----------------------------------------------------------------------------------------
-- Usage: This will be used as main package for form "Auto Submit Docs" . This is the
-- package body.
-- -----------------------------------------------------------------------------------------
-- Description: This is package body. This will be used as main package for
--                  form "Auto Submit Docs" .
-- CR#          : CHG0039163
-- Parameter    : Written in each procedure section.
-- Return value : Written in each procedure section.
-- -----------------------------------------------------------------------------------------
-- Modification History:
-- Modified Date          Version        Done by               Change Description
-- 29-Dec-2016            1.0            Saugata(TCS)           Initial Build: CHG0039163
-- 19-Feb-2017            1.1            Lingaraj.Sarangi(TCS)  Initial Build: CHG0039163
-- 18-May-2017            1.2            Lingaraj.Sarangi(TCS)  INC0093012 - XX CUST Document Submitter  - Increase timeout
-- 27-AUG-2018            1.3            Roman W.               CHG0043434 - Sync documents from Oracle to salesforce 
-- =========================================================================================
 IS
  -- ===========================================================================
  --                     Global Variable Declaration Start
  -- ===========================================================================
  g_last_updated_by   NUMBER := fnd_global.user_id;
  g_last_update_login NUMBER := fnd_global.conc_login_id;
  g_last_update_date  DATE := SYSDATE;
  g_org_id            NUMBER := fnd_global.org_id;
  g_created_by        NUMBER := fnd_global.user_id;
  g_creation_date     DATE := SYSDATE;
  g_request_id        NUMBER := fnd_global.conc_request_id;
  g_err_msg           VARCHAR2(4000);
  g_skip_to_next_prg  VARCHAR2(3) := 'YES';
  g_err_email_body    VARCHAR2(2000) := '';
  --Below will hold Body Header
  g_err_email_body_H VARCHAR2(1000) := '<HTML>
	<p>Hello,</p>
	<p>The following concurrent Program Failed During execution.Detail information provided Below.</p>
    <TABLE cellpadding="5"  style="color:blue" BORDER =1 >
        <TR>
		    <TH>Request Id</TH>
			<TH>Concurrent Program Short Name</TH>
            <TH>Concurrent Program Name</TH>
			<TH>Key</TH>
			<TH>Operating Unit</TH>
			<TH>Org Id</TH>
			<TH>Set Code</TH>
			<TH>Application Short Name</TH>
			<TH>Template Code</TH>
			<TH>Export Folder</TH>
			<TH>Export File Name</TH>
			<TH>Output Type</TH>
		</TR>';

  --------------------------------------------------------------------
  --  customization code: CHG0039163
  --  name:               log_submitt
  --  create by:          Saugata(TCS)
  --  Revision:           1.0
  --  creation date:      29-Dec-2016
  --  Purpose :           This will Procedure will help to  Print Log messages
  ----------------------------------------------------------------------
  --  ver   date          name             desc
  --  1.0   29-Dec-2016   Saugata(TCS)     Initial Build: CHG0039163
  ----------------------------------------------------------------------
  PROCEDURE log_message(p_msg VARCHAR2) IS
  BEGIN
    IF fnd_global.conc_request_id = -1 THEN
      dbms_output.put_line(p_msg);
    ELSE
      fnd_file.put_line(fnd_file.log, p_msg);
    END IF;
  Exception
    When Others Then
      IF fnd_global.conc_request_id = -1 THEN
        dbms_output.put_line('There is an Error in Printing log Messages.');
      ELSE
        fnd_file.put_line(fnd_file.log,
                          'There is an Error in Printing log Messages.');
      END IF;
  END log_message;
  --------------------------------------------------------------------
  --  customization code: CHG0039163
  --  name:               wait_for_request_completion
  --  create by:          Lingaraj.Sarangi(TCS)
  --  Revision:           1.0
  --  creation date:      19-Feb-2017
  --  Purpose :           Wait to Complete the Concurrent program
  --  Return :            After Completion Return Dev Status , Dev Phase, and message Returned
  ----------------------------------------------------------------------
  --  ver   date          name                desc
  --  1.0   19-Feb-2017   Lingaraj(TCS)       Initial Build: CHG0039163
  ----------------------------------------------------------------------
  PROCEDURE wait_for_request_completion(p_request_id IN NUMBER,
                                        p_dev_phase  OUT VARCHAR2,
                                        p_dev_status OUT VARCHAR2,
                                        p_message    OUT VARCHAR2,
                                        p_max_wait   IN NUMBER DEFAULT 600) IS
    l_complete BOOLEAN;
    l_phase    VARCHAR2(100);
    l_status   VARCHAR2(100);
  BEGIN
    log_message('');
    log_message('       Program Entered - xxcust_document_submitter_pkg.wait_for_request_completion Procedure');
    IF nvl(p_request_id, 0) > 0 THEN
      -- Wait for completion
      l_complete := fnd_concurrent.wait_for_request(request_id => p_request_id,
                                                    interval   => 2,
                                                    max_wait   => p_max_wait, --600,
                                                    phase      => l_phase,
                                                    status     => l_status,
                                                    dev_phase  => p_dev_phase,
                                                    dev_status => p_dev_status,
                                                    message    => p_message);
      Commit;
    ELSE
      log_message('          p_request_id is Null or Zero');
    END IF;
    log_message('          Request Id :' || p_request_id ||
                ' Completed with Status:' || p_dev_phase);
    log_message('       Program Exited  - xxcust_document_submitter_pkg.wait_for_request_completion Procedure');
  Exception
    When Others Then
      log_message('       Program Exited  - xxcust_document_submitter_pkg.wait_for_request_completion Procedure with Error :' ||
                  sqlerrm);
  END wait_for_request_completion;
  --------------------------------------------------------------------
  --  customization code: CHG0039163
  --  name:               send_error_log_to_admin
  --  create by:          Lingaraj.Sarangi(TCS)
  --  Revision:           1.0
  --  creation date:      19-Feb-2017
  --  Purpose :           Work Flow Email to the Users with the Detail Error
  --  Return :            After Completion Return Dev Status , Dev Phase, and message
  ----------------------------------------------------------------------
  --  ver   date          name                desc
  --  1.0   19-Feb-2017   Lingaraj(TCS)       Initial Build: CHG0039163
  ----------------------------------------------------------------------
  Procedure send_error_log_to_admin(p_request_id NUMBER,
                                    p_user_email VARCHAR2,
                                    p_cc_list    VARCHAR2,
                                    p_set_code   VARCHAR2,
                                    p_key        VARCHAR2) IS
    l_admin_user     VARCHAR2(100);
    l_err_email_body VARCHAR2(4000) := (g_err_email_body_H ||
                                       g_err_email_body);
    l_err_code       NUMBER;
    l_err_message    VARCHAR2(2000);
    l_subject        VARCHAR2(100) := 'Error In Auto Submit Document Set :' ||
                                      p_set_code || ' ,For Key: ' || p_key;
  BEGIN
    log_message('');
    log_message('       Program Entered - xxcust_document_submitter_pkg.Send_error_log_to_Admin Procudure');
  
    log_message(' EMAIL ROLE :' || p_user_email);
    log_message(' CC to :' || p_cc_list);
  
    --Send HTML to the Admin User
    xxobjt_wf_mail.send_mail_html(p_to_role     => p_user_email,
                                  p_cc_mail     => p_cc_list,
                                  p_subject     => l_subject,
                                  p_body_html   => l_err_email_body,
                                  p_err_code    => l_err_code,
                                  p_err_message => l_err_message);
    IF l_err_code <> 0 THEN
      log_message('        Error in Mail Send :' || l_err_message);
    END IF;
  
    log_message('       Program Exited  - xxcust_document_submitter_pkg.Send_error_log_to_Admin  Procudure');
  Exception
    When Others Then
      log_message('       Program Exited  - xxcust_document_submitter_pkg.Send_error_log_to_Admin  Procudure with Error :' ||
                  SQLERRM);
  END send_error_log_to_admin;

  --------------------------------------------------------------------
  --  customization code: CHG0039163
  --  name:               is_valid_user
  --  create by:          Lingaraj.Sarangi(TCS)
  --  Revision:           1.0
  --  creation date:      19-Feb-2017
  --  Purpose :           Is the Provided User is a Active User
  --  Return :            BOOLEAN
  ----------------------------------------------------------------------
  --  ver   date          name                desc
  --  1.0   19-Feb-2017   Lingaraj(TCS)       Initial Build: CHG0039163
  ----------------------------------------------------------------------
  Function is_valid_user(p_user_name VARCHAR2) Return BOOLEAN IS
    l_user_id NUMBER;
  BEGIN
    Select user_id
      into l_user_id
      from fnd_user
     where user_name = p_user_name
       and trunc(sysdate) between Start_Date and
           nvl(end_date, trunc(sysdate));
    Return TRUE;
  Exception
    When No_Data_Found Then
      Return FALSE;
    When Others Then
      Return FALSE;
  END is_valid_user;
  --------------------------------------------------------------------
  --  customization code: CHG0039163
  --  name:               build_err_email_body
  --  create by:          Lingaraj.Sarangi(TCS)
  --  Revision:           1.0
  --  creation date:      19-Feb-2017
  --  Purpose :           Build Error Email Body with the information Received and Call Send Email
  ----------------------------------------------------------------------
  --  ver   date          name                desc
  --  1.0   19-Feb-2017   Lingaraj(TCS)       Initial Build: CHG0039163
  ----------------------------------------------------------------------
  procedure build_err_email_body(p_request_id         NUMBER,
                                 p_key                VARCHAR2,
                                 p_org_id             NUMBER,
                                 p_set_code           VARCHAR2,
                                 p_program_short_name VARCHAR2,
                                 p_user_program_name  VARCHAR2,
                                 p_appl_short_name    VARCHAR2,
                                 p_template_code      VARCHAR2,
                                 p_export_folder      VARCHAR2,
                                 p_export_file_name   VARCHAR2,
                                 p_output_type        VARCHAR2,
                                 p_exp_error          VARCHAR2 DEFAULT NULL,
                                 p_admin_user         VARCHAR2,
                                 p_cc_to_email        VARCHAR2) IS
    l_completion_text VARCHAR2(4000);
    l_ou_name         VARCHAR2(100);
  BEGIN
    g_err_email_body := '';
  
    Begin
      Select ORGANIZATION
        into l_ou_name
        from XXHR_OPERATING_UNITS_V
       where org_id = p_org_id;
      select completion_text
        into l_completion_text
        from fnd_concurrent_requests
       where request_id = p_request_id;
    Exception
      When Others Then
        Null;
    End;
  
    g_err_email_body := '<TR>
                        <TD>' || p_request_id ||
                        '</TD>
                        <TD>' || p_program_short_name ||
                        '</TD>
                        <TD>' || p_user_program_name ||
                        '</TD>
                        <TD>' || p_key ||
                        '</TD>
                        <TD>' || l_ou_name ||
                        '</TD>
                        <TD>' || p_org_id ||
                        '</TD>
                        <TD>' || p_set_code ||
                        '</TD>
                        <TD>' || p_appl_short_name ||
                        '</TD>
                        <TD>' || p_template_code ||
                        '</TD>
                        <TD>' || p_export_folder ||
                        '</TD>
                        <TD>' || p_export_file_name ||
                        '</TD>
                        <TD>' || p_output_type ||
                        '</TD>
                    </TR>
                </TABLE>
                <p>Please Review the Concurrent Log of Request Id :' ||
                        g_request_id || ' for detail information.</p>' ||
                        '<P style="color:red;font-weight:bold;font-size:20">' ||
                        (CASE
                          WHEN p_request_id IS NOT NULL THEN
                           'Program Completed with Completion Text :' ||
                           l_completion_text
                          ELSE
                           ''
                        END) || '</p>' ||
                        '<p style="color:red;font-weight:bold;font-size:20">' ||
                        nvl(p_exp_error, '') || '</p>' || '<p>Good day,</p>
                <p>This is an automated e-mail from Oracle system.</p>
                <p>Tech Info: xxcust_document_submitter_pkg Package</p>
            </HTML>';
  
    --Send Mail.
    Send_error_log_to_Admin(p_request_id => p_request_id,
                            p_user_email => p_admin_user,
                            p_cc_list    => p_cc_to_email,
                            p_set_code   => p_set_code,
                            p_key        => p_key);
  
  END build_err_email_body;
  --------------------------------------------------------------------
  --  customization code: CHG0039163
  --  name:               submit_document_set
  --  create by:          Lingaraj.Sarangi(TCS)
  --  Revision:           1.0
  --  creation date:      19-Feb-2017
  --  Purpose :           This is the Main Program Called by Concurrnt Program and GTMS Package
  --                      Called from the GTMS Package 'XXWSH_GTMS_SEND_SHIP_DOCS_PKG'
  ----------------------------------------------------------------------
  --  ver   date          name                desc
  --  1.0   19-Feb-2017   Lingaraj(TCS)       Initial Build: CHG0039163
  --  1.1   18-May-2017   Lingaraj(TCS)       INC0093012 - XX CUST Document Submitter  - Increase timeout
  --  1.2   27-AUG-2018   Roman W.            CHG0043434 - Sync documents from Oracle to salesforce 
  ----------------------------------------------------------------------
  PROCEDURE submit_document_set(x_errbuf   OUT VARCHAR2,
                                x_retcode  OUT VARCHAR2,
                                p_set_code IN VARCHAR2,
                                p_org_id   IN NUMBER,
                                p_key      IN VARCHAR2) IS
    ---- Local variable diclaration -Start.
    l_org_id           xx_cust_report_submitter.org_id%TYPE;
    l_set_code         xx_cust_report_submitter.set_code%TYPE;
    l_value1           VARCHAR2(500);
    l_request          NUMBER;
    l_request1         NUMBER;
    l_file_trf_request NUMBER;
    l_req_child        NUMBER;
    l_result           BOOLEAN;
    l_last_att         VARCHAR2(20);
    l_last_att_index   NUMBER;
    l_dev_phase        VARCHAR2(100);
    l_dev_status       VARCHAR2(100);
    l_message          VARCHAR2(100);
    l_count            NUMBER;
    l_file_name        VARCHAR2(1000);
    l_admin_user       VARCHAR2(50);
    -- l_admin_user_email VARCHAR2(100);
    TYPE t_rpt_submtr_param_arr IS TABLE OF VARCHAR2(50) INDEX BY VARCHAR2(20);
    l_cp_exception         VARCHAR2(4000);
    l_rpt_submtr_param_arr t_rpt_submtr_param_arr;
    MAIN_CP_FAILED_TO_SUBMIT      EXCEPTION;
    FILE_COPY_CP_FAILED_TO_SUBMIT EXCEPTION;
    ---- Local variable diclaration -End.
  
    ---- Cursor to fetch data from XX_CUST_REPORT_SUBMITTER table -Start.
    CURSOR cur_rpt_submtr IS
      SELECT xcrs.set_id set_id,
             xcrs.set_code set_code,
             xcrs.org_id org_id,
             xcrs.application_short_name application_short_name,
             xcrs.concurrent_program_name concurrent_program_name,
             (select USER_CONCURRENT_PROGRAM_NAME
                from fnd_concurrent_programs_vl
               where CONCURRENT_PROGRAM_NAME = xcrs.concurrent_program_name
                 and rownum = 1) user_concurrent_program_name,
             xcrs.template_code template_code,
             xcrs.enable_flag enable_flag,
             xcrs.export_folder export_folder,
             xcrs.export_file_name export_file_name,
             xcrs.admin_user admin_user,
             xcrs.cc_mail_recipient_list cc_mail_recipient_list,
             xcrs.template_type_code template_type_code,
             xcrs.default_language default_language,
             xcrs.default_territory default_territory,
             xcrs.output_type output_type,
             xcrs.created_by created_by,
             xcrs.creation_date creation_date,
             xcrs.last_updated_by last_updated_by,
             xcrs.last_update_date last_update_date
        FROM xx_cust_report_submitter xcrs
       WHERE xcrs.set_code = p_set_code
         AND nvl(xcrs.org_id, -1) = nvl(p_org_id, nvl(xcrs.org_id, -1)) -- added by Roman W. CHG0043434
            -- rem by Roman W.        AND   xcrs.org_id = nvl(p_org_id, xcrs.org_id)
         AND nvl(xcrs.enable_flag, 'N') = 'Y';
  
    ---- Cursor to fetch data from XX_CUST_REPORT_SUBMITTER table -End.
  
    ---- Cursor to fetch data from XX_CUST_REPORT_SUBMITTER_PARAM table -Start.
    CURSOR cur_rpt_submtr_param(c_set_id NUMBER) IS
      SELECT xcrsp.set_id              set_id,
             t.application_column_name,
             xcrsp.seq_no              seq_no,
             xcrsp.default_value       default_value,
             xcrsp.created_by          created_by,
             xcrsp.creation_date       creation_date,
             xcrsp.last_updated_by     last_updated_by,
             xcrsp.last_update_date    last_update_date
        FROM xx_cust_report_submitter_param xcrsp,
             fnd_descr_flex_column_usages   t,
             xx_cust_report_submitter       xcrs
       WHERE xcrsp.set_id = c_set_id
         AND xcrs.set_id = xcrsp.set_id
         AND t.descriptive_flexfield_name =
             '$SRS$.' || xcrs.concurrent_program_name
         AND xcrsp.seq_no = t.column_seq_num
       ORDER BY t.column_seq_num;
  
    ---- Cursor to fetch data from XX_CUST_REPORT_SUBMITTER_PARAM table -End.
  BEGIN
    log_message('Program Entered : xxcust_document_submitter_pkg.submit_document_set Procedure');
    log_message('  Input Parameters:');
    log_message('                p_set_code:' || p_set_code);
    log_message('                p_org_id  :' || p_org_id);
    log_message('                p_key     :' || p_key);
  
    x_retcode := 0;
    log_message('');
    log_message('  For Loop Started to run the Program for the Set Code :' ||
                p_set_code);
    FOR i IN cur_rpt_submtr LOOP
      BEGIN
        log_message(' *****************************************************************************************');
        log_message('  Data Processing Started for Concurrent Program :' ||
                    i.user_concurrent_program_name);
        --- 1. Loop Over Table XX_CUST_REPORT_SUBMITTER  -- Start.
        --1.1
        l_last_att       := NULL;
        l_last_att_index := NULL;
        l_request        := NULL;
        l_req_child      := NULL;
        l_value1         := NULL;
        l_result         := NULL;
        l_file_name      := NULL;
        l_admin_user     := NULL;
        --l_admin_user_email:= NULL;
        l_cp_exception := NULL;
      
        l_file_name  := xxcust_document_submitter_pkg.get_dyn_sql_value(i.export_file_name,
                                                                        p_key);
        l_admin_user := xxcust_document_submitter_pkg.get_dyn_sql_value(i.admin_user,
                                                                        p_key);
        log_message('  Export File Name :' || l_file_name);
        log_message('  File Export Folder Path: ' || i.export_folder);
      
        IF NOT (is_valid_user(l_admin_user)) THEN
          log_message(' Admin User Name is Not Valid. Please Provide Valid User Name');
        
        END IF;
      
        FOR i IN 1 .. 30 LOOP
          l_rpt_submtr_param_arr('ATTRIBUTE' || i) := NULL;
        END LOOP;
      
        log_message('  ');
        log_message('  Paremeter Values Set for Concurrent Program :' ||
                    i.user_concurrent_program_name);
        --- 2. Open child cur base on set_id -- Start.
        FOR j IN cur_rpt_submtr_param(i.set_id) LOOP
          -- 2.1 Get default value from field DEFAULT_VALUE (if not null )
          IF j.default_value IS NOT NULL THEN
            l_value1 := NULL;
            l_value1 := xxcust_document_submitter_pkg.get_dyn_sql_value(j.default_value,
                                                                        p_key);
            l_rpt_submtr_param_arr(j.application_column_name) := l_value1;
          
            l_last_att := j.application_column_name;
          END IF;
        
        END LOOP;
        log_message('  Paremeter Values Set for Concurrent Program :' ||
                    i.user_concurrent_program_name ||
                    ' Completed sucessfully.');
        log_message('');
        --
        -- find last empty attribute and assign chr(0) to next parameter;
      
        l_last_att_index := to_number(REPLACE(l_last_att, 'ATTRIBUTE')) + 1;
        l_rpt_submtr_param_arr('ATTRIBUTE' || l_last_att_index) := chr(0);
      
        -- setting  layout
      
        IF i.template_type_code IS NOT NULL THEN
          l_result := fnd_request.add_layout(template_appl_name => i.application_short_name, --'XXAR',
                                             template_code      => i.template_code, --'XXAR_DE_TRX_REP',
                                             template_language  => i.default_language, -- 'en',
                                             template_territory => i.default_territory, --'US', -- 'IL'
                                             output_format      => i.output_type);
          log_message('   Report Layout Template sucessfully Associated with the Program.');
          log_message('   Template Code / Template Language  / Template Territory / Output Type:' ||
                      i.template_code || '/' || i.default_language || '/' ||
                      i.default_territory || '/' || i.output_type);
        END IF;
      
        /* -- set printer
        lb_flag := fnd_request.set_print_options(printer     => v_printer,
                                                     copies      => 1,
                                                     save_output => TRUE);*/
      
        -- 2.2 After inner loop end submitting concurrent program.
        l_request := fnd_request.submit_request(application => i.application_short_name,
                                                program     => i.concurrent_program_name,
                                                start_time  => SYSDATE,
                                                argument1   => l_rpt_submtr_param_arr('ATTRIBUTE1'),
                                                argument2   => l_rpt_submtr_param_arr('ATTRIBUTE2'),
                                                argument3   => l_rpt_submtr_param_arr('ATTRIBUTE3'),
                                                argument4   => l_rpt_submtr_param_arr('ATTRIBUTE4'),
                                                argument5   => l_rpt_submtr_param_arr('ATTRIBUTE5'),
                                                argument6   => l_rpt_submtr_param_arr('ATTRIBUTE6'),
                                                argument7   => l_rpt_submtr_param_arr('ATTRIBUTE7'),
                                                argument8   => l_rpt_submtr_param_arr('ATTRIBUTE8'),
                                                argument9   => l_rpt_submtr_param_arr('ATTRIBUTE9'),
                                                argument10  => l_rpt_submtr_param_arr('ATTRIBUTE10'),
                                                argument11  => l_rpt_submtr_param_arr('ATTRIBUTE11'),
                                                argument12  => l_rpt_submtr_param_arr('ATTRIBUTE12'),
                                                argument13  => l_rpt_submtr_param_arr('ATTRIBUTE13'),
                                                argument14  => l_rpt_submtr_param_arr('ATTRIBUTE14'),
                                                argument15  => l_rpt_submtr_param_arr('ATTRIBUTE15'),
                                                argument16  => l_rpt_submtr_param_arr('ATTRIBUTE16'),
                                                argument17  => l_rpt_submtr_param_arr('ATTRIBUTE17'),
                                                argument18  => l_rpt_submtr_param_arr('ATTRIBUTE18'),
                                                argument19  => l_rpt_submtr_param_arr('ATTRIBUTE19'),
                                                argument20  => l_rpt_submtr_param_arr('ATTRIBUTE20'),
                                                argument21  => l_rpt_submtr_param_arr('ATTRIBUTE21'),
                                                argument22  => l_rpt_submtr_param_arr('ATTRIBUTE22'),
                                                argument23  => l_rpt_submtr_param_arr('ATTRIBUTE23'),
                                                argument24  => l_rpt_submtr_param_arr('ATTRIBUTE24'),
                                                argument25  => l_rpt_submtr_param_arr('ATTRIBUTE25'),
                                                argument26  => l_rpt_submtr_param_arr('ATTRIBUTE26'),
                                                argument27  => l_rpt_submtr_param_arr('ATTRIBUTE27'),
                                                argument28  => l_rpt_submtr_param_arr('ATTRIBUTE28'),
                                                argument29  => l_rpt_submtr_param_arr('ATTRIBUTE29'),
                                                argument30  => l_rpt_submtr_param_arr('ATTRIBUTE30'));
      
        COMMIT;
      
        log_message('  Program Submitted with Request ID : ' || l_request);
      
        IF l_request > 0 THEN
          ---- Wait for Request completion
          --Wait time value added to wait_for_request_completion on 18th May 2017 for INC0093012
          wait_for_request_completion(p_request_id => l_request,
                                      p_dev_phase  => l_dev_phase,
                                      p_dev_status => l_dev_status,
                                      p_message    => l_message,
                                      p_max_wait   => nvl(fnd_profile.VALUE('XXCUST_DOCSUBMITTER_WAIT_SEC'),
                                                          600));
          --COMMIT;
        
          ---- Calling XX: Copy Concurrent Request Output program.
          IF UPPER(l_dev_phase) = 'COMPLETE' AND
             upper(l_dev_status) = 'NORMAL' THEN
            log_message('  The Program SUCCESSFULLY COMPLETED for Request ID : ' ||
                        l_request);
          
            -- Checking whether the request has any child request or not
            -- If child request present seleting that request
          
            BEGIN
              SELECT request_id
                INTO l_req_child
                FROM fnd_concurrent_requests
               WHERE has_sub_request = 'N'
                 AND is_sub_request = 'Y'
                 AND parent_request_id = l_request
                 AND rownum = 1;
              log_message('  Child Request found for request id ' ||
                          l_request);
              log_message('  Child Request Id : ' || l_req_child);
              --If Request Failed But Parent request Completed Sucessfully
              -- Then May required to check the Child Request Status
            EXCEPTION
              WHEN no_data_found THEN
                l_req_child := l_request;
                log_message(' No Child Request found for Parent Request Id:' ||
                            l_request);
            END;
            log_message(' ');
            IF i.export_folder IS NOT NULL AND l_file_name IS NOT NULL THEN
              -- Selection of output file name from dynamic function.
            
              log_message('  File Transfer Process Started for Request Id :' ||
                          l_req_child);
              --l_file_name := xxcust_document_submitter_pkg.get_dyn_sql_value(i.export_file_name,p_key);
              --log_message(' Export File Name                  : '||l_file_name);
            
              -- Useing copy file concurrent program XX: Copy Concurrent Request Output
              l_file_trf_request := fnd_request.submit_request(application => 'XXOBJT',
                                                               program     => 'XXFNDCPCONCOUTPUT',
                                                               start_time  => SYSDATE,
                                                               argument1   => i.concurrent_program_name,
                                                               argument2   => l_req_child,
                                                               argument3   => i.output_type, --'PDF',
                                                               argument4   => i.export_folder,
                                                               argument5   => l_file_name);
              COMMIT;
              IF l_request > 0 THEN
                ---- Wait for Request completion
                l_dev_phase  := NULL;
                l_dev_status := NULL;
                l_message    := NULL;
                wait_for_request_completion(l_file_trf_request,
                                            l_dev_phase,
                                            l_dev_status,
                                            l_message);
              
                --If File Transfer Program Failed, Send Notification to Admin User
                IF --UPPER(l_dev_phase) != 'COMPLETE' OR
                 upper(l_dev_status) != 'NORMAL' THEN
                  log_message('  File Transfer Program Completed abnormally');
                  log_message('  Dev_Phase/ Dev_Status / Message :' ||
                              l_dev_phase || '/' || l_dev_status || '/' ||
                              l_message);
                  build_err_email_body(p_request_id         => l_file_trf_request,
                                       p_key                => p_key,
                                       p_org_id             => i.org_id,
                                       p_set_code           => i.set_code,
                                       p_program_short_name => 'XXFNDCPCONCOUTPUT',
                                       p_user_program_name  => 'XX: Copy Concurrent Request Output',
                                       p_appl_short_name    => 'XXOBJT',
                                       p_template_code      => NULL,
                                       p_export_folder      => i.export_folder,
                                       p_export_file_name   => l_file_name,
                                       p_output_type        => i.output_type,
                                       p_admin_user         => l_admin_user,
                                       p_cc_to_email        => i.cc_mail_recipient_list);
                
                  -- If Any Error Happens then go to the Next Program or Abort the Program Set
                  IF g_skip_to_next_prg = 'NO' THEN
                    EXIT;
                  END IF;
                ELSE
                  log_message('  File Transfer Process Completed Sucessfully for Request Id :' ||
                              l_req_child);
                END IF;
              ELSE
                RAISE FILE_COPY_CP_FAILED_TO_SUBMIT;
              END IF;
            
            ELSE
              log_message('  File Transfer Process SKIPPED because of either Export folder Path or File Name missing for Request Id :' ||
                          l_req_child);
            END IF;
          ELSE
            log_message('  Program Completed abnormally');
            log_message('  Dev_Phase/ Dev_Status / Message :' ||
                        l_dev_phase || '/' || l_dev_status || '/' ||
                        l_message);
          
            build_err_email_body(p_request_id         => l_request,
                                 p_key                => p_key,
                                 p_org_id             => i.org_id,
                                 p_set_code           => i.set_code,
                                 p_program_short_name => i.concurrent_program_name,
                                 p_user_program_name  => i.user_concurrent_program_name,
                                 p_appl_short_name    => i.application_short_name,
                                 p_template_code      => i.template_code,
                                 p_export_folder      => i.export_folder,
                                 p_export_file_name   => l_file_name,
                                 p_output_type        => i.output_type,
                                 p_admin_user         => l_admin_user,
                                 p_cc_to_email        => i.cc_mail_recipient_list);
          
          END IF;
        ELSE
          RAISE MAIN_CP_FAILED_TO_SUBMIT;
        END IF;
        log_message(' *****************************************************************************************');
      EXCEPTION
        WHEN MAIN_CP_FAILED_TO_SUBMIT THEN
          l_cp_exception := 'Main Concurrent Program ' ||
                            i.user_concurrent_program_name ||
                            ' Submission Failed.';
        WHEN FILE_COPY_CP_FAILED_TO_SUBMIT THEN
          l_cp_exception := 'File Copy Concurrent Program ' ||
                            i.user_concurrent_program_name ||
                            ' Submission Failed.';
        WHEN OTHERS THEN
          l_cp_exception := substr(SQLERRM, 1, 3999);
      END;
      IF l_cp_exception IS NOT NULL THEN
        log_message(l_cp_exception);
        build_err_email_body(p_request_id         => l_request,
                             p_key                => p_key,
                             p_org_id             => i.org_id,
                             p_set_code           => i.set_code,
                             p_program_short_name => i.concurrent_program_name,
                             p_user_program_name  => i.user_concurrent_program_name,
                             p_appl_short_name    => i.application_short_name,
                             p_template_code      => i.template_code,
                             p_export_folder      => i.export_folder,
                             p_export_file_name   => l_file_name,
                             p_output_type        => i.output_type,
                             p_exp_error          => l_cp_exception,
                             p_admin_user         => l_admin_user,
                             p_cc_to_email        => i.cc_mail_recipient_list);
      END IF;
    END LOOP;
  
    --- Loop Over Table XX_CUST_REPORT_SUBMITTER  -- End.
    --- 3. Log submission
  
  EXCEPTION
    WHEN OTHERS THEN
      log_message('Unexpected error occured in program, process abort. ' ||
                  SQLERRM);
      x_errbuf  := sqlerrm;
      x_retcode := 2;
  END submit_document_set;

  --------------------------------------------------------------------
  --  customization code: CHG0039163
  --  name:               get_dyn_sql_value
  --  create by:          Saugata(TCS)
  --  Revision:           1.0
  --  creation date:      29-Dec-2016
  --  Purpose :           This is the function which support the dynamic sql.
  --  Return Value:       VRACHAR2
  ----------------------------------------------------------------------
  --  ver   date          name       desc
  --  1.0   29-Dec-2016     Saugata(TCS)    Initial Build: CHG0039163
  ----------------------------------------------------------------------
  FUNCTION get_dyn_sql_value(p_string IN VARCHAR2, p_key IN VARCHAR2)
    RETURN VARCHAR2 IS
  
    l_string     VARCHAR2(2000);
    l_key        VARCHAR2(50);
    l_value      VARCHAR2(2000);
    l_return_val VARCHAR2(2000);
  BEGIN
    log_message('        Program Entered : xxcust_document_submitter_pkg.get_dyn_sql_value Procedure');
    log_message('                Query :' || p_string);
    log_message('                Key   :' || p_key);
  
    l_string := p_string;
    l_key    := p_key;
  
    IF l_string LIKE '%:%' THEN
      EXECUTE IMMEDIATE l_string
        INTO l_value
        USING l_key;
      l_return_val := l_value;
    ELSE
      l_return_val := l_string;
    END IF;
  
    log_message('        Program Exited : xxcust_document_submitter_pkg.get_dyn_sql_value Procedure With value :' ||
                l_return_val);
    Return l_return_val;
    /*Exception
    When Others Then
      log_message('        Program Exited : xxcust_document_submitter_pkg.get_dyn_sql_value Procedure With Error :'||SQLERRM);
      Return NULL; */
  END get_dyn_sql_value;
  --------------------------------------------------------------------
  --  customization code: CHG0039163
  --  name:               validate_sql
  --  create by:          Lingaraj Sarangi
  --  Revision:           1.0
  --  creation date:      19/02/2017
  --  Purpose :           Returns TRUE or FALSE Boolean Value
  --                      This Function will verify that is the Dynamic Query is Correct or Nor.
  --                      Function will be called from XXCUSTREPSET.fmb.
  --  Return Value:     BOLLEAN
  ----------------------------------------------------------------------
  --  ver   date          name                desc
  --  1.0   19/02/2017    Lingaraj Sarangi    Initial Build: CHG0039163
  ----------------------------------------------------------------------
  FUNCTION validate_sql(p_query IN VARCHAR2) RETURN BOOLEAN IS
    l_value VARCHAR2(2000);
  BEGIN
    IF p_query LIKE '%:%' THEN
      BEGIN
        EXECUTE IMMEDIATE p_query
          INTO l_value
          USING '0';
        Return True;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          Return True;
        WHEN OTHERS THEN
          Return False;
      END;
    ELSE
      Return True;
    END IF;
  
  END validate_sql;

END xxcust_document_submitter_pkg;
/
