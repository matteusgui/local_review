# Manual Film Entry & Reviews — MVP Design

Date: 2026-08-09

## Context

The product's local-first vision (see `CLAUDE.md`) means the MVP does not depend on any external film database/API — those cost money and were evaluated separately (TMDB, Watchmode, Trakt, OMDb, etc.) but deferred to a later, possibly paid/remote feature. For the MVP, users create their own film entries by hand and write reviews against them, entirely on-device, at zero cost. This spec covers that MVP feature: manual film entry plus reviews.

The codebase is currently the unmodified Flutter starter template (`lib/main.dart` is the counter-app demo) — this is a from-scratch design.

## Scope

In scope:
- Manually creating, editing, and deleting films (title, year, optional director, optional multi-genre, optional poster image).
- Writing, editing, and deleting reviews (rating, text, watch date) against a film, with multiple reviews per film supported (rewatches).
- A Reviews screen (reverse-chronological log) and a Films screen (library), navigable via responsive bottom-nav/side-nav shell.
- Local persistence via Drift (SQLite), including a poster image file copied into app storage.

Out of scope (explicitly deferred, not part of this feature):
- Any external film database/API integration (planned as a later, possibly remote/paid feature).
- Deduplication or canonicalization of films across separately-created entries.
- Data encryption (separate roadmap item per `CLAUDE.md`).
- Remote sync, freemium limits, self-hosting (separate roadmap items per `CLAUDE.md`).
- Web platform support (target platforms for this feature are Android, iOS, Linux, macOS, Windows).
- Integration/end-to-end tests.

## Data model

Three Drift tables (SQLite via the `drift` package):

**`Films`**
| column | type | notes |
|---|---|---|
| `id` | int, PK, autoincrement | |
| `title` | text | required |
| `year` | int | required; valid range 1888–(current year + 1) |
| `director` | text, nullable | optional |
| `posterPath` | text, nullable | path to the copied poster file under app documents dir; optional |

**`Genres`** — fixed lookup table seeded at first run (e.g. Action, Comedy, Drama, Horror, Sci-Fi, Documentary, Animation, Thriller, Romance, Fantasy — exact seed list finalized during implementation). Genre is a fixed list, not free text, to keep values consistent and filterable later.

**`FilmGenres`** — join table (`filmId`, `genreId`) implementing the film↔genre many-to-many relation (a film can have zero or more genres).

**`Reviews`**
| column | type | notes |
|---|---|---|
| `id` | int, PK, autoincrement | |
| `filmId` | int, FK → `Films.id` | required |
| `rating` | real | required; 0.5–5.0 in 0.5 increments |
| `text` | text | required |
| `watchDate` | date | required |
| `createdAt` | timestamp | auto-set on insert, used as a secondary sort key |

**Cascade rule**: deleting a film deletes all of its reviews (enforced at the repository level with a transaction, or via an `ON DELETE CASCADE` foreign key — decided during implementation). There is no scenario where a review points at a nonexistent film.

Films are independent entries — no deduplication logic. Two films can legitimately share the same title/year (e.g. remakes, or accidental duplicates); this is accepted MVP simplicity given there's no external source of truth to dedup against.

## Architecture

- **`lib/data/`** — `AppDatabase` (Drift, code-generated via `drift_dev`) defining the three tables above. A single instance is created at app startup and made available down the widget tree via a minimal `InheritedWidget`/`Provider` for dependency injection of the db instance — this is *not* a general state-management layer.
- **`lib/data/repositories/`** — `FilmRepository` and `ReviewRepository` wrap the generated Drift API: `watchAllReviews()`, `watchAllFilms()`, `createFilm(...)`, `createReview(...)`, `updateFilm(...)`, `updateReview(...)`, `deleteFilm(...)` (cascades), `deleteReview(...)`, `searchFilmsByTitle(...)`. Reads return Drift's reactive `Stream`s; writes return `Future`s. This thin layer keeps SQL/Drift specifics out of widget code and gives tests a seam to inject an in-memory database.
- **Image handling**: `image_picker` for gallery/camera selection; `path_provider` to resolve the app's documents directory. On save, the picked file is copied to `<app documents dir>/posters/<uuid>.jpg` and that path is stored in `Films.posterPath`. If `posterPath` is null or the referenced file is missing at render time, a placeholder icon is shown instead.
- **UI reactivity**: Screens consume repository `Stream`s directly via `StreamBuilder` (e.g. the Reviews list rebuilds automatically whenever a review is added/edited/deleted). No separate state-management package (Provider/Riverpod/Bloc/etc.) is introduced for this MVP — Drift's built-in streams already provide reactive updates, so an additional state layer would be redundant complexity.

