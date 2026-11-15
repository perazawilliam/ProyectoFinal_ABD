-- =============================================================================
-- PROYECTO FINAL — ADMINISTRACIÓN DE BASES DE DATOS
-- PROYECTO: SISTEMA DE RESERVAS DE GIMNASIO
-- ARCHIVO: 02_crear_tablas.sql
-- DESCRIPCIÓN: CREACIÓN DE TABLAS, INTEGRIDAD REFERENCIAL Y LÓGICA TRANSACCIONAL
-- =============================================================================

USE GimnasioDB;
GO

-- TABLA: personal.especialidad
CREATE TABLE personal.especialidad (
    id_especialidad     INT IDENTITY(1,1) NOT NULL,
    nombre_especialidad VARCHAR(100)      NOT NULL,
    CONSTRAINT PK_especialidad        PRIMARY KEY (id_especialidad),
    CONSTRAINT UQ_especialidad_nombre UNIQUE (nombre_especialidad)
);

-- TABLA: personal.entrenador
CREATE TABLE personal.entrenador (
    id_entrenador      INT IDENTITY(1,1) NOT NULL,
    id_especialidad    INT               NOT NULL,
    dui                VARCHAR(10)       NOT NULL,
    nombre_entrenador  VARCHAR(150)      NOT NULL,
    telefono           VARCHAR(15)       NULL,
    correo             VARCHAR(100)      NOT NULL,
    fecha_contratacion DATE              NOT NULL CONSTRAINT DF_entrenador_fecha_contratacion DEFAULT (CAST(GETDATE() AS DATE)),
    estado_entrenador  VARCHAR(20)       NOT NULL CONSTRAINT DF_entrenador_estado DEFAULT ('Activo'),
    CONSTRAINT PK_entrenador              PRIMARY KEY (id_entrenador),
    CONSTRAINT UQ_entrenador_dui          UNIQUE (dui),
    CONSTRAINT UQ_entrenador_correo       UNIQUE (correo),
    CONSTRAINT FK_entrenador_especialidad FOREIGN KEY (id_especialidad) REFERENCES personal.especialidad (id_especialidad),
    CONSTRAINT CK_entrenador_estado       CHECK (estado_entrenador IN ('Activo', 'Inactivo'))
);

-- TABLA: socios.socio
CREATE TABLE socios.socio (
    id_socio         INT IDENTITY(1,1) NOT NULL,
    dui              VARCHAR(10)       NOT NULL,
    nombre           VARCHAR(150)      NOT NULL,
    fecha_nacimiento DATE              NULL,
    telefono         VARCHAR(15)       NULL,
    correo           VARCHAR(100)      NOT NULL,
    fecha_registro   DATE              NOT NULL CONSTRAINT DF_socio_fecha_registro DEFAULT (CAST(GETDATE() AS DATE)),
    estado_socio     VARCHAR(20)       NOT NULL CONSTRAINT DF_socio_estado DEFAULT ('Activo'),
    CONSTRAINT PK_socio        PRIMARY KEY (id_socio),
    CONSTRAINT UQ_socio_dui    UNIQUE (dui),
    CONSTRAINT UQ_socio_correo UNIQUE (correo),
    CONSTRAINT CK_socio_estado CHECK (estado_socio IN ('Activo', 'Inactivo', 'Suspendido'))
);

-- TABLA: socios.plan_membresia
CREATE TABLE socios.plan_membresia (
    id_plan             INT IDENTITY(1,1) NOT NULL,
    nombre_plan         VARCHAR(80)       NOT NULL,
    duracion_dias       INT               NOT NULL,
    precio              NUMERIC(8,2)      NOT NULL,
    max_reservas_semana INT               NULL,
    CONSTRAINT PK_plan_membresia          PRIMARY KEY (id_plan),
    CONSTRAINT UQ_plan_membresia_nombre   UNIQUE (nombre_plan),
    CONSTRAINT CK_plan_membresia_duracion CHECK (duracion_dias > 0),
    CONSTRAINT CK_plan_membresia_precio   CHECK (precio >= 0)
);

