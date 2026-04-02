import Link from "next/link";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { Badge } from "@/components/ui/badge";
import {
  Lightbulb,
  ArrowRight,
  CheckCircle2,
  Search,
  Rocket,
  FolderOpen,
  MessageSquare,
  LogIn,
} from "lucide-react";

export default function GuidePage() {
  return (
    <div className="max-w-3xl mx-auto space-y-10">
      {/* Hero */}
      <section className="text-center space-y-4 pt-4">
        <div className="text-6xl">💡</div>
        <h1 className="text-3xl font-bold tracking-tight">
          idea-hub 사용 안내
        </h1>
        <p className="text-slate-500 text-lg max-w-xl mx-auto leading-relaxed">
          아이디어를 제출하면, 분석부터 개발까지 자동으로 이어지는 파이프라인
          플랫폼입니다.
        </p>
      </section>

      <Separator />

      {/* 한 눈에 보는 흐름 */}
      <section className="space-y-4">
        <h2 className="text-xl font-bold">한 눈에 보는 흐름</h2>
        <div className="flex flex-col sm:flex-row items-center gap-2 sm:gap-0 justify-between bg-slate-50 rounded-xl p-6">
          {[
            { emoji: "📝", label: "아이디어 제출" },
            { emoji: "🔍", label: "검토" },
            { emoji: "✅", label: "승인" },
            { emoji: "🚀", label: "개발" },
            { emoji: "🎉", label: "완료" },
          ].map((step, i) => (
            <div key={i} className="flex items-center gap-2 sm:gap-0">
              <div className="flex flex-col items-center gap-1 min-w-[72px]">
                <span className="text-2xl">{step.emoji}</span>
                <span className="text-xs font-medium text-slate-600">
                  {step.label}
                </span>
              </div>
              {i < 4 && (
                <ArrowRight className="hidden sm:block h-4 w-4 text-slate-300 mx-1" />
              )}
            </div>
          ))}
        </div>
      </section>

      <Separator />

      {/* 상세 단계 */}
      <section className="space-y-6">
        <h2 className="text-xl font-bold">상세 사용법</h2>

        {/* Step 1 */}
        <Card>
          <CardHeader className="pb-3">
            <div className="flex items-center gap-3">
              <div className="flex items-center justify-center w-8 h-8 rounded-full bg-amber-100 text-amber-700 font-bold text-sm">
                1
              </div>
              <div>
                <CardTitle className="text-base flex items-center gap-2">
                  <LogIn className="h-4 w-4" />
                  로그인
                </CardTitle>
                <CardDescription>
                  GitHub 계정으로 로그인합니다
                </CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent className="text-sm text-slate-600 space-y-2">
            <p>
              우측 상단의 <strong>&quot;로그인&quot;</strong> 버튼을 클릭하면
              GitHub 로그인 화면이 나타납니다.
            </p>
            <p>
              <strong>처음 사용하시나요?</strong> 관리자에게 GitHub 아이디를
              전달하여 접근 권한을 요청해주세요. 허용된 사용자만 플랫폼을 이용할
              수 있습니다.
            </p>
          </CardContent>
        </Card>

        {/* Step 2 */}
        <Card>
          <CardHeader className="pb-3">
            <div className="flex items-center gap-3">
              <div className="flex items-center justify-center w-8 h-8 rounded-full bg-amber-100 text-amber-700 font-bold text-sm">
                2
              </div>
              <div>
                <CardTitle className="text-base flex items-center gap-2">
                  <Lightbulb className="h-4 w-4" />
                  아이디어 제출
                </CardTitle>
                <CardDescription>
                  새로운 프로젝트 아이디어를 등록합니다
                </CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent className="text-sm text-slate-600 space-y-3">
            <p>
              상단 메뉴의 <strong>&quot;아이디어 제출&quot;</strong> 버튼을
              클릭하여 양식을 작성합니다.
            </p>
            <div className="bg-slate-50 rounded-lg p-4 space-y-2">
              <p className="font-medium text-slate-700">작성 항목:</p>
              <ul className="space-y-1.5">
                <li className="flex items-start gap-2">
                  <span className="text-red-400 mt-0.5">*</span>
                  <span>
                    <strong>프로젝트 제목</strong> — 아이디어를 한 줄로 요약
                  </span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-red-400 mt-0.5">*</span>
                  <span>
                    <strong>배경 / 문제</strong> — 왜 이 프로젝트가 필요한지
                  </span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-red-400 mt-0.5">*</span>
                  <span>
                    <strong>기대 효과</strong> — 만들면 어떤 가치가 있는지
                  </span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-red-400 mt-0.5">*</span>
                  <span>
                    <strong>핵심 기능</strong> — 꼭 필요한 기능 목록
                  </span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-slate-300 mt-0.5">-</span>
                  <span>
                    <strong>제외 범위</strong> — MVP에서 빼도 되는 것 (선택)
                  </span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-red-400 mt-0.5">*</span>
                  <span>
                    <strong>우선순위</strong> — 긴급 / 높음 / 보통 / 낮음
                  </span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-red-400 mt-0.5">*</span>
                  <span>
                    <strong>플랫폼</strong> — Web, Backend API, Flutter 등
                  </span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-slate-300 mt-0.5">-</span>
                  <span>
                    <strong>참고 자료</strong> — 관련 URL이나 이미지 (선택)
                  </span>
                </li>
              </ul>
              <p className="text-xs text-slate-400 mt-2">
                <span className="text-red-400">*</span> 표시는 필수 항목입니다
              </p>
            </div>
          </CardContent>
        </Card>

        {/* Step 3 */}
        <Card>
          <CardHeader className="pb-3">
            <div className="flex items-center gap-3">
              <div className="flex items-center justify-center w-8 h-8 rounded-full bg-amber-100 text-amber-700 font-bold text-sm">
                3
              </div>
              <div>
                <CardTitle className="text-base flex items-center gap-2">
                  <Search className="h-4 w-4" />
                  검토 및 승인
                </CardTitle>
                <CardDescription>
                  관리자가 아이디어를 검토합니다
                </CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent className="text-sm text-slate-600 space-y-2">
            <p>
              제출된 아이디어는 자동으로{" "}
              <Badge variant="secondary" className="text-xs">
                접수됨
              </Badge>{" "}
              →{" "}
              <Badge variant="secondary" className="text-xs">
                검토 필요
              </Badge>{" "}
              상태로 전환됩니다.
            </p>
            <p>
              관리자가 검토 후 아이디어를 <strong>승인</strong> 또는{" "}
              <strong>거절</strong>합니다. 승인된 아이디어는 개발 단계로
              넘어갑니다.
            </p>
            <p>
              아이디어 상세 페이지에서 댓글을 남겨 의견을 주고받을 수 있습니다.
            </p>
          </CardContent>
        </Card>

        {/* Step 4 */}
        <Card>
          <CardHeader className="pb-3">
            <div className="flex items-center gap-3">
              <div className="flex items-center justify-center w-8 h-8 rounded-full bg-amber-100 text-amber-700 font-bold text-sm">
                4
              </div>
              <div>
                <CardTitle className="text-base flex items-center gap-2">
                  <Rocket className="h-4 w-4" />
                  개발 진행
                </CardTitle>
                <CardDescription>
                  승인된 아이디어가 프로젝트로 만들어집니다
                </CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent className="text-sm text-slate-600 space-y-2">
            <p>
              승인된 아이디어는 자동으로 프로젝트 저장소가 생성되고, AI(Claude
              Code)가 분석 문서를 작성합니다.
            </p>
            <p>
              이후 개발이 시작되면 상태가{" "}
              <Badge variant="secondary" className="text-xs">
                개발 중
              </Badge>
              으로 변경되며, 완료되면{" "}
              <Badge variant="secondary" className="text-xs">
                완료
              </Badge>
              로 표시됩니다.
            </p>
          </CardContent>
        </Card>

        {/* Step 5 */}
        <Card>
          <CardHeader className="pb-3">
            <div className="flex items-center gap-3">
              <div className="flex items-center justify-center w-8 h-8 rounded-full bg-amber-100 text-amber-700 font-bold text-sm">
                5
              </div>
              <div>
                <CardTitle className="text-base flex items-center gap-2">
                  <FolderOpen className="h-4 w-4" />
                  대시보드에서 진행 현황 확인
                </CardTitle>
                <CardDescription>
                  모든 아이디어의 상태를 한눈에 봅니다
                </CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent className="text-sm text-slate-600 space-y-2">
            <p>
              메인 화면(대시보드)에서 제출된 모든 아이디어와 현재 상태를 확인할
              수 있습니다. 각 아이디어를 클릭하면 상세 내용, 댓글, 상태 변경
              이력을 볼 수 있습니다.
            </p>
          </CardContent>
        </Card>
      </section>

      <Separator />

      {/* 상태 설명 */}
      <section className="space-y-4">
        <h2 className="text-xl font-bold">상태 안내</h2>
        <p className="text-sm text-slate-500">
          아이디어는 아래 상태를 순서대로 거칩니다.
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {[
            {
              label: "📥 접수됨",
              color: "bg-slate-100",
              desc: "아이디어가 제출되었습니다",
            },
            {
              label: "🔍 검토 필요",
              color: "bg-yellow-50",
              desc: "관리자의 검토를 기다리고 있습니다",
            },
            {
              label: "✅ 승인됨",
              color: "bg-blue-50",
              desc: "개발이 승인되었습니다",
            },
            {
              label: "❌ 거절",
              color: "bg-red-50",
              desc: "이번에는 진행하지 않습니다",
            },
            {
              label: "⏸️ 보류",
              color: "bg-slate-50",
              desc: "나중에 다시 검토합니다",
            },
            {
              label: "🚀 개발 중",
              color: "bg-purple-50",
              desc: "현재 개발이 진행 중입니다",
            },
            {
              label: "🎉 완료",
              color: "bg-green-50",
              desc: "개발이 완료되었습니다",
            },
          ].map((status, i) => (
            <div
              key={i}
              className={`flex items-center gap-3 rounded-lg p-3 ${status.color}`}
            >
              <span className="text-sm font-medium min-w-[100px]">
                {status.label}
              </span>
              <span className="text-xs text-slate-500">{status.desc}</span>
            </div>
          ))}
        </div>
      </section>

      <Separator />

      {/* FAQ */}
      <section className="space-y-4">
        <h2 className="text-xl font-bold">자주 묻는 질문</h2>

        <div className="space-y-4">
          <Card>
            <CardContent className="pt-5 space-y-1">
              <p className="font-medium flex items-center gap-2">
                <MessageSquare className="h-4 w-4 text-slate-400" />
                로그인했는데 &quot;접근 권한이 없습니다&quot;가 나와요
              </p>
              <p className="text-sm text-slate-500 pl-6">
                관리자에게 GitHub 아이디를 전달하여 허용 목록에 추가를
                요청해주세요.
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-5 space-y-1">
              <p className="font-medium flex items-center gap-2">
                <MessageSquare className="h-4 w-4 text-slate-400" />
                아이디어를 수정하고 싶어요
              </p>
              <p className="text-sm text-slate-500 pl-6">
                아이디어 상세 페이지에서 댓글로 수정 내용을 남기면 관리자가
                반영합니다. 또는 GitHub Issue에서 직접 수정할 수도 있습니다.
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-5 space-y-1">
              <p className="font-medium flex items-center gap-2">
                <MessageSquare className="h-4 w-4 text-slate-400" />
                승인된 아이디어는 언제 개발되나요?
              </p>
              <p className="text-sm text-slate-500 pl-6">
                승인 후 우선순위에 따라 순차적으로 개발이 시작됩니다. 진행
                상태는 대시보드에서 실시간으로 확인할 수 있습니다.
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-5 space-y-1">
              <p className="font-medium flex items-center gap-2">
                <MessageSquare className="h-4 w-4 text-slate-400" />
                GitHub 계정이 없어요
              </p>
              <p className="text-sm text-slate-500 pl-6">
                <a
                  href="https://github.com/signup"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-blue-600 underline underline-offset-2"
                >
                  github.com/signup
                </a>
                에서 무료로 계정을 만들 수 있습니다. 가입 후 관리자에게 아이디를
                알려주세요.
              </p>
            </CardContent>
          </Card>
        </div>
      </section>

      <Separator />

      {/* CTA */}
      <section className="text-center space-y-4 pb-8">
        <h2 className="text-xl font-bold">시작해볼까요?</h2>
        <div className="flex flex-col sm:flex-row gap-3 justify-center">
          <Button asChild size="lg">
            <Link href="/login">
              <LogIn className="h-4 w-4" />
              로그인하기
            </Link>
          </Button>
          <Button asChild size="lg" variant="outline">
            <Link href="/">
              <FolderOpen className="h-4 w-4" />
              대시보드 보기
            </Link>
          </Button>
        </div>
      </section>
    </div>
  );
}
