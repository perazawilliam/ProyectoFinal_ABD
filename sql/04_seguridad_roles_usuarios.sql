-- =============================================================================
-- PROYECTO FINAL — ADMINISTRACIÓN DE BASES DE DATOS
-- PROYECTO: SISTEMA DE RESERVAS DE GIMNASIO
-- ARCHIVO: 04_seguridad_roles_usuarios.sql
-- DESCRIPCIÓN: LOGINS, USUARIOS, ROLES FUNCIONALES Y PRUEBAS DE PERMISOS
-- =============================================================================

-- =============================================================================
-- 1. LOGINS | NIVEL SERVIDOR
-- =============================================================================
USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'lg_recepcion')
    CREATE LOGIN lg_recepcion WITH PASSWORD = N'Gym#Recepcion2026!', DEFAULT_DATABASE = GimnasioDB, CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'lg_entrenador')
    CREATE LOGIN lg_entrenador WITH PASSWORD = N'Gym#Entrenador2026!', DEFAULT_DATABASE = GimnasioDB, CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'lg_finanzas')
    CREATE LOGIN lg_finanzas WITH PASSWORD = N'Gym#Finanzas2026!', DEFAULT_DATABASE = GimnasioDB, CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'lg_powerbi')
    CREATE LOGIN lg_powerbi WITH PASSWORD = N'Gym#PowerBI2026!', DEFAULT_DATABASE = GimnasioDB, CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;
GO

-- =============================================================================
-- 2. USUARIOS | NIVEL BASE DE DATOS
-- =============================================================================
USE GimnasioDB;
GO

CREATE USER usr_recepcion  FOR LOGIN lg_recepcion;
CREATE USER usr_entrenador FOR LOGIN lg_entrenador;
CREATE USER usr_finanzas   FOR LOGIN lg_finanzas;
CREATE USER usr_powerbi    FOR LOGIN lg_powerbi;

-- =============================================================================
-- 3. ROLES | UNO POR FUNCIÓN DEL NEGOCIO
-- =============================================================================
CREATE ROLE rol_recepcion;
CREATE ROLE rol_entrenador;
CREATE ROLE rol_finanzas;
CREATE ROLE rol_reportes;

ALTER ROLE rol_recepcion  ADD MEMBER usr_recepcion;
ALTER ROLE rol_entrenador ADD MEMBER usr_entrenador;
ALTER ROLE rol_finanzas   ADD MEMBER usr_finanzas;
ALTER ROLE rol_reportes   ADD MEMBER usr_powerbi;

-- =============================================================================
-- 4. PERMISOS | rol_recepcion
-- DESCRIPCIÓN: ATIENDE SOCIOS, MEMBRESÍAS Y COBROS. RESERVAS Y CHECK-IN SOLO
--              MEDIANTE PROCEDIMIENTOS ALMACENADOS.
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON OBJECT::socios.socio          TO rol_recepcion;
GRANT SELECT, INSERT, UPDATE ON OBJECT::socios.membresia      TO rol_recepcion;
GRANT SELECT                 ON OBJECT::socios.plan_membresia TO rol_recepcion;
GRANT SELECT, INSERT         ON OBJECT::finanzas.pago         TO rol_recepcion;
GRANT SELECT                 ON OBJECT::finanzas.metodo_pago  TO rol_recepcion;
GRANT SELECT ON OBJECT::personal.entrenador (id_entrenador, nombre_entrenador) TO rol_recepcion;

GRANT SELECT ON SCHEMA::clases TO rol_recepcion;
DENY INSERT, UPDATE, DELETE ON SCHEMA::clases TO rol_recepcion;

GRANT EXECUTE ON OBJECT::clases.usp_reservar_clase    TO rol_recepcion;
GRANT EXECUTE ON OBJECT::clases.usp_registrar_checkin TO rol_recepcion;

-- =============================================================================
-- 5. PERMISOS | rol_entrenador
-- DESCRIPCIÓN: CONSULTA CLASES Y REGISTRA ASISTENCIA. DE SOCIOS SOLO VE ID Y NOMBRE.
-- =============================================================================
GRANT SELECT ON SCHEMA::clases TO rol_entrenador;
DENY INSERT, UPDATE, DELETE ON SCHEMA::clases TO rol_entrenador;

GRANT SELECT  ON OBJECT::socios.socio (id_socio, nombre) TO rol_entrenador;
GRANT EXECUTE ON OBJECT::clases.usp_registrar_checkin    TO rol_entrenador;

-- =============================================================================
-- 6. PERMISOS | rol_finanzas
-- DESCRIPCIÓN: REGISTRA Y CORRIGE PAGOS. NO ELIMINA NI VE DATOS PERSONALES.
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON OBJECT::finanzas.pago         TO rol_finanzas;
GRANT SELECT                 ON OBJECT::finanzas.metodo_pago  TO rol_finanzas;
GRANT SELECT                 ON OBJECT::socios.membresia      TO rol_finanzas;
GRANT SELECT                 ON OBJECT::socios.plan_membresia TO rol_finanzas;

