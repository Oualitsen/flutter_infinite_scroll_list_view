# Infinite Scroll List View

A **powerful, flexible, and efficient infinite scrolling list view** for Flutter — with built-in sorting, deduplication, dynamic mutations, sliver support, and a minimal API that stays out of your way.

[![pub.dev](https://img.shields.io/pub/v/infinite_scroll_list_view)](https://pub.dev/packages/infinite_scroll_list_view)

---

## Why this package?

Most infinite-scroll packages just load pages. This one manages your **entire list lifecycle**:

- Pages load automatically as the user scrolls — zero boilerplate.
- Items inserted mid-session land in the right sorted position instantly.
- Duplicates are detected and merged, not doubled.
- State (`isLoading`, `isEndOfResults`) is readable at any time without subscribing to streams.
- Works as a regular widget **or** as a sliver inside a `CustomScrollView`.

---

## Features

| | |
|---|---|
| Automatic pagination | New pages load as the sentinel scrolls into view |
| Smart end-of-page detection | `pageSize`, `isEndOfPage`, or the default empty-page heuristic |
| Custom comparator | Full control over sort order — items insert at the right position every time |
| Deduplication + `pick` | Zero == same item; choose which version to keep |
| Dynamic mutations | `add()`, `update()`, `removeItem()`, `removeWhere()` — all animated |
| State control | `clear()`, `replace()`, `reload()`, `isLoading`, `isEndOfResults` via `GlobalKey` |
| Sliver variant | `SliverInfiniteScrollListView` composes with app bars, headers, grids |
| One-shot loader | `.once` constructor — no index checks, no empty-page round-trip |
| Simple builder | `simpleBuilder` drops unused `index` and `animation` params |
| Separators | `separatorBuilder` — like `ListView.separated`, but paginated |
| Remove animations | `removeAnimationBuilder` receives the removed item for exit transitions |
| Pull-to-refresh | Built-in `RefreshIndicator`, opt out with `refreshable: false` |
| Error handling | `errorBuilder` for full-page errors, `elementErrorBuilder` for inline retry |
| Horizontal lists | `.horizontal` named constructor |
| Batch insert fast-path | No `betweenItemRenderDelay`? All items insert in a single frame |

---

## Installation

```yaml
dependencies:
  infinite_scroll_list_view: ^1.3.0
```

```
flutter pub get
```

---

## Quick start

### Paginated list

```dart
InfiniteScrollListView<Post>(
  pageSize: 20,
  pageLoader: (page) => api.fetchPosts(page: page, size: 20),
  elementBuilder: simpleBuilder((context, post) => PostTile(post)),
)
```

### Single-page list (load once, done)

No more `if (index == 0) fetch else return []`:

```dart
InfiniteScrollListView.once(
  oncePageLoader: () => api.fetchFeatured(),
  elementBuilder: simpleBuilder((context, post) => PostTile(post)),
)
```

### Inside a CustomScrollView

```dart
CustomScrollView(
  slivers: [
    SliverAppBar(title: Text('Feed')),
    SliverInfiniteScrollListView<Post>(
      pageSize: 20,
      pageLoader: (page) => api.fetchPosts(page: page, size: 20),
      elementBuilder: simpleBuilder((context, post) => PostTile(post)),
    ),
  ],
)
```

---

## Sorting and deduplication

Provide a `comparator` and items always land in the right position — whether they come from pagination or a live push.

```dart
// Positive → a before b. Zero → same item (triggers update). Negative → a after b.
int compareByDate(Post a, Post b) => b.createdAt.compareTo(a.createdAt); // newest first
```

When two items compare as equal, the `pick` function decides which version to keep:

```dart
pick: (current, incoming) => incoming.updatedAt > current.updatedAt ? incoming : current,
```

---

## Live mutations

Use a `GlobalKey` to mutate the list from anywhere — items animate in and out automatically.

```dart
final key = GlobalKey<InfiniteScrollListViewState<Message>>();

// Elsewhere — e.g. a WebSocket handler:
key.currentState!.add(newMessage);       // inserts at the sorted position
key.currentState!.update(editedMessage); // updates in-place
key.currentState!.removeItem(message);  // animated removal
key.currentState!.reload();             // clears and re-fetches from page 0
```

---

## State control

```dart
if (key.currentState!.isLoading) showSpinner();
if (key.currentState!.isEndOfResults) showEndBanner();

await key.currentState!.clear();          // empty list, reset pagination, no fetch
await key.currentState!.replace(items);   // swap contents without animation
```

---

## Full example — live chat feed

```dart
class ChatScreen extends StatefulWidget { ... }

class _ChatScreenState extends State<ChatScreen> {
  final _key = GlobalKey<InfiniteScrollListViewState<Message>>();

  @override
  void initState() {
    super.initState();
    socket.onMessage((msg) => _key.currentState?.add(msg));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: InfiniteScrollListView<Message>(
        key: _key,
        pageSize: 30,
        pageLoader: (page) => api.fetchMessages(page: page, size: 30),
        comparator: (a, b) => b.sentAt.compareTo(a.sentAt), // newest first
        pick: (current, incoming) => incoming,
        elementBuilder: simpleBuilder((context, msg) => MessageBubble(msg)),
        errorBuilder: (context, error) => RetryWidget(onRetry: () => _key.currentState!.reload()),
        separatorBuilder: (context, index) => const Divider(height: 1),
      ),
    );
  }
}
```

---

## API reference

### `InfiniteScrollListView<T>`

| Parameter | Type | Description |
|---|---|---|
| `pageLoader` | `Future<List<T>?> Function(int page)` | Called with the next page index. Return `null` or `[]` to signal end of results. |
| `elementBuilder` | `Widget Function(context, item, index, animation)` | Builds each item. Use `simpleBuilder` to drop unused params. |
| `comparator` | `int Function(T a, T b)?` | Sort order. Positive = a before b, zero = same item (update), negative = a after b. |
| `pick` | `T Function(T current, T incoming)?` | Resolves duplicates when `comparator` returns zero. Defaults to keeping the incoming item. |
| `pageSize` | `int?` | Stops paginating when a page has fewer items than this. |
| `isEndOfPage` | `bool Function(List<T> page)?` | Custom end-of-page predicate. Overrides `pageSize` and the default. |
| `initialItems` | `List<T>?` | Pre-populates the list on mount without a network call. |
| `onReload` | `void Function()?` | Fires when `reload()` is called explicitly (not on the initial load). |
| `onLoadMore` | `void Function(int page)?` | Fires for every page after the first. |
| `errorBuilder` | `Widget Function(context, error)?` | Full-page error widget shown when the list is empty and a fetch fails. |
| `elementErrorBuilder` | `Widget Function(context, error)?` | Inline error widget shown when a subsequent page fails. |
| `separatorBuilder` | `Widget Function(context, index)?` | Separator between items, like `ListView.separated`. |
| `removeAnimationBuilder` | `Widget Function(context, item, animation)?` | Exit animation for removed items. Receives the removed item. |
| `betweenItemRenderDelay` | `Duration?` | Delay between each item rendering. `null` enables the batch fast-path. |
| `animateRemovingItemsOnReload` | `bool` | Whether to animate items out during `reload()`. Default `false`. |
| `refreshable` | `bool` | Wraps the list in a `RefreshIndicator`. Default `true`. |
| `noDataWidget` | `Widget?` | Shown when the list is empty and loading is done. |
| `loadingWidget` | `Widget?` | Shown during the initial load. |
| `itemLoadingWidget` | `Widget?` | Shown at the bottom while the next page loads. |
| `endOfResultWidget` | `Widget?` | Shown when all pages have been loaded. |

### Named constructors

| Constructor | Description |
|---|---|
| `InfiniteScrollListView.once(oncePageLoader: () => ...)` | Fetches exactly one page. No index argument, no end-of-page configuration needed. |
| `InfiniteScrollListView.horizontal(...)` | Sets `scrollDirection: Axis.horizontal`. |
| `SliverInfiniteScrollListView.once(oncePageLoader: () => ...)` | Sliver variant of `.once`. |

### Top-level helpers

| Helper | Description |
|---|---|
| `simpleBuilder<T>((context, item) => ...)` | Wraps a two-argument builder into the full four-argument `elementBuilder` signature. |

---

## Contribute

Found a bug? Have an idea? Open an issue or PR:

https://github.com/Oualitsen/flutter_infinite_scroll_list_view
