# Investigación breve — Entity Framework Core

**Universidad CENFOTEC · SOFT-12 · Tarea 3, Parte B**  
Daniel Campos Sánchez y Francisco José Torres Sandoval.

## 1. Datos relacionados: Select, Include y AsNoTracking

`Select` proyecta la consulta en la forma que necesita el resultado: permite seleccionar columnas de una entidad y de sus relaciones para construir un DTO, sin recuperar información innecesaria. `Include` realiza carga anticipada de las entidades relacionadas mediante sus propiedades de navegación; resulta útil cuando se requiere un agregado de entidades completo, por ejemplo, al modificar una iniciativa y sus competencias. Al incluir varias colecciones conviene considerar consultas divididas para evitar multiplicar filas innecesariamente. [1, 2]

En `GET /api/initiatives?page=1&size=2`, conviene proyectar mediante `Select` el título, resumen, propietario, categoría, competencias de `InitiativeSkills`, etiquetas y conteo de membresías activas. No es necesario cargar hashes, correos ni la descripción completa. En cambio, para editar una iniciativa se podrían cargar la entidad y sus `InitiativeSkills` con `Include` para comparar y actualizar asociaciones.

`AsNoTracking` evita registrar las entidades recuperadas en el rastreador de cambios del contexto. Es apropiado para lecturas que no se modificarán; si la proyección contiene únicamente valores o DTO y ninguna entidad, EF Core no realiza seguimiento de entidades de todas formas. Para actualizar entidades con `SaveChanges`, el seguimiento habitual permite detectar sus modificaciones. [3]

## 2. Muchos a muchos con datos propios

Una relación N:M siempre requiere dos llaves foráneas en una tabla intermedia. Cuando esta solo representa la asociación y no tiene atributos propios, EF Core puede administrar la tabla sin que el desarrollador declare una clase de unión explícita, mediante navegaciones directas (*skip navigations*). Por ejemplo, una versión simplificada de Initiative–Skill sin orden ni atributos propios únicamente necesitaría `InitiativeId` y `SkillId`. [4]

En nuestro modelo, `UserSkills` necesita una entidad intermedia explícita: Ana posee Diseño en nivel `advanced` y Facilitación en `intermediate`. El nivel no pertenece exclusivamente al usuario ni a la competencia, sino a la combinación. La PK compuesta `(UserId, SkillId)` evita duplicados. También se conserva `Position` para reproducir el orden del arreglo. Lo mismo justifica modelar `InitiativeSkills` si se exige preservar su posición.

`Memberships` también es una entidad explícita: guarda rol, estado, fechas y solicitud de origen, y permite conservar varios periodos históricos de una misma pareja usuario–iniciativa.

