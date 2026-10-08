@echo off
setlocal EnableExtensions

title PostgreSQL Week 6 - Backups, PITR and Replication

REM ============================================================
REM POSTGRESQL WEEK 6 LAB
REM Backups, Point-in-Time Recovery, and Replication
REM ============================================================

REM PostgreSQL installation
set "PG_BIN=C:\Program Files\PostgreSQL\18\bin"

REM Backup locations
set "BACKUP_DIR=%USERPROFILE%\backups"
set "WAL_DIR=%USERPROFILE%\backups\wal"
set "BASE_DIR=%USERPROFILE%\backups\base_backup"

REM Database
set "DB=bootcamp"
set "TEST_DB=bootcamp_check"

echo.
echo ============================================================
echo       POSTGRESQL WEEK 6 LAB
echo       Backups, PITR and Replication
echo ============================================================
echo.

REM ============================================================
REM STEP 1 - CREATE BACKUP DIRECTORIES
REM ============================================================

echo [STEP 1] Creating backup directories...
echo.

if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
if not exist "%WAL_DIR%" mkdir "%WAL_DIR%"

echo Backup directory:
echo %BACKUP_DIR%

echo WAL directory:
echo %WAL_DIR%

echo.
pause

REM ============================================================
REM STEP 2 - LOGICAL BACKUP
REM ============================================================

cls

echo ============================================================
echo STEP 2 - CREATING LOGICAL BACKUP
echo ============================================================
echo.

echo Database:
echo %DB%

echo.
echo The PostgreSQL password will be requested.
echo.

"%PG_BIN%\pg_dump.exe" -U postgres -Fc -f "%BACKUP_DIR%\bootcamp.dump" "%DB%"

if errorlevel 1 (
    echo.
    echo ERROR: Logical backup failed.
    echo.
    pause
    exit /b 1
)

echo.
echo SUCCESS: Logical backup created.
echo.
echo Backup file:
echo %BACKUP_DIR%\bootcamp.dump

echo.
pause

REM ============================================================
REM STEP 3 - VERIFY LOGICAL BACKUP
REM ============================================================

cls

echo ============================================================
echo STEP 3 - VERIFYING LOGICAL BACKUP
echo ============================================================
echo.

"%PG_BIN%\pg_restore.exe" --list "%BACKUP_DIR%\bootcamp.dump"

if errorlevel 1 (
    echo.
    echo ERROR: Backup verification failed.
    echo.
    pause
    exit /b 1
)

echo.
echo SUCCESS: Backup archive can be read.
echo.
pause

REM ============================================================
REM STEP 4 - RESTORE BACKUP INTO TEST DATABASE
REM ============================================================

cls

echo ============================================================
echo STEP 4 - RESTORE VERIFICATION
echo ============================================================
echo.

echo Removing old test database if it exists...
"%PG_BIN%\dropdb.exe" -U postgres --if-exists "%TEST_DB%"

echo.
echo Creating fresh test database...
"%PG_BIN%\createdb.exe" -U postgres "%TEST_DB%"

if errorlevel 1 (
    echo.
    echo ERROR: Could not create test database.
    echo.
    pause
    exit /b 1
)

echo.
echo Restoring backup into %TEST_DB%...
echo.

"%PG_BIN%\pg_restore.exe" -U postgres -d "%TEST_DB%" "%BACKUP_DIR%\bootcamp.dump"

if errorlevel 1 (
    echo.
    echo WARNING: Restore returned an error.
    echo Check the message above.
    echo.
    pause
    exit /b 1
)

echo.
echo SUCCESS: Backup restored.
echo.

echo Checking restored tables...
"%PG_BIN%\psql.exe" -U postgres -d "%TEST_DB%" -c "\dt"

echo.
echo Checking number of restored rows...
"%PG_BIN%\psql.exe" -U postgres -d "%TEST_DB%" -c "SELECT COUNT(*) FROM orders;"

echo.
pause

REM ============================================================
REM STEP 5 - CHECK CURRENT POSTGRESQL CONFIGURATION
REM ============================================================

cls

echo ============================================================
echo STEP 5 - WAL CONFIGURATION
echo ============================================================
echo.

echo Checking PostgreSQL WAL settings...
echo.

"%PG_BIN%\psql.exe" -U postgres -d "%DB%" -c "SHOW wal_level; SHOW archive_mode; SHOW archive_command;"

echo.
echo ============================================================
echo IMPORTANT
echo ============================================================
echo.
echo For Windows PostgreSQL 18, the expected settings are:
echo.
echo wal_level = replica
echo archive_mode = on
echo archive_command = copy command pointing to:
echo %WAL_DIR%
echo.
echo If archive_mode is OFF, PostgreSQL must be restarted
echo after editing postgresql.conf.
echo.
pause

REM ============================================================
REM STEP 6 - CHECK WAL DIRECTORY
REM ============================================================

cls

echo ============================================================
echo STEP 6 - WAL ARCHIVE DIRECTORY
echo ============================================================
echo.

echo WAL directory:
echo %WAL_DIR%

echo.
dir "%WAL_DIR%"

