####################################################################
# OLTP-EMUL test for Firebird database - configuration parameters.
# Get last version: svn://svn.code.sf.net/p/firebird/code/qa/oltp-emul/
# This file is used for launching ISQL sessions test on POSIX machine
# and relates to Firebird 3.0.
# Parameters are extracted by '1run_oltp_emul.sh' command scenario.
# You can change order of these key-value pairs (move them up and down)
# but do NOT remove or make undefined any of them.
####################################################################

#::::::::::::::::::::::::::::::::::::::
#  SETTINGS FOR LAUNCHING ISQL SESSIONS
#::::::::::::::::::::::::::::::::::::::

# Folder with Firebird console utilities (isql, fbsvcmgr).
# Trailing backslash and double quotes are optional.
# Allows referencing to existing OS environment variable by using dollar sign.
# Samples:
# fbc = $FB40_HOME/bin
# fbc = /opt/firebird.40/bin

fbc  = /opt/fb40ss/bin

# Alias or full path and file name of database.
# If you want this database be created by test itself, specify it as
# FULL PATH and file name. Use only ASCII characters in its name.
# Allows referencing to existing OS environment variable by using dollar sign.
# Use forward slash ("/) in all cases, even when database is on Windows host.
# Samples:
# dbnm = $HOME/data/oltp40.fdb
# dbnm = /var/db/fb40/oltp40.fdb
# dbnm = C:/MIX/firebird/OLTPTEST/oltp40.fdb

dbnm = /var/db/fb40/oltp40.fdb

# Parameters for remote connection and authentication.
# Will be ignored by command scenario if FB runs in embedded mode.

host = localhost
port = 3400
usr =  SYSDBA
pwd =  masterkey

# Folder where to store logs of STDOUT and STDERR redirection for each ISQL session.
# Trailing backslash is optional.
# Allows referencing to existing OS environment variable by using dollar sign.
# Samples:
# tmpdir = /var/tmp/logs.oltp40
# tmpdir = $TMP/logs.oltp40

tmpdir = /var/tmp/logs.oltp40

# Test has several settings that define how much work should be done by each business action in average.
# All of them are considered as separate enumerations: when new ISQL session creates connection, it reads
# "entry" setting about selected workload level and then read all other settings for THIS workload level.
# Parameter 'working_mode' is mnemonic these enumerations. Possible values for this parameter are:
# SMALL_01, SMALL_02, SMALL_03, MEDIUM_01, MEDIUM_02, MEDIUM_03, LARGE_01, LARGE_02, LARGE_03 and HEAVY_01
# In case of launching from several machines ensure that all of them have the same value for this parameter.
# Completely new workload mode can be added to the test by editing file "oltp_main_filling.sql", see there
# sub-section "Definitions for workload modes".
# WARNING: exception will raise on test startup if this value was mistyped and has no correspond data in DB.
# Mnemonic name of workload mode (must be specified without quotes, case-insensitive):

working_mode = small_03

# Time (in minutes) to warm-up database after initial data population
# will finish and before all following operations will be measured:
# Recommended value: at least 30 for Firebird 3.0

warm_time = 30

# Limit (in minutes) to measure operations before test autostop itself:
# Recommended value: at least 60

test_time = 60

# Number of seconds between transactions for pause in each working session
# Default: 0 - no pauses, subsequent Tx starts immediatelly after commit.
# ::: WARNING ::: 
# Ensure that file 'cscript.exe' (Console Windows Script Host) exists
# in the folder from PATH list; usually it is in %SystemRoot%\system32

idle_time = 0

# Do we use mtee.exe utility to provide timestamps for error messages 
# before they are logged in .err files (1=yes, 0=no) ? 
# Windows only. Not implemented for Linux, will be ignored at runtime.

use_mtee = 0

# Does Firebird running in embedded mode ? (1=yes, 0=no)

is_embed = 0

# If you want be able to force all ISQL sessions quickly self-stop their job BEFORE test
# will finish by expiration of <warm_time> + <test_time>, one may to use simple TEXT file
# on server-side, which shoudl be empty before each test launch. Then, if all sessions must
# be immediatelly detached, just open that file in text editor, type any character followed
# by LINE-FEED (or CR/LF on Windows). This is much faster than move database to offline or
# execute 'delete from mon$attachments'. It is also more preferable than kill ISQL processes.
# Format of text file that you have to specify in that case depends on value of parameter 
# "ExternalFileAccess" in firebird.conf:
# 1. When ExternalFileAccess = FULL - write here full path and name of text file that will be 
# queried by every attachment as 'stop flag'.
# 2. When ExternalFileAccess = RESTRICTED - specify only NAME of file, without path.
#
# Do NOT uncomment this parameter, i.e. leave it undefined, if you will launch test every time
# without necessity of its premature cancellation. This is suitable for running scheduled basis.
#
# Default setting: parameter is UNDEFINED, i.e. test will not check content of external file to stop.

