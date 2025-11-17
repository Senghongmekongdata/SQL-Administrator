
-- ===================================================================
-- Create SQL Server Login, Database User, and Grant Full Permissions
-- ===================================================================
--
-- !! IMPORTANT !!
-- Please replace the 3 placeholder values in the section below
-- before running this script.
--
-- ===================================================================

-- Start a single execution batch
BEGIN

    -- ==== CONFIGURATION ====
    DECLARE @DatabaseName NVARCHAR(128) = N'CANADIABANK_DB'; -- 1. The database you want to grant access to
    DECLARE @LoginName    NVARCHAR(128) = N'senghong.soeung';     -- 2. The desired username for the new login
    DECLARE @Password     NVARCHAR(128) = N'@hong050697'; -- 3. A strong, complex password
    -- ==== END CONFIGURATION ====


    -- Declare variables for dynamic SQL
    DECLARE @SqlStatement NVARCHAR(MAX);
    DECLARE @ErrorMessage NVARCHAR(MAX);

    -- Use 'master' database to create the server-level login
    USE master;

    -- Step 1: Create the Server Login
    -- This allows the user to connect to the SQL Server instance.
    IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @LoginName)
    BEGIN
        BEGIN TRY
            SET @SqlStatement = N'CREATE LOGIN ' + QUOTENAME(@LoginName) +
                                N' WITH PASSWORD = ' + QUOTENAME(@Password, '''') +
                                N', CHECK_EXPIRATION = OFF, CHECK_POLICY = ON;';
            PRINT 'Creating server login [' + @LoginName + ']...';
            EXEC sp_executesql @SqlStatement;
        END TRY
        BEGIN CATCH
            SET @ErrorMessage = ERROR_MESSAGE();
            PRINT 'Failed to create login: ' + @ErrorMessage;
            -- Exit script if login creation fails
            GOTO EndScript;
        END CATCH
    END
    ELSE
    BEGIN
        PRINT 'Server login [' + @LoginName + '] already exists. Skipping creation.';
    END

    -- Check if the target database exists
    IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @DatabaseName)
    BEGIN
        PRINT 'Error: Database [' + @DatabaseName + '] does not exist. Cannot proceed.';
        GOTO EndScript;
    END

    -- Step 2 & 3: Switch to the target database, create the user, and grant permissions
    -- We build dynamic SQL to execute within the context of the *target* database.
    SET @SqlStatement = N'USE ' + QUOTENAME(@DatabaseName) + N';' + CHAR(13) + CHAR(10) +
                        N'-- Step 2: Create the Database User' + CHAR(13) + CHAR(10) +
                        N'IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = ' + QUOTENAME(@LoginName, '''') + N')' + CHAR(13) + CHAR(10) +
                        N'BEGIN' + CHAR(13) + CHAR(10) +
                        N'    PRINT ''Creating user [' + @LoginName + '] in database [' + @DatabaseName + ']...'';' + CHAR(13) + CHAR(10) +
                        N'    CREATE USER ' + QUOTENAME(@LoginName) + N' FOR LOGIN ' + QUOTENAME(@LoginName) + N';' + CHAR(13) + CHAR(10) +
                        N'END' + CHAR(13) + CHAR(10) +
                        N'ELSE' + CHAR(13) + CHAR(10) +
                        N'BEGIN' + CHAR(13) + CHAR(10) +
                        N'    PRINT ''User [' + @LoginName + '] already exists in database [' + @DatabaseName + '].'';' + CHAR(13) + CHAR(10) +
                        N'END;' + CHAR(13) + CHAR(10) +
                        N'' + CHAR(13) + CHAR(10) +
                        N'-- Step 3: Grant Full Functionality (db_owner)' + CHAR(13) + CHAR(10) +
                        N'PRINT ''Granting db_owner permissions to [' + @LoginName + ']...'';' + CHAR(13) + CHAR(10) +
                        N'ALTER ROLE db_owner ADD MEMBER ' + QUOTENAME(@LoginName) + N';' + CHAR(13) + CHAR(10) +
                        N'PRINT ''Script completed successfully.'';' + CHAR(13) + CHAR(10) +
                        N'PRINT ''Login [' + @LoginName + '] now has full (db_owner) permissions on [' + @DatabaseName + '].'';'

    -- Execute the dynamic SQL
    BEGIN TRY
        EXEC sp_executesql @SqlStatement;
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();
        PRINT 'An error occurred while creating the user or granting permissions: ' + @ErrorMessage;
    END CATCH

    EndScript:
    PRINT 'Execution finished.';

END; -- End of single execution batch
GO

