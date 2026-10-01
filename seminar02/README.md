# Проект: Ветропарк (ветроэнергетическая станция)

**Команда:** Данилов А.Д., <добавьте остальных>
**Предметная область:** энергетика — ветропарк
**Объект наблюдения:** ветроэнергетическая установка (ВЭУ) и её узлы
**Схема в БД:** `project` (в базе `plant`, рядом с учебным датасетом в `public`)

## Сущности

| Сущность | PK / UK | Атрибуты | Источник |
|---|---|---|---|
| `wind_farm` | id PK, code UK | name, region, capacity_mw, commissioned | V1 |
| `turbine` | id PK, code UK | farm_id FK, kind_id FK, model, commissioned, created_at | V1 |
| `turbine_kind` | id PK, code UK | manufacturer, rated_power_kw, rotor_diameter_m | V1 |
| `component` | id PK, (turbine_id, code) UK | turbine_id FK, parent_id FK (self), kind FK, name | V1 |
| `component_kind` | id PK, code UK | name | V1 |
| `sensor` | id PK, (component_id, tag) UK | component_id FK, kind FK, unit_of_measure | V1 |
| `sensor_kind` | id PK, code UK | name, unit_of_measure | V1 |
| `telemetry` | (ts, sensor_id) PK | value | V1 |
| `event` | id PK | turbine_id FK, ts, severity_id FK, message | V1 |
| `severity` | id PK, code UK | rank (1–4) | V1 |
| `engineer` | id PK, tab_no UK | full_name, team | V1 |
| `part` | id PK, code UK | name, manufacturer | V1 |
| `maintenance` | id PK | turbine_id FK, engineer_id FK, performed_at, work_type, notes | V1 |
| `maintenance_part` | (maintenance_id, part_id) PK | qty (CHECK > 0) | V1 |
| `turbine_spec` | turbine_id PK, FK | specs (jsonb) | V2 |
| `turbine_location` | (turbine_id, valid_from) PK | farm_id FK, valid_to | V2 |

## Связи

- `wind_farm` — `turbine`: 1:N, обязательна (каждая турбина привязана к площадке).
- `turbine_kind` — `turbine`: 1:N, обязательна (у турбины есть модель из справочника).
- `turbine` — `component`: 1:N, обязательна (узлы турбины).
- `component` — `component`: 1:N через `parent_id` (дерево состава, самоссылка).
- `component_kind` — `component`: 1:N, обязательна.
- `component` — `sensor`: 1:N, необязательна (не на каждом узле есть датчик).
- `sensor_kind` — `sensor`: 1:N, обязательна.
- `sensor` — `telemetry`: 1:N, обязательна (у датчика много измерений).
- `turbine` — `event`: 1:N, обязательна.
- `severity` — `event`: 1:N, обязательна (уровень — справочник).
- `turbine` — `maintenance`: 1:N, обязательна.
- `engineer` — `maintenance`: 1:N, обязательна.
- `maintenance` — `part`: **M:N** через `maintenance_part`, атрибут связи — `qty`.
- `turbine` — `turbine_spec`: 1:1, необязательна (характеристики в jsonb).
- `turbine` — `turbine_location`: 1:N (история размещения турбины).
- `wind_farm` — `turbine_location`: 1:N.

## Что меняется во времени

- **Размещение турбины** — таблица `turbine_location` с `valid_from` / `valid_to`. `valid_to IS NULL` = действует сейчас. Гарантия «не более одной действующей записи на турбину» — частичный уникальный индекс `turbine_location_one_current` (в V2).
- **Пороги срабатывания датчиков** — в `turbine_spec.specs` (jsonb): `limits.temp.warning`, `limits.temp.alarm`.
- **Ответственные инженеры** — история через `maintenance.engineer_id` + `performed_at`.

## Условные обозначения ER-диаграммы

- `||` — ровно один;
- `o{` — ноль или много;
- `|{` — один или много.

