import type { NextAuthOptions } from "next-auth";
import GitHubProvider from "next-auth/providers/github";

// 허용된 GitHub 사용자 목록
// 환경변수 ALLOWED_USERS에 쉼표로 구분하여 설정 (없으면 모두 허용)
function getAllowedUsers(): string[] {
  const env = process.env.ALLOWED_USERS;
  if (!env) return [];
  return env.split(",").map((u) => u.trim().toLowerCase()).filter(Boolean);
}

export function isUserAllowed(username: string): boolean {
  const allowed = getAllowedUsers();
  if (allowed.length === 0) return true; // allowlist가 비어있으면 모두 허용
  return allowed.includes(username.toLowerCase());
}

export const authOptions: NextAuthOptions = {
  providers: [
    GitHubProvider({
      clientId: process.env.GITHUB_ID ?? "",
      clientSecret: process.env.GITHUB_SECRET ?? "",
    }),
  ],
  callbacks: {
    async signIn({ profile }) {
      const username = (profile as { login?: string })?.login;
      if (!username) return false;

      // allowlist 체크
      if (!isUserAllowed(username)) {
        return "/unauthorized";
      }
      return true;
    },
    async session({ session, token }) {
      if (session.user && token.sub) {
        (
          session.user as {
            name?: string | null;
            email?: string | null;
            image?: string | null;
            username?: string;
          }
        ).username = token.username as string;
      }
      return session;
    },
    async jwt({ token, profile }) {
      if (profile) {
        token.username = (profile as { login?: string }).login;
      }
      return token;
    },
  },
  pages: {
    signIn: "/login",
    error: "/login",
  },
};
