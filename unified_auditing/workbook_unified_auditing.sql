-- Unified Auditing
-- scriptset to create policies, to query and to maintain audit
-- 
-- Roland Graeff, Oracle ACS
--   roland.graeff@oracle.com
-- 19c / 2021-09


--------------------------------------------------------------------------------------------------------------
--References
-- https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/topics-for-database-administrators-and-developers.html#GUID-B4C43A8E-A9CF-42C1-947E-FA234CF49B62

-- security
-- https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/part_6.html
--best practice 
-- https://www.oracle.com/a/tech/docs/dbsec/unified-audit-best-practice-guidelines.pdf
--tutorial
-- https://www.oracle.com/webfolder/technetwork/tutorials/obe/db/12c/r1/security/sec_uni_audit/sec_uni_audit.html

-- Dbms_Audit_Mgmt.Set_Audit_Trail_Location Does Not Move Lob And Index Partitions (Doc ID 2428624.1)
-- DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL is NOT purging all the records before LAST_ARCHIVE_TIMESTAMP in Unified Auditing when there is one DBID (Doc ID 2744602.1)
-- https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/administering-the-audit-trail.html#GUID-9B891A44-3DF4-4B52-98D4-A931DBFAEC1D


-- General
-- schema AUDSYS
-- tablspace sysaux
-- readonly 
-- $ORACLE_BASE/audit/$ORACLE_SID

-- views
-- audit_unified_policies
-- audit_unified_enabled_policies
--
-- unified_audit_trail
-- 
-- DBA_AUDIT_MGMT_CONFIG_PARAMS
-- DBA_AUDIT_MGMT_CLEAN_EVENTS
-- DBA_AUDIT_MGMT_CLEANUP_JOBS
-- DBA_AUDIT_MGMT_LAST_ARCH_TS
-- dba_scheduler_job_run_details
--
-- DBMS_AUDIT_MGMT

--------------------------------------------------------------------------------------------------------------

-- ### enable unified auding
select parameter, value from v$option where lower(parameter) like '%unified%';

shutdown immediate
/srv/oracle/product/19.0.0.0/rdbms/lib>make -f ins_rdbms.mk uniaud_on ioracle
startup


-- ### policies
-- list all policies
select distinct policy_name from audit_unified_policies order by 1;
 
-- list enabled policies
col policy_name format a40
col entity_name format a40
select policy_name,enabled_option,entity_name,entity_type,success,failure from audit_unified_enabled_policies;


-- content of policies
col audit_option format A40
col condition_eval_opt format A10
col audit_condition format A50
col policy_name format A30


SELECT policy_name,
	   audit_option,
	   condition_eval_opt,
	   audit_condition
FROM   audit_unified_policies
WHERE  policy_name in ('ORA_SECURECONFIG','ORA_LOGON_FAILURES')
ORDER BY 1,2;

--------------------------------------------------------------------------------------------------------------

--### maintenance

-- audit trail properties
col parameter_name format a40
col parameter_value format a40
select * from dba_audit_mgmt_config_params order by audit_trail, parameter_name;

col segment_name format a30
select segment_name,segment_subtype,segment_type,bytes/1024/1024 MB,tablespace_name  from dba_segments where owner = 'AUDSYS';


--move different tablespace
You can designate a different tablespace on a running instance, including one that is encrypted, 
by using the DBMS_AUDIT_MGMT.SET_AUDIT_TRAIL_LOCATION procedure. 
This procedure sets the tablespace for newer audit records but does not move theolder audit records.

create tablespace ADT datafile '/srv/oracle/oradata/RGFTST/adt01.dbf' size 100M autoextend on next 100M maxsize 1G;

exec dbms_audit_mgmt.set_audit_trail_location(audit_trail_type=>dbms_audit_mgmt.audit_trail_unified,audit_trail_location_value => 'ADT');

-- change partition frequency, to have next day the extents in the correct tablespace
begin
dbms_audit_mgmt.alter_partition_interval(
interval_number=>1,
interval_frequency=>'DAY');
end;
/