M:N-связь `maintenance — part` разрешена через таблицу `maintenance_part` с составным первичным ключом и атрибутом `qty`.

## Как применить схему

### Способ 1 (основной, не требует Makefile)

```bash
docker compose exec postgres psql -U student -d plant -c "drop schema if exists project cascade;"

docker compose exec -T postgres psql -U student -d plant -v ON_ERROR_STOP=1 \
  < seminar02/migrations/V1__init.sql
docker compose exec -T postgres psql -U student -d plant -v ON_ERROR_STOP=1 \
  < seminar02/migrations/V2__spec_and_location.sql

docker compose exec postgres psql -U student -d plant -c "\dt project.*"
```

Ожидаемо — 16 таблиц в схеме `project`.

### Способ 2 (если в Makefile есть цель migrate)

```bash
make migrate
make migrate-reset
```

Если `make migrate` выдаёт `No rule to make target 'migrate'` — цели в вашем `Makefile` нет, используйте способ 1.

## ER-диаграмма

```mermaid
erDiagram
    wind_farm       ||--o{ turbine             : "размещает"
    turbine_kind    ||--o{ turbine             : "тип"
    turbine         ||--o{ component           : "состоит из"
    component       ||--o{ component           : "вложен в"
    component_kind  ||--o{ component           : "тип"
    component       ||--o{ sensor              : "несёт"
    sensor_kind     ||--o{ sensor              : "тип"
    sensor          ||--o{ telemetry           : "измеряет"
    turbine         ||--o{ event               : "порождает"
    severity        ||--o{ event               : "уровень"
    turbine         ||--o{ maintenance         : "обслуживается"
    engineer        ||--o{ maintenance         : "выполняет"
    maintenance     ||--o{ maintenance_part    : "расходует"
    part            ||--o{ maintenance_part    : "используется в"
    turbine         ||--|| turbine_spec        : "имеет характеристики"
    turbine         ||--o{ turbine_location    : "история размещения"
    wind_farm       ||--o{ turbine_location    : ""

    wind_farm {
        int  id PK
        text code UK
        text name
        text region
        numeric capacity_mw
        date commissioned
    }
    turbine {
        int  id PK
        text code UK "WT-01"
        int  farm_id FK
        int  kind_id FK
        text model
        date commissioned
        timestamptz created_at
    }
    turbine_kind {
        int  id PK
        text code UK "V112"
        text manufacturer
        int  rated_power_kw
        numeric rotor_diameter_m
    }
    component {
        int  id PK
        int  turbine_id FK
        int  parent_id FK
        text code
        text kind FK
        text name
    }
    component_kind {
        int  id PK
        text code UK
        text name
    }
    sensor {
        int  id PK
        int  component_id FK
        text tag
        text kind FK
        text unit_of_measure
    }
    sensor_kind {
        int  id PK
        text code UK
        text name
        text unit_of_measure
    }
    telemetry {
        timestamptz ts PK
        int         sensor_id PK, FK
        numeric     value
    }
    event {
        int         id PK
        int         turbine_id FK
        timestamptz ts
        int         severity_id FK
        text        message
    }
    severity {
        int  id PK
        text code UK
        int  rank
    }
    engineer {
        int  id PK
        text tab_no UK
        text full_name
        text team
    }
    part {
        int  id PK
        text code UK
        text name
        text manufacturer
    }
    maintenance {
        int         id PK
        int         turbine_id FK
        int         engineer_id FK
        timestamptz performed_at
        text        work_type
        text        notes
    }
    maintenance_part {
        int maintenance_id PK, FK
        int part_id        PK, FK
        int qty "check qty > 0"
    }
    turbine_spec {
        int  turbine_id PK, FK
        jsonb specs
    }
    turbine_location {
        int         turbine_id PK, FK
        timestamptz valid_from PK
        int         farm_id FK
        timestamptz valid_to "NULL = действует сейчас"
    }
```