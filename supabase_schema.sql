-- =========================================================
-- THE PONG GAME! - SUPABASE DATABASE SCHEMA & RLS POLICIES
-- Paste this script into your Supabase Project's SQL Editor
-- =========================================================

-- 1. Create profiles table
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  username text unique not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Create game_stats table
create table if not exists public.game_stats (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade unique not null,
  username text not null,
  high_score int default 0 not null,
  best_rally int default 0 not null,
  games_played int default 0 not null,
  wins int default 0 not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. Enable Row Level Security (RLS)
alter table public.profiles enable row level security;
alter table public.game_stats enable row level security;

-- 4. Policies for profiles
create policy "Public profiles are viewable by everyone"
  on public.profiles for select
  using (true);

create policy "Users can insert their own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- 5. Policies for game_stats (Leaderboard is public, users update their own stats)
create policy "Game stats are viewable by everyone"
  on public.game_stats for select
  using (true);

create policy "Users can insert their own stats"
  on public.game_stats for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own stats"
  on public.game_stats for update
  using (auth.uid() = user_id);

-- 6. Trigger to automatically create a profile and stats entry on signup
create or replace function public.handle_new_user()
returns trigger as $$
declare
  default_username text;
begin
  default_username := coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1));

  insert into public.profiles (id, username)
  values (new.id, default_username);

  insert into public.game_stats (user_id, username, high_score, best_rally, games_played, wins)
  values (new.id, default_username, 0, 0, 0, 0);

  return new;
end;
$$ language plpgsql security definer;

-- Drop trigger if exists and recreate
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
