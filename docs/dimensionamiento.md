# Dimensionamiento de la Base de Datos: GimnasioDB

## 1. Alcance y supuestos

Se estima cuánto espacio ocupa la base hoy y cuánto ocupará en 1, 3 y 5 años, incluyendo el **factor por índices**.

**Volumen actual.** Los conteos de socios, entrenadores, clases y catálogos son exactos (salen del script de carga). Los de `membresia`, `pago`, `reserva` y `asistencia` son **estimaciones** obtenidas simulando la lógica del script 03 (varias corridas dieron entre 585 y 657 membresías y entre 17,470 y 17,880 reservas). Deben reemplazarse por los valores reales de la validación del script 03 (sección 9 de este documento).

| Tabla | Filas usadas | Origen |
|---|---|---|
| `socios.socio` | 200 | Exacto |
| `socios.membresia` | 600 | Estimado |
| `finanzas.pago` | 600 | Igual a membresía (un pago por membresía) |
| `clases.clase` | 1,320 | Exacto |
| `clases.reserva` | 17,000 | Estimado |
| `clases.asistencia` | 13,000 | Estimado (≈ 80 % de las reservas históricas) |
| Catálogos | 6 + 8 + 5 + 4 + 4 + 10 | Exacto |

**Supuestos de crecimiento:**

| Concepto | Valor | Base |
|---|---|---|
| Clases nuevas por año | 2,496 | 6 días × 8 clases × 52 semanas (horario constante) |
| Reservas nuevas por año | 32,100 | ≈ 12.9 reservas por clase × 2,496 |
| Asistencias nuevas por año | 24,700 | ≈ 77 % de las reservas |
| Socios nuevos por año | 140 | 200 socios en 17 meses de historia |
| Membresías y pagos por año | 425 | 600 en 17 meses |
| Crecimiento anual de la demanda | 15 % | Aplicado a socios, membresías, pagos, reservas y asistencias |
| Holgura | 30 % | Fragmentación, páginas parcialmente llenas y divisiones de página |

## 2. Metodología

Se usan las fórmulas de Microsoft para estimar el tamaño de una tabla con índice agrupado (la PK de cada tabla es el índice agrupado, por lo que los datos viven en él). Una página de datos mide 8 KB y ofrece 8,096 bytes útiles.

```
Fila fija        = suma de columnas de tamaño fijo   (int 4 · date 3 · datetime2 8 · numeric(8,2) 5)
Fila variable    = 2 + (2 × columnas variables) + promedio real de bytes de esas columnas
Mapa de nulos    = 2 + ((columnas + 7) / 8)             (división entera)
Tamaño de fila   = fija + variable + mapa de nulos + 4  (4 = encabezado de fila)
Filas por página = piso( 8096 / (tamaño de fila + 2) )  (2 = entrada en la tabla de ranuras)
Páginas          = techo( filas / filas por página )
Tamaño           = páginas × 8 KB
```

Para un índice no agrupado (hoja): `fila de hoja = columnas de la clave + columnas incluidas + clave del índice agrupado (id, 4 B) + mapa de nulos + 1`, con las mismas fórmulas de filas por página y páginas. A las páginas hoja se suman los niveles intermedios hasta llegar a la raíz (fila no hoja = clave + mapa de nulos + 1 + 6 de puntero a la página hija).

El **factor por índices** es `páginas de índices no agrupados / páginas de datos`.

### Ejemplo completo: `clases.reserva`

| Paso | Cálculo | Resultado |
|---|---|---|
| Columnas fijas | `id_reserva` 4 + `id_clase` 4 + `id_socio` 4 + `fecha_reserva` 8 | 20 B |
| Columna variable | `estado_reserva` (promedio 9 B): 2 + 2×1 + 9 | 13 B |
| Mapa de nulos | 2 + ((5 + 7) / 8) | 3 B |
| **Tamaño de fila** | 20 + 13 + 3 + 4 | **40 B** |
| Filas por página | piso(8096 / (40 + 2)) | 192 |
| Páginas | techo(17,000 / 192) | 89 |
| **Tamaño** | 89 × 8 KB | **712 KB** |

