import React, { useState, useEffect, useRef } from "react";
import { MessageSquare, Plus, Trash2, Send, Bot, User, Cpu, Loader2 } from "lucide-react";
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
}

export const ChatInterface: React.FC<ChatInterfaceProps> = ({ token, availableModels }) => {
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [activeConvId, setActiveConvId] = useState<number | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputVal, setInputVal] = useState("");
  const [selectedModel, setSelectedModel] = useState("qwen3:8b");
  const [isStreaming, setIsStreaming] = useState(false);
  const [isLoadingConv, setIsLoadingConv] = useState(false);
  
  const chatEndRef = useRef<HTMLDivElement>(null);

  // Set default model once available models populate
  useEffect(() => {
    if (availableModels.length > 0) {
      // Find qwen model or default first
      const qwen = availableModels.find(m => m.toLowerCase().includes("qwen"));
      setSelectedModel(qwen || availableModels[0]);
    }
  }, [availableModels]);

  const headers = { Authorization: `Bearer ${token}` };

  // Fetch all user conversations
  const fetchConversations = async () => {
    try {
      const res = await axios.get("/api/chat/conversations", { headers });
      setConversations(res.data);
      if (res.data.length > 0 && activeConvId === null) {
        setActiveConvId(res.data[0].id);
      }
    } catch (err) {
      console.error("Failed to load conversations:", err);
    }
  };

  useEffect(() => {
    fetchConversations();
  }, []);

  // Fetch messages when active conversation changes
  useEffect(() => {
    if (activeConvId !== null) {
      const fetchMessages = async () => {
        setIsLoadingConv(true);
        try {
          const res = await axios.get(`/api/chat/conversations/${activeConvId}/messages`, { headers });
          setMessages(res.data);
        } catch (err) {
          console.error("Failed to load messages:", err);
        } finally {
          setIsLoadingConv(false);
        }
      };
      fetchMessages();
    } else {
      setMessages([]);
    }
  }, [activeConvId]);

  // Auto-scroll chat window to bottom
  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  // Create new conversation thread
  const handleNewConversation = async () => {
    try {
      const title = `Session #${conversations.length + 1} - ${new Date().toLocaleDateString()}`;
      const res = await axios.post("/api/chat/conversations", { title }, { headers });
      setConversations(prev => [res.data, ...prev]);
      setActiveConvId(res.data.id);
    } catch (err) {
      console.error("Failed to create conversation:", err);
    }
  };

  // Delete conversation thread
  const handleDeleteConversation = async (e: React.MouseEvent, id: number) => {
    e.stopPropagation();
    try {
      await axios.delete(`/api/chat/conversations/${id}`, { headers });
      setConversations(prev => prev.filter(c => c.id !== id));
      if (activeConvId === id) {
        setActiveConvId(null);
      }
    } catch (err) {
      console.error("Failed to delete conversation:", err);
    }
  };

  // Simple custom Markdown formatter helper
  const renderMarkdown = (text: string) => {
    if (!text) return "";
    
    // Escape HTML tags to prevent XSS
    let html = text
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");

    // 1. Code blocks formatting: ```language ... ```
    html = html.replace(/```(\w*)\n([\s\S]*?)```/g, (_, lang, code) => {
      return `<div class="bg-black/50 border border-dashboard-border rounded-lg my-3 p-3 overflow-x-auto font-mono text-xs select-text">
        <div class="flex justify-between border-b border-dashboard-border/30 pb-1.5 mb-2 text-[10px] uppercase text-dashboard-accent select-none">
          <span>CODE BLOCK: ${lang || 'raw'}</span>
        </div>
        <pre class="bg-transparent! p-0! border-0! text-dashboard-neon">${code.trim()}</pre>
      </div>`;
    });

    // 2. Inline code formatting: `code`
    html = html.replace(/`([^`\n]+)`/g, '<code class="bg-black/40 border border-dashboard-border px-1.5 py-0.5 rounded font-mono text-dashboard-accent text-xs select-text">$1</code>');

    // 3. Newlines to paragraphs / breaks
    html = html.split('\n\n').map(p => {
      // Don't wrap code block divs
      if (p.trim().startsWith('<div class="bg-black/50')) return p;
      return `<p class="mb-2 leading-relaxed">${p.replace(/\n/g, '<br />')}</p>`;
    }).join('');

    return <div dangerouslySetInnerHTML={{ __html: html }} />;
  };

  // Handle post message and read stream chunks
  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!inputVal.trim() || activeConvId === null || isStreaming) return;

    const userText = inputVal;
    setInputVal("");
    setIsStreaming(true);

    // Append User message locally first
    const updatedMessages: Message[] = [...messages, { role: "user", content: userText }];
    setMessages(updatedMessages);

    // Insert dummy Assistant message placeholder
    const streamMessageIndex = updatedMessages.length;
    setMessages(prev => [...prev, { role: "assistant", content: "" }]);

    try {
      // Send post request using fetch to read stream
      const response = await fetch(`/api/chat/conversations/${activeConvId}/messages`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`,
        },
        body: JSON.stringify({
          content: userText,
          model: selectedModel,
        }),
      });

      if (!response.body) {
        throw new Error("No response stream body found");
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder("utf-8");
      let accumulatedResponse = "";

      while (true) {
        const { value, done } = await reader.read();
        if (done) break;

        const chunkText = decoder.decode(value);
        // SSE responses can contain multiple "data: ..." lines
        const lines = chunkText.split("\n");
        for (const line of lines) {
          if (line.trim().startsWith("data: ")) {
            const dataStr = line.replace("data: ", "").trim();
            if (dataStr) {
              try {
                const parsed = JSON.parse(dataStr);
                if (parsed.error) {
                  accumulatedResponse += `\n[ERROR: ${parsed.error}]`;
                } else if (parsed.message?.content) {
                  accumulatedResponse += parsed.message.content;
                }
                
                // Update Assistant Message text chunk by chunk
                setMessages(prev => {
                  const copy = [...prev];
                  if (copy[streamMessageIndex]) {
                    copy[streamMessageIndex].content = accumulatedResponse;
                  }
                  return copy;
                });
              } catch (pe) {
                // Not JSON (e.g. metadata or stream end)
              }
            }
          }
        }
      }
    } catch (err) {
      console.error(err);
      setMessages(prev => {
        const copy = [...prev];
        if (copy[streamMessageIndex]) {
          copy[streamMessageIndex].content = "Ollama connection timeout. Local simulation fallback triggered. Check AI Inference server logs.";
        }
        return copy;
      });
    } finally {
      setIsStreaming(false);
      // Re-trigger conversations list sync to show any title changes or logs
      fetchConversations();
    }
  };

  return (
    <div className="glass-panel rounded-xl border border-dashboard-border flex flex-col md:flex-row h-[600px] overflow-hidden select-none">
      
      {/* Left Pane: Conversations list */}
      <div className="w-full md:w-64 border-r border-dashboard-border flex flex-col bg-black/15 shrink-0">
        <div className="p-4 border-b border-dashboard-border flex items-center justify-between">
          <span className="text-xs font-mono font-bold text-dashboard-accent uppercase tracking-widest flex items-center gap-1">
            <MessageSquare className="w-3.5 h-3.5" /> Conversations
          </span>
          <button
            onClick={handleNewConversation}
            className="p-1 rounded bg-dashboard-neon/10 hover:bg-dashboard-neon border border-dashboard-neon/30 hover:border-transparent text-dashboard-neon hover:text-black transition-all"
            title="Create new chat thread"
          >
            <Plus className="w-4 h-4" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-2 space-y-1.5">
          {conversations.length === 0 ? (
            <div className="text-center text-gray-500 font-mono text-xs py-8">
              No active conversations
            </div>
          ) : (
            conversations.map((conv) => {
              const isActive = activeConvId === conv.id;
              return (
                <button
                  key={conv.id}
                  onClick={() => setActiveConvId(conv.id)}
                  className={`w-full flex items-center justify-between px-3 py-2.5 rounded-lg border text-left text-xs font-mono transition-all truncate ${
                    isActive
                      ? "bg-dashboard-accent/15 text-dashboard-neon border-dashboard-accent/40 shadow-glow-neon"
                      : "text-gray-400 hover:text-white bg-transparent border-transparent hover:bg-white/5"
                  }`}
                >
                  <span className="truncate max-w-[170px]">{conv.title}</span>
                  <span
                    onClick={(e) => handleDeleteConversation(e, conv.id)}
                    className="p-1 text-gray-500 hover:text-rose-400 rounded hover:bg-black/20"
                    title="Delete thread"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </span>
                </button>
              );
            })
          )}
        </div>
      </div>

      {/* Right Pane: Active Chat window */}
      <div className="flex-1 flex flex-col bg-black/5 relative justify-between">
        
        {/* Chat Header details */}
        <div className="p-4 border-b border-dashboard-border flex flex-col sm:flex-row items-center justify-between gap-3 bg-black/10 select-none">
          <div className="flex items-center gap-2">
            <Bot className="w-5 h-5 text-dashboard-neon" />
            <div>
              <h3 className="text-xs font-bold font-digital tracking-wider text-white uppercase">AI SEC-INTELLIGENCE ASSISTANT</h3>
              <p className="text-[10px] text-dashboard-accent font-mono tracking-widest">Connected to R510 Node</p>
            </div>
          </div>

          {/* Model selector dropdown */}
          <div className="flex items-center gap-2">
            <span className="text-[10px] font-mono text-dashboard-accent flex items-center gap-1 uppercase">
              <Cpu className="w-3 h-3" /> Target Model:
            </span>
            <select
              value={selectedModel}
              onChange={(e) => setSelectedModel(e.target.value)}
              className="bg-black/50 border border-dashboard-border text-white text-xs px-2.5 py-1.5 rounded font-mono focus:outline-none focus:border-dashboard-neon appearance-none select-text"
            >
              {availableModels.length === 0 ? (
                <option value="qwen3:8b">qwen3:8b (Default)</option>
              ) : (
                availableModels.map((m) => (
                  <option key={m} value={m}>{m}</option>
                ))
              )}
            </select>
          </div>
        </div>

        {/* Scrollable messages area */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {activeConvId === null ? (
            <div className="h-full flex flex-col items-center justify-center text-center text-gray-500 font-mono text-sm">
              <Bot className="w-12 h-12 text-dashboard-neon/30 mb-2 animate-bounce" />
              <p>NO CONVERSATION RUNNING</p>
              <p className="text-xs text-dashboard-accent opacity-60 mt-1">Select or create a thread in the sidepane to get started</p>
            </div>
          ) : isLoadingConv ? (
            <div className="h-full flex items-center justify-center text-gray-500 font-mono text-sm gap-2">
              <Loader2 className="w-5 h-5 animate-spin text-dashboard-accent" />
              <span>Loading messages thread...</span>
            </div>
          ) : messages.length === 0 ? (
            <div className="h-full flex flex-col items-center justify-center text-center text-gray-500 font-mono text-sm">
              <Bot className="w-10 h-10 text-dashboard-neon/20 mb-2" />
              <p className="text-xs tracking-wider">SECURE TRANSMISSION OPEN</p>
              <p className="text-[10px] text-dashboard-accent opacity-60">Send a prompt to begin parsing inferences</p>
            </div>
          ) : (
            messages.map((msg, idx) => {
              const isUser = msg.role === "user";
              return (
                <div key={idx} className={`flex gap-3 max-w-[85%] ${isUser ? "ml-auto flex-row-reverse" : "mr-auto"}`}>
                  {/* Bubble icon */}
                  <div className={`w-8 h-8 rounded-full flex items-center justify-center shrink-0 border border-dashboard-border ${
                    isUser ? "bg-dashboard-accent/15 text-dashboard-neon" : "bg-dashboard-card text-dashboard-accent"
                  }`}>
                    {isUser ? <User className="w-4 h-4" /> : <Bot className="w-4 h-4" />}
                  </div>

                  {/* Bubble text */}
                  <div className={`p-3.5 rounded-xl border text-sm font-sans ${
                    isUser
                      ? "bg-dashboard-accent/10 border-dashboard-accent/30 text-white"
                      : "bg-dashboard-card border-dashboard-border text-gray-150"
                  }`}>
                    {renderMarkdown(msg.content)}
                  </div>
                </div>
              );
            })
          )}
          {isStreaming && (
            <div className="flex gap-3 mr-auto max-w-[85%]">
              <div className="w-8 h-8 rounded-full flex items-center justify-center shrink-0 border border-dashboard-border bg-dashboard-card text-dashboard-accent">
                <Bot className="w-4 h-4 animate-spin" />
              </div>
              <div className="p-3.5 rounded-xl border bg-dashboard-card border-dashboard-border text-gray-400 flex items-center gap-2 font-mono text-xs">
                <Loader2 className="w-3.5 h-3.5 animate-spin text-dashboard-neon" />
                <span>Streaming response...</span>
              </div>
            </div>
          )}
          <div ref={chatEndRef} />
        </div>

        {/* Input message form */}
        <form onSubmit={handleSendMessage} className="p-4 border-t border-dashboard-border flex gap-3 bg-black/10 select-none">
          <input
            type="text"
            required
            disabled={activeConvId === null || isStreaming}
            value={inputVal}
            onChange={(e) => setInputVal(e.target.value)}
            placeholder={activeConvId === null ? "Open a conversation thread to type..." : "Enter inference instructions / prompt model..."}
            className="flex-1 px-4 py-3 bg-black/35 border border-dashboard-border focus:border-dashboard-neon rounded-lg text-white font-mono placeholder-gray-600 focus:outline-none transition-colors disabled:opacity-50 disabled:cursor-not-allowed select-text"
          />
          <button
            type="submit"
            disabled={activeConvId === null || !inputVal.trim() || isStreaming}
            className="px-5 py-3 bg-dashboard-neon text-black rounded-lg hover:bg-white transition-all shadow-glow-neon flex items-center gap-1.5 disabled:opacity-40 disabled:cursor-not-allowed shrink-0 font-digital uppercase font-bold text-xs"
          >
            <Send className="w-4 h-4" />
            <span>SEND</span>
          </button>
        </form>

      </div>
    </div>
  );
};
