"use client";

import { useState } from "react";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { ChevronDown, ChevronUp } from "lucide-react";

interface CommentItemProps {
  author: string;
  date: string;
  body: string;
}

export function CommentItem({ author, date, body }: CommentItemProps) {
  const lines = body.split("\n");
  const isLong = lines.length > 2;
  const [expanded, setExpanded] = useState(false);

  const displayText = isLong && !expanded
    ? lines.slice(0, 2).join("\n")
    : body;

  return (
    <Card>
      <CardHeader className="pb-2 pt-4 px-4">
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium text-slate-700">
            @{author}
          </span>
          <span className="text-xs text-slate-400">{date}</span>
        </div>
      </CardHeader>
      <CardContent className="pb-4 pt-0 px-4">
        <pre className="whitespace-pre-wrap font-sans text-sm text-slate-700">
          {displayText}
        </pre>
        {isLong && (
          <button
            onClick={() => setExpanded(!expanded)}
            className="mt-2 flex items-center gap-1 text-xs text-slate-400 hover:text-slate-600 transition-colors"
          >
            {expanded ? (
              <>
                <ChevronUp className="h-3 w-3" />
                접기
              </>
            ) : (
              <>
                <ChevronDown className="h-3 w-3" />
                더보기
              </>
            )}
          </button>
        )}
      </CardContent>
    </Card>
  );
}
