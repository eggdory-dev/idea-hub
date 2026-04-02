"use client";

import { useState } from "react";
import { useSession } from "next-auth/react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import type { IdeaFormData } from "@/types";

const initialFormData: IdeaFormData = {
  title: "",
  background: "",
  expectedEffect: "",
  coreFeatures: "",
  exclusions: "",
  priority: "",
  platform: "",
  references: "",
};

export default function NewIdeaPage() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const [formData, setFormData] = useState<IdeaFormData>(initialFormData);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (status === "loading") {
    return (
      <div className="flex items-center justify-center py-24">
        <div className="h-6 w-6 animate-spin rounded-full border-2 border-slate-900 border-t-transparent" />
      </div>
    );
  }

  if (!session) {
    return (
      <div className="flex flex-col items-center justify-center py-24 text-center">
        <p className="text-slate-600">아이디어를 제출하려면 GitHub 계정으로 로그인해주세요.</p>
      </div>
    );
  }

  const handleChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>
  ) => {
    setFormData((prev) => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const handleSelectChange = (name: keyof IdeaFormData) => (value: string) => {
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (
      !formData.title ||
      !formData.background ||
      !formData.expectedEffect ||
      !formData.coreFeatures ||
      !formData.priority ||
      !formData.platform
    ) {
      setError("필수 항목(*)을 모두 입력해주세요.");
      return;
    }

    setIsSubmitting(true);
    try {
      const res = await fetch("/api/ideas", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(formData),
      });

      const data = await res.json() as { number?: number; error?: string };

      if (!res.ok) {
        throw new Error(data.error ?? "제출에 실패했습니다.");
      }

      router.push(`/ideas/${data.number}`);
    } catch (err) {
      setError(err instanceof Error ? err.message : "알 수 없는 오류가 발생했습니다.");
      setIsSubmitting(false);
    }
  };

  return (
    <div className="mx-auto max-w-2xl">
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-slate-900">아이디어 제출</h1>
        <p className="mt-1 text-slate-500">
          새로운 아이디어를 제출합니다. 제출 후 GitHub Issue로 등록됩니다.
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-lg">아이디어 정보</CardTitle>
          <CardDescription>
            * 표시 항목은 필수입니다.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-6">

            {/* 프로젝트 제목 */}
            <div className="space-y-2">
              <Label htmlFor="title">
                프로젝트 제목 <span className="text-red-500">*</span>
              </Label>
              <Input
                id="title"
                name="title"
                placeholder="예: AI 기반 일정 관리 앱"
                value={formData.title}
                onChange={handleChange}
                required
              />
            </div>

            <Separator />

            {/* 배경/문제 */}
            <div className="space-y-2">
              <Label htmlFor="background">
                배경 / 문제 <span className="text-red-500">*</span>
              </Label>
              <p className="text-xs text-slate-400">
                이 아이디어가 필요한 이유, 해결하려는 문제
              </p>
              <Textarea
                id="background"
                name="background"
                placeholder="현재 어떤 문제가 있고, 왜 이것이 필요한지 설명해주세요."
                rows={4}
                value={formData.background}
                onChange={handleChange}
                required
              />
            </div>

            {/* 기대 효과 */}
            <div className="space-y-2">
              <Label htmlFor="expectedEffect">
                기대 효과 <span className="text-red-500">*</span>
              </Label>
              <p className="text-xs text-slate-400">
                이 아이디어가 실현되면 어떤 효과가 있는지
              </p>
              <Textarea
                id="expectedEffect"
                name="expectedEffect"
                placeholder="사용자 경험 개선, 비용 절감, 시간 단축 등"
                rows={3}
                value={formData.expectedEffect}
                onChange={handleChange}
                required
              />
            </div>

            {/* 핵심 기능 */}
            <div className="space-y-2">
              <Label htmlFor="coreFeatures">
                핵심 기능 <span className="text-red-500">*</span>
              </Label>
              <p className="text-xs text-slate-400">
                반드시 포함되어야 하는 기능 목록
              </p>
              <Textarea
                id="coreFeatures"
                name="coreFeatures"
                placeholder={"- 기능 1: 설명\n- 기능 2: 설명\n- 기능 3: 설명"}
                rows={4}
                value={formData.coreFeatures}
                onChange={handleChange}
                required
              />
            </div>

            {/* 제외 범위 */}
            <div className="space-y-2">
              <Label htmlFor="exclusions">제외 범위</Label>
              <p className="text-xs text-slate-400">
                이번 범위에서 제외할 것들 (선택)
              </p>
              <Textarea
                id="exclusions"
                name="exclusions"
                placeholder="MVP에서 제외할 기능이나 범위를 명시해주세요."
                rows={3}
                value={formData.exclusions}
                onChange={handleChange}
              />
            </div>

            <Separator />

            {/* 우선순위 & 플랫폼 */}
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label>
                  우선순위 <span className="text-red-500">*</span>
                </Label>
                <Select
                  value={formData.priority}
                  onValueChange={handleSelectChange("priority")}
                  required
                >
                  <SelectTrigger>
                    <SelectValue placeholder="선택해주세요" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="urgent">🔴 긴급 (Urgent)</SelectItem>
                    <SelectItem value="high">🟠 높음 (High)</SelectItem>
                    <SelectItem value="medium">🟡 보통 (Medium)</SelectItem>
                    <SelectItem value="low">🟢 낮음 (Low)</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label>
                  플랫폼 <span className="text-red-500">*</span>
                </Label>
                <Select
                  value={formData.platform}
                  onValueChange={handleSelectChange("platform")}
                  required
                >
                  <SelectTrigger>
                    <SelectValue placeholder="선택해주세요" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="Web">Web</SelectItem>
                    <SelectItem value="Backend (API)">Backend (API)</SelectItem>
                    <SelectItem value="Mobile (Flutter)">Mobile (Flutter)</SelectItem>
                    <SelectItem value="Mobile (React Native)">Mobile (React Native)</SelectItem>
                    <SelectItem value="Monorepo (Full-stack)">Monorepo (Full-stack)</SelectItem>
                    <SelectItem value="CLI / Script">CLI / Script</SelectItem>
                    <SelectItem value="기타">기타</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>

            {/* 참고 자료 */}
            <div className="space-y-2">
              <Label htmlFor="references">참고 자료</Label>
              <p className="text-xs text-slate-400">
                참고할 서비스, 링크, 디자인, 문서 등 (선택)
              </p>
              <Textarea
                id="references"
                name="references"
                placeholder="URL, 스크린샷, 경쟁 서비스 등"
                rows={3}
                value={formData.references}
                onChange={handleChange}
              />
            </div>

            {error && (
              <div className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
                {error}
              </div>
            )}

            <div className="flex justify-end gap-3 pt-2">
              <Button
                type="button"
                variant="outline"
                onClick={() => router.back()}
                disabled={isSubmitting}
              >
                취소
              </Button>
              <Button type="submit" disabled={isSubmitting}>
                {isSubmitting ? (
                  <>
                    <span className="mr-2 inline-block h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
                    제출 중...
                  </>
                ) : (
                  "아이디어 제출"
                )}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
