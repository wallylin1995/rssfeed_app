# Jippo RSS Reader Project Skill

## Purpose

Use this skill whenever working on **Jippo**, a Universal Swift RSS reader app for macOS, iPadOS, and iOS.

This skill preserves the core architectural decisions so future AI sessions do not forget the project constraints.

Jippo is not a generic RSS list reader. It is a calm, design-forward, Apple-native RSS reader with a dynamic editorial homepage.

---

# 1. Product Identity

App name: **Jippo**

Jippo should feel like:

- A native Apple app
- A design-forward RSS reader
- A calm reading environment
- An App Store / Apple News-inspired editorial homepage
- A Universal Swift app for macOS, iPadOS, and iOS

Do not build Jippo as a plain table-based RSS reader.

The homepage should support:

- Large hero sections
- Container-based editorial sections
- Dynamic topic/category sections
- AI-assisted but fully validated curation
- Deterministic fallback when AI is unavailable

---

# 2. Core Architecture Rule

The `article` table is the source of truth.

AI must not create article data.

AI can only:

- Reference existing `article.id`
- Produce `HomeLayoutPlanDraft`
- Suggest topic/category labels
- Generate short model-facing article briefs
- Generate section titles/subtitles
- Help arrange known articles into known renderable sections

AI must never:

- Invent articles
- Invent unsupported UI components
- Directly generate SwiftUI
- Directly mutate article identity
- Store homepage state on the `article` table
- Bypass validation
- Render raw model output

SwiftUI must only render:

```swift
ValidHomeLayoutPlan
```

Never render raw AI output.

---

# 3. Homepage Design Principle

Dynamic homepage does not mean free-form AI UI.

Dynamic homepage means:

```text
Existing articles
+ article annotations
+ topics
+ local ranking
+ compact candidate cards
+ AI layout planning
+ validator
+ repairer
+ persisted valid homepage plan
+ SwiftUI renderer
```

The AI may dynamically create category sections like:

```text
農業
食安
AI 工具
半導體
公共衛生
氣候災害
```

But those categories must use known section components:

```text
hero_split
hero_stack
magazine_grid
compact_list
topic_cluster
```

Example:

```text
section_type = topic_cluster
semantic_type = category
topic_key = food_safety
title = 食安
```

```text
section_type = magazine_grid
semantic_type = category
topic_key = agriculture
title = 農業
```

---

# 4. Local Database Naming Rules

Use singular, human-readable table names.

Preferred table names:

```sql
account
account_settings

feed
collection
collection_feed
collection_article

article
article_content
article_enclosure
cached_image

sync_operation

topic
article_topic
article_annotation

homepage_plan
homepage_section
homepage_placement
homepage_candidate
```

Avoid legacy/generic names:

```sql
GROUP_T
ITEM
CONTENT
oid
pos
feed_link
site_link
```

Preferred column names:

```sql
remote_id
feed_url
site_url
display_order
published_at
received_at
last_synced_at
sync_cursor
topic_key
semantic_type
```

---

# 5. Core Database Model

## account

Represents one RSS service account.

Examples:

```text
local
icloud
feedbin
inoreader
feedly
freshrss
custom
```

## feed

Represents one RSS / Atom subscription source.

Every normal RSS article should belong to a feed through:

```sql
article.feed_id
```

## collection

Represents folders, smart folders, internal streams, and saved views.

Examples:

```text
All Articles
Today
Unread
Starred
Technology
Design
User-created folder
Smart search result
```

Suggested `collection_type` values:

```text
folder
smart_folder
stream
saved_search
internal
```

## article

Stores article metadata and identity.

This is the source of truth for articles.

Do not add homepage columns to `article`.

Avoid:

```sql
article.is_homepage_hero
article.homepage_section
article.homepage_order
```

## article_content

Stores body content:

```sql
html
plain_text
summary
reader_html
extracted_text
word_count
reading_time_minutes
```

## sync_operation

Stores offline operations:

```text
mark_read
mark_unread
star
unstar
archive
unarchive
delete
add_feed
remove_feed
rename_feed
rename_collection
move_feed
```