# use_external_to_stop = c:/temp/stoptext.txt
# use_external_to_stop = stoptext.txt


# Condition where all ISQL logs should be removed after test will finish.
# Possible values: always | never | if_no_severe_errors
# Option 'always' means that ISQL logs in %tmpdir% will be removed after test finish without any condition.
# Option 'never' means that ISQL logs will be preserved.
# Option 'if_no_severe_errors' means that ISQL logs will be removed if no severe exceptions occured.
# Test considers following exceptions as 'severe':
#   335544558 check_constraint     (Operation violates CHECK constraint @1 on view or table @2).
#   335544347 not_valid            (Validation error for column @1, value "@2").
#   335544665 unique_key_violation (Violation of PRIMARY or UNIQUE KEY constraint "..." on table ...") - if table has unique CONSTRAINT
#   335544349 no_dup               (attempt to store duplicate value (visible to active transactions) in unique index "***") - if table has only unique INDEX

# Recommended value: if_no_severe_errors

remove_isql_logs = if_no_severe_errors


#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#  SETTINGS FOR PREPARING WORKLOAD SQL SCRIPT
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::

# Should SET TRANSACTION statement include NO AUTO UNDO clause (1=yes, 0=no) ? 
# Performance can be increased if this option is set to 1:
# SuperServer:   5 -  6%
# SuperClassic: 10 - 11%
# Recommended value: 1

no_auto_undo = 1

# Add in ISQL logs detailed info for each iteration (select from perf_log...) ?
# Recommended value: 0
# Note: value = 1 significantly increases disk I/O on client machine.
# Do not use it if you are not interested on data of table 'perf_log'.

detailed_info = 0

# Do we add call to mon$ tables before and after each application unit 
# in generated file tmp_random_run.sql (1=yes, 0=no) ? 
# NOTE-1. Value of this parameter will be written by script 1run_oltp_emul.sh
# into table SETTINGS on each new test run by issuing SQL command: 
# update settings set svalue = $mon_unit_perf where mcode='ENABLE_MON_QUERY' and ...;
# Each ISQL session that will create workload will read this value before starting job.
# NOTE-2. More detailed analysis with detalization down to separate stored procedures
# can be achieved by updating setting TRACED_UNITS in the script oltp_main_filling.sql.

mon_unit_perf = 0

# Number of pages for usage during init data population ("-c" switch for ISQL).
# Actual only for CS and SC, will be ignored in SS. Used ONLY during phase of
# initial data population and is IGNORED on main phase of test.
# Make sure that it is LESS than FileSystemCacheThreshold, which default is 65536.

init_buff = 32768


#::::::::::::::::::::::::::::::::::::::
#  SETTINGS FOR TEST DATABASE CREATION
#::::::::::::::::::::::::::::::::::::::

# If database already does exist these settings are ignored.

# Following two settings actual only when database does not exist 
# and should be created by test script itself.
# Valid options for create_with_fw are sync | async
# Value of create_with_sweep should be not less than zero.

create_with_fw = sync

create_with_sweep = 20000


# Should script be paused if database does not exist or its creation
# did not finished properly (e.g. was interrupted; 1=yes; 0=no) ?
# You have to set this parameter to 0 if this batch is launched by 
# scheduler on regular basis. Otherwise it is recommended to set 1.

wait_if_not_exists = 1

# Should script be PAUSED after creation database objects before starting
# initial filling with <init_docs> documents (mostly need only for debug; 1=yes, 0=no) ?
# NOTE: test database will be (re-)created only when it does not contain all necessary objects.
# Command scenario verifies this by searching special record in table 'SEMAPHORES' which should
# be added there at the end-point of building process. If this record is found, test will use 
# existing database and following parameters will be IGNORED.

wait_after_create = 1

# Number of documents, total of all types, for initial data population.
# Command scenario will compare number of existing document with this
# and create new ones only if <init_docs> still greater than obtained.
# Recommended value: 
# 1. For benchmark purposes - at least 30000.
# 2. For regular running on scheduled basis - at least 1000.

init_docs = 500

# Should command scenario - 1run_oltp_emul.sh - be PAUSED after finish creating
# required initial number of documents (see parameter 'init_docs'; 1=yes, 0=no) ?
# Value = 1 can be set if you want to make copy of .fdb and restore later
# this database to 'origin' state. This can save time because of avoiding need
# to create <init_docs> again:

wait_for_copy = 1

# Do we want to create some DEBUG objects (tables, views and procedures)
# in order to:
# 1) make dumps of all data from tables when critical error occurs;
# 2) make miscelaneous diagnostic queries via "Z_" views.
# Value=1 will cause "oltp_misc_debug.sql" be called when build database.
# NB: setting 'QMISM_VERIFY_BITSET' must have bit #2 = 1 when this value = 1.
# (see oltp_main_filling.sql)
# Recommended value: 1

