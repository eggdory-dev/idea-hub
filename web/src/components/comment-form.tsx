"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Send } from "lucide-react";

export function CommentForm({ issueNumber }: { issueNumber: number }) {
  const [body, setBody] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!body.trim()) return;

    setLoading(true);
    setError("");
    setSuccess(false);

    try {
      const res = await fetch(`/api/ideas/${issueNumber}/comments`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ body: body.trim() }),
      });

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || "댓글 등록 실패");
      }

      setBody("");
      setSuccess(true);
      setTimeout(() => setSuccess(false), 3000);
      // 페이지 새로고침으로 댓글 반영
      window.location.reload();
    } catch (err) {
      setError(err instanceof Error ? err.message : "댓글 등록에 실패했습니다.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-3">
      <Textarea
        placeholder="댓글을 입력하세요..."
        value={body}
        onChange={(e) => setBody(e.target.value)}
        rows={3}
        className="resize-none"
      />
      {error && (
        <p className="text-sm text-red-500">{error}</p>
      )}
      {success && (
        <p className="text-sm text-green-600">댓글이 등록되었습니다!</p>
      )}
      <div className="flex justify-end">
        <Button type="submit" size="sm" disabled={loading || !body.trim()}>
          <Send className="h-4 w-4" />
          {loading ? "등록 중..." : "댓글 등록"}
        </Button>
      </div>
    </form>
  );
}
