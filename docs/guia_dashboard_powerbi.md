# Guía del Dashboard en Power BI: Gimnasio

Esta guía acompaña a `10_vistas_reportes.sql`. El archivo final se guarda como `powerbi/dashboard_gimnasio.pbix`.

## 1. Requisitos
- Power BI Desktop instalado.
- Scripts `01` a `04` y `10` ejecutados (datos cargados, login `lg_powerbi` y vistas del esquema `reportes`).
- La instancia de SQL Server en **autenticación mixta** (el login es de SQL Server, no de Windows).

## 2. Conexión a SQL Server

1. **Obtener datos → SQL Server**.
2. **Servidor:** el nombre de su instancia (por ejemplo `localhost`, `.` o `NOMBRE-PC\SQLEXPRESS`). **Base de datos:** `GimnasioDB`.
3. **Modo de conectividad: Importar.** Con unos pocos miles de filas es más rápido y permite todo el DAX. DirectQuery solo es necesario si se requiere información en tiempo real.
4. **Credenciales → Base de datos:** usuario `lg_powerbi` y su contraseña (la del script `04`).
5. En el Navegador solo aparecerán las vistas del esquema `reportes`: seleccionar las **7 vistas** y **Cargar**.

Que solo aparezcan las vistas es la prueba de que el principio de mínimo privilegio funciona: Power BI nunca ve las tablas base.

**Si falla la conexión:**

| Mensaje | Causa y solución |
|---|---|
| *Login failed for user 'lg_powerbi'* | La instancia está en modo solo Windows, o la contraseña es incorrecta. Cambiar a autenticación mixta y reiniciar el servicio. |
| Error de certificado o de cifrado | El servidor usa un certificado propio. Aceptar la conexión sin cifrar cuando Power BI lo pregunte (solo en entorno de práctica). |
| Vistas vacías o no visibles | Verificar que el script `10` se ejecutó y que `usr_powerbi` pertenece a `rol_reportes`. |

## 3. Modelo de datos

Renombrar las consultas quitando el prefijo `vw_` para que las medidas sean legibles.

| Tabla | Tipo | Contenido |
|---|---|---|
| `dim_plan` | Dimensión | Planes de membresía |
| `dim_entrenador` | Dimensión | Entrenadores y especialidad |
| `Calendario` | Dimensión (se crea en DAX) | Fechas |
| `ingresos_mensuales` | Hechos | Ingresos por mes y plan |
| `ocupacion_clases` | Hechos | Una fila por clase |
| `ranking_entrenadores` | Hechos | Ranking por entrenador y clase |
| `socios_constancia` | Hechos | Una fila por socio |
| `membresias` | Hechos | Una fila por membresía |

**Tabla Calendario** (Modelado → Nueva tabla):

```dax
Calendario =
ADDCOLUMNS(
    CALENDAR(DATE(2025, 6, 1), DATE(2026, 12, 31)),
    "Año", YEAR([Date]),
    "MesInicio", DATE(YEAR([Date]), MONTH([Date]), 1),
    "Mes", FORMAT([Date], "mmm yyyy")
)
```
Renombrar la columna `Date` a `Fecha`, marcar la tabla como **tabla de fechas** y ordenar `Mes` por `MesInicio`.

**Relaciones** (todas uno a varios, filtro en un sentido):

| Desde (uno) | Hacia (varios) |
|---|---|
| `Calendario[Fecha]` | `ocupacion_clases[fecha_clase]` |
| `Calendario[Fecha]` | `ingresos_mensuales[mes]` |
| `dim_plan[id_plan]` | `ingresos_mensuales[id_plan]` |
| `dim_plan[id_plan]` | `membresias[id_plan]` |
| `dim_entrenador[id_entrenador]` | `ocupacion_clases[id_entrenador]` |
| `dim_entrenador[id_entrenador]` | `ranking_entrenadores[id_entrenador]` |
| `socios_constancia[id_socio]` | `membresias[id_socio]` |

## 4. Medidas DAX

