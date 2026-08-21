const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const endpointNames = new Set(["price-index-month", "production-index-month"]);

const fetchWithTimeout = async (input: RequestInfo | URL, init: RequestInit = {}, timeoutMs = 12000) => {
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

    const body = await request.json();
    const endpoint = body?.endpoint;
    const yearTh = Number(body?.yearTh);
    const month = Number(body?.month);
    if (!endpointNames.has(endpoint) || !Number.isInteger(yearTh) || !Number.isInteger(month) || month < 1 || month > 12) {
      return Response.json({ error: "invalid_nabc_request" }, { status: 400, headers: cors });
    }

    const url = new URL(`https://agriapi.nabc.go.th/api/${endpoint}/category`);
    url.searchParams.set("page", "1");
    url.searchParams.set("year_th", String(yearTh));
    url.searchParams.set("month", String(month).padStart(2, "0"));
    url.searchParams.set("product_category", "หมวดพืชผลสำคัญ");

    const response = await fetchWithTimeout(url, { headers: { Accept: "application/json" } });
    const text = await response.text();
    return new Response(text, {
      status: response.status,
      headers: { ...cors, "Content-Type": response.headers.get("content-type") ?? "application/json" },
    });
  } catch (error) {
    console.error("NABC proxy error", error);
    return Response.json({ error: "nabc_upstream_unavailable" }, { status: 503, headers: cors });
  }
});
