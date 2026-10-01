-- =====================================================================
--  V1. Начальная схема проекта «Ветропарк»
--  Семинар 2, команда: Данилов А.Д. и др.
-- =====================================================================
create schema if not exists project;
set search_path = project;

-- ---------------------------------------------------------------------
-- Справочники
-- ---------------------------------------------------------------------
create table turbine_kind (
    id              int  generated always as identity primary key,
    code            text not null unique,
    manufacturer    text not null,
    rated_power_kw  int  not null check (rated_power_kw > 0),
    rotor_diameter_m numeric(5,1) not null check (rotor_diameter_m > 0)
);
comment on table turbine_kind is 'Справочник моделей ВЭУ';

create table component_kind (
    id   int  generated always as identity primary key,
    code text not null unique,
    name text not null
);
comment on table component_kind is 'Справочник видов узлов: generator, gearbox, blade, tower';

create table sensor_kind (
    id              int  generated always as identity primary key,
    code            text not null unique,
    name            text not null,
    unit_of_measure text not null
);
comment on table sensor_kind is 'Справочник видов датчиков';

create table severity (
    id   int  generated always as identity primary key,
    code text not null unique
         check (code in ('info', 'warning', 'alarm', 'unplanned_stop')),
    rank int  not null unique check (rank between 1 and 4)
);
comment on table severity is 'Справочник уровней серьёзности событий';

-- ---------------------------------------------------------------------
-- Основные сущности
-- ---------------------------------------------------------------------
create table wind_farm (
    id            int  generated always as identity primary key,
    code          text not null unique,
    name          text not null,
    region        text not null,
    capacity_mw   numeric(8,1) not null check (capacity_mw > 0),
    commissioned  date not null
);
comment on table wind_farm is 'Площадка ветропарка';

create table turbine (
    id           int  generated always as identity primary key,
    code         text not null unique,
    farm_id      int  not null references wind_farm(id) on delete restrict,
    kind_id      int  not null references turbine_kind(id) on delete restrict,
    model        text not null,
    commissioned date not null,
    created_at   timestamptz not null default now()
);
comment on table turbine is 'Ветроэнергетическая установка (ВЭУ)';
comment on column turbine.code is 'Эксплуатационный номер, напр. WT-01';

create table component (
    id         int  generated always as identity primary key,
    turbine_id int  not null references turbine(id) on delete cascade,
    parent_id  int           references component(id) on delete cascade,
    code       text not null,
    kind       text not null references component_kind(code),
    name       text not null,
    unique (turbine_id, code),
    check (parent_id is null or parent_id <> id)
);
comment on table component is 'Состав ВЭУ: дерево узлов и деталей';

create table sensor (
    id              int  generated always as identity primary key,
    component_id    int  not null references component(id) on delete cascade,
    tag             text not null,
    kind            text not null references sensor_kind(code),
    unit_of_measure text not null,
    unique (component_id, tag)
);
comment on table sensor is 'Датчик, установленный на узле';

create table telemetry (
    ts        timestamptz not null,
    sensor_id int         not null references sensor(id) on delete cascade,
    value     numeric(12,3) not null,
    primary key (ts, sensor_id)
);
comment on table telemetry is 'Измерения датчиков; составной PK (ts, sensor_id)';

create table event (
    id          int  generated always as identity primary key,
    turbine_id  int  not null references turbine(id) on delete cascade,
    ts          timestamptz not null,
    severity_id int  not null references severity(id) on delete restrict,
    message     text not null
);
comment on table event is 'События и аварии на ВЭУ';

create table engineer (
    id        int  generated always as identity primary key,
    tab_no    text not null unique,
    full_name text not null,
    team      text
);
comment on table engineer is 'Справочник инженеров и ремонтных бригад';

create table part (
    id           int  generated always as identity primary key,
    code         text not null unique,
    name         text not null,
    manufacturer text
);
comment on table part is 'Справочник запчастей и расходных материалов';

create table maintenance (
    id           int  generated always as identity primary key,
    turbine_id   int  not null references turbine(id) on delete cascade,
    engineer_id  int  not null references engineer(id) on delete restrict,
    performed_at timestamptz not null,
    work_type    text not null
                 check (work_type in ('planned', 'unplanned', 'inspection')),
    notes        text
);
comment on table maintenance is 'Журнал работ и ремонтов';

create table maintenance_part (
    maintenance_id int not null references maintenance(id) on delete cascade,
    part_id        int not null references part(id) on delete restrict,
    qty            int not null check (qty > 0),
    primary key (maintenance_id, part_id)
);
comment on table maintenance_part is 'M:N между ремонтом и запчастями, атрибут qty';

-- ---------------------------------------------------------------------
-- Тестовые данные (3-5 строк на ключевые таблицы)
-- ---------------------------------------------------------------------
insert into turbine_kind (code, manufacturer, rated_power_kw, rotor_diameter_m) values
  ('V112',  'Vestas',   3450, 112.0),
  ('SWT-3', 'Siemens',  3600, 120.0);

insert into component_kind (code, name) values
  ('generator', 'Генератор'),
  ('gearbox',   'Редуктор'),
  ('blade',     'Лопасть'),
  ('tower',     'Башня');

insert into sensor_kind (code, name, unit_of_measure) values
  ('wind_speed',    'Скорость ветра',     'м/с'),
  ('rotor_speed',   'Обороты ротора',     'об/мин'),
  ('gen_temp',      'Температура генератора', '°C'),
  ('voltage',       'Напряжение',         'кВ'),
  ('power_kw',      'Активная мощность',  'кВт');

insert into severity (code, rank) values
  ('info',            1),
  ('warning',         2),
  ('alarm',           3),
  ('unplanned_stop',  4);

insert into wind_farm (code, name, region, capacity_mw, commissioned) values
  ('WF-NORTH', 'Северный ветропарк', 'Мурманская обл.', 45.0, '2023-06-01');

insert into turbine (code, farm_id, kind_id, model, commissioned) values
  ('WT-01', 1, 1, 'Vestas V112-3.45', '2023-06-15'),
  ('WT-02', 1, 2, 'Siemens SWT-3.6',  '2023-07-01');

insert into engineer (tab_no, full_name, team) values
  ('T-101', 'Иванов А.С.', 'бригада №1'),
  ('T-102', 'Петров В.К.', 'бригада №2');

insert into part (code, name, manufacturer) values
  ('BRG-6312', 'Подшипник 6312', 'SKF'),
  ('OIL-220',  'Масло редукторное', 'Shell');