```dax
Ingresos = SUM(ingresos_mensuales[ingresos])

Membresias vigentes =
CALCULATE(COUNTROWS(membresias), membresias[estado_membresia] = "Vigente")

Socios activos =
CALCULATE(DISTINCTCOUNT(socios_constancia[id_socio]), socios_constancia[estado_socio] = "Activo")

Clases realizadas =
CALCULATE(COUNTROWS(ocupacion_clases), ocupacion_clases[estado_clase] = "Realizada")

Cupo total =
CALCULATE(SUM(ocupacion_clases[cupo_maximo]), ocupacion_clases[estado_clase] = "Realizada")

Reservas activas =
CALCULATE(SUM(ocupacion_clases[reservas_activas]), ocupacion_clases[estado_clase] = "Realizada")

Asistentes =
CALCULATE(SUM(ocupacion_clases[asistentes]), ocupacion_clases[estado_clase] = "Realizada")

% Ocupacion = DIVIDE([Reservas activas], [Cupo total])

% Asistencia = DIVIDE([Asistentes], [Reservas activas])

Ingresos mes anterior = CALCULATE([Ingresos], DATEADD(Calendario[Fecha], -1, MONTH))

Variacion % = DIVIDE([Ingresos] - [Ingresos mes anterior], [Ingresos mes anterior])
```

Dar formato de porcentaje a `% Ocupacion`, `% Asistencia` y `Variacion %`, y de moneda a `Ingresos`.

## 5. Narrativas dinámicas (medidas de texto)

Se muestran en tarjetas o cuadros de texto y cambian con los filtros.

```dax
Narrativa ingresos =
VAR MesAct = CALCULATE(MAX(ingresos_mensuales[mes]), ingresos_mensuales[mes] < DATE(2026, 11, 1))
VAR IngAct = CALCULATE([Ingresos], ingresos_mensuales[mes] = MesAct)
VAR IngAnt = CALCULATE([Ingresos], ingresos_mensuales[mes] = EDATE(MesAct, -1))
VAR Var    = DIVIDE(IngAct - IngAnt, IngAnt)
RETURN "En " & FORMAT(MesAct, "mmmm yyyy") & " los ingresos fueron " & FORMAT(IngAct, "$#,##0") &
       ", " & IF(Var >= 0, "un aumento", "una disminución") & " de " & FORMAT(ABS(Var), "0.0%") &
       " frente al mes anterior."

Narrativa clase top =
VAR Top = TOPN(1, VALUES(ocupacion_clases[nombre_clase]), [Asistentes], DESC)
RETURN "La clase con más asistentes es " & MAXX(Top, ocupacion_clases[nombre_clase]) &
       ", con " & FORMAT(CALCULATE([Asistentes], Top), "#,##0") & " asistencias."

Narrativa asistencia =
"De cada 100 reservas activas, " & FORMAT([% Asistencia] * 100, "0") &
" terminan en asistencia y la ocupación promedio de las clases es " & FORMAT([% Ocupacion], "0%") & "."
```

Además puede añadirse el visual **Narrativa inteligente** (Smart narrative) sobre el gráfico de ingresos, que redacta el texto automáticamente.

## 6. Diseño de las páginas

### Página 1: Resumen ejecutivo

| Zona | Visual | Campos | Para qué sirve |
|---|---|---|---|
| Superior | 5 **tarjetas KPI** | `Ingresos`, `Membresias vigentes`, `Socios activos`, `% Ocupacion`, `% Asistencia` | Estado general del negocio |
| Centro izquierda | **Columnas apiladas + línea** | Eje `Calendario[Mes]`, leyenda `dim_plan[nombre_plan]`, valores `Ingresos` y `ingresos_acumulados_plan` | Evolución de ingresos y aporte de cada plan |
| Centro derecha | **Barras horizontales** | `nombre_clase` por `Asistentes` (Top 10) | Clases más populares |
| Inferior izquierda | **Matriz con mapa de calor** | Filas `dia_semana`, columnas `hora_inicio`, valores `% Ocupacion` (formato condicional de color) | Franjas de mayor y menor demanda |
| Inferior derecha | **Cuadro de texto / tarjetas** | Las 3 medidas de narrativa | Conclusiones en lenguaje natural |
| Lateral | **Segmentaciones** | `Calendario[Fecha]` (entre), `dim_plan[nombre_plan]`, `dim_entrenador[nombre_entrenador]`, `ocupacion_clases[franja]` | Filtros interactivos |

