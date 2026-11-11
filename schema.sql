-- Formatura 2027 · PSP · esquema Supabase
-- Execute inteiro no SQL Editor de um projeto Supabase DEDICADO a esta aula.
-- Todas as tabelas têm RLS ligado e NENHUMA política: a chave pública (anon)
-- só alcança as funções (RPC) abaixo.

create table if not exists f27_rooms (
  code text primary key,
  pin_hash text not null,
  stage text not null default 'lobby',
  created_at timestamptz not null default now()
);

create table if not exists f27_students (
  id uuid primary key default gen_random_uuid(),
  room text not null references f27_rooms(code) on delete cascade,
  token uuid not null default gen_random_uuid(),
  nick text not null,
  ficha jsonb,
  frase_done boolean not null default false
);

create table if not exists f27_choices (
  student uuid not null references f27_students(id) on delete cascade,
  round int not null check (round between 1 and 3),
  phase int not null check (phase in (1,2)),
  place text,
  vinculo text,
  fora boolean not null default false,
  changed boolean,
  reason text,
  depois text,
  grau int check (grau between 1 and 5),
  primary key (student, round, phase)
);

create table if not exists f27_votes (
  student uuid not null references f27_students(id) on delete cascade,
  kind text not null check (kind in ('abertura','final')),
  opt text not null,
  primary key (student, kind)
);

create table if not exists f27_prio (
  student uuid primary key references f27_students(id) on delete cascade,
  items text[] not null
);

-- sem vínculo com aluno (anônima)
create table if not exists f27_frases (
  id bigint generated always as identity primary key,
  room text not null references f27_rooms(code) on delete cascade,
  texto text not null
);

alter table f27_rooms enable row level security;
alter table f27_students enable row level security;
alter table f27_choices enable row level security;
alter table f27_votes enable row level security;
alter table f27_prio enable row level security;
alter table f27_frases enable row level security;

-- ---------- utilidades ----------
create or replace function f27_stages() returns text[] language sql immutable as $$
  select array[
   'lobby','ficha','vote0',
   'r1_card','r1_c1','r1_video','r1_c2','r1_rev',
   'r2_card','r2_c1','r2_video','r2_c2','r2_rev',
   'r3_card','r3_c1','r3_video','r3_c2','r3_rev',
   'fin_guia','fin_fichas','fin_plen','fin_prio','fin_sintese',
   'fec_vote','fec_frase','fec_end']
$$;

create or replace function f27_hash(p_code text, p_pin text) returns text
language sql immutable as $$
  select encode(sha256(convert_to('f27|'||p_code||'|'||p_pin,'utf8')),'hex')
$$;

create or replace function f27_t(p_code text, p_pin text) returns void
language plpgsql security definer set search_path=public as $$
begin
  if not exists (select 1 from f27_rooms where code=p_code and pin_hash=f27_hash(p_code,p_pin)) then
    raise exception 'sala ou PIN inválidos';
  end if;
end $$;

create or replace function f27_s(p_student uuid, p_token uuid) returns text
language plpgsql security definer set search_path=public as $$
declare r text;
begin
  select room into r from f27_students where id=p_student and token=p_token;
  if r is null then raise exception 'aluno inválido'; end if;
  return r;
end $$;

create or replace function f27_stage_of(p_room text) returns text
language sql security definer set search_path=public as $$
  select stage from f27_rooms where code=p_room
$$;

-- ---------- público ----------
create or replace function f27_create_room(p_code text, p_pin text) returns void
language plpgsql security definer set search_path=public as $$
begin
  p_code := upper(trim(p_code));
  if length(p_code) < 3 or length(p_pin) < 4 then raise exception 'código ≥3 e PIN ≥4 caracteres'; end if;
  if exists (select 1 from f27_rooms where code=p_code) then raise exception 'esse código já existe'; end if;
  insert into f27_rooms(code,pin_hash) values (p_code, f27_hash(p_code,p_pin));
end $$;

