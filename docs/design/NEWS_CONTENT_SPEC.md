# SweetTime Stories And News Content Contract

Status: implementation contract approved by the owner on 2026-07-15.

## Product model

SweetTime has three related but distinct surfaces:

1. **Home stories** — a horizontally scrollable rail of at most 30 active
   stories. A story may contain text, an image, an MP4 video, or media plus
   text. Pinned stories come first, then newer stories. A story may be
   evergreen or automatically expire.
2. **Story collections** — editable round categories at the top of `/news`.
   Examples are employees, videos, company news, and reviews. A collection has
   a localized name and an editable image cover; both remain editable after
   creation. It has no small hard item limit and the UI must remain lazy and
   usable with at least 40 stories per collection. This is a capacity
   guarantee, not a requirement to upload 40 items before publishing.
3. **News feed posts** — permanent scrollable publications below the collection
   rail. A post has localized title, summary and full body, an automatic
   publication date, and optional image or MP4 video. Opening a post presents
   the full content in a bottom sheet; Android back closes it and returns to the
   feed.

The Home section title is actionable and includes an accessible forward arrow
to `/news`. Android/system back from `/news` or a collection returns through
normal navigation history.

## Visibility and ordering

- Public endpoints never expose drafts, future content or expired stories.
- Story active interval is `publishedAt <= now < expiresAt`; `expiresAt=null`
  means evergreen.
- Expiry hides a story but does not physically delete it or its media.
- Home stories: `showOnHome=true`, pinned first, then `publishedAt` descending,
  then stable ID; maximum 30.
- Stories inside a collection: pinned first, then `publishedAt` descending,
  then stable ID. Rendering is lazy; no video is initialized off-screen.
- Collections: `sortOrder` ascending, then stable ID.
- Feed posts: `publishedAt` descending, then stable ID.
- Empty collections may be saved as drafts but are omitted from the public
  collection rail until they contain public stories.

## Localized content

All owner-authored visible text uses stable objects `{ru, ky, en}`. Admin must
show all three languages. Russian is the compatibility fallback for legacy
rows, but publishing UI must report missing KY/EN instead of silently claiming
translation completeness.

## Entities

### Story (backward-compatible `news` resource)

- stable `id`, tenant `companyId`
- optional `collectionId`
- localized `title`, `body`, `badge`
- `accentColor`, fallback `visual`
- `isPublished`, `showOnHome`, `isPinned`, `sortOrder`
- ISO `publishedAt`, nullable `expiresAt`
- `mediaType`: `none | image | video`
- nullable server-owned `mediaUrl`; legacy `imageUrl` remains a read alias
- optional localized `ctaLabel` and allowlisted in-app `ctaRoute`

### StoryCollection

- stable `id`, tenant `companyId`
- localized editable `name`
- optional localized `description`
- editable image-only `coverImageUrl`
- `accentColor`, fallback `visual`, `sortOrder`, `isPublished`

### NewsPost

- stable `id`, tenant `companyId`
- localized `title`, `summary`, `body`
- `isPublished`, automatic/owner-adjustable ISO `publishedAt`
- `mediaType`: `none | image | video`
- nullable server-owned `mediaUrl`

## Media

- Images: JPEG, PNG or WebP; decoded and re-encoded by Pillow to sanitized
  WebP variants, metadata removed, maximum source size 10 MiB and 25 MP.
- Collection covers are image-only.
- Video: MP4 only for the first production slice, maximum 50 MiB. The backend
  validates MIME and ISO-BMFF `ftyp` signature, writes a controlled `.mp4`
  storage key and never trusts a client path or URL. No transcoding claim is
  made: admin explains that H.264/AAC MP4 is required.
- Files live below `/srv/sweetime/media/tenants/<company>/...`; PostgreSQL owns
  metadata. Replacement is transactional and old files are removed after DB
  commit. Entity deletion also removes owned media metadata/files.
- Browser/mobile clients receive HTTPS URLs only. Home/feed never initialize a
  video player; video initializes only for the current opened story/post and is
  disposed on page change/back/lifecycle pause.
- Deployment proxies accept at most 52 MiB request bodies. Public media keeps
  immutable caching; MP4 byte ranges are served by nginx.

## API shape

Existing `GET/POST/PATCH/DELETE /api/companies/{companyId}/news` stays as the
backward-compatible story resource. Public GET becomes server-filtered and
ordered. Admin reads all rows from protected `/news/manage`.

Add:

- public and protected CRUD list for `/story-collections`
- public collection stories at `/story-collections/{collectionId}/stories`
- public and protected CRUD list for `/news-posts`
- authenticated `PUT/DELETE .../media` for story and post
- authenticated image-only `PUT/DELETE .../cover` for collection

All mutations require owner or manager. Barista is denied. Company scope is
checked from the staff token and path. An unpublished empty draft shell is
allowed so the server can issue an ID before multipart media upload. Publishing
(or a patch that enables publication) rejects content with neither text nor
media, incomplete used translations, and invalid/naive dates.

## Admin UX

The News section has three tabs: `Сторисы`, `Подборки`, `Лента`.

- Story editor: RU/KY/EN fields; collection; Home toggle; pin; publish; expiry
  presets (never, 24 hours, 3 days, 7 days, custom); image/MP4 upload with
  preview, replace and remove; order remains available as a tie-breaker.
- Collection editor: RU/KY/EN name/description, image cover, order, publish;
  card shows story count and manages 40+ items without rendering media.
- Feed editor: RU/KY/EN title/summary/body, automatic date, publish and optional
  image/MP4.
- Saving and uploading show pending/error state and only report success after
  server acknowledgement. Uploaded URLs are never typed manually.

## Flutter UX and performance

- Home takes at most 30 active Home stories and uses `ListView.builder`.
- `/news` uses slivers: lazy collection rail followed by lazy feed cards.
- Collection viewer uses `PageView.builder`; 40+ stories use one linear progress
  indicator and `current / total`, not dozens of progress bars.
- Feed detail uses a modal bottom sheet with full localized body and media.
- Network images have loading/error fallbacks and bounded decode dimensions.
- A single video controller may exist only for the currently visible detail.
- Pull-to-refresh and app resume refresh stories, collections and posts.

## Acceptance

1. Owner creates a localized collection, changes its name and cover, and adds
   at least one localized image story.
2. Owner creates a Home story with expiry and a feed post.
3. Public API excludes drafts/future/expired content and never exceeds 30 Home
   stories.
4. Flutter refresh shows the Home story, collection and feed post in RU/KY/EN;
   detail/back behavior works.
5. Removing or expiring the test content removes it from public Flutter without
   resurrecting DemoData.
6. Backend, admin typecheck/build, Flutter analyze/tests and production
   deployment smoke pass before phone acceptance.