---

# 6. Topic Model

Jippo supports dynamic topic/category generation.

Use:

```sql
topic
article_topic
article_annotation.primary_topic_key
```

## topic

Stores normalized topics/categories.

Examples:

```text
food_safety -> 食安
agriculture -> 農業
ai_tools -> AI 工具
semiconductor -> 半導體
public_health -> 公共衛生
climate_disaster -> 氣候災害
```

Suggested source values:

```text
system
ai_generated
user_created
imported
```

## article_topic

A many-to-many join table.

A single article can belong to multiple topics.

Examples:

```text
article 101 -> agriculture, food_safety
article 102 -> food_safety, public_health
article 103 -> agriculture, climate_disaster
```

## Topic normalization

AI can output Chinese category titles, but `topic_key` should be lowercase snake_case.

Examples:

```text
農業 -> agriculture
食安 -> food_safety
氣候災害 -> climate_disaster
台灣政治 -> taiwan_politics
AI 工具 -> ai_tools
半導體 -> semiconductor
公共衛生 -> public_health
食品標示 -> food_labeling
冷鏈物流 -> cold_chain_logistics
```

Merge equivalent labels:

```text
食品安全 / 食安 / 食物安全 / 食品風險
→ food_safety
→ title: 食安

農業 / 農產 / 農糧 / 農政
→ agriculture
→ title: 農業
```

Implement:

```text
TopicNormalizer
TopicRepository
ArticleTopicRepository
```

---

# 7. Article Annotation

`article_annotation` stores AI-generated or locally-generated semantic signals.

It should include:

```sql
summary
short_summary
ai_brief

primary_topic_key
content_type
language

title_token_estimate
ai_brief_token_estimate

importance_score
freshness_score
source_score
user_interest_score
visual_score
editorial_score
diversity_score

sentiment
reason

annotated_at
model_version
algorithm_version
```

`ai_brief` is a compact model-facing brief used for homepage curation.

It is not necessarily the same as a polished user-facing summary.

Example:

```text
食品安全事件，涉及原料污染、下架與監管。
```

---

# 8. Homepage Tables

Homepage state belongs in:

```sql
homepage_plan
homepage_section
homepage_placement
homepage_candidate
```

Never store homepage placement on `article`.

## homepage_plan

Represents one generated homepage plan.

Suggested status values:

```text
draft
valid
failed
fallback
archived
```

## homepage_section

Represents one homepage section.

Important fields:

```sql
section_type
semantic_type
topic_key
title
subtitle
style_variant
display_order
```

`section_type` controls how the section is rendered.

`semantic_type` controls what the section means.

Allowed MVP `section_type` values:

```text
hero_split
hero_stack
magazine_grid
compact_list
topic_cluster
```

Allowed `semantic_type` values:

```text
editorial
category
source
timeline
personalized
breaking
deep_read
reading_goal
```

Suggested `style_variant` values:

```text
large
dense
editorial
minimal
visual
text_first
```

## homepage_placement

Represents one article placement inside one section.

Allowed roles:

```text
primary
secondary
tertiary
list_item
thumbnail_item
```

Allowed image modes:

```text
cover
fit
thumbnail
hidden
```

Important rule:

One article should not appear more than once in the same homepage plan.

---

# 9. Homepage Layout Contract

AI must output a constrained layout plan, not UI code.

Example:

```json
{
  "layout_version": 1,
  "sections": [
    {
      "section_type": "topic_cluster",
      "semantic_type": "category",
      "topic_key": "food_safety",
      "title": "食安",
      "subtitle": "食品安全、標示與供應鏈風險",
      "style_variant": "text_first",
      "placements": [
        {
          "article_id": 201,
          "role": "primary"
        },
        {
          "article_id": 202,
          "role": "secondary"
        },
        {
          "article_id": 203,
          "role": "list_item"
        }
      ]
    }
  ]
}
```

AI output rules:

- Use only provided article IDs.
- Use only supported section types.
- Use only supported semantic types.
- Use only supported role values.
- Each article ID can appear at most once in the whole homepage plan.
- If `semantic_type = category`, include `topic_key` and `title`.
- `topic_key` must be lowercase snake_case.
- The title can be localized and user-facing.
- Do not invent article data.
- Do not output UI code.
- Output JSON only.

