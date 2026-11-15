-- =============================================================================
-- PROYECTO FINAL — ADMINISTRACIÓN DE BASES DE DATOS
-- PROYECTO: SISTEMA DE RESERVAS DE GIMNASIO
-- ARCHIVO: 03_1_carga_datos.sql
-- DESCRIPCIÓN: CARGA DETERMINÍSTICA 100% T-SQL 
-- =============================================================================

USE GimnasioDB;
SET NOCOUNT ON;

-- =============================================================================
-- 1. PARÁMETROS GENERALES DE SIMULACIÓN
-- =============================================================================
DECLARE @fecha_corte DATE = '2026-11-13';                      
DECLARE @inicio_hist DATE = DATEADD(MONTH, -6, @fecha_corte);  

-- =============================================================================
-- 2. CATÁLOGOS | INSERCIÓN DIRECTA CON IDENTIDAD EXPLÍCITA
-- =============================================================================
SET IDENTITY_INSERT personal.especialidad ON;
INSERT INTO personal.especialidad (id_especialidad, nombre_especialidad) VALUES
    (1, 'Yoga y Pilates'), (2, 'Entrenamiento funcional'), (3, 'Ciclismo indoor'),
    (4, 'Baile y Zumba'), (5, 'Boxeo y artes marciales'), (6, 'Fuerza y acondicionamiento');
SET IDENTITY_INSERT personal.especialidad OFF;

SET IDENTITY_INSERT personal.entrenador ON;
INSERT INTO personal.entrenador (id_entrenador, id_especialidad, dui, nombre_entrenador, telefono, correo, fecha_contratacion, estado_entrenador) VALUES
    (1, 6, '68446522-8', 'Carlos Alberto Mejía',      '7121-5234', 'carlos.mejia@gimnasio.example',     '2022-02-14', 'Activo'),
    (2, 1, '30968745-9', 'Ana Lucía Hernández',       '7662-1681', 'ana.hernandez@gimnasio.example',    '2022-08-01', 'Activo'),
    (3, 2, '57453983-9', 'José Roberto Martínez',     '7636-9118', 'jose.martinez@gimnasio.example',    '2023-01-09', 'Activo'),
    (4, 4, '79721495-7', 'María Fernanda López',      '7560-8042', 'maria.lopez@gimnasio.example',      '2023-05-22', 'Activo'),
    (5, 3, '83437103-1', 'Luis Enrique Ramírez',      '7245-0041', 'luis.ramirez@gimnasio.example',     '2023-11-06', 'Activo'),
    (6, 1, '14160265-7', 'Sofía Alejandra Portillo',  '7113-4706', 'sofia.portillo@gimnasio.example',   '2024-03-18', 'Activo'),
    (7, 5, '92186040-5', 'Diego Armando Cruz',        '7011-8032', 'diego.cruz@gimnasio.example',       '2024-09-02', 'Activo'),
    (8, 2, '34757517-5', 'Karla Beatriz Menjívar',    '7215-6508', 'karla.menjivar@gimnasio.example',   '2021-07-05', 'Inactivo');
SET IDENTITY_INSERT personal.entrenador OFF;

SET IDENTITY_INSERT socios.plan_membresia ON;
INSERT INTO socios.plan_membresia (id_plan, nombre_plan, duracion_dias, precio, max_reservas_semana) VALUES
    (1, 'Mensual', 30, 35.00, NULL), (2, 'Trimestral', 90, 95.00, NULL),
    (3, 'Semestral', 180, 175.00, NULL), (4, 'Anual', 365, 320.00, NULL),
    (5, 'Estudiante mensual', 30, 25.00, 3);
SET IDENTITY_INSERT socios.plan_membresia OFF;

SET IDENTITY_INSERT finanzas.metodo_pago ON;
INSERT INTO finanzas.metodo_pago (id_metodo_pago, nombre_metodo) VALUES
    (1, 'Efectivo'), (2, 'Tarjeta de crédito'), (3, 'Tarjeta de débito'), (4, 'Transferencia bancaria');
SET IDENTITY_INSERT finanzas.metodo_pago OFF;

SET IDENTITY_INSERT clases.sala ON;
INSERT INTO clases.sala (id_sala, nombre_sala, capacidad) VALUES
    (1, 'Sala Funcional', 25), (2, 'Sala Spinning', 20), (3, 'Estudio Yoga', 18), (4, 'Sala Multiusos', 30);
