import { ORDER_STATUS_LABELS } from "@/lib/labels";
import type { OrderStatus } from "@/lib/types";
import { cn } from "@/lib/utils";

const STATUS_STYLES: Record<OrderStatus, string> = {
  new: "bg-accent/10 text-accent dark:bg-accent/20",
  preparing: "bg-cream-200 text-coffee-700 dark:bg-cream-200/15",
  ready: "bg-mint-100 text-emerald-700 dark:bg-mint-500/15 dark:text-mint-300",
  done: "bg-coffee-900/5 text-coffee-500 dark:bg-white/10",
  cancelled: "bg-red-50 text-red-600 dark:bg-red-500/15 dark:text-red-400"
};

export function StatusBadge({
  status,
  className
}: {
  status: OrderStatus;
  className?: string;
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold",
        STATUS_STYLES[status],
        className
      )}
    >
      {ORDER_STATUS_LABELS[status]}
    </span>
  );
}
