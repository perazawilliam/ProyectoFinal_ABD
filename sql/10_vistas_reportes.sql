-- =============================================================================
-- PROYECTO FINAL — ADMINISTRACIÓN DE BASES DE DATOS
-- PROYECTO: SISTEMA DE RESERVAS DE GIMNASIO
-- ARCHIVO: 10_vistas_reportes.sql
-- DESCRIPCIÓN: CAPA ANALÍTICA DE SOLO LECTURA PARA POWER BI
-- =============================================================================

USE GimnasioDB;
GO

-- =============================================================================
-- 1. VISTA | reportes.vw_dim_plan (DIMENSIÓN)
-- =============================================================================
CREATE OR ALTER VIEW reportes.vw_dim_plan
AS
SELECT id_plan, nombre_plan, duracion_dias, precio, max_reservas_semana
FROM   socios.plan_membresia;
GO

-- =============================================================================
-- 2. VISTA | reportes.vw_dim_entrenador (DIMENSIÓN)
-- =============================================================================
CREATE OR ALTER VIEW reportes.vw_dim_entrenador
AS
SELECT e.id_entrenador, e.nombre_entrenador, es.nombre_especialidad, e.estado_entrenador
FROM   personal.entrenador e
JOIN   personal.especialidad es ON es.id_especialidad = e.id_especialidad;
GO

-- =============================================================================
-- 3. VISTA | reportes.vw_ingresos_mensuales_plan
-- =============================================================================
CREATE OR ALTER VIEW reportes.vw_ingresos_mensuales_plan
AS
WITH mensual AS (
    SELECT pl.id_plan, pl.nombre_plan,
           DATEFROMPARTS(YEAR(p.fecha_pago), MONTH(p.fecha_pago), 1) AS mes,
           COUNT(*)     AS pagos,
           SUM(p.monto) AS ingresos
    FROM   finanzas.pago p
    JOIN   socios.membresia m       ON m.id_membresia = p.id_membresia
    JOIN   socios.plan_membresia pl ON pl.id_plan = m.id_plan
    WHERE  p.estado_pago = 'Completado'
    GROUP BY pl.id_plan, pl.nombre_plan, DATEFROMPARTS(YEAR(p.fecha_pago), MONTH(p.fecha_pago), 1)
)
SELECT id_plan, nombre_plan, mes, pagos, ingresos,
       SUM(ingresos) OVER (PARTITION BY id_plan ORDER BY mes ROWS UNBOUNDED PRECEDING) AS ingresos_acumulados_plan,
       ingresos - LAG(ingresos) OVER (PARTITION BY id_plan ORDER BY mes)               AS variacion_vs_mes_anterior,
       CAST(100.0 * ingresos / SUM(ingresos) OVER (PARTITION BY mes) AS DECIMAL(5,2))  AS pct_del_mes,
       RANK() OVER (PARTITION BY mes ORDER BY ingresos DESC)                           AS ranking_en_mes
FROM   mensual;
GO

-- =============================================================================
-- 4. VISTA | reportes.vw_ocupacion_clases
-- =============================================================================
CREATE OR ALTER VIEW reportes.vw_ocupacion_clases
AS
SELECT c.id_clase,
       CAST(c.fecha_hora_inicio AS DATE)                         AS fecha_clase,
       DATEPART(HOUR, c.fecha_hora_inicio)                       AS hora_inicio,
       CASE WHEN DATEPART(HOUR, c.fecha_hora_inicio) < 12 THEN 'Mañana' ELSE 'Tarde-noche' END AS franja,
       DATEDIFF(DAY, '19000101', c.fecha_hora_inicio) % 7 + 1    AS num_dia_semana,
       CASE DATEDIFF(DAY, '19000101', c.fecha_hora_inicio) % 7
            WHEN 0 THEN 'Lunes' WHEN 1 THEN 'Martes' WHEN 2 THEN 'Miércoles' WHEN 3 THEN 'Jueves'
            WHEN 4 THEN 'Viernes' WHEN 5 THEN 'Sábado' ELSE 'Domingo' END AS dia_semana,
       t.nombre_clase, t.nivel,
       c.id_entrenador, e.nombre_entrenador,
       sa.nombre_sala,
       c.cupo_maximo, c.estado_clase,
       ISNULL(x.reservas_activas, 0) AS reservas_activas,
       ISNULL(x.asistentes, 0)       AS asistentes,
       CAST(100.0 * ISNULL(x.reservas_activas, 0) / c.cupo_maximo AS DECIMAL(5,2)) AS pct_ocupacion
FROM   clases.clase c
JOIN   clases.tipo_clase t   ON t.id_tipo_clase = c.id_tipo_clase
JOIN   personal.entrenador e ON e.id_entrenador = c.id_entrenador
JOIN   clases.sala sa        ON sa.id_sala = c.id_sala
OUTER APPLY (
    SELECT SUM(CASE WHEN r.estado_reserva IN ('Confirmada', 'Asistida', 'No asistio') THEN 1 ELSE 0 END) AS reservas_activas,
           SUM(CASE WHEN r.estado_reserva = 'Asistida' THEN 1 ELSE 0 END)                                AS asistentes
    FROM   clases.reserva r
    WHERE  r.id_clase = c.id_clase
) x;
GO

