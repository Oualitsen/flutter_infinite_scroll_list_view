# Package Specification: infinite_scroll_list_view

## Overview

A Flutter package providing a generic, animated, paginated list view with built-in infinite scrolling, pull-to-refresh, real-time item management (add/update/remove), and stream-driven state.

---

## Components

### `ReactiveValue<T>` — `reactive_value.dart`

A lightweight broadcast stream wrapper that replays the last emitted value to new subscribers (BehaviorSubject-like, no external dependencies).

**Behavior:**
- Optional initial value via constructor.
- `.stream` replays the last known value to each new subscriber, then forwards subsequent emissions.
- `.add(value)` sets internal state and emits to all active subscribers.
- `.valueOrNull` returns the last value or `null` if none has been emitted.
- `.value` unwraps `valueOrNull` (throws if no value ever set).
- `.isClosed` reflects whether the underlying `StreamController` is closed.
- `.close()` closes the broadcast controller; subsequent `.add()` calls are no-ops.

---

### `DataListLoaderMixin<T>` — `data_list_loader_mixin.dart`

A mixin providing paginated data loading, in-memory sorted list management, and three reactive streams. Intended to be mixed into a `State` class.

#### Internal State

| Field | Type | Purpose |
|---|---|---|
| `_dataStream` | `ReactiveValue<DataWrapper<T>?>` | Current list + optional error |
| `_loadingStream` | `ReactiveValue<bool>` | Page-fetch in progress flag |
| `_endOfResultStream` | `ReactiveValue<bool>` | Whether all pages are exhausted |
| `_pageIndex` | `int` | Next page number to request (0-based) |
| `queue` | `List<Function()>` | Pending load calls queued while loading |

#### Public Streams

- `dataStream` → emits `DataWrapper<T>?` on every list mutation.
- `loadingStream` → emits `true` when a fetch starts, `false` when it ends.

#### Lifecycle

- `initMixin()` — must be called in `initState`. Subscribes the queue-drain listener.
- `disposeMixin()` — must be called in `dispose`. Cancels subscription, closes all streams, clears queue.

#### Loading / Pagination

- `load({reload, ignoreIfLoading})` — fetches one page.
  - If already loading: queues the call (unless `ignoreIfLoading: true`).
  - `reload: true` resets `_pageIndex` to 0 and clears the list before inserting new items.
  - On success: increments `_pageIndex`; if the response is empty, marks end-of-result.
  - On error: marks end-of-result, emits `DataWrapper(currentList, error)`, re-throws.
- `reload()` — shorthand for `load(reload: true)`.

#### Sorting & Deduplication

Controlled by `comparator()` (abstract, overridden by the widget):

| Return value | Meaning |
|---|---|
| `> 0` | `a` sorts before `b` (descending) |
| `0` | `a` equals `b` → triggers **update** instead of insert |
| `< 0` | `a` sorts after `b` |

When `comparator` is `null`, items are appended in arrival order.

The `pick` callback resolves which value wins on a duplicate (default: incoming value wins).

#### Item Management (public API)

| Method | Description |
|---|---|
| `add(item)` | Inserts item respecting sort order; appends the "last element" sentinel. |
| `update(item)` | Re-runs insert logic for the item; updates in place if already present. |
| `removeItem(item, [index])` | Removes by reference or index; also removes empty-state sentinel if list becomes empty. |
| `removeWhere(filter)` | Removes all items matching predicate (sequentially). |
| `getItem(index)` | Returns item at index from internal list. |
| `getIndexOf(item)` | Finds index using comparator (equality when return is 0). |

#### Abstract Interface (implemented by the host `State`)

```dart
Future<List<T>?> Function(int index) getLoader();   // page fetch callback
int Function(T a, T b)? comparator();               // sort/dedup comparator
T Function(T current, T newValue)? pick;            // dedup value resolver
void onAdd(int index, T? item);                     // insert into AnimatedList
void onRemove(int index);                           // remove from AnimatedList
void onUpdate(int index, T item);                   // update in AnimatedList
int get listLength;                                 // current AnimatedList length
bool get isListReady;                               // AnimatedList key state != null
bool get animateRemovingItemsOnReload;              // whether to animate clears
Duration? get betweenItemRenderDelay;               // delay between animated insertions
```

#### "Last Element" Sentinel

`lastElement` is a virtual item appended at position `dataLength` in the `AnimatedList`. It renders one of three widgets based on `_endOfResultStream`:

- `endOfResult == false` → `getItemLoadingWidget()` (spinner); also triggers `load(ignoreIfLoading: true)` to fetch the next page automatically.
- `endOfResult == true, no error` → `getEndOfResultWidget()` (grey dot icon by default).
- `endOfResult == true, error present` → `getElementError()` (red refresh button by default).

