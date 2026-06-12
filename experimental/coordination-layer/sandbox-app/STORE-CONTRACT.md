# Store interface contract

The stable contract between the two halves of the Trinity Run 2 sandbox app.
**The HTTP half codes against this file; it does not read the store half's
code. The store half implements exactly this.** Neither half may change this
contract — if it feels wrong, flag it to the coordinator, don't edit it.

## `createStore()`

```
createStore() -> store
```

Returns a fresh in-memory store. No arguments. No persistence — state lives for
the lifetime of the process.

## `store` methods

```
store.create(todo)      -> { id, title, done, createdAt }   // throws on invalid input
store.get(id)           -> todo | null
store.list(query)       -> todo[]                           // query: { done?, sort? }
store.update(id, patch) -> todo | null
store.remove(id)        -> boolean
```

- **`create(todo)`** — validates input (see TASK-B2), assigns a unique string
  `id` and an ISO-string `createdAt`, stores and returns the full todo. Throws
  on invalid input.
- **`get(id)`** — returns the todo, or `null` if no todo has that id.
- **`list(query)`** — returns an array of todos. `query` is optional;
  `{ done?: boolean, sort?: 'asc' | 'desc' }` filters by `done` and sorts by
  `createdAt` (see TASK-B3). No query → all todos.
- **`update(id, patch)`** — applies `patch` (a partial todo) to an existing
  todo, validates the result, returns the updated todo; `null` if the id is
  unknown. Throws on invalid patched input.
- **`remove(id)`** — deletes the todo; returns `true` if something was
  removed, `false` if the id was unknown.

## The `todo` shape

```
{
  id:        string,        // unique, store-assigned
  title:     string,        // required, non-empty
  done:      boolean,       // defaults to false on create
  createdAt: string         // ISO 8601, store-assigned
}
```

## Notes

- Validation rules (what makes input valid) are defined by **TASK-B2**.
- Query/filter/sort semantics are defined by **TASK-B3**.
- The HTTP handlers (**TASK-A3**) are tested against a *stub* store that
  honors this contract — they never import the real store.
