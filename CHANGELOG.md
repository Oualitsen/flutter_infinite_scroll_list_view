# 1.2.0
Adds optional `pageSize` and `isEndOfPage` parameters to `InfiniteScrollListView`.
- When `pageSize` is set, the list stops paginating as soon as a page returns fewer items than `pageSize`, avoiding an extra empty-page round-trip.
- When `isEndOfPage` is set, it overrides all default end-of-page logic with a custom predicate.
- Fallback order: `isEndOfPage` → `pageSize` → `page.isEmpty` → `null response`.

**New widget**
- `SliverInfiniteScrollListView<T>` backed by `SliverAnimatedList`, composable inside any `CustomScrollView` alongside other slivers (app bars, headers, grids, etc.). Supports all existing APIs: `clear()`, `replace()`, `isLoading`, `isEndOfResults`, `removeAnimationBuilder`, `separatorBuilder`, `initialItems`, `onReload`, `onLoadMore`, `pageSize`, `isEndOfPage`.

**State-control API**
- `isLoading` and `isEndOfResults` are synchronous boolean getters readable at any time without subscribing to streams.
- `clear()` empties the list and resets pagination without triggering a new fetch.
- `replace(List<T>)` atomically swaps the entire list without animation. Marks end-of-results so the sentinel does not auto-trigger pagination; call `load()` or `reload()` afterwards to resume fetching.

**Lifecycle callbacks**
- `initialItems` pre-populates the list on mount without a network call.
- `onReload` fires when `reload()` is explicitly called; does not fire on the initial load.
- `onLoadMore(int page)` fires for every page after the first.
- `InfiniteScrollListView.horizontal(...)` named constructor shorthand that sets `scrollDirection: Axis.horizontal`.
- `InfiniteScrollListView.once(oncePageLoader: () => ...)` and `SliverInfiniteScrollListView.once(...)` named constructors that accept a no-argument loader and fetch exactly one page, with no need for manual index checks.
- `simpleBuilder<T>((context, item) => ...)` top-level helper that wraps a two-argument builder into the full four-argument `elementBuilder` signature, eliminating unused `index` and `animation` parameters.

**Performance**
- Batch insert fast-path: when `betweenItemRenderDelay` is null, all items from a page are inserted synchronously in a single event-loop turn instead of one microtask per item.

**Bug fixes**
- Disposed-widget guard: all async paths check `_disposed` before mutating state, preventing "setState called after dispose" errors.
- Load queue now keeps only the latest pending call; stale queued loads are dropped with `queue.clear()`.

## 0.0.1

* First realease
## 0.0.7

Adds elementErrorBuilder:
if the list already contains some element but gets an error at some time, the list displays (by default)
an icon button that allow the user to try to load the data.


## 0.0.7
Bug fixes

# 1.0.0
Fixes deprications

# 1.1.0
Fixes a bug when adding element on a sorted environement.
Adds a function pick to allow the user to pick which version of the same object (decided by comparator) to keep.