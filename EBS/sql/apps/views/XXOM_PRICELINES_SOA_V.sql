CREATE OR REPLACE VIEW XXOM_PRICELINES_SOA_V AS
SELECT
----------------------------------------------------------------------------------------------------------
--  name       :     XXOM_PRICELINES_SOA_V
--  Description:     PRICE LINE SOA view
--                   Called by SOA
----------------------------------------------------------------------------------------------------------
--  ver   date          name                   desc
--  1.0   17.11.17      Lingaraj Sarangi       CHG0041808-Pricelist Line Interface - strataforce  project initial build
----------------------------------------------------------------------------------------------------------
       event_id,
       status,
       sf_product_id,
       decode (unit_price,null,0,unit_price) unit_price,
       direct_price,
       list_line_id,
       sf_price_book_id,
       product_uom_code,
       (Case
         When active = 'True' and  unit_price is not null Then
            'True'
         Else
            'False'
         End
       ) Active,
       dml_mode,
       currency_code
FROM   (
   Select * from (
       SELECT  1 seq ,
       e.event_id,
     e.status,
     '' dml_mode,
     xxssys_oa2sf_util_pkg.get_sf_product_id(e.attribute4) sf_product_id,
     xxssys_oa2sf_util_pkg.get_sf_pricebook_id(h.list_header_id) sf_price_book_id,
     xxssys_oa2sf_util_pkg.get_active_price(h.list_header_id,
              e.attribute1) unit_price,
     xxssys_oa2sf_util_pkg.get_oracle_directpl_unitprice(h.attribute11,
                 to_number(e.attribute1)) direct_price,
     e.entity_code list_line_id,
     h.currency_code,
     l.product_uom_code product_uom_code,
       (Case
         When nvl(h.active_flag,'N') = 'Y' and  nvl(h.attribute6 ,'N') = 'Y'
              and trunc(sysdate) < nvl(h.end_date_active , (sysdate + 1))
         Then
            'True'
         Else
            'False'
         End
         ) Active,
       --  row_number() over (partition by e.target_name,e.ENTITY_name, e.ENTITY_code order by to_date(e.attribute2,'dd-mon-yyyy' ) ) as
       1 rec_num,
         h.list_header_id
        FROM   xxssys_events         e,
               qp_list_headers_all_b h,
               qp_pricing_attributes l
        WHERE

         l.list_line_id(+) = e.attribute6
        AND    l.product_attribute_context(+) = 'ITEM'
        AND    l.list_header_id(+) = entity_id
        and nvl(l.pricing_attribute_context,'x')='x'
        AND    e.entity_name = 'PRICE_ENTRY'
      AND    e.status = 'NEW'
        AND    e.target_name = 'STRATAFORCE'
        AND    h.list_header_id = entity_id
        AND    e.event_id = (select min(event_id)
                                from xxssys_events e2
                                where e.entity_code   = e2.entity_code
                                and    e2.entity_name = 'PRICE_ENTRY'
                              and    e2.status      =   'NEW'
                                and    e2.target_name = 'STRATAFORCE'
                         )
        and( nvl(to_date(e.attribute3,'dd-mon-yyyy'),sysdate+1) <trunc(sysdate)
        or trunc(sysdate) between
                       to_date(e.attribute2,'dd-mon-yyyy')
                   AND to_date(e.attribute3,'dd-mon-yyyy'))
        ) --where
       --and rec_num = 1
        UNION ALL
                 SELECT

                  2 seq ,e.event_id,
                  e.status,
                   null                                    DML_MODE,
                  ----------------------------------
                  xxssys_oa2sf_util_pkg.get_sf_product_id(e.attribute3) sf_product_id,
                      std_pl.pl_id                            sf_price_book_id,
                  1                                       Unit_Price,
                  null                                    direct_price,
                  entity_code                             list_Line_Id,
                     e.attribute2                            currency_code,
                  null                                    product_uom_code,
                  'True' Active,
                  1 rec_num,
                  0  list_header_id
                   from (SELECT id pl_id
            FROM   xxsf2_pricebook2 t
            WHERE  t.isstandard = 1)  std_pl,
                        xxssys_events e
                  where e.entity_name = 'PRICE_ENTRY_STD'
                  and   e.status      = 'NEW'
                  and   e.target_name = 'STRATAFORCE'
         UNION ALL
                 SELECT 3 seq ,
                        e.event_id,
                        e.status,
                        null DML_MODE,
                        ----------------------------------
                        xxssys_oa2sf_util_pkg.get_sf_product_id(e.attribute4) sf_product_id,
                        xxssys_oa2sf_util_pkg.get_sf_pricebook_id(e.entity_id) sf_price_book_id,
                        to_number(e.attribute7) Unit_Price,
                        null direct_price,
                        e.entity_code list_Line_Id,
                        e.attribute5 currency_code,
                        e.attribute8 product_uom_code,
                        (Case
                         When e.active_flag = 'Y'
                         Then
                            'True'
                         Else
                            'False'
                         End
                         ) Active,
                         1 rec_num,
                         e.entity_id list_header_id
                   from xxssys_events e
                  where e.entity_name = 'PRICE_LINE_FORMULA'
                  and   e.status      = 'NEW'
                  and   e.target_name = 'STRATAFORCE'
        )
Where  sf_price_book_id != 'NOVALUE'
and    sf_product_id  != 'NOVALUE'
;
/