-- =============================================================================
-- 7. PERMISOS | rol_reportes
-- DESCRIPCIÓN: SOLO LECTURA SOBRE VISTAS DEL ESQUEMA REPORTES PARA POWER BI.
-- =============================================================================
GRANT SELECT ON SCHEMA::reportes TO rol_reportes;
GO

-- =============================================================================
-- 8. PRUEBAS | SIMULACIÓN DE ACCIONES PERMITIDAS Y DENEGADAS
-- =============================================================================
DECLARE @pruebas TABLE (
    id        INT IDENTITY(1,1), 
    usuario   SYSNAME, 
    sentencia NVARCHAR(400), 
    esperado  VARCHAR(10), 
    obtenido  VARCHAR(10)
);

INSERT INTO @pruebas (usuario, sentencia, esperado) VALUES
    ('usr_recepcion',  N'SELECT @x = COUNT(*) FROM socios.socio;',                               'PERMITIDO'),
    ('usr_recepcion',  N'SELECT TOP (1) @x = dui FROM personal.entrenador;',                     'DENEGADO'),
    ('usr_recepcion',  N'INSERT INTO clases.reserva (id_clase, id_socio) VALUES (1, 1);',        'DENEGADO'),
    ('usr_recepcion',  N'DELETE FROM finanzas.pago WHERE id_pago = -1;',                         'DENEGADO'),
    ('usr_recepcion',  N'EXEC clases.usp_reservar_clase @id_clase = -1, @id_socio = -1;',        'PERMITIDO'),
    ('usr_entrenador', N'SELECT TOP (1) @x = nombre FROM socios.socio;',                         'PERMITIDO'),
    ('usr_entrenador', N'SELECT TOP (1) @x = dui FROM socios.socio;',                            'DENEGADO'),
    ('usr_entrenador', N'UPDATE clases.clase SET cupo_maximo = cupo_maximo WHERE id_clase = -1;', 'DENEGADO'),
    ('usr_entrenador', N'EXEC clases.usp_reservar_clase @id_clase = -1, @id_socio = -1;',        'DENEGADO'),
    ('usr_entrenador', N'EXEC clases.usp_registrar_checkin @id_reserva = -1;',                   'PERMITIDO'),
    ('usr_finanzas',   N'SELECT @x = COUNT(*) FROM finanzas.pago;',                              'PERMITIDO'),
    ('usr_finanzas',   N'SELECT TOP (1) @x = dui FROM socios.socio;',                            'DENEGADO'),
    ('usr_finanzas',   N'DELETE FROM finanzas.pago WHERE id_pago = -1;',                         'DENEGADO'),
    ('usr_powerbi',    N'SELECT @x = COUNT(*) FROM socios.socio;',                               'DENEGADO'),
    ('usr_powerbi',    N'SELECT @x = COUNT(*) FROM finanzas.pago;',                              'DENEGADO');

DECLARE @i INT = 1, @usuario SYSNAME, @sql NVARCHAR(500), @r VARCHAR(10);
WHILE @i <= (SELECT COUNT(*) FROM @pruebas)
BEGIN
    SELECT @usuario = usuario, @sql = N'DECLARE @x sql_variant; ' + sentencia FROM @pruebas WHERE id = @i;
    SET @r = 'PERMITIDO';

    BEGIN TRY
        EXECUTE AS USER = @usuario;
        EXEC (@sql);
        REVERT;
    END TRY
    BEGIN CATCH
        SET @r = CASE WHEN ERROR_NUMBER() IN (229, 230, 262, 297, 300) THEN 'DENEGADO'
                      WHEN ERROR_NUMBER() >= 50000 THEN 'PERMITIDO'
                      ELSE 'ERROR' END;
        REVERT;
    END CATCH

    UPDATE @pruebas SET obtenido = @r WHERE id = @i;
    SET @i += 1;
END;

SELECT id, usuario, sentencia, esperado, obtenido,
       CASE WHEN esperado = obtenido THEN 'OK' ELSE 'REVISAR' END AS resultado
FROM   @pruebas
ORDER BY id;

-- =============================================================================
-- 9. VERIFICACIÓN | ROLES, MIEMBROS Y PERMISOS EFECTIVOS
-- =============================================================================
SELECT r.name AS rol, m.name AS usuario
FROM   sys.database_role_members rm
JOIN   sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN   sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE  r.name LIKE 'rol[_]%'
ORDER BY r.name;

SELECT pr.name AS rol, p.state_desc AS estado, p.permission_name AS permiso,
       CASE p.class WHEN 1 THEN OBJECT_SCHEMA_NAME(p.major_id) + '.' + OBJECT_NAME(p.major_id)
                    WHEN 3 THEN 'SCHEMA::' + SCHEMA_NAME(p.major_id) END AS objeto,
       COL_NAME(p.major_id, p.minor_id) AS columna
FROM   sys.database_permissions p
JOIN   sys.database_principals pr ON pr.principal_id = p.grantee_principal_id
WHERE  pr.name LIKE 'rol[_]%'
ORDER BY pr.name, objeto, p.permission_name;
GO