Índice `UQ_reserva_clase_socio` (`id_clase`, `id_socio`): fila de hoja = 12 (dos claves + id agrupado) + 3 (mapa de nulos) + 1 = 16 B → 449 filas por página → 38 páginas hoja + 1 raíz = **39 páginas (312 KB)**.

## 3. Tamaño de las tablas (datos)

| Tabla | Filas | Cols. | Fijo (B) | Variable (B) | Mapa nulos (B) | Fila (B) | Filas/pág. | Páginas | KB |
|---|---|---|---|---|---|---|---|---|---|
| `personal.especialidad` | 6 | 2 | 4 | 26 | 3 | 37 | 207 | 1 | 8 |
| `personal.entrenador` | 8 | 8 | 11 | 87 | 3 | 105 | 75 | 1 | 8 |
| `socios.socio` | 200 | 8 | 10 | 93 | 3 | 110 | 72 | 3 | 24 |
| `socios.plan_membresia` | 5 | 5 | 17 | 16 | 3 | 40 | 192 | 1 | 8 |
| `socios.membresia` | 600 | 6 | 18 | 11 | 3 | 36 | 213 | 3 | 24 |
| `finanzas.metodo_pago` | 4 | 2 | 4 | 20 | 3 | 31 | 245 | 1 | 8 |
| `finanzas.pago` | 600 | 6 | 25 | 14 | 3 | 46 | 168 | 4 | 32 |
| `clases.sala` | 4 | 3 | 8 | 18 | 3 | 33 | 231 | 1 | 8 |
| `clases.tipo_clase` | 10 | 5 | 8 | 89 | 3 | 104 | 76 | 1 | 8 |
| `clases.clase` | 1,320 | 8 | 36 | 13 | 3 | 56 | 139 | 10 | 80 |
| `clases.reserva` | 17,000 | 5 | 20 | 13 | 3 | 40 | 192 | 89 | 712 |
| `clases.asistencia` | 13,000 | 3 | 16 | 0 | 3 | 23 | 323 | 41 | 328 |
| **Total datos** | | | | | | | **156** | **1248** |

Promedios de columnas variables usados: `dui` 10 B, `nombre` 26 B, `correo` 30 B, `teléfono` 9 B, columnas `estado_*` entre 6 y 10 B, `descripcion` 52 B.

## 4. Índices y factor por índices

### 4.1 Índices que ya existen (restricciones UNIQUE)

| Tabla | Índice | Filas | Fila hoja (B) | Filas/pág. | Páginas | KB |
|---|---|---|---|---|---|---|
| `socios.socio` | `UQ_socio_dui` | 200 | 22 | 337 | 1 | 8 |
| `socios.socio` | `UQ_socio_correo` | 200 | 42 | 184 | 3 | 24 |
| `personal.entrenador` | `UQ_entrenador_dui` | 8 | 22 | 337 | 1 | 8 |
| `personal.entrenador` | `UQ_entrenador_correo` | 8 | 40 | 192 | 1 | 8 |
| `personal.especialidad` | `UQ_especialidad_nombre` | 6 | 34 | 224 | 1 | 8 |
| `socios.plan_membresia` | `UQ_plan_membresia_nombre` | 5 | 24 | 311 | 1 | 8 |
| `finanzas.metodo_pago` | `UQ_metodo_pago_nombre` | 4 | 28 | 269 | 1 | 8 |
| `clases.sala` | `UQ_sala_nombre` | 4 | 26 | 289 | 1 | 8 |
| `clases.tipo_clase` | `UQ_tipo_clase_nombre` | 10 | 30 | 253 | 1 | 8 |
| `clases.reserva` | `UQ_reserva_clase_socio` | 17,000 | 16 | 449 | 39 | 312 |
| `clases.asistencia` | `UQ_asistencia_reserva` | 13,000 | 12 | 578 | 24 | 192 |
| **Total** | | | | | **74** | **592** |