create_with_debug_objects = 1

# Test has two tables which are subject of very intensive modifications: QDistr and QStorned.
# Performance highly depends on time which engine spends on handling DP, PP and index pages
# of this tables - they are "bottlenecks" of schema. Database can be created either with two
# these tables or with several "clones" of them (with the same stucture). The latter allows
# to "split" workload on different areas and reduce low-level lock contention.
# Should heavy-loaded tables (QDistr and QStorned) be splitted on several different tables,
# each one for separate pair of operations that are 'source' and 'target' of storning ?
# Avaliable values: 
# 0 = do NOT split workload on several tables (instead of single QDistr and QStorned);
# 1 = USE several tables with the same structure in order to split heavy workload on them.
# Recommended value: nope (choose yourself and compare).

create_with_split_heavy_tabs = 1

# Whether heavy-loaded table (QDistr or its XQD_* clones) should have only one ("wide")
# compound index or two separate indices (1=yes, 0=no).
# Number of columns in compound index depends on value of two parameters:
# 1) create_with_split_heavy_tabs and 2) create_with_separate_qdistr_idx (this).
# Order of columns is defined by parameter 'create_with_compound_idx_selectivity'.
# Recommended value: nope (choose yourself and compare).

create_with_separate_qdistr_idx = 0

# Parameter 'create_with_compound_columns_order' defines order of fields in the starting part
# of compound index key for the table which is subject to most heavy workload - QDistr. 
# Avaliable options: 'most_selective_first' or 'least_selective_first'.
# When choice = 'most_selective_first' then first column of this index will have selectivity = 1 / <W>,
# where <W> = number of rows in the table 'WARES', depends on selected workload mode.
# Second and third columns will have selectivity about 1/6.
# When choice = 'least_selective_first' then first and second columns will have poor selectivity = 1/6,
# and third column will have selectivity = 1 / <W>.
#
# Actual only when create_with_split_heavy_tabs = 0.
# Recommended value: nope (choose yourself and compare).

create_with_compound_columns_order = most_selective_first

#::::::::::::::::::::::::::::::::::::::
#  SETTINGS FOR FINAL TEST REPORT
#::::::::::::::::::::::::::::::::::::::

# Create report in HTML format (beside plain text one; 1=yes, 0=no) ?
# Windows only. Not implemented for Linux, will be ignored at runtime.

make_html=0

# Do we want to include into final report result of gathering database statistics (1=yes; 0=no) ?
# This operation can take lot of time on big databases. Replace this setting with 0 for skip it.

run_db_statistics = 1

# Do we want to include into final report result of database validation (1=yes; 0=no) ?
# This operation can take lot of time on big databases. Replace this setting with 0 for skip it.

run_db_validation = 1

# Should final report be saved in file with name which contain info about FB, database, test settings ?
# If no, leave this parameter commented. In that case final report will be always saved with the same name.
# If yes, choose format of this name:
# regular   - appropriate for quick found performance degradation, without details of test settings
# benchmark - appropriate for analysis when different settings are applied
# Sample of report name when this parameter = 'regular':
# 20151102_1448_score_06543_build_31236_ss40__3h00m_100_att_fw__on.txt
# Sample of report name when this parameter = 'benchmark':
# ss40_fw_off_split_most__sel_1st_one_index_score_06543_build_31236__3h00m_100_att_20151102_1448.txt

# Available options: regular | benchmark, or leave commented (undefined).

file_name_with_test_params = regular

# Suffix for adding at the end of report name.
# CHANGE this value to some useful info about host location, 
# hardware specifics, FB instance etc.

file_name_this_host_info = no_host_info


# When setting 'postie_send_args' is defined batch will send final report to required e-mail using console
# client POSTIE.EXE with arguments that are defined here plus add auto generated subject and
# attach report. This setting is OPTIONAL. Note: executable 'postie.exe' must be either in one
#  of PATH-list or in ..\util related to current ('src') folder.
# Windows only. Not implemented for Linux, will be ignored at runtime.

#postie_send_args = -esmtp -host:mail.local -from:malert@company.com -to:foo@bar.com -user:malert@company.com -pass:QwerTyuI0p

# Windows only. Should final report be uploaded (1=yes; 0 or undefined = no) ?
# If no, leave this parameter commented. In that case final report will be preserved on local drive, in the folder %tmpdir%.
# If yes, set its value to 1 and make ensure that batch ..\util\upload.bat has command that is able to upload text html content
# to external source and store its result in text log with marking successful finish with phrase containing word 'success'.
# One of such console utility can be found here: http://curl.haxx.se/download.html
# Sample of its usage: curl.exe -F "name=%1" -F "file=@%2" http://some_external_site_as_storage

#upload_report = 0