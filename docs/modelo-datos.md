# Innovation Hub — Modelo relacional (SQL Server)

**Universidad CENFOTEC · SOFT-12 · Tarea 3, Parte B**  
**Integrantes:** Daniel Campos Sánchez y Francisco José Torres Sandoval.  
**Docente:** Álvaro Cordero Peña · III cuatrimestre de 2026.

Diseño para la futura API .NET con EF Core. No se ha creado ni ejecutado una base de datos SQL Server. El punto de partida es el Avance 2: `servidor/src/models/`, `servidor/src/validation/`, `servidor/src/services/`, `servidor/src/dto/`, `pruebas/fixtures/` y [contrato HTTP](api-contract.md). Se mantienen las reglas y la respuesta JSON del servidor Express.

## Diagrama

Se proponen 14 tablas: nueve proceden de las colecciones existentes y cinco reemplazan sus arreglos. Las relaciones se representan con notación pata de cuervo. PK = llave primaria, FK = llave foránea y UK = llave única. El equipo de un proyecto es el equipo de la iniciativa de origen, no una segunda copia de sus integrantes.

```mermaid
erDiagram
    Users ||--o{ Sessions : autentica
    Users ||--o{ UserSkills : posee
    Skills ||--o{ UserSkills : clasifica
    Users ||--o{ UserInterests : declara
    Users ||--o{ Initiatives : publica
    Categories ||--o{ Initiatives : categoriza
    Initiatives ||--o{ InitiativeSkills : requiere
    Skills ||--o{ InitiativeSkills : clasifica
    Initiatives ||--o{ InitiativeTags : etiqueta
    Initiatives ||--o{ ParticipationRequests : recibe
    Users ||--o{ ParticipationRequests : solicita
    Skills ||--o{ ParticipationRequests : ofrece
    Initiatives ||--o{ Memberships : integra
    Users ||--o{ Memberships : participa
    ParticipationRequests o|--o{ Memberships : origina
    Memberships ||--o{ MembershipEvents : registra
    Initiatives ||--o{ MembershipEvents : contextualiza
    Users ||--o{ MembershipEvents : integrante
    Users ||--o{ MembershipEvents : actor
    ParticipationRequests o|--o{ MembershipEvents : referencia
    Initiatives ||--o| Projects : convierte
    Users ||--o{ Projects : posee
    Projects ||--o{ ProjectTechnologies : utiliza

    Users {
        int Id PK
        uniqueidentifier PublicId UK
        nvarchar EmailNormalized UK
    }
    Sessions {
        int Id PK
        uniqueidentifier PublicId UK
        int UserId FK
        varchar TokenHash UK
    }
    Categories {
        int Id PK
        varchar PublicId UK
    }
    Skills {
        int Id PK
        uniqueidentifier PublicId UK
    }
    UserSkills {
        int UserId PK,FK
        int SkillId PK,FK
        varchar Level
        int Position
    }
    UserInterests {
        int UserId PK,FK
        int Position PK
        nvarchar Value
    }
    Initiatives {
        int Id PK
        uniqueidentifier PublicId UK
        int OwnerId FK
        int CategoryId FK
    }
    InitiativeSkills {
        int InitiativeId PK,FK
        int SkillId PK,FK
        int Position
    }
    InitiativeTags {
        int InitiativeId PK,FK
        int Position PK
        nvarchar Value
    }
    ParticipationRequests {
        int Id PK
        uniqueidentifier PublicId UK
        int InitiativeId FK
        int ApplicantId FK
        int OfferedSkillId FK
    }
    Memberships {
        int Id PK
        uniqueidentifier PublicId UK
        int InitiativeId FK
        int UserId FK
        int SourceRequestId FK
        varchar State
    }
    MembershipEvents {
        int Id PK
        uniqueidentifier PublicId UK
        int InitiativeId FK
        int UserId FK
        int MembershipId FK
        int ActorId FK
        int RequestId FK
    }
    Projects {
        int Id PK
        uniqueidentifier PublicId UK
        int SourceInitiativeId FK,UK
        int OwnerId FK
    }
    ProjectTechnologies {
        int ProjectId PK,FK
        int Position PK
        nvarchar Value
    }
```

### Relaciones solicitadas

| Relación | Tipo | Resolución |
| --- | --- | --- |
| Usuario–competencia | Muchos a muchos | `UserSkills` une `Users` y `Skills` mediante dos FK y conserva el nivel. |
| Usuario–iniciativa | Uno a muchos (propiedad) | `Initiatives.OwnerId → Users.Id`. Un usuario puede publicar varias iniciativas, cada una tiene un propietario. |
| Iniciativa–competencia | Muchos a muchos | `InitiativeSkills` contiene FK a `Initiatives` y `Skills`. |
| Iniciativa–solicitud | Uno a muchos | `ParticipationRequests.InitiativeId → Initiatives.Id`. |
| Proyecto–usuario | Muchos a muchos | `Memberships` es la tabla intermedia entre usuarios e iniciativas; `Projects.SourceInitiativeId` identifica el equipo reutilizado. Un JOIN `Projects → Memberships → Users` recupera sus integrantes activos. No se crea una tabla ProyectoUsuario redundante. |
| Proyecto–iniciativa | Uno a cero o uno (caso restringido de uno a muchos) | `Projects.SourceInitiativeId → Initiatives.Id` con UNIQUE: una iniciativa puede no tener proyecto, pero nunca dos. Cada proyecto procede de una iniciativa. |

### Del documento a la tabla

