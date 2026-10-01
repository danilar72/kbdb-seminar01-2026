-- =====================================================================
--  V2. Расширение: jsonb-характеристики и история размещения ВЭУ
--  Закрывает замечания ревью:
--    1. Не хватает гибкого места для технических характеристик.
--    2. Не хранится история перемещения турбины между площадками.
--  V1 не редактируется — правило миграций.
-- =====================================================================
set search_path = project;

-- 1. Гибкие характеристики ВЭУ в jsonb
create table turbine_spec (
    turbine_id int primary key references turbine(id) on delete cascade,
    specs      jsonb not null default '{}'::jsonb,
    check (jsonb_typeof(specs) = 'object')
);
comment on table turbine_spec is 'Технические характеристики ВЭУ в jsonb';

insert into turbine_spec (turbine_id, specs) values
  (1, '{"manufacturer":"Vestas","power_kw":3450,"bearings":["6312","6312"],"limits":{"temp":{"warning":80,"alarm":90}}}'),
  (2, '{"manufacturer":"Siemens","power_kw":3600,"bearings":["6320"],"limits":{"temp":{"warning":85}}}');

-- 2. История размещения турбины между площадками
create table turbine_location (
    turbine_id int         not null references turbine(id) on delete cascade,
    valid_from timestamptz not null,
    farm_id    int         not null references wind_farm(id) on delete restrict,
    valid_to   timestamptz,
    primary key (turbine_id, valid_from),
    check (valid_to is null or valid_to > valid_from)
);
comment on table turbine_location is
  'История размещения ВЭУ; valid_to NULL = действует сейчас';

insert into turbine_location (turbine_id, valid_from, farm_id, valid_to) values
  (1, '2023-06-15 00:00:00+03', 1, null),
  (2, '2023-07-01 00:00:00+03', 1, null);

-- 3. Индексы для аналитических запросов
create index telemetry_sensor_ts_idx on telemetry (sensor_id, ts desc);
create index event_turbine_ts_idx    on event    (turbine_id, ts desc);
create index maintenance_turbine_idx on maintenance (turbine_id, performed_at desc);