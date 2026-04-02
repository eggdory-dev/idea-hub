export type IdeaStatus =
  | "intake"
  | "needs-review"
  | "approved"
  | "building"
  | "done"
  | "rejected";

export interface Idea {
  number: number;
  title: string;
  body: string | null;
  status: IdeaStatus;
  labels: string[];
  submitter: string | null;
  createdAt: string;
  htmlUrl: string;
}

export interface IdeaComment {
  id: number;
  body: string;
  author: string;
  createdAt: string;
}

export interface IdeaFormData {
  title: string;
  background: string;
  expectedEffect: string;
  coreFeatures: string;
  exclusions: string;
  priority: string;
  platform: string;
  references: string;
}
