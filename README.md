# PostgreSQL Week 6 Assignment

## Backups, Point-in-Time Recovery, and Replication

**Student Name:** Joseph Tawa Samuel
**Week:** Week 6
**Database:** `bootcamp`
**PostgreSQL Version:** 18.6
**Operating System:** Windows 11

---

## 1. Assignment Overview

This Week 6 assignment focuses on PostgreSQL database backup, recovery, Point-in-Time Recovery (PITR), and replication.

The purpose of this assignment was to learn how to protect a PostgreSQL database from data loss and how to restore the database after a failure or accidental change.

The main tasks were:

1. Create and verify a logical database backup.
2. Configure PostgreSQL WAL archiving.
3. Create a physical base backup.
4. Prepare for Point-in-Time Recovery.
5. Recover a database to a specific point in time.
6. Set up and monitor streaming replication.

The assignment was completed using PostgreSQL 18.6 on Windows 11. Since the original laboratory instructions used Linux commands, the commands were adapted to work correctly on Windows.

---

# 2. PostgreSQL Environment

PostgreSQL was installed at:

```text
C:\Program Files\PostgreSQL\18\bin
```

The main database used in the assignment was:

```text
bootcamp
```

A separate database was created for testing the backup:

```text
bootcamp_check
```

The backup directory used was:

```text
C:\Users\Master son Jose\backups
```

The WAL archive directory was:

```text
C:\Users\Master son Jose\backups\wal
```

---

# 3. Step One: Create a Logical Backup

The first task was to create a backup of the `bootcamp` database.

First, the backup directories were created:

```cmd
mkdir "%USERPROFILE%\backups"
mkdir "%USERPROFILE%\backups\wal"
```

The PostgreSQL `pg_dump` utility was then used to create a custom-format backup:

```cmd
"C:\Program Files\PostgreSQL\18\bin\pg_dump.exe" -U postgres -Fc -f "%USERPROFILE%\backups\bootcamp.dump" bootcamp
```

The `-U postgres` option specifies the PostgreSQL administrator account.

The `-Fc` option creates the backup in PostgreSQL custom format.

The backup was saved as:

```text
bootcamp.dump
```

---

# 4. Verify the Logical Backup

After creating the backup, I verified that the backup file was valid and contained the expected database objects.

I used:

```cmd
"C:\Program Files\PostgreSQL\18\bin\pg_restore.exe" --list "%USERPROFILE%\backups\bootcamp.dump"
```

This displayed the contents of the backup archive.

The backup contained the `orders` table, its sequence, table data, primary key, and index.

This confirmed that the logical backup was successfully created.

---

# 5. Restore the Backup to a Test Database

To verify that the backup could actually be restored, I created a separate test database called `bootcamp_check`.

The existing test database was removed and recreated:

```cmd
"C:\Program Files\PostgreSQL\18\bin\dropdb.exe" -U postgres bootcamp_check
"C:\Program Files\PostgreSQL\18\bin\createdb.exe" -U postgres bootcamp_check
```

The backup was then restored:

```cmd
"C:\Program Files\PostgreSQL\18\bin\pg_restore.exe" -U postgres -d bootcamp_check "%USERPROFILE%\backups\bootcamp.dump"
```

After the restoration, I checked the tables:

```cmd
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d bootcamp_check -c "\dt"
```

The `orders` table was successfully restored.

I then checked the number of records:

```cmd
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d bootcamp_check -c "SELECT COUNT(*) FROM orders;"
```

The result was:

```text
2000000
```

This confirmed that the backup was successfully restored and that all 2,000,000 records in the `orders` table were recovered.

---

# 6. Step Two: Configure WAL Archiving

The next part of the assignment was to configure Write-Ahead Logging (WAL) archiving.

The PostgreSQL configuration file is located at:

```text
C:\Program Files\PostgreSQL\18\data\postgresql.conf
```

The following settings were added to the configuration file:

```conf
wal_level = replica
archive_mode = on
archive_command = 'copy "%p" "C:\\Users\\Master son Jose\\backups\\wal\\%f"'
```

### Explanation

`wal_level = replica` enables the WAL information required for replication and recovery.

`archive_mode = on` enables WAL archiving.

`archive_command` tells PostgreSQL where to copy completed WAL files.

The WAL files are stored in:

```text
C:\Users\Master son Jose\backups\wal
```

After changing `postgresql.conf`, PostgreSQL must be restarted for `archive_mode` to become active.

---

# 7. Verify WAL Configuration

The configuration was checked using:

```cmd
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d bootcamp -c "SHOW wal_level; SHOW archive_mode; SHOW archive_command;"
```

The expected configuration is:

```text
wal_level = replica
archive_mode = on
archive_command = copy "%p" "C:\Users\Master son Jose\backups\wal\%f"
```

The WAL archive directory can be checked with:

```cmd
dir "%USERPROFILE%\backups\wal"
```

This allows the archived WAL files to be monitored.

---

# 8. Step Three: Create a Physical Base Backup

A physical base backup is a copy of the PostgreSQL database files that can be used as the starting point for recovery or replication.

The base backup was created using PostgreSQL's `pg_basebackup` utility:

```cmd
"C:\Program Files\PostgreSQL\18\bin\pg_basebackup.exe" -U postgres -D "%USERPROFILE%\backups\base_backup" -Fp -Xs -P
```

