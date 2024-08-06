DROP PROCEDURE IF EXISTS proyecto1.PR1;
DROP PROCEDURE IF EXISTS proyecto1.PR2;
 DROP PROCEDURE IF EXISTS proyecto1.PR3;
 DROP PROCEDURE IF EXISTS proyecto1.PR4;
DROP PROCEDURE IF EXISTS proyecto1.PR5;
DROP PROCEDURE IF EXISTS proyecto1.PR6;
 DROP FUNCTION IF EXISTS proyecto1.F1;
 DROP FUNCTION IF EXISTS proyecto1.F2;
 DROP FUNCTION IF EXISTS proyecto1.F3;
 DROP FUNCTION IF EXISTS proyecto1.F4;
DROP FUNCTION IF EXISTS proyecto1.F5;
DROP TRIGGER IF EXISTS proyecto1.TriggerUsuarios;
DROP TRIGGER IF EXISTS proyecto1.TriggerUsuarioRole;
DROP TRIGGER IF EXISTS proyecto1.TriggerTutorProfile;
DROP TRIGGER IF EXISTS proyecto1.TriggerTFA;
DROP TRIGGER IF EXISTS proyecto1.TriggerProfileStudent;
DROP TRIGGER IF EXISTS proyecto1.TriggerCourseTutor;
DROP TRIGGER IF EXISTS proyecto1.TriggerCourseAssignment;
DROP TRIGGER IF EXISTS proyecto1.TriggerCourse;
DROP TRIGGER IF EXISTS proyecto1.TriggerRol ;
DROP TRIGGER IF EXISTS proyecto1.TriggerNotification;
-- >>>>>>>>>>>>>>>> PROCEDIMIENTOS <<<<<<<<<<<<<<<<
-- PROCEDIMIENTO PR1 (Registro de Usuarios)
create procedure proyecto1.PR1
    @Firstname nvarchar(max),
    @Lastname nvarchar(max),
    @Email nvarchar(max),
    @DateOfBirth datetime2 (7),
    @Password nvarchar(max),
    @Credits int
as
begin
    set nocount on;
    DECLARE @UserId uniqueidentifier;
    DECLARE @RolId uniqueidentifier;
    DECLARE @ErrorMessage NVARCHAR(250);
    DECLARE @ErrorSeverity INT;

    -- Validaciones de cada campo
    -- Firtsname Vacio
    IF (@Firstname IS NULL OR @Firstname = '')
    BEGIN
        SET @ErrorMessage = 'Error, El nombre no puede ir vacio';
        SET @ErrorSeverity = 16;
        RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
        RETURN;
    END

    -- Apellido Vacio
    IF (@Lastname IS NULL OR @Lastname = '')
    BEGIN
        SET @ErrorMessage = 'Error, El apellido no puede ir vacio';
        SET @ErrorSeverity = 16;
        RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
        RETURN;
    END

    -- Email Vacio
    IF (@Email IS NULL OR @Email = '')
    BEGIN
        SET @ErrorMessage = 'Error, El campo correo no puede ir vacio';
        SET @ErrorSeverity = 16;
        RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
        RETURN;
    END

    -- Fecha de Nacimiento Vacio
    IF (@DateOfBirth IS NULL)
    BEGIN
        SET @ErrorMessage = 'Error, La fecha de nacimiento no puede ir vacia';
        SET @ErrorSeverity = 16;
        RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
        RETURN;
    END

    -- Contraseña Vacía
    IF (@Password IS NULL OR @Password = '')
    BEGIN
        SET @ErrorMessage = 'Error, El password no puede estar vacía';
        SET @ErrorSeverity = 16;
        RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
        RETURN;
    END

    -- Creditos negativos
    IF (@Credits < 0)
    BEGIN
        SET @ErrorMessage = 'Error, No puede ingresar una cantidad de creditos negativa';
        SET @ErrorSeverity = 16;
        RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
        RETURN;
    END

    -- Validación de datos
     BEGIN TRY
    	
        BEGIN TRANSACTION;

    	-- Validar datos con el PR6
        DECLARE @IsValid BIT;
        EXEC proyecto1.PR6 'Usuarios', @Firstname, @Lastname, NULL, NULL, @IsValid OUTPUT;
        IF(@IsValid = 0)
        BEGIN
            SET @ErrorMessage = 'Los campos son incorrectos, tienen caracteres invalidos';
            SET @ErrorSeverity = 16;
            RAISERROR(@ErrorMessage,@ErrorSeverity,1);
            RETURN;
        END

        -- Validar email
        IF EXISTS (SELECT * FROM proyecto1.Usuarios WHERE Email = @Email)
        BEGIN
            SET @ErrorMessage = 'Este email ya se encuentra registrado en otra cuenta';
            SET @ErrorSeverity = 16;
            RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
            RETURN;
        END

        -- Asignacion rol de estudiante
        SET @RolId = (SELECT Id FROM proyecto1.Roles WHERE RoleName = 'Student');
        IF @RolId IS NULL
        BEGIN
            SET @ErrorMessage = 'El rol Student no existe';
            SET @ErrorSeverity = 16;
            RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
            RETURN;
        END

        -- Insert tabla Usuarios
        SET @UserId = NEWID();
        INSERT INTO proyecto1.Usuarios(Id, Firstname, Lastname, Email, DateOfBirth, Password, LastChanges, EmailConfirmed)
        VALUES (@UserId, @Firstname, @Lastname, @Email, @DateOfBirth, @Password, GETDATE(), 1);

        -- Insert tabla UsuarioRole
        INSERT INTO proyecto1.UsuarioRole (RoleId, UserId, IsLatestVersion)
        VALUES (@RolId, @UserId, 1);

        -- Insert tabla ProfileStudent
        INSERT INTO proyecto1.ProfileStudent (UserId, Credits)
        VALUES (@UserId, @Credits);

        -- Insert tabla TFA
        INSERT INTO proyecto1.TFA (UserId, Status, LastUpdate)
        VALUES (@UserId, 1, GETDATE());

        -- Insert tabla Notification
        INSERT INTO proyecto1.Notification (UserId, Message, Date)
        VALUES (@UserId, 'Se ha registrado correctamente', GETDATE());
		PRINT 'El estudiante se ha registrado correctamente';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
          -- Error - transacción cancelada
        ROLLBACK;
        SELECT @ErrorMessage = ERROR_MESSAGE();
		-- Registro del error en la tabla HistoryLog
        INSERT INTO proyecto1.HistoryLog (Date, Description)
        VALUES (GETDATE(), 'Error Registro Usuario - ' + @ErrorMessage);
       	PRINT 'Registro no pudo realizarse'
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

