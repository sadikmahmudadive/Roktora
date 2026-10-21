"use client";

import { format, isToday, isYesterday } from "date-fns";
import { MapPin, Send } from "lucide-react";
import { useEffect, useRef, useState, type FormEvent } from "react";
import { sendChatMessage, useMessages, type ChatMsg } from "@/lib/store";
import { Banner, Button, cn } from "./ui";

const dayLabel = (d: Date) => (isToday(d) ? "Today" : isYesterday(d) ? "Yesterday" : format(d, "EEE, d MMM"));

/** The request's chat with the donors who committed. Read-only once the request is closed. */
export function RequestChat({ requestId, open, uid, name }: { requestId: string; open: boolean; uid: string; name: string }) {
  const { data, loading, error } = useMessages(requestId);
  const [text, setText] = useState("");
  const [sending, setSending] = useState(false);
  const [failed, setFailed] = useState<string | null>(null);
  const list = useRef<HTMLDivElement>(null);
  const last = data[data.length - 1]?.id;

  // Follow new messages.
  useEffect(() => {
    const el = list.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [last, data.length]);

  async function send(e: FormEvent) {
    e.preventDefault();
    const t = text.trim();
    if (!t || sending) return;
    setSending(true);
    setFailed(null);
    try {
      await sendChatMessage(requestId, uid, name, t);
      setText("");
    } catch {
      setFailed("Couldn't send. Chats are only open while the request is open.");
    } finally {
      setSending(false);
    }
  }

  return (
    <section aria-label="Chat with donors" className="mt-5">
      <h4 className="mb-2 font-semibold">Chat with donors</h4>
      {error ? (
        <Banner tone="warning">Couldn&apos;t load the chat. {error}</Banner>
      ) : (
        <div ref={list} className="max-h-72 min-h-24 overflow-y-auto rounded-[var(--radius-ctl)] border border-line bg-surface-1 p-3">
          {loading ? (
            <p className="text-sm text-ink-3">Loading…</p>
          ) : data.length === 0 ? (
            <p className="text-sm text-ink-2">No messages yet. Donors who committed see what you write here and in the app.</p>
          ) : (
            data.map((m, i) => <Bubble key={m.id} m={m} prev={data[i - 1]} mine={m.fromUid === uid} />)
          )}
        </div>
      )}
      {open ? (
        <form onSubmit={(e) => void send(e)} className="mt-2 flex gap-2">
          <input
            aria-label="Write a message"
            value={text}
            maxLength={1000}
            placeholder="Write a message to the donors"
            onChange={(e) => setText(e.target.value)}
            className="min-w-0 flex-1 rounded-[var(--radius-ctl)] border border-line-2 bg-surface-0 px-3.5 py-2.5 text-[15px] text-ink placeholder:text-ink-3 focus:border-brand focus:ring-2 focus:ring-brand-bg"
          />
          <Button type="submit" icon={<Send size={16} />} disabled={sending || !text.trim()}>
            Send
          </Button>
        </form>
      ) : (
        <p className="mt-2 text-xs text-ink-3">This request is closed, so the chat is read-only. Reopen it to write again.</p>
      )}
      {failed && <Banner className="mt-2" tone="danger">{failed}</Banner>}
    </section>
  );
}

function Bubble({ m, prev, mine }: { m: ChatMsg; prev: ChatMsg | undefined; mine: boolean }) {
  const newDay = m.sentAt && (!prev?.sentAt || dayLabel(prev.sentAt) !== dayLabel(m.sentAt));
  const startsGroup = !prev || prev.fromUid !== m.fromUid || newDay;
  return (
    <>
      {newDay && m.sentAt && <div className="my-2 text-center text-xs font-semibold text-ink-3">{dayLabel(m.sentAt)}</div>}
      <div className={cn("flex flex-col", mine ? "items-end" : "items-start", startsGroup ? "mt-2.5" : "mt-0.5")}>
        {!mine && startsGroup && <span className="mb-0.5 px-1.5 text-xs font-semibold text-ink-2">{m.senderName || "Donor"}</span>}
        <div className={cn("max-w-[80%] rounded-2xl px-3 py-2 text-sm", mine ? "bg-brand text-on-fill" : "border border-line bg-surface-0", m.pending && "opacity-70")}>
          {m.lat !== null && m.lng !== null ? (
            <a
              href={`https://www.google.com/maps/search/?api=1&query=${m.lat},${m.lng}`}
              target="_blank"
              rel="noreferrer"
              className="flex items-center gap-2 font-semibold underline-offset-2 hover:underline"
            >
              <MapPin size={16} />
              <span>{m.text}</span>
            </a>
          ) : (
            m.text
          )}
        </div>
        <span className="px-1.5 pt-0.5 text-[11px] text-ink-3">{m.pending ? "Sending…" : m.sentAt ? format(m.sentAt, "h:mm a") : ""}</span>
      </div>
    </>
  );
}
