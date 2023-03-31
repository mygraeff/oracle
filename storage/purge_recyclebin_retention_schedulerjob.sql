-- script to cleanup recyclebin older 60 days
-- interval 30 min, delete only 1500 entries at once
-- Roland Graeff, Oracle Germany Advanced Customer Services (ACS)
-- https://github.com/mygraeff/oracle

--grant select on dba_users to JOBOWNER;
--grant select on  dba_recyclebin to JOBOWNER;
--grant drop any table to JOBOWNER;


BEGIN
sys.dbms_scheduler.create_job( 
job_name => '"PURGE_RECYCLEBIN_OLDER60DAYS"',
job_type => 'PLSQL_BLOCK',
job_action => 'DECLARE
   TYPE purge_object_rt IS RECORD (
      vowner     VARCHAR2 (128),
      vobject    VARCHAR2 (128),
      vdroptime  VARCHAR2 (19)
   );
   TYPE purge_object_aat IS TABLE OF purge_object_rt
      INDEX BY PLS_INTEGER;
   l_pobject   purge_object_aat;
   
   purge_sql     VARCHAR2(500);

   num_recycles  NUMBER;
BEGIN
   execute immediate
      q''[select count(*) from dba_recyclebin
          Where
               Type = ''TABLE''
           and can_purge = ''YES''
           and owner not in (select username from dba_users where oracle_maintained = ''Y'')
           and to_date(droptime, ''yyyy-mm-dd:hh24:mi:ss'')   < sysdate-60]''
        into num_recycles;
   DBMS_OUTPUT.put_line(''Num entries dba-recyclebin to delete ''||to_char(sysdate,''dd-mm-yy hh24:mi:ss'')||'' : ''||num_recycles);


   EXECUTE IMMEDIATE
      q''[select owner,object_name,droptime
           from dba_recyclebin
          Where
                Type = ''TABLE''
            and can_purge = ''YES''
            and owner not in (select username from dba_users where oracle_maintained = ''Y'')
            and to_date(droptime, ''yyyy-mm-dd:hh24:mi:ss'')   < sysdate-60
           order by  to_date(droptime, ''yyyy-mm-dd:hh24:mi:ss'')  asc
           fetch first 1500 rows only]''           
      BULK COLLECT INTO l_pobject;
   FOR indx IN 1 .. l_pobject.COUNT
   LOOP
      -- DBMS_OUTPUT.put_line(''purging ''||l_pobject (indx).vowner||''."''||l_pobject (indx).vobject||''" dropped : ''|| l_pobject (indx).vdroptime );

      purge_sql := ''purge table /* scheduled purge recyclebin job */  ''||l_pobject (indx).vowner||''."''||l_pobject (indx).vobject||''"'';
      execute immediate  purge_sql;
   
   END LOOP;

   execute immediate
      q''[select count(*) from dba_recyclebin
          Where
               Type = ''TABLE''
           and can_purge = ''YES''
           and owner not in (select username from dba_users where oracle_maintained = ''Y'')
           and to_date(droptime, ''yyyy-mm-dd:hh24:mi:ss'')   < sysdate-60]''
        into num_recycles;
   dbms_output.new_line;
   DBMS_OUTPUT.put_line(''Num entries dba-recyclebin to delete ''||to_char(sysdate,''dd-mm-yy hh24:mi:ss'')||'' : ''||num_recycles);

   EXCEPTION
     WHEN OTHERS
    THEN
     DBMS_OUTPUT.PUT_LINE (''ERROR :'' || SQLERRM);
END;',
--repeat_interval => 'FREQ=HOURLY;INTERVAL=3',
repeat_interval => 'FREQ=MINUTELY;INTERVAL=30;BYDAY=MON,TUE,WED,THU,FRI,SAT,SUN',
start_date => to_timestamp_tz('2021-08-04 15:00:00 Europe/Vienna', 'YYYY-MM-DD HH24:MI:SS TZR'),
job_class => '"DEFAULT_JOB_CLASS"',
comments => 'purge job to cleanup recyclebin older 60 days  - max 1500 each run',
auto_drop => TRUE,
enabled => FALSE);
sys.dbms_scheduler.set_attribute( name => '"PURGE_RECYCLEBIN_OLDER60DAYS"', attribute => 'max_failures', value => 10); 
sys.dbms_scheduler.set_attribute( name => '"PURGE_RECYCLEBIN_OLDER60DAYS"', attribute => 'logging_level', value => DBMS_SCHEDULER.LOGGING_OFF); 
sys.dbms_scheduler.set_attribute( name => '"PURGE_RECYCLEBIN_OLDER60DAYS"', attribute => 'job_weight', value => 1); 
-- sys.dbms_scheduler.enable( '"PURGE_RECYCLEBIN_OLDER60DAYS"' ); 
END;
/


-- enable scheduler job
execute dbms_scheduler.enable('PURGE_RECYCLEBIN_OLDER60DAYS');

-- disable scheduler Job
execute dbms_scheduler.disable('PURGE_RECYCLEBIN_OLDER60DAYS');

-- to verify the history of the schedules
select LOG_DATE,STATUS,RUN_DURATION,ERRORS,output 
 from DBA_SCHEDULER_JOB_RUN_DETAILS  
  where job_name = 'PURGE_RECYCLEBIN_OLDER60DAYS' 
 order by log_date
/

-- to check execution count and next run
 select OWNER,JOB_NAME,ENABLED,RUN_COUNT,NEXT_RUN_DATE from dba_scheduler_jobs
 where job_name = 'PURGE_RECYCLEBIN_OLDER60DAYS'
 /
 
 -- drop scheduler job
 execute dbms_scheduler.drop_job('PURGE_RECYCLEBIN_OLDER60DAYS');