-- PROCEDIMIENTO PR2 (Cambio de Roles)
CREATE PROCEDURE proyecto1.PR2 
    @Email NVARCHAR(256), 
    @CodCourse INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    DECLARE @UserId UNIQUEIDENTIFIER;
    DECLARE @RoleId UNIQUEIDENTIFIER;
    DECLARE @TutorCode NVARCHAR(50);  -- Ajusta el tamaño del tipo de datos según corresponda

    -- Obtener el ID del usuario y verificar que el email esté confirmado
    SELECT @UserId = Id
    FROM proyecto1.Usuarios
    WHERE Email = @Email AND EmailConfirmed = 1;

    IF @UserId IS NULL
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR ('El usuario no existe o no tiene una cuenta activa.', 16, 1);
        RETURN;
    END

    -- Obtener el RoleId para el rol de Tutor
    SELECT @RoleId = Id 
    FROM proyecto1.Roles 
    WHERE RoleName = 'Tutor';

    -- Asegurar que RoleId no es NULL
    IF @RoleId IS NULL
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR ('El rol de Tutor no existe.', 16, 1);
        RETURN;
    END

    -- Generar un código único para el tutor
    SET @TutorCode = NEWID();

    -- Añadir el rol de tutor al usuario
    INSERT INTO proyecto1.UsuarioRole (UserId, RoleId, IsLatestVersion)
    VALUES (@UserId, @RoleId, 1);  -- Aseguramos que IsLatestVersion tenga un valor predeterminado

    -- Crear el perfil de tutor
    INSERT INTO proyecto1.TutorProfile (UserId, TutorCode)
    VALUES (@UserId, @TutorCode);  -- Aseguramos que TutorCode no sea nulo

    -- Asignar el curso al tutor
    INSERT INTO proyecto1.CourseTutor (CourseCodCourse, TutorId)
    VALUES (@CodCourse, @UserId);

    -- Notificar al usuario
    INSERT INTO proyecto1.Notification (UserId, Message, Date)
    VALUES (@UserId, 'Has sido promovido al rol de tutor.', GETDATE());

    COMMIT TRANSACTION;
END;
GO

