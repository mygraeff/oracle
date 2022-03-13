-- Compression Advisor 
-- Roland Graeff, Oracle ACS
-- 2022 - 19c

/* notes / whitepapers
 

 https://www.oracle.com/a/otn/docs/getstartedwithacotwp-5104153.pdf
Information Center: Advanced Compression (Doc ID 1526780.2)
1477918.1

https://blogs.oracle.com/dbstorage/post/compression-advisor-a-valuable-but-often-overlooked-tool-insights-and-best-practices


Compression Advisory in 11GR2: Using DBMS_COMPRESSION (Doc ID 762974.1)
How Does Compression Advisor Work? (Doc ID 1284972.1)
All About Advanced Table Compression (Overview, Usage, Examples, Restrictions) (Doc ID 882712.1)
How to estimate COMPRESSION RATIO for Indexes in 12c (Doc ID 1911547.1)

https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_COMPRESSION.html#GUID-9F37CAD6-C72C-407C-AFEE-CB5FD1129627

How to See Whether Rows are Compressed in a Table (Doc ID 1477918.1)

How To Disable Compression Advisor Alone Without Disabling Segment Advisor From 12.2 Onwards (Doc ID 2674127.1)

https://blogs.oracle.com/dbstorage/post/interested-in-oracle-database-compression-best-practices-and-insights

How to Compress an Existing Table (Doc ID 1080816.1)
How to Set Compression for Future Table Partitions (Doc ID 1984916.1)

*/

set lines 180 pages 100

-- check object types
select object_type, count(*) 
 from dba_objects
  where owner = 'S0YO'
 group by object_type
 order by 2 asc
/


-- check col-types
col data_type format a20
select data_type, count(*) 
 from dba_tab_cols
  where owner = 'S0YO'
 group by data_type 
 order by 1
/


-- check object sizes
col segment_name format a40
select segment_name, round(sum(bytes)/1024/1024/1024,2) GB 
 from dba_segments 
  where owner = 'S0YO' 
 group by segment_name 
 order by 2 asc
/

-- autotask status - check 
select client_name, status from dba_autotask_client;


-- tables without any modifications since last flush
-- 8k blocksize
col table_name format a40
select t.table_name,num_rows, to_char(last_analyzed,'dd-mm-yy hh24:mi:ss') lastanalyzed
 from dba_tables t
where t.owner = 'S0YO'
  and table_name not in (select table_name from dba_tab_modifications where owner = 'S0YO')
order by num_rows
/


-- exec DBMS_STATS.FLUSH_DATABASE_MONITORING_INFO  - by default view is populated once a day
-- tab modifications
col table_name format a40
select m.table_name,t.num_rows,t.blocks,  inserts, updates, deletes, inserts+updates+deletes sumdml
 from dba_tab_modifications m, dba_tables t
where m.table_owner = 'S0YO'
  and m.table_name = t.table_name
order by sumdml desc, num_rows asc
/


-- comp.types
--https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_COMPRESSION.html#GUID-8C9942CA-4EBD-48FF-9E8C-A59BF21A0176
--

-- get table compression rate
set serveroutput on
 DECLARE
 blkcnt_cmp pls_integer;
 blkcnt_uncmp pls_integer;
 row_cmp pls_integer;
 row_uncmp pls_integer;
 cmp_ratio pls_integer;
 cmptype_str varchar2(100);
 BEGIN
 DBMS_COMPRESSION.GET_COMPRESSION_RATIO ('USERS', 'S0YO', 'S0YRCIBZ', '', 
 DBMS_COMPRESSION.COMP_ADVANCED , 
 blkcnt_cmp, blkcnt_uncmp,row_cmp, row_uncmp, cmp_ratio, cmptype_str);
 
 DBMS_OUTPUT.PUT_LINE('Block count compressed = '|| blkcnt_cmp);
 DBMS_OUTPUT.PUT_LINE('Block count uncompressed = '|| blkcnt_uncmp);
 DBMS_OUTPUT.PUT_LINE('Row count per block compressed = '|| row_cmp);
 DBMS_OUTPUT.PUT_LINE('Row count per block uncompressed = '|| row_uncmp);
 DBMS_OUTPUT.PUT_LINE('Compression type = '|| cmptype_str);
 DBMS_OUTPUT.PUT_LINE('Compression ratio = '|| cmp_ratio);
 END;
 /
 
 
 -- get index compression rate

 set serveroutput on
 DECLARE
 blkcnt_cmp pls_integer;
 blkcnt_uncmp pls_integer;
 row_cmp pls_integer;
 row_uncmp pls_integer;
 cmp_ratio pls_integer;
 cmptype_str varchar2(100);
 BEGIN
 DBMS_COMPRESSION.GET_COMPRESSION_RATIO ('USERS', 'S0YO', 'S0YICIBZ_003', '', 
 DBMS_COMPRESSION.COMP_INDEX_ADVANCED_HIGH , 
 blkcnt_cmp, blkcnt_uncmp,
 row_cmp, row_uncmp, 
 cmp_ratio, cmptype_str,
 subset_numrows => dbms_compression.COMP_RATIO_MINROWS,
 objtype => dbms_compression.OBJTYPE_INDEX
 );
 
 DBMS_OUTPUT.PUT_LINE('Block count compressed = '|| blkcnt_cmp);
 DBMS_OUTPUT.PUT_LINE('Block count uncompressed = '|| blkcnt_uncmp);
 DBMS_OUTPUT.PUT_LINE('Row count per block compressed = '|| row_cmp);
 DBMS_OUTPUT.PUT_LINE('Row count per block uncompressed = '|| row_uncmp);
 DBMS_OUTPUT.PUT_LINE('Compression type = '|| cmptype_str);
 DBMS_OUTPUT.PUT_LINE('Compression ratio = '|| cmp_ratio);
 END;
 /


-- get LOB compression rate

-- list lobs, tables
col data_type format a20
col table_name format a30
col column_name format a30

select table_name, column_name, data_type
 from dba_tab_cols
  where owner = 'S0YO'
    and data_type like '%LOB' 
 order by 3,1,2
/

 
 
 set serveroutput on
 DECLARE
 blkcnt_cmp pls_integer;
 blkcnt_uncmp pls_integer;
 lobcnt pls_integer;
 cmp_ratio pls_integer;
 cmptype_str varchar2(1000);
 BEGIN
 DBMS_COMPRESSION.GET_COMPRESSION_RATIO ('USERS', 'S0YO', 'S0YRCBINFOHT', 'HTMLCONTENT', NULL,
 DBMS_COMPRESSION.COMP_LOB_MEDIUM , 
 blkcnt_cmp, blkcnt_uncmp,
 lobcnt, 
 cmp_ratio, cmptype_str,
 subset_numrows => dbms_compression.COMP_RATIO_MINROWS
 );
 
 DBMS_OUTPUT.PUT_LINE('Block count compressed               : '|| blkcnt_cmp);
 DBMS_OUTPUT.PUT_LINE('Block count uncompressed             : '|| blkcnt_uncmp);
 DBMS_OUTPUT.PUT_LINE('number of rows in a block(compressed : '||lobcnt);
 DBMS_OUTPUT.PUT_LINE('number of lobs sampled               : '|| cmp_ratio);
 DBMS_OUTPUT.PUT_LINE('Compression type                     : '|| cmptype_str);
 
 END;
 /


-- manual testing of compression
create table target_table as select * from  source_table where 1=2;
 
-- modify the default attributes of the table for compression, so new partitions will be compressed
alter table <TABLE_NAME> modify default attributes compress for oltp; 

insert into table target_table select * from source_table sample (10);
 
-- compress table
ALTER TABLE T1 move COMPRESS;
  
 
 -- find compression in a table
 col Compression_type format a50
SELECT CASE comp_type
         WHEN 1 THEN 'No Compression'
         WHEN 2 THEN 'Advanced compression level'
         WHEN 4 THEN 'Hybrid Columnar Compression for Query High'
         WHEN 8 THEN 'Hybrid Columnar Compression for Query Low'
         WHEN 16 THEN 'Hybrid Columnar Compression for Archive High'
         WHEN 32 THEN 'Hybrid Columnar Compression for Archive Low'
         WHEN 64 THEN 'Compressed row'
         WHEN 128 THEN 'High compression level for LOB operations'
         WHEN 256 THEN 'Medium compression level for LOB operations'
         WHEN 512 THEN 'Low compression level for LOB operations'
         WHEN 1000 THEN 'Minimum required number of LOBs in the object for which LOB compression ratio is to be estimated'
         WHEN 4096 THEN 'Basic compression level'
         WHEN 5000 THEN 'Maximum number of LOBs used to compute the LOB compression ratio'
         WHEN 1000000 THEN 'Minimum required number of rows in the object for which HCC ratio is to be estimated'
         WHEN -1 THEN 'To indicate the use of all the rows in the object to estimate HCC ratio'
         WHEN 1 THEN 'Identifies the object whose compression ratio is estimated as of type table'
         ELSE 'Unknown Compression Type'
       END AS Compression_type,
       n as num_rows
FROM  (
   SELECT comp_type, sum(numrows) n  
   from  (
      SELECT dbms_compression.Get_compression_type('USER', 'SALES_COMP', myROWID) AS comp_type, numrows
      from (
         select min(rowid) myrowid,count(*) numrows from SALES_COMP group by dbms_rowid.rowid_block_number(rowid)
      )
   )
   GROUP  BY comp_type
)
/

