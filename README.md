# Bakery App

A recipe management tool for cottage bakers — track ingredients, calculate CFIA-format nutrition facts and cost-per-portion, and manage a shared, community-editable ingredient database with private per-user pricing.

Built for a real client (a Toronto-based cottage bakery) on a $0 budget, using only free tiers.

## Status

**Live and in beta testing.** Every feature from the original project scope is built and working: ingredient management (manual entry, per-100g nutrition normalization, private per-user pricing, flexible units including cups/tbsp for solids and count-based ingredients like eggs, soft-delete archiving), recipe management with kitchen-unit conversion and duplicate-ingredient handling (rename or merge), live ingredient swapping with recalculated nutrition/cost, a printable CFIA-format nutrition label with an editable-values-before-printing flow and a print audit trail, and per-user inventory tracking with "not enough on hand" warnings on recipes.

**Not yet built:** barcode scanning, Open Food Facts / nutrient database integrations, a USDA/FDA label format, public sign-up (currently invite-only via manual account creation), and password reset.

**Note on the nutrition label:** it uses the correct CFIA nutrients, layout, and % Daily Value formulas, but does not yet implement Health Canada's official per-nutrient rounding rules. It's intended as a strong starting point, not a certified-compliant label — see the disclaimer printed on the label itself, and the AI Usage statement below.

## Stack

- **Frontend:** SvelteKit (static adapter, no server required)
- **Database/Auth:** Supabase (Postgres + Row Level Security)
- **Hosting:** Cloudflare Pages
- **Units:** all quantities stored internally in grams/milliliters; kitchen units (cups, tbsp, oz, etc.) converted at the UI layer

## Key design decisions

- **Ingredients are shared** across all users (a community nutrition database), while **recipes and ingredient costs are private per-user**, enforced via Supabase Row Level Security — not just application logic.
- **Nutrition is entered as printed on a label** (per serving) and converted to a canonical per-100g/ml basis for storage, so recipe scaling and cost math stay consistent regardless of package size.
- No AI features anywhere in the app itself — this is a hard requirement from the client.

## Local development

```bash
npm install
```

Create a `.env` file in the project root with your own Supabase project credentials:

```
PUBLIC_SUPABASE_URL=your_project_url
PUBLIC_SUPABASE_PUBLISHABLE_KEY=your_publishable_key
```

Set up your Supabase project's database by running [`supabase/schema.sql`](supabase/schema.sql) in the Supabase SQL Editor — one file, sets up the complete current schema (tables, RLS, grants, indexes) in one shot.

If you're curious how the schema got here, or want to understand the reasoning behind individual decisions, the full incremental history is preserved in [`supabase/sql/`](supabase/sql/) as 10 numbered migration files (`001` through `010`), each with comments explaining why that change was made. You don't need to run these for a fresh setup — `schema.sql` already reflects their combined end result.

In your Supabase project settings, make sure **"Automatically expose new tables"** is turned **off** — this project relies on explicit Row Level Security policies rather than blanket table exposure (see the comments in `001_initial_schema.sql` for why this also affects baseline grants).

Then start the dev server:

```bash
npm run dev
```

## Deployment

Deployed on **Cloudflare Pages**, connected directly to this GitHub repo.

- **Build command:** `npm run build`
- **Build output directory:** `build`
- **Environment variables:** the same `PUBLIC_SUPABASE_URL` / `PUBLIC_SUPABASE_PUBLISHABLE_KEY` as local dev, plus `NODE_VERSION=24` (see note below)
- When creating the project in Cloudflare's dashboard, make sure you're in the **Pages** flow specifically, not the newer unified "Workers" flow — the Workers path expects a `wrangler.toml` and isn't what this static site needs.

**Node version note:** `@zxing/browser` (installed for future barcode-scanning support, not yet used) has a dependency requiring Node 24+. Cloudflare's default build image is older, so `NODE_VERSION=24` must be set explicitly as an environment variable in the Pages project settings, or the build will fail during `npm install`.

**Filename case-sensitivity note:** this repo is developed primarily on Windows, which is case-insensitive for filenames — Cloudflare's Linux build environment is not. If a deploy fails with a "file not found" error for a file that clearly exists, check that the actual filename case matches its import statements exactly.

## AI Usage & Diligence Statement

This project was built collaboratively with Claude (Anthropic), used as a coding and architecture assistant throughout development. In the interest of transparency, especially given this codebase may be released publicly:

- **All code was written with Claude's assistance**, working step-by-step with a developer who is new to professional software development and used this project partly as a learning exercise.
- **Every piece of infrastructure — the GitHub repository, the Supabase project, the database schema, environment configuration — was set up and executed manually by the developer**, not automated by AI, specifically so the process could be understood and verified rather than treated as a black box.
- **Architectural decisions** (multi-user data model, Row Level Security design, unit conversion strategy, nutrition label data handling) were discussed and reasoned through collaboratively, with tradeoffs explained before implementation, rather than generated and accepted without review.
- **All code was tested manually** against a running instance of the app with real data before being considered complete.
- The developer takes full responsibility for the correctness, security, and behavior of this codebase. AI assistance does not substitute for review — bugs and design flaws found during development (including a couple of real ones) were caught through actual testing, not assumed away because "the AI wrote it."

If you're evaluating this codebase — as a contributor, an auditor, or simply out of curiosity — feel free to open an issue with questions about any part of the implementation or the reasoning behind it.
