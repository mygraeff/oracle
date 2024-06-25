--
-- dbms_privilege_capture.sql 
--
-- 202406 Version 1.1
--
-- with this procedure you are able to identify used privileges in a database 
--
-- create capture, enable capture, wait and collect the informations as long as neccessary (depending on business case)
-- stop capture, generate results and check results
-- you can only enable one kind of capture at once
--
-- improvements / suggestions always welcome
-- 
-- Roland Graeff, Oracle customer success service
-- 2024-06
-- https://github.com/mygraeff/oracle



--  privilege capture
-- https://oracle-base.com/articles/12c/capture-privilege-usage-12cr1
-- https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_PRIVILEGE_CAPTURE.html#GUID-8475738F-1660-4CCF-8171-A547DEAA78F2
-- https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/performing-privilege-analysis-identify-privilege-use.html#GUID-624BEE71-EE04-450F-9E8D-E5DF9788D18C


-- MOS
-- High Library Cache: Mutex X After Enabling Privilege Capture - dbms_privilege_capture.create_capture (Doc ID 2952850.1)
-- Privilege Analysis is not Working in a Procedure PL/SQL block Using DBMS_PRIVILEGE_CAPTURE (Doc ID 2891332.1)



-- A user defined condition, when user is RGF (type = G_CONTEXT).
begin
  dbms_privilege_capture.create_capture(
    name        => 'cond_pol_RGF',
	description => 'policy to record  privs used by schema RGF',
    type        => dbms_privilege_capture.g_context,
    condition   => 'sys_context(''userenv'', ''session_user'') = ''RGF'''
  );
end;
/

--Create a privilege analysis policy to analyze privileges from the role PUBLIC
begin
dbms_privilege_capture.create_capture(
       name         => 'pub_analysis_pol',
       description  => 'policy to record privilege use by PUBLIC',
       type         => dbms_privilege_capture.g_role,
       roles        => role_name_list('PUBLIC'));
end;
/

-- Create a privilege analysis for the database
begin
dbms_privilege_capture.create_capture(
       name          => 'db_capt_pol',
       description   => 'database privilege capture',
       type          => DBMS_PRIVILEGE_CAPTURE.G_DATABASE);
end;
/



begin 
 dbms_privilege_capture.capture_dependency_privs();
end;
/


-- list configured captures  (1)
column name format a15
column roles format a20
column context format a50
set linesize 200

select name,
       type,
       enabled,
       roles,
       context	   
from   dba_priv_captures
order by name;


-- enable
begin
	dbms_privilege_capture.enable_capture('cond_pol_RGF');
end;
/


-- disable_capture
begin
	dbms_privilege_capture.disable_capture('cond_pol_RGF');
end;
/


-- generate results

begin
  dbms_privilege_capture.generate_result('cond_pol_RGF');
end;
/


-- checks

-- sysprivs used
column username format a20
column used_role format a30
column sys_priv format a20
column path format a50
set linesize 200
set pages 100

select username, sys_priv, used_role, path
from   dba_used_sysprivs_path
where  capture = 'cond_pol_RGF'
order by username, sys_priv;

-- obj_priv used
column username format a20
column obj_priv format a8
column object_owner format a15
column object_name format a25
column object_type format a11

select sequence,username, obj_priv, object_owner, object_name, object_type, used_role
from   dba_used_objprivs
where  capture = 'cond_pol_RGF';


-- drop capture
-- results of this capture will also be deleted
begin 
	dbms_privilege_capture.drop_capture('cond_pol_RGF');
end;
/



-- example output

/*
(1)
NAME            TYPE             E ROLES                CONTEXT
--------------- ---------------- - -------------------- --------------------------------------------------
ORA$DEPENDENCY  DATABASE         N
cond_pol_RGF   CONTEXT          N                      sys_context('userenv', 'session_user') = 'RGF'
cond_pol_RGF   CONTEXT          N                      sys_context('userenv', 'session_user') = 'RGF'


(2)


USERNAME             SYS_PRIV             USED_ROLE                      PATH
-------------------- -------------------- ------------------------------ --------------------------------------------------
RGF                 CREATE SESSION       CONNECT                        GRANT_PATH('RGF', 'S0Y_ROLE', 'CONNECT')
RGF                 CREATE SESSION       CONNECT                        GRANT_PATH('RGF', 'S0Y_ROLE')
RGF                 CREATE TABLE         RESOURCE                       GRANT_PATH('RGF', 'RESOURCE')
RGF                 CREATE TABLE         RESOURCE                       GRANT_PATH('RGF', 'S0Y_ROLE', 'RESOURCE')




(3)
USERNAME             OBJ_PRIV OBJECT_OWNER    OBJECT_NAME               OBJECT_TYPE USED_ROLE
-------------------- -------- --------------- ------------------------- ----------- ------------------------------
RGF                 READ     SYS             KU$_HTABLE_VIEW           VIEW        PUBLIC
RGF                 SELECT   SYS             DUAL                      TABLE       PUBLIC
RGF                 EXECUTE  SYS             DBMS_OUTPUT               PACKAGE     PUBLIC
RGF                 SELECT   SYS             DUAL                      TABLE       PUBLIC
RGF                 READ     SYS             KU$_REFPARTTABPROP_VIEW   VIEW        PUBLIC
RGF                 READ     SYS             KU$_PFHTABPROP_VIEW       VIEW        PUBLIC
MDSYS                EXECUTE  SYS             DBMS_STANDARD             PACKAGE     PUBLIC
RGF                 SELECT   SYS             DUAL                      TABLE       PUBLIC
RGF                 EXECUTE  SYS             DBMS_STATS                PACKAGE     PUBLIC
RGF                 EXECUTE  SYS             DBMS_METADATA             PACKAGE     PUBLIC
RGF                 READ     SYS             KU$_TABPROP_VIEW          VIEW        PUBLIC
RGF                 READ     SYS             NLS_SESSION_PARAMETERS    VIEW        PUBLIC
RGF                 EXECUTE  SYS             XMLGENFORMATTYPE          TYPE        PUBLIC
RMAN$CATALOG         SELECT   SYS             DUAL                      TABLE       PUBLIC
RGF                 SELECT   SYS             DBA_TABLES                VIEW        SELECT_CATALOG_ROLE
RGF                 EXECUTE  SYS             DBMS_APPLICATION_INFO     PACKAGE     PUBLIC

*/