-- TABLA: socios.membresia
CREATE TABLE socios.membresia (
    id_membresia     INT IDENTITY(1,1) NOT NULL,
    id_socio         INT               NOT NULL,
    id_plan          INT               NOT NULL,
    fecha_inicio     DATE              NOT NULL,
    fecha_fin        DATE              NOT NULL,
    estado_membresia VARCHAR(20)       NOT NULL CONSTRAINT DF_membresia_estado DEFAULT ('Vigente'),
    CONSTRAINT PK_membresia        PRIMARY KEY (id_membresia),
    CONSTRAINT FK_membresia_socio  FOREIGN KEY (id_socio) REFERENCES socios.socio (id_socio),
    CONSTRAINT FK_membresia_plan   FOREIGN KEY (id_plan)  REFERENCES socios.plan_membresia (id_plan),
    CONSTRAINT CK_membresia_fechas CHECK (fecha_fin > fecha_inicio),
    CONSTRAINT CK_membresia_estado CHECK (estado_membresia IN ('Vigente', 'Vencida', 'Cancelada'))
);

-- TABLA: finanzas.metodo_pago
CREATE TABLE finanzas.metodo_pago (
    id_metodo_pago INT IDENTITY(1,1) NOT NULL,
    nombre_metodo  VARCHAR(50)       NOT NULL,
    CONSTRAINT PK_metodo_pago        PRIMARY KEY (id_metodo_pago),
    CONSTRAINT UQ_metodo_pago_nombre UNIQUE (nombre_metodo)
);

-- TABLA: finanzas.pago
CREATE TABLE finanzas.pago (
    id_pago        INT IDENTITY(1,1) NOT NULL,
    id_membresia   INT               NOT NULL,
    id_metodo_pago INT               NOT NULL,
    monto          NUMERIC(8,2)      NOT NULL,
    fecha_pago     DATETIME2         NOT NULL CONSTRAINT DF_pago_fecha DEFAULT (SYSDATETIME()),
    estado_pago    VARCHAR(20)       NOT NULL CONSTRAINT DF_pago_estado DEFAULT ('Completado'),
    CONSTRAINT PK_pago             PRIMARY KEY (id_pago),
    CONSTRAINT FK_pago_membresia   FOREIGN KEY (id_membresia)   REFERENCES socios.membresia (id_membresia),
    CONSTRAINT FK_pago_metodo_pago FOREIGN KEY (id_metodo_pago) REFERENCES finanzas.metodo_pago (id_metodo_pago),
    CONSTRAINT CK_pago_monto       CHECK (monto > 0),
    CONSTRAINT CK_pago_estado      CHECK (estado_pago IN ('Completado', 'Pendiente', 'Anulado'))
);

-- TABLA: clases.sala
CREATE TABLE clases.sala (
    id_sala     INT IDENTITY(1,1) NOT NULL,
    nombre_sala VARCHAR(50)       NOT NULL,
    capacidad   INT               NOT NULL,
    CONSTRAINT PK_sala           PRIMARY KEY (id_sala),
    CONSTRAINT UQ_sala_nombre    UNIQUE (nombre_sala),
    CONSTRAINT CK_sala_capacidad CHECK (capacidad > 0)
);

-- TABLA: clases.tipo_clase
CREATE TABLE clases.tipo_clase (
    id_tipo_clase INT IDENTITY(1,1) NOT NULL,
    nombre_clase  VARCHAR(100)      NOT NULL,
    descripcion   VARCHAR(250)      NULL,
    nivel         VARCHAR(20)       NOT NULL,
    duracion_min  INT               NOT NULL,
    CONSTRAINT PK_tipo_clase          PRIMARY KEY (id_tipo_clase),
    CONSTRAINT UQ_tipo_clase_nombre   UNIQUE (nombre_clase),
    CONSTRAINT CK_tipo_clase_nivel    CHECK (nivel IN ('Principiante', 'Intermedio', 'Avanzado')),
    CONSTRAINT CK_tipo_clase_duracion CHECK (duracion_min > 0)
);

