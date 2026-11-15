-- =============================================================================
-- PROYECTO FINAL — ADMINISTRACIÓN DE BASES DE DATOS
-- PROYECTO: SISTEMA DE RESERVAS DE GIMNASIO
-- ARCHIVO: 05_auditoria.sql
-- DESCRIPCIÓN: CONFIGURACIÓN DE SQL SERVER AUDIT Y BITÁCORA TRIGGER DE PAGOS
-- =============================================================================

-- =============================================================================
-- 1. LIMPIEZA | ELIMINA ESPECIFICACIONES PREVIAS PARA REPETIR EL SCRIPT
-- =============================================================================
USE GimnasioDB;
GO

IF EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = N'DAS_Gimnasio')
BEGIN
    ALTER DATABASE AUDIT SPECIFICATION DAS_Gimnasio WITH (STATE = OFF);
    DROP DATABASE AUDIT SPECIFICATION DAS_Gimnasio;
END
GO

USE master;
GO

IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = N'SAS_Gimnasio_Accesos')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION SAS_Gimnasio_Accesos WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION SAS_Gimnasio_Accesos;
END

IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = N'Audit_Gimnasio')
BEGIN
    ALTER SERVER AUDIT Audit_Gimnasio WITH (STATE = OFF);
    DROP SERVER AUDIT Audit_Gimnasio;
END
GO

-- =============================================================================
-- 2. AUDITORÍA DE SERVIDOR | DESTINO EN CARPETA DE DOCKER Y ACCESOS
-- =============================================================================
CREATE SERVER AUDIT Audit_Gimnasio
TO FILE (
    FILEPATH = N'/audit/GimnasioDB/',
    MAXSIZE = 50 MB,
    MAX_FILES = 12
)
WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);
GO

ALTER SERVER AUDIT Audit_Gimnasio WITH (STATE = ON);
GO

CREATE SERVER AUDIT SPECIFICATION SAS_Gimnasio_Accesos
FOR SERVER AUDIT Audit_Gimnasio
    ADD (FAILED_LOGIN_GROUP),
    ADD (SERVER_PRINCIPAL_CHANGE_GROUP),
    ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP)
WITH (STATE = ON);
GO

-- VERIFICACIÓN DEL ESTADO DE LA AUDITORÍA DE SERVIDOR
SELECT name, status_desc, audit_file_path
FROM   sys.dm_server_audit_status
WHERE  name = N'Audit_Gimnasio';
GO

-- =============================================================================
-- 3. AUDITORÍA DE BASE DE DATOS | DATOS SENSIBLES Y CAMBIOS DE SEGURIDAD
-- =============================================================================
USE GimnasioDB;
GO

CREATE DATABASE AUDIT SPECIFICATION DAS_Gimnasio
FOR SERVER AUDIT Audit_Gimnasio
    ADD (INSERT, UPDATE, DELETE ON OBJECT::finanzas.pago BY public),
    ADD (UPDATE, DELETE ON OBJECT::socios.membresia BY public),
    ADD (UPDATE, DELETE ON OBJECT::socios.socio BY public),
    ADD (SCHEMA_OBJECT_CHANGE_GROUP),
    ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP),
    ADD (DATABASE_PERMISSION_CHANGE_GROUP),
    ADD (DATABASE_OBJECT_PERMISSION_CHANGE_GROUP)
WITH (STATE = ON);
GO

-- =============================================================================
-- 4. BITÁCORA | auditoria.log_pago (VALORES ANTERIORES Y NUEVOS)
-- =============================================================================
IF OBJECT_ID(N'auditoria.log_pago') IS NULL
    CREATE TABLE auditoria.log_pago (
        id_log          INT IDENTITY(1,1) NOT NULL,
        id_pago         INT               NOT NULL,
        accion          VARCHAR(10)       NOT NULL,
        monto_anterior  NUMERIC(8,2)      NULL,
        monto_nuevo     NUMERIC(8,2)      NULL,
        estado_anterior VARCHAR(20)       NULL,
        estado_nuevo    VARCHAR(20)       NULL,
        usuario         SYSNAME           NOT NULL CONSTRAINT DF_log_pago_usuario DEFAULT (ORIGINAL_LOGIN()),
        fecha           DATETIME2         NOT NULL CONSTRAINT DF_log_pago_fecha DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_log_pago PRIMARY KEY (id_log)
    );
GO

CREATE OR ALTER TRIGGER finanzas.trg_pago_auditoria
ON finanzas.pago
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.log_pago (id_pago, accion, monto_anterior, monto_nuevo, estado_anterior, estado_nuevo)
    SELECT d.id_pago,
           CASE WHEN i.id_pago IS NULL THEN 'DELETE' ELSE 'UPDATE' END,
           d.monto, i.monto, d.estado_pago, i.estado_pago
    FROM   deleted d
    LEFT JOIN inserted i ON i.id_pago = d.id_pago;
END;
GO

-- =============================================================================
-- 5. PRUEBAS | GENERACIÓN DE EVENTOS AUDITABLES (REVERTIDOS)
-- =============================================================================
BEGIN TRANSACTION;
UPDATE finanzas.pago SET estado_pago = 'Anulado' WHERE id_pago = 1;
SELECT TOP (1) * FROM auditoria.log_pago ORDER BY id_log DESC;
ROLLBACK TRANSACTION;

BEGIN TRANSACTION;
UPDATE socios.membresia SET estado_membresia = estado_membresia WHERE id_membresia = 1;
UPDATE socios.socio SET telefono = telefono WHERE id_socio = 1;
ROLLBACK TRANSACTION;

DENY SELECT ON OBJECT::socios.plan_membresia TO rol_reportes;
REVOKE SELECT ON OBJECT::socios.plan_membresia FROM rol_reportes;
GO

-- =============================================================================
-- 6. CONSULTA DE LOGS | LECTURA DIRECTA DESDE /audit/GimnasioDB/
-- =============================================================================
WAITFOR DELAY '00:00:02';

USE master;
GO

SELECT TOP (50) event_time, action_id, succeeded,
       server_principal_name AS usuario,
       database_name AS base_datos,
       schema_name AS esquema,
       object_name AS objeto,
       statement AS sentencia
FROM   sys.fn_get_audit_file(N'/audit/GimnasioDB/*.sqlaudit', DEFAULT, DEFAULT)
WHERE  database_name = N'GimnasioDB'
ORDER BY event_time DESC;

SELECT action_id, COUNT(*) AS eventos
FROM   sys.fn_get_audit_file(N'/audit/GimnasioDB/*.sqlaudit', DEFAULT, DEFAULT)
WHERE  database_name = N'GimnasioDB'
GROUP BY action_id
ORDER BY eventos DESC;
GO