import Link from "next/link";
import { listIdeas } from "@/lib/github";
import type { Idea } from "@/types";
import { StatusBadge } from "@/components/status-badge";
import { formatDate } from "@/lib/utils";
import { Card, CardContent } from "@/components/ui/card";
import { User2, CalendarDays, ArrowRight } from "lucide-react";

export const revalidate = 60;

export default async function DashboardPage() {
  let ideas: Idea[] = [];
  let error: string | null = null;

  try {
    ideas = await listIdeas();
  } catch {
    error = "아이디어 목록을 불러오는 데 실패했습니다. 환경 변수를 확인해주세요.";
  }

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-slate-900">아이디어 현황</h1>
        <p className="mt-1 text-slate-500">
          제출된 아이디어와 진행 상태를 확인할 수 있습니다.
        </p>
      </div>

      {error ? (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          {error}
        </div>
      ) : ideas.length === 0 ? (
        <div className="rounded-lg border border-slate-200 bg-slate-50 p-12 text-center">
          <p className="text-slate-500">아직 제출된 아이디어가 없습니다.</p>
          <p className="mt-1 text-sm text-slate-400">
            상단의 &apos;아이디어 제출&apos; 버튼을 눌러 첫 번째 아이디어를 등록해보세요.
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {ideas.map((idea) => (
            <Link key={idea.number} href={`/ideas/${idea.number}`}>
              <Card className="cursor-pointer transition-shadow hover:shadow-md">
                <CardContent className="p-5">
                  <div className="flex items-start justify-between gap-4">
                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <StatusBadge status={idea.status} />
                        <span className="text-xs text-slate-400">
                          #{idea.number}
                        </span>
                      </div>
                      <h2 className="mt-2 truncate text-base font-medium text-slate-900">
                        {idea.title}
                      </h2>
                      <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-slate-400">
                        {idea.submitter && (
                          <span className="flex items-center gap-1">
                            <User2 className="h-3 w-3" />
                            @{idea.submitter}
                          </span>
                        )}
                        <span className="flex items-center gap-1">
                          <CalendarDays className="h-3 w-3" />
                          {formatDate(idea.createdAt)}
                        </span>
                      </div>
                    </div>
                    <ArrowRight className="mt-1 h-4 w-4 shrink-0 text-slate-300" />
                  </div>
                </CardContent>
              </Card>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