SET IDENTITY_INSERT clases.sala OFF;

SET IDENTITY_INSERT clases.tipo_clase ON;
INSERT INTO clases.tipo_clase (id_tipo_clase, nombre_clase, descripcion, nivel, duracion_min) VALUES
    (1,  'Yoga Flow',               'Secuencias de yoga con enfoque en flexibilidad y respiración', 'Principiante', 60),
    (2,  'Pilates Mat',             'Fortalecimiento del core sobre colchoneta',                    'Intermedio',   60),
    (3,  'Spinning Cardio',         'Ciclismo indoor de resistencia cardiovascular',                'Intermedio',   45),
    (4,  'Spinning Power',          'Ciclismo indoor por intervalos de alta intensidad',            'Avanzado',     60),
    (5,  'Zumba',                   'Baile aeróbico con ritmos latinos',                            'Principiante', 60),
    (6,  'Funcional HIIT',          'Circuitos funcionales de alta intensidad',                     'Avanzado',     45),
    (7,  'Boxeo Fitness',           'Técnica de boxeo combinada con acondicionamiento',             'Intermedio',   60),
    (8,  'Crossfit',                'Entrenamiento variado de fuerza y resistencia',                'Intermedio',   75),
    (9,  'Stretching y Movilidad',  'Estiramientos y movilidad articular',                          'Principiante', 45),
    (10, 'Entrenamiento de Fuerza', 'Trabajo con pesas y máquinas guiado',                          'Intermedio',   90);
SET IDENTITY_INSERT clases.tipo_clase OFF;

-- =============================================================================
-- 3. SOCIOS | GENERACIÓN DETERMINÍSTICA DE 200 REGISTROS
-- =============================================================================
SELECT id, nombre INTO #nombres FROM (VALUES
    (1, 'María'), (2, 'Ana'), (3, 'Carmen'), (4, 'Rosa'), (5, 'Lucía'),
    (6, 'Gabriela'), (7, 'Daniela'), (8, 'Fátima'), (9, 'Paola'), (10, 'Andrea'),
    (11, 'Verónica'), (12, 'Claudia'), (13, 'Karen'), (14, 'Jessica'), (15, 'Mónica'),
    (16, 'José'), (17, 'Carlos'), (18, 'Luis'), (19, 'Juan'), (20, 'Miguel'),
    (21, 'Jorge'), (22, 'Mario'), (23, 'Kevin'), (24, 'Oscar'), (25, 'Daniel'),
    (26, 'Fernando'), (27, 'Ricardo'), (28, 'Eduardo'), (29, 'Roberto'), (30, 'Alexis')
) v(id, nombre);

SELECT id, apellido INTO #apellidos FROM (VALUES
    (1, 'Hernández'), (2, 'Martínez'), (3, 'López'), (4, 'García'), (5, 'Rodríguez'),
    (6, 'Pérez'), (7, 'Gómez'), (8, 'Flores'), (9, 'Ramírez'), (10, 'Rivas'),
    (11, 'Cruz'), (12, 'Mejía'), (13, 'Alvarado'), (14, 'Ortiz'), (15, 'Guzmán'),
    (16, 'Chávez'), (17, 'Aguilar'), (18, 'Castillo'), (19, 'Vásquez'), (20, 'Menjívar'),
    (21, 'Portillo'), (22, 'Henríquez'), (23, 'Reyes'), (24, 'Méndez'), (25, 'Escobar'),
    (26, 'Campos'), (27, 'Quintanilla'), (28, 'Amaya'), (29, 'Rosales'), (30, 'Navarro')
) v(id, apellido);

INSERT INTO socios.socio (dui, nombre, fecha_nacimiento, telefono, correo, fecha_registro, estado_socio)
SELECT CAST(10000000 + (g.n * 441337) % 89000000 AS VARCHAR(8)) + '-' + CAST(g.n % 10 AS VARCHAR(1)),
       nm.nombre + ' ' + a1.apellido + ' ' + a2.apellido,
       DATEADD(DAY, (CHECKSUM(g.n, 1) & 2147483647) % 15705, CAST('19650101' AS DATE)),
       CASE WHEN (CHECKSUM(g.n, 2) & 2147483647) % 100 < 5 THEN NULL
            ELSE '7' + RIGHT('000'  + CAST((CHECKSUM(g.n, 3) & 2147483647) % 1000  AS VARCHAR(3)), 3)
                 + '-' + RIGHT('0000' + CAST((CHECKSUM(g.n, 4) & 2147483647) % 10000 AS VARCHAR(4)), 4) END,
       c.correo,
       DATEADD(DAY, (CHECKSUM(g.n, 5) & 2147483647) % 518, CAST('20250601' AS DATE)),
       CASE WHEN r.v < 88 THEN 'Activo' WHEN r.v < 97 THEN 'Inactivo' ELSE 'Suspendido' END
