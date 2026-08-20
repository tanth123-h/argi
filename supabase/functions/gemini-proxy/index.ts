const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const fetchWithTimeout = async (input: RequestInfo | URL, init: RequestInit = {}, timeoutMs = 15000) => {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const authorization = request.headers.get("Authorization");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!authorization || !supabaseUrl || !anonKey) {
      return Response.json({ error: "authentication_required" }, { status: 401, headers: cors });
    }
    const userResponse = await fetchWithTimeout(`${supabaseUrl}/auth/v1/user`, {
      headers: { Authorization: authorization, apikey: anonKey },
    }, 10000);
    if (!userResponse.ok) {
      return Response.json({ error: "authentication_required" }, { status: 401, headers: cors });
    }
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) throw new Error("GEMINI_API_KEY is not configured");
    const { prompt, imageBase64, mimeType } = await request.json();
    if (typeof prompt !== "string" || prompt.length < 1 || prompt.length > 20000) {
      return Response.json({ error: "invalid_prompt" }, { status: 400, headers: cors });
    }
    if (imageBase64 && (typeof imageBase64 !== "string" || imageBase64.length > 14000000)) {
      return Response.json({ error: "image_too_large" }, { status: 413, headers: cors });
    }
    const allowedMimeTypes = new Set(["image/jpeg", "image/png", "image/webp"]);
    if (imageBase64 && mimeType && !allowedMimeTypes.has(mimeType)) {
      return Response.json({ error: "unsupported_image_type" }, { status: 400, headers: cors });
    }
    const parts: Record<string, unknown>[] = [{ text: prompt }];
    if (imageBase64) {
      parts.push({ inline_data: { mime_type: mimeType ?? "image/jpeg", data: imageBase64 } });
    }
    const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.6-flash";
    const response = await fetchWithTimeout(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: "คุณคือชาวนา AI ผู้ช่วยเกษตรกรไทย ตอบภาษาไทย แยกข้อมูลวัดจริงจากข้อเสนอแนะ และห้ามสร้างแหล่งอ้างอิง" }] },
          contents: [{ role: "user", parts }],
          generationConfig: { temperature: 0.7, maxOutputTokens: 2048 },
        }),
      },
      30000,
    );
    const data = await response.json();
    if (!response.ok) {
      console.error("Gemini upstream error", response.status, data);
      return Response.json({ error: "gemini_upstream_error" }, { status: response.status, headers: cors });
    }
    const text = data?.candidates?.[0]?.content?.parts?.map((part: { text?: string }) => part.text ?? "").join("") ?? "";
    return Response.json({ text }, { headers: cors });
  } catch (error) {
    console.error("Gemini proxy error", error);
    return Response.json({ error: "gemini_proxy_unavailable" }, { status: 503, headers: cors });
  }
});
