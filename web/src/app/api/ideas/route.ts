import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { createIdea, listIdeas } from "@/lib/github";
import type { IdeaFormData } from "@/types";

export async function GET() {
  try {
    const ideas = await listIdeas();
    return NextResponse.json(ideas);
  } catch (error) {
    console.error("Failed to list ideas:", error);
    return NextResponse.json(
      { error: "아이디어 목록을 불러오는 데 실패했습니다." },
      { status: 500 }
    );
  }
}

export async function POST(request: NextRequest) {
  const session = await getServerSession(authOptions);

  if (!session?.user) {
    return NextResponse.json(
      { error: "로그인이 필요합니다." },
      { status: 401 }
    );
  }

  const username =
    (session.user as { username?: string }).username ??
    session.user.name ??
    "unknown";

  try {
    const body = await request.json() as IdeaFormData;

    const { title, background, expectedEffect, coreFeatures, priority, platform } =
      body;

    if (!title || !background || !expectedEffect || !coreFeatures || !priority || !platform) {
      return NextResponse.json(
        { error: "필수 항목을 모두 입력해주세요." },
        { status: 400 }
      );
    }

    const issueNumber = await createIdea(body, username);

    return NextResponse.json({ number: issueNumber }, { status: 201 });
  } catch (error) {
    console.error("Failed to create idea:", error);
    return NextResponse.json(
      { error: "아이디어 제출에 실패했습니다." },
      { status: 500 }
    );
  }
}