---

# 10. Swift Homepage Models

Implement:

```swift
enum HomeSectionType: String, Codable {
    case heroSplit = "hero_split"
    case heroStack = "hero_stack"
    case magazineGrid = "magazine_grid"
    case compactList = "compact_list"
    case topicCluster = "topic_cluster"
}

enum HomeSectionSemanticType: String, Codable {
    case editorial
    case category
    case source
    case timeline
    case personalized
    case breaking
    case deepRead = "deep_read"
    case readingGoal = "reading_goal"
}

enum HomePlacementRole: String, Codable {
    case primary
    case secondary
    case tertiary
    case listItem = "list_item"
    case thumbnailItem = "thumbnail_item"
}

enum HomeStyleVariant: String, Codable {
    case large
    case dense
    case editorial
    case minimal
    case visual
    case textFirst = "text_first"
}

enum HomeImageMode: String, Codable {
    case cover
    case fit
    case thumbnail
    case hidden
}

struct HomeLayoutPlanDraft: Codable {
    let layoutVersion: Int
    let sections: [HomeSectionDraft]
}

struct HomeSectionDraft: Codable {
    let sectionType: HomeSectionType
    let semanticType: HomeSectionSemanticType
    let topicKey: String?
    let title: String?
    let subtitle: String?
    let styleVariant: HomeStyleVariant?
    let placements: [HomePlacementDraft]
}

struct HomePlacementDraft: Codable {
    let articleID: Int64
    let role: HomePlacementRole
    let titleOverride: String?
    let summaryOverride: String?
    let imageMode: HomeImageMode?
}

struct ValidHomeLayoutPlan {
    let id: Int64
    let layoutVersion: Int
    let sections: [ValidHomeSection]
}

struct ValidHomeSection {
    let id: Int64
    let type: HomeSectionType
    let semanticType: HomeSectionSemanticType
    let topicKey: String?
    let title: String?
    let subtitle: String?
    let styleVariant: HomeStyleVariant?
    let placements: [ValidHomePlacement]
}

struct ValidHomePlacement {
    let article: Article
    let role: HomePlacementRole
    let titleOverride: String?
    let summaryOverride: String?
    let imageMode: HomeImageMode?
}
```

---

# 11. Homepage Section Capabilities

Implement:

```swift
struct HomeSectionCapability {
    let type: HomeSectionType
    let minItems: Int
    let maxItems: Int
    let requiresImageForPrimary: Bool
    let allowedRoles: Set<HomePlacementRole>
}
```

MVP capabilities:

```text
hero_split:
- min 2
- max 4
- primary requires image
- roles: primary, secondary

hero_stack:
- min 1
- max 3
- image optional
- roles: primary, secondary

magazine_grid:
- min 3
- max 6
- image recommended but not required
- roles: primary, secondary, tertiary

compact_list:
- min 3
- max 10
- image not required
- roles: list_item

topic_cluster:
- min 3
- max 8
- image optional
- roles: primary, secondary, list_item
```

---

# 12. Apple Foundation Models Strategy

Jippo should support Apple Foundation Models, but it must treat the on-device model as a constrained local editorial assistant, not as a long-context cloud model.

## 12.1 Context Window Constraint

The on-device Foundation Models path should assume a strict context window.

Rules:

```text
Do not send full article bodies to the on-device model for homepage planning.
Do not send raw HTML.
Do not send hundreds of articles.
Do not use a long-lived chat session for homepage generation.
```

Instead:

```text
Use short-lived sessions.
Use compact candidate cards.
Reserve output budget.
Fallback before or after context overflow.
```

## 12.2 Recommended Context Budget

Use a conservative budget for Chinese/Japanese/Korean content.

```text
Model hard limit: 4096 tokens
Recommended safe limit: 3200 tokens

Instructions: 400–600
Layout contract / enum schema: 500–700
Candidate articles: 1600–2000
Output JSON reserve: 600–900
```

