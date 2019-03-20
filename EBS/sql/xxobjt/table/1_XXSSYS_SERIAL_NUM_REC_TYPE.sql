CREATE OR REPLACE TYPE XXOBJT.XXSSYS_SERIAL_NUM_REC_TYPE FORCE AS OBJECT
(
--------------------------------------------------------------------
--  name:     XXSSYS_SERIAL_NUM_REC_TYPE
--  Description:
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   05.07.18      Lingaraj        CHG0042874 -CTASK0037418-Added Serial Contol Fields
--------------------------------------------------------------------
ITEM_CODE               VARCHAR2(40),
SERIAL_NUMBER           VARCHAR2(100)
)
/
CREATE OR REPLACE TYPE XXOBJT.XXSSYS_SERIAL_NUM_TAB_TYPE IS TABLE OF XXOBJT.XXSSYS_SERIAL_NUM_REC_TYPE
/