**Detalle importante:** noviembre de 2026 es un mes incompleto (los datos llegan al 7). En los gráficos de ingresos agregar un filtro de visual `mes < 01/11/2026` para no mostrar una caída falsa.

### Página 2: Entrenadores y socios

| Visual | Campos | Para qué sirve |
|---|---|---|
| **Barras agrupadas** | `nombre_entrenador` por `asistentes` y `pct_ocupacion` de `ranking_entrenadores` | Desempeño de cada entrenador |
| **Tabla con barras de datos** | `nombre_entrenador`, `nombre_clase`, `sesiones`, `pct_ocupacion`, `ranking_en_entrenador` | Detalle del ranking (RANK y DENSE_RANK) |
| **Anillo** | `cuartil_constancia` y conteo de `id_socio` | Cuántos socios son muy o poco constantes |
| **Gráfico de dispersión** | Eje X `reservas_pasadas`, eje Y `pct_asistencia`, detalle `nombre` | Socios que reservan mucho y asisten poco |
| **Anillo o barras** | `estado_membresia` por `Membresias vigentes` (conteo) | Salud de las membresías |
| **Segmentación** | `estado_socio` y `plan_ultimo` | Filtrar por perfil de socio |

Para navegar entre páginas, agregar botones o una barra de navegación con *Insertar → Botones → Navegador*.

## 7. Correspondencia con la rúbrica

| Nivel "Excelente" pide | Cómo se cubre |
|---|---|
| KPIs | 5 tarjetas en la página 1 |
| Filtros | Segmentaciones de fecha, plan, entrenador, franja, estado y plan del socio |
| Narrativas | 3 medidas dinámicas más el visual de narrativa inteligente |
| Visualizaciones útiles | 9 visuales entre ambas páginas, con mapa de calor y formato condicional |
| Conectado a SQL Server | Importación desde `GimnasioDB` con el usuario de solo lectura `lg_powerbi` |

## 8. Buenas prácticas de presentación
- Una paleta de 3 o 4 colores y los mismos colores para el mismo plan en todos los gráficos.
- Títulos que respondan una pregunta ("¿Qué plan genera más ingresos?"), no solo el nombre del campo.
- Ocultar las columnas técnicas (`id_*`) del panel de campos.
- Revisar las interacciones entre visuales (*Formato → Editar interacciones*): el filtro de plan afecta ingresos y membresías, y el de entrenador afecta ocupación y ranking, pero no al revés.

## 9. Evidencias para el informe
- Captura de la conexión con `lg_powerbi` y del Navegador con solo el esquema `reportes`.
- Captura del modelo de datos (vista de relaciones).
- Capturas de las 2 páginas con y sin filtros aplicados.
- Captura de las medidas DAX.
- Resultado de la sección 8 de `10_vistas_reportes.sql` (filas por vista y acceso denegado a las tablas base).

## 10. Preguntas probables en la defensa

| Pregunta | Idea de respuesta |
|---|---|
| ¿Por qué vistas y no tablas directas? | Aíslan la capa de lectura, aplican mínimo privilegio y exponen solo columnas no sensibles (sin DUI ni contacto). |
| ¿Por qué modo Importar? | El volumen es pequeño, mejora el rendimiento y habilita todo el DAX; la actualización se hace al refrescar el modelo. |
| ¿Dónde se usan las funciones ventana? | En las vistas de ingresos, ranking y constancia; Power BI recibe los resultados ya calculados. |
| ¿Qué pasaría si el usuario de Power BI intenta leer `socios.socio`? | Está denegado (se demuestra en el script 10). |
| ¿Cómo se actualizan los datos? | Con *Actualizar* en Desktop; para actualización programada haría falta publicar en el servicio de Power BI con un gateway. |
