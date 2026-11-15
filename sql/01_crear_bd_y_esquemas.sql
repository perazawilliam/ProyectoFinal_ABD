-- =============================================================================
-- PROYECTO FINAL — ADMINISTRACIÓN DE BASES DE DATOS
-- PROYECTO: SISTEMA DE RESERVAS DE GIMNASIO
-- ARCHIVO: 01_crear_bd_y_esquemas.sql
-- DESCRIPCIÓN: CREACIÓN DE BASE DE DATOS, MODELO DE RECUPERACIÓN Y ESQUEMAS
-- =============================================================================

USE master;
GO

-- 1. CREACIÓN E INICIALIZACIÓN DE LA BASE DE DATOS

-- Verificacion de existencia de la base datos
IF DB_ID(N'GimnasioDB') IS NOT NULL
BEGIN
    -- Generando una desconexion forzada
    ALTER DATABASE GimnasioDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE GimnasioDB;
END
GO

-- Creando la base de datos "GimnasioDB"
CREATE DATABASE GimnasioDB COLLATE Modern_Spanish_CI_AS;
ALTER DATABASE GimnasioDB SET RECOVERY FULL;
GO

-- 2. CREACIÓN DE ESQUEMAS FUNCIONALES
USE GimnasioDB;
GO

EXEC (N'CREATE SCHEMA socios    AUTHORIZATION dbo');
EXEC (N'CREATE SCHEMA finanzas  AUTHORIZATION dbo');
EXEC (N'CREATE SCHEMA clases    AUTHORIZATION dbo');
EXEC (N'CREATE SCHEMA personal  AUTHORIZATION dbo');
EXEC (N'CREATE SCHEMA auditoria AUTHORIZATION dbo');
EXEC (N'CREATE SCHEMA reportes  AUTHORIZATION dbo');
GO