echo.
echo WAL files may not appear until PostgreSQL generates
echo WAL activity after archiving is enabled.
echo.
pause

REM ============================================================
REM STEP 7 - CREATE BASE BACKUP
REM ============================================================

cls

echo ============================================================
echo STEP 7 - PHYSICAL BASE BACKUP
echo ============================================================
echo.

echo Destination:
echo %BASE_DIR%

echo.

if exist "%BASE_DIR%" (
    echo A previous base backup exists.
    echo It will be removed before creating a new one.
    echo.
    rmdir /s /q "%BASE_DIR%"
)

mkdir "%BASE_DIR%"

echo.
echo Starting pg_basebackup...
echo.
echo PostgreSQL password will be requested.
echo.

"%PG_BIN%\pg_basebackup.exe" -U postgres -D "%BASE_DIR%" -Fp -Xs -P

if errorlevel 1 (
    echo.
    echo ERROR: Base backup failed.
    echo.
    pause
    exit /b 1
)

echo.
echo SUCCESS: Base backup created.
echo.
echo Base backup location:
echo %BASE_DIR%

echo.
pause

REM ============================================================
REM STEP 8 - POINT-IN-TIME RECOVERY INFORMATION
REM ============================================================

cls

echo ============================================================
echo STEP 8 - POINT-IN-TIME RECOVERY
echo ============================================================
echo.

echo Recording current database time...
echo.

"%PG_BIN%\psql.exe" -U postgres -d "%DB%" -c "SELECT now() AS recovery_reference_time;"

echo.
echo Current WAL location:
echo.

"%PG_BIN%\psql.exe" -U postgres -d "%DB%" -c "SELECT pg_current_wal_lsn() AS current_wal_lsn;"

echo.
echo Creating a PITR demonstration table...
echo.

"%PG_BIN%\psql.exe" -U postgres -d "%DB%" -c "CREATE TABLE IF NOT EXISTS pitr_test (id SERIAL PRIMARY KEY, message TEXT, created_at TIMESTAMPTZ DEFAULT now());"

echo.
echo Inserting a test record...
echo.

"%PG_BIN%\psql.exe" -U postgres -d "%DB%" -c "INSERT INTO pitr_test (message) VALUES ('Data created before simulated disaster');"

echo.
echo Recording valid data time...
echo.

"%PG_BIN%\psql.exe" -U postgres -d "%DB%" -c "SELECT now() AS valid_data_time;"

echo.
echo Forcing a WAL switch...
echo.

"%PG_BIN%\psql.exe" -U postgres -d "%DB%" -c "SELECT pg_switch_wal();"

echo.
echo PITR preparation complete.
echo.
echo NOTE:
echo A real PITR recovery should be performed against a separate
echo PostgreSQL data directory or test PostgreSQL instance.
echo The original bootcamp database is NOT destroyed by this lab.
echo.
pause

REM ============================================================
REM STEP 9 - STREAMING REPLICATION INFORMATION
REM ============================================================

cls

echo ============================================================
echo STEP 9 - STREAMING REPLICATION
echo ============================================================
echo.

echo Checking whether this server is in recovery...
echo.

"%PG_BIN%\psql.exe" -U postgres -d "%DB%" -c "SELECT pg_is_in_recovery();"

echo.
echo Checking replication connections on the primary...
echo.

"%PG_BIN%\psql.exe" -U postgres -d "%DB%" -c "SELECT pid, usename, application_name, client_addr, state, sync_state FROM pg_stat_replication;"

echo.
echo ============================================================
echo STREAMING REPLICATION COMMAND
echo ============================================================
echo.
echo A standby can be initialized from a separate PostgreSQL
echo instance using:
echo.
echo pg_basebackup -U postgres -D standby_data -Fp -Xs -P -R
echo.
echo The -R option creates standby connection configuration.
echo.
echo A real standby requires a SECOND PostgreSQL instance/server.
echo.
pause

REM ============================================================
REM STEP 10 - FINAL VERIFICATION
REM ============================================================

cls

echo ============================================================
echo FINAL WEEK 6 VERIFICATION
echo ============================================================
echo.

echo Original database:
echo %DB%

echo.
echo Test database:
echo %TEST_DB%

echo.
echo Logical backup:
echo %BACKUP_DIR%\bootcamp.dump

echo.
echo WAL directory:
echo %WAL_DIR%

echo.
echo Base backup:
echo %BASE_DIR%

echo.
echo Checking restored row count one final time...
echo.

"%PG_BIN%\psql.exe" -U postgres -d "%TEST_DB%" -c "SELECT COUNT(*) AS restored_orders FROM orders;"

echo.
echo ============================================================
echo LAB SUMMARY
echo ============================================================
echo.
echo [1] Logical backup created
echo [2] Backup archive verified
echo [3] Backup restored into test database
echo [4] Restored orders table verified
echo [5] WAL configuration checked
echo [6] Base backup attempted
echo [7] PITR preparation demonstrated
echo [8] Streaming replication monitoring checked
echo.
echo ============================================================
echo       WEEK 6 LAB FINISHED
echo ============================================================
echo.

pause
endlocal