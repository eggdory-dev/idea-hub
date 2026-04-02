import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { updateIdeaStatus, addComment, getIdea } from "@/lib/github";
import { sendTelegramNotification } from "@/lib/telegram";

const VALID_STATUSES = [
  "intake",
  "needs-review",
  "approved",
  "rejected",
  "on-hold",
  "building",
  "done",
];

const STATUS_LABELS: Record<string, string> = {
  intake: "📥 접수",
  "needs-review": "🔍 검토 중",
  approved: "✅ 승인",
  rejected: "❌ 거절",
  "on-hold": "⏸️ 보류",
  building: "🚀 개발 중",
  done: "✅ 완료",
};

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

  const { status } = (await request.json()) as { status?: string };
  if (!status || !VALID_STATUSES.includes(status)) {
    return NextResponse.json({ error: "유효하지 않은 상태값" }, { status: 400 });
  }

  const username =
    (session.user as { username?: string }).username ??
    session.user.name ??
    "unknown";

  try {
    await updateIdeaStatus(issueNumber, status);

    // Issue에 상태 변경 댓글 추가
    const statusLabel = STATUS_LABELS[status] ?? status;
    await addComment(
      issueNumber,
      `${statusLabel} 상태로 변경됨 — by @${username} (via idea-hub)`
    );

    // 텔레그램 알림
    const idea = await getIdea(issueNumber);
    const title = idea?.title ?? `#${issueNumber}`;
    await sendTelegramNotification(
      `🔄 상태 변경\n\n아이디어: ${title}\n새 상태: ${statusLabel}\n변경자: @${username}\n\n👉 https://idea-hub-eggdory.vercel.app/ideas/${issueNumber}`
    );

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error("Failed to update status:", error);
    return NextResponse.json({ error: "상태 변경에 실패했습니다." }, { status: 500 });
  }
}
