CREATE OR REPLACE TRIGGER XXHZ_SITE_SOA_V_TRG
------------------------------------------------------------------------------------------
  -- Trigger: XXPO_VENDOR_SITE_SOA_V_TRG
  -- Created:
  -- Author  :
  -- Version: 1.0
  -------------------------------------------------------------------------------------------
  -- Ver When        Who        Description
  -- --- ----------  ---------  -------------------------------------------------------------
  -- 1.0 27/03/2018  Roman.W    Init Version
  --                            CHG0042560 - New Site interface from Oracle to  STRATAFORCE
  --                            trigger used by soa
  -------------------------------------------------------------------------------------------
  instead of update on XXHZ_SITE_SOA_V
  for each row
---------------------------
  --    Code Section
  ---------------------------
declare
  -- local variables here
begin
  if :new.status = 'IN_PROCESS' and nvl(:old.status, 'NEW') = 'NEW' then

    update xxssys_events xe
       set xe.status = 'IN_PROCESS'
     where xe.event_id = nvl(:old.event_id, :new.event_id);
  end if;
end XXHZ_SITE_SOA_V_TRG;
/
