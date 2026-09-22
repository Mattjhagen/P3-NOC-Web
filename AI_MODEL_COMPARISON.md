# OpenCode Free AI Model Comparison

Testing results for P3NOC dashboard AI integration (2026-09-22)

## Models Tested

### ✅ Gemini 3 Flash (RECOMMENDED)
- **Provider**: Google Gemini Free
- **Model**: `gemini-free/gemini-3-flash-preview`
- **Speed**: ~2-3 seconds
- **Quality**: Excellent diagnostic responses
- **Reliability**: High
- **Cost**: $0.00
- **Context**: 1M tokens
- **Test Result**: ✓ Working perfectly

**Example Response:**
```
> Diagnose: High CPU usage
Diagnosis: Run `top` or `pidstat 1` to check if load stems from 
runaway user processes, I/O wait, or system interrupts.

Fix:
1. Gracefully restart or kill offending PIDs (`kill -15 <PID>`)
2. Optimize hot code paths, unindexed database queries, or worker thread pools
3. Scale CPU capacity if load is legitimate
```

### ❌ OpenCode Big Pickle
- **Provider**: OpenCode
- **Model**: `opencode/big-pickle`
- **Speed**: ~10-15 seconds
- **Quality**: Sometimes verbose/confused
- **Reliability**: Inconsistent
- **Cost**: $0.00
- **Test Result**: ✗ Slow and unreliable

### ⚠️ Groq GPT-OSS 120B
- **Provider**: GroqCloud Free
- **Model**: `groq-free/openai/gpt-oss-120b`
- **Speed**: N/A (rate limited)
- **Error**: Request too large for model (TPM limit: 8000)
- **Test Result**: ✗ Rate limit issues

### ❌ DeepSeek V4 Flash
- **Provider**: OpenCode/DeepSeek
- **Model**: `opencode/deepseek-v4-flash`
- **Speed**: N/A
- **Error**: "Insufficient account funds"
- **Test Result**: ✗ Requires paid account or credits

## Recommendation

**Use Gemini 3 Flash** (`gemini-free/gemini-3-flash-preview`) for:
- Fastest response times
- Best quality diagnostics
- Most reliable performance
- Huge context window (1M tokens)
- Free tier with generous limits

## Configuration

Update `.env`:
```bash
USE_OPENCODE=true
OPENCODE_MODEL=gemini-free/gemini-3-flash-preview
```

## Fallback Options

If Gemini has issues, try these in order:
1. `opencode/deepseek-v4.1-flash` - DeepSeek latest
2. `opencode/gemini-3.8-flash` - Newer Gemini version
3. `opencode/claude-fable-5` - Smaller Claude model (may have costs)

## API Keys Required

- Gemini: `~/.config/gemini/api-key` (get free at https://aistudio.google.com)
- DeepSeek: Built into OpenCode
- Groq: `~/.config/groq/api-key` (not recommended due to rate limits)
