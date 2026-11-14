-- Dedicated Supabase project only. Apply as postgres. No client writes to events.
begin;
create table public.player_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 nickname text not null check (char_length(nickname) between 1 and 16)
);
alter table public.player_profiles enable row level security;
revoke all on public.player_profiles from anon, authenticated;
create function public.set_nickname(value text) returns void language sql security definer set search_path = '' as $$
 insert into public.player_profiles values (auth.uid(), trim(value))
 on conflict (user_id) do update set nickname = excluded.nickname;
$$;
revoke all on function public.set_nickname(text) from public, anon;
grant execute on function public.set_nickname(text) to authenticated;
create function public.my_profile() returns setof public.player_profiles language sql security definer set search_path = '' as $$
 select * from public.player_profiles where user_id = auth.uid();
$$;
revoke all on function public.my_profile() from public, anon;
grant execute on function public.my_profile() to authenticated;
create schema if not exists competitive;
revoke all on schema competitive from public, anon, authenticated;
create table competitive.sessions (
 id uuid primary key,
 mode text not null check (mode in ('campaign','endless')),
 closed boolean not null default false
);
create table competitive.participants (
 session_id uuid references competitive.sessions(id),
 user_id uuid references auth.users(id) on delete cascade,
 primary key(session_id,user_id)
);
create table competitive.events (
 session_id uuid not null,
 event_id text not null check (char_length(event_id) between 1 and 128),
 user_id uuid not null,
 metric text not null check (metric in ('kills','hordes','scrap')),
 amount integer not null check (amount > 0 and amount <= 100000 and (metric = 'scrap' or amount = 1)),
 primary key (session_id,event_id,user_id,metric),
 foreign key(session_id,user_id) references competitive.participants(session_id,user_id)
);
create unique index one_killer on competitive.events(session_id,event_id) where metric = 'kills';
alter table competitive.sessions enable row level security;
alter table competitive.participants enable row level security;
alter table competitive.events enable row level security;
-- Only the future authoritative simulator may receive this credential, never a player host.
grant usage on schema competitive to service_role;
grant select,insert,update on competitive.sessions to service_role;
grant select,insert on competitive.participants,competitive.events to service_role;
create function public.leaderboard(metric text, game_mode text, page_offset integer default 0)
returns table(position bigint,nickname text,score bigint)
language sql stable security definer set search_path = '' as $$
 with scores as (
 select e.user_id,sum(e.amount)::bigint score from competitive.events e
 join competitive.sessions s on s.id=e.session_id
 where e.metric=leaderboard.metric and s.mode=game_mode and s.closed
 and leaderboard.metric in ('kills','hordes','scrap') and game_mode in ('campaign','endless')
 group by e.user_id
 ), ranked as (
 select row_number() over(order by scores.score desc,scores.user_id) position,
 p.nickname,scores.score from scores join public.player_profiles p on p.user_id=scores.user_id
 ) select * from ranked order by position limit 25 offset greatest(0,least(page_offset,24975));
$$;
revoke all on function public.leaderboard(text,text,integer) from public;
grant execute on function public.leaderboard(text,text,integer) to anon, authenticated;
commit;
