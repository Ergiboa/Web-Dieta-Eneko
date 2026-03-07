// supabase/functions/create-client/index.ts
// Deploy:  supabase functions deploy create-client
// Secret:  supabase secrets set SUPABASE_SERVICE_KEY=eyJ...  (service_role key, NO la anon)
//
// La service_role key está en: Supabase Dashboard → Settings → API → service_role

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

  const respond = (data: unknown, status = 200) =>
    new Response(JSON.stringify(data), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    // ── 1. Verificar que el que llama es un coach autenticado ──────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return respond({ error: "No autorizado" }, 401);

    const supabaseUrl  = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey      = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceKey   = Deno.env.get("SUPABASE_SERVICE_KEY") ?? "";

    if (!serviceKey) return respond({ error: "SUPABASE_SERVICE_KEY no configurada en secrets" }, 500);

    // Cliente con la sesión del coach (para verificar identidad)
    const coachClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user: coachUser }, error: authErr } = await coachClient.auth.getUser();
    if (authErr || !coachUser) return respond({ error: "Sesión inválida" }, 401);

    // Verificar que es coach
    const { data: coachProfile } = await coachClient
      .from("profiles")
      .select("role, full_name")
      .eq("id", coachUser.id)
      .single();

    if (coachProfile?.role !== "coach") {
      return respond({ error: "Solo los entrenadores pueden crear clientes" }, 403);
    }

    // ── 2. Parsear datos del nuevo cliente ────────────────────────────────
    const { email, password, full_name } = await req.json();

    if (!email || !password || !full_name) {
      return respond({ error: "email, password y full_name son obligatorios" }, 400);
    }
    if (password.length < 6) {
      return respond({ error: "La contraseña debe tener al menos 6 caracteres" }, 400);
    }

    // ── 3. Crear usuario con Admin API (service role key) ─────────────────
    const adminClient = createClient(supabaseUrl, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: newUser, error: createErr } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,           // confirmar email automáticamente
      user_metadata: { full_name },
    });

    if (createErr) {
      // Mensaje legible para errores comunes
      const msg = createErr.message.includes("already registered")
        ? "Ya existe un usuario con ese email"
        : createErr.message;
      return respond({ error: msg }, 400);
    }

    // ── 4. Actualizar perfil: asignar rol client + coach_id ───────────────
    // El trigger handle_new_user ya habrá creado la fila básica,
    // así que hacemos upsert para añadir role y coach_id
    const { error: profileErr } = await adminClient
      .from("profiles")
      .upsert({
        id:        newUser.user.id,
        email,
        full_name,
        role:      "client",
        coach_id:  coachUser.id,
      }, { onConflict: "id" });

    if (profileErr) {
      // Si falla el perfil, intentar eliminar el usuario creado para no dejar basura
      await adminClient.auth.admin.deleteUser(newUser.user.id);
      return respond({ error: "Error al crear perfil: " + profileErr.message }, 500);
    }

    return respond({
      ok: true,
      client: { id: newUser.user.id, email, full_name },
    });

  } catch (err) {
    return respond({ error: err.message }, 500);
  }
});