| Colección o arreglo de MongoDB | Tabla SQL Server | Correspondencia y justificación |
| --- | --- | --- |
| `users` | `Users` | Una fila por usuario; conserva datos personales y autenticación. |
| `users.skills[]` (`skillId`, `level`) | `UserSkills` | Relación N:M; nivel propio de cada relación, FK a usuario y competencia. |
| `users.interests[]` | `UserInterests` | Una fila por interés; orden y límites sin listas separadas por comas. |
| `sessions` | `Sessions` | Una fila por sesión; `userId → UserId`, hash único y fecha de expiración. |
| `categories` | `Categories` | Catálogo; conserva slug estable en `PublicId`. |
| `skills` | `Skills` | Catálogo reutilizable; UUID en `PublicId`. |
| `initiatives` | `Initiatives` | `ownerId → OwnerId` y `categoryId → CategoryId`; mantiene estados y visibilidad. |
| `initiatives.skillIds[]` | `InitiativeSkills` | N:M, dos FK y posición para reconstruir el arreglo. |
| `initiatives.tags[]` | `InitiativeTags` | Hijas de iniciativa; cada etiqueta se consulta individualmente. |
| `requests` | `ParticipationRequests` | `initiativeId → InitiativeId`, `applicantId → ApplicantId`, `offeredSkillId → OfferedSkillId`. Historial y solicitudes pendientes únicas. |
| `memberships` | `Memberships` | `initiativeId → InitiativeId`, `userId → UserId`, `sourceRequestId → SourceRequestId` opcional; conserva periodos y roles. |
| `membershipEvents` | `MembershipEvents` | `initiativeId`, `userId`, `membershipId`, `actorId`, `requestId` se convierten a FK numéricas homónimas; historial de ingreso y retiro. |
| `projects` | `Projects` | `sourceInitiativeId → SourceInitiativeId` único, `ownerId → OwnerId`; comparte equipo con iniciativa. |
| `projects.technologies[]` | `ProjectTechnologies` | Una fila por tecnología y posición; no se inventa un catálogo de tecnologías ajeno al Avance 2. |

## Tablas

Convenciones: `Id INT IDENTITY(1,1)` es interno; `PublicId UNIQUEIDENTIFIER` conserva el UUID público original excepto categorías, que conservan su slug. Los tipos `DATETIME2(3)` almacenan instantes UTC y `DATE` almacena fechas sin hora. Las PK compuestas identifican las filas dependientes sin otro autoincremental. En cada FK, **NO ACTION** impide borrar el padre referenciado; **CASCADE** elimina únicamente filas hijas sin ciclo de vida independiente. No se usa SET NULL para borrar hechos históricos, aunque algunas referencias admiten NULL desde su creación.

### 1. Users

| Columna | Tipo | ¿Obligatoria? | Llave | Regla |
| --- | --- | --- | --- | --- |
| Id | INT IDENTITY | Sí | Primaria | Positiva. |
| PublicId | UNIQUEIDENTIFIER | Sí | UNIQUE | UUID v4 inmutable; API `id`. |
| FirstName | NVARCHAR(60) | Sí | | 2–60 caracteres. |
| LastName | NVARCHAR(80) | Sí | | 2–80 caracteres. |
| MemberType | VARCHAR(20) | Sí | | CHECK: student, professor, administrative, graduate, external. |
| Email | NVARCHAR(254) | Sí | | Formato correo, no editable desde perfil. |
| EmailNormalized | NVARCHAR(254) | Sí | UNIQUE | Minúsculas y sin espacios externos. |
| PasswordHash | VARCHAR(255) | Sí | | Hash scrypt con sal, nunca contraseña en claro. |
| Career | NVARCHAR(120) | No | | NULL si no se informa. |
| Bio | NVARCHAR(600) | No | | NULL si no se informa. |
| Availability | VARCHAR(10) | Sí | | CHECK low, medium, high; DEFAULT medium. |
| PortfolioUrl | NVARCHAR(2048) | No | | URL HTTP(S) válida o NULL. |
| Active | BIT | Sí | | DEFAULT 1. |
| CreatedAt | DATETIME2(3) | Sí | | UTC, inmutable. |
| UpdatedAt | DATETIME2(3) | Sí | | CHECK UpdatedAt >= CreatedAt. |

### 2. Categories

| Columna | Tipo | ¿Obligatoria? | Llave | Regla |
| --- | --- | --- | --- | --- |
| Id | INT IDENTITY | Sí | Primaria | Positiva. |
| PublicId | VARCHAR(80) | Sí | UNIQUE | Slug inmutable. |
| Name | NVARCHAR(80) | Sí | | 2–80 caracteres. |
| NameNormalized | NVARCHAR(80) | Sí | UNIQUE | Normalizado sin tildes, minúsculas. |
| Active | BIT | Sí | | DEFAULT 1; desactivar conserva referencias. |

### 3. Skills

| Columna | Tipo | ¿Obligatoria? | Llave | Regla |
| --- | --- | --- | --- | --- |
| Id | INT IDENTITY | Sí | Primaria | Positiva. |
| PublicId | UNIQUEIDENTIFIER | Sí | UNIQUE | UUID v4 inmutable. |
| Name | NVARCHAR(80) | Sí | | 2–80 caracteres. |
| NameNormalized | NVARCHAR(80) | Sí | UNIQUE | Nombre normalizado. |
| Active | BIT | Sí | | DEFAULT 1. |

### 4. Sessions

