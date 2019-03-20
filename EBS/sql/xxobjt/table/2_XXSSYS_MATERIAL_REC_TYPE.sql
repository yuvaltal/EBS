CREATE OR REPLACE TYPE XXOBJT.XXSSYS_MATERIAL_REC_TYPE FORCE AS OBJECT
(
--------------------------------------------------------------------
--  name:     XXSSYS_MATERIAL_REC_TYPE
--  Description:
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   23.05.18      yuval tal       CHG0042874 - Field Service Usage interface from salesforce to Oracle
--  1.1   05.07.18      Lingaraj        CHG0042874 -CTASK0037418-Added Serial Contol Fields
--------------------------------------------------------------------
  SOURCE_REFERENCE_ID      VARCHAR2(30),
  INVENTORY_ITEM_ID        NUMBER,
  ITEM_CODE                VARCHAR2(40),
  REVISION                 VARCHAR2(10),
  SERIAL_CONTROLLED        VARCHAR2(1), --CTASK0037418
  SERIAL_NUMBER_LIST       XXOBJT.XXSSYS_SERIAL_NUM_TAB_TYPE,--CTASK0037418
  QUANTITY_TRX             NUMBER,
  TRANSACTION_UOM          VARCHAR2(5),
  SUBINVENTORY_CODE        VARCHAR2(50),
  ORGANIZATION_ID          NUMBER,
  ORGANIZATION_CODE        VARCHAR2(5),
  COST_OF_SALES_ACCOUNT_ID NUMBER,
  USER_ID                  NUMBER,
  ATTRIBUTE1               VARCHAR2(240),
  ATTRIBUTE2               VARCHAR2(240),
  ATTRIBUTE3               VARCHAR2(240),
  ATTRIBUTE4               VARCHAR2(240),
  ATTRIBUTE5               VARCHAR2(240),
  ERR_CODE                 VARCHAR2(1),-- S/E
  ERR_MESSAGE              VARCHAR2(500)
)
/
CREATE OR REPLACE TYPE XXOBJT.XXSSYS_MATERIAL_TAB_TYPE IS TABLE OF XXOBJT.XXSSYS_MATERIAL_REC_TYPE
/