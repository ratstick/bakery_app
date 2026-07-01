# Bakery App

A recipe management tool for cottage bakers — track ingredients, calculate CFIA-format (and USDA) nutrition facts and cost-per-portion, and manage a shared, community-editable ingredient database with private per-user pricing.

Built for a real client (a Toronto-based cottage bakery) on a $0 budget, using only free tiers.

## Status

Actively in development. Core recipe and ingredient management is functional; barcode scanning, inventory tracking, and printable nutrition labels are still in progress.

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

Set up your Supabase project's database by running the SQL files in [`supabase/sql/`](supabase/sql/) against it, **in order**, using the Supabase SQL Editor:

1. `001_initial_schema.sql` — core tables, RLS, grants, indexes
2. `002_multi_user_rls.sql` — per-user ownership for recipes/inventory
3. `003_shared_ingredient_costs.sql` — private per-user ingredient pricing
4. `004_ingredient_brand_category_package.sql` — ingredient metadata
5. `005_label_serving_g.sql` — label-based nutrition entry support

In your Supabase project settings, make sure **"Automatically expose new tables"** is turned **off** — this project relies on explicit Row Level Security policies rather than blanket table exposure (see the comments in `001_initial_schema.sql` for why this also affects baseline grants).

Then start the dev server:

```bash
npm run dev
```

## AI Usage & Diligence Statement

This project was built collaboratively with Claude (Anthropic), used as a coding and architecture assistant throughout development. In the interest of transparency, especially given this codebase may be released publicly:

- **All code was written with Claude's assistance**, working step-by-step with a developer who is new to professional software development and used this project partly as a learning exercise.
- **Every piece of infrastructure — the GitHub repository, the Supabase project, the database schema, environment configuration — was set up and executed manually by the developer**, not automated by AI, specifically so the process could be understood and verified rather than treated as a black box.
- **Architectural decisions** (multi-user data model, Row Level Security design, unit conversion strategy, nutrition label data handling) were discussed and reasoned through collaboratively, with tradeoffs explained before implementation, rather than generated and accepted without review.
- **All code was tested manually** against a running instance of the app with real data before being considered complete.
- The developer takes full responsibility for the correctness, security, and behavior of this codebase. AI assistance does not substitute for review — bugs and design flaws found during development (including a couple of real ones) were caught through actual testing, not assumed away because "the AI wrote it."

If you're evaluating this codebase — as a contributor, an auditor, or simply out of curiosity — feel free to open an issue with questions about any part of the implementation or the reasoning behind it.
