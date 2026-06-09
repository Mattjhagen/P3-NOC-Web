import React, { useState, useEffect, useRef } from "react";
import { Plus, Trash2, Send, ExternalLink, ChevronRight } from "lucide-react";
import axios from "axios";

interface ChatInterfaceProps {
  token: string;
  availableModels: string[];
}

interface Conversation {
  id: number;
  title: string;
  created_at: string;
}

interface Message {
  id?: number;
  role: "user" | "assistant";
  content: string;
  sources?: { title: string; url: string }[];
  suggestions?: string[];
}

// ── Helpers ────────────────────────────────────────────────────────

const extractThinkingSteps = (content: string): string[] => {
  const match = content.match(/\[THINKING\]([\s\S]*?)(?:\[\/THINKING\]|Thinking Process:|$)/);
  if (!match) return [];
  return match[1]
    .split("\n")
    .map(l => l.trim())
    .filter(l => l.length > 0 && (l.startsWith("🔍") || l.startsWith("✅") || l.startsWith("ℹ️") || l.startsWith("-")));
};

const isThinkingDone = (content: string): boolean =>
  content.includes("[/THINKING]") ||
  (content.includes("[THINKING]") && content.split("[THINKING]")[1]?.length > 250);

const renderMarkdown = (text: string) => {
  if (!text) return null;
  let html = text.replace(/\[THINKING\][\s\S]*?(\[\/THINKING\]|\n\n)/g, "");
  if (html.includes("[THINKING]")) html = html.split("[THINKING]")[0];
  html = html.trim();
  if (!html) return null;

  html = html.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  // Citation badges
  html = html.replace(/\[(\d+)\]/g,
    `<span class="metro-cite">$1</span>`
  );
  // Code blocks
  html = html.replace(/```(\w*)\n([\s\S]*?)```/g, (_match, _lang, code) =>
    `<pre><code>${code.trim()}</code></pre>`
  );
  // Inline code
  html = html.replace(/`([^`\n]+)`/g, '<code>$1</code>');
  // Bold
  html = html.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  // Paragraphs
  html = html.split("\n\n").map(p => {
    if (p.trim().startsWith("<pre")) return p;
    return `<p>${p.replace(/\n/g, "<br/>")}</p>`;
  }).join("");

  return <div className="metro-prose" dangerouslySetInnerHTML={{ __html: html }} />;
};

// ── Components ────────────────────────────────────────────────────

const ThinkingBar: React.FC<{ steps: string[]; done: boolean }> = ({ steps, done }) => (
  <div style={{
    borderLeft: `3px solid ${done ? "rgba(255,255,255,0.1)" : "var(--metro-accent)"}`,
    paddingLeft: "1rem",
    marginBottom: "1.5rem",
  }}>
    <div style={{
      fontSize: "0.6875rem",
      fontWeight: 600,
      letterSpacing: "0.1em",
      textTransform: "uppercase",
      color: done ? "rgba(255,255,255,0.25)" : "var(--metro-accent)",
      marginBottom: "0.5rem",
      display: "flex",
      alignItems: "center",
      gap: "0.5rem",
    }}>
      {!done && (
        <span style={{ display: "flex", gap: "3px", alignItems: "center" }}>
          {[0, 1, 2].map(i => (
            <span key={i} className="metro-dot" style={{
              display: "inline-block",
              width: "3px",
              height: "12px",
              background: "var(--metro-accent)",
              borderRadius: "1px",
            }} />
          ))}
        </span>
      )}
      {done ? "search complete" : "searching..."}
    </div>
    {steps.map((step, i) => (
      <div key={i} style={{
        fontSize: "0.8125rem",
        color: "rgba(255,255,255,0.4)",
        lineHeight: 1.5,
        marginBottom: "0.2rem",
      }}>
        {step.replace(/^[✅🔍ℹ️·\-]\s*/, "")}
      </div>
    ))}
  </div>
);

const SourceRow: React.FC<{ sources: { title: string; url: string }[] }> = ({ sources }) => (
  <div style={{ marginBottom: "1.5rem" }}>
    <div style={{
      fontSize: "0.6875rem",
      fontWeight: 600,
      letterSpacing: "0.1em",
      textTransform: "uppercase",
      color: "rgba(255,255,255,0.25)",
      marginBottom: "0.75rem",
    }}>
      sources
    </div>
    <div style={{ display: "flex", gap: "0.75rem", flexWrap: "wrap" }}>
      {sources.map((src, i) => {
        let hostname = "";
        try { hostname = new URL(src.url).hostname; } catch (_) { hostname = src.url; }
        return (
          <a key={i} href={src.url} target="_blank" rel="noopener noreferrer"
            style={{
              display: "flex",
              flexDirection: "column",
              gap: "0.375rem",
              padding: "0.75rem 1rem",
              background: "#1a1a1a",
              textDecoration: "none",
              maxWidth: "220px",
              transition: "background 0.15s",
              minWidth: "140px",
            }}
            onMouseEnter={e => (e.currentTarget.style.background = "#222")}
            onMouseLeave={e => (e.currentTarget.style.background = "#1a1a1a")}
          >
            <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
              <span style={{
                display: "inline-flex",
                alignItems: "center",
                justifyContent: "center",
                width: "18px",
                height: "18px",
                background: "var(--metro-accent)",
                color: "#000",
                fontSize: "0.625rem",
                fontWeight: 700,
                flexShrink: 0,
                borderRadius: "2px",
              }}>{i + 1}</span>
              <ExternalLink size={11} style={{ color: "rgba(255,255,255,0.2)", flexShrink: 0 }} />
            </div>
            <div style={{ fontSize: "0.8125rem", color: "rgba(255,255,255,0.8)", lineHeight: 1.35 }}
              className="line-clamp-2">{src.title}</div>
            <div style={{ fontSize: "0.6875rem", color: "rgba(255,255,255,0.3)" }}>{hostname}</div>
          </a>
        );
      })}
    </div>
  </div>
);

const SuggestionsBox: React.FC<{ suggestions: string[]; onSelect: (s: string) => void; disabled: boolean }> = ({
  suggestions, onSelect, disabled,
}) => (
  <div style={{
    marginTop: "1.5rem",
    borderTop: "1px solid rgba(255,255,255,0.06)",
    paddingTop: "1rem",
  }}>
    <div style={{
      fontSize: "0.6875rem",
      fontWeight: 600,
      letterSpacing: "0.1em",
      textTransform: "uppercase",
      color: "rgba(255,255,255,0.25)",
      marginBottom: "0.75rem",
    }}>related</div>
    {suggestions.map((sug, i) => (
      <button key={i} onClick={() => onSelect(sug)} disabled={disabled}
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          width: "100%",
          background: "transparent",
          border: "none",
          borderBottom: "1px solid rgba(255,255,255,0.04)",
          padding: "0.75rem 0",
          cursor: disabled ? "not-allowed" : "pointer",
          textAlign: "left",
          color: disabled ? "rgba(255,255,255,0.2)" : "rgba(255,255,255,0.65)",
          fontSize: "0.9375rem",
          fontWeight: 300,
          transition: "color 0.15s",
          fontFamily: "inherit",
          gap: "1rem",
        }}
        onMouseEnter={e => { if (!disabled) e.currentTarget.style.color = "#fff"; }}
        onMouseLeave={e => { if (!disabled) e.currentTarget.style.color = "rgba(255,255,255,0.65)"; }}
      >
        <span>{sug}</span>
        <ChevronRight size={14} style={{ flexShrink: 0, opacity: 0.4 }} />
      </button>
    ))}
  </div>
);

// ── Main Component ────────────────────────────────────────────────

export const ChatInterface: React.FC<ChatInterfaceProps> = ({ token, availableModels }) => {
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [activeConvId, setActiveConvId] = useState<number | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputVal, setInputVal] = useState("");
  const [selectedModel, setSelectedModel] = useState("phi3:mini");
  const [isStreaming, setIsStreaming] = useState(false);
  const [isLoadingConv, setIsLoadingConv] = useState(false);

  const chatEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (availableModels.length > 0) {
      const phi = availableModels.find(m => m.toLowerCase().includes("phi"));
      setSelectedModel(phi || availableModels[0]);
    }
  }, [availableModels]);

  const headers = { Authorization: `Bearer ${token}` };

  const fetchConversations = async () => {
    try {
      const res = await axios.get("/api/chat/conversations", { headers });
      setConversations(res.data);
      if (res.data.length > 0 && activeConvId === null) setActiveConvId(res.data[0].id);
    } catch (err) { console.error(err); }
  };

  useEffect(() => { fetchConversations(); }, []);

  useEffect(() => {
    if (activeConvId !== null) {
      setIsLoadingConv(true);
      axios.get(`/api/chat/conversations/${activeConvId}/messages`, { headers })
        .then(res => setMessages(res.data))
        .catch(console.error)
        .finally(() => setIsLoadingConv(false));
    } else {
      setMessages([]);
    }
  }, [activeConvId]);

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const handleNewConversation = async () => {
    try {
      const title = `chat · ${new Date().toLocaleString("en-US", { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" })}`;
      const res = await axios.post("/api/chat/conversations", { title }, { headers });
      setConversations(prev => [res.data, ...prev]);
      setActiveConvId(res.data.id);
    } catch (err) { console.error(err); }
  };

  const handleDeleteConversation = async (e: React.MouseEvent, id: number) => {
    e.stopPropagation();
    try {
      await axios.delete(`/api/chat/conversations/${id}`, { headers });
      setConversations(prev => prev.filter(c => c.id !== id));
      if (activeConvId === id) setActiveConvId(null);
    } catch (err) { console.error(err); }
  };

  const sendMessageWithContent = async (text: string) => {
    if (!text.trim() || activeConvId === null || isStreaming) return;
    setIsStreaming(true);

    const updatedMessages: Message[] = [...messages, { role: "user", content: text }];
    setMessages(updatedMessages);
    const streamIdx = updatedMessages.length;
    setMessages(prev => [...prev, { role: "assistant", content: "" }]);

    try {
      const response = await fetch(`/api/chat/conversations/${activeConvId}/messages`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
        body: JSON.stringify({ content: text, model: selectedModel }),
      });

      if (!response.body) throw new Error("No stream");
      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let accumulated = "";

      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        for (const line of decoder.decode(value).split("\n")) {
          if (!line.trim().startsWith("data: ")) continue;
          const ds = line.replace("data: ", "").trim();
          if (!ds) continue;
          try {
            const parsed = JSON.parse(ds);
            if (parsed.sources) {
              setMessages(prev => { const c = [...prev]; if (c[streamIdx]) c[streamIdx].sources = parsed.sources; return c; });
            } else if (parsed.suggestions) {
              setMessages(prev => { const c = [...prev]; if (c[streamIdx]) c[streamIdx].suggestions = parsed.suggestions; return c; });
            } else {
              if (parsed.message?.thinking) {
                if (!accumulated.includes("[THINKING]")) accumulated += "[THINKING]";
                accumulated += parsed.message.thinking;
              }
              if (parsed.message?.content) {
                if (accumulated.includes("[THINKING]") && !accumulated.includes("[/THINKING]")) accumulated += "[/THINKING]\n\n";
                accumulated += parsed.message.content;
              }
            }
            setMessages(prev => { const c = [...prev]; if (c[streamIdx]) c[streamIdx].content = accumulated; return c; });
          } catch (_) {}
        }
      }
    } catch (err) {
      setMessages(prev => { const c = [...prev]; if (c[streamIdx]) c[streamIdx].content = "Connection error."; return c; });
    } finally {
      setIsStreaming(false);
      fetchConversations();
    }
  };

  const handleSend = (e: React.FormEvent) => {
    e.preventDefault();
    if (!inputVal.trim()) return;
    const text = inputVal;
    setInputVal("");
    if (inputRef.current) inputRef.current.style.height = "auto";
    sendMessageWithContent(text);
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); handleSend(e as any); }
  };

  return (
    <div style={{ display: "flex", height: "calc(100vh - 160px)", minHeight: "600px", background: "#0f0f0f" }}>

      {/* ── Conversations Panel ── */}
      <div style={{
        width: "260px",
        flexShrink: 0,
        borderRight: "1px solid rgba(255,255,255,0.05)",
        display: "flex",
        flexDirection: "column",
        background: "#0a0a0a",
      }}>
        {/* Header */}
        <div style={{
          padding: "1.5rem 1.25rem 1rem",
          borderBottom: "1px solid rgba(255,255,255,0.05)",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
        }}>
          <div>
            <div style={{ fontSize: "1.5rem", fontWeight: 300, color: "#fff", letterSpacing: "-0.01em", lineHeight: 1 }}>
              threads
            </div>
          </div>
          <button onClick={handleNewConversation}
            style={{
              background: "var(--metro-accent)",
              border: "none",
              color: "#000",
              cursor: "pointer",
              width: "28px",
              height: "28px",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              flexShrink: 0,
              borderRadius: "2px",
            }}>
            <Plus size={16} />
          </button>
        </div>

        {/* List */}
        <div style={{ flex: 1, overflowY: "auto", padding: "0.5rem 0" }}>
          {conversations.length === 0 ? (
            <div style={{ padding: "1.5rem 1.25rem", fontSize: "0.8125rem", color: "rgba(255,255,255,0.2)" }}>
              no threads yet
            </div>
          ) : conversations.map(conv => {
            const isActive = conv.id === activeConvId;
            return (
              <div key={conv.id}
                onClick={() => setActiveConvId(conv.id)}
                style={{
                  padding: "0.875rem 1.25rem",
                  cursor: "pointer",
                  background: isActive ? "#1a1a1a" : "transparent",
                  borderLeft: isActive ? "3px solid var(--metro-accent)" : "3px solid transparent",
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                  transition: "background 0.1s",
                }}
                onMouseEnter={e => { if (!isActive) e.currentTarget.style.background = "#111"; }}
                onMouseLeave={e => { if (!isActive) e.currentTarget.style.background = "transparent"; }}
              >
                <span style={{
                  fontSize: "0.8125rem",
                  color: isActive ? "#fff" : "rgba(255,255,255,0.45)",
                  fontWeight: isActive ? 400 : 300,
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                  whiteSpace: "nowrap",
                  flex: 1,
                }}>{conv.title}</span>
                <button
                  onClick={e => handleDeleteConversation(e, conv.id)}
                  style={{
                    background: "transparent",
                    border: "none",
                    color: "rgba(255,255,255,0.15)",
                    cursor: "pointer",
                    padding: "2px",
                    flexShrink: 0,
                    display: "flex",
                    marginLeft: "0.5rem",
                  }}
                  onMouseEnter={e => (e.currentTarget.style.color = "#ef233c")}
                  onMouseLeave={e => (e.currentTarget.style.color = "rgba(255,255,255,0.15)")}
                >
                  <Trash2 size={13} />
                </button>
              </div>
            );
          })}
        </div>

        {/* Model selector */}
        <div style={{
          padding: "1rem 1.25rem",
          borderTop: "1px solid rgba(255,255,255,0.05)",
        }}>
          <div className="metro-label" style={{ marginBottom: "0.5rem" }}>model</div>
          <select
            value={selectedModel}
            onChange={e => setSelectedModel(e.target.value)}
            style={{
              background: "#1a1a1a",
              border: "none",
              color: "#fff",
              fontSize: "0.8125rem",
              padding: "0.5rem 0.75rem",
              width: "100%",
              cursor: "pointer",
              fontFamily: "inherit",
              outline: "none",
              borderBottom: "1px solid rgba(255,255,255,0.1)",
            }}
          >
            {(availableModels.length === 0 ? ["qwen3:8b", "phi3:mini"] : availableModels).map(m => (
              <option key={m} value={m} style={{ background: "#1a1a1a" }}>{m}</option>
            ))}
          </select>
        </div>
      </div>

      {/* ── Chat Area ── */}
      <div style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0 }}>

        {/* Messages */}
        <div style={{ flex: 1, overflowY: "auto", padding: "2rem" }}>
          {activeConvId === null ? (
            /* Empty home */
            <div style={{ maxWidth: "560px", paddingTop: "2rem" }}>
              <div style={{ fontSize: "clamp(2.5rem, 5vw, 4rem)", fontWeight: 300, color: "#fff", lineHeight: 1, letterSpacing: "-0.02em", marginBottom: "0.75rem" }}>
                intelligence
              </div>
              <div style={{ fontSize: "1rem", color: "rgba(255,255,255,0.35)", fontWeight: 300, marginBottom: "2.5rem" }}>
                bitcoin · crypto · noc operations
              </div>
              <div style={{ display: "flex", flexDirection: "column", gap: "0" }}>
                {[
                  "What's the latest on BlackRock's Bitcoin ETF?",
                  "Summarize recent hash rate trends",
                  "How does Fed policy impact Bitcoin price?",
                ].map((s, i) => (
                  <button key={i} onClick={() => handleNewConversation().then(() => setTimeout(() => sendMessageWithContent(s), 300))}
                    style={{
                      background: "transparent",
                      border: "none",
                      borderBottom: "1px solid rgba(255,255,255,0.06)",
                      padding: "1rem 0",
                      textAlign: "left",
                      color: "rgba(255,255,255,0.5)",
                      fontSize: "1rem",
                      fontWeight: 300,
                      cursor: "pointer",
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "space-between",
                      fontFamily: "inherit",
                      transition: "color 0.15s",
                    }}
                    onMouseEnter={e => (e.currentTarget.style.color = "#fff")}
                    onMouseLeave={e => (e.currentTarget.style.color = "rgba(255,255,255,0.5)")}
                  >
                    <span>{s}</span>
                    <ChevronRight size={16} style={{ opacity: 0.3, flexShrink: 0 }} />
                  </button>
                ))}
              </div>
            </div>
          ) : isLoadingConv ? (
            <div style={{ display: "flex", alignItems: "center", gap: "0.75rem", color: "rgba(255,255,255,0.3)", paddingTop: "2rem" }}>
              <span style={{ display: "flex", gap: "4px" }}>
                {[0, 1, 2].map(i => (
                  <span key={i} className="metro-dot" style={{ display: "inline-block", width: "4px", height: "16px", background: "rgba(255,255,255,0.3)", borderRadius: "2px" }} />
                ))}
              </span>
              <span style={{ fontSize: "0.9375rem", fontWeight: 300 }}>loading thread...</span>
            </div>
          ) : messages.length === 0 ? (
            <div style={{ paddingTop: "2rem" }}>
              <div style={{ fontSize: "1.5rem", fontWeight: 300, color: "rgba(255,255,255,0.2)" }}>ask anything</div>
            </div>
          ) : (
            <div style={{ maxWidth: "680px" }}>
              {messages.map((msg, idx) => {
                const isUser = msg.role === "user";
                const steps = !isUser ? extractThinkingSteps(msg.content) : [];
                const done = !isUser ? isThinkingDone(msg.content) : true;
                const isEmpty = !isUser && msg.content === "";

                if (isUser) {
                  return (
                    <div key={idx} className="metro-enter" style={{ marginBottom: "2.5rem" }}>
                      {/* Oversized user question */}
                      <div style={{
                        fontSize: "clamp(1.25rem, 2.5vw, 1.75rem)",
                        fontWeight: 300,
                        color: "#ffffff",
                        lineHeight: 1.25,
                        letterSpacing: "-0.01em",
                      }}>
                        {msg.content}
                      </div>
                    </div>
                  );
                }

                return (
                  <div key={idx} className="metro-enter" style={{ marginBottom: "3rem" }}>
                    {/* Sources */}
                    {msg.sources && msg.sources.length > 0 && (
                      <SourceRow sources={msg.sources} />
                    )}

                    {/* Thinking bar */}
                    {steps.length > 0 && (
                      <ThinkingBar steps={steps} done={done} />
                    )}

                    {/* Loading indicator */}
                    {isEmpty && (
                      <div style={{ display: "flex", alignItems: "center", gap: "0.5rem", marginBottom: "1rem" }}>
                        {[0, 1, 2].map(i => (
                          <span key={i} className="metro-dot" style={{ display: "inline-block", width: "4px", height: "16px", background: "var(--metro-accent)", borderRadius: "2px" }} />
                        ))}
                        <span style={{ fontSize: "0.875rem", color: "rgba(255,255,255,0.35)", fontWeight: 300, marginLeft: "0.25rem" }}>generating answer...</span>
                      </div>
                    )}

                    {/* Answer text */}
                    {!isEmpty && renderMarkdown(msg.content)}

                    {/* Suggestions */}
                    {msg.suggestions && msg.suggestions.length > 0 && (
                      <SuggestionsBox suggestions={msg.suggestions} onSelect={sendMessageWithContent} disabled={isStreaming} />
                    )}
                  </div>
                );
              })}
              <div ref={chatEndRef} />
            </div>
          )}
        </div>

        {/* ── Metro Input Bar ── */}
        <div style={{
          borderTop: "1px solid rgba(255,255,255,0.05)",
          padding: "1.25rem 2rem",
          background: "#0f0f0f",
        }}>
          <form onSubmit={handleSend} style={{ display: "flex", gap: "1rem", alignItems: "flex-end", maxWidth: "680px" }}>
            <div style={{ flex: 1, position: "relative" }}>
              <textarea
                ref={inputRef}
                rows={1}
                value={inputVal}
                onChange={e => {
                  setInputVal(e.target.value);
                  e.target.style.height = "auto";
                  e.target.style.height = Math.min(e.target.scrollHeight, 140) + "px";
                }}
                onKeyDown={handleKeyDown}
                disabled={activeConvId === null || isStreaming}
                placeholder={
                  activeConvId === null
                    ? "select a thread to start..."
                    : isStreaming
                    ? "generating..."
                    : "ask anything..."
                }
                style={{
                  background: "transparent",
                  border: "none",
                  borderBottom: `2px solid ${activeConvId ? "rgba(255,255,255,0.15)" : "rgba(255,255,255,0.05)"}`,
                  color: "#fff",
                  fontSize: "1.0625rem",
                  fontWeight: 300,
                  padding: "0.75rem 0",
                  width: "100%",
                  resize: "none",
                  outline: "none",
                  fontFamily: "inherit",
                  lineHeight: 1.4,
                  minHeight: "40px",
                  maxHeight: "140px",
                  overflowY: "auto",
                  transition: "border-color 0.2s",
                }}
                onFocus={e => { if (activeConvId) e.currentTarget.style.borderBottomColor = "var(--metro-accent)"; }}
                onBlur={e => { e.currentTarget.style.borderBottomColor = "rgba(255,255,255,0.15)"; }}
              />
            </div>
            <button
              type="submit"
              disabled={activeConvId === null || !inputVal.trim() || isStreaming}
              style={{
                background: "var(--metro-accent)",
                border: "none",
                color: "#000",
                cursor: activeConvId && inputVal.trim() && !isStreaming ? "pointer" : "not-allowed",
                width: "40px",
                height: "40px",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                flexShrink: 0,
                opacity: activeConvId && inputVal.trim() && !isStreaming ? 1 : 0.3,
                transition: "opacity 0.15s",
                borderRadius: "2px",
              }}
            >
              {isStreaming
                ? <span style={{ width: "14px", height: "14px", borderRadius: "50%", border: "2px solid #000", borderTopColor: "transparent", animation: "spin 0.7s linear infinite" }} />
                : <Send size={16} />
              }
            </button>
          </form>
          <div style={{ fontSize: "0.6875rem", color: "rgba(255,255,255,0.15)", marginTop: "0.5rem", maxWidth: "680px" }}>
            {selectedModel} · enter to send · shift+enter for new line
          </div>
        </div>
      </div>
    </div>
  );
};
