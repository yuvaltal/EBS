CREATE OR REPLACE TRIGGER xxoe_order_lines_all_6_trg
  before DELETE ON OE_ORDER_LINES_ALL
FOR EACH ROW

when( 1=1 )
declare
  l_event_rec   xxobjt_custom_events%ROWTYPE;
begin
    --------------------------------------------------------------------
    --  name:            XXOE_ORDER_LINES_ALL_6_TRG
    --  create by:       Lingaraj Sarangi
    --  Revision:        1.0
    --  creation date:   16-Apr-2018
    --------------------------------------------------------------------
    --  purpose :   Order Header Delete Event will be generated for Strataforce
    --
    --  in params:
    --------------------------------------------------------------------
    --  ver  date          name                  desc
    --  1.0  16-Apr-2018   Lingaraj Sarangi      initial build CHG0042041
    --  1.1  17/12/2018    Roman W.              CHG0044657
    --------------------------------------------------------------------
    l_event_rec.event_name               := 'SO_LINE_DELETE';
    l_event_rec.source_name              := 'XXOE_ORDER_LINES_ALL_6_TRG';
    l_event_rec.event_table              := 'OE_ORDER_LINES_ALL';
    l_event_rec.event_key                := :OLD.LINE_ID;

    SELECT order_type_id ,
           -- order_number, rem CHG0044657
           order_number || '-' || :old.line_number ,-- added CHG0044657
           quote_number
      into l_event_rec.attribute1,
           l_event_rec.attribute2,
           l_event_rec.attribute3
      FROM oe_order_headers_all t
     WHERE t.header_id = :OLD.HEADER_ID;

    xxobjt_custom_events_pkg.insert_event(l_event_rec);


exception
  when others then
    null;
End xxoe_order_lines_all_6_trg;
/
