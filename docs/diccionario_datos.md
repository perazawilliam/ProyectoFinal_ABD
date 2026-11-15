# Diccionario de Datos y Diseño de Esquemas: Sistema de Reservas de Gimnasio

Base de datos: `GimnasioDB` · Motor: SQL Server 2025 Developer

---

## 1. Diseño de esquemas

Los objetos se agrupan por **función del negocio**, de modo que cada esquema coincida con un área que tendrá su propio rol de acceso. Así los permisos se otorgan por esquema (`GRANT ... ON SCHEMA::`) y no tabla por tabla, lo que simplifica el mantenimiento y respeta el principio de mínimo privilegio.

| Esquema | Tablas | Propósito | Justificación de seguridad |
|---|---|---|---|
| `socios` | `socio`, `plan_membresia`, `membresia` | Gestión de clientes y sus membresías | Contiene datos personales (DUI, correo, teléfono). Acceso de recepción, restringido para el resto. |
| `finanzas` | `metodo_pago`, `pago` | Cobros y registro de ingresos | Información monetaria. Solo finanzas y administración escriben; los demás no tienen acceso. |
| `clases` | `sala`, `tipo_clase`, `clase`, `reserva`, `asistencia` | Operación diaria: programación, reservas y check-in | Es el esquema de mayor uso transaccional. Entrenadores y recepción operan aquí. |
| `personal` | `especialidad`, `entrenador` | Datos del equipo de entrenadores | Contiene DUI y datos de contacto del personal. Acceso mínimo. |
| `auditoria` *(paso 4)* | Tablas de bitácora y objetos de auditoría | Registro de acciones sensibles | Separado para que ningún rol operativo pueda modificarlo ni borrarlo. |
| `reportes` *(paso 8)* | Vistas para Power BI | Capa de lectura para el dashboard | El usuario de Power BI solo lee vistas y nunca toca las tablas base. |

**Dependencias entre esquemas.** `socios`, `clases` y `finanzas` se relacionan mediante claves foráneas entre esquemas. SQL Server lo permite sin problema, y los permisos de cada rol se evalúan por objeto y esquema.

---

## 2. Convención de nombres de restricciones

| Tipo | Patrón | Ejemplo |
|---|---|---|
| Clave primaria | `PK_tabla` | `PK_socio` |
| Clave foránea | `FK_tabla_referenciada` | `FK_membresia_socio` |
| Única | `UQ_tabla_columna` | `UQ_socio_dui` |
| Check | `CK_tabla_columna` | `CK_pago_monto` |
| Default | `DF_tabla_columna` | `DF_socio_fecha_registro` |

**Nota general:** las claves foráneas usan `NO ACTION` al eliminar (comportamiento por defecto). No se borran en cascada, para no perder historial de pagos, reservas ni asistencias. El estado de los registros se controla con columnas `estado_*`.

---

## 3. Diccionario de datos por tabla

### 3.1 `socios.socio`
Persona inscrita en el gimnasio.

| Columna | Tipo | Clave | Nulo | Restricciones / Default | Descripción |
|---|---|---|---|---|---|
| id_socio | int IDENTITY(1,1) | PK | No | | Identificador único del socio |
| dui | varchar(10) | | No | UNIQUE | Documento de identidad (formato 00000000-0) |
| nombre | varchar(150) | | No | | Nombre completo |
| fecha_nacimiento | date | | Sí | | Fecha de nacimiento |
| telefono | varchar(15) | | Sí | | Teléfono de contacto |
| correo | varchar(100) | | No | UNIQUE | Correo electrónico |
| fecha_registro | date | | No | DEFAULT CAST(GETDATE() AS date) | Fecha de alta en el gimnasio |
| estado_socio | varchar(20) | | No | DEFAULT 'Activo'; CHECK IN ('Activo','Inactivo','Suspendido') | Situación actual del socio |

### 3.2 `socios.plan_membresia`
Catálogo de planes que ofrece el gimnasio.

| Columna | Tipo | Clave | Nulo | Restricciones / Default | Descripción |
|---|---|---|---|---|---|
| id_plan | int IDENTITY(1,1) | PK | No | | Identificador del plan |
| nombre_plan | varchar(80) | | No | UNIQUE | Nombre comercial (Mensual, Trimestral, Anual...) |
| duracion_dias | int | | No | CHECK > 0 | Vigencia del plan en días |
| precio | numeric(8,2) | | No | CHECK >= 0 | Precio del plan |
| max_reservas_semana | int | | Sí | | Límite de reservas por semana; NULL = ilimitadas |