### 4.2 Índices de optimización (`06_indices.sql`)

Cada índice respalda una de las tres consultas de `07_consultas_avanzadas.sql`.

| Tabla | Índice | Filas | Fila hoja (B) | Filas/pág. | Páginas | KB |
|---|---|---|---|---|---|---|
| `clases.reserva` | `IX_reserva_socio (id_socio) INCLUDE (id_clase, estado_reserva)` | 17,000 | 29 | 261 | 67 | 536 |
| `clases.clase` | `IX_clase_fecha (fecha_hora_inicio) INCLUDE (tipo, entrenador, estado, cupo)` | 1,320 | 41 | 188 | 9 | 72 |
| `finanzas.pago` | `IX_pago_fecha (fecha_pago) INCLUDE (id_membresia, monto, estado_pago)` | 600 | 39 | 197 | 5 | 40 |
| `socios.membresia` | `IX_membresia_socio (id_socio, fecha_inicio) INCLUDE (id_plan, fecha_fin, estado)` | 600 | 33 | 231 | 4 | 32 |
| `clases.reserva` | `IX_reserva_clase_estado (id_clase) INCLUDE (estado_reserva)` | 17,000 | 25 | 299 | 58 | 464 |
| **Total** | | | | | **143** | **1144** |

### 4.3 Factor por índices

| Tabla | Páginas de datos | Páginas de índices | Factor |
|---|---|---|---|
| `personal.especialidad` | 1 | 1 | 1.00 |
| `personal.entrenador` | 1 | 2 | 2.00 |
| `socios.socio` | 3 | 4 | 1.33 |
| `socios.plan_membresia` | 1 | 1 | 1.00 |
| `socios.membresia` | 3 | 4 | 1.33 |
| `finanzas.metodo_pago` | 1 | 1 | 1.00 |
| `finanzas.pago` | 4 | 5 | 1.25 |
| `clases.sala` | 1 | 1 | 1.00 |
| `clases.tipo_clase` | 1 | 1 | 1.00 |
| `clases.clase` | 10 | 9 | 0.90 |
| `clases.reserva` | 89 | 164 | 1.84 |
| `clases.asistencia` | 41 | 24 | 0.59 |
| **Total** | **156** | **217** | **1.39** |

- Solo con los índices UNIQUE el factor es **0.47**.
- Con los índices de optimización sube a **1.39**: por cada 1 MB de datos hay aproximadamente 1.4 MB de índices.
- En `reserva` los índices pesan más que los datos (factor 1.84), porque las filas son cortas y cada índice replica la clave agrupada. En `asistencia`, con un solo índice, el factor es 0.59.

## 5. Tamaño total actual

| Componente | Páginas | MB |
|---|---|---|
| Datos (índices agrupados) | 156 | 1.22 |
| Índices UNIQUE | 74 | 0.58 |
| Índices de optimización | 143 | 1.12 |
| **Total** | **373** | **2.91** |

## 6. Proyección de crecimiento

| Horizonte | Socios | Reservas | Asistencias | Datos (MB) | Índices (MB) | Total (MB) | Factor índices |
|---|---|---|---|---|---|---|---|
| Actual | 200 | 17,000 | 13,000 | 1.22 | 1.70 | 2.91 | 1.39 |
| 1 año | 340 | 49,100 | 37,700 | 3.31 | 4.55 | 7.86 | 1.37 |
| 3 años | 686 | 128,467 | 98,771 | 8.49 | 11.55 | 20.04 | 1.36 |
| 5 años | 1,144 | 233,430 | 179,537 | 15.34 | 20.87 | 36.20 | 1.36 |

Con 15 % de crecimiento anual, en 5 años la base llega a unos **36.20 MB** de datos más índices. La tabla `reserva` y sus índices concentran la mayor parte del espacio, y `asistencia` es la segunda.

## 7. Tamaño recomendado de archivos

