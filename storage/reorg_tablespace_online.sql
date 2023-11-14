-- 
-- move_table_2_tablespace
-- 
-- 202314 Version 1.9
--
-- the procedure is an example how to :
--  reorg tablespaces online
--  change LOB Storage  destination and type
--  change index destination
--  
-- tables from from source tablespace to others - wildcards for owner and tablenames can be used
-- run this script as sys / system / dba-privs 
--
-- in sqlplus set serveroutput on timing on
--
-- improvements / suggestions always welcome
-- 
-- Roland Graeff, Oracle customer success service
-- 2023-11
-- https://github.com/mygraeff/oracle


-- create procedure

CREATE OR REPLACE PROCEDURE "MOVE_TABLES_2_TABLESPACE" 
(
-- Roland Gräff, Oracle Customer success services
-- 20231114   Version 1.9
--
-- in sqlplus use
-- set serveroutput on
--

 SOURCEOWNER IN VARCHAR2 DEFAULT '%',
 SOURCETABLE IN VARCHAR2 DEFAULT '%',
 SOURCETBLSP IN VARCHAR2,
 TARGETTBLSP IN VARCHAR2, 
 TARGETINDEXTBLSP IN VARCHAR2,
 TARGETLOBTBLSP IN VARCHAR2,
 LOBSTORE IN VARCHAR2 DEFAULT NULL,
 TABLE_COUNT IN number DEFAULT 10
) AS
 q_owner varchar(30);
 q_table varchar(128);
 q_size number;
 num_tables number;
 stat_date date;

cursor c1 is
 select /* move_tables_2_tablespace */ owner, segment_name name, round(sum(bytes)/1024/1024,2) sizeMB
  from dba_segments
   where tablespace_name=sourcetblsp
     and segment_type = 'TABLE'
     and upper(owner) like SOURCEOWNER
     and upper(segment_name) like SOURCETABLE
   group by owner, segment_name
   order by owner, segment_name
  fetch first TABLE_COUNT rows only;

BEGIN
 num_tables := 0;

 open c1;

 loop
  fetch c1 into q_owner, q_table,q_size;
 exit when c1%NOTFOUND;

 DBMS_REDEFINITION.REDEF_TABLE ( 
  uname => q_owner, 
  tname => q_table,
  table_part_tablespace => TARGETTBLSP,
  index_tablespace => TARGETINDEXTBLSP,
  lob_tablespace => TARGETLOBTBLSP,
  lob_store_as => LOBSTORE
 );

 DBMS_STATS.GATHER_TABLE_STATS (ownname => q_owner, tabname => q_table);

 select LAST_ANALYZED into stat_date from dba_tables where owner = q_owner and table_name = q_table;

 DBMS_OUTPUT.PUT_LINE('table '||q_owner||'.'||q_table||' moved to '||targettblsp||' size MB '||q_size||' dbms_stat-date: '||to_char(stat_date,'''dd-mm-yy hh24:mi:ss'''));
 num_tables := num_tables + 1;
 end loop;

 DBMS_OUTPUT.PUT_LINE('tables modified : '||num_tables);

 close c1;

 exception
 when others then
 raise_application_error(-20001,'error in move_tables_2_tablespace encountered - '||sqlcode||' ERROR !! '||SQLERRM);
END move_tables_2_tablespace;
/


-- scripts to identify objects and progress

-- check number of extents before 
select count(*) from dba_extents
 where tablespace_name = 'TBLSPA';

-- check nuber of extents of each object
select owner, segment_name, segment_type, count(*) 
 from dba_extents
  where tablespace_name = 'TBLSPA'
 group by (owner, segment_name, segment_type)  
 order by owner, segment_name;


-- list all tablespaces
select tablespace_name, bigfile from dba_tablespaces order by 1;

-- list owner of objects in tablespace tblspA
select distinct owner from dba_extents where tablespace_name = 'TBLSPA';

