# Estrategia de Respaldo y Recuperación: GimnasioDB

## 1. Objetivos: RPO y RTO

| Objetivo | Valor | Qué significa | Justificación |
|---|---|---|---|
| **RPO** (Recovery Point Objective) | **15 minutos** | Máxima cantidad de datos que se acepta perder | El gimnasio registra reservas, check-in y pagos durante el día. Perder 15 minutos equivale a unas pocas reservas, que se pueden volver a capturar. |
| **RTO** (Recovery Time Objective) | **30 minutos** | Máximo tiempo que el sistema puede estar fuera de servicio | La recepción puede atender manualmente por un periodo corto; más de media hora afecta el control de acceso y el cobro. |

## 2. Modelo de recuperación

`GimnasioDB` usa el modelo **FULL** (se configura en `01_crear_bd_y_esquemas.sql`). Es obligatorio para respaldar el log de transacciones, y el log es lo que permite cumplir el RPO de 15 minutos y recuperar a un punto exacto en el tiempo (`STOPAT`).

## 3. Tipos de respaldo y calendario

| Tipo | Frecuencia | Horario | Job de SQL Agent | Para qué sirve |
|---|---|---|---|---|
| Completo | Semanal | Domingo 23:30 | `GYM_Backup_Full` | Base de toda restauración |
| Diferencial | Diario | Lunes a sábado 23:30 | `GYM_Backup_Diferencial` | Acorta la cadena: solo cambios desde el último completo |
| Log de transacciones | Cada 15 minutos | Todo el día | `GYM_Backup_Log` | Cumple el RPO y permite recuperar a un momento exacto |
| Verificación de integridad | Semanal | Domingo 22:30 | `GYM_Verificacion_Integridad` | `DBCC CHECKDB`: detecta corrupción antes del respaldo completo |
| Limpieza de respaldos | Semanal | Domingo 22:00 | `GYM_Limpieza_Backups` | Elimina archivos con más de 28 días |

Los respaldos se hacen de noche (después del cierre) para no competir con la operación. Todos usan `COMPRESSION` y `CHECKSUM`: la compresión reduce el espacio y el checksum permite detectar archivos dañados al verificar o restaurar. Los archivos llevan la fecha y hora en el nombre (`GimnasioDB_FULL_20261108_233000.bak`).

**Retención:** 28 días (4 respaldos completos, 24 diferenciales y las cadenas de log asociadas). Orden de magnitud de espacio: unos 100 a 150 MB, porque cada archivo de log sin mucha actividad pesa decenas de KB.

## 4. Cómo la estrategia cumple el RPO y el RTO

### RPO de 15 minutos
Un log cada 15 minutos garantiza que, ante una falla, solo se pierden las transacciones posteriores al último log respaldado: **máximo 15 minutos**.

### RTO de 30 minutos
La restauración necesita el último completo, el último diferencial y los logs posteriores al diferencial.

| Etapa | Estimación |
|---|---|
| Detectar el problema y decidir restaurar | 10 min |
| Ubicar los archivos y revisar la secuencia | 5 min |
| Restaurar completo + diferencial + logs | 2 a 3 min |
| Validar los datos y reabrir el sistema | 5 min |
| **Total estimado** | **≈ 22 min** |

El diferencial diario limita la cadena de logs: en el peor caso hay **95 archivos de log** por restaurar (un día completo menos un intervalo). Cada uno pesa muy poco y se aplica en menos de un segundo, así que la cadena no pone en riesgo el RTO. Sin diferenciales habría que aplicar hasta 7 días de logs (más de 600 archivos).

**Tiempo medido en la demostración:** el script `08_backup_restore.sql` mide el tiempo de restauración (completo, diferencial y 2 logs) en milisegundos. Anotar aquí el valor obtenido: ______ ms.

## 5. Procedimientos de recuperación

