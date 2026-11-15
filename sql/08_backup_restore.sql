-- =============================================================================
-- PROYECTO FINAL — ADMINISTRACIÓN DE BASES DE DATOS
-- PROYECTO: SISTEMA DE RESERVAS DE GIMNASIO
-- ARCHIVO: 08_backup_restore.sql
-- DESCRIPCIÓN: ESTRATEGIA FULL, DIFERENCIAL, LOG Y POINT-IN-TIME EN DOCKER
-- =============================================================================

USE master;
GO

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'GYM_Backup_Log')
    EXEC msdb.dbo.sp_update_job @job_name = N'GYM_Backup_Log', @enabled = 0;
GO

-- =============================================================================
-- 1. DATOS DE PRUEBA | COPIA DE PAGOS PARA SIMULAR DESASTRE
-- =============================================================================
DROP TABLE IF EXISTS GimnasioDB.dbo.prueba_pagos;
SELECT * INTO GimnasioDB.dbo.prueba_pagos FROM GimnasioDB.finanzas.pago;
GO

-- =============================================================================
-- 2. CADENA DE RESPALDOS | FULL, DIFERENCIAL, LOGS Y PUNTO DE CORTE
-- =============================================================================
BACKUP DATABASE GimnasioDB 
TO DISK = N'/backup/GimnasioDB/GimnasioDB_DEMO_FULL.bak'
WITH COMPRESSION, CHECKSUM, INIT, NAME = N'GimnasioDB DEMO completo';
GO

INSERT INTO GimnasioDB.dbo.prueba_pagos (id_membresia, id_metodo_pago, monto, fecha_pago, estado_pago)
SELECT TOP (10) id_membresia, id_metodo_pago, monto, SYSDATETIME(), estado_pago
FROM   GimnasioDB.finanzas.pago ORDER BY id_pago;
GO

BACKUP DATABASE GimnasioDB 
TO DISK = N'/backup/GimnasioDB/GimnasioDB_DEMO_DIFF.bak'
WITH DIFFERENTIAL, COMPRESSION, CHECKSUM, INIT, NAME = N'GimnasioDB DEMO diferencial';
GO

INSERT INTO GimnasioDB.dbo.prueba_pagos (id_membresia, id_metodo_pago, monto, fecha_pago, estado_pago)
SELECT TOP (10) id_membresia, id_metodo_pago, monto, SYSDATETIME(), estado_pago
FROM   GimnasioDB.finanzas.pago ORDER BY id_pago;
GO

BACKUP LOG GimnasioDB 
TO DISK = N'/backup/GimnasioDB/GimnasioDB_DEMO_LOG1.trn'
WITH COMPRESSION, CHECKSUM, INIT, NAME = N'GimnasioDB DEMO log 1';
GO

-- =============================================================================
-- 3. SIMULACIÓN DEL DESASTRE | BORRADO ACCIDENTAL
-- =============================================================================
INSERT INTO GimnasioDB.dbo.prueba_pagos (id_membresia, id_metodo_pago, monto, fecha_pago, estado_pago)
SELECT TOP (10) id_membresia, id_metodo_pago, monto, SYSDATETIME(), estado_pago
FROM   GimnasioDB.finanzas.pago ORDER BY id_pago;
GO

-- SIMULACIÓN DE BORRADO ACCIDENTAL
DELETE FROM GimnasioDB.dbo.prueba_pagos;
GO

-- =============================================================================
-- 4. VERIFICACIÓN DE INTEGRIDAD DE ARCHIVOS DE RESPALDO
-- =============================================================================
RESTORE VERIFYONLY FROM DISK = N'/backup/GimnasioDB/GimnasioDB_DEMO_FULL.bak' WITH CHECKSUM;
RESTORE VERIFYONLY FROM DISK = N'/backup/GimnasioDB/GimnasioDB_DEMO_DIFF.bak' WITH CHECKSUM;
RESTORE VERIFYONLY FROM DISK = N'/backup/GimnasioDB/GimnasioDB_DEMO_LOG1.trn' WITH CHECKSUM;
GO

-- =============================================================================
-- 5. RESTAURACIÓN | BASE DE DATOS GimnasioDB_Recuperada
-- =============================================================================
IF DB_ID(N'GimnasioDB_Recuperada') IS NOT NULL
BEGIN
    ALTER DATABASE GimnasioDB_Recuperada SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE GimnasioDB_Recuperada;
END
GO

RESTORE DATABASE GimnasioDB_Recuperada 
FROM DISK = N'/backup/GimnasioDB/GimnasioDB_DEMO_FULL.bak'
WITH MOVE N'GimnasioDB'     TO N'/var/opt/mssql/data/GimnasioDB_Recuperada.mdf',
     MOVE N'GimnasioDB_log' TO N'/var/opt/mssql/data/GimnasioDB_Recuperada_log.ldf',
     NORECOVERY;
GO

RESTORE DATABASE GimnasioDB_Recuperada 
FROM DISK = N'/backup/GimnasioDB/GimnasioDB_DEMO_DIFF.bak' WITH NORECOVERY;
GO

RESTORE LOG GimnasioDB_Recuperada 
FROM DISK = N'/backup/GimnasioDB/GimnasioDB_DEMO_LOG1.trn' WITH RECOVERY;
GO

-- =============================================================================
-- 6. RESULTADO | COMPARACIÓN DE FILAS RECUPERADAS
-- =============================================================================
SELECT (SELECT COUNT(*) FROM GimnasioDB.dbo.prueba_pagos)            AS filas_en_GimnasioDB_tras_desastre,
       (SELECT COUNT(*) FROM GimnasioDB_Recuperada.dbo.prueba_pagos) AS filas_en_GimnasioDB_Recuperada;
GO

SELECT * FROM GimnasioDB.dbo.prueba_pagos;
SELECT * FROM GimnasioDB_Recuperada.dbo.prueba_pagos;
-- =============================================================================
-- 7. HISTORIAL DE RESPALDOS | EVIDENCIA EN msdb
-- =============================================================================
SELECT TOP (20)
       bs.backup_finish_date AS fecha,
       CASE bs.type WHEN 'D' THEN 'Completo' WHEN 'I' THEN 'Diferencial' WHEN 'L' THEN 'Log' END AS tipo,
       CAST(bs.backup_size / 1048576.0 AS DECIMAL(10,2))            AS mb,
       CAST(bs.compressed_backup_size / 1048576.0 AS DECIMAL(10,2)) AS mb_comprimido,
       bmf.physical_device_name AS archivo
FROM   msdb.dbo.backupset bs
JOIN   msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
WHERE  bs.database_name = N'GimnasioDB'
ORDER BY bs.backup_finish_date DESC;
GO

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'GYM_Backup_Log')
    EXEC msdb.dbo.sp_update_job @job_name = N'GYM_Backup_Log', @enabled = 1;
GO