"use client";

import Link from "next/link";
import { signOut } from "next-auth/react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { HelpCircle } from "lucide-react";

export default function UnauthorizedPage() {
  return (
    <div className="flex min-h-[80vh] items-center justify-center px-4">
      <Card className="w-full max-w-sm shadow-lg">
        <CardHeader className="text-center space-y-2">
          <div className="text-4xl">🔒</div>
          <CardTitle className="text-xl">접근 권한이 없습니다</CardTitle>
        </CardHeader>
        <CardContent className="text-center space-y-3">
          <p className="text-sm text-slate-500">
            이 플랫폼은 허용된 사용자만 이용할 수 있습니다.
            <br />
            관리자에게 GitHub 아이디를 전달하여 권한을 요청해주세요.
          </p>
          <Button
            variant="outline"
            className="w-full"
            onClick={() => signOut({ callbackUrl: "/login" })}
          >
            다른 계정으로 로그인
          </Button>
          <Button asChild variant="ghost" className="w-full text-slate-500">
            <Link href="/guide">
              <HelpCircle className="h-4 w-4 mr-2" />
              사용 안내 보기
            </Link>
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
