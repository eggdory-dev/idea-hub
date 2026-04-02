"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";

const STATUSES = [
  { value: "intake", label: "📥 접수", color: "bg-yellow-100 text-yellow-800" },
  { value: "needs-review", label: "🔍 검토 중", color: "bg-blue-100 text-blue-800" },
  { value: "approved", label: "✅ 승인", color: "bg-green-100 text-green-800" },
  { value: "rejected", label: "❌ 거절", color: "bg-red-100 text-red-800" },
  { value: "on-hold", label: "⏸️ 보류", color: "bg-gray-100 text-gray-800" },
  { value: "building", label: "🚀 개발 중", color: "bg-purple-100 text-purple-800" },
  { value: "done", label: "✅ 완료", color: "bg-emerald-100 text-emerald-800" },
];

export function StatusChanger({
  issueNumber,
  currentStatus,
}: {
  issueNumber: number;
  currentStatus: string;
}) {
  const [loading, setLoading] = useState<string | null>(null);
  const [error, setError] = useState("");

  const handleChange = async (newStatus: string) => {
    if (newStatus === currentStatus) return;

    setLoading(newStatus);
    setError("");

    try {
      const res = await fetch(`/api/ideas/${issueNumber}/status`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ status: newStatus }),
      });

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || "상태 변경 실패");
      }

      window.location.reload();
    } catch (err) {
      setError(err instanceof Error ? err.message : "상태 변경에 실패했습니다.");
    } finally {
      setLoading(null);
    }
  };

  return (
    <div className="space-y-3">
      <h3 className="text-sm font-semibold text-slate-700">상태 변경</h3>
      <div className="flex flex-wrap gap-2">
        {STATUSES.map((s) => (
          <Button
            key={s.value}
            variant={currentStatus === s.value ? "default" : "outline"}
            size="sm"
            className={
              currentStatus === s.value
                ? "pointer-events-none"
                : ""
            }
            disabled={loading !== null}
            onClick={() => handleChange(s.value)}
          >
            {loading === s.value ? "변경 중..." : s.label}
          </Button>
        ))}
      </div>
      {error && <p className="text-sm text-red-500">{error}</p>}
    </div>
  );
}