begin
dbms_audit_mgmt.init_cleanup(
              audit_trail_type   => dbms_audit_mgmt.audit_trail_all,
      default_cleanup_interval   => 12 /* hours */);
end;
/


-- verify extents
select owner,table_name,interval,partitioning_type,partition_count,def_tablespace_name from dba_part_Tables where owner='AUDSYS';

set lines 250
set pages 9999
col table_name for a30
col partition_name for a30
col HIGH_VALUE for a40
select table_name,partition_name,tablespace_name,interval,high_value,high_value_length from dba_tab_partitions where table_name='AUD$UNIFIED';


-- by default the changes are written in async mode
-- immediate write / sync
begin
dbms_audit_mgmt.set_audit_trail_property(
dbms_audit_mgmt.audit_trail_unified,
dbms_audit_mgmt.audit_trail_write_mode,
dbms_audit_mgmt.audit_trail_immediate_write);
end;
/

--queued write / async
begin
dbms_audit_mgmt.set_audit_trail_property(
dbms_audit_mgmt.audit_trail_unified,
dbms_audit_mgmt.audit_trail_write_mode,
dbms_audit_mgmt.audit_trail_queued_write);
end;
/


-- purge audit logs in interval
--   dbms_audi_mgmt-job is not used due to the use_timestamp has to be configured each time 

-- query last_arch_ts 
select audit_trail,last_archive_ts
 from   dba_audit_mgmt_last_arch_ts;

-- create job   - retentiontime 8 days
 begin
  dbms_scheduler.create_job (
  job_name => 'PURGE_UNIFIED_AUDIT_TRAIL',
  job_type => 'PLSQL_BLOCK',
  job_action => 'begin 
	dbms_audit_mgmt.set_last_archive_timestamp(audit_trail_type=> dbms_audit_mgmt.audit_trail_unified,last_archive_time=>to_timestamp(sysdate-8));
    dbms_audit_mgmt.clean_audit_trail(audit_trail_type =>dbms_audit_mgmt.audit_trail_all,use_last_arch_timestamp => true);
  end;',
  start_date => to_timestamp_tz('2021-08-04 15:00:00 Europe/Vienna', 'YYYY-MM-DD HH24:MI:SS TZR'),
  -- repeat_interval => 'FREQ=DAILY;BYHOUR=21',
  repeat_interval => 'FREQ=MINUTELY;INTERVAL=5;BYDAY=MON,TUE,WED,THU,FRI,SAT,SUN',
  comments => 'job to cleanup unified audit trail at 9pm daily');
end;
/

-- job need to be enabled
exec dbms_scheduler.enable('PURGE_UNIFIED_AUDIT_TRAIL');

-- disable job
exec dbms_scheduler.disable('PURGE_UNIFIED_AUDIT_TRAIL');

select job_name,enabled,start_date,repeat_interval,last_run_duration,next_run_date,state
from dba_scheduler_jobs
  where
    job_name like 'PURGE_UNIFIED_AUDIT_TRAIL'
order by 1
/

 
-- query cleanup-job executions
col job_name format a15
col status format a15
col actual_start_date format a30
col log_date format a30

select job_name, status, to_char(actual_start_date,'dd-mm-yy hh24:mi:ss') act_startdate, to_char(log_date,'dd-mm-yy hh24:mi:ss') log_date,run_duration
-- , errors, output
from dba_scheduler_job_run_details
where job_name='PURGE_UNIFIED_AUDIT_TRAIL'
order by actual_start_date
/

-- clear last_archive_timestamp
begin
dbms_audit_mgmt.clear_last_archive_timestamp(
   audit_trail_type     => dbms_audit_mgmt.audit_trail_unified);
end;
/

-- set_lst_archive_timestamp
begin
dbms_audit_mgmt.set_last_archive_timestamp(audit_trail_type=> dbms_audit_mgmt.audit_trail_unified,last_archive_time=>to_timestamp(sysdate-8));
end;
/