### 3.3 `socios.membresia`
Compra de un plan por un socio. Conserva el historial de renovaciones.

| Columna | Tipo | Clave | Nulo | Restricciones / Default | Descripción |
|---|---|---|---|---|---|
| id_membresia | int IDENTITY(1,1) | PK | No | | Identificador de la membresía |
| id_socio | int | FK → socios.socio | No | | Socio que la adquiere |
| id_plan | int | FK → socios.plan_membresia | No | | Plan contratado |
| fecha_inicio | date | | No | | Inicio de vigencia |
| fecha_fin | date | | No | CHECK fecha_fin > fecha_inicio | Fin de vigencia |
| estado_membresia | varchar(20) | | No | DEFAULT 'Vigente'; CHECK IN ('Vigente','Vencida','Cancelada') | Estado de la membresía |

### 3.4 `finanzas.metodo_pago`
Catálogo de formas de pago.

| Columna | Tipo | Clave | Nulo | Restricciones / Default | Descripción |
|---|---|---|---|---|---|
| id_metodo_pago | int IDENTITY(1,1) | PK | No | | Identificador del método |
| nombre_metodo | varchar(50) | | No | UNIQUE | Efectivo, Tarjeta, Transferencia... |

### 3.5 `finanzas.pago`
Pagos realizados por una membresía.

| Columna | Tipo | Clave | Nulo | Restricciones / Default | Descripción |
|---|---|---|---|---|---|
| id_pago | int IDENTITY(1,1) | PK | No | | Identificador del pago |
| id_membresia | int | FK → socios.membresia | No | | Membresía que se paga |
| id_metodo_pago | int | FK → finanzas.metodo_pago | No | | Forma de pago utilizada |
| monto | numeric(8,2) | | No | CHECK > 0 | Monto pagado |
| fecha_pago | datetime2 | | No | DEFAULT SYSDATETIME() | Fecha y hora del pago |
| estado_pago | varchar(20) | | No | DEFAULT 'Completado'; CHECK IN ('Completado','Pendiente','Anulado') | Estado del pago |

### 3.6 `personal.especialidad`
Catálogo de especialidades de los entrenadores.

| Columna | Tipo | Clave | Nulo | Restricciones / Default | Descripción |
|---|---|---|---|---|---|
| id_especialidad | int IDENTITY(1,1) | PK | No | | Identificador de la especialidad |
| nombre_especialidad | varchar(100) | | No | UNIQUE | Yoga, Crossfit, Spinning... |

### 3.7 `personal.entrenador`
Entrenadores que imparten clases.

| Columna | Tipo | Clave | Nulo | Restricciones / Default | Descripción |
|---|---|---|---|---|---|
| id_entrenador | int IDENTITY(1,1) | PK | No | | Identificador del entrenador |
| id_especialidad | int | FK → personal.especialidad | No | | Especialidad principal |
| dui | varchar(10) | | No | UNIQUE | Documento de identidad |
| nombre_entrenador | varchar(150) | | No | | Nombre completo |
| telefono | varchar(15) | | Sí | | Teléfono de contacto |
| correo | varchar(100) | | No | UNIQUE | Correo electrónico |
| fecha_contratacion | date | | No | DEFAULT CAST(GETDATE() AS date) | Fecha de ingreso |
| estado_entrenador | varchar(20) | | No | DEFAULT 'Activo'; CHECK IN ('Activo','Inactivo') | Situación laboral |

### 3.8 `clases.sala`
Espacios físicos del gimnasio.

| Columna | Tipo | Clave | Nulo | Restricciones / Default | Descripción |
|---|---|---|---|---|---|
| id_sala | int IDENTITY(1,1) | PK | No | | Identificador de la sala |
| nombre_sala | varchar(50) | | No | UNIQUE | Nombre de la sala |
| capacidad | int | | No | CHECK > 0 | Aforo máximo de la sala |

### 3.9 `clases.tipo_clase`
Catálogo de clases que se ofrecen.