| Columna | Tipo | ¿Obligatoria? | Llave | Regla |
| --- | --- | --- | --- | --- |
| Id | INT IDENTITY | Sí | Primaria | Positiva. |
| PublicId | UNIQUEIDENTIFIER | Sí | UNIQUE | UUID v4 inmutable. |
| UserId | INT | Sí | Foránea → Users.Id | ON DELETE NO ACTION. |
| TokenHash | VARCHAR(43) | Sí | UNIQUE | SHA-256 codificado base64url, no token en claro. Usar collation binaria. |
| ExpiresAt | DATETIME2(3) | Sí | | CHECK ExpiresAt > CreatedAt; índice. |
| RevokedAt | DATETIME2(3) | No | | NULL si no revocada; si existe >= CreatedAt. |
| CreatedAt | DATETIME2(3) | Sí | | UTC. |

### 5. UserSkills

| Columna | Tipo | ¿Obligatoria? | Llave | Regla |
| --- | --- | --- | --- | --- |
| UserId | INT | Sí | Primaria compuesta; foránea → Users.Id | ON DELETE CASCADE. |
| SkillId | INT | Sí | Primaria compuesta; foránea → Skills.Id | ON DELETE NO ACTION. |
| Level | VARCHAR(15) | Sí | | CHECK basic, intermediate, advanced. |
| Position | INT | Sí | | CHECK 1–20; UNIQUE(UserId, Position). |

PK(UserId, SkillId): una competencia no se repite dentro del perfil. Máximo 20 competencias por perfil; competencia activa al asignar.

### 6. UserInterests

| Columna | Tipo | ¿Obligatoria? | Llave | Regla |
| --- | --- | --- | --- | --- |
| UserId | INT | Sí | Primaria compuesta; foránea → Users.Id | ON DELETE CASCADE. |
| Position | INT | Sí | Primaria compuesta | CHECK 1–15. |
| Value | NVARCHAR(40) | Sí | | 1–40 caracteres; UNIQUE(UserId, Value) con collation CI_AS. |

### 7. Initiatives

| Columna | Tipo | ¿Obligatoria? | Llave | Regla |
| --- | --- | --- | --- | --- |
| Id | INT IDENTITY | Sí | Primaria | Positiva. |
| PublicId | UNIQUEIDENTIFIER | Sí | UNIQUE | UUID v4 inmutable. |
| OwnerId | INT | Sí | Foránea → Users.Id | ON DELETE NO ACTION; propietario inmutable. |
| CategoryId | INT | Sí | Foránea → Categories.Id | ON DELETE NO ACTION; categoría activa al asignar. |
| Title | NVARCHAR(100) | Sí | | 5–100 caracteres. |
| Type | VARCHAR(10) | Sí | | CHECK idea, need, challenge. |
| Summary | NVARCHAR(240) | Sí | | 15–240 caracteres. |
| Description | NVARCHAR(2000) | Sí | | 20–2000 caracteres. |
| Problem | NVARCHAR(500) | Sí | | 10–500 caracteres. |
| Beneficiaries | NVARCHAR(150) | Sí | | 3–150 caracteres. |
| EstimatedMembers | INT | Sí | | CHECK 1–100; estimación, no cupo máximo. |
| Visibility | VARCHAR(15) | Sí | | CHECK public, institutional, restricted, private. |
| State | VARCHAR(20) | Sí | | CHECK draft, published, forming_team, converted, archived. |
| SearchText | NVARCHAR(1000) | Sí | | Derivado de título, resumen y tags; nunca se expone. |
| PublicSearchText | NVARCHAR(341) | Sí | | Título y resumen normalizados para búsquedas restringidas. |
| TitleNormalized | NVARCHAR(100) | Sí | | Derivado para ordenar. |
| Revision | INT | Sí | | CHECK >= 0; DEFAULT 0, token de concurrencia EF Core. |
| CreatedAt | DATETIME2(3) | Sí | | Inmutable, UTC. |
| UpdatedAt | DATETIME2(3) | Sí | | CHECK UpdatedAt >= CreatedAt. |

### 8. InitiativeSkills

| Columna | Tipo | ¿Obligatoria? | Llave | Regla |
| --- | --- | --- | --- | --- |
| InitiativeId | INT | Sí | Primaria compuesta; foránea → Initiatives.Id | ON DELETE CASCADE. |
| SkillId | INT | Sí | Primaria compuesta; foránea → Skills.Id | ON DELETE NO ACTION. |
| Position | INT | Sí | | CHECK 1–10; UNIQUE(InitiativeId, Position). |

PK(InitiativeId, SkillId). Cada iniciativa publicada requiere entre 1 y 10 competencias activas al asignar.

### 9. InitiativeTags

| Columna | Tipo | ¿Obligatoria? | Llave | Regla |
| --- | --- | --- | --- | --- |
| InitiativeId | INT | Sí | Primaria compuesta; foránea → Initiatives.Id | ON DELETE CASCADE. |
| Position | INT | Sí | Primaria compuesta | CHECK 1–10. |
| Value | NVARCHAR(40) | Sí | | 1–40 caracteres; UNIQUE(InitiativeId, Value) con collation CI_AI. |

### 10. ParticipationRequests

