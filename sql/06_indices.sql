-- =============================================================================
-- PROYECTO FINAL — ADMINISTRACIÓN DE BASES DE DATOS
-- PROYECTO: SISTEMA DE RESERVAS DE GIMNASIO
-- ARCHIVO: 05_auditoria.sql
-- DESCRIPCIÓN: CONFIGURACIÓN DE SQL SERVER AUDIT Y BITÁCORA TRIGGER DE PAGOS
-- =============================================================================

USE GimnasioDB;
GO

-- === 1. LIMPIEZA | deja la base sin índices de optimización (estado "antes") ===
DROP INDEX IF EXISTS IX_pago_fecha          ON finanzas.pago;
DROP INDEX IF EXISTS IX_membresia_socio     ON socios.membresia;
DROP INDEX IF EXISTS IX_clase_fecha         ON clases.clase;
DROP INDEX IF EXISTS IX_reserva_socio       ON clases.reserva;
DROP INDEX IF EXISTS IX_reserva_clase_estado ON clases.reserva;

-- === 2. ÍNDICES ===
-- Consulta 1 (ingresos por plan): rango de fechas de pago; cubre monto, estado y membresía.
CREATE NONCLUSTERED INDEX IX_pago_fecha
ON finanzas.pago (fecha_pago)
INCLUDE (id_membresia, monto, estado_pago);

-- Consulta 3 (historial del socio): membresías de un socio ordenadas por fecha de inicio.
CREATE NONCLUSTERED INDEX IX_membresia_socio
ON socios.membresia (id_socio, fecha_inicio)
INCLUDE (id_plan, fecha_fin, estado_membresia);

-- Consulta 2 (ocupación y ranking): rango de fechas de clase; cubre entrenador, tipo, estado y cupo.
CREATE NONCLUSTERED INDEX IX_clase_fecha
ON clases.clase (fecha_hora_inicio)
INCLUDE (id_tipo_clase, id_entrenador, estado_clase, cupo_maximo);

-- Consulta 3 (historial del socio): reservas de un socio sin recorrer toda la tabla.
CREATE NONCLUSTERED INDEX IX_reserva_socio
ON clases.reserva (id_socio)
INCLUDE (id_clase, estado_reserva);

-- Consulta 2 (ocupación y ranking): reservas de una clase con su estado.
-- El índice UNIQUE (id_clase, id_socio) no incluye el estado y obligaría a buscar fila por fila.
CREATE NONCLUSTERED INDEX IX_reserva_clase_estado
ON clases.reserva (id_clase)
INCLUDE (estado_reserva);

-- === 3. VERIFICACIÓN | índices creados y su tamaño ===
SELECT OBJECT_SCHEMA_NAME(i.object_id) + '.' + OBJECT_NAME(i.object_id) AS tabla,
       i.name AS indice,
       SUM(ps.used_page_count) AS paginas,
       SUM(ps.used_page_count) * 8 AS kb
FROM sys.indexes i
JOIN sys.dm_db_partition_stats ps ON ps.object_id = i.object_id AND ps.index_id = i.index_id
WHERE i.name LIKE 'IX[_]%'
GROUP BY i.object_id, i.name
ORDER BY tabla, indice;

-- === 4. USO | ejecutar después de correr 07 para comprobar que el optimizador los usa ===
SELECT OBJECT_NAME(s.object_id) AS tabla, i.name AS indice,
       s.user_seeks AS busquedas, s.user_scans AS recorridos, s.user_lookups AS lookups
FROM sys.dm_db_index_usage_stats s
JOIN sys.indexes i ON i.object_id = s.object_id AND i.index_id = s.index_id
WHERE s.database_id = DB_ID() AND i.name LIKE 'IX[_]%'
ORDER BY tabla, indice;

-- =============================================================================
-- PRUEBAS RÁPIDAS DE ÍNDICES (1 POR CADA ÍNDICE DE 06_indices.sql)
-- Activar Plan de Ejecución Real (Ctrl + M) antes de ejecutar.
-- =============================================================================
USE GimnasioDB;
GO

SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

-- 1. Prueba para IX_pago_fecha (finanzas.pago)
SELECT id_membresia, monto, estado_pago
FROM   finanzas.pago
WHERE  fecha_pago >= '2026-10-01' AND fecha_pago < '2026-11-01';
GO

-- 2. Prueba para IX_membresia_socio (socios.membresia)
SELECT id_plan, fecha_inicio, fecha_fin, estado_membresia
FROM   socios.membresia
WHERE  id_socio = 15 AND fecha_inicio >= '2026-01-01';
GO

-- 3. Prueba para IX_clase_fecha (clases.clase)
SELECT id_tipo_clase, id_entrenador, estado_clase, cupo_maximo
FROM   clases.clase
WHERE  fecha_hora_inicio >= '2026-10-01' AND fecha_hora_inicio < '2026-11-01';
GO

-- 4. Prueba para IX_reserva_socio (clases.reserva)
SELECT id_clase, estado_reserva
FROM   clases.reserva
WHERE  id_socio = 15;
GO

-- 5. Prueba para IX_reserva_clase_estado (clases.reserva)
SELECT estado_reserva
FROM   clases.reserva
WHERE  id_clase = 10;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO