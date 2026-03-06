-- ══════════════════════════════════════════════════════
--  NUTRICOACH — SUPABASE SCHEMA + RLS
--  Ejecutar en: Supabase > SQL Editor
-- ══════════════════════════════════════════════════════

-- EXTENSIONES
create extension if not exists "uuid-ossp";

-- ── PROFILES ────────────────────────────────────────────
-- Extiende auth.users con rol y relación coach-cliente
create table profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text unique not null,
  full_name  text not null default '',
  role       text not null check (role in ('coach','client')) default 'client',
  coach_id   uuid references profiles(id) on delete set null,
  avatar_url text,
  created_at timestamptz default now()
);

-- ── NUTRITION DB ─────────────────────────────────────────
-- Base de datos nutricional del coach (compartida con sus clientes)
create table nutrition_db (
  id         uuid primary key default uuid_generate_v4(),
  coach_id   uuid not null references profiles(id) on delete cascade,
  product    text not null,
  base       text not null default '100g',  -- '100g' | '100ml' | '1ud'
  kcal       numeric(8,2) default 0,
  prot       numeric(8,2) default 0,
  carb       numeric(8,2) default 0,
  fat        numeric(8,2) default 0,
  fib        numeric(8,2) default 0,
  unique(coach_id, product)
);

-- ── PRICES ──────────────────────────────────────────────
create table prices (
  id           uuid primary key default uuid_generate_v4(),
  coach_id     uuid not null references profiles(id) on delete cascade,
  product      text not null,
  merc         numeric(8,2),
  lidl         numeric(8,2),
  aldi         numeric(8,2),
  base_unit    text default '500g',
  updated_at   timestamptz default now(),
  unique(coach_id, product)
);

-- ── CLIENT DIETS ─────────────────────────────────────────
-- El coach edita el plan. El cliente solo puede leer.
create table client_diets (
  id          uuid primary key default uuid_generate_v4(),
  client_id   uuid not null references profiles(id) on delete cascade,
  coach_id    uuid not null references profiles(id) on delete cascade,
  diet_json   jsonb not null default '{}',  -- { LUNES: {desayuno:[...], ...}, ... }
  updated_at  timestamptz default now(),
  updated_by  uuid references profiles(id),
  unique(client_id)
);

-- ── ROUTINES ────────────────────────────────────────────
-- Estructura de rutinas: el coach las crea, el cliente las ve (no las edita)
create table routines (
  id            uuid primary key default uuid_generate_v4(),
  client_id     uuid not null references profiles(id) on delete cascade,
  coach_id      uuid not null references profiles(id) on delete cascade,
  name          text not null default 'Nueva rutina',
  muscles       text[] default '{}',
  exercises     jsonb default '[]',  -- [{id, name, note, sets:[{reps,weight,time}]}]
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- ── WEEK SCHEDULES ───────────────────────────────────────
create table week_schedules (
  id          uuid primary key default uuid_generate_v4(),
  client_id   uuid not null references profiles(id) on delete cascade,
  coach_id    uuid not null references profiles(id) on delete cascade,
  schedule    jsonb not null default '{}',  -- {LUN:'routine_id', MAR:'routine_id', ...}
  updated_at  timestamptz default now(),
  unique(client_id)
);

-- ── TRAINING LOGS ────────────────────────────────────────
-- El CLIENTE rellena los pesos, RPE, series completadas
-- Solo el cliente puede escribir aquí (y el coach puede leer)
create table training_logs (
  id           uuid primary key default uuid_generate_v4(),
  client_id    uuid not null references profiles(id) on delete cascade,
  routine_id   uuid not null references routines(id) on delete cascade,
  week_key     text not null,               -- '2025-W22'
  exercises    jsonb not null default '{}', -- {ex_id: {sets:[{weight,reps,done}], rpe, done}}
  completed    boolean default false,
  logged_at    timestamptz default now(),
  unique(client_id, routine_id, week_key)
);

-- ── EXERCISES LIBRARY ────────────────────────────────────
-- Librería de ejercicios con GIFs. Gestionada por el coach.
create table exercises_library (
  id           uuid primary key default uuid_generate_v4(),
  coach_id     uuid references profiles(id) on delete cascade, -- null = global
  name         text not null,
  name_search  text generated always as (lower(name)) stored,
  gif_url      text,
  muscles      text[] default '{}',
  tips         text default '',
  source       text default 'custom',  -- 'builtin' | 'exercisedb' | 'custom'
  created_at   timestamptz default now()
);

-- ── CLIENT STOCK ─────────────────────────────────────────
create table client_stock (
  id          uuid primary key default uuid_generate_v4(),
  client_id   uuid not null references profiles(id) on delete cascade,
  stock_json  jsonb not null default '{}',  -- {product: {qty, u}}
  updated_at  timestamptz default now(),
  unique(client_id)
);

-- ── CLIENT NOTES ─────────────────────────────────────────
create table client_notes (
  id              uuid primary key default uuid_generate_v4(),
  client_id       uuid not null references profiles(id) on delete cascade,
  personal_notes  text default '',
  coach_feedback  text default '',
  updated_at      timestamptz default now(),
  unique(client_id)
);

-- ══════════════════════════════════════════════════════
--  ROW LEVEL SECURITY (RLS)
-- ══════════════════════════════════════════════════════

alter table profiles          enable row level security;
alter table nutrition_db       enable row level security;
alter table prices             enable row level security;
alter table client_diets       enable row level security;
alter table routines           enable row level security;
alter table week_schedules     enable row level security;
alter table training_logs      enable row level security;
alter table exercises_library  enable row level security;
alter table client_stock       enable row level security;
alter table client_notes       enable row level security;

-- Helper: ¿el usuario autenticado es coach del cliente?
create or replace function is_my_client(client_uuid uuid)
returns boolean language sql security definer as $$
  select exists (
    select 1 from profiles
    where id = client_uuid and coach_id = auth.uid()
  );
$$;

-- Helper: ¿el usuario es coach?
create or replace function is_coach()
returns boolean language sql security definer as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'coach');
$$;

-- PROFILES ──
create policy "Leer perfil propio"      on profiles for select using (id = auth.uid());
create policy "Leer clientes (coach)"   on profiles for select using (coach_id = auth.uid());
create policy "Actualizar perfil propio" on profiles for update using (id = auth.uid());
create policy "Insertar perfil"         on profiles for insert with check (id = auth.uid());

-- NUTRITION DB ──
create policy "Coach lee su DB"    on nutrition_db for select using (coach_id = auth.uid());
create policy "Cliente lee DB"     on nutrition_db for select using (
  exists (select 1 from profiles where id = auth.uid() and coach_id = nutrition_db.coach_id)
);
create policy "Coach edita su DB"  on nutrition_db for all using (coach_id = auth.uid());

-- PRICES ──
create policy "Coach lee sus precios"  on prices for select using (coach_id = auth.uid());
create policy "Cliente lee precios"    on prices for select using (
  exists (select 1 from profiles where id = auth.uid() and coach_id = prices.coach_id)
);
create policy "Coach edita precios"    on prices for all using (coach_id = auth.uid());

-- CLIENT DIETS ──
create policy "Cliente lee su dieta"   on client_diets for select using (client_id = auth.uid());
create policy "Coach lee dieta"        on client_diets for select using (coach_id = auth.uid());
create policy "Coach edita dieta"      on client_diets for all using (coach_id = auth.uid());
-- ⚠ Cliente NO puede insertar/actualizar dieta

-- ROUTINES ──
create policy "Cliente lee sus rutinas"  on routines for select using (client_id = auth.uid());
create policy "Coach lee rutinas"        on routines for select using (coach_id = auth.uid());
create policy "Coach edita rutinas"      on routines for all using (coach_id = auth.uid());

-- WEEK SCHEDULES ──
create policy "Cliente lee horario"  on week_schedules for select using (client_id = auth.uid());
create policy "Coach gestiona"       on week_schedules for all using (coach_id = auth.uid());

-- TRAINING LOGS ──
-- El cliente escribe SUS logs; el coach puede leer los de sus clientes
create policy "Cliente lee y escribe logs"  on training_logs for all using (client_id = auth.uid());
create policy "Coach lee logs cliente"      on training_logs for select using (is_my_client(client_id));

-- EXERCISES LIBRARY ──
create policy "Todos leen ejercicios globales"  on exercises_library for select using (coach_id is null);
create policy "Coach lee su librería"           on exercises_library for select using (coach_id = auth.uid());
create policy "Cliente lee librería de su coach" on exercises_library for select using (
  exists (select 1 from profiles where id = auth.uid() and coach_id = exercises_library.coach_id)
);
create policy "Coach edita su librería"  on exercises_library for all using (coach_id = auth.uid());

-- CLIENT STOCK ──
create policy "Cliente gestiona stock"  on client_stock for all using (client_id = auth.uid());
create policy "Coach lee stock"         on client_stock for select using (is_my_client(client_id));

-- CLIENT NOTES ──
create policy "Cliente gestiona notas"    on client_notes for all using (client_id = auth.uid());
create policy "Coach lee/escribe notas"   on client_notes for all using (is_my_client(client_id));

-- ══════════════════════════════════════════════════════
--  DATOS INICIALES — Librería global de ejercicios (builtin)
-- ══════════════════════════════════════════════════════
insert into exercises_library (coach_id, name, gif_url, muscles, tips, source) values
(null,'Press banca plano','https://fitnessprogramer.com/wp-content/uploads/2021/02/Barbell-Bench-Press.gif',
  array['Pecho','Tríceps','Hombros'],'Codos a 45–75°. Baja controlado hasta el pecho. Pies en el suelo, arco natural.','builtin'),
(null,'Press inclinado mancuernas','https://fitnessprogramer.com/wp-content/uploads/2021/04/Incline-Dumbbell-Press.gif',
  array['Pecho superior','Tríceps'],'Banco a 30–45°. Core activo.','builtin'),
(null,'Aperturas en cable','https://fitnessprogramer.com/wp-content/uploads/2021/06/Cable-Crossover.gif',
  array['Pecho','Serratos'],'Codos ligeramente flexionados. Contracción firme en el centro.','builtin'),
(null,'Fondos en paralelas','https://fitnessprogramer.com/wp-content/uploads/2021/02/Dips.gif',
  array['Pecho','Tríceps'],'Inclínate para pecho. Baja hasta 90° en el codo.','builtin'),
(null,'Extensiones tríceps polea','https://fitnessprogramer.com/wp-content/uploads/2021/02/Tricep-Pushdown.gif',
  array['Tríceps'],'Codos pegados al cuerpo. Extiende completamente.','builtin'),
(null,'Sentadilla barra','https://fitnessprogramer.com/wp-content/uploads/2021/02/Barbell-Back-Squat.gif',
  array['Cuádriceps','Glúteos','Isquiotibiales','Core'],'Rodillas sobre los pies. Pecho erguido. Baja hasta paralelo.','builtin'),
(null,'Prensa 45°','https://fitnessprogramer.com/wp-content/uploads/2021/04/Leg-Press.gif',
  array['Cuádriceps','Glúteos'],'No bloquees las rodillas al extender.','builtin'),
(null,'Extensiones cuádriceps','https://fitnessprogramer.com/wp-content/uploads/2021/02/Leg-Extension.gif',
  array['Cuádriceps'],'Extiende completamente. Mantén 1s arriba.','builtin'),
(null,'Curl femoral tumbado','https://fitnessprogramer.com/wp-content/uploads/2021/02/Lying-Leg-Curl.gif',
  array['Isquiotibiales'],'Cadera pegada al banco. Baja controlado.','builtin'),
(null,'Elevaciones gemelos','https://fitnessprogramer.com/wp-content/uploads/2021/06/Standing-Calf-Raise.gif',
  array['Gemelos','Sóleo'],'Rango completo. Pausa arriba y abajo.','builtin'),
(null,'Dominadas','https://fitnessprogramer.com/wp-content/uploads/2021/02/Pull-up.gif',
  array['Espalda','Bíceps','Antebrazo'],'Lleva el pecho a la barra. Baja lento.','builtin'),
