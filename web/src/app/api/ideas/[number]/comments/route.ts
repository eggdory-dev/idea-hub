import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { addComment, getIdea } from "@/lib/github";
import { sendTelegramNotification } from "@/lib/telegram";
import { sendDiscordNotification } from "@/lib/discord";

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ number: string }> }
) {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: "로그인이 필요합니다." }, { status: 401 });
  }

  const { number: numberStr } = await params;
  const issueNumber = parseInt(numberStr, 10);
  if (isNaN(issueNumber)) {
    return NextResponse.json({ error: "유효하지 않은 아이디어 번호" }, { status: 400 });
  }

  const { body } = (await request.json()) as { body?: string };
  if (!body?.trim()) {
    return NextResponse.json({ error: "댓글 내용을 입력해주세요." }, { status: 400 });
  }

  const username =
    (session.user as { username?: string }).username ??
    session.user.name ??
    "unknown";

  try {
    const commentBody = `${body.trim()}\n\n— @${username} (via idea-hub)`;
    await addComment(issueNumber, commentBody);

    // 텔레그램 알림
    const idea = await getIdea(issueNumber);
    const title = idea?.title ?? `#${issueNumber}`;
    const notificationMessage = `💬 새 댓글 등록\n\n아이디어: ${title}\n작성자: @${username}\n내용: ${body.trim().slice(0, 200)}\n\n👉 https://web-iota-ashy-12.vercel.app/ideas/${issueNumber}`;
    await Promise.all([
      sendTelegramNotification(notificationMessage),
      sendDiscordNotification(notificationMessage),
    ]);

    return NextResponse.json({ success: true }, { status: 201 });
  } catch (error) {
    console.error("Failed to add comment:", error);
    return NextResponse.json({ error: "댓글 등록에 실패했습니다." }, { status: 500 });
  }
}