-- list objects in tblspA
select owner, tablespace_name, segment_name, segment_type, round(sum(bytes/1024/1024/1024),2) GB
 from dba_segments
  where
 (
  tablespace_name = 'TBLSPA'
 --  or
 -- tablespace_name =  'TBLSPBLOB'
 -		- or
 -- tablespace_name =  'TBLSPB'
 )
 -- and segment_type = 'TABLE'
 group by  owner, tablespace_name, segment_name, segment_type
 order by owner, tablespace_name, segment_name
-- fetch first 5 rows only
/

-- show current storage type of LOBS
select owner, table_name, securefile from dba_lobs
  where tablespace_name = 'TBLSPA';

-- create new tablespaces if neccessary
CREATE BIGFILE TABLESPACE "TBLSPB" datafile SIZE 500M AUTOEXTEND ON NEXT 250M;
CREATE BIGFILE TABLESPACE "TBLSPBLOB" datafile SIZE 500M AUTOEXTEND ON NEXT 250M;

-- grant privileges to schema
alter user RGF quota unlimited on TBLSPB;
alter user RGF quota unlimited on TBLSPBLOB;

-- list all objects in source tablespace
select tablespace_name, segment_type, count(*) from dba_segments
 where tablespace_name like 'TBLSPA%'
 group by cube (tablespace_name, segment_type);

-- list tables in source tablespace
select tablespace_name, count(*) from dba_segments
 where tablespace_name like 'TBLSPA%'
   and segment_type = 'TABLE'
 group by cube (tablespace_name);


-- example to move all tables from source to target tablespace and store as securefile, only 1 table
-- options LOBSTORE : BASICFILE, SECUREFILE
exec move_tables_2_tablespace ( -
  SOURCETBLSP => 'TBLSPA',  -
  TARGETTBLSP => 'TBLSPB', -
  TARGETINDEXTBLSP => 'TBLSPBLOB', -
  TARGETLOBTBLSP   => 'TBLSPBLOB',  -
  LOBSTORE => 'SECUREFILE', -
  TABLE_COUNT => 1 -
)

-- example to move 300 tables 
exec move_tables_2_tablespace ( -
  SOURCETBLSP => 'TBLSPA',  -
  TARGETTBLSP => 'TBLSPB', -
  TARGETINDEXTBLSP => 'TBLSPB', -
  TARGETLOBTBLSP   => 'TBLSPBLOB',  -
  LOBSTORE => 'SECUREFILE', -
  TABLE_COUNT => 300 -
) 

-- example to move schema based objects without modifing LOBSTORAGE
exec move_tables_2_tablespace ( -
  SOURCEOWNER => 'RGF', -
  SOURCETBLSP => 'TBLSPA',  -
  TARGETTBLSP => 'TBLSPB', -
  TARGETINDEXTBLSP => 'TBLSPB', -
  TARGETLOBTBLSP   => 'TBLSPBLOB',  -
  TABLE_COUNT => 300 -
) 

-- example to move specific tables only
exec move_tables_2_tablespace ( -
  SOURCEOWNER => 'RGF', -
  SOURCETABLE => 'TESTTAB%', -
  SOURCETBLSP => 'TBLSPA',  -
  TARGETTBLSP => 'TBLSPB', -
  TARGETINDEXTBLSP => 'TBLSPB', -
  TARGETLOBTBLSP   => 'TBLSPBLOB',  -
  TABLE_COUNT => 300 -
) 


-- verify source tablespace is empty
select count(*) from dba_extents
 where tablespace_name = 'TBLSPA';

-- drop empty tablespace without option including contents to avoid data loss in case objects are not moved
drop tablespace TBLSPA;

-- rename tablespace to original name 
alter tablespace TBLSPB rename to TBLSPA;
alter tablespace TBLSPBLOB rename to TBLSPALOBS;

-- verify content 
select tablespace_name, segment_type, count(*) from dba_segments
 where tablespace_name like 'TBLSP%'
 group by cube (tablespace_name, segment_type);