FROM (SELECT TOP (200) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM sys.all_objects) g
JOIN #nombres   nm ON nm.id = (CHECKSUM(g.n, 6) & 2147483647) % 30 + 1
JOIN #apellidos a1 ON a1.id = (CHECKSUM(g.n, 7) & 2147483647) % 30 + 1
JOIN #apellidos a2 ON a2.id = (a1.id + (CHECKSUM(g.n, 8) & 2147483647) % 29) % 30 + 1
CROSS APPLY (VALUES ((CHECKSUM(g.n, 9) & 2147483647) % 100)) r(v)
CROSS APPLY (VALUES (
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(nm.nombre + '.' + a1.apellido),
            'á', 'a'), 'é', 'e'), 'í', 'i'), 'ó', 'o'), 'ú', 'u'), 'ñ', 'n')
    + CAST(g.n AS VARCHAR(3)) + '@correo.example')) c(correo)
ORDER BY g.n;

DROP TABLE #nombres;
DROP TABLE #apellidos;

-- =============================================================================
-- 4. MEMBRESÍAS | ASIGNACIÓN INICIAL Y RENOVACIONES HISTÓRICAS
-- =============================================================================
INSERT INTO socios.membresia (id_socio, id_plan, fecha_inicio, fecha_fin, estado_membresia)
SELECT s.id_socio, p.id_plan, s.fecha_registro,
       DATEADD(DAY, p.duracion_dias - 1, s.fecha_registro), 'Vigente'
FROM socios.socio s
CROSS APPLY (VALUES ((CHECKSUM(s.id_socio, 11) & 2147483647) % 100)) r(v)
JOIN socios.plan_membresia p
  ON p.id_plan = CASE WHEN r.v < 40 THEN 1 WHEN r.v < 62 THEN 2 WHEN r.v < 72 THEN 3
                      WHEN r.v < 82 THEN 4 ELSE 5 END
WHERE s.fecha_registro <= @fecha_corte
ORDER BY s.id_socio;

WHILE 1 = 1
BEGIN
    INSERT INTO socios.membresia (id_socio, id_plan, fecha_inicio, fecha_fin, estado_membresia)
    SELECT u.id_socio, p.id_plan, ini.d,
           DATEADD(DAY, p.duracion_dias - 1, ini.d), 'Vigente'
    FROM (SELECT id_socio, MAX(fecha_fin) AS ultimo_fin
          FROM socios.membresia GROUP BY id_socio) u
    JOIN socios.socio s ON s.id_socio = u.id_socio
    CROSS APPLY (VALUES (DATEADD(DAY, 1 + (CHECKSUM(u.id_socio, u.ultimo_fin, 21) & 2147483647) % 8, u.ultimo_fin))) ini(d)
    CROSS APPLY (VALUES ((CHECKSUM(u.id_socio, u.ultimo_fin, 31) & 2147483647) % 100)) rp(v)
    CROSS APPLY (VALUES ((CHECKSUM(u.id_socio, u.ultimo_fin, 41) & 2147483647) % 100)) rr(v)
    JOIN socios.plan_membresia p
      ON p.id_plan = CASE WHEN rp.v < 40 THEN 1 WHEN rp.v < 62 THEN 2 WHEN rp.v < 72 THEN 3
                          WHEN rp.v < 82 THEN 4 ELSE 5 END
    WHERE u.ultimo_fin < @fecha_corte
      AND ini.d <= @fecha_corte
      AND rr.v < CASE WHEN s.estado_socio = 'Activo' THEN 92 ELSE 0 END
    ORDER BY u.id_socio;

    IF @@ROWCOUNT = 0 BREAK;
END;

UPDATE socios.membresia
SET estado_membresia = CASE WHEN fecha_fin < @fecha_corte THEN 'Vencida' ELSE 'Vigente' END;

UPDATE m
SET m.estado_membresia = 'Cancelada'
FROM socios.membresia m
JOIN socios.socio s ON s.id_socio = m.id_socio
WHERE m.fecha_fin >= @fecha_corte
  AND (s.estado_socio <> 'Activo' OR (CHECKSUM(m.id_membresia, 51) & 2147483647) % 100 < 3);

