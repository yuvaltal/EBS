CREATE OR REPLACE PACKAGE xxhz_soa_api_pkg AUTHID CURRENT_USER IS

  -- Author  : Somnath Dawn
  -- Created : 11/05/2016
  -- Purpose :

  -- Purpose : Stratasys SFDC to Oracle Customer Data Transfer
  /******************************************************************************************************************************************
  * Type                : Package                                                                                                          *
  * Conversion Name     : AR_CUSTOMERS                                                                                                     *
  * Name                : xxhz_soa_api_pkg                                                                                           *
  * Script Name         : xxhz_soa_api_pkg.pks                                                                                       *
  * Procedures          :                                                                                 *
                                                                                                                                           *
                                                                                                                                           *
  * Purpose             : This script is used to create Package "XXHZ_SOA_API_PKG" in APPS schema,                                   *
                                                                                *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE         AUTHOR(S)           DESCRIPTION                                                                                   *
  * -------  -----------  ---------------     ---------------------                                                                         *
  * 1.00      11/05/2016  Somnath Dawn        Draft version                                                                                 *
  * 1.1       30/JAN/2017 Adi Safin           CHG0040057 - Change xxcust --> xxobjt
  * 1.2       03/NOV/2017 Piyali Bhowmick     CHG0041658- Submit the program DQM Synchronization Program automatically after SF interface complete                                                                                 *
  * 1.3       13-DEC-2017 Diptasurjya         CHG0042044 - Make API call capmatiable with STRATAFORCE
              7.1.18      yuval tal           add get_territory_org_info to spec                                        *
  * 1.4       12.NOV.18   Llingaraj           CHG0042632 - SFDC2OA - Location - Sites  interface ( upsert and find)
  *                                           Find_match_sites - Logic Updated and Old procedure names as Find_match_sites_old                        
  ******************************************************************************************************************************************/

  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : find_match_accounts                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE find_match_accounts(p_source           IN VARCHAR2,
		        p_accounts_in      IN xxobjt.xxhz_account_match_req_rec,
		        p_accounts_out     OUT xxobjt.xxhz_accounts_match_resp_tab,
		        p_status           OUT VARCHAR2,
		        p_message          OUT VARCHAR2,
		        p_soa_reference_id IN NUMBER);

  ----------------
  PROCEDURE set_my_session( --p_username       IN VARCHAR2,  -- CHG0042044 - Commented Dipta
		   p_source         IN VARCHAR2, -- CHG0042044 - Added Dipta
		   p_status_out     OUT VARCHAR2,
		   p_status_msg_out OUT VARCHAR2);
  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : find_match_sites_old                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *  1.1     12-Nov-2018 Lingaraj           CHG0042632 - SFDC2OA - Location - Sites  interface ( upsert and find)
  *                                         This is Procedure is now Obsolete , Please Use find_match_sites
  ******************************************************************************************************************************************/
  PROCEDURE find_match_sites_old(p_source           IN VARCHAR2,
		         p_sites_in         IN OUT xxobjt.xxhz_site_match_req_rec,
		         p_sites_out        OUT xxobjt.xxhz_site_match_resp_tab,
		         p_status           OUT VARCHAR2,
		         p_message          OUT VARCHAR2,
		         p_soa_reference_id IN NUMBER);

  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : find_match_sites                                                                        *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Sites                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    12-Nov-2018 Lingaraj           CHG0042632 - SFDC2OA - Location - Sites  interface ( upsert and find)
  *
  ******************************************************************************************************************************************/
  PROCEDURE find_match_sites(p_source           IN VARCHAR2,
		     p_sites_in         IN OUT xxobjt.xxhz_site_match_req_rec,
		     p_sites_out        OUT xxobjt.xxhz_site_match_resp_tab,
		     p_status           OUT VARCHAR2,
		     p_message          OUT VARCHAR2,
		     p_soa_reference_id IN NUMBER,
		     p_debug            IN VARCHAR2 DEFAULT 'N');

  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : create_person                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE create_person(p_person_record IN hz_party_v2pub.person_rec_type,
		  p_party_id      OUT NUMBER,
		  p_api_status    OUT VARCHAR2,
		  p_error_msg     OUT VARCHAR2);
  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : update_person                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE update_person(p_person_record IN hz_party_v2pub.person_rec_type,
		  p_obj_version   IN OUT NOCOPY NUMBER,
		  p_api_status    OUT VARCHAR2,
		  p_error_msg     OUT VARCHAR2);

  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : update_organization                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE update_organization(p_organization_record   IN hz_party_v2pub.organization_rec_type,
		        p_party_obj_version_num IN NUMBER,
		        p_api_status            OUT VARCHAR2,
		        p_error_msg             OUT VARCHAR2);
  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : create_location                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE create_location(p_location_record IN OUT hz_location_v2pub.location_rec_type,
		    p_location_id     OUT NUMBER,
		    p_api_status      OUT VARCHAR2,
		    p_error_msg       OUT VARCHAR2);
  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : update_location                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE update_location(p_location_rec          IN OUT hz_location_v2pub.location_rec_type,
		    p_object_version_number IN OUT NOCOPY NUMBER,
		    p_api_status            OUT VARCHAR2,
		    p_error_msg             OUT VARCHAR2);
  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : create_party_site                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  * 1.1      21.03.2017  Lingaraj Sarangi    CHG0040057 - Adding p_party_site_number as Output Parameter                                    *
  ******************************************************************************************************************************************/
  PROCEDURE create_party_site(p_party_site_record IN hz_party_site_v2pub.party_site_rec_type,
		      p_party_site_id     OUT NUMBER,
		      p_party_site_number OUT hz_party_sites.party_site_number%TYPE,
		      p_api_status        OUT VARCHAR2,
		      p_error_msg         OUT VARCHAR2);

  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : upsert_account                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE upsert_account(p_source           IN VARCHAR2,
		   p_soa_reference_id IN NUMBER,
		   p_account_in       IN OUT xxobjt.xxhz_accounts_tab,
		   p_account_out      OUT xxobjt.xxhz_accounts_tab,
		   p_status           OUT VARCHAR2,
		   p_message          OUT VARCHAR2);
  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : upsert_contact                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE upsert_contact(p_source           IN VARCHAR2,
		   p_soa_reference_id IN NUMBER,
		   p_contacts_in      IN OUT xxobjt.xxhz_contact_tab,
		   p_contacts_out     OUT xxobjt.xxhz_contact_tab,
		   p_status           OUT VARCHAR2,
		   p_message          OUT VARCHAR2);
  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : upsert_sites                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE upsert_sites(p_source           IN VARCHAR2,
		 p_soa_reference_id IN NUMBER,
		 p_sites_in         IN OUT xxobjt.xxhz_site_tab,
		 p_sites_out        OUT xxobjt.xxhz_site_tab,
		 p_status           OUT VARCHAR2,
		 p_message          OUT VARCHAR2);
  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : create_account                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE create_account(p_org_record          IN hz_party_v2pub.organization_rec_type,
		   p_cust_account_record IN hz_cust_account_v2pub.cust_account_rec_type,
		   p_cust_prof_record    IN hz_customer_profile_v2pub.customer_profile_rec_type,
		   p_cust_account_id     OUT NUMBER,
		   p_party_id            OUT NUMBER,
		   p_api_status          OUT VARCHAR2,
		   p_error_msg           OUT VARCHAR2);

  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : update_account                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE update_account(p_cust_account_record IN hz_cust_account_v2pub.cust_account_rec_type,
		   p_cust_prof_record    IN hz_customer_profile_v2pub.customer_profile_rec_type,
		   p_api_status          OUT VARCHAR2,
		   p_error_msg           OUT VARCHAR2);

  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : create_contact_point                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE create_contact_point(p_contact_point_record IN hz_contact_point_v2pub.contact_point_rec_type,
		         p_edi_record           IN hz_contact_point_v2pub.edi_rec_type DEFAULT NULL,
		         p_email_record         IN hz_contact_point_v2pub.email_rec_type DEFAULT NULL,
		         p_phone_record         IN hz_contact_point_v2pub.phone_rec_type DEFAULT NULL,
		         p_telex_record         IN hz_contact_point_v2pub.telex_rec_type DEFAULT NULL,
		         p_web_record           IN hz_contact_point_v2pub.web_rec_type DEFAULT NULL,
		         p_api_status           OUT VARCHAR2,
		         p_error_msg            OUT VARCHAR2,
		         p_contact_point_id     OUT NUMBER);
  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : update_contact_point                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE update_contact_point(p_contact_point_record IN hz_contact_point_v2pub.contact_point_rec_type,
		         p_edi_record           IN hz_contact_point_v2pub.edi_rec_type DEFAULT NULL,
		         p_email_record         IN hz_contact_point_v2pub.email_rec_type DEFAULT NULL,
		         p_phone_record         IN hz_contact_point_v2pub.phone_rec_type DEFAULT NULL,
		         p_telex_record         IN hz_contact_point_v2pub.telex_rec_type DEFAULT NULL,
		         p_web_record           IN hz_contact_point_v2pub.web_rec_type DEFAULT NULL,
		         p_obj_version          IN NUMBER,
		         p_api_status           OUT VARCHAR2,
		         p_error_msg            OUT VARCHAR2);
  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : create_contact                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE create_contact(p_contact_record        IN hz_party_contact_v2pub.org_contact_rec_type,
		   p_relationship_party_id OUT VARCHAR2,
		   p_org_contact_id        OUT NUMBER,
		   p_api_status            OUT VARCHAR2,
		   p_error_msg             OUT VARCHAR2);
  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : update_contact                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE update_contact(p_contact_record           IN hz_party_contact_v2pub.org_contact_rec_type,
		   p_contact_obj_version_num  IN NUMBER,
		   p_relation_obj_version_num IN NUMBER,
		   p_party_obj_version_num    IN NUMBER,
		   p_api_status               OUT VARCHAR2,
		   p_error_msg                OUT VARCHAR2);
  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : create_account_role                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE create_account_role(p_cust_account_role_record IN OUT hz_cust_account_role_v2pub.cust_account_role_rec_type,
		        p_relationship_party_id    IN VARCHAR2,
		        p_cust_account_role_id     OUT NUMBER,
		        p_api_status               OUT VARCHAR2,
		        p_error_msg                OUT VARCHAR2);

  --
  PROCEDURE update_account_role(p_cust_account_role_record IN hz_cust_account_role_v2pub.cust_account_role_rec_type,
		        p_api_status               OUT NOCOPY VARCHAR2,
		        p_error_msg                OUT NOCOPY VARCHAR2);

  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : create_acct_site                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE create_acct_site(p_cust_acct_site_rec IN hz_cust_account_site_v2pub.cust_acct_site_rec_type,
		     p_cust_acct_site_id  OUT NUMBER,
		     p_api_status         OUT VARCHAR2,
		     p_error_msg          OUT VARCHAR2);

  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : update_acct_site                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE update_acct_site(p_cust_acct_site_rec    IN hz_cust_account_site_v2pub.cust_acct_site_rec_type,
		     p_object_version_number IN OUT NOCOPY NUMBER,
		     p_api_status            OUT VARCHAR2,
		     p_error_msg             OUT VARCHAR2);
  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : create_acct_site_use                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE create_acct_site_use(p_cust_site_use_rec IN hz_cust_account_site_v2pub.cust_site_use_rec_type,
		         p_site_use_id       OUT NUMBER,
		         p_api_status        OUT VARCHAR2,
		         p_error_msg         OUT VARCHAR2);

  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : update_acct_site_use                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE update_acct_site_use(p_cust_site_use_rec     IN hz_cust_account_site_v2pub.cust_site_use_rec_type,
		         p_object_version_number IN OUT NOCOPY NUMBER,
		         p_api_status            OUT VARCHAR2,
		         p_error_msg             OUT VARCHAR2);
  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : process_uda                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  /*PROCEDURE process_uda(p_cust_account_id IN NUMBER,
  p_indus_class_cat IN VARCHAR2,
  p_cross_industry  IN VARCHAR2,
  p_institute_type  IN VARCHAR2,
  p_department      IN VARCHAR2,
  p_return_status   OUT VARCHAR2,
  p_error_msg       OUT VARCHAR2);*/

  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : insert_acc_sfid_uda                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  /*PROCEDURE insert_acc_sfid_uda(p_cust_account_id IN NUMBER,
  p_acc_sfid        IN VARCHAR2,
  p_return_status   OUT VARCHAR2,
  p_error_msg       OUT VARCHAR2);*/

  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : insert_site_sfid_uda                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  /*PROCEDURE insert_site_sfid_uda(p_cust_acc_site_id IN NUMBER,
  p_site_sfid        IN VARCHAR2,
  p_return_status    OUT VARCHAR2,
  p_error_msg        OUT VARCHAR2);*/

  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : initialize_apps                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for Finding Organization                                          *
  ******************************************************************************************************************
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  *  1.00    11/05/2016  Somnath Dawn       Initial version
  *
  ******************************************************************************************************************************************/
  PROCEDURE initialize_apps(p_user_id           IN NUMBER,
		    p_application_id    IN NUMBER,
		    p_responsibility_id IN NUMBER);
  ----------------------------------------------
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
		         x_error_msg  IN OUT NOCOPY VARCHAR2);
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
			   x_error_msg  OUT VARCHAR2);

  PROCEDURE get_territory_org_info(p_country        IN VARCHAR2,
		           x_territory_code OUT VARCHAR2,
		           x_org_id         OUT NUMBER,
		           x_ou_unit_name   OUT VARCHAR2,
		           x_error_code     OUT VARCHAR2,
		           x_error_msg      OUT VARCHAR2);

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
		       p_soa_reference_id IN NUMBER);
END xxhz_soa_api_pkg;
/