## Screens & flow

**Navigation shell**: Two top-level destinations, **Reviews** and **Films**. Bottom navigation bar on narrow (phone) layouts; side navigation rail on wide (desktop/tablet) layouts, switched by a width breakpoint (e.g. `MediaQuery` width ≥ 600 — Flutter's standard adaptive-layout convention).

**Reviews screen** (home) — Reverse-chronological list of reviews, sorted by `watchDate` desc (ties broken by `createdAt` desc). Each row shows poster thumbnail (or placeholder), film title + year, star rating, watch date. Tapping a row opens Review Detail. FAB opens Add Review.

**Films screen** (library) — List of all films. Each row shows poster thumbnail/placeholder, title + year, director if present, genre chips if present. Tapping a row opens Film Detail. FAB opens Add Film (title/year required, director/genre/poster optional) — this creates a film with no review attached yet.

**Add/Edit Review** — A film picker (type-ahead search over existing films by title) with an inline "+ New film" expander offering the same fields as Add Film, for creating a film on the fly. Below that: rating (half-star selector, 0.5–5.0), review text, watch date picker. Saving writes the Review row (and the Film row too, if it was created inline).

**Review Detail** — Displays the associated film (title/year/poster) and the review's rating/text/date. Edit and Delete actions; Delete shows a confirmation dialog.

**Film Detail** — Displays film fields and the list of its reviews (tap → Review Detail). Edit Film and Delete Film actions; Delete Film shows a confirmation dialog stating how many reviews will be cascade-deleted.

**Add/Edit Film** — Shared form for both the Films-screen FAB and the inline expander in Add/Edit Review: title (required), year (required), director (optional), genres (optional, multi-select from the fixed list), poster image (optional, gallery/camera via `image_picker`).

## Error handling & validation

- **Required fields**: title (non-empty) and year (integer, 1888–current year+1) block saving a film; rating, review text, and watch date block saving a review. Inline field errors; save is blocked until valid.
- **No duplicate-film prevention** (see Data model above) — accepted MVP simplicity.
- **Image picker failures** (permission denied, user cancels): `posterPath` stays null, no error dialog, since the field is optional.
- **Delete confirmations**: both film and review deletion require confirming a dialog; the film-delete dialog states the cascade-deleted review count.
- **Storage errors** (disk full, poster file copy failure, etc.): surfaced via a snackbar rather than failing silently or crashing.

## Future: encryption

Not part of this MVP (encryption is a separate later roadmap phase per `CLAUDE.md`), but confirmed compatible so this doesn't get architected into a corner:

- Drift supports encrypted SQLite via **SQLite3MultipleCiphers** (Drift's current recommended approach, Drift 2.32.0+ / sqlite3 3.x) — same `NativeDatabase` already used here, no separate database package. Setup is a build-hook config change plus a passphrase passed via `PRAGMA key = '...'` in the `NativeDatabase.createInBackground()` setup callback.
- Covers exactly this feature's target platforms: Android, iOS, Linux, macOS, Windows.
- Because this MVP ships an **unencrypted** database first, turning encryption on later is a migration, not a flag flip: SQLite can't apply `PRAGMA key` to an already-unencrypted database. The migration path is `PRAGMA rekey` to produce an encrypted copy of the existing database. Whatever implements the encryption phase should plan for that migration step explicitly.

## Testing

- **Repository tests**: `FilmRepository`/`ReviewRepository` tested against Drift's in-memory `NativeDatabase.memory()` — covering create/update/delete, the film-delete cascade, and multi-genre association, without touching real device storage.
- **Widget tests**: Add Review form validation (blocked save on missing required fields), Reviews list rendering against a seeded in-memory database, and the film-delete confirmation flow. These replace the current placeholder `test/widget_test.dart` (the default Flutter counter-app smoke test).
- No integration/end-to-end tests planned for this MVP (see Scope).