| Columna | Tipo | ¿Obligatoria? | Llave | Regla |
| --- | --- | --- | --- | --- |
| Id | INT IDENTITY | Sí | Primaria | Positiva. |
| PublicId | UNIQUEIDENTIFIER | Sí | UNIQUE | UUID v4 inmutable. |
| InitiativeId | INT | Sí | Foránea → Initiatives.Id | ON DELETE NO ACTION. |
| ApplicantId | INT | Sí | Foránea → Users.Id | ON DELETE NO ACTION. |
| OfferedSkillId | INT | Sí | Foránea → Skills.Id | ON DELETE NO ACTION; debe pertenecer al perfil al solicitar/editar. |
| Message | NVARCHAR(500) | Sí | | 15–500 caracteres. |
| Role | NVARCHAR(100) | Sí | | 3–100 caracteres. |
| Availability | VARCHAR(10) | Sí | | CHECK low, medium, high. |
| State | VARCHAR(10) | Sí | | CHECK pending, accepted, rejected, cancelled. |
| DecisionComment | NVARCHAR(500) | No | | NULL permitido. |
| CreatedAt | DATETIME2(3) | Sí | | UTC. |
| UpdatedAt | DATETIME2(3) | Sí | | CHECK >= CreatedAt. |
| DecidedAt | DATETIME2(3) | No | | Obligatoria al aceptar/rechazar, NULL pendiente/cancelada. |

Índice único filtrado `(InitiativeId, ApplicantId) WHERE State = 'pending'`; permite nuevos intentos sin borrar el historial.

### 11. Memberships

| Columna | Tipo | ¿Obligatoria? | Llave | Regla |
| --- | --- | --- | --- | --- |
| Id | INT IDENTITY | Sí | Primaria | Identifica un periodo de pertenencia. |
| PublicId | UNIQUEIDENTIFIER | Sí | UNIQUE | UUID v4 inmutable. |
| InitiativeId | INT | Sí | Foránea → Initiatives.Id | ON DELETE NO ACTION. |
| UserId | INT | Sí | Foránea → Users.Id | ON DELETE NO ACTION. |
| Role | NVARCHAR(150) | Sí | | 2–150 caracteres. |
| State | VARCHAR(10) | Sí | | CHECK active, retired. |
| JoinedAt | DATETIME2(3) | Sí | | UTC, inmutable. |
| RetiredAt | DATETIME2(3) | No | | NULL activa; retirada >= JoinedAt. |
| SourceRequestId | INT | No | Foránea → ParticipationRequests.Id | ON DELETE NO ACTION; NULL para dueño y legado. |

Índice único filtrado `(InitiativeId, UserId) WHERE State = 'active'`. La reincorporación genera otra fila. No se elimina la membresía para simular un retiro.

### 12. MembershipEvents

| Columna | Tipo | ¿Obligatoria? | Llave | Regla |
| --- | --- | --- | --- | --- |
| Id | INT IDENTITY | Sí | Primaria | Positiva. |
| PublicId | UNIQUEIDENTIFIER | Sí | UNIQUE | UUID v4 inmutable. |
| InitiativeId | INT | Sí | Foránea → Initiatives.Id | ON DELETE NO ACTION. |
| UserId | INT | Sí | Foránea → Users.Id | ON DELETE NO ACTION; integrante. |
| MembershipId | INT | Sí | Foránea → Memberships.Id | ON DELETE NO ACTION. |
| Type | VARCHAR(10) | Sí | | CHECK joined, retired. |
| OccurredAt | DATETIME2(3) | Sí | | UTC, inmutable. |
| ActorId | INT | Sí | Foránea → Users.Id | ON DELETE NO ACTION; quién ejecutó la acción. |
| RequestId | INT | No | Foránea → ParticipationRequests.Id | ON DELETE NO ACTION; NULL para origen sin solicitud. |

Historial de solo inserción en operaciones normales. UserId e InitiativeId se conservan por auditoría; deben coincidir con su membresía en la misma transacción. La única excepción a conservar eventos es la eliminación autorizada del agregado sin historial adicional (véase reglas).

### 13. Projects

| Columna | Tipo | ¿Obligatoria? | Llave | Regla |
| --- | --- | --- | --- | --- |
| Id | INT IDENTITY | Sí | Primaria | Positiva. |
| PublicId | UNIQUEIDENTIFIER | Sí | UNIQUE | UUID v4 inmutable. |
| SourceInitiativeId | INT | Sí | Foránea → Initiatives.Id; UNIQUE | ON DELETE NO ACTION; conversión única. |
| OwnerId | INT | Sí | Foránea → Users.Id | ON DELETE NO ACTION; coincide con dueño de iniciativa. |
| Name | NVARCHAR(120) | Sí | | 5–120 caracteres. |
| Description | NVARCHAR(2000) | Sí | | 20–2000 caracteres. |
| Objective | NVARCHAR(500) | Sí | | 10–500 caracteres. |
| StartDate | DATE | Sí | | Fecha calendario. |
| EstimatedEndDate | DATE | No | | NULL o CHECK >= StartDate. |
| State | VARCHAR(20) | Sí | | CHECK planning, in_development, paused, finished, archived. |
| RepositoryUrl | NVARCHAR(2048) | No | | URL HTTP(S) válida o NULL. |
| CreatedAt | DATETIME2(3) | Sí | | UTC. |
| UpdatedAt | DATETIME2(3) | Sí | | CHECK >= CreatedAt. |

### 14. ProjectTechnologies

| Columna | Tipo | ¿Obligatoria? | Llave | Regla |
| --- | --- | --- | --- | --- |
| ProjectId | INT | Sí | Primaria compuesta; foránea → Projects.Id | ON DELETE CASCADE. |
| Position | INT | Sí | Primaria compuesta | CHECK 1–20. |
| Value | NVARCHAR(50) | Sí | | 1–50 caracteres; UNIQUE(ProjectId, Value) con collation CI_AS. |

