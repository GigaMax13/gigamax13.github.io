---
alwaysApply: false
description: "React hooks, component patterns, and TDD rules"
---

# React TDD Rules

> Extends: typescript.md (always load both for React projects)

Stack: React 18+, React Testing Library

## Hooks

### useEffect — Side Effects Only

```tsx
// ✅
useEffect(() => {
  setOrderedChapters(sortChapters(chapters));
}, [chapters]);
// ❌ useMemo for side effects
useMemo(() => {
  setOrderedChapters(sortChapters(chapters));
}, [chapters]);
```

### useMemo — Expensive Computations Only

```tsx
const sortedChapters = useMemo(
  () => chapters.sort((a, b) => a.order - b.order),
  [chapters],
);
```

### useCallback — Stable Function References

For memoized children or useEffect dependencies. Skip for simple handlers on native elements.

```tsx
const handleClick = useCallback(() => {
  onSelect(item.id);
}, [item.id, onSelect]);

const fetchData = useCallback(async () => {
  const data = await api.get(id);
  setData(data);
}, [id]);
useEffect(() => {
  fetchData();
}, [fetchData]);
```

### Dependency Arrays — All deps used inside must be listed

```tsx
// ✅
useEffect(() => {
  setTotal(price * quantity);
}, [price, quantity]);
// ❌ Missing dependency
useEffect(() => {
  setTotal(price * quantity);
}, [price]);
```

### Cleanup

```tsx
useEffect(() => {
  const subscription = api.subscribe(userId, handleUpdate);
  return () => subscription.unsubscribe();
}, [userId]);
```

### Don't Overuse Memoization

```tsx
// ❌
const error = useMemo(() => errorA ?? errorB, [errorA, errorB]);
// ✅
const error = errorA ?? errorB;
```

### No setState Wrapper Functions

```tsx
// ❌
const setFoo = () => setStateFoo(123);
// ✅
<button onClick={() => setStateFoo(123)}>Click</button>;

// ❌
const handleChange = (value: string) => setValue(value);
// ✅ (signatures match)
<Input onChange={setValue} />;
```

Exception: wrappers for parameter transforms, conditional logic, or side effects.

## Component Patterns

```tsx
{
  items.map((item) => <ItemCard key={item.id} item={item} />);
} // stable unique key
const [data, setData] = useState(() => computeExpensiveInitialValue()); // lazy init
setCount((prev) => prev + 1); // functional update
const fullName = `${first} ${last}`; // compute during render, not derived useState
```

## Anti-Patterns

| Pattern                                  | Solution                         |
| ---------------------------------------- | -------------------------------- |
| `useMemo` for side effects               | `useEffect`                      |
| `useEffect` without deps when not needed | Correct deps or `useMemo`        |
| Empty dep array with external refs       | Include deps                     |
| `useState` object without spread         | Functional updates with spread   |
| Derived state in useState                | Compute during render or useMemo |
| Inline object/array in deps              | Memoize or use primitives        |

## Testing

```tsx
import { render, screen, fireEvent } from "@testing-library/react";

it("increments counter on click", () => {
  render(<Counter />);
  fireEvent.click(screen.getByText("Increment"));
  expect(screen.getByText("Count: 1")).toBeInTheDocument();
});

it("loads and displays data", async () => {
  render(<DataComponent id="123" />);
  await waitFor(() => {
    expect(screen.getByText("Loaded")).toBeInTheDocument();
  });
});
```

## Standards

- Tests: `*.test.tsx` alongside components; source: `components/`, `hooks/`, `pages/`, `app/`
- Custom hooks in `hooks/` with `use` prefix; props interfaces named `{ComponentName}Props`

## Boundaries

| Always                | Ask First           | Never                       |
| --------------------- | ------------------- | --------------------------- |
| Exhaustive hook deps  | Context API changes | Inline styles               |
| Cleanup subscriptions | New state libraries | Class components (new code) |
| `key` on list items   | Router changes      |                             |
| Stable references     |                     |                             |
