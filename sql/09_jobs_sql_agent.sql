-- =============================================================================
-- PROYECTO FINAL — ADMINISTRACIÓN DE BASES DE DATOS
-- PROYECTO: SISTEMA DE RESERVAS DE GIMNASIO
-- ARCHIVO: 09_jobs_sql_agent.sql
-- =============================================================================

USE msdb;
GO

-- =============================================================================
-- PASO 1 | LIMPIEZA TOTAL (Elimina jobs y horarios viejos)
-- =============================================================================
IF EXISTS (SELECT 1 FROM sysjobs WHERE name = N'GYM_Backup_Full') EXEC sp_delete_job @job_name = N'GYM_Backup_Full', @delete_unused_schedule = 1;
IF EXISTS (SELECT 1 FROM sysjobs WHERE name = N'GYM_Backup_Diferencial') EXEC sp_delete_job @job_name = N'GYM_Backup_Diferencial', @delete_unused_schedule = 1;
IF EXISTS (SELECT 1 FROM sysjobs WHERE name = N'GYM_Backup_Log') EXEC sp_delete_job @job_name = N'GYM_Backup_Log', @delete_unused_schedule = 1;
IF EXISTS (SELECT 1 FROM sysjobs WHERE name = N'GYM_Verificacion_Integridad') EXEC sp_delete_job @job_name = N'GYM_Verificacion_Integridad', @delete_unused_schedule = 1;
IF EXISTS (SELECT 1 FROM sysjobs WHERE name = N'GYM_Limpieza_Backups') EXEC sp_delete_job @job_name = N'GYM_Limpieza_Backups', @delete_unused_schedule = 1;
GO

-- =============================================================================
-- PASO 2 | CREAR JOB 1: RESPALDO COMPLETO (Domingo 10:00 PM SV)
-- =============================================================================
EXEC sp_add_job @job_name = N'GYM_Backup_Full';
EXEC sp_add_jobstep
    @job_name = N'GYM_Backup_Full',
    @step_name = N'Respaldo completo',
    @subsystem = N'TSQL', @database_name = N'master',
    @command = N'BACKUP DATABASE GimnasioDB TO DISK = ''/backup/GimnasioDB/GimnasioDB_job_FULL.bak'' WITH INIT, CHECKSUM, COMPRESSION;';
EXEC sp_add_jobserver @job_name = N'GYM_Backup_Full';
EXEC sp_add_schedule
    @schedule_name = N'GYM_Full_Domingo_2200_SV',
    @freq_type = 8, @freq_interval = 1, 
    @freq_recurrence_factor = 1,
    @active_start_time = 040000;
EXEC sp_attach_schedule @job_name = N'GYM_Backup_Full', @schedule_name = N'GYM_Full_Domingo_2200_SV';
GO

-- =============================================================================
-- PASO 3 | CREAR JOB 2: RESPALDO DIFERENCIAL (Lunes a Sábado 10:00 PM SV)
-- =============================================================================
EXEC sp_add_job @job_name = N'GYM_Backup_Diferencial';
EXEC sp_add_jobstep
    @job_name = N'GYM_Backup_Diferencial',
    @step_name = N'Respaldo diferencial',
    @subsystem = N'TSQL', @database_name = N'master',
    @command = N'BACKUP DATABASE GimnasioDB TO DISK = ''/backup/GimnasioDB/GimnasioDB_job_DIFF.bak'' WITH DIFFERENTIAL, INIT, CHECKSUM, COMPRESSION;';
EXEC sp_add_jobserver @job_name = N'GYM_Backup_Diferencial';
EXEC sp_add_schedule
    @schedule_name = N'GYM_Diff_Lun_Sab_2200_SV',
    @freq_type = 8, @freq_interval = 126, 
    @freq_recurrence_factor = 1,
    @active_start_time = 040000;
EXEC sp_attach_schedule @job_name = N'GYM_Backup_Diferencial', @schedule_name = N'GYM_Diff_Lun_Sab_2200_SV';
GO

-- =============================================================================
-- PASO 4 | CREAR JOB 3: RESPALDO DE LOG (Cada 15 minutos)
-- =============================================================================
EXEC sp_add_job @job_name = N'GYM_Backup_Log';
EXEC sp_add_jobstep
    @job_name = N'GYM_Backup_Log',
    @step_name = N'Respaldo de log',
    @subsystem = N'TSQL', @database_name = N'master',
    @command = N'BACKUP LOG GimnasioDB TO DISK = ''/backup/GimnasioDB/GimnasioDB_job_LOG.trn'' WITH INIT, CHECKSUM, COMPRESSION;';
