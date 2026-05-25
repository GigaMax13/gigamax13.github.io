---
alwaysApply: false
description: "Guard clause patterns for reducing nesting"
---

# Guard Clauses

- [ ] Check edge cases/errors at function start, return immediately
- [ ] Invert conditions: `if (!isValid) return;` not `if (isValid) { ... }`
- [ ] Keep "happy path" at top level, remove `else` blocks

```typescript
// ❌
function processOrder(order: Order | null) {
  if (order != null) {
    if (order.isValid) {
      if (order.isPaid) {
        return "Order Processed";
      } else {
        return "Not Paid";
      }
    } else {
      return "Invalid Order";
    }
  } else {
    return "No Order";
  }
}

// ✅
function processOrder(order: Order | null) {
  if (order == null) return "No Order";
  if (!order.isValid) return "Invalid Order";
  if (!order.isPaid) return "Not Paid";
  return "Order Processed";
}
```