| Columna | Tipo | Clave | Nulo | Restricciones / Default | Descripción |
|---|---|---|---|---|---|
| id_tipo_clase | int IDENTITY(1,1) | PK | No | | Identificador del tipo de clase |
| nombre_clase | varchar(100) | | No | UNIQUE | Nombre de la clase |
| descripcion | varchar(250) | | Sí | | Descripción breve |
| nivel | varchar(20) | | No | CHECK IN ('Principiante','Intermedio','Avanzado') | Nivel de dificultad |
| duracion_min | int | | No | CHECK > 0 | Duración en minutos |

### 3.10 `clases.clase`
Sesión programada de una clase.

| Columna | Tipo | Clave | Nulo | Restricciones / Default | Descripción |
|---|---|---|---|---|---|
| id_clase | int IDENTITY(1,1) | PK | No | | Identificador de la sesión |
| id_tipo_clase | int | FK → clases.tipo_clase | No | | Tipo de clase impartida |
| id_entrenador | int | FK → personal.entrenador | No | | Entrenador a cargo |
| id_sala | int | FK → clases.sala | No | | Sala donde se imparte |
| fecha_hora_inicio | datetime2 | | No | | Inicio de la sesión |
| fecha_hora_fin | datetime2 | | No | CHECK fecha_hora_fin > fecha_hora_inicio | Fin de la sesión |
| cupo_maximo | int | | No | CHECK > 0 | Cupos disponibles para reservar |
| estado_clase | varchar(20) | | No | DEFAULT 'Programada'; CHECK IN ('Programada','Realizada','Cancelada') | Estado de la sesión |

### 3.11 `clases.reserva`
Apartado de un cupo por un socio.

| Columna | Tipo | Clave | Nulo | Restricciones / Default | Descripción |
|---|---|---|---|---|---|
| id_reserva | int IDENTITY(1,1) | PK | No | | Identificador de la reserva |
| id_clase | int | FK → clases.clase | No | UNIQUE (id_clase, id_socio) | Clase reservada |
| id_socio | int | FK → socios.socio | No | UNIQUE (id_clase, id_socio) | Socio que reserva |
| fecha_reserva | datetime2 | | No | DEFAULT SYSDATETIME() | Momento de la reserva |
| estado_reserva | varchar(20) | | No | DEFAULT 'Confirmada'; CHECK IN ('Confirmada','Cancelada','Asistida','No asistio') | Estado de la reserva |

### 3.12 `clases.asistencia`
Check-in real de una reserva (relación 1 a 1).

| Columna | Tipo | Clave | Nulo | Restricciones / Default | Descripción |
|---|---|---|---|---|---|
| id_asistencia | int IDENTITY(1,1) | PK | No | | Identificador de la asistencia |
| id_reserva | int | FK → clases.reserva | No | UNIQUE | Reserva a la que corresponde |
| fecha_checkin | datetime2 | | No | DEFAULT SYSDATETIME() | Momento del ingreso a la clase |

---

## 4. Reglas de negocio no cubiertas por restricciones declarativas

Estas reglas no se pueden expresar con un `CHECK` simple porque dependen de otras filas o tablas. Se implementarán con procedimientos almacenados o triggers y se documentarán en el script correspondiente.

| Regla | Mecanismo previsto |
|---|---|
| El número de reservas confirmadas de una clase no puede superar `cupo_maximo` | Trigger o procedimiento de reserva |
| El cupo de una clase no puede superar la `capacidad` de su sala | Trigger sobre `clases.clase` |
| Un socio solo puede reservar si tiene una membresía `Vigente` | Procedimiento de reserva |
| El socio no puede exceder `max_reservas_semana` de su plan | Procedimiento de reserva |
| Una sala o entrenador no puede tener dos clases que se traslapen en horario | Trigger sobre `clases.clase` |
| Una asistencia solo puede registrarse para reservas `Confirmada` | Procedimiento de check-in |

---

## 5. Resumen del modelo

| Concepto | Valor |
|---|---|
| Tablas | 12 |
| Esquemas con tablas | 4 (`socios`, `finanzas`, `clases`, `personal`) |
| Esquemas adicionales previstos | 2 (`auditoria`, `reportes`) |
| Relaciones 1 a N | 10 |
| Relaciones 1 a 1 | 1 (`asistencia` ↔ `reserva`) |
