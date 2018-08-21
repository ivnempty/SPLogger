--1. Create Linked Server
IF NOT EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'LOCAL')
BEGIN

EXEC master.dbo.sp_addlinkedserver @server = N'LOCAL', @srvproduct=N'SQL Native Client', @provider=N'SQLNCLI10', @datasrc=N'127.0.0.1'
EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname=N'LOCAL',@useself=N'False',@locallogin=NULL,@rmtuser=N'sa',@rmtpassword='itapps'

EXEC master.dbo.sp_serveroption @server=N'LINKEDSELF', @optname=N'rpc out', @optvalue=N'true'
EXEC master.dbo.sp_serveroption @server=N'LINKEDSELF', @optname=N'remote proc transaction promotion', @optvalue=N'false'

END


--2 .Create Log Table
USE [XXXX] --Change XXXX to target database name

CREATE TABLE [dbo].[splog] (
	[id] INT NOT NULL IDENTITY(1,1), 
	[log_time] DATETIME NOT NULL DEFAULT (GETDATE()), 
	[sp_name] NVARCHAR(128), 
	[msg] NVARCHAR(MAX) NOT NULL, 
	[spid] VARCHAR(20)
);

--3. Create Stored Procedure
CREATE procedure [dbo].[sp_log_internal]
    @spid INT,
	@procId INT,
	@msg VARCHAR(MAX)
AS 
BEGIN

	INSERT INTO splog (sp_name, msg, spid)
	VALUES (OBJECT_NAME(procId), @msg, @spid)

END

--4. Create Synonyms
CREATE SYNONYM [dbo].[sp_log] 
FOR [LOCAL].[XXXX].[dbo].[sp_log_internal] --Change XXXX to target database name





--Example
CREATE PROCEDURE [dbo].[sp_execTranSql] 
    @sql NVARCHAR(MAX), 
	@success BIT OUTPUT 
AS 
BEGIN
    DECLARE @msg NVARCHAR(MAX)
    
    EXEC sp_log @@spid, @@PROCID, 'Start sp_execTranSql' 
    
    IF LEN(@sql) > 0 
		BEGIN TRY 
			SET @msg = 'Start Query : ' + @sql
			EXEC sp_log @@spid, @@PROCID, @msg 
			EXEC (@sql)
			
			EXEC sp_log @@spid, @@PROCID, 'End Query' 
			SET @success = 1 
		END TRY 
		BEGIN CATCH 
			SET @success = 0 
			SET @msg = 'Error : ' + ERROR_MESSAGE() 
			EXEC sp_log @@spid, @@PROCID, @msg 
		END CATCH 
    ELSE
        BEGIN
            EXEC sp_log @@spid, @@PROCID, 'No SQL Statement Provided' 
            SET @success = 0 
        END
    
    SET @msg = '' 
    EXEC sp_log @@spid, @@PROCID, 'End sp_execTranSql' 
END


--Usage of above sp
DECLARE @sql NVARCHAR(1000)
DECLARE @success BIT

SET @sql = 
'BEGIN TRY;
	BEGIN TRAN; 
	INSERT INTO splog (logtime, seq, msg) VALUES(GETDATE(),10, ''A'');
	SELECT test FROM splog;
	COMMIT TRAN;
END TRY
BEGIN CATCH;
	ROLLBACK TRAN;
END CATCH;';

--or
SET @sql = 'sp_spWithTran'

EXEC sp_execTranSql @sql, @success OUTPUT
SELECT @success as SpExecResult

IF @success = 1 PRINT 'success'
ELSE PRINT 'failure'

SELECT * FROM splog