Al menos una tecnología por proyecto, como máximo 20.

### Integridad y reglas del dominio

Las restricciones de una fila se expresan con CHECK, NOT NULL, UNIQUE y FK; las longitudes mínimas se pueden comprobar con CHECK(LEN(LTRIM(RTRIM(...))) >= mínimo). Los máximos de arreglos se imponen por posición única y rango; el mínimo de elementos, autenticación, pertenencia a perfil, roles, visibilidad y transiciones entre tablas se validan mediante servicios y transacciones EF Core. `CI_AI` significa insensible a mayúsculas y acentos, `CI_AS` insensible a mayúsculas y sensible a acentos. No se confía en la interfaz como control de acceso.

- Al publicar: crear iniciativa, membresía activa del dueño y evento joined en una transacción. No existe guardado de borrador en la interfaz del Avance 2.
- Aceptar: solo dueño, solicitud pendiente, solicitante sin membresía activa, iniciativa en published/forming_team/converted. Actualizar solicitud, crear membresía y evento joined; published pasa a forming_team, converted se mantiene. Oferta de competencia validada al solicitar/editar, no se obliga a conservarla indefinidamente en el perfil.
- Retirar: solo dueño, nunca al propietario; cambiar estado/fecha y registrar evento retired. El integrante puede solicitar de nuevo. El historial de solicitudes y períodos no se borra.
- Convertir: solo dueño, estado published/forming_team, mínimo dos miembros activos incluyendo propietario; crear proyecto en planning y marcar iniciativa converted atómicamente; el equipo no se copia.
- Archivar y eliminar son distintos. Para borrar una iniciativa solo se admite el agregado sin solicitudes, proyecto ni historia adicional a la membresía/evento inicial del dueño. En esa transacción se eliminan primero ese evento y membresía inicial, después iniciativa (sus competencias y etiquetas se eliminan en cascada). Si hay historial, responder 409 y ofrecer archivo. Todas las demás relaciones históricas impiden borrado.
- Un usuario anónimo solo ve iniciativas públicas de catálogo; institucional requiere identidad, restringida muestra resumen a terceros autenticados, privada se oculta a ajenos; dueño y miembro activo tienen detalle según estado. Borrador/archivada no aparecen en catálogo general y su detalle queda reservado al dueño. Los proyectos heredan acceso de la iniciativa de origen.
- `memberCount`, `availableSpaces = MAX(0, EstimatedMembers - memberCount)` y `access` son derivados; no se guardan. El dueño cuenta como integrante. La estimación no impide aceptar solicitudes. `Revision` se incrementa junto a las mutaciones relevantes para prevenir carreras, con transacción y control optimista.
- Conservar índices de consulta: Initiatives(OwnerId, State, UpdatedAt), Initiatives(State, Visibility, CreatedAt), ParticipationRequests(ApplicantId, CreatedAt), ParticipationRequests(InitiativeId, State), Memberships(InitiativeId, State, JoinedAt), MembershipEvents(InitiativeId, OccurredAt), Projects(CreatedAt); indexar FK de consultas frecuentes. Índices únicos filtrados de solicitudes/membresías, además del UNIQUE de origen del proyecto. En Sessions un proceso programado futuro elimina expiradas; toda petición comprueba la expiración y revocación incluso si aún existe la fila.

## Plan de migración

### Paso 1 — Inventario

Todos los documentos tienen `_id` BSON ObjectId generado por MongoDB más el `id` público (UUID, salvo slug de categorías). Los modelos usan `versionKey: false`; no se migra `__v`. Los campos en negrita indican referencias o arreglos que se descomponen en la etapa relacional.

| Colección | Campos escalares | Arreglos / referencias |
| --- | --- | --- |
| users | id, firstName, lastName, memberType, email, emailNormalized, passwordHash, career, bio, availability, portfolioUrl, active, createdAt, updatedAt | **interests[]**, **skills[]** (skillId referencia skills, level). |
| sessions | id, tokenHash, expiresAt, revokedAt, createdAt | **userId → users**. |
| categories | id (slug), name, nameNormalized, active | Ninguno. |
| skills | id, name, nameNormalized, active | Ninguno. |
| initiatives | id, title, type, summary, description, problem, beneficiaries, estimatedMembers, visibility, state, searchText, publicSearchText, titleNormalized, revision, createdAt, updatedAt | **ownerId → users**, **categoryId → categories**, **skillIds[] → skills**, **tags[]**. |
| requests | id, message, role, availability, state, decisionComment, createdAt, updatedAt, decidedAt | **initiativeId → initiatives**, **applicantId → users**, **offeredSkillId → skills**. |
| memberships | id, role, state, joinedAt, retiredAt | **initiativeId → initiatives**, **userId → users**, **sourceRequestId → requests** (opcional). |
| membershipEvents | id, type, occurredAt | **initiativeId → initiatives**, **userId → users**, **membershipId → memberships**, **actorId → users**, **requestId → requests** (opcional). |
| projects | id, name, description, objective, startDate, estimatedEndDate, state, repositoryUrl, createdAt, updatedAt | **sourceInitiativeId → initiatives**, **ownerId → users**, **technologies[]**. |

Antes de migrar: tomar respaldo, identificar duplicados, verificar referencias, normalización/estados, fechas UTC y distinguir datos de producción frente a fixtures. Exportar en un entorno controlado, sin publicar hashes de sesión ni contraseña. Congelar escrituras durante la extracción consistente de las nueve colecciones o usar una instantánea equivalente.