-- PROCEDIMIENTO PR3 (Asignación de Curso)
CREATE PROCEDURE proyecto1.PR3 
    @Email NVARCHAR(256), 
    @CodCourse INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserId UNIQUEIDENTIFIER;
    DECLARE @TutorId UNIQUEIDENTIFIER;
    DECLARE @ProfileId INT;
    DECLARE @Credits INT;
    DECLARE @CreditsRequired INT;

    BEGIN TRANSACTION;

    -- Obtener el ID del usuario 
    SELECT @UserId = Id
    FROM proyecto1.Usuarios
    WHERE Email = @Email;

    -- Obtener el ProfileId del usuario
    SELECT @ProfileId = Id
    FROM proyecto1.ProfileStudent
    WHERE UserId = @UserId;

    -- Obtener los créditos actuales
    SELECT @Credits = Credits
    FROM proyecto1.ProfileStudent
    WHERE Id = @ProfileId;

    -- Obtener los créditos requeridos del curso
    SELECT @CreditsRequired = CreditsRequired
    FROM proyecto1.Course
    WHERE CodCourse = @CodCourse;

    -- Verificar si el usuario tiene suficientes créditos para el curso
    IF @Credits >= @CreditsRequired
    BEGIN
        -- Insertar en la tabla CourseAssignment
        INSERT INTO BD2.proyecto1.CourseAssignment (StudentId, CourseCodCourse)
        VALUES (@UserId, @CodCourse);

        -- Notificar al estudiante
        INSERT INTO BD2.proyecto1.Notification (UserId, Message, Date)
        VALUES (@UserId, 'Has sido asignado al curso', GETDATE());

        -- Obtener el TutorId para el curso
        SELECT @TutorId = TutorId 
        FROM BD2.proyecto1.CourseTutor 
        WHERE CourseCodCourse = @CodCourse;

        -- Notificar al tutor
        INSERT INTO BD2.proyecto1.Notification (UserId, Message, Date)
        VALUES (@TutorId, 'Un nuevo alumno ha sido asignado a tu curso', GETDATE());
    END
    ELSE
    BEGIN
        -- Notificar al estudiante que no tiene suficientes créditos
        INSERT INTO BD2.proyecto1.Notification (UserId, Message, Date)
        VALUES (@UserId, 'No cuentas con creditos suficientes para asignarte este curso', GETDATE());
    END

    COMMIT TRANSACTION;
END;
GO

-- PROCEDIMIENTO PR4 (Creacion de Roles)
CREATE PROCEDURE proyecto1.PR4
(
    @RoleName NVARCHAR(MAX)
)
AS
BEGIN
	DECLARE @ErrorMessage NVARCHAR(250);
    DECLARE @ErrorSeverity INT; 
    -- Iniciar la transacción
    BEGIN TRANSACTION

    BEGIN TRY
        DECLARE @RoleId UNIQUEIDENTIFIER

        -- Asignar el RoleId basado en el RoleName
        IF @RoleName = 'Student' OR @RoleName = 'Tutor'
            SET @RoleId = NEWID()
        ELSE
        BEGIN
            -- Generar un error si el rol no es "Student" o "Tutor"
			SET @ErrorMessage = 'Solo se pueden insertar los roles "Student" y "Tutor".';
			SET @ErrorSeverity = 16;
			RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
            -- Revertir la transacción
            ROLLBACK TRANSACTION
            RETURN
        END

        -- Verificar que el rol con el RoleId específico no exista ya en la tabla Roles
        IF NOT EXISTS ( SELECT 1 FROM Roles WHERE RoleName = @RoleName )
        BEGIN
            -- Insertar el nuevo rol en la tabla Roles
            INSERT INTO Roles (Id, RoleName) VALUES (@RoleId, @RoleName)
        END
        ELSE
        BEGIN
			-- Error si el rol ya existe
			SET @ErrorMessage = 'El rol ya existe';
			SET @ErrorSeverity = 16;
			RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
			-- Revertir la transacción
			ROLLBACK TRANSACTION
			RETURN;
        END

        -- Confirmar la transacción si todo va bien
        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        -- Revertir la transacción en caso de error
        ROLLBACK TRANSACTION
        SELECT @ErrorMessage = ERROR_MESSAGE();
		-- Registro del error en la tabla HistoryLog
        INSERT INTO proyecto1.HistoryLog (Date, Description)
        VALUES (GETDATE(), 'Error Creación Rol - ' + @ErrorMessage);
		RAISERROR (@ErrorMessage, @ErrorSeverity, 1);
    END CATCH
END
GO