-- TABLA: clases.clase
CREATE TABLE clases.clase (
    id_clase          INT IDENTITY(1,1) NOT NULL,
    id_tipo_clase     INT               NOT NULL,
    id_entrenador     INT               NOT NULL,
    id_sala           INT               NOT NULL,
    fecha_hora_inicio DATETIME2         NOT NULL,
    fecha_hora_fin    DATETIME2         NOT NULL,
    cupo_maximo       INT               NOT NULL,
    estado_clase      VARCHAR(20)       NOT NULL CONSTRAINT DF_clase_estado DEFAULT ('Programada'),
    CONSTRAINT PK_clase            PRIMARY KEY (id_clase),
    CONSTRAINT FK_clase_tipo_clase FOREIGN KEY (id_tipo_clase) REFERENCES clases.tipo_clase (id_tipo_clase),
    CONSTRAINT FK_clase_entrenador FOREIGN KEY (id_entrenador) REFERENCES personal.entrenador (id_entrenador),
    CONSTRAINT FK_clase_sala       FOREIGN KEY (id_sala)       REFERENCES clases.sala (id_sala),
    CONSTRAINT CK_clase_horario    CHECK (fecha_hora_fin > fecha_hora_inicio),
    CONSTRAINT CK_clase_cupo       CHECK (cupo_maximo > 0),
    CONSTRAINT CK_clase_estado     CHECK (estado_clase IN ('Programada', 'Realizada', 'Cancelada'))
);

-- TABLA: clases.reserva
CREATE TABLE clases.reserva (
    id_reserva     INT IDENTITY(1,1) NOT NULL,
    id_clase       INT               NOT NULL,
    id_socio       INT               NOT NULL,
    fecha_reserva  DATETIME2         NOT NULL CONSTRAINT DF_reserva_fecha DEFAULT (SYSDATETIME()),
    estado_reserva VARCHAR(20)       NOT NULL CONSTRAINT DF_reserva_estado DEFAULT ('Confirmada'),
    CONSTRAINT PK_reserva             PRIMARY KEY (id_reserva),
    CONSTRAINT FK_reserva_clase       FOREIGN KEY (id_clase) REFERENCES clases.clase (id_clase),
    CONSTRAINT FK_reserva_socio       FOREIGN KEY (id_socio) REFERENCES socios.socio (id_socio),
    CONSTRAINT UQ_reserva_clase_socio UNIQUE (id_clase, id_socio),
    CONSTRAINT CK_reserva_estado      CHECK (estado_reserva IN ('Confirmada', 'Cancelada', 'Asistida', 'No asistio'))
);

-- TABLA: clases.asistencia
CREATE TABLE clases.asistencia (
    id_asistencia INT IDENTITY(1,1) NOT NULL,
    id_reserva    INT               NOT NULL,
    fecha_checkin DATETIME2         NOT NULL CONSTRAINT DF_asistencia_checkin DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_asistencia         PRIMARY KEY (id_asistencia),
    CONSTRAINT UQ_asistencia_reserva UNIQUE (id_reserva),
    CONSTRAINT FK_asistencia_reserva FOREIGN KEY (id_reserva) REFERENCES clases.reserva (id_reserva)
);
GO