(null,'Remo barra','https://fitnessprogramer.com/wp-content/uploads/2021/02/Barbell-Bent-Over-Row.gif',
  array['Espalda media','Dorsales','Bíceps'],'Espalda recta, torso a 45°. Retrae escápulas.','builtin'),
(null,'Jalón al pecho','https://fitnessprogramer.com/wp-content/uploads/2021/02/Pulldown.gif',
  array['Dorsales','Bíceps'],'Barra al pecho alto. No balancees el torso.','builtin'),
(null,'Remo polea baja','https://fitnessprogramer.com/wp-content/uploads/2021/02/Seated-Cable-Row.gif',
  array['Espalda media','Romboides'],'Espalda erguida. Retrae escápulas al final.','builtin'),
(null,'Curl bíceps barra','https://fitnessprogramer.com/wp-content/uploads/2021/02/Barbell-Curl.gif',
  array['Bíceps','Braquial'],'Codos pegados. Sube a plena contracción. Sin impulso de cadera.','builtin'),
(null,'Curl martillo','https://fitnessprogramer.com/wp-content/uploads/2021/06/Hammer-Curl.gif',
  array['Bíceps','Braquial','Antebrazo'],'Pulgares arriba. Movimiento limpio.','builtin'),
(null,'Press militar barra','https://fitnessprogramer.com/wp-content/uploads/2021/02/Barbell-Overhead-Press.gif',
  array['Hombros','Tríceps','Trapecio'],'Empuja verticalmente. Core activo.','builtin'),
(null,'Elevaciones laterales','https://fitnessprogramer.com/wp-content/uploads/2021/02/Lateral-Raise.gif',
  array['Deltoides lateral'],'Codos flexionados. Sube a hombro. Baja lento.','builtin'),
(null,'Pájaros en máquina','https://fitnessprogramer.com/wp-content/uploads/2021/02/Reverse-Fly.gif',
  array['Deltoides posterior','Romboides'],'Retrae escápulas arriba.','builtin'),
(null,'Plancha','https://fitnessprogramer.com/wp-content/uploads/2021/02/Plank.gif',
  array['Core','Abdominales'],'Cuerpo recto. Abdomen activo. Respira continuamente.','builtin'),
(null,'Crunch con peso','https://fitnessprogramer.com/wp-content/uploads/2021/02/Crunch.gif',
  array['Abdominales'],'Contrae abdomen al subir. Baja controlado.','builtin'),
(null,'Hip thrust barra','https://fitnessprogramer.com/wp-content/uploads/2021/04/Barbell-Hip-Thrust.gif',
  array['Glúteos','Isquiotibiales'],'Hombros sobre banco. Empuja con glúteos, no espalda.','builtin'),
(null,'Peso muerto','https://fitnessprogramer.com/wp-content/uploads/2021/02/Barbell-Deadlift.gif',
  array['Espalda baja','Glúteos','Isquiotibiales','Trapecio'],'Espalda neutral. Empuja el suelo, no tires de la barra.','builtin'),
(null,'Face pull','https://fitnessprogramer.com/wp-content/uploads/2021/06/Face-Pull.gif',
  array['Deltoides posterior','Manguito rotador'],'Cuerda a la cara. Codos altos. Retrae escápulas.','builtin'),
(null,'Bulgarian split squat','https://fitnessprogramer.com/wp-content/uploads/2021/06/Dumbbell-Bulgarian-Split-Squat.gif',
  array['Cuádriceps','Glúteos'],'Rodilla trasera hacia el suelo. Torso ligeramente inclinado.','builtin');

-- ══════════════════════════════════════════════════════
--  FUNCIÓN: Auto-crear perfil al registrarse
-- ══════════════════════════════════════════════════════
create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'role', 'client')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ══════════════════════════════════════════════════════
--  STORAGE BUCKET para GIFs personalizados
-- ══════════════════════════════════════════════════════
-- Ejecutar en Storage > New Bucket:
-- Nombre: exercise-gifs
-- Public: true
-- Max file size: 10MB
-- Allowed MIME: image/gif, image/webp, video/mp4