-- =============================================================================
-- 5. PAGOS | HISTORIAL FINANCIERO ASOCIADO A MEMBRESÍAS
-- =============================================================================
INSERT INTO finanzas.pago (id_membresia, id_metodo_pago, monto, fecha_pago, estado_pago)
SELECT m.id_membresia,
       1 + (CHECKSUM(m.id_membresia, 61) & 2147483647) % 4,
       p.precio,
       DATEADD(MINUTE, 480 + (CHECKSUM(m.id_membresia, 71) & 2147483647) % 600, CAST(m.fecha_inicio AS DATETIME2)),
       CASE WHEN m.estado_membresia = 'Cancelada' THEN 'Anulado'
            WHEN m.fecha_inicio >= DATEADD(DAY, -5, @fecha_corte)
                 AND (CHECKSUM(m.id_membresia, 81) & 2147483647) % 100 < 30 THEN 'Pendiente'
            ELSE 'Completado' END
FROM socios.membresia m
JOIN socios.plan_membresia p ON p.id_plan = m.id_plan
ORDER BY m.id_membresia;

-- =============================================================================
-- 6. CLASES | PROGRAMACIÓN DE HORARIOS SIN TRASLAPES
-- =============================================================================
DECLARE @n_salas INT = (SELECT COUNT(*) FROM clases.sala);
DECLARE @n_tipos INT = (SELECT COUNT(*) FROM clases.tipo_clase);

SELECT ROW_NUMBER() OVER (ORDER BY id_entrenador) AS rn, id_entrenador
INTO #ent
FROM personal.entrenador
WHERE estado_entrenador = 'Activo';