create or replace function f27_state(p_code text) returns jsonb
language sql security definer set search_path=public as $$
  select jsonb_build_object('stage', stage,
     'alunos', (select count(*) from f27_students where room=upper(p_code)))
  from f27_rooms where code=upper(p_code)
$$;

create or replace function f27_join(p_code text, p_nick text) returns jsonb
language plpgsql security definer set search_path=public as $$
declare s f27_students;
begin
  p_code := upper(trim(p_code));
  if not exists (select 1 from f27_rooms where code=p_code) then raise exception 'sala não encontrada'; end if;
  p_nick := left(trim(p_nick), 30);
  if length(p_nick) < 1 then raise exception 'apelido vazio'; end if;
  if exists (select 1 from f27_students where room=p_code and lower(nick)=lower(p_nick)) then
    raise exception 'apelido já usado nesta sala';
  end if;
  insert into f27_students(room,nick) values (p_code,p_nick) returning * into s;
  return jsonb_build_object('id',s.id,'token',s.token,'room',p_code);
end $$;

-- estado privado do próprio aluno
create or replace function f27_me(p_student uuid, p_token uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
declare r text := f27_s(p_student,p_token); out jsonb;
begin
  select jsonb_build_object(
    'stage', f27_stage_of(r),
    'alunos', (select count(*) from f27_students where room=r),
    'ficha', (select ficha from f27_students where id=p_student),
    'frase_done', (select frase_done from f27_students where id=p_student),
    'choices', coalesce((select jsonb_agg(to_jsonb(c) - 'student') from f27_choices c where student=p_student),'[]'::jsonb),
    'votes', coalesce((select jsonb_object_agg(kind,opt) from f27_votes where student=p_student),'{}'::jsonb),
    'prio', (select items from f27_prio where student=p_student)
  ) into out;
  return out;
end $$;

create or replace function f27_save_ficha(p_student uuid, p_token uuid, p_ficha jsonb) returns void
language plpgsql security definer set search_path=public as $$
declare r text := f27_s(p_student,p_token);
begin
  if array_position(f27_stages(), f27_stage_of(r)) < 2 then raise exception 'a ficha ainda não foi liberada'; end if;
  update f27_students set ficha=p_ficha where id=p_student;
end $$;

create or replace function f27_choose(
  p_student uuid, p_token uuid, p_round int, p_phase int,
  p_place text, p_vinculo text, p_fora boolean,
  p_changed boolean, p_reason text, p_depois text, p_grau int) returns void
language plpgsql security definer set search_path=public as $$
declare r text := f27_s(p_student,p_token);
begin
  if f27_stage_of(r) <> 'r'||p_round||'_c'||p_phase then
    raise exception 'esta escolha não está aberta';
  end if;
  insert into f27_choices(student,round,phase,place,vinculo,fora,changed,reason,depois,grau)
  values (p_student,p_round,p_phase,p_place,p_vinculo,coalesce(p_fora,false),p_changed,p_reason,p_depois,p_grau)
  on conflict (student,round,phase) do update set
    place=excluded.place, vinculo=excluded.vinculo, fora=excluded.fora,
    changed=excluded.changed, reason=excluded.reason,
    depois=coalesce(excluded.depois, f27_choices.depois), grau=excluded.grau;
end $$;

create or replace function f27_vote(p_student uuid, p_token uuid, p_kind text, p_opt text) returns void
language plpgsql security definer set search_path=public as $$
declare r text := f27_s(p_student,p_token); st text := f27_stage_of(r);
begin
  if not ((p_kind='abertura' and st='vote0') or (p_kind='final' and st='fec_vote')) then
    raise exception 'votação fechada';
  end if;
  insert into f27_votes values (p_student,p_kind,p_opt)
  on conflict (student,kind) do update set opt=excluded.opt;
end $$;

create or replace function f27_prio_set(p_student uuid, p_token uuid, p_items text[]) returns void
language plpgsql security definer set search_path=public as $$
declare r text := f27_s(p_student,p_token);
begin
  if f27_stage_of(r) <> 'fin_prio' then raise exception 'votação fechada'; end if;
  if coalesce(array_length(p_items,1),0) <> 3 then raise exception 'escolha exatamente 3'; end if;
  insert into f27_prio values (p_student,p_items)
  on conflict (student) do update set items=excluded.items;
end $$;

-- frase anônima: grava o texto sem aluno nem horário
create or replace function f27_frase(p_student uuid, p_token uuid, p_texto text) returns void
language plpgsql security definer set search_path=public as $$
declare r text := f27_s(p_student,p_token);
begin
  if f27_stage_of(r) <> 'fec_frase' then raise exception 'envio fechado'; end if;
  if exists (select 1 from f27_students where id=p_student and frase_done) then raise exception 'frase já enviada'; end if;
  if length(trim(p_texto)) = 0 then raise exception 'frase vazia'; end if;
  insert into f27_frases(room,texto) values (r,left(trim(p_texto),400));
  update f27_students set frase_done=true where id=p_student;
end $$;

-- ---------- professor ----------
create or replace function f27_t_set_stage(p_code text, p_pin text, p_stage text) returns void
language plpgsql security definer set search_path=public as $$
begin
  perform f27_t(p_code,p_pin);
  if not (p_stage = any(f27_stages())) then raise exception 'etapa inválida'; end if;
  update f27_rooms set stage=p_stage where code=p_code;
end $$;

create or replace function f27_t_status(p_code text, p_pin text) returns jsonb
language plpgsql security definer set search_path=public as $$
declare st text; n int; resp int;
begin
  perform f27_t(p_code,p_pin);
  select stage into st from f27_rooms where code=p_code;
  select count(*) into n from f27_students where room=p_code;
  resp := case
    when st='ficha' then (select count(*) from f27_students where room=p_code and ficha is not null)
    when st='vote0' then (select count(*) from f27_votes v join f27_students s on s.id=v.student where s.room=p_code and kind='abertura')
    when st='fec_vote' then (select count(*) from f27_votes v join f27_students s on s.id=v.student where s.room=p_code and kind='final')
    when st='fin_prio' then (select count(*) from f27_prio v join f27_students s on s.id=v.student where s.room=p_code)
    when st='fec_frase' then (select count(*) from f27_students where room=p_code and frase_done)
    when st ~ '^r[123]_c[12]$' then
      (select count(*) from f27_choices c join f27_students s on s.id=c.student
        where s.room=p_code and c.round=substr(st,2,1)::int and c.phase=substr(st,5,1)::int)
    else null end;
  return jsonb_build_object('stage',st,'alunos',n,'responderam',resp);
end $$;

-- revelação: pares anônimos, em ordem aleatória, sem id de aluno
create or replace function f27_t_reveal(p_code text, p_pin text, p_round int) returns jsonb
language plpgsql security definer set search_path=public as $$
declare out jsonb;
begin
  perform f27_t(p_code,p_pin);
  select coalesce(jsonb_agg(row order by random()),'[]'::jsonb) into out from (
    select jsonb_build_object(
      'p1',a.place,'v1',a.vinculo,'f1',a.fora,'g1',a.grau,'d1',a.depois,
      'p2',b.place,'v2',b.vinculo,'f2',b.fora,'g2',b.grau,
      'changed',b.changed,'reason',b.reason) as row
    from f27_students s
    join f27_choices a on a.student=s.id and a.round=p_round and a.phase=1
    left join f27_choices b on b.student=s.id and b.round=p_round and b.phase=2
    where s.room=p_code) q;
  return jsonb_build_object('pairs',out,'alunos',(select count(*) from f27_students where room=p_code));
end $$;

create or replace function f27_t_fichas(p_code text, p_pin text) returns jsonb
language plpgsql security definer set search_path=public as $$
begin
  perform f27_t(p_code,p_pin);
  return jsonb_build_object(
    'n', (select count(*) from f27_students where room=p_code and ficha is not null),
    'area', coalesce((select jsonb_object_agg(k,c) from (select ficha->>'area' k, count(*) c from f27_students where room=p_code and ficha is not null group by 1) x),'{}'),
    'valoriza', coalesce((select jsonb_object_agg(k,c) from (select jsonb_array_elements_text(ficha->'valoriza') k, count(*) c from f27_students where room=p_code and ficha is not null group by 1) x),'{}'),
    'pesa', coalesce((select jsonb_object_agg(k,c) from (select jsonb_array_elements_text(ficha->'pesa') k, count(*) c from f27_students where room=p_code and ficha is not null group by 1) x),'{}'),
    'jornada', coalesce((select jsonb_object_agg(k,c) from (select ficha->>'jornada' k, count(*) c from f27_students where room=p_code and ficha is not null group by 1) x),'{}'),
    'divida_sim', (select count(*) from f27_students where room=p_code and ficha->>'divida'='sim'),
    'teme', coalesce((select jsonb_agg(t order by random()) from (select ficha->>'teme' t from f27_students where room=p_code and coalesce(trim(ficha->>'teme'),'')<>'') x),'[]')
  );
end $$;

create or replace function f27_t_results(p_code text, p_pin text) returns jsonb
language plpgsql security definer set search_path=public as $$
begin
  perform f27_t(p_code,p_pin);
  return jsonb_build_object(
    'abertura', coalesce((select jsonb_object_agg(opt,c) from (select opt,count(*) c from f27_votes v join f27_students s on s.id=v.student where s.room=p_code and kind='abertura' group by 1) x),'{}'),
    'final', coalesce((select jsonb_object_agg(opt,c) from (select opt,count(*) c from f27_votes v join f27_students s on s.id=v.student where s.room=p_code and kind='final' group by 1) x),'{}'),
    'prio', coalesce((select jsonb_object_agg(k,c) from (select unnest(items) k, count(*) c from f27_prio p join f27_students s on s.id=p.student where s.room=p_code group by 1) x),'{}'),
    'frases', coalesce((select jsonb_agg(texto order by random()) from f27_frases where room=p_code),'[]')
  );
end $$;

-- CSV: sem apelido, sem ficha, sem id de aluno (aluno_n é só um número aleatório da linha)
create or replace function f27_t_export(p_code text, p_pin text) returns jsonb
language plpgsql security definer set search_path=public as $$
begin
  perform f27_t(p_code,p_pin);
  return coalesce((select jsonb_agg(row order by random()) from (
    select jsonb_build_object('rodada',c.round,'momento',c.phase,'lugar',c.place,'vinculo',c.vinculo,
      'fora_da_regra',c.fora,'mudou',c.changed,'o_que_pesou',c.reason,'depois_dos_2_anos',c.depois,'grau',c.grau) row
    from f27_choices c join f27_students s on s.id=c.student where s.room=p_code) q),'[]'::jsonb);
end $$;

create or replace function f27_t_wipe(p_code text, p_pin text) returns void
language plpgsql security definer set search_path=public as $$
begin
  perform f27_t(p_code,p_pin);
  delete from f27_rooms where code=p_code;  -- cascata apaga alunos, escolhas, votos, frases
end $$;

-- permissões: só as funções públicas (anon). Utilitárias internas ficam fechadas.
revoke all on function
  f27_stages(), f27_hash(text,text), f27_t(text,text), f27_s(uuid,uuid), f27_stage_of(text)
  from public, anon, authenticated;
grant execute on function
  f27_create_room(text,text), f27_state(text), f27_join(text,text),
  f27_me(uuid,uuid), f27_save_ficha(uuid,uuid,jsonb),
  f27_choose(uuid,uuid,int,int,text,text,boolean,boolean,text,text,int),
  f27_vote(uuid,uuid,text,text), f27_prio_set(uuid,uuid,text[]), f27_frase(uuid,uuid,text),
  f27_t_set_stage(text,text,text), f27_t_status(text,text), f27_t_reveal(text,text,int),
  f27_t_fichas(text,text), f27_t_results(text,text), f27_t_export(text,text), f27_t_wipe(text,text)
  to anon, authenticated;
