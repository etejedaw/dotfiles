---
description: Divide una tarea en bloques independientes, los desarrolla en paralelo en git worktrees con instancias de Claude en herdr y los integra en una rama
argument-hint: <tarea>
---

# Tarea

$ARGUMENTS

# Cómo vamos a trabajar

Eres el orquestador de esta tarea. Tú planificas, das las órdenes, resuelves dudas e integras; el desarrollo lo hacen instancias de Claude en paneles de herdr, una por bloque. Este comando sustituye, para los paneles de desarrollo, el límite de modelo y de número de workers del hook de orquestador.

## 1. Dividir la tarea en bloques

1. Analiza la tarea y el código del repo hasta entender qué hay que cambiar.
2. Divídela en bloques **no relacionados entre sí**: cada bloque debe poder desarrollarse sin esperar a otro y sin tocar los mismos archivos que otro. Si dos partes comparten archivos o una depende de la otra, van en el mismo bloque. Usa tantos bloques como haga falta, normalmente entre 2 y 4.
3. Dale a cada bloque un nombre corto y representativo de su contenido, en kebab-case (por ejemplo `auth-login-form`, no `bloque-a`).
4. Muéstrame la división: nombre de cada bloque, qué incluye, qué archivos o áreas toca y la rama base de la que saldrán (la rama actual, salvo que yo diga otra). Espera mi visto bueno antes de seguir.

## 2. Preparar los worktrees

1. Crea el directorio `.worktree` en la raíz del repo y añade `.worktree/` al `.gitignore` si no está ya.
2. Por cada bloque, crea un worktree con su propia rama: `git worktree add .worktree/<nombre> -b <nombre> <rama-base>`.

## 3. Abrir una instancia por worktree

Por cada worktree, abre un panel de herdr con su `--cwd` apuntando al worktree y arranca en él una instancia de Claude como indica el hook de orquestador, añadiendo `--permission-mode auto` a sus argumentos para que no se bloquee en avisos de permisos. Usa como nombre del agente el nombre del bloque.

## 4. Dirigir las instancias

1. Envía a cada instancia un prompt autocontenido: la tarea general en una frase, su bloque en detalle, los archivos que puede tocar y los que no, los criterios de terminado y que **no haga commits ni PRs**.
2. Indícales que sigan la guía de estilo oficial del framework y que usen las skills de diseño y UX cuando el bloque toque interfaz.
3. No pidas pasos que ya cubre un hook de pre-commit del repo (por ejemplo, formateo o lint con lint-staged): revisa `.husky/` y la config de `lint-staged` y deja en los criterios solo lo que el hook no corre, como typecheck y tests.
4. Revisa el resultado de cada instancia antes de darlo por terminado; si falta algo o no cumple los criterios, pídele que lo corrija.

## 5. Commits e integración

1. Cuando los bloques estén terminados, busca si existe una skill de commits en el repo (`.claude/skills`, `.claude/commands`) o global (`~/.claude/skills`, `~/.claude/commands`). Si existe, pide a cada instancia que la use para commitear su bloque (solo nómbrala, sin repetir sus reglas: la skill ya las trae) y espera a que confirme. Si no existe, pregúntame cómo quiero los commits y traslada esas reglas a cada instancia.
2. Crea una rama de integración desde la rama base, con un nombre que describa la tarea completa, y déjala activa en el checkout principal del repo (`git switch -c <rama-integracion> <rama-base>`).
3. Integra en ella la rama de cada worktree, una a una, con **rebase merge**, sin commits de merge. Por cada bloque, haz el rebase de su rama sobre la rama de integración desde su worktree (`git -C .worktree/<nombre> rebase <rama-integracion>`) y luego avanza la rama de integración en fast-forward (`git merge --ff-only <nombre>`). Tú resuelves los conflictos durante el rebase y las dependencias entre bloques (imports, tipos compartidos, rutas, paquetes, migraciones…), sin delegarlos en las instancias. Si en un conflicto no está claro qué versión conservar, pregúntame antes de decidir.

## 6. Pruebas

1. Ejecuta las pruebas según las instrucciones ya definidas en el proyecto (`CLAUDE.md`, `README.md` u otro `.md` de pruebas). Si no hay instrucciones, pregúntame cómo probar antes de inventarlas.
2. Si hay errores, corrígelos tú en la rama de integración (o delega los arreglos acotados), haz los commits con el mismo criterio del paso 5 y vuelve a probar hasta que todo pase.

## 7. Entrega en la rama de integración

1. Cuando todo pase, **detente**: no integres en `develop` ni en ninguna otra rama.
2. Comprueba que la rama de integración sigue activa en el checkout principal del repo, para que yo pueda probar desde la raíz.
3. Cierra los paneles de las instancias de desarrollo; a partir de aquí los arreglos se hacen en la rama de integración. No borres los worktrees ni sus ramas.
4. Avísame de que todos los worktrees están integrados en `<rama-integracion>` y dame un resumen con: qué se hizo en cada bloque, cómo resolviste los conflictos, qué errores aparecieron en las pruebas y cómo se corrigieron, y una lista concreta de **qué debo probar yo** a mano (flujos, pantallas, casos límite).

## 8. Esperar mi decisión

Quédate a la espera mientras pruebo. Según lo que te pida:

- **Correcciones**: hazlas en la rama de integración (o delega los arreglos acotados), commitea con el mismo criterio del paso 5, vuelve a ejecutar las pruebas y avísame de nuevo con lo que cambió. Repite hasta que dé el resultado por bueno.
- **Integrar en `develop`**: solo cuando yo lo pida. Usa el mismo rebase merge del paso 5: rebase de la rama de integración sobre `develop` y `git merge --ff-only <rama-integracion>`. Vuelve a ejecutar las pruebas si el rebase trajo cambios nuevos de `develop`. Si el repo no tiene `develop`, pregúntame en qué rama integrarla.
- **Limpiar**: borra los worktrees y sus ramas solo cuando yo lo pida.