---

### `InfiniteScrollListView<T>` — `infinite_scroll_list_view.dart`

A `StatefulWidget` that combines `DataListLoaderMixin` with Flutter's `AnimatedList`.

#### Constructor Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `elementBuilder` | `Widget Function(context, T, index, Animation)` | required | Builds each list item |
| `pageLoader` | `Future<List<T>?> Function(int index)` | required | Fetches page `index` |
| `comparator` | `int Function(T a, T b)?` | `null` | Sort/dedup comparator |
| `pick` | `T Function(T current, T newValue)?` | `null` | Dedup value resolver |
| `physics` | `ScrollPhysics?` | `null` | Scroll physics |
| `scrollDirection` | `Axis` | `Axis.vertical` | Scroll axis |
| `padding` | `EdgeInsetsGeometry?` | `null` | List padding |
| `controller` | `ScrollController?` | `null` | Scroll controller |
| `primary` | `bool?` | `null` | Whether primary scroll view |
| `reverse` | `bool` | `false` | Reverse scroll direction |
| `shrinkWrap` | `bool` | `false` | Shrink-wrap content |
| `clipBehavior` | `Clip` | `Clip.hardEdge` | Clip behavior |
| `noDataWidget` | `Widget?` | `null` | Shown when list is empty and not loading |
| `loadingWidget` | `Widget?` | `null` | Shown during initial load |
| `itemLoadingWidget` | `Widget?` | `null` | Shown at bottom while fetching next page |
| `endOfResultWidget` | `Widget?` | `null` | Shown when all pages are exhausted |
| `onRemoveAnimation` | `Widget?` | `null` | Widget shown during item removal animation |
| `betweenItemRenderDelay` | `Duration?` | `null` | Delay between animated item insertions |
| `animateRemovingItemsOnReload` | `bool` | `false` | Animate item removal on full reload |
| `refreshable` | `bool` | `true` | Wrap list in `RefreshIndicator` |
| `errorBuilder` | `Widget Function(context, error)?` | `null` | Full-screen error widget |
| `elementErrorBuilder` | `Widget Function(context, error)?` | `null` | Per-element error widget |

#### Build Logic

The widget is wrapped in a `StreamBuilder<DataWrapper<T>?>` on `dataStream`. A `Stack` is used to overlay state widgets:

1. **`data == null`** (stream never emitted) → show `loadingWidget`.
2. **`data.error != null && dataLength == 0`** → show `errorBuilder` output (full-screen error).
3. **`data.list` is empty** → show a nested `StreamBuilder<bool>` on `loadingStream`:
   - loading → `loadingWidget`
   - not loading → `noDataWidget`
4. Otherwise → show the `AnimatedList`.

If `refreshable: true`, the `AnimatedList` is wrapped in `RefreshIndicator` (calls `load(reload: true)`).

#### Default Fallback Widgets

| State | Default |
|---|---|
| No data | `Center(Text("No data", style: red))` |
| Loading | `Center(CircularProgressIndicator())` |
| Item loading | `Row > CircularProgressIndicator` (centered) |
| End of results | `Row > Icon(fiber_manual_record, grey)` (centered) |
| Full error | `Column > Icon(error, red) + Text("Could not load data")` |
| Element error | `Row > IconButton(refresh, red)` that calls `load()` |

#### `InfiniteScrollListViewState<T>` (public state)

Accessible via `GlobalKey<InfiniteScrollListViewState<T>>`. Exposes all `DataListLoaderMixin` methods: `add`, `update`, `removeItem`, `removeWhere`, `reload`, `getItem`, `getIndexOf`, `dataLength`, `dataList`.

---

## Data Flow

```
pageLoader(pageIndex)
        │
        ▼
  DataListLoaderMixin.load()
        │
        ├─ _loadingStream  →  StreamBuilder (loading indicator)
        ├─ _endOfResultStream  →  lastElement sentinel widget
        └─ _dataStream  →  StreamBuilder (main build)
                │
                └─ onAdd / onUpdate / onRemove
                        │
                        ▼
                  AnimatedList (animated insert/remove)
```

---

## Constraints & Edge Cases

- `pageLoader` returning `null` or `[]` signals end-of-results.
- Concurrent `load()` calls while loading are queued and drained in order.
- The sentinel item at index `dataLength` is not part of `dataList`; `listLength` equals `dataLength + 1` when the sentinel is present.
- `animateRemovingItemsOnReload: false` (default) clears without animation for snappier reloads.
- `betweenItemRenderDelay` is skipped for the first item of each page (`skipDelay: true` on `i == 0`).
- `pick` defaults to always preferring the incoming value on duplicates.
- `comparator` returning `0` triggers an update (remove + re-insert at same index) rather than a second copy being inserted.