| Situación | Procedimiento |
|---|---|
| **Borrado o modificación accidental de datos** | Restaurar a una **base nueva** (`RESTORE ... WITH MOVE`) hasta el momento anterior al error con `STOPAT`, y copiar de ahí los datos afectados a la base de producción. No se sobrescribe la base original. Es lo que muestra el script 08. |
| **Pérdida o corrupción de la base** | Respaldar el log pendiente (`BACKUP LOG ... WITH NO_TRUNCATE`) si es posible; restaurar completo (`NORECOVERY`), diferencial (`NORECOVERY`), todos los logs en orden y el último con `RECOVERY`. |
| **Corrupción detectada por `CHECKDB`** | Restaurar desde el último respaldo íntegro verificado con `RESTORE VERIFYONLY ... WITH CHECKSUM`. |

Secuencia general:

```sql
RESTORE DATABASE GimnasioDB FROM DISK = '<completo>'    WITH NORECOVERY, REPLACE;
RESTORE DATABASE GimnasioDB FROM DISK = '<diferencial>' WITH NORECOVERY;
RESTORE LOG      GimnasioDB FROM DISK = '<log 1>'       WITH NORECOVERY;
-- ... resto de logs, en orden ...
RESTORE LOG      GimnasioDB FROM DISK = '<último log>'  WITH STOPAT = '<fecha y hora>', RECOVERY;
```

## 6. Demostración (`08_backup_restore.sql`)

Simula un desastre sin dañar `GimnasioDB`:

1. Crea `dbo.prueba_pagos`, copia de `finanzas.pago` (600 filas aprox.).
2. Respalda: completo → +10 filas → diferencial → +10 filas → log 1 → +10 filas.
3. Registra el momento (`@momento`) y **borra todas las filas** de la tabla de prueba.
4. Respalda el log 2 (que ya contiene el borrado) y **verifica** los 4 archivos con `RESTORE VERIFYONLY`.
5. Restaura todo en `GimnasioDB_Recuperada` con `STOPAT = @momento`.
6. Compara: `GimnasioDB` queda con 0 filas, `GimnasioDB_Recuperada` con las filas previas al borrado (630 si la tabla parte de 600).

## 7. Jobs de SQL Server Agent (`09_jobs_sql_agent.sql`)

El script crea los 5 jobs de la sección 3, cada uno con un paso T-SQL y su calendario, los ejecuta una vez en el orden correcto y muestra tres consultas de evidencia:
- Jobs y su próxima ejecución.
- Historial con el resultado de cada ejecución (`Exitoso` o `Fallido`).
- Archivos de respaldo generados (tipo, fecha, tamaño comprimido).

## 8. Evidencias para el informe

| Evidencia | Dónde se obtiene |
|---|---|
| Resultado de `RESTORE VERIFYONLY` en los 4 archivos | Pestaña Mensajes del script 08, sección 4 |
| Comparación 0 filas contra filas recuperadas y tiempo de restauración | Script 08, sección 6 |
| Historial de respaldos (completo, diferencial, log) | Script 08, sección 7 |
| Los 5 jobs y su calendario | SSMS (SQL Server Agent → Jobs) y script 09, sección 6.1 |
| Jobs ejecutados con éxito | Script 09, sección 6.2 |
| Archivos `.bak` y `.trn` en la carpeta de respaldos | Explorador de archivos |

## 9. Limitaciones y mejoras

- Los respaldos se guardan en la misma máquina que la base. En producción deben copiarse a **otro disco, servidor o nube** (regla 3-2-1: 3 copias, 2 medios distintos, 1 fuera del sitio), porque si falla el disco se pierden la base y sus respaldos.
- La limpieza de archivos usa `xp_delete_file`, un procedimiento no documentado por Microsoft pero muy usado; un plan de mantenimiento o un script de PowerShell serían alternativas.
- Los jobs no envían notificaciones. Se puede agregar un operador con correo para avisar de fallos.
- Las pruebas de restauración deben repetirse periódicamente: un respaldo no probado no es una garantía.
