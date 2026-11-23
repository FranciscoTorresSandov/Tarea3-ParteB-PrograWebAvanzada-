-- Universidad CENFOTEC | SOFT-12 | Tarea 3, Parte B | Innovation Hub
-- Consultas T-SQL de diseño, sobre los datos del Paso 5 de modelo-datos.md.
-- No ejecutadas: SQL Server y la API .NET se implementarán en la entrega final.
-- Cada ejercicio se considera independiente y parte de los datos originales.

-- 1. JOIN 1:N: cada iniciativa y el nombre de su propietario.
-- Esperado: 3 filas: (4, Mentorías tecnológicas, Ana Rojas),
-- (6, Datos de calidad del aire, Ana Rojas), (8, Orientación laboral, Ana Rojas).
SELECT i.Id, i.Title, CONCAT(u.FirstName, N' ', u.LastName) AS OwnerName
FROM dbo.Initiatives AS i
INNER JOIN dbo.Users AS u ON u.Id = i.OwnerId
ORDER BY i.Id;

-- 2. JOIN N:M: competencias requeridas por iniciativa mediante InitiativeSkills.
-- Esperado: 6 filas: 4 Desarrollo web, 4 Facilitación; 6 Diseño, 6 Datos;
-- 8 Comunicación, 8 Recursos humanos. Position conserva el orden del arreglo.
SELECT i.Id AS InitiativeId, i.Title, s.Name AS SkillName
FROM dbo.Initiatives AS i
INNER JOIN dbo.InitiativeSkills AS ix ON ix.InitiativeId = i.Id
INNER JOIN dbo.Skills AS s ON s.Id = ix.SkillId
ORDER BY i.Id, ix.Position;

-- 3. GROUP BY: cantidad de solicitudes por iniciativa (incluye las que no tienen).
-- Esperado: (4, 2), (6, 0), (8, 1). COUNT(r.Id) no cuenta el NULL del LEFT JOIN.
SELECT i.Id, i.Title, COUNT(r.Id) AS RequestCount
FROM dbo.Initiatives AS i
LEFT JOIN dbo.ParticipationRequests AS r ON r.InitiativeId = i.Id
GROUP BY i.Id, i.Title
ORDER BY i.Id;

-- 4. UPDATE con WHERE: cambiar disponibilidad de Luis (Id 2) de medium a high.
-- Esperado: exactamente una fila; no cambia el email ni las demás personas.
-- SYSUTCDATETIME mantiene UpdatedAt actualizado. Se revierte solo la demostración.
BEGIN TRANSACTION;
UPDATE dbo.Users
SET Availability = 'high', UpdatedAt = SYSUTCDATETIME()
WHERE Id = 2 AND Availability = 'medium';
SELECT @@ROWCOUNT AS AffectedRows;
ROLLBACK TRANSACTION;

-- 5. DELETE con WHERE: quitar el interés "comunidad" de Luis (posición 2).
-- Esperado: una fila eliminada de UserInterests; quedan 6 intereses en total,
-- Luis conserva "accesibilidad". No se borra al usuario ni su historial.
-- No se usa DELETE sobre una iniciativa con historial, que sería inválido.
BEGIN TRANSACTION;
DELETE FROM dbo.UserInterests
WHERE UserId = 2 AND Position = 2 AND Value = N'comunidad';
SELECT @@ROWCOUNT AS AffectedRows;
ROLLBACK TRANSACTION;

-- 6. INSERT rechazado: Luis ya tiene una solicitud pending para iniciativa 4.
-- La competencia 3 existe y pertenece a Luis; los demás campos son válidos.
-- Esperado: no se inserta ninguna fila. El índice único filtrado
-- (InitiativeId, ApplicantId) WHERE State = 'pending' rechaza (4, 2).
-- Sigue habiendo 3 solicitudes. La solicitud rejected anterior sí puede coexistir.
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.ParticipationRequests
        (PublicId, InitiativeId, ApplicantId, OfferedSkillId, Message, Role,
         Availability, State, DecisionComment, CreatedAt, UpdatedAt, DecidedAt)
    VALUES
        (NEWID(), 4, 2, 3, N'Puedo colaborar con la investigación de mentorías.',
         N'Investigación', 'medium', 'pending', NULL,
         SYSUTCDATETIME(), SYSUTCDATETIME(), NULL);
    ROLLBACK TRANSACTION; -- si se alcanzara, faltaría aplicar el índice del diseño
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
END CATCH;

-- 7. JOIN N:M adicional: integrantes activos de cada proyecto a través del equipo
-- de su iniciativa. Esperado: proyecto 1, Ana Rojas, Carla Vega y Elena Solís
-- (ordenados por Id de usuario); Luis no aparece porque su membresía está retired.
SELECT p.Id AS ProjectId, p.Name, u.FirstName, u.LastName, m.Role
FROM dbo.Projects AS p
INNER JOIN dbo.Memberships AS m ON m.InitiativeId = p.SourceInitiativeId
INNER JOIN dbo.Users AS u ON u.Id = m.UserId
WHERE m.State = 'active'
ORDER BY p.Id, u.Id;