Candidate sizing guideline:

```text
20 articles × 80 tokens ≈ 1600 tokens
30 articles × 60 tokens ≈ 1800 tokens
40 articles × 50 tokens ≈ 2000 tokens
```

For Chinese RSS content, assume roughly:

```text
1 Chinese character ≈ 1 token
```

## 12.3 Compact AI Candidate Card

Foundation Models should receive compact candidate cards, not article bodies.

```swift
struct AICandidateCard: Codable, Identifiable {
    let id: Int64
    let title: String
    let sourceTitle: String
    let topicKeys: [String]
    let ageHours: Int
    let hasImage: Bool
    let brief: String
    let localScore: Double
}
```

Example JSON:

```json
{
  "id": 301,
  "title": "某食品原料檢出污染物，監管單位要求下架",
  "source": "中央社",
  "topic_keys": ["food_safety", "public_health"],
  "age_hours": 3,
  "has_image": true,
  "brief": "食品安全事件，涉及原料污染、下架與監管。"
}
```

Each candidate card should ideally stay within 50–100 Chinese characters.

## 12.4 Split AI into Small Tasks

Do not ask the local model to do everything at once.

Recommended task split:

```text
Task 1: Article brief generation
Task 2: Topic classification / normalization
Task 3: Homepage layout planning
```

### Task 1: Article brief generation

Input:

```text
title
source
published_at
first 500–800 characters of plain_text
optional feed/category metadata
```

Output:

```json
{
  "ai_brief": "一句話重點",
  "primary_topic_key": "food_safety",
  "topic_keys": ["food_safety", "public_health"],
  "content_type": "report",
  "importance_score": 0.74
}
```

Write result into:

```text
article_annotation.ai_brief
article_annotation.primary_topic_key
article_topic
```

### Task 2: Topic normalization

Input:

```text
small batch of topic labels
```

Output:

```json
{
  "食安": "food_safety",
  "食品安全": "food_safety",
  "農糧": "agriculture"
}
```

Write result into:

```text
topic
article_topic
```

### Task 3: Homepage layout planning

Input:

```text
20–30 compact article candidates
allowed section types
allowed semantic types
allowed role values
section capability rules
```

Output:

```json
{
  "layout_version": 1,
  "sections": [
    {
      "section_type": "topic_cluster",
      "semantic_type": "category",
      "topic_key": "food_safety",
      "title": "食安",
      "placements": [
        { "article_id": 201, "role": "primary" },
        { "article_id": 202, "role": "secondary" },
        { "article_id": 203, "role": "list_item" }
      ]
    }
  ]
}
```

## 12.5 PromptBudgeter

Implement a `PromptBudgeter`.

Responsibilities:

```text
Estimate token usage before model call.
Reserve output tokens.
Trim candidate list before exceeding safe limit.
Prefer removing low-score candidates over truncating schema.
Use compact card fields only.
Reject or fallback before calling model if over budget.
```

Suggested Swift model:

```swift
struct ContextBudget {
    let hardLimit: Int = 4096
    let safeLimit: Int = 3200
    let reservedOutputTokens: Int = 800
    let instructionsBudget: Int = 600
    let schemaBudget: Int = 500
    let candidatesBudget: Int = 1800
}
```

Naive conservative token estimator for MVP:

```swift
struct TokenEstimator {
    func estimateTokens(_ text: String) -> Int {
        var count = 0

        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x4E00...0x9FFF:
                count += 1
            case 0x3040...0x30FF:
                count += 1
            case 0xAC00...0xD7AF:
                count += 1
            default:
                count += 1
            }
        }

        return count
    }
}
```

This estimator is intentionally conservative.

## 12.6 Planner Chain

Jippo should not assume Foundation Models are always available.

Recommended planner chain:

```text
PrivateCloudComputeHomeLayoutPlanner
→ future only; requires paid developer program, entitlement, availability, network, and quota

OnDeviceFoundationModelHomeLayoutPlanner
→ available only if SystemLanguageModel is available

DeterministicHomeLayoutPlanner
→ always available fallback
```

For MVP, implement:

