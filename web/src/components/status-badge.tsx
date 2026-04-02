import { cn, getStatusColor, getStatusLabel } from "@/lib/utils";
import type { IdeaStatus } from "@/types";

interface StatusBadgeProps {
  status: IdeaStatus;
  className?: string;
}

export function StatusBadge({ status, className }: StatusBadgeProps) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-medium",
        getStatusColor(status),
        className
      )}
    >
      {getStatusLabel(status)}
    </span>
  );
}
