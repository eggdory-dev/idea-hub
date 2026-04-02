"use client";

import Link from "next/link";
import { useSession, signIn, signOut } from "next-auth/react";
import { Button } from "@/components/ui/button";
import { Lightbulb, LogIn, LogOut, PlusCircle } from "lucide-react";

export function Header() {
  const { data: session, status } = useSession();

  return (
    <header className="sticky top-0 z-50 w-full border-b border-slate-200 bg-white/95 backdrop-blur supports-[backdrop-filter]:bg-white/60">
      <div className="mx-auto max-w-5xl flex h-14 items-center justify-between px-4">
        <Link href="/" className="flex items-center gap-2 font-semibold text-slate-900">
          <Lightbulb className="h-5 w-5 text-amber-500" />
          <span>idea-hub</span>
        </Link>

        <nav className="flex items-center gap-3">
          {status === "loading" ? (
            <div className="h-9 w-20 animate-pulse rounded-md bg-slate-100" />
          ) : session ? (
            <>
              <span className="hidden text-sm text-slate-500 sm:inline">
                @{(session.user as { username?: string }).username ?? session.user?.name}
              </span>
              <Button asChild size="sm" variant="default">
                <Link href="/new">
                  <PlusCircle className="h-4 w-4" />
                  아이디어 제출
                </Link>
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => signOut({ callbackUrl: "/" })}
              >
                <LogOut className="h-4 w-4" />
                <span className="hidden sm:inline">로그아웃</span>
              </Button>
            </>
          ) : (
            <Button
              size="sm"
              onClick={() => signIn("github", { callbackUrl: "/" })}
            >
              <LogIn className="h-4 w-4" />
              GitHub 로그인
            </Button>
          )}
        </nav>
      </div>
    </header>
  );
}
