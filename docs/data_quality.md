# Data Quality Summary

## Source validation

| Check | Result |
|---|---:|
| Sales rows | 125,751 |
| Inventory rows | 284,755 |
| Sales duplicate records | 0 |
| Inventory duplicate records | 0 |
| Unique products | 2,326 |
| Stores | 40 |
| Suppliers | 30 |

## Inventory interval analysis

Inventory records contain validity intervals and are not a simple daily snapshot.

The interval-gap analysis identified:

- **8,607** internal inventory gaps
- **299,671** total gap days
- **298 days** largest observed gap
- **~34.82 days** average gap length

These gaps are explicitly treated as **unknown inventory availability**, not zero stock.

## Inventory position

The final product-store-date inventory classification preserved all **16,546,616** Gold demand rows:

- Inventory Available: 7,265,315
- Inventory Gap: 8,432,437
- No Inventory History: 848,864

## Negative inventory

Negative stock records:

- Negative Stock: 46,571
- Positive Stock: 6,484,450
- Zero Stock: 734,294

Negative inventory is treated as an **Inventory Deficit** in business decisioning.

## Gold validation

| Gold table | Rows |
|---|---:|
| `gold_daily_demand` | 16,546,616 |
| `gold_inventory_risk` | 50,447 |
| `gold_replenishment_recommendations` | 3,763 |

## Important modeling decision

Sales and inventory do not have identical product-store coverage. Therefore, an unconditional inner join would silently remove valid demand records.

The pipeline instead preserves the complete demand calendar and classifies inventory availability explicitly.
