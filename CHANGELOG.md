# 1.2.0
Adds optional `pageSize` and `isEndOfPage` parameters to `InfiniteScrollListView`.
- When `pageSize` is set, the list stops paginating as soon as a page returns fewer items than `pageSize`, avoiding an extra empty-page round-trip.
- When `isEndOfPage` is set, it overrides all default end-of-page logic with a custom predicate.
- Fallback order: `isEndOfPage` → `pageSize` → `page.isEmpty` → `null response`.

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