| Concepto | Cálculo | Resultado |
|---|---|---|
| Datos e índices a 5 años | Tabla de la sección 6 | 36.20 MB |
| Con holgura del 30 % | 36.20 × 1.30 | 47.1 MB |
| Sistema (catálogo, páginas de asignación) | La base nueva parte de ~8 MB | ~8 MB |
| **Archivo de datos inicial** | 47.1 + 8 ≈ 55 MB, redondeado a 64 MB (cubre 5 años sin crecer) | **64 MB** |
| **Archivo de log inicial** | Cubre la carga inicial (~10 MB de log estimados) con margen para reversión; en modelo FULL el log se libera con cada backup de log | **64 MB** |
| Crecimiento automático | Incrementos fijos (no porcentuales) para evitar crecimientos cada vez mayores | 32 MB (datos y log) |

Con volúmenes tan pequeños, el tamaño real de los archivos lo fija el mínimo práctico y no los datos. Lo importante es dimensionarlos con una cifra justificada, no dejar los 8 MB por defecto.

Para aplicar los tamaños (ejecutar una vez, después del script 01):

```sql
ALTER DATABASE GimnasioDB MODIFY FILE (NAME = N'GimnasioDB',     SIZE = 64MB, FILEGROWTH = 32MB);
ALTER DATABASE GimnasioDB MODIFY FILE (NAME = N'GimnasioDB_log', SIZE = 64MB, FILEGROWTH = 32MB);
```

Para el plan de respaldo, el tamaño usado de la base (2.91 MB hoy y ~36.20 MB a 5 años) es también el orden de magnitud de un backup completo sin compresión.

## 8. Resumen para el informe

- Método: fórmulas de Microsoft por tabla y por índice, con promedios reales de columnas variables.
- Volumen actual estimado: ~2.91 MB, de los cuales ~1.22 MB son datos.
- **Factor por índices: 1.39** (con los 5 índices de optimización y los UNIQUE).
- Crecimiento: ~36.20 MB a 5 años con 15 % anual y 30 % de holgura recomendada.
- Archivos recomendados: datos 64 MB y log 64 MB, con crecimiento de 32 MB.

## 9. Validación contra SQL Server

Ejecutar en `GimnasioDB` después de cargar los datos, y anotar los valores reales en la columna "Real". Si difieren mucho de la estimación, se ajusta la sección 3.

```sql
-- Filas, datos e índices por tabla (KB)
SELECT OBJECT_SCHEMA_NAME(ps.object_id) + '.' + OBJECT_NAME(ps.object_id) AS tabla,
       SUM(CASE WHEN ps.index_id IN (0, 1) THEN ps.row_count END)        AS filas,
       SUM(CASE WHEN ps.index_id IN (0, 1) THEN ps.used_page_count END) * 8 AS datos_kb,
       SUM(CASE WHEN ps.index_id > 1       THEN ps.used_page_count END) * 8 AS indices_kb
FROM sys.dm_db_partition_stats ps
JOIN sys.tables t ON t.object_id = ps.object_id
GROUP BY ps.object_id
ORDER BY datos_kb DESC;

-- Tamaño total y archivos
EXEC sp_spaceused;
SELECT name, size * 8 / 1024 AS mb, growth * 8 / 1024 AS crecimiento_mb FROM sys.database_files;
```

| Tabla | Filas reales | Datos estimados (KB) | Datos reales (KB) | Índices estimados (KB) | Índices reales (KB) |
|---|---|---|---|---|---|
| `clases.reserva` | | 712 | | 1312 | |
| `clases.asistencia` | | 328 | | 192 | |
| `clases.clase` | | 80 | | 72 | |
| `finanzas.pago` | | 32 | | 40 | |
| `socios.membresia` | | 24 | | 32 | |
| `socios.socio` | | 24 | | 32 | |

`used_page_count` incluye las páginas de administración del índice, así que es normal que el valor real supere ligeramente al calculado, sobre todo en tablas pequeñas, donde cada índice ocupa como mínimo una página de 8 KB.
