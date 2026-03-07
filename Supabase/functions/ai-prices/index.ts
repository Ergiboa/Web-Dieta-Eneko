// supabase/functions/ai-prices/index.ts
// Deploy: supabase functions deploy ai-prices
// Secret:  supabase secrets set ANTHROPIC_KEY=sk-ant-api03-...

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "No autorizado" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Sesión inválida" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    let anthropicKey = Deno.env.get("ANTHROPIC_KEY") ?? "";

    if (!anthropicKey) {
      const { data: settings } = await supabaseClient
        .from("app_settings")
        .select("anthropic_key")
        .eq("user_id", user.id)
        .maybeSingle();
      anthropicKey = settings?.anthropic_key ?? "";
    }

    if (!anthropicKey) {
      return new Response(JSON.stringify({ error: "ANTHROPIC_KEY no configurada" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    const { products, prompt } = await req.json();
    if (!products || !Array.isArray(products)) {
      return new Response(JSON.stringify({ error: "products array requerido" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    const finalPrompt = prompt ?? `Eres un experto en precios de supermercados españoles en 2025.
Dame los precios aproximados para estos productos en: Mercadona, Lidl, Carrefour, Dia, Eroski.

Productos: ${products.join(', ')}

Responde SOLO con JSON válido (sin texto adicional, sin backticks):
{
  "nombre_producto": {"merc": 1.99, "lidl": 1.79, "carrefour": 2.09, "dia": 1.89, "eroski": 1.95, "base": "500g"},
  ...
}
Reglas:
- Precio del envase/unidad más habitual en ese super
- base = cantidad del envase (ej: "500g", "1L", "6ud", "kg", "ud", "300g")
- Si no se vende en ese super, pon null
- Nombres exactamente como en la lista dada`;

    const anthropicRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": anthropicKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-20250514",
        max_tokens: 4096,
        messages: [{ role: "user", content: finalPrompt }],
      }),
    });

    if (!anthropicRes.ok) {
      const errText = await anthropicRes.text();
      return new Response(JSON.stringify({ error: `Anthropic error: ${anthropicRes.status}`, detail: errText }), {
        status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    const data = await anthropicRes.json();
    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});