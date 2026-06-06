# Code Analysis: infinite_scroll_list_view

## Bugs

### 1. ~~`removeItem` reverts its own data change~~ ✅ Fixed
The stale `dataStream.add(DataWrapper(_list, null))` call that overwrote the correctly-updated stream was removed.

---

### 2. ~~`removeWere` infinite loop~~ ✅ Fixed
Renamed to `removeWhere`. Loop now reads `dataList` on each iteration so it always sees fresh state. `removeItem` is now properly awaited.

---

### 3. ~~`_addItem` off-by-one~~ ✅ Fixed
Both `max(0, _list.length - 1)` and `_list.length - 1` were replaced with `_list.length`.

---

### 4. ~~`dispose()` calls `super.dispose()` first~~ ✅ Fixed
`disposeMixin()` now runs before `super.dispose()`. The erroneous manual `state.dispose()` call on the child state was also removed.

---

### 5. ~~`_innterCtrl` is untyped~~ ✅ Fixed
Changed to `late final StreamController<T> _innterCtrl`.

---

## Design Issues / Improvements

### 6. ~~`errorStream` is dead code~~ ✅ Fixed
Removed entirely.

---

### 7. ~~Unbounded operation queue~~ ✅ Fixed
`queue.clear()` is now called before `queue.add(...)`, so at most one pending load is ever queued. Rapid scroll events or repeated calls no longer accumulate stale entries.

---

### 8. ~~`getIndexOf` returns -1 with no comparator~~ ✅ Fixed
Falls back to `==` equality when no comparator is provided: `comparator() ?? (a, b) => a == b ? 0 : -1`.

---

### 9. ~~Sorting convention undocumented~~ ✅ Fixed
Doc comment added to `comparator()` explaining the convention: positive = `a` before `b` (descending), zero = duplicate (update), negative = `a` after `b`.

---

### 10. ~~Stale TODO comment~~ ✅ Fixed
Removed. `RefreshIndicator` was already implemented.

---

### 11. ~~Missing `const` constructors for default widgets~~ ✅ Fixed
`SizedBox.shrink()`, default loading/error rows, and other default widgets now use `const` where the Dart 2.19 SDK allows.

---

### 12. ~~`loadingStream` and `dataStream` are public fields~~ ✅ Fixed
Both are now private `ReactiveValue` instances exposed only as read-only `Stream<>` getters.

---

## Summary

All 12 issues resolved across three PRs:
- Bugs 1–5, issues 6, 8–12: fixed as part of the initial refactor.
- Issue 7 (unbounded queue): fixed by replacing `queue.add` with `queue.clear` + `queue.add`.
