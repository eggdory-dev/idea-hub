import type { NextAuthOptions } from "next-auth";
import GitHubProvider from "next-auth/providers/github";

export const authOptions: NextAuthOptions = {
  providers: [
    GitHubProvider({
      clientId: process.env.GITHUB_ID ?? "",
      clientSecret: process.env.GITHUB_SECRET ?? "",
    }),
  ],
  callbacks: {
    async session({ session, token }) {
      if (session.user && token.sub) {
        (session.user as { name?: string | null; email?: string | null; image?: string | null; username?: string }).username =
          token.username as string;
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
    signIn: "/",
  },
};