```text
DeterministicHomeLayoutPlanner
MockHomeLayoutPlanner
OnDeviceFoundationModelHomeLayoutPlanner interface placeholder
PromptBudgeter
TokenEstimator
```

Do not block the app on Foundation Models availability.

## 12.7 Error Handling

If the model fails, Jippo must not fail the homepage.

Handle:

```text
model unavailable
context window exceeded
generation failed
invalid JSON
invalid section type
invalid article ID
duplicated article
quota or availability changes
```

Fallback flow:

```text
AI call fails
→ log failure
→ create fallback homepage_plan with status = fallback
→ render fallback homepage
```

If the model exceeds context window:

```text
Catch exceededContextWindowSize
→ reduce candidate count
→ retry once if safe
→ otherwise fallback deterministic
```

## 12.8 Session Strategy

Use short-lived sessions for homepage planning.

```text
One homepage generation task
→ one short-lived LanguageModelSession
→ one output JSON
→ validate
→ discard session
```

Avoid:

```text
Keeping one long-lived session for all RSS updates
Accumulating chat history
Sending prior plans repeatedly
Sending raw article bodies
```

---

# 13. Homepage Validation and Repair Rules

General validation checks:

1. `layout_version` is supported.
2. Every `section_type` exists.
3. Every `semantic_type` exists.
4. Every `style_variant` exists or is nullable.
5. Every `role` exists.
6. Every `article_id` exists.
7. No duplicated article in the same plan.
8. Section item count is valid.
9. Required primary article exists.
10. Hero primary image requirement is satisfied.
11. Article is not deleted.
12. Article is recent enough for homepage candidate pool.
13. Too many articles from same feed are avoided.
14. Section ordering is deterministic.
15. Placement ordering is deterministic.
16. Prompt budget is respected before AI generation.
17. AI output JSON is schema-valid.

Category/topic validation checks:

1. If `semantic_type = category`, `topic_key` should exist or be normalizable.
2. `topic_key` must use lowercase snake_case.
3. `title` must exist for category sections.
4. `title` length should be reasonable.
5. `subtitle` length should be reasonable.
6. Category section should have enough articles.
7. Category section articles should be related to the section topic.
8. Same `topic_key` should not appear twice in the same homepage plan.
9. Overly narrow one-off topics should be merged or downgraded.
10. If topic confidence is low, downgrade to `compact_list` or remove section.

Repair examples:

```text
hero_split without primary image
→ downgrade to hero_stack

magazine_grid with too few images
→ downgrade to compact_list

topic_cluster with weak topic consistency
→ downgrade to compact_list

category section with invalid topic_key
→ normalize topic_key

category section with duplicate topic_key
→ merge sections or keep stronger section

category section with too few related articles
→ remove section or merge into compact_list

section with invalid article IDs
→ remove invalid placements

section below min item count
→ remove section or fill from fallback candidate pool

prompt over budget
→ reduce candidates before calling model

model context window exceeded
→ retry with fewer candidates once, then fallback

entire plan invalid
→ generate fallback homepage from local ranking
```

Rendering rule:

```text
SwiftUI must only render ValidHomeLayoutPlan.
Never render raw AI output.
```

---

# 14. Fallback Homepage

When AI fails, use deterministic local ranking.

Fallback layout:

```text
hero_stack:
- top 1–3 articles by total local score

compact_list:
- next 5–10 recent unread articles

topic_cluster:
- strongest topic group if available

category sections:
- generated from article_topic clusters if they have enough articles
```

Fallback scoring formula example:

```swift
totalScore =
    recencyScore * 0.30 +
    sourceScore * 0.20 +
    unreadScore * 0.15 +
    userInterestScore * 0.20 +
    visualScore * 0.10 +
    diversityScore * 0.05
```

Fallback category generation:

```text
1. Group recent articles by topic_key using article_topic.
2. Exclude hidden topics.
3. Require minimum article count, e.g. 3 articles.
4. Rank topics by article importance + freshness + diversity.
5. Generate at most 2–4 category sections.
6. Use topic_cluster or compact_list depending on available image quality.
```

---

