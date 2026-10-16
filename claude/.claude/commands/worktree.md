---
description: Divide una tarea en bloques independientes, los desarrolla en paralelo en git worktrees con instancias de Claude en herdr y los integra en una rama
argument-hint: <tarea>
---

# Tarea

$ARGUMENTS

# Cómo vamos a trabajar

Eres el orquestador de esta tarea. Tú planificas, das las órdenes, resuelves dudas e integras; el desarrollo lo hacen instancias de Claude en paneles de herdr, una por bloque. Carga la skill `herdr` antes del primer comando de `herdr`. Este comando es autorización explícita para usar herdr y sustituye, para los paneles de desarrollo, el límite de modelo y de número de workers del hook de orquestador.

## 1. Dividir la tarea en bloques

1. Analiza la tarea y el código del repo hasta entender qué hay que cambiar.
2. Divídela en bloques **no relacionados entre sí**: cada bloque debe poder desarrollarse sin esperar a otro y sin tocar los mismos archivos que otro. Si dos partes comparten archivos o una depende de la otra, van en el mismo bloque. Usa tantos bloques como haga falta, normalmente entre 2 y 4.
3. Dale a cada bloque un nombre corto y representativo de su contenido, en kebab-case (por ejemplo `auth-login-form`, no `bloque-a`).
4. Muéstrame la división: nombre de cada bloque, qué incluye, qué archivos o áreas toca y la rama base de la que saldrán (la rama actual, salvo que yo diga otra). Espera mi visto bueno antes de seguir.

## 2. Preparar los worktrees

1. Crea el directorio `.worktree` en la raíz del repo y añade `.worktree/` al `.gitignore` si no está ya.
2. Por cada bloque, crea un worktree con su propia rama: `git worktree add .worktree/<nombre> -b <nombre> <rama-base>`.

## 3. Abrir una instancia por worktree

Por cada worktree, abre un panel de herdr con su `--cwd` apuntando al worktree y arranca en él una instancia de Claude. Sigue las reglas de geometría, variables de entorno (`CLAUDE_HERDR_WORKER=1`, `CLAUDE_CONFIG_DIR`) y carpeta de resultados del hook de orquestador. Usa como nombre del agente el nombre del bloque.

## 4. Dirigir las instancias

1. Envía a cada instancia un prompt autocontenido: la tarea general en una frase, su bloque en detalle, los archivos que puede tocar y los que no, los criterios de terminado y que **no haga commits ni PRs**.
2. Indícales que usen las skills y herramientas que apliquen a su bloque: context7 (`ctx7`) para la documentación actual y buenas prácticas de las librerías y frameworks del proyecto, la guía de estilo oficial del framework, y las skills de diseño y UX cuando el bloque toque interfaz.
3. Envía todos los prompts primero y luego espera a cada instancia.
4. Si una instancia tiene dudas, respóndele tú. Si la duda es una decisión que no puedes tomar con lo que sabes, pregúntame a mí y luego trasládale la respuesta. Yo solo hablo contigo, nunca con las instancias.
5. Revisa el resultado de cada instancia antes de darlo por terminado; si falta algo o no cumple los criterios, pídele que lo corrija.

## 5. Commits e integración

1. Tú no haces commits ni PRs en los worktrees. Cuando los bloques estén terminados, ejecuta `/commit` en cada instancia y espera a que confirme. Si la skill `commit` no existe, pregúntame antes por las reglas de commit.
2. Crea una rama de integración desde la rama base, con un nombre que describa la tarea completa.
3. Integra en ella la rama de cada worktree, una a una, con **rebase merge**, sin commits de merge: no hace falta que el historial muestre de qué rama vino cada bloque. Por cada bloque, haz el rebase de su rama sobre la rama de integración desde su worktree (`git -C .worktree/<nombre> rebase <rama-integracion>`) y luego avanza la rama de integración en fast-forward (`git merge --ff-only <nombre>`). Tú resuelves los conflictos durante el rebase y las dependencias entre bloques (imports, tipos compartidos, rutas, paquetes, migraciones…), sin delegarlos en las instancias. Si en un conflicto no está claro qué versión conservar, pregúntame antes de decidir.
4. Cierra los paneles de desarrollo cuando ya no los necesites.

## 6. Pruebas

1. Ejecuta las pruebas según las instrucciones ya definidas en el proyecto (`CLAUDE.md`, `README.md` u otro `.md` de pruebas). Si no hay instrucciones, pregúntame cómo probar antes de inventarlas.
2. Hazlo con una instancia de herdr con **haiku**, como indica el hook de orquestador, para ahorrar tokens: que ejecute las pruebas y te devuelva un resumen de los fallos.
3. Si hay errores, corrígelos tú en la rama de integración (o delega los arreglos acotados) y vuelve a probar hasta que todo pase.

## 7. Entrega

1. Cuando todo pase, integra la rama de integración en `develop` también con **rebase merge**: haz el rebase de la rama de integración sobre `develop` resolviendo tú los conflictos con el mismo criterio del paso 5, vuelve a ejecutar las pruebas si el rebase trajo cambios nuevos de `develop`, y luego avanza `develop` en fast-forward (`git merge --ff-only <rama-integracion>`). Si el repo no tiene `develop`, pregúntame en qué rama integrarla.
2. Cierra todos los paneles de herdr que hayas creado.
3. Dame un resumen final con: qué se hizo en cada bloque, cómo resolviste los conflictos, qué errores aparecieron en las pruebas y cómo se corrigieron, y una lista concreta de **qué debo probar yo** a mano (flujos, pantallas, casos límite).
4. No borres los worktrees ni sus ramas; pregúntame si quiero eliminarlos cuando haya validado el resultado.