-- PROCEDIMIENTO PR5 (Creacion de Cursos)

CREATE PROCEDURE proyecto1.PR5(@CodCourse int, @Name nvarchar(max), @CreditsRequired int)
AS BEGIN
    DECLARE @Description nvarchar(max);
    Declare @IsValid BIT;
    -- Validación de datos con el PR6
    EXEC proyecto1.PR6 'Course',NULL,NULL, @Name, @CreditsRequired, @IsValid OUTPUT ;
    IF @IsValid = 0
        BEGIN
            -- Sí los datos son incorrectos
            SET @Description = 'No se pudo crear el curso correctamente';
            INSERT INTO proyecto1.HistoryLog ([Date], Description)
            VALUES (GETDATE(), @Description);
            SELECT @Description AS 'Error';
            ROLLBACK TRANSACTION;
            RETURN;
        END
    -- Error si los creditos nos son corrrectos
    IF @CreditsRequired < 0
        BEGIN
            SET @Description = 'Creación de Curso Erronea Creditos con valor menos a 0';
            INSERT INTO proyecto1.HistoryLog ([Date], Description)
            VALUES (GETDATE(), @Description);
            SELECT @Description AS 'Error';
            ROLLBACK TRANSACTION;
            RETURN;
        END
    -- Error si el código de curso no es corrrecto
    IF @CodCourse < 0
        BEGIN
            SET @Description = 'Creación de Curso Erronea Código de Curso invalido';
            INSERT INTO proyecto1.HistoryLog ([Date], Description)
            VALUES (GETDATE(), @Description);
            SELECT @Description AS 'Error';
            ROLLBACK TRANSACTION;
            RETURN;
        END


    BEGIN TRY
        BEGIN TRANSACTION;
        -- Creación del curso
        INSERT INTO proyecto1.Course(CodCourse, Name, CreditsRequired) VALUES
        (@CodCourse, @Name, @CreditsRequired);
        SELECT 'Creacion de Curso Correcta' AS Mensaje;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Sí hay error en la inserción
        SET @Description = 'Creacion de Curso Incorrecta'+ ERROR_MESSAGE();
        SELECT @Description AS 'Error';
        ROLLBACK TRANSACTION;
    END CATCH;
END;
GO

-- PROCEDIMIENTO PR6 (Validacion de Datos)
CREATE PROCEDURE proyecto1.PR6
    @EntityName NVARCHAR(50),
    @FirstName NVARCHAR(MAX) = NULL,
    @LastName NVARCHAR(MAX) = NULL,
    @Name NVARCHAR(MAX) = NULL,
    @CreditsRequired INT = NULL,
    @IsValid BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
	-- Validaciones de Usuario
    IF @EntityName = 'Usuarios'
    BEGIN
        IF ISNULL(@FirstName, '') NOT LIKE '%[^a-zA-Z ]%' AND ISNULL(@LastName, '') NOT LIKE '%[^a-zA-Z ]%'
            SET @IsValid = 1;
        ELSE
            SET @IsValid = 0;
    END
    -- Validacion de Curso
    ELSE IF @EntityName = 'Course'
    BEGIN
        IF ISNULL(@Name, '') NOT LIKE '%[^a-zA-Z ]%' AND ISNUMERIC(@CreditsRequired) = 1
			IF @CreditsRequired >= 0
                SET @IsValid = 1;
             ELSE
				SET @IsValid = 0;
        ELSE
            SET @IsValid = 0;
    END
    ELSE
    BEGIN
        -- No valida
        SET @IsValid = 0;
    END;
END;
GO
-- >>>>>>>>>>>>>>>> FUNCIONES <<<<<<<<<<<<<<<<

-- FUNCION 1:  Func_course_usuarios
CREATE FUNCTION proyecto1.F1(@CodCourse INT)
RETURNS TABLE
AS
RETURN
(
    SELECT U.Id, U.Firstname, U.Lastname, U.Email
    FROM Usuarios U
    JOIN CourseAssignment CA ON U.Id = CA.StudentId
    WHERE CA.CourseCodCourse = @CodCourse
)
GO

-- FUNCION 2:  Func_tutor_course
CREATE FUNCTION proyecto1.F2(@Id INT)
RETURNS TABLE
AS
RETURN	
(
    SELECT c.CodCourse, c.Name
    FROM proyecto1.Course c
    JOIN proyecto1.CourseTutor ct ON c.CodCourse = ct.CourseCodCourse
    JOIN proyecto1.TutorProfile tp ON ct.TutorId = tp.UserId
    WHERE tp.Id = @Id
);