-- =============================================================================
-- 5. VISTA | reportes.vw_ranking_entrenadores
-- =============================================================================
CREATE OR ALTER VIEW reportes.vw_ranking_entrenadores
AS
WITH agrupado AS (
    SELECT id_entrenador, nombre_entrenador, nombre_clase,
           COUNT(*)               AS sesiones,
           SUM(asistentes)        AS asistentes,
           SUM(reservas_activas)  AS reservas,
           SUM(cupo_maximo)       AS cupo_total
    FROM   reportes.vw_ocupacion_clases
    WHERE  estado_clase = 'Realizada'
    GROUP BY id_entrenador, nombre_entrenador, nombre_clase
),
con_pct AS (
    SELECT *, CAST(100.0 * reservas / cupo_total AS DECIMAL(5,2)) AS pct_ocupacion
    FROM   agrupado
)
SELECT id_entrenador, nombre_entrenador, nombre_clase, sesiones, asistentes, pct_ocupacion,
       RANK() OVER (PARTITION BY id_entrenador ORDER BY asistentes DESC)          AS ranking_en_entrenador,
       DENSE_RANK() OVER (ORDER BY pct_ocupacion DESC)                            AS ranking_general_ocupacion,
       CAST(AVG(pct_ocupacion) OVER (PARTITION BY id_entrenador) AS DECIMAL(5,2)) AS ocupacion_prom_entrenador
FROM   con_pct;
GO

-- =============================================================================
-- 6. VISTA | reportes.vw_socios_constancia
-- =============================================================================
CREATE OR ALTER VIEW reportes.vw_socios_constancia
AS
WITH visitas AS (
    SELECT r.id_socio, c.fecha_hora_inicio AS fecha_clase, r.estado_reserva,
           LAG(c.fecha_hora_inicio) OVER (PARTITION BY r.id_socio ORDER BY c.fecha_hora_inicio) AS fecha_anterior
    FROM   clases.reserva r
    JOIN   clases.clase c ON c.id_clase = r.id_clase
    WHERE  r.estado_reserva IN ('Asistida', 'No asistio')
),
por_socio AS (
    SELECT id_socio,
           COUNT(*) AS reservas_pasadas,
           SUM(CASE WHEN estado_reserva = 'Asistida' THEN 1 ELSE 0 END) AS asistencias,
           CAST(MAX(fecha_clase) AS DATE) AS ultima_visita,
           AVG(CAST(DATEDIFF(DAY, fecha_anterior, fecha_clase) AS DECIMAL(9,2))) AS dias_prom_entre_visitas
    FROM   visitas
    GROUP BY id_socio
)
SELECT s.id_socio, s.nombre, s.estado_socio,
       ISNULL(ps.reservas_pasadas, 0) AS reservas_pasadas,
       ISNULL(ps.asistencias, 0)      AS asistencias,
       CASE WHEN ISNULL(ps.reservas_pasadas, 0) = 0 THEN NULL
            ELSE CAST(100.0 * ps.asistencias / ps.reservas_pasadas AS DECIMAL(5,2)) END AS pct_asistencia,
       ps.ultima_visita,
       CAST(ps.dias_prom_entre_visitas AS DECIMAL(6,1)) AS dias_prom_entre_visitas,
       NTILE(4) OVER (ORDER BY ISNULL(ps.asistencias, 0) DESC) AS cuartil_constancia,
       ult.nombre_plan       AS plan_ultimo,
       ult.estado_membresia  AS estado_ultima_membresia
FROM   socios.socio s
LEFT JOIN por_socio ps ON ps.id_socio = s.id_socio
OUTER APPLY (
    SELECT TOP (1) pl.nombre_plan, m.estado_membresia
    FROM   socios.membresia m
    JOIN   socios.plan_membresia pl ON pl.id_plan = m.id_plan
    WHERE  m.id_socio = s.id_socio
    ORDER BY m.fecha_inicio DESC
) ult;
GO

-- =============================================================================
-- 7. VISTA | reportes.vw_membresias
-- =============================================================================
CREATE OR ALTER VIEW reportes.vw_membresias
AS
SELECT m.id_membresia, m.id_socio, m.id_plan, pl.nombre_plan, pl.precio,
       m.fecha_inicio, m.fecha_fin, m.estado_membresia
FROM   socios.membresia m
JOIN   socios.plan_membresia pl ON pl.id_plan = m.id_plan;
GO

-- =============================================================================
-- 8. VERIFICACIÓN | CONTEO POR VISTA Y PRUEBA DE AISLAMIENTO CON usr_powerbi
-- =============================================================================
SELECT 'vw_dim_plan'                AS vista, COUNT(*) AS filas FROM reportes.vw_dim_plan UNION ALL
SELECT 'vw_dim_entrenador',         COUNT(*) FROM reportes.vw_dim_entrenador         UNION ALL
SELECT 'vw_ingresos_mensuales_plan', COUNT(*) FROM reportes.vw_ingresos_mensuales_plan UNION ALL
SELECT 'vw_ocupacion_clases',       COUNT(*) FROM reportes.vw_ocupacion_clases       UNION ALL
SELECT 'vw_ranking_entrenadores',   COUNT(*) FROM reportes.vw_ranking_entrenadores   UNION ALL
SELECT 'vw_socios_constancia',      COUNT(*) FROM reportes.vw_socios_constancia      UNION ALL
SELECT 'vw_membresias',             COUNT(*) FROM reportes.vw_membresias;

EXECUTE AS USER = 'usr_powerbi';
SELECT COUNT(*) AS filas_leidas_por_usr_powerbi FROM reportes.vw_ocupacion_clases;
BEGIN TRY
    SELECT COUNT(*) FROM socios.socio;
END TRY
BEGIN CATCH
    SELECT 'DENEGADO: ' + ERROR_MESSAGE() AS acceso_a_tablas_base;
END CATCH
REVERT;
GO