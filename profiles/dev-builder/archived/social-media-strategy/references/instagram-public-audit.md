# Public Instagram account audit

Instagram's public HTML may expose useful crawler-oriented server-rendered JSON even when a normal browser or extractor shows only a login shell. This reference records a robust extraction pattern for profile and post analysis.

## Retrieval pattern

Request the public profile with a crawler user agent such as Bingbot, then parse every:

```html
<script type="application/json" data-sjs>...</script>
```

Walk each decoded JSON object recursively.

### Profile records

A useful profile object commonly contains:

- `username`
- `full_name`
- `biography`
- `follower_count`
- `following_count`
- `bio_links`
- `is_private`
- `is_verified`

Choose the richest matching object for the requested username, because the same account may appear more than once in the payload.

### Timeline records

Post nodes commonly contain:

- `code` — shortcode used in `/p/{code}/`
- `caption.text`
- `accessibility_caption` — often includes date and visible overlay-text hints
- `display_uri` — thumbnail
- `media_type`
- `product_type` — often `clips`, `carousel_container`, or `feed`
- `carousel_media_count`

Deduplicate by `code`. The returned order may mix recent and pinned posts; do not call it strictly chronological without checking timestamps.

### Post metrics

Request each individual `/p/{code}/` page using the same crawler user agent. Recursively find a matching object that contains both the requested `code` and `like_count`. Prefer that direct media object over a larger wrapper that embeds the whole profile timeline.

Fields can include:

- `like_count`
- `comment_count`
- `taken_at`
- `product_type`
- `media_type`

Convert `taken_at` from Unix time and date the snapshot. Public metrics may change and do not prove leads or revenue.

## Visual contact sheet

Download `display_uri` thumbnails and tile them for one-pass visual review. If Pillow is unavailable but ffmpeg exists, scale/crop each image to a square and combine with `xstack`. Inspect:

- legibility at grid size;
- recurring cover system;
- visible faces;
- beginner versus advanced imagery;
- whether topic, audience, and promise are apparent without captions.

## Fallback ladder

1. Standard web extraction for profile/post body.
2. Search-engine snippets for indexed captions.
3. Crawler-oriented SSR JSON as above.
4. Individual public post pages.
5. Real browser only when needed and available.

Do not encode a transient browser failure as a permanent limitation. Preserve the successful retrieval method and retry pattern instead.

## Ethical and analytical guardrails

- Audit only public content.
- Do not infer private demographics, revenue, or conversion data.
- Report counts as dated snapshots.
- Distinguish pinned posts from current cadence when timestamps reveal mixed ordering.
- A keyword post with many comments demonstrates visible interaction, not sales.
- Do not copy captions or branding verbatim; extract reusable mechanisms.
