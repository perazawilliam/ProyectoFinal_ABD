# Seguridad y Auditoría: GimnasioDB

## 1. Principios aplicados

| Principio | Cómo se aplica |
|---|---|
| Mínimo privilegio | Cada rol recibe solo lo que su función necesita. Nadie, salvo el administrador, tiene `DELETE` sobre pagos ni acceso a todas las tablas. |
| Roles por función | Los permisos se asignan a roles, nunca a usuarios. Un usuario nuevo solo se agrega al rol que corresponda. |
| Permisos por esquema | Los esquemas agrupan objetos por área de negocio, así que un `GRANT ... ON SCHEMA::` cubre los objetos actuales y futuros. |
| Datos sensibles protegidos | Permisos por columna: el entrenador ve `id_socio` y `nombre`, y recepción ve solo `id_entrenador` y `nombre_entrenador`. DUI, correo y teléfono quedan fuera. |
| Reglas de negocio en la base | Las reservas y los check-in se crean solo con procedimientos almacenados, que validan cupo, membresía y límites. El `DENY` directo impide saltarse esas reglas. |
| Trazabilidad | SQL Server Audit registra quién hizo qué, y una bitácora propia guarda los valores anteriores y nuevos de los pagos. |

## 2. Logins, usuarios y roles

| Login (servidor) | Usuario (base de datos) | Rol | Quién lo usa |
|---|---|---|---|
| `lg_recepcion` | `usr_recepcion` | `rol_recepcion` | Personal de recepción |
| `lg_entrenador` | `usr_entrenador` | `rol_entrenador` | Entrenadores |
| `lg_finanzas` | `usr_finanzas` | `rol_finanzas` | Administración y cobros |
| `lg_powerbi` | `usr_powerbi` | `rol_reportes` | Conexión de Power BI |

Las cuentas usan `CHECK_POLICY = ON` (política de contraseñas de Windows). El administrador de la base (sysadmin) queda fuera de este esquema de roles.

## 3. Matriz de privilegios

**S** = SELECT · **I** = INSERT · **U** = UPDATE · **D** = DELETE · **E** = EXECUTE · **–** = sin acceso · **DENY** = prohibido de forma explícita

| Objeto | rol_recepcion | rol_entrenador | rol_finanzas | rol_reportes |
|---|---|---|---|---|
| `socios.socio` | S, I, U | S (solo `id_socio`, `nombre`) | – | – |
| `socios.plan_membresia` | S | – | S | – |
| `socios.membresia` | S, I, U | – | S | – |
| `finanzas.pago` | S, I | – | S, I, U | – |
| `finanzas.metodo_pago` | S | – | S | – |
| `personal.entrenador` | S (solo `id_entrenador`, `nombre_entrenador`) | – | – | – |
| esquema `clases` (tablas) | S · **DENY** I, U, D | S · **DENY** I, U, D | – | – |
| `clases.usp_reservar_clase` | E | – | – | – |
| `clases.usp_registrar_checkin` | E | E | – | – |
| esquema `reportes` (vistas) | – | – | – | S |

Ningún rol tiene acceso al esquema `auditoria`.

## 4. Justificación por esquema

| Esquema | Quién accede | Razón |
|---|---|---|
| `socios` | Recepción (escritura), entrenadores y finanzas (lectura limitada) | Contiene datos personales (DUI, correo, teléfono) |
| `finanzas` | Finanzas (escritura), recepción (cobros) | Información monetaria |
| `clases` | Recepción y entrenadores | Operación diaria; las escrituras pasan por procedimientos |
| `personal` | Casi nadie | Datos de empleados, con acceso limitado a nombres |
| `auditoria` | Solo administradores | Una bitácora que los usuarios operativos pudieran modificar perdería su valor |
| `reportes` | Power BI | Capa de lectura aislada de las tablas base |

## 5. Auditoría

| Objeto | Qué registra | Dónde queda |
|---|---|---|
| `Audit_Gimnasio` | Destino de la auditoría (archivo `.sqlaudit`, 50 MB, 5 archivos de rotación) | Carpeta de logs de la instancia |
| `SAS_Gimnasio_Accesos` (servidor) | Inicios de sesión fallidos, cambios de logins y de pertenencia a roles del servidor | `Audit_Gimnasio` |
| `DAS_Gimnasio` (base de datos) | INSERT/UPDATE/DELETE en `finanzas.pago`; UPDATE/DELETE en `socios.membresia` y `socios.socio`; cambios de esquema, roles y permisos | `Audit_Gimnasio` |
| `auditoria.log_pago` + `trg_pago_auditoria` | Valor anterior y nuevo de monto y estado en cada UPDATE o DELETE de pagos, con usuario y fecha | Tabla en la propia base |

Los logs se consultan con `sys.fn_get_audit_file`, y la bitácora de pagos con un `SELECT` a `auditoria.log_pago` (ambos en `05_auditoria.sql`).

## 6. Resultado esperado de las pruebas de permisos

La sección 8 de `04_seguridad_roles_usuarios.sql` ejecuta 15 pruebas con cada usuario. La columna `resultado` debe mostrar **OK** en todas. Por ejemplo:

| Usuario | Acción | Resultado esperado |
|---|---|---|
| `usr_recepcion` | Leer `socios.socio` | Permitido |
| `usr_recepcion` | Leer `dui` de `personal.entrenador` | Denegado |
| `usr_recepcion` | `INSERT` directo en `clases.reserva` | Denegado |
| `usr_entrenador` | Leer `dui` de `socios.socio` | Denegado |
| `usr_finanzas` | `DELETE` en `finanzas.pago` | Denegado |
| `usr_powerbi` | Leer `socios.socio` | Denegado |