-- =============================================================================
-- TRIGGER: clases.trg_clase_validar
-- DESCRIPCIÓN: IMPIDE QUE EL CUPO SUPERE LA CAPACIDAD DE LA SALA Y EVITA
--              TRASLAPES HORARIOS POR SALA O ENTRENADOR.
-- =============================================================================
CREATE OR ALTER TRIGGER clases.trg_clase_validar
ON clases.clase
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1 
        FROM   inserted i
        JOIN   clases.sala s ON s.id_sala = i.id_sala
        WHERE  i.cupo_maximo > s.capacidad
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50001, N'El cupo de la clase no puede superar la capacidad de la sala.', 1;
    END

    IF EXISTS (
        SELECT 1 
        FROM   inserted i
        JOIN   clases.clase c
               ON  c.id_clase <> i.id_clase
               AND c.estado_clase <> 'Cancelada'
               AND (c.id_sala = i.id_sala OR c.id_entrenador = i.id_entrenador)
               AND c.fecha_hora_inicio < i.fecha_hora_fin
               AND c.fecha_hora_fin    > i.fecha_hora_inicio
        WHERE  i.estado_clase <> 'Cancelada'
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50002, N'La sala o el entrenador ya tienen una clase en ese horario.', 1;
    END
END;
GO

-- =============================================================================
-- PROCEDIMIENTO: clases.usp_reservar_clase
-- DESCRIPCIÓN: VALIDA REGLAS DE NEGOCIO, CUPO Y LÍMITES SEMANALES PARA RESERVAR
-- =============================================================================
CREATE OR ALTER PROCEDURE clases.usp_reservar_clase
    @id_clase INT,
    @id_socio INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @inicio        DATETIME2, 
            @estado_clase  VARCHAR(20), 
            @cupo          INT, 
            @fecha_clase   DATE,
            @id_plan       INT, 
            @max_semana    INT, 
            @inicio_semana DATE,
            @activas       INT, 
            @en_semana     INT, 
            @id_reserva    INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @inicio = fecha_hora_inicio, @estado_clase = estado_clase, @cupo = cupo_maximo
        FROM   clases.clase WITH (UPDLOCK, HOLDLOCK)
        WHERE  id_clase = @id_clase;

        IF @estado_clase IS NULL
            THROW 50010, N'La clase no existe.', 1;
        IF @estado_clase <> 'Programada'
            THROW 50011, N'La clase no está programada.', 1;
        IF NOT EXISTS (SELECT 1 FROM socios.socio WHERE id_socio = @id_socio AND estado_socio = 'Activo')
            THROW 50012, N'El socio no existe o no está activo.', 1;

        SET @fecha_clase = CAST(@inicio AS DATE);

        SELECT TOP (1) @id_plan = m.id_plan
        FROM   socios.membresia m
        WHERE  m.id_socio = @id_socio
          AND  m.estado_membresia = 'Vigente'
          AND  @fecha_clase BETWEEN m.fecha_inicio AND m.fecha_fin;

        IF @id_plan IS NULL
            THROW 50013, N'El socio no tiene una membresía vigente para la fecha de la clase.', 1;
        IF EXISTS (SELECT 1 FROM clases.reserva WHERE id_clase = @id_clase AND id_socio = @id_socio)
            THROW 50014, N'El socio ya tiene una reserva para esta clase.', 1;

        SELECT @activas = COUNT(*)
        FROM   clases.reserva
        WHERE  id_clase = @id_clase 
          AND  estado_reserva IN ('Confirmada', 'Asistida', 'No asistio');

        IF @activas >= @cupo
            THROW 50015, N'La clase no tiene cupos disponibles.', 1;

        SELECT @max_semana = max_reservas_semana FROM socios.plan_membresia WHERE id_plan = @id_plan;

        IF @max_semana IS NOT NULL
        BEGIN
            -- 01/01/1900 fue lunes: el residuo de días entre 7 calcula el desfase al lunes
            SET @inicio_semana = DATEADD(DAY, -(DATEDIFF(DAY, '19000101', @fecha_clase) % 7), @fecha_clase);

            SELECT @en_semana = COUNT(*)
            FROM   clases.reserva r
            JOIN   clases.clase c ON c.id_clase = r.id_clase
            WHERE  r.id_socio = @id_socio
              AND  r.estado_reserva IN ('Confirmada', 'Asistida', 'No asistio')
              AND  c.fecha_hora_inicio >= @inicio_semana
              AND  c.fecha_hora_inicio <  DATEADD(DAY, 7, @inicio_semana);

            IF @en_semana >= @max_semana
                THROW 50016, N'El socio alcanzó el máximo de reservas semanales de su plan.', 1;
        END

        INSERT INTO clases.reserva (id_clase, id_socio) VALUES (@id_clase, @id_socio);
        SET @id_reserva = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
        SELECT @id_reserva AS id_reserva, N'Reserva confirmada' AS mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- =============================================================================
-- PROCEDIMIENTO: clases.usp_registrar_checkin
-- DESCRIPCIÓN: REGISTRA ASISTENCIA DE RESERVA CONFIRMADA Y ACTUALIZA ESTADO
-- =============================================================================
CREATE OR ALTER PROCEDURE clases.usp_registrar_checkin
    @id_reserva INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @estado VARCHAR(20);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @estado = estado_reserva
        FROM   clases.reserva WITH (UPDLOCK, HOLDLOCK)
        WHERE  id_reserva = @id_reserva;

        IF @estado IS NULL
            THROW 50020, N'La reserva no existe.', 1;
        IF @estado <> 'Confirmada'
            THROW 50021, N'Solo se puede registrar asistencia de reservas confirmadas.', 1;

        INSERT INTO clases.asistencia (id_reserva) VALUES (@id_reserva);
        UPDATE clases.reserva SET estado_reserva = 'Asistida' WHERE id_reserva = @id_reserva;

        COMMIT TRANSACTION;
        SELECT @id_reserva AS id_reserva, N'Asistencia registrada' AS mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO