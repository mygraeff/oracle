--
-- shows online redologs + numbe of logswitches /hour/day + amount of redo
-- only for ARCH
-- 
-- als system
--
-- PROOFREAD THIS SCRIPT BEFORE USING IT!
--
-- IN NO EVENT SHALL ORACLE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
-- SPECIAL OR CONSEQUENTIAL DAMAGES, OR DAMAGES FOR LOSS OF PROFITS, REVENUE,
-- DATA OR USE, INCURRED BY YOU OR ANY THIRD PARTY, WHETHER IN AN ACTION IN
-- CONTRACT OR TORT, ARISING FROM YOUR ACCESS TO, OR USE OF, THE SOFTWARE.
--
-- Roland Graeff, Oracle Germany Advanced Customer Services (ACS)
-- 2022

set feed off
set pagesize 10000
set wrap off
set linesize 200
set heading on
set tab on
set scan on
set verify off

alter session set nls_date_format = 'MM-DD-YYYY:HH24:MI';

ttitle left 'Online Redolog File Status' skip 2

col group# format 999999
col mb format 999
col status format a10

select group#, bytes/1024/1024 MB, sequence#,
       Members, archived, status, first_time
  from v$log;

ttitle skip 2 left 'Logswitches/hour' skip 2


col 00 format a4
col 01 format a4
col 02 format a4
col 03 format a4
col 04 format a4
col 05 format a4
col 06 format a4
col 07 format a4
col 08 format a4
col 09 format a4
col 10 format a4
col 11 format a4
col 12 format a4
col 13 format a4
col 14 format a4
col 15 format a4
col 16 format a4
col 17 format a4
col 18 format a4
col 19 format a4
col 20 format a4
col 21 format a4
col 22 format a4
col 23 format a4
col day format a10

select substr(completion_time,1,10) day,
       to_char(sum(decode(substr(completion_time,12,2),'00',1,0)),'999') "00",
       to_char(sum(decode(substr(completion_time,12,2),'01',1,0)),'999') "01",
       to_char(sum(decode(substr(completion_time,12,2),'02',1,0)),'999') "02",
       to_char(sum(decode(substr(completion_time,12,2),'03',1,0)),'999') "03",
       to_char(sum(decode(substr(completion_time,12,2),'04',1,0)),'999') "04",
       to_char(sum(decode(substr(completion_time,12,2),'05',1,0)),'999') "05",
       to_char(sum(decode(substr(completion_time,12,2),'06',1,0)),'999') "06",
       to_char(sum(decode(substr(completion_time,12,2),'07',1,0)),'999') "07",
       to_char(sum(decode(substr(completion_time,12,2),'08',1,0)),'999') "08",
       to_char(sum(decode(substr(completion_time,12,2),'09',1,0)),'999') "09",
       to_char(sum(decode(substr(completion_time,12,2),'10',1,0)),'999') "10",
       to_char(sum(decode(substr(completion_time,12,2),'11',1,0)),'999') "11",
       to_char(sum(decode(substr(completion_time,12,2),'12',1,0)),'999') "12",
       to_char(sum(decode(substr(completion_time,12,2),'13',1,0)),'999') "13",
       to_char(sum(decode(substr(completion_time,12,2),'14',1,0)),'999') "14",
       to_char(sum(decode(substr(completion_time,12,2),'15',1,0)),'999') "15",
       to_char(sum(decode(substr(completion_time,12,2),'16',1,0)),'999') "16",
       to_char(sum(decode(substr(completion_time,12,2),'17',1,0)),'999') "17",
       to_char(sum(decode(substr(completion_time,12,2),'18',1,0)),'999') "18",
       to_char(sum(decode(substr(completion_time,12,2),'19',1,0)),'999') "19",
       to_char(sum(decode(substr(completion_time,12,2),'20',1,0)),'999') "20",
       to_char(sum(decode(substr(completion_time,12,2),'21',1,0)),'999') "21",
       to_char(sum(decode(substr(completion_time,12,2),'22',1,0)),'999') "22",
       to_char(sum(decode(substr(completion_time,12,2),'23',1,0)),'999') "23"
  from V$ARCHIVED_LOG
   where creator = 'ARCH'
 group by substr(completion_time,1,10)
  order by day
/


ttitle skip 2 left 'MB per day' skip 2

col MB format 9,999,999

select substr(completion_time,1,5) day,
       sum(blocks*block_size/1024/1024) MB
  from V$ARCHIVED_LOG
   where creator = 'ARCH'
 group by substr(completion_time,1,5)
  order by day
/



