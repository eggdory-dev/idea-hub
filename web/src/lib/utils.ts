import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";
import type { IdeaStatus } from "@/types";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function getStatusLabel(status: IdeaStatus): string {
  const labels: Record<IdeaStatus, string> = {
    intake: "접수됨",
    "needs-review": "검토 필요",
    approved: "승인됨",
    building: "개발 중",
    done: "완료",
    rejected: "반려",
    "on-hold": "보류",
  };
  return labels[status] ?? status;
}

export function getStatusColor(status: IdeaStatus): string {
  const colors: Record<IdeaStatus, string> = {
    intake: "bg-slate-100 text-slate-700 border-slate-200",
    "needs-review": "bg-yellow-50 text-yellow-700 border-yellow-200",
    approved: "bg-blue-50 text-blue-700 border-blue-200",
    building: "bg-purple-50 text-purple-700 border-purple-200",
    done: "bg-green-50 text-green-700 border-green-200",
    rejected: "bg-red-50 text-red-700 border-red-200",
    "on-hold": "bg-gray-100 text-gray-700 border-gray-200",
  };
  return colors[status] ?? "bg-gray-100 text-gray-700 border-gray-200";
}

export function extractStatusFromLabels(labels: string[]): IdeaStatus {
  const statusLabels: IdeaStatus[] = [
    "intake",
    "needs-review",
    "approved",
    "building",
    "done",
    "rejected",
    "on-hold",
  ];
  for (const label of labels) {
    if (statusLabels.includes(label as IdeaStatus)) {
      return label as IdeaStatus;
    }
  }
  return "intake";
}

export function extractSubmitterFromBody(body: string | null): string | null {
  if (!body) return null;
  const match = body.match(/제출자:\s*@(\S+)/);
  return match ? match[1] : null;
}

export function formatDate(dateString: string): string {
  const date = new Date(dateString);
  return new Intl.DateTimeFormat("ko-KR", {
    year: "numeric",
    month: "long",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}