DECLARE @n_ent INT = (SELECT COUNT(*) FROM #ent);
DECLARE @mitad INT = @n_ent / 2;

SELECT DATEADD(DAY, t.n, @inicio_hist) AS fecha,
       DATEDIFF(DAY, '19000101', DATEADD(DAY, t.n, @inicio_hist)) AS di
INTO #dias
FROM (SELECT TOP (400) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
      FROM sys.all_objects) t
WHERE DATEADD(DAY, t.n, @inicio_hist) <= DATEADD(DAY, 7, @fecha_corte)
  AND DATEDIFF(DAY, '19000101', DATEADD(DAY, t.n, @inicio_hist)) % 7 <> 6;

INSERT INTO clases.clase (id_tipo_clase, id_entrenador, id_sala, fecha_hora_inicio,
                          fecha_hora_fin, cupo_maximo, estado_clase)
SELECT t.id_tipo_clase,
       e.id_entrenador,
       sa.id_sala,
       ini.f,
       DATEADD(MINUTE, t.duracion_min, ini.f),
       sa.capacidad - (CHECKSUM(d.di, sl.slot, ln.lane, 101) & 2147483647) % 3,
       CASE WHEN d.fecha > @fecha_corte THEN 'Programada'
            WHEN (CHECKSUM(d.di, sl.slot, ln.lane, 111) & 2147483647) % 100 < 4 THEN 'Cancelada'
            ELSE 'Realizada' END
FROM #dias d
CROSS JOIN (VALUES (1, 360), (2, 480), (3, 1020), (4, 1140)) sl(slot, minutos)
CROSS JOIN (VALUES (1), (2)) ln(lane)
CROSS APPLY (VALUES (DATEADD(MINUTE, sl.minutos, CAST(d.fecha AS DATETIME2)))) ini(f)
JOIN clases.sala sa
  ON sa.id_sala = 1 + (d.di + sl.slot + ln.lane - 1) % @n_salas
JOIN clases.tipo_clase t
  ON t.id_tipo_clase = 1 + (CHECKSUM(d.di, sl.slot, ln.lane, 91) & 2147483647) % @n_tipos
JOIN #ent e
  ON e.rn = (d.di * 3 + sl.slot + (ln.lane - 1) * @mitad) % @n_ent + 1
ORDER BY ini.f, ln.lane;

-- =============================================================================
-- 7. RESERVAS | SIMULACIÓN DE ASISTENCIA Y RESPETO A LÍMITES POR PLAN
-- =============================================================================
SELECT c.id_clase,
       c.fecha_hora_inicio AS inicio,
       DATEDIFF(DAY, '19000101', c.fecha_hora_inicio) / 7 AS semana,
       CASE WHEN c.estado_clase = 'Programada' THEN 1 ELSE 0 END AS programada,
       CASE WHEN x.pct > 100 THEN c.cupo_maximo
            WHEN x.pct < 15  THEN CAST(CEILING(c.cupo_maximo * 0.15) AS INT)
            ELSE CAST(ROUND(c.cupo_maximo * x.pct / 100.0, 0) AS INT) END AS objetivo
INTO #obj
FROM clases.clase c
CROSS APPLY (VALUES (
      (CASE DATEPART(HOUR, c.fecha_hora_inicio) WHEN 6 THEN 40 WHEN 8 THEN 55 WHEN 17 THEN 75 ELSE 85 END
       + ((c.id_tipo_clase * 7) % 5 - 2) * 5
       + (CHECKSUM(c.id_clase, 161) & 2147483647) % 21 - 10)
      * CASE WHEN c.estado_clase = 'Programada' THEN 0.4 ELSE 1.0 END
)) x(pct)
WHERE c.estado_clase IN ('Realizada', 'Programada');

SELECT *
INTO #sel
FROM (
    SELECT o.id_clase, m.id_socio, m.id_plan, m.fecha_inicio AS fi,
           p.max_reservas_semana AS lim, o.inicio, o.semana, o.programada, o.objetivo,
           ROW_NUMBER() OVER (
               PARTITION BY o.id_clase
               ORDER BY (CHECKSUM(o.id_clase, m.id_socio, 121) & 2147483647) % 1000
                        - ((CHECKSUM(m.id_socio, 131) & 2147483647) % 100) * 5,
                        m.id_socio) AS rk
    FROM #obj o
    JOIN socios.membresia m
      ON m.estado_membresia <> 'Cancelada'
     AND CAST(o.inicio AS DATE) BETWEEN m.fecha_inicio AND m.fecha_fin
    JOIN socios.plan_membresia p ON p.id_plan = m.id_plan
) q
WHERE q.rk <= q.objetivo;

;WITH lim_sem AS (
    SELECT lim,
           ROW_NUMBER() OVER (PARTITION BY id_socio, semana ORDER BY inicio, id_clase) AS rn
    FROM #sel
)
DELETE FROM lim_sem WHERE lim IS NOT NULL AND rn > lim;

INSERT INTO clases.reserva (id_clase, id_socio, fecha_reserva, estado_reserva)
SELECT s.id_clase, s.id_socio,
       CASE WHEN y.f < CAST(s.fi AS DATETIME2) THEN CAST(s.fi AS DATETIME2) ELSE y.f END,
       CASE WHEN s.programada = 1 THEN 'Confirmada'
            WHEN r.roll < 8  THEN 'Cancelada'
            WHEN r.roll < 20 THEN 'No asistio'
            ELSE 'Asistida' END
FROM #sel s
CROSS APPLY (VALUES ((CHECKSUM(s.id_clase, s.id_socio, 141) & 2147483647) % 100)) r(roll)
CROSS APPLY (VALUES (
      CASE WHEN s.programada = 1
           THEN DATEADD(MINUTE, (CHECKSUM(s.id_clase, s.id_socio, 181) & 2147483647) % 1200, CAST(@fecha_corte AS DATETIME2))
           ELSE DATEADD(MINUTE, -(60 + (CHECKSUM(s.id_clase, s.id_socio, 171) & 2147483647) % 7200), s.inicio) END
)) y(f)
ORDER BY s.id_clase, s.id_socio;

-- =============================================================================
-- 8. ASISTENCIAS | CHECK-IN DE CLASES COMPLETADAS
-- =============================================================================
INSERT INTO clases.asistencia (id_reserva, fecha_checkin)
SELECT r.id_reserva,
       DATEADD(MINUTE, -((CHECKSUM(r.id_reserva, 151) & 2147483647) % 20), c.fecha_hora_inicio)
FROM clases.reserva r
JOIN clases.clase c ON c.id_clase = r.id_clase
WHERE r.estado_reserva = 'Asistida'
ORDER BY r.id_reserva;

DROP TABLE #sel;
DROP TABLE #obj;
DROP TABLE #dias;
DROP TABLE #ent;

-- =============================================================================
-- 9. AUDITORÍA DE CARGA | CONTEO DE REGISTROS Y ESTADOS
-- =============================================================================
SELECT 'personal.especialidad' AS tabla, COUNT(*) AS filas FROM personal.especialidad UNION ALL
SELECT 'personal.entrenador',   COUNT(*) FROM personal.entrenador   UNION ALL
SELECT 'socios.socio',          COUNT(*) FROM socios.socio          UNION ALL
SELECT 'socios.plan_membresia', COUNT(*) FROM socios.plan_membresia UNION ALL
SELECT 'socios.membresia',      COUNT(*) FROM socios.membresia      UNION ALL
SELECT 'finanzas.metodo_pago',  COUNT(*) FROM finanzas.metodo_pago  UNION ALL
SELECT 'finanzas.pago',         COUNT(*) FROM finanzas.pago         UNION ALL
SELECT 'clases.sala',           COUNT(*) FROM clases.sala           UNION ALL
SELECT 'clases.tipo_clase',     COUNT(*) FROM clases.tipo_clase     UNION ALL
SELECT 'clases.clase',          COUNT(*) FROM clases.clase          UNION ALL
SELECT 'clases.reserva',        COUNT(*) FROM clases.reserva        UNION ALL
SELECT 'clases.asistencia',     COUNT(*) FROM clases.asistencia;

SELECT 'membresia' AS tabla, estado_membresia AS estado, COUNT(*) AS filas FROM socios.membresia GROUP BY estado_membresia
UNION ALL SELECT 'pago',    estado_pago,    COUNT(*) FROM finanzas.pago  GROUP BY estado_pago
UNION ALL SELECT 'clase',   estado_clase,   COUNT(*) FROM clases.clase   GROUP BY estado_clase
UNION ALL SELECT 'reserva', estado_reserva, COUNT(*) FROM clases.reserva GROUP BY estado_reserva
ORDER BY tabla, estado;

-- =============================================================================
-- 10. VALIDACIÓN DE REGLAS DE NEGOCIO (LAS 4 CONSULTAS DEBEN RETORNAR 0 FILAS)
-- =============================================================================
-- 10.1 Clases con sobrecupo
SELECT c.id_clase, c.cupo_maximo, COUNT(*) AS reservas_activas
FROM   clases.clase c
JOIN   clases.reserva r ON r.id_clase = c.id_clase AND r.estado_reserva <> 'Cancelada'
GROUP BY c.id_clase, c.cupo_maximo
HAVING COUNT(*) > c.cupo_maximo;

-- 10.2 Reservas sin respaldo de membresía vigente
SELECT r.id_reserva, r.id_socio, c.fecha_hora_inicio
FROM   clases.reserva r
JOIN   clases.clase c ON c.id_clase = r.id_clase
WHERE  NOT EXISTS (
           SELECT 1 FROM socios.membresia m
           WHERE  m.id_socio = r.id_socio
             AND  m.estado_membresia <> 'Cancelada'
             AND  CAST(c.fecha_hora_inicio AS DATE) BETWEEN m.fecha_inicio AND m.fecha_fin
       );

-- 10.3 Exceso de reservas semanales según plan
SELECT r.id_socio, DATEDIFF(DAY, '19000101', c.fecha_hora_inicio) / 7 AS semana,
       COUNT(*) AS reservas, MAX(p.max_reservas_semana) AS limite
FROM   clases.reserva r
JOIN   clases.clase c ON c.id_clase = r.id_clase
JOIN   socios.membresia m ON m.id_socio = r.id_socio
       AND m.estado_membresia <> 'Cancelada'
       AND CAST(c.fecha_hora_inicio AS DATE) BETWEEN m.fecha_inicio AND m.fecha_fin
JOIN   socios.plan_membresia p ON p.id_plan = m.id_plan
WHERE  r.estado_reserva <> 'Cancelada' AND p.max_reservas_semana IS NOT NULL
GROUP BY r.id_socio, DATEDIFF(DAY, '19000101', c.fecha_hora_inicio) / 7
HAVING COUNT(*) > MAX(p.max_reservas_semana);

-- 10.4 Traslapes de sala o entrenador
SELECT a.id_clase AS clase_a, b.id_clase AS clase_b
FROM   clases.clase a
JOIN   clases.clase b
       ON  a.id_clase < b.id_clase
       AND a.estado_clase <> 'Cancelada' AND b.estado_clase <> 'Cancelada'
       AND (a.id_sala = b.id_sala OR a.id_entrenador = b.id_entrenador)
       AND a.fecha_hora_inicio < b.fecha_hora_fin
       AND a.fecha_hora_fin    > b.fecha_hora_inicio;
GO