-- FUNCION 3: Func_notification_usuarios
CREATE FUNCTION proyecto1.F3(@UserId UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN
(
    SELECT Id, Message, Date FROM Notification 
    WHERE UserId = @UserId
)
GO

-- FUNCION 4: Func_logger
CREATE FUNCTION proyecto1.F4()
RETURNS TABLE
AS
RETURN
(
    SELECT *
    FROM proyecto1.HistoryLog
);
GO

-- FUNCION 5: Func_usuarios
CREATE FUNCTION proyecto1.F5 (@Id uniqueidentifier)
RETURNS TABLE
    AS
    RETURN
(
    select
        US.Firstname,
        US.Lastname,
        US.Email,
        US.DateOfBirth,
        PROF.Credits,
        ROL.RoleName
    from Usuarios US
    inner join UsuarioRole UROL on US.Id = UROL.UserId
    inner join Roles ROL on UROL.RoleId = ROL.Id
    left join ProfileStudent PROF on US.Id = PROF.UserId
    where US.Id = @Id
);
GO


-- >>>>>>>>>>>>>>>>TRIGGER PARA HISTORYLOG<<<<<<<<<<<<<<<<
-- TRIGGER NOTIFICACION
CREATE TRIGGER proyecto1.TriggerNotification
ON proyecto1.Roles
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    DECLARE @Operacion VARCHAR(20);
    DECLARE @Descripcion VARCHAR(100);

   IF EXISTS (SELECT * FROM inserted)
        SET @Operacion = 'INSERT';
    ELSE IF EXISTS (SELECT * FROM deleted)
        SET @Operacion = 'DELETE';
    ELSE
        SET @Operacion = 'UPDATE';

    SET @Descripcion = 'Operacion ' + @Operacion + ' Exitosa - Tabla Notification';

    INSERT INTO proyecto1.HistoryLog ([Date], Description)
    VALUES (GETDATE(), @Descripcion);
END;
GO

-- TRIGGER ROL
CREATE TRIGGER proyecto1.TriggerRol
ON proyecto1.Roles
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    DECLARE @Operacion VARCHAR(20);
    DECLARE @Descripcion VARCHAR(100);

   IF EXISTS (SELECT * FROM inserted)
        SET @Operacion = 'INSERT';
    ELSE IF EXISTS (SELECT * FROM deleted)
        SET @Operacion = 'DELETE';
    ELSE
        SET @Operacion = 'UPDATE';

    SET @Descripcion = 'Operacion ' + @Operacion + ' Exitosa - Tabla Roles';

    INSERT INTO proyecto1.HistoryLog ([Date], Description)
    VALUES (GETDATE(), @Descripcion);
END;
GO
-- TRIGGER COURSE
CREATE TRIGGER proyecto1.TriggerCourse
ON proyecto1.Course
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    DECLARE @Operacion VARCHAR(20);
    DECLARE @Descripcion VARCHAR(100);

   IF EXISTS (SELECT * FROM inserted)
        SET @Operacion = 'INSERT';
    ELSE IF EXISTS (SELECT * FROM deleted)
        SET @Operacion = 'DELETE';
    ELSE
        SET @Operacion = 'UPDATE';

    SET @Descripcion = 'Operacion ' + @Operacion + ' Exitosa - Tabla Course';

    INSERT INTO proyecto1.HistoryLog ([Date], Description)
    VALUES (GETDATE(), @Descripcion);
END;
GO
-- TRIGGER COURSEASSIGNMENT
CREATE TRIGGER proyecto1.TriggerCourseAssignment
ON proyecto1.CourseAssignment
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    DECLARE @Operacion VARCHAR(20);
    DECLARE @Descripcion VARCHAR(100);

   IF EXISTS (SELECT * FROM inserted)
        SET @Operacion = 'INSERT';
    ELSE IF EXISTS (SELECT * FROM deleted)
        SET @Operacion = 'DELETE';
    ELSE
        SET @Operacion = 'UPDATE';

    SET @Descripcion = 'Operacion ' + @Operacion + ' Exitosa - Tabla CourseAssigment';

    INSERT INTO proyecto1.HistoryLog ([Date], Description)
    VALUES (GETDATE(), @Descripcion);
END;

GO
-- TRIGGER Course Tutor
CREATE TRIGGER proyecto1.TriggerCourseTutor
ON proyecto1.CourseTutor
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    DECLARE @Operacion VARCHAR(20);
    DECLARE @Descripcion VARCHAR(100);

   IF EXISTS (SELECT * FROM inserted)
        SET @Operacion = 'INSERT';
    ELSE IF EXISTS (SELECT * FROM deleted)
        SET @Operacion = 'DELETE';
    ELSE
        SET @Operacion = 'UPDATE';

    SET @Descripcion = 'Operacion ' + @Operacion + ' Exitosa - Tabla CourseTutor';

    INSERT INTO proyecto1.HistoryLog ([Date], Description)
    VALUES (GETDATE(), @Descripcion);
END;
GO
-- No trigger para tabla HistoryLog

-- TRIGGER Profile Student
CREATE TRIGGER proyecto1.TriggerProfileStudent
ON proyecto1.ProfileStudent
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    DECLARE @Operacion VARCHAR(20);
    DECLARE @Descripcion VARCHAR(100);

   IF EXISTS (SELECT * FROM inserted)
        SET @Operacion = 'INSERT';
    ELSE IF EXISTS (SELECT * FROM deleted)
        SET @Operacion = 'DELETE';
    ELSE
        SET @Operacion = 'UPDATE';

    SET @Descripcion = 'Operacion ' + @Operacion + ' Exitosa - Tabla ProfileStudent';

    INSERT INTO proyecto1.HistoryLog ([Date], Description)
    VALUES (GETDATE(), @Descripcion);
END;
GO
-- TRIGGER TFA
CREATE TRIGGER proyecto1.TriggerTFA
ON proyecto1.TFA
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    DECLARE @Operacion VARCHAR(20);
    DECLARE @Descripcion VARCHAR(100);

   IF EXISTS (SELECT * FROM inserted)
        SET @Operacion = 'INSERT';
    ELSE IF EXISTS (SELECT * FROM deleted)
        SET @Operacion = 'DELETE';
    ELSE
        SET @Operacion = 'UPDATE';

    SET @Descripcion = 'Operacion ' + @Operacion + ' Exitosa - Tabla TFA';

    INSERT INTO proyecto1.HistoryLog ([Date], Description)
    VALUES (GETDATE(), @Descripcion);
END;
GO
-- TRIGGER TutorProfile
CREATE TRIGGER proyecto1.TriggerTutorProfile
ON proyecto1.TutorProfile
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    DECLARE @Operacion VARCHAR(20);
    DECLARE @Descripcion VARCHAR(100);

   IF EXISTS (SELECT * FROM inserted)
        SET @Operacion = 'INSERT';
    ELSE IF EXISTS (SELECT * FROM deleted)
        SET @Operacion = 'DELETE';
    ELSE
        SET @Operacion = 'UPDATE';

    SET @Descripcion = 'Operacion ' + @Operacion + ' Exitosa - Tabla TutorProfile';

    INSERT INTO proyecto1.HistoryLog ([Date], Description)
    VALUES (GETDATE(), @Descripcion);
END;
GO

-- TRIGGER UsuarioRole
CREATE TRIGGER proyecto1.TriggerUsuarioRole
ON proyecto1.UsuarioRole
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    DECLARE @Operacion VARCHAR(20);
    DECLARE @Descripcion VARCHAR(100);

   IF EXISTS (SELECT * FROM inserted)
        SET @Operacion = 'INSERT';
    ELSE IF EXISTS (SELECT * FROM deleted)
        SET @Operacion = 'DELETE';
    ELSE
        SET @Operacion = 'UPDATE';

    SET @Descripcion = 'Operacion ' + @Operacion + ' Exitosa - Tabla UsuarioRole';

    INSERT INTO proyecto1.HistoryLog ([Date], Description)
    VALUES (GETDATE(), @Descripcion);
END;
GO
-- TRIGGER USUARIOS
CREATE TRIGGER proyecto1.TriggerUsuarios
ON proyecto1.Usuarios
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    DECLARE @Operacion VARCHAR(20);
    DECLARE @Descripcion VARCHAR(100);

   IF EXISTS (SELECT * FROM inserted)
        SET @Operacion = 'INSERT';
    ELSE IF EXISTS (SELECT * FROM deleted)
        SET @Operacion = 'DELETE';
    ELSE
        SET @Operacion = 'UPDATE';

    SET @Descripcion = 'Operacion ' + @Operacion + ' Exitosa - Tabla Usuarios';

    INSERT INTO proyecto1.HistoryLog ([Date], Description)
    VALUES (GETDATE(), @Descripcion);
END;
GO