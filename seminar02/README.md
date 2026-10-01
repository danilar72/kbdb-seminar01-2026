# Проект: Ветропарк (ветроэнергетическая станция)

**Команда:** Данилов А.Д., Емельянов А.О.,Мухаметзянов А.А.
**Предметная область:** энергетика — ветропарк
**Объект наблюдения:** ветроэнергетическая установка (ВЭУ) и её узлы

## Сущности

| Сущность | Ключ | Атрибуты |
|---|---|---|
| wind_farm | id, code (UK) | name, region, capacity_mw, commissioned |
| turbine | id, code (UK «WT-01») | farm_id, kind_id, model, commissioned, x, y |
| turbine_kind | id, code (UK «V112») | manufacturer, rated_power_kw, rotor_diameter_m |
| component | id | turbine_id, parent_id, code, kind, name |
| component_kind | id, code (UK) | name |
| sensor | id | component_id, tag, kind_id, unit_of_measure |
| sensor_kind | id, code (UK «wind_speed») | name, unit_of_measure |
| telemetry | (ts, sensor_id) PK | value |
| event | id | turbine_id, ts, severity_id, message |
| severity | id, code (UK) | rank |
| engineer | id, tab_no (UK) | full_name, team |
| part | id, code (UK «BRG-6312») | name, manufacturer |
| maintenance | id | turbine_id, engineer_id, performed_at, work_type, notes |
| maintenance_part | (maintenance_id, part_id) PK | qty CHECK > 0 |
| turbine_spec | turbine_id PK | specs jsonb |
| turbine_location | (turbine_id, valid_from) PK | farm_id, valid_to |

## Связи

- wind_farm — turbine: 1:N, обязательна (каждая турбина принадлежит площадке)
- turbine — component: 1:N, обязательна (узлы, дерево parent_id)
- component — sensor: 1:N, необязательна (не на каждом узле датчик)
- sensor — telemetry: 1:N, обязательна (у датчика много измерений)
- turbine — event: 1:N, обязательна
- severity — event: 1:N, обязательна (уровень — справочник)
- turbine — maintenance: 1:N, обязательна
- engineer — maintenance: 1:N, обязательна
- maintenance — part: M:N через maintenance_part, атрибут связи — qty
- turbine — turbine_location: 1:N (история размещения)

## Что меняется во времени

- **Размещение турбины** между площадками — `turbine_location` с valid_from/valid_to.
- **Пороги срабатывания** датчиков — в `turbine_spec.specs` jsonb; для полноценной истории порогов отдельная таблица на будущее.
- **Ответственные инженеры** — история через `maintenance.engineer_id`.