EXEC sp_add_jobserver @job_name = N'GYM_Backup_Log';
EXEC sp_add_schedule
    @schedule_name = N'GYM_Log_Cada_15min',
    @freq_type = 4, @freq_interval = 1, 
    @freq_recurrence_factor = 1,
    @freq_subday_type = 4, @freq_subday_interval = 15;
EXEC sp_attach_schedule @job_name = N'GYM_Backup_Log', @schedule_name = N'GYM_Log_Cada_15min';
GO

-- =============================================================================
-- PASO 5 | CREAR JOB 4: VERIFICACIÓN DE FRAGMENTACIÓN (Domingo 10:30 PM SV)
-- =============================================================================
-- Nota: Se agregó el NULL faltante en la función para evitar el error 313
EXEC sp_add_job @job_name = N'GYM_Verificacion_Integridad';
EXEC sp_add_jobstep
    @job_name = N'GYM_Verificacion_Integridad',
    @step_name = N'Revisar Indices',
    @subsystem = N'TSQL', @database_name = N'GimnasioDB',
    @command = N'SELECT DB_NAME() AS DatabaseName, OBJECT_NAME(IPS.OBJECT_ID) AS TableName, I.name AS IndexName, IPS.avg_fragmentation_in_percent 
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, ''SAMPLED'') AS IPS 
JOIN sys.indexes AS I ON IPS.object_id = I.object_id AND IPS.index_id = I.index_id 
WHERE IPS.avg_fragmentation_in_percent > 5 
ORDER BY IPS.avg_fragmentation_in_percent DESC;';
EXEC sp_add_jobserver @job_name = N'GYM_Verificacion_Integridad';
EXEC sp_add_schedule
    @schedule_name = N'GYM_Integridad_Domingo_2230_SV',
    @freq_type = 8, @freq_interval = 1, 
    @freq_recurrence_factor = 1,
    @active_start_time = 043000;
EXEC sp_attach_schedule @job_name = N'GYM_Verificacion_Integridad', @schedule_name = N'GYM_Integridad_Domingo_2230_SV';
GO

-- =============================================================================
-- PASO 6 | CREAR JOB 5: LIMPIEZA DE RESPALDOS (Domingo 10:00 PM SV)
-- =============================================================================
EXEC sp_add_job @job_name = N'GYM_Limpieza_Backups';
EXEC sp_add_jobstep
    @job_name = N'GYM_Limpieza_Backups',
    @step_name = N'Limpiar Archivos',
    @subsystem = N'TSQL', @database_name = N'master',
    @command = N'DECLARE @limite datetime = DATEADD(DAY, -28, GETDATE());
EXEC master.dbo.xp_delete_file 0, N''/backup/GimnasioDB/'', N''bak'', @limite, 0;
EXEC master.dbo.xp_delete_file 0, N''/backup/GimnasioDB/'', N''trn'', @limite, 0;';
EXEC sp_add_jobserver @job_name = N'GYM_Limpieza_Backups';
EXEC sp_add_schedule
    @schedule_name = N'GYM_Limpieza_Domingo_2200_SV',
    @freq_type = 8, @freq_interval = 1, 
    @freq_recurrence_factor = 1,
    @active_start_time = 040000;
EXEC sp_attach_schedule @job_name = N'GYM_Limpieza_Backups', @schedule_name = N'GYM_Limpieza_Domingo_2200_SV';
GO

-- =============================================================================
-- PASO 7 | COMPROBAR QUE SE CREARON BIEN
-- =============================================================================
SELECT name, enabled FROM msdb.dbo.sysjobs WHERE name LIKE 'GYM[_]%';
GO

-- =============================================================================
-- PASO 8 | EJECUTAR TODOS LOS JOBS PARA PROBAR
-- =============================================================================
EXEC msdb.dbo.sp_start_job @job_name = N'GYM_Backup_Full';
EXEC msdb.dbo.sp_start_job @job_name = N'GYM_Backup_Diferencial';
EXEC msdb.dbo.sp_start_job @job_name = N'GYM_Backup_Log';
EXEC msdb.dbo.sp_start_job @job_name = N'GYM_Verificacion_Integridad';
EXEC msdb.dbo.sp_start_job @job_name = N'GYM_Limpieza_Backups';
GO

-- =============================================================================
-- PASO 9 | ESPERAR Y VER EL RESULTADO FINAL (Historial limpio)
-- =============================================================================
WAITFOR DELAY '00:00:10';
GO

SELECT TOP (5) j.name AS trabajo, h.run_status,
       CASE h.run_status WHEN 1 THEN N'Correcto'
            WHEN 0 THEN N'Falló' ELSE N'Revisar' END AS resultado
FROM msdb.dbo.sysjobhistory AS h
JOIN msdb.dbo.sysjobs AS j ON j.job_id = h.job_id
WHERE j.name LIKE 'GYM[_]%' AND h.step_id = 0
ORDER BY h.instance_id DESC;
GO