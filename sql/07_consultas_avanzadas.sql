-- =============================================================================
-- PROYECTO FINAL — ADMINISTRACIÓN DE BASES DE DATOS
-- PROYECTO: SISTEMA DE RESERVAS DE GIMNASIO
-- ARCHIVO: 07_consultas_avanzadas.sql
-- DESCRIPCIÓN: CONSULTAS ANALÍTICAS AUTÓNOMAS CON FUNCIONES VENTANA
-- =============================================================================

USE GimnasioDB;
GO

SET STATISTICS IO, TIME ON;
GO

-- =============================================================================
-- CONSULTA 1 | INGRESOS MENSUALES POR PLAN (ÚLTIMOS 12 MESES COMPLETOS)
-- FUNCIONES VENTANA: SUM() OVER, LAG(), RANK()
-- ÍNDICE UTILIZADO: IX_pago_fecha
-- =============================================================================
WITH mensual AS (
    SELECT pl.nombre_plan,
           DATEFROMPARTS(YEAR(p.fecha_pago), MONTH(p.fecha_pago), 1) AS mes,
           COUNT(*)     AS pagos,
           SUM(p.monto) AS ingresos
    FROM   finanzas.pago p
    JOIN   socios.membresia m       ON m.id_membresia = p.id_membresia
    JOIN   socios.plan_membresia pl ON pl.id_plan = m.id_plan
    WHERE  p.estado_pago = 'Completado'
      AND  p.fecha_pago >= '2025-11-01'
      AND  p.fecha_pago <  '2026-11-01'
    GROUP BY pl.nombre_plan, DATEFROMPARTS(YEAR(p.fecha_pago), MONTH(p.fecha_pago), 1)
)
SELECT mes,
       nombre_plan,
       pagos,
       ingresos,
       SUM(ingresos) OVER (PARTITION BY nombre_plan ORDER BY mes ROWS UNBOUNDED PRECEDING) AS acumulado_plan,
       ingresos - LAG(ingresos) OVER (PARTITION BY nombre_plan ORDER BY mes)               AS variacion_vs_mes_anterior,
       CAST(100.0 * ingresos / SUM(ingresos) OVER (PARTITION BY mes) AS DECIMAL(5,2))      AS pct_del_mes,
       RANK() OVER (PARTITION BY mes ORDER BY ingresos DESC)                               AS ranking_en_mes
FROM   mensual
ORDER BY mes, ranking_en_mes;
GO

-- =============================================================================
-- CONSULTA 2 | OCUPACIÓN Y RANKING DE CLASES POR ENTRENADOR (ÚLTIMOS 3 MESES)
-- FUNCIONES VENTANA: RANK(), DENSE_RANK(), AVG() OVER
-- ÍNDICES UTILIZADOS: IX_clase_fecha, IX_reserva_clase_estado
-- =============================================================================
WITH por_clase AS (
    SELECT c.id_clase,
           c.id_entrenador,
           c.id_tipo_clase,
           c.cupo_maximo,
           SUM(CASE WHEN r.estado_reserva IN ('Confirmada', 'Asistida', 'No asistio') THEN 1 ELSE 0 END) AS reservas,
           SUM(CASE WHEN r.estado_reserva = 'Asistida' THEN 1 ELSE 0 END)                                AS asistentes
    FROM   clases.clase c
    LEFT JOIN clases.reserva r ON r.id_clase = c.id_clase
    WHERE  c.estado_clase = 'Realizada'
      AND  c.fecha_hora_inicio >= '2026-08-07'
      AND  c.fecha_hora_inicio <  '2026-11-08'
    GROUP BY c.id_clase, c.id_entrenador, c.id_tipo_clase, c.cupo_maximo
),
por_entrenador AS (
    SELECT id_entrenador,
           id_tipo_clase,
           COUNT(*)        AS sesiones,
           SUM(asistentes) AS asistentes,
           CAST(100.0 * SUM(reservas) / SUM(cupo_maximo) AS DECIMAL(5,2)) AS pct_ocupacion
    FROM   por_clase
    GROUP BY id_entrenador, id_tipo_clase
)
SELECT e.nombre_entrenador,
       t.nombre_clase,
       pe.sesiones,
       pe.asistentes,
       pe.pct_ocupacion,
       RANK() OVER (PARTITION BY pe.id_entrenador ORDER BY pe.asistentes DESC)         AS ranking_en_entrenador,
       DENSE_RANK() OVER (ORDER BY pe.pct_ocupacion DESC)                              AS ranking_general_ocupacion,
       CAST(AVG(pe.pct_ocupacion) OVER (PARTITION BY pe.id_entrenador) AS DECIMAL(5,2)) AS ocupacion_prom_entrenador
FROM   por_entrenador pe
JOIN   personal.entrenador e ON e.id_entrenador = pe.id_entrenador
JOIN   clases.tipo_clase t   ON t.id_tipo_clase = pe.id_tipo_clase
ORDER BY e.nombre_entrenador, ranking_en_entrenador;
GO

-- =============================================================================
-- CONSULTA 3 | HISTORIAL DE ASISTENCIA DEL SOCIO MÁS CONSTANTE
-- FUNCIONES VENTANA: ROW_NUMBER(), SUM() OVER, LAG()
-- ÍNDICES UTILIZADOS: IX_reserva_socio, IX_membresia_socio
-- =============================================================================
WITH socio_top AS (
    SELECT TOP (1) id_socio
    FROM   clases.reserva
    WHERE  estado_reserva = 'Asistida'
    GROUP BY id_socio
    ORDER BY COUNT(*) DESC
),
visitas AS (
    SELECT c.fecha_hora_inicio AS fecha_clase,
           t.nombre_clase,
           pl.nombre_plan,
           r.estado_reserva
    FROM   clases.reserva r
    JOIN   socio_top st         ON st.id_socio = r.id_socio
    JOIN   clases.clase c       ON c.id_clase = r.id_clase
    JOIN   clases.tipo_clase t  ON t.id_tipo_clase = c.id_tipo_clase
    LEFT JOIN socios.membresia m
           ON  m.id_socio = r.id_socio
           AND m.estado_membresia <> 'Cancelada'
           AND CAST(c.fecha_hora_inicio AS DATE) BETWEEN m.fecha_inicio AND m.fecha_fin
    LEFT JOIN socios.plan_membresia pl ON pl.id_plan = m.id_plan
    WHERE  r.estado_reserva IN ('Asistida', 'No asistio')
)
SELECT fecha_clase,
       nombre_clase,
       nombre_plan,
       estado_reserva,
       ROW_NUMBER() OVER (ORDER BY fecha_clase) AS n_visita,
       SUM(CASE WHEN estado_reserva = 'Asistida' THEN 1 ELSE 0 END)
           OVER (ORDER BY fecha_clase ROWS UNBOUNDED PRECEDING) AS asistencias_acumuladas,
       DATEDIFF(DAY, LAG(fecha_clase) OVER (ORDER BY fecha_clase), fecha_clase) AS dias_desde_visita_anterior,
       CAST(100.0 * SUM(CASE WHEN estado_reserva = 'Asistida' THEN 1 ELSE 0 END)
                        OVER (ORDER BY fecha_clase ROWS UNBOUNDED PRECEDING)
                  / ROW_NUMBER() OVER (ORDER BY fecha_clase) AS DECIMAL(5,2)) AS pct_asistencia_acumulado
FROM   visitas
ORDER BY fecha_clase;
GO

SET STATISTICS IO, TIME OFF;
GO