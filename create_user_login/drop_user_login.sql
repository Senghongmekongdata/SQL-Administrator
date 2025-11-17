-- ===================================================================
-- Drop SQL Server Login and Associated Database User
-- (Now with a "force disconnect" for active sessions)
-- ===================================================================
--
-- !! IMPORTANT !!
-- Please replace the 2 placeholder values in the section below
-- before running this script.
--
-- ===================================================================

-- Start a single execution batch
BEGIN

    -- ==== CONFIGURATION ====
    DECLARE @DatabaseName NVARCHAR(128) = N'CANADIABANK_DB'; -- 1. The database the user has access to
    DECLARE @LoginName    NVARCHAR(128) = N'senghong.soeung';     -- 2. The username of the login to drop
    -- ==== END CONFIGURATION ====


    -- Declare variables
    DECLARE @SqlStatement NVARCHAR(MAX);
    DECLARE @ErrorMessage NVARCHAR(MAX);

    -- Check if the target database exists
    IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @DatabaseName)
    BEGIN
        PRINT 'Error: Database [' + @DatabaseName + '] does not exist. Cannot check for user.';
        -- We can still try to drop the login, so we don't GOTO EndScript
    END
    ELSE
    BEGIN
        -- Step 1 & 2: Revert ownership and drop the database-level user
        -- This dynamic SQL runs inside the target database
        SET @SqlStatement = N'USE ' + QUOTENAME(@DatabaseName) + N';' + CHAR(13) + CHAR(10) +
                            N'DECLARE @DBUserPrincipalId INT = DATABASE_PRINCIPAL_ID(' + QUOTENAME(@LoginName, '''') + N');' + CHAR(13) + CHAR(10) +
                            N'DECLARE @DBOwnerSid VARBINARY(85) = (SELECT owner_sid FROM sys.databases WHERE name = ' + QUOTENAME(@DatabaseName, '''') + N');' + CHAR(13) + CHAR(10) +
                            N'DECLARE @LoginSid VARBINARY(85) = SUSER_SID(' + QUOTENAME(@LoginName, '''') + N');' + CHAR(13) + CHAR(10) +
                            CHAR(13) + CHAR(10) +
                            N'-- Step 1: Revert Database Ownership (if this login is the owner)' + CHAR(13) + CHAR(10) +
                            N'IF @DBOwnerSid = @LoginSid' + CHAR(13) + CHAR(10) +
                            N'BEGIN' + CHAR(13) + CHAR(10) +
                            N'    PRINT ''Login is database owner. Reverting ownership to [sa]...'';' + CHAR(13) + CHAR(10) +
                            N'    ALTER AUTHORIZATION ON DATABASE::' + QUOTENAME(@DatabaseName) + N' TO sa;' + CHAR(13) + CHAR(10) +
                            N'END;' + CHAR(13) + CHAR(10) +
                            CHAR(13) + CHAR(10) +
                            N'-- Step 2: Drop the Database User' + CHAR(13) + CHAR(10) +
                            N'IF @DBUserPrincipalId IS NOT NULL' + CHAR(13) + CHAR(10) +
                            N'BEGIN' + CHAR(13) + CHAR(10) +
                            N'    PRINT ''Dropping user [' + @LoginName + '] from database [' + @DatabaseName + ']...'';' + CHAR(13) + CHAR(10) +
                            N'    DROP USER ' + QUOTENAME(@LoginName) + N';' + CHAR(13) + CHAR(10) +
                            N'END' + CHAR(13) + CHAR(10) +
                            N'ELSE' + CHAR(13) + CHAR(10) +
                            N'BEGIN' + CHAR(13) + CHAR(10) +
                            N'    PRINT ''User [' + @LoginName + '] does not exist in database [' + @DatabaseName + ']. Skipping user drop.'';' + CHAR(13) + CHAR(10) +
                            N'END;'

        -- Execute the SQL to drop the user
        BEGIN TRY
            EXEC sp_executesql @SqlStatement;
        END TRY
        BEGIN CATCH
            SET @ErrorMessage = ERROR_MESSAGE();
            PRINT 'An error occurred while dropping the user or reverting ownership: ' + @ErrorMessage;
            PRINT 'Login may not be dropped if user removal failed.';
            GOTO EndScript;
        END CATCH
    END

    -- Step 2.5: Kill any active connections for the login
    USE master;
    PRINT 'Checking for active connections for [' + @LoginName + ']...';
    DECLARE @KillSql NVARCHAR(MAX) = N'';

    -- Find all session IDs (spid) for the login
    SELECT @KillSql = @KillSql + N'KILL ' + CONVERT(NVARCHAR(10), session_id) + N'; '
    FROM sys.dm_exec_sessions
    WHERE login_name = @LoginName;

    IF LEN(@KillSql) > 0
    BEGIN
        PRINT 'Active connections found. Terminating sessions...';
        PRINT 'Executing: ' + @KillSql;
        BEGIN TRY
            EXEC sp_executesql @KillSql;
            PRINT 'Sessions terminated.';
        END TRY
        BEGIN CATCH
            SET @ErrorMessage = ERROR_MESSAGE();
            PRINT 'Could not kill active sessions: ' + @ErrorMessage;
            PRINT 'The DROP LOGIN command will likely fail.';
        END CATCH
    END
    ELSE
    BEGIN
        PRINT 'No active connections found.';
    END

    -- Step 3: Drop the Server Login
    IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @LoginName)
    BEGIN
        BEGIN TRY
            SET @SqlStatement = N'DROP LOGIN ' + QUOTENAME(@LoginName);
            PRINT 'Dropping server login [' + @LoginName + ']...';
            EXEC sp_executesql @SqlStatement;
            PRINT 'Login [' + @LoginName + '] successfully dropped.';
        END TRY
        BEGIN CATCH
            SET @ErrorMessage = ERROR_MESSAGE();
            PRINT 'Failed to drop login: ' + @ErrorMessage;
        END CATCH
    END
    ELSE
    BEGIN
        PRINT 'Server login [' + @LoginName + '] does not exist. Skipping login drop.';
    END

    EndScript:
    PRINT 'Execution finished.';

END; -- End of single execution batch
GO