--purge manual 
begin
dbms_audit_mgmt.clean_audit_trail(
audit_trail_type => dbms_audit_mgmt.audit_trail_unified,
use_last_arch_timestamp => true);
end;
/

-- drop job
exec dbms_scheduler.drop_job('PURGE_UNIFIED_AUDIT_TRAIL');

--------------------------------------------------------------------------------------------------------------

-- ### example to audit operations on table

--audit object exept owner
create audit policy audit_t1_action
   actions all on rgraeff.t1;

audit policy audit_t1_action except rgraeff;


select policy_name, enabled_option, entity_name, success, failure
  from audit_unified_enabled_policies
 where policy_name ='AUDIT_T1_ACTION'
/

--audit procedure execute
create audit policy audit_proc_rgraeff_test
  actions execute on rgraeff.rgraeff_test;
audit policy audit_proc_rgraeff_test except rgraeff;


-- query audit trail
-- timezone in UTC
col unified_audit_policies format a20
col dbusername format a15
col action_name format a10
col system_privilege_used format a20
col object_name format a20

select unified_audit_policies, dbusername, action_name,
		   system_privilege_used, object_name,
		   to_char(event_timestamp_utc,'dd-mm-yy hh24:mi') "date_utc", return_code
	from unified_audit_trail
  --  where dbusername = 'RGRAEFF'
  order by entry_id
/

select audit_trail,last_archive_ts,systimestamp at time zone 'UTC'
 from   dba_audit_mgmt_last_arch_ts;


--------------------------------------------------------------------------------------------------------------

--### query unified_audit_trail

--flush audit data to disk
exec sys.dbms_audit_mgmt.flush_unified_audit_trail

select policy_name, audit_option, condition_eval_opt
  from   audit_unified_policies;

select policy_name, enabled_option, entity_name, success, failure
  from audit_unified_enabled_policies;

select sql_text, unified_audit_policies, dbusername 
  from unified_audit_trail 
 order by event_timestamp_utc desc;


-- ### drop policy
select * from audit_unified_enabled_policies;
noaudit policy audit_t1_action;
drop audit policy audit_t1_action;

--------------------------------------------------------------------------------------------------------------

-- ### policies - several examples

--create policy e.g
CREATE AUDIT POLICY ALL_ACTIONS_ON_EMPLOYEES
ACTIONS ALL ON HR.EMPLOYEES
WHEN 'INSTR(UPPER(SYS_CONTEXT(USERENV, AUTHENTICATION_METHOD)), SSL) = 0'
EVALUATE PER SESSION
ONLY TOPLEVEL;

--activate policy
AUDIT POLICY ALL_ACTIONS_ON_EMPLOYEES BY USERS WITH GRANTED ROLES DBA;



