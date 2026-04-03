import { notFound } from "next/navigation";
import Link from "next/link";
import { getIdea, getIdeaComments } from "@/lib/github";
import { StatusBadge } from "@/components/status-badge";
import { CommentForm } from "@/components/comment-form";
import { CommentItem } from "@/components/comment-item";
import { StatusChanger } from "@/components/status-changer";
import { formatDate } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import {
  ArrowLeft,
  CalendarDays,
  ExternalLink,
  MessageSquare,
  User2,
} from "lucide-react";

export const dynamic = "force-dynamic";

interface PageProps {
  params: Promise<{ number: string }>;
}

export default async function IdeaDetailPage({ params }: PageProps) {
  const { number: numberStr } = await params;
  const number = parseInt(numberStr, 10);

  if (isNaN(number)) notFound();

  const [idea, comments] = await Promise.all([
    getIdea(number),
    getIdeaComments(number).catch(() => []),
  ]);

  if (!idea) notFound();

  const bodyLines = idea.body ?? "";

  return (
    <div className="mx-auto max-w-2xl">
      {/* Back button */}
      <div className="mb-6">
        <Button asChild variant="ghost" size="sm" className="-ml-2">
          <Link href="/">
            <ArrowLeft className="h-4 w-4" />
            목록으로
          </Link>
        </Button>
      </div>

      {/* Header */}
      <div className="mb-6">
        <div className="flex flex-wrap items-center gap-2">
          <StatusBadge status={idea.status} />
          <span className="text-sm text-slate-400">#{idea.number}</span>
        </div>
        <h1 className="mt-3 text-2xl font-bold text-slate-900">{idea.title}</h1>
        <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-slate-500">
          {idea.submitter && (
            <span className="flex items-center gap-1.5">
              <User2 className="h-4 w-4" />
              @{idea.submitter}
            </span>
          )}
          <span className="flex items-center gap-1.5">
            <CalendarDays className="h-4 w-4" />
            {formatDate(idea.createdAt)}
          </span>
          <a
            href={idea.htmlUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1.5 hover:text-slate-900"
          >
            <ExternalLink className="h-4 w-4" />
            GitHub에서 보기
          </a>
        </div>
      </div>

      {/* Status Changer */}
      <Card className="mb-6">
        <CardContent className="p-4">
          <StatusChanger issueNumber={number} currentStatus={idea.status} />
        </CardContent>
      </Card>

      <Separator className="mb-6" />

      {/* Body */}
      <Card className="mb-6">
        <CardContent className="p-6">
          <div className="prose prose-slate max-w-none">
            <BodyRenderer body={bodyLines} />
          </div>
        </CardContent>
      </Card>

      {/* Comments */}
      <div className="mb-28">
        <h2 className="mb-4 flex items-center gap-2 text-base font-semibold text-slate-900">
          <MessageSquare className="h-4 w-4" />
          댓글 {comments.length}개
        </h2>

        {comments.length > 0 && (
          <div className="space-y-3">
            {[...comments].reverse().map((comment) => (
              <CommentItem
                key={comment.id}
                author={comment.author}
                date={formatDate(comment.createdAt)}
                body={comment.body}
              />
            ))}
          </div>
        )}
      </div>

      {/* Floating Comment Form */}
      <div className="fixed bottom-0 left-0 right-0 z-40 border-t border-slate-200 bg-white/95 backdrop-blur supports-[backdrop-filter]:bg-white/80">
        <div className="mx-auto max-w-2xl px-4 py-3">
          <CommentForm issueNumber={number} />
        </div>
      </div>
    </div>
  );
}

function BodyRenderer({ body }: { body: string }) {
  const sections = body.split(/^## /m).filter(Boolean);

  if (sections.length === 0) {
    return (
      <pre className="whitespace-pre-wrap font-sans text-sm text-slate-700">
        {body}
      </pre>
    );
  }

  return (
    <div className="space-y-5">
      {sections.map((section, i) => {
        const newlineIdx = section.indexOf("\n");
        const heading = newlineIdx === -1 ? section : section.slice(0, newlineIdx);
        const content = newlineIdx === -1 ? "" : section.slice(newlineIdx + 1).trim();

        // "---" 이하 (제출자 정보 등) 숨기기
        if (heading.startsWith("---")) return null;

        return (
          <div key={i}>
            <h3 className="mb-1.5 text-sm font-semibold text-slate-500 uppercase tracking-wide">
              {heading}
            </h3>
            <p className="whitespace-pre-wrap text-sm leading-relaxed text-slate-800">
              {content}
            </p>
          </div>
        );
      })}
    </div>
  );
}
