-- ============================================================
-- 灯泡方块 · 云存档数据库（Supabase SQL Editor 执行一次）
-- 表结构：每个账号一行，data 为整份存档 JSON（金币/购买/常规记录/每日记录/历史/设置）
-- 存档结构 v2 关键字段：
--   data.coins                         金币
--   data.purchases[]                   购买记录 {style, price, at}
--   data.records.infinite{...}         常规挑战记录 {best_level, clear_count, total_seconds}
--   data.records.daily{...}            每日挑战记录 {clear_count, cleared_days[], total_seconds}
--   data.best_infinite / infinite_level  兼容字段（旧版）
--   data.history[]                     最近 20 局明细
--   data.meta{version, updated_at}     版本 + 更新时间（自动同步用）
-- ============================================================

create table if not exists public.saves (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

-- 行级安全：每个玩家只能读写自己那一行
alter table public.saves enable row level security;

drop policy if exists "saves_select_own" on public.saves;
create policy "saves_select_own" on public.saves
  for select using (auth.uid() = user_id);

drop policy if exists "saves_insert_own" on public.saves;
create policy "saves_insert_own" on public.saves
  for insert with check (auth.uid() = user_id);

drop policy if exists "saves_update_own" on public.saves;
create policy "saves_update_own" on public.saves
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

grant select, insert, update on public.saves to authenticated;

-- ============================================================
-- 可选：查看账号存档摘要（在 SQL Editor 里手动执行）
-- ============================================================
-- select
--   user_id,
--   data->>'coins' as coins,
--   data->'records'->'infinite' as infinite_records,
--   data->'records'->'daily' as daily_records,
--   jsonb_array_length(coalesce(data->'purchases', '[]'::jsonb)) as purchases,
--   updated_at
-- from public.saves
-- order by updated_at desc;

-- ============================================================
-- 可选：清除旧版遗留的「最高记录」字段（客户端会从 records / history 重建）
-- 注意：只想清某一个账号时，把 where 条件改成 user_id = '<你的 UUID>'
-- ============================================================
-- update public.saves
-- set data = data - 'best_infinite'
-- where data ? 'best_infinite';
