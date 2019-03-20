create or replace package xxinv_soa_onhand_pkg AUTHID CURRENT_USER AS
  ----------------------------------------------------------------------------
  --  name:            xxinv_soa_onhand_pkg
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
  ----------------------------------------------------------------------------

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
                                    x_status_message     OUT VARCHAR2);

END xxinv_soa_onhand_pkg;
/