The backup is stored in:

```text
C:\Users\Master son Jose\backups\base_backup
```

### Command options

`-U postgres` specifies the PostgreSQL user.

`-D` specifies the destination directory.

`-Fp` creates the backup in plain format.

`-Xs` includes the required WAL data.

`-P` displays the progress of the backup.

---

# 9. Step Four: Point-in-Time Recovery

Point-in-Time Recovery, also known as PITR, allows PostgreSQL to restore a database to a specific moment in time.

PITR uses:

* A physical base backup.
* Archived WAL files.
* A recovery target.

To demonstrate a database change, a test table can be created:

```sql
CREATE TABLE IF NOT EXISTS pitr_test (
    id SERIAL PRIMARY KEY,
    message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

A test record can then be inserted:

```sql
INSERT INTO pitr_test (message)
VALUES ('PITR test record');
```

The current time can be recorded:

```sql
SELECT now();
```

The current WAL position can also be checked:

```sql
SELECT pg_current_wal_lsn();
```

A WAL switch can be triggered using:

```sql
SELECT pg_switch_wal();
```

These commands demonstrate how PostgreSQL records database changes in WAL.

---

# 10. PITR Recovery Process

A complete Point-in-Time Recovery process follows these general steps:

1. Create a physical base backup.
2. Enable WAL archiving.
3. Continue generating and archiving WAL files.
4. Record the time of important database changes.
5. Simulate a database failure or unwanted change.
6. Restore the base backup.
7. Provide PostgreSQL with the archived WAL files.
8. Specify the required recovery target.
9. Allow PostgreSQL to replay the WAL files.
10. Stop recovery at the selected point in time.

For example, a recovery target can be specified by time:

```conf
recovery_target_time = '2026-10-08 04:30:00'
```

The recovery target should be replaced with the actual time required for the recovery operation.

---

# 11. Step Five: Streaming Replication

Streaming replication allows a PostgreSQL standby server to continuously receive WAL records from the primary server.

The primary PostgreSQL server must have:

```conf
wal_level = replica
```

The primary server also needs to allow replication connections through PostgreSQL authentication settings.

A physical base backup can be used as the starting point for creating the standby server.

The replication status on the primary server can be checked using:

```cmd
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d bootcamp -c "SELECT * FROM pg_stat_replication;"
```

This command shows information about connected standby servers.

---

# 12. Check Whether a Server Is in Recovery

The following command checks whether the PostgreSQL server is currently operating in recovery mode:

```cmd
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d bootcamp -c "SELECT pg_is_in_recovery();"
```

On a primary server, the expected result is:

```text
false
```

On a standby server, the expected result is:

```text
true
```

This provides a simple way to determine whether a PostgreSQL server is functioning as a primary or standby.

---

# 13. Monitor Replication

Replication can be monitored on the primary server with:

```sql
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    sync_state
FROM pg_stat_replication;
```

This provides information about the standby connection and its current replication state.

---

# 14. Combined Week 6 Script

To make the Windows implementation easier to run and manage, the main commands were combined into one batch file:

```text
week6_lab.bat
```

The batch file contains the commands for:

* Creating backup directories.
* Creating the logical backup.
* Verifying the backup.
* Restoring the backup.
* Checking the restored database.
* Checking WAL configuration.
* Creating a physical base backup.
* Preparing PITR testing.
* Checking recovery status.
* Checking replication status.

The batch file is included in this repository together with this README file.

---

# 15. Results

The logical backup and restore process was successfully completed.

The following results were verified:

* PostgreSQL 18.6 was used successfully.
* The `bootcamp` database was backed up.
* The `bootcamp.dump` file was successfully created.
* The backup archive was successfully inspected.
* The `bootcamp_check` database was successfully restored.
* The `orders` table was successfully restored.
* The restored `orders` table contained **2,000,000 records**.
* WAL archiving was configured.
* A physical base backup was prepared using `pg_basebackup`.
* PITR procedures were prepared and tested using WAL commands.
* PostgreSQL replication status and recovery status can be monitored using PostgreSQL system functions.

---

# 16. Challenges and Solutions

The original assignment instructions contained Linux commands such as:

```text
mkdir -p
cp
~/backups
```

Because I was working on Windows 11, these commands were converted to Windows-compatible commands.

For example, the Linux backup path:

```text
~/backups
```

was changed to:

```text
C:\Users\Master son Jose\backups
```

Another issue occurred when `pg_dump` attempted to use the Windows username as the PostgreSQL username.

The problem was solved by explicitly specifying the PostgreSQL administrator account:

```cmd
-U postgres
```

After making this change, the database backup was created successfully.

---

# 17. Conclusion

This Week 6 assignment provided practical experience with PostgreSQL backup, recovery, WAL archiving, Point-in-Time Recovery, and replication.

I learned how to create a logical backup using `pg_dump`, inspect and restore the backup using `pg_restore`, and verify the restored data using SQL queries.

I also learned how WAL archiving supports database recovery and how a physical base backup can be created using `pg_basebackup`.

The assignment also introduced Point-in-Time Recovery and streaming replication, including the PostgreSQL commands used to monitor recovery and replication status.

Overall, this exercise improved my understanding of PostgreSQL disaster recovery and database availability techniques.
