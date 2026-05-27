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
        "TEFAS/BEFAS fund ingestion now runs only through workers/tefas_ingest.",
    }),
    {
      status: 410,
      headers: { ...CORS, "Content-Type": "application/json" },
    },
  );
});
