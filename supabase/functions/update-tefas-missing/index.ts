const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

Deno.serve((req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS });
  }

  return new Response(
    JSON.stringify({
      error: "deprecated_tefas_edge_function",
      message:
        "Missing TEFAS/BEFAS data is handled by workers/tefas_ingest validation and publish flow.",
    }),
    {
      status: 410,
      headers: { ...CORS, "Content-Type": "application/json" },
    },
  );
});