### Paso 2 — Correspondencia

Aplicar exactamente la tabla [Del documento a la tabla](#del-documento-a-la-tabla) de la sección Diagrama. Los escalares se trasladan con los tipos definidos en Tablas, los arreglos se descomponen en filas con posición original y las referencias se resuelven mediante equivalencias del paso 4. No se materializan los campos calculados del DTO.

### Paso 3 — Orden de creación de las tablas

El siguiente orden sirve también para insertar datos y activar las FK sin dependencias inexistentes:

| Orden | Tabla | Dependencias previas |
| ---: | --- | --- |
| 1 | Users | Ninguna |
| 2 | Categories | Ninguna |
| 3 | Skills | Ninguna |
| 4 | Sessions | Users |
| 5 | UserSkills | Users, Skills |
| 6 | UserInterests | Users |
| 7 | Initiatives | Users, Categories |
| 8 | InitiativeSkills | Initiatives, Skills |
| 9 | InitiativeTags | Initiatives |
| 10 | ParticipationRequests | Initiatives, Users, Skills |
| 11 | Memberships | Initiatives, Users, ParticipationRequests |
| 12 | MembershipEvents | Memberships, Initiatives, Users, ParticipationRequests |
| 13 | Projects | Initiatives, Users |
| 14 | ProjectTechnologies | Projects |

En la futura entrega se podrán generar migraciones EF Core en ese orden lógico, configurar FK y restricciones y aplicar la migración a una base vacía. No desactivar restricciones para ocultar datos inválidos.

### Paso 4 — Identificadores

Para cada colección, conservar una equivalencia temporal `(Collection, MongoObjectId, PublicId, SqlId)` con unicidad por colección y por identificador. SQL genera `Id INT IDENTITY` al insertar cada entidad y registra el valor mediante `OUTPUT INSERTED.Id`. Las referencias del Avance 2 usan el `id` público, no `_id`: se buscan por Collection + PublicId en la equivalencia; si se encuentra un ObjectId en una exportación legado, se resuelve por Collection + MongoObjectId. Una referencia que no se resuelva detiene la carga, sin inventar registros. Las filas de arreglos se identifican por su PK compuesta.

| Colección | PublicId de ejemplo | SqlId de ejemplo |
| --- | --- | ---: |
| users | 11111111-1111-4111-8111-111111111111 | 1 |
| skills | aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4 | 4 |
| initiatives | 10000000-0000-4000-8000-000000000008 | 8 |
| projects | 50000000-0000-4000-8000-000000000001 | 1 |

Los ObjectId reales se obtienen de la exportación MongoDB; no están en los fixtures JSON. En este ejemplo los Id numéricos son asignaciones ilustrativas, con huecos válidos; para reproducirlos se puede usar IDENTITY_INSERT de manera controlada en una base de prueba futura. La API devuelve `PublicId` como texto (por ejemplo UUID), nunca el Id numérico ni el ObjectId. Con ello no se rompen enlaces React, Postman ni datos ya referenciados.

### Paso 5 — Carga de datos

Datos sintéticos seleccionados de los fixtures reales del Avance 2: usuarios activos, tres iniciativas de distinta visibilidad, sus solicitudes e historial, y un proyecto convertido. Se incluyen todos los catálogos. Constituyen un subconjunto cerrado por referencias para el diseño; no son un volcado completo ni una base ejecutada. Las tablas están en el orden del paso 3. `NULL` representa ausencia. Los UUID y fechas se mantienen; las revisiones se inicializan en 0 para esta muestra. Los hashes no forman parte de los fixtures JSON: se generarán con scrypt para contraseñas de demostración al cargar en un futuro entorno aislado; `HASH_DEMO_n` es una indicación de ese valor obligatorio pendiente, no una credencial ni un hash válido. No hay sesiones activas en la muestra; se crearán al autenticar.

#### 1. Users (4 filas)

| Id | PublicId | FirstName | LastName | MemberType | Email | EmailNormalized | PasswordHash |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 11111111-1111-4111-8111-111111111111 | Ana | Rojas | student | ana.owner@example.test | ana.owner@example.test | HASH_DEMO_1 |
| 2 | 22222222-2222-4222-8222-222222222222 | Luis | Mora | student | luis.applicant@example.test | luis.applicant@example.test | HASH_DEMO_2 |
| 3 | 33333333-3333-4333-8333-333333333333 | Carla | Vega | professor | carla.outsider@example.test | carla.outsider@example.test | HASH_DEMO_3 |
| 5 | 55555555-5555-4555-8555-555555555555 | Elena | Solís | administrative | elena.member@example.test | elena.member@example.test | HASH_DEMO_5 |

| Id | Career | Bio | Availability | PortfolioUrl | Active | CreatedAt | UpdatedAt |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Ingeniería del Software | Propietaria de iniciativas para pruebas compartidas. | high | NULL | 1 | 2026-10-10T14:00:00.000Z | 2026-10-10T14:00:00.000Z |
| 2 | Diseño de Experiencias Digitales | Solicitante usado en escenarios de participación. | medium | https://example.test/luis | 1 | 2026-10-11T14:00:00.000Z | 2026-10-11T14:00:00.000Z |
| 3 | NULL | NULL | low | NULL | 1 | 2026-10-12T14:00:00.000Z | 2026-10-12T14:00:00.000Z |
| 5 | NULL | Miembro aceptado para escenarios de equipo. | high | NULL | 1 | 2026-10-14T14:00:00.000Z | 2026-10-14T14:00:00.000Z |

Los bloques anteriores representan las mismas filas, enlazadas por Id.

#### 2. Categories (8 filas)

| Id | PublicId | Name | NameNormalized | Active |
| --- | --- | --- | --- | --- |
| 1 | technology | Tecnología | tecnologia | 1 |
| 2 | education | Educación | educacion | 1 |
| 3 | sustainability | Sostenibilidad | sostenibilidad | 1 |
| 4 | social-impact | Impacto social | impacto social | 1 |
| 5 | business | Negocios y emprendimiento | negocios y emprendimiento | 1 |
| 6 | health | Salud y bienestar | salud y bienestar | 1 |
| 7 | culture-creativity | Cultura y creatividad | cultura y creatividad | 1 |
| 8 | other | Otro | otro | 1 |

#### 3. Skills (10 filas)

| Id | PublicId | Name | NameNormalized | Active |
| --- | --- | --- | --- | --- |
| 1 | aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1 | Desarrollo web | desarrollo web | 1 |
| 2 | aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2 | Diseño | diseno | 1 |
| 3 | aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3 | Investigación | investigacion | 1 |
| 4 | aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4 | Comunicación | comunicacion | 1 |
| 5 | aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa5 | Logística | logistica | 1 |
| 6 | aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa6 | Facilitación | facilitacion | 1 |
| 7 | aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa7 | Datos | datos | 1 |
| 8 | aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8 | Sostenibilidad | sostenibilidad | 1 |
| 9 | aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa9 | Organización | organizacion | 1 |
| 10 | aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa10 | Recursos humanos | recursos humanos | 1 |

#### 4. Sessions (0 filas)

| Id | PublicId | UserId | TokenHash | ExpiresAt | RevokedAt | CreatedAt |
| --- | --- | --- | --- | --- | --- | --- |


Sin filas: las sesiones se generan al autenticar.

#### 5. UserSkills (7 filas)

| UserId | SkillId | Level | Position |
| --- | --- | --- | --- |
| 1 | 2 | advanced | 1 |
| 1 | 6 | intermediate | 2 |
| 2 | 3 | intermediate | 1 |
| 2 | 4 | advanced | 2 |
| 3 | 3 | advanced | 1 |
| 5 | 5 | advanced | 1 |
| 5 | 9 | advanced | 2 |

#### 6. UserInterests (7 filas)

| UserId | Position | Value |
| --- | --- | --- |
| 1 | 1 | educación |
| 1 | 2 | sostenibilidad |
| 2 | 1 | accesibilidad |
| 2 | 2 | comunidad |
| 3 | 1 | investigación |
| 5 | 1 | logística |
| 5 | 2 | impacto social |

#### 7. Initiatives (3 filas)

| Id | PublicId | OwnerId | CategoryId | Title | Type | Summary | Description |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 4 | 10000000-0000-4000-8000-000000000004 | 1 | 2 | Mentorías tecnológicas | idea | Vincular estudiantes con mentores voluntarios de la institución. | Organizar sesiones breves para acompañar proyectos académicos y resolver bloqueos técnicos. |
| 6 | 10000000-0000-4000-8000-000000000006 | 1 | 1 | Datos de calidad del aire | challenge | Visualizar lecturas ambientales en un tablero comprensible. | Crear gráficos claros con mediciones simuladas de diferentes zonas de la ciudad. |
| 8 | 10000000-0000-4000-8000-000000000008 | 1 | 2 | Orientación laboral | need | Crear recursos y prácticas guiadas para entrevistas laborales. | Reunir guías y ofrecer espacios de práctica con voluntarios de recursos humanos. |

| Id | Problem | Beneficiaries | EstimatedMembers | Visibility | State | SearchText | PublicSearchText |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 4 | Faltan espacios de asesoría práctica para proyectos estudiantiles. | Estudiantes de la institución | 3 | institutional | published | mentorias tecnologicas vincular estudiantes con mentores voluntarios de la institucion. mentoria | mentorias tecnologicas vincular estudiantes con mentores voluntarios de la institucion. |
| 6 | Los datos ambientales disponibles son difíciles de interpretar. | Habitantes, investigadores y docentes | 4 | private | published | datos de calidad del aire visualizar lecturas ambientales en un tablero comprensible. datos ambiente | datos de calidad del aire visualizar lecturas ambientales en un tablero comprensible. |
| 8 | Las personas sin experiencia requieren apoyo para preparar sus postulaciones. | Personas en búsqueda de empleo | 2 | public | converted | orientacion laboral crear recursos y practicas guiadas para entrevistas laborales. empleo entrevistas | orientacion laboral crear recursos y practicas guiadas para entrevistas laborales. |

| Id | TitleNormalized | Revision | CreatedAt | UpdatedAt |
| --- | --- | --- | --- | --- |
| 4 | mentorias tecnologicas | 0 | 2026-10-21T14:00:00.000Z | 2026-10-25T14:00:00.000Z |
| 6 | datos de calidad del aire | 0 | 2026-10-22T14:00:00.000Z | 2026-10-22T14:00:00.000Z |
| 8 | orientacion laboral | 0 | 2026-10-23T14:00:00.000Z | 2026-10-28T14:00:00.000Z |

Los bloques anteriores representan las mismas filas, enlazadas por Id.

#### 8. InitiativeSkills (6 filas)

| InitiativeId | SkillId | Position |
| --- | --- | --- |
| 4 | 1 | 1 |
| 4 | 6 | 2 |
| 6 | 2 | 1 |
| 6 | 7 | 2 |
| 8 | 4 | 1 |
| 8 | 10 | 2 |

#### 9. InitiativeTags (5 filas)

| InitiativeId | Position | Value |
| --- | --- | --- |
| 4 | 1 | mentoría |
| 6 | 1 | datos |
| 6 | 2 | ambiente |
| 8 | 1 | empleo |
| 8 | 2 | entrevistas |

#### 10. ParticipationRequests (3 filas)

| Id | PublicId | InitiativeId | ApplicantId | OfferedSkillId | Message | Role | Availability |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 3 | 20000000-0000-4000-8000-000000000003 | 4 | 2 | 4 | Quiero preparar materiales para las sesiones de mentoría tecnológica. | Preparación de materiales | medium |
| 4 | 20000000-0000-4000-8000-000000000004 | 4 | 2 | 3 | Ahora puedo apoyar la investigación y seguimiento de cada mentoría. | Seguimiento de mentorías | medium |
| 5 | 20000000-0000-4000-8000-000000000005 | 8 | 3 | 3 | Puedo revisar materiales y realizar entrevistas de práctica con participantes. | Mentoría de entrevistas | low |

| Id | State | DecisionComment | CreatedAt | UpdatedAt | DecidedAt |
| --- | --- | --- | --- | --- | --- |
| 3 | rejected | El primer ciclo ya tenía cubierta esta función. | 2026-10-23T10:00:00.000Z | 2026-10-24T10:00:00.000Z | 2026-10-24T10:00:00.000Z |
| 4 | pending | NULL | 2026-10-26T10:00:00.000Z | 2026-10-26T10:00:00.000Z | NULL |
| 5 | accepted | NULL | 2026-10-25T11:00:00.000Z | 2026-10-26T11:00:00.000Z | 2026-10-26T11:00:00.000Z |

Los bloques anteriores representan las mismas filas, enlazadas por Id.

#### 11. Memberships (6 filas)

| Id | PublicId | InitiativeId | UserId | Role | State | JoinedAt | RetiredAt | SourceRequestId |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 4 | 30000000-0000-4000-8000-000000000004 | 4 | 1 | Propietaria | active | 2026-10-21T14:00:00.000Z | NULL | NULL |
| 6 | 30000000-0000-4000-8000-000000000006 | 6 | 1 | Propietaria | active | 2026-10-22T14:00:00.000Z | NULL | NULL |
| 8 | 30000000-0000-4000-8000-000000000008 | 8 | 1 | Propietaria | active | 2026-10-23T14:00:00.000Z | NULL | NULL |
| 10 | 30000000-0000-4000-8000-000000000010 | 8 | 5 | Coordinación de talleres | active | 2026-10-24T10:00:00.000Z | NULL | NULL |
| 11 | 30000000-0000-4000-8000-000000000011 | 8 | 3 | Mentoría de entrevistas | active | 2026-10-26T11:00:00.000Z | NULL | 5 |
| 12 | 30000000-0000-4000-8000-000000000012 | 8 | 2 | Investigación laboral | retired | 2026-10-24T12:00:00.000Z | 2026-10-27T12:00:00.000Z | NULL |

#### 12. MembershipEvents (7 filas)

| Id | PublicId | InitiativeId | UserId | MembershipId | Type | OccurredAt | ActorId | RequestId |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 4 | 40000000-0000-4000-8000-000000000004 | 4 | 1 | 4 | joined | 2026-10-21T14:00:00.000Z | 1 | NULL |
| 6 | 40000000-0000-4000-8000-000000000006 | 6 | 1 | 6 | joined | 2026-10-22T14:00:00.000Z | 1 | NULL |
| 8 | 40000000-0000-4000-8000-000000000008 | 8 | 1 | 8 | joined | 2026-10-23T14:00:00.000Z | 1 | NULL |
| 10 | 40000000-0000-4000-8000-000000000010 | 8 | 5 | 10 | joined | 2026-10-24T10:00:00.000Z | 1 | NULL |
| 11 | 40000000-0000-4000-8000-000000000011 | 8 | 3 | 11 | joined | 2026-10-26T11:00:00.000Z | 1 | 5 |
| 12 | 40000000-0000-4000-8000-000000000012 | 8 | 2 | 12 | joined | 2026-10-24T12:00:00.000Z | 1 | NULL |
| 13 | 40000000-0000-4000-8000-000000000013 | 8 | 2 | 12 | retired | 2026-10-27T12:00:00.000Z | 1 | NULL |

#### 13. Projects (1 filas)

| Id | PublicId | SourceInitiativeId | OwnerId | Name | Description | Objective | StartDate |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 50000000-0000-4000-8000-000000000001 | 8 | 1 | Programa de orientación laboral | Implementación de talleres y recursos para preparar postulaciones y entrevistas. | Acompañar a participantes durante la preparación de su búsqueda laboral. | 2026-11-01 |

| Id | EstimatedEndDate | State | RepositoryUrl | CreatedAt | UpdatedAt |
| --- | --- | --- | --- | --- | --- |
| 1 | 2027-02-28 | planning | NULL | 2026-10-25T16:00:00.000Z | 2026-10-25T16:00:00.000Z |

Los bloques anteriores representan las mismas filas, enlazadas por Id.

#### 14. ProjectTechnologies (2 filas)

| ProjectId | Position | Value |
| --- | --- | --- |
| 1 | 1 | React |
| 1 | 2 | Node.js |