--policy all schema changes
CREATE AUDIT POLICY AUDIT_DB_SCHEMA_CHANGES
PRIVILEGES
CREATE EXTERNAL JOB, CREATE JOB, CREATE ANY JOB
ACTIONS
CREATE PACKAGE, ALTER PACKAGE, DROP PACKAGE,
CREATE PACKAGE BODY, ALTER PACKAGE BODY, DROP PACKAGE BODY,
CREATE PROCEDURE, DROP PROCEDURE, ALTER PROCEDURE,
CREATE FUNCTION, DROP FUNCTION, ALTER FUNCTION,
CREATE TRIGGER, ALTER TRIGGER, DROP TRIGGER,
CREATE LIBRARY, ALTER LIBRARY, DROP LIBRARY,
CREATE SYNONYM, DROP SYNONYM, ALTER SYNONYM,
CREATE TABLE, ALTER TABLE, DROP TABLE, TRUNCATE TABLE,
CREATE DATABASE LINK, ALTER DATABASE LINK, DROP DATABASE LINK,
CREATE INDEX, ALTER INDEX, DROP INDEX,
CREATE INDEXTYPE, ALTER INDEXTYPE, DROP INDEXTYPE,
CREATE OUTLINE, ALTER OUTLINE, DROP OUTLINE,
CREATE CONTEXT, DROP CONTEXT,
CREATE ATTRIBUTE DIMENSION, ALTER ATTRIBUTE DIMENSION, DROP ATTRIBUTE DIMENSION,
CREATE DIMENSION, ALTER DIMENSION, DROP DIMENSION,
CREATE MINING MODEL, ALTER MINING MODEL, DROP MINING MODEL,
CREATE OPERATOR, ALTER OPERATOR, DROP OPERATOR,
CREATE JAVA, ALTER JAVA, DROP JAVA,
CREATE TYPE BODY, ALTER TYPE BODY, DROP TYPE BODY,
CREATE TYPE, ALTER TYPE, DROP TYPE,
CREATE VIEW, ALTER VIEW, DROP VIEW,
CREATE MATERIALIZED VIEW, ALTER MATERIALIZED VIEW, DROP MATERIALIZED VIEW,
CREATE MATERIALIZED VIEW LOG, ALTER MATERIALIZED VIEW LOG, DROP MATERIALIZED VIEW LOG,
CREATE MATERIALIZED ZONEMAP, ALTER MATERIALIZED ZONEMAP, DROP MATERIALIZED ZONEMAP,
CREATE ANALYTIC VIEW, ALTER ANALYTIC VIEW, DROP ANALYTIC VIEW,
CREATE SEQUENCE, ALTER SEQUENCE, DROP SEQUENCE,
CREATE CLUSTER, ALTER CLUSTER, DROP CLUSTER, TRUNCATE CLUSTER;
AUDIT POLICY AUDIT_DB_SCHEMA_CHANGES;


--create policy audit datapump
CREATE AUDIT POLICY AUDIT_DATAPUMP
ACTIONS COMPONENT= datapump EXPORT, IMPORT;

AUDIT POLICY AUDIT_DATAPUMP ;

--create policy non-business-hour
CREATE AUDIT POLICY AUDIT_NON_BUSINESS_HOURS
ACTIONS update ON HR.EMPLOYEES
WHEN '((SYS_CONTEXT(DATE_CTX,DAY) NOT IN SATURDAY, SUNDAY)
AND (SYS_CONTEXT(DATE_CTX,TIME) > 180000)
AND (SYS_CONTEXT(DATE_CTX,TIME) < 090000)) OR
(SYS_CONTEXT(DATE_CTX,DAY) IN SATURDAY, SUNDAY)'
EVALUATE PER STATEMENT;

AUDIT POLICY AUDIT_NON_BUSINESS_HOURS EXCEPT HR_ANN;


--create policy sensitive-data
CREATE AUDIT POLICY USER_ACTIVITY_NOT_IN_TRUSTED_PATH
ACTIONS
ALL ON HR.EMPLOYEES
, ALL ON HR.JOB_HISTORY
, ALL ON HR.DEPARTMENTS
, ALL ON HR.COUNTRIES
, ALL ON HR.LOCATIONS
, ALL ON HR.REGIONS
, ALL ON HR.JOBS
WHEN 'SYS_CONTEXT("APPUSER_CONTEXT, APP_USER) NOT IN (EMPLOYEE_USER, HR_USER, HR_MANAGER'')'
EVALUATE PER STATEMENT
ONLY TOPLEVEL;

AUDIT POLICY USER_ACTIVITY_NOT_IN_TRUSTED_PATH BY USERS WITH GRANTED ROLES EMP_ROLE, HR_ROLE, HR_MGR;

--create policy on objects
CREATE AUDIT POLICY USER_ACTIVITY_HUMAN_ACTORS
ACTIONS
ALL ON HR.EMPLOYEES
, ALL ON HR.JOB_HISTORY
, ALL ON HR.DEPARTMENTS
, ALL ON HR.COUNTRIES
, ALL ON HR.LOCATIONS
, ALL ON HR.REGIONS
, ALL ON HR.JOBS
ONLY TOPLEVEL;

AUDIT POLICY USER_ACTIVITY_HUMAN_ACTORS by sophie, john;