# 15. Swift Module Recommendations

Suggested modules:

```text
JippoDatabase
JippoRSS
JippoSync
JippoHome
JippoAI
JippoUI
```

Suggested model groups:

```text
Account
Feed
Collection
Article
ArticleContent
Topic
ArticleTopic
ArticleAnnotation
SyncOperation
HomeLayoutPlan
HomeSectionPlan
HomePlacement
AICandidateCard
ContextBudget
```

Suggested service objects:

```text
RSSParser
FeedFetcher
SyncEngine
ArticleNormalizer
ArticleAnnotator
TopicNormalizer
PromptBudgeter
TokenEstimator
HomeCandidateBuilder
HomeLayoutPlanner
HomePlanValidator
HomePlanRepairer
HomePlanRepository
```

---

# 16. MVP Build Order

## Phase 1: Local RSS Database

Implement:

```text
account
account_settings
feed
collection
collection_feed
article
article_content
article_enclosure
cached_image
sync_operation
```

Features:

- Add RSS feed
- Fetch feed
- Parse RSS / Atom
- Store articles
- List articles
- Open article
- Mark read/unread
- Star/unstar
- Basic folders

## Phase 2: Homepage Without AI

Implement:

```text
topic
article_topic
article_annotation
homepage_plan
homepage_section
homepage_placement
PromptBudgeter
TokenEstimator
```

Features:

- Hero section
- Compact list
- Topic cluster
- Category sections from article_topic
- Fallback local ranking
- Validated homepage render path
- Compact candidate card builder

## Phase 3: AI Curation

Add:

- Article summary / `ai_brief`
- Topic inference
- Topic normalization
- Multi-topic article classification
- Importance score
- HomeLayoutPlanDraft generation
- AI-generated category sections
- Prompt budget enforcement
- Short-lived model session strategy
- Validator
- Repair engine
- Persist valid plans only

## Phase 4: Universal UI Polish

Add:

- macOS sidebar
- iPad split view
- iPhone compact navigation
- App Store-like hero cards
- Dynamic homepage sections
- Offline image cache
- Search
- Keyboard shortcuts
- Multi-window macOS support

## Future Phase

Add:

```text
PrivateCloudComputeHomeLayoutPlanner
```

Only if entitlement, availability, network, and quota are available.

---

# 17. Codex Prompt Summary

When asking Codex to implement Jippo, include this summary:

```text
Build Jippo, a Universal Swift RSS reader app for macOS, iPadOS, and iOS.

Use SwiftUI, SQLite/GRDB, async/await, URLSession, RSS/Atom parsing, and a clean module structure.

Jippo must support a dynamic editorial homepage, but AI must never directly create UI.

AI may only produce HomeLayoutPlanDraft using existing article IDs. The app must validate, repair, and persist only ValidHomeLayoutPlan.

Implement local RSS database tables:
account, account_settings, feed, collection, collection_feed, collection_article, article, article_content, article_enclosure, cached_image, sync_operation, topic, article_topic, article_annotation, homepage_plan, homepage_section, homepage_placement, homepage_candidate.

Implement dynamic topic/category sections:
section_type controls UI.
semantic_type controls meaning.
topic_key stores normalized topic.
title stores user-facing section label.

Implement on-device Foundation Models architecture cautiously:
Do not send full article bodies.
Use compact AICandidateCard.
Use PromptBudgeter.
Use short-lived sessions.
Fallback to DeterministicHomeLayoutPlanner if AI is unavailable, over budget, invalid, or fails.

Start with deterministic homepage and mock AI planner before real Foundation Models integration.
```

---

# 18. Non-Negotiable Constraints

Always preserve these constraints:

1. `article` is the source of truth.
2. AI must not invent article data.
3. AI must not generate SwiftUI.
4. AI output must be validated before persistence.
5. SwiftUI renders only `ValidHomeLayoutPlan`.
6. Homepage placement never lives on `article`.
7. Dynamic category sections use `semantic_type = category`.
8. Category sections still use known `section_type` values.
9. On-device Foundation Models receive compact candidate cards only.
10. Deterministic fallback must always exist.
