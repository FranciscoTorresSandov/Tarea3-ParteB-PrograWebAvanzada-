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

