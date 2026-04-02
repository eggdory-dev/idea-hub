import { Octokit } from "@octokit/rest";
import type { Idea, IdeaComment, IdeaFormData } from "@/types";
import {
  extractStatusFromLabels,
  extractSubmitterFromBody,
} from "@/lib/utils";

const REPO_OWNER = "eggdory-dev";
const REPO_NAME = "idea-hub";

function getOctokit() {
  const pat = process.env.GITHUB_PAT;
  if (!pat) {
    throw new Error("GITHUB_PAT environment variable is not set");
  }
  return new Octokit({ auth: pat });
}

export async function listIdeas(): Promise<Idea[]> {
  const octokit = getOctokit();

  const { data } = await octokit.issues.listForRepo({
    owner: REPO_OWNER,
    repo: REPO_NAME,
    state: "open",
    per_page: 100,
  });

  return data
    .filter((issue) => !issue.pull_request)
    .map((issue) => {
      const labels = issue.labels.map((l) =>
        typeof l === "string" ? l : (l.name ?? "")
      );
      const status = extractStatusFromLabels(labels);
      const submitter = extractSubmitterFromBody(issue.body ?? null);

      return {
        number: issue.number,
        title: issue.title,
        body: issue.body ?? null,
        status,
        labels,
        submitter,
        createdAt: issue.created_at,
        htmlUrl: issue.html_url,
      };
    });
}

export async function getIdea(number: number): Promise<Idea | null> {
  const octokit = getOctokit();

  try {
    const { data: issue } = await octokit.issues.get({
      owner: REPO_OWNER,
      repo: REPO_NAME,
      issue_number: number,
    });

    if (issue.pull_request) return null;

    const labels = issue.labels.map((l) =>
      typeof l === "string" ? l : (l.name ?? "")
    );
    const status = extractStatusFromLabels(labels);
    const submitter = extractSubmitterFromBody(issue.body ?? null);

    return {
      number: issue.number,
      title: issue.title,
      body: issue.body ?? null,
      status,
      labels,
      submitter,
      createdAt: issue.created_at,
      htmlUrl: issue.html_url,
    };
  } catch {
    return null;
  }
}

export async function getIdeaComments(
  number: number
): Promise<IdeaComment[]> {
  const octokit = getOctokit();

  const { data } = await octokit.issues.listComments({
    owner: REPO_OWNER,
    repo: REPO_NAME,
    issue_number: number,
  });

  return data.map((comment) => ({
    id: comment.id,
    body: comment.body ?? "",
    author: comment.user?.login ?? "unknown",
    createdAt: comment.created_at,
  }));
}

export async function createIdea(
  formData: IdeaFormData,
  githubUsername: string
): Promise<number> {
  const octokit = getOctokit();

  const priorityMap: Record<string, string> = {
    urgent: "🔴 긴급 (Urgent)",
    high: "🟠 높음 (High)",
    medium: "🟡 보통 (Medium)",
    low: "🟢 낮음 (Low)",
  };

  const priorityLabel = priorityMap[formData.priority] ?? formData.priority;

  const body = `## 배경 / 문제

${formData.background}

## 기대 효과

${formData.expectedEffect}

## 핵심 기능

${formData.coreFeatures}

${
  formData.exclusions
    ? `## 제외 범위

${formData.exclusions}

`
    : ""
}## 우선순위

${priorityLabel}

## 플랫폼

${formData.platform}

${
  formData.references
    ? `## 참고 자료

${formData.references}

`
    : ""
}---

제출자: @${githubUsername}`;

  const { data } = await octokit.issues.create({
    owner: REPO_OWNER,
    repo: REPO_NAME,
    title: `[IDEA] ${formData.title}`,
    body,
    labels: ["intake"],
  });

  return data.number;
}

export async function addComment(
  issueNumber: number,
  body: string
): Promise<void> {
  const octokit = getOctokit();
  await octokit.issues.createComment({
    owner: REPO_OWNER,
    repo: REPO_NAME,
    issue_number: issueNumber,
    body,
  });
}

export async function updateIdeaStatus(
  issueNumber: number,
  newStatus: string
): Promise<void> {
  const octokit = getOctokit();

  // 현재 라벨 가져오기
  const { data: issue } = await octokit.issues.get({
    owner: REPO_OWNER,
    repo: REPO_NAME,
    issue_number: issueNumber,
  });

  const statusLabels = [
    "intake",
    "needs-review",
    "approved",
    "rejected",
    "on-hold",
    "building",
    "done",
  ];

  // 기존 상태 라벨 제거
  const currentLabels = issue.labels
    .map((l) => (typeof l === "string" ? l : l.name ?? ""))
    .filter((l) => !statusLabels.includes(l));

  // 새 상태 라벨 추가
  currentLabels.push(newStatus);

  await octokit.issues.update({
    owner: REPO_OWNER,
    repo: REPO_NAME,
    issue_number: issueNumber,
    labels: currentLabels,
  });
}
