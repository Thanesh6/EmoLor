import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const {
      childName,
      weekSessions,
      preEmotions,
      postEmotions,
      emotionImprovement,
      dominantEmotion,
      emotionDistribution,
      mostPlayedActivity,
      totalStars,
      activeDays,
    } = body;

    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "ANTHROPIC_API_KEY not set" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const prompt = `You are a child development assistant for EmoLor, an emotional learning app for children with ASD Level 1-2 and alexithymia. Based on the session data provided, write a warm, friendly and simple progress summary for the caregiver in 3-4 sentences. Highlight any emotional improvement between pre and post session emotions. Mention the most engaged activity. Be positive, constructive and avoid clinical language.

Child: ${childName}
Sessions this week: ${weekSessions}
Active days: ${activeDays}
Pre-session emotions: ${preEmotions?.join(", ") || "Not recorded"}
Post-session emotions: ${postEmotions?.join(", ") || "Not recorded"}
Sessions where mood improved: ${emotionImprovement}%
Dominant emotion: ${dominantEmotion}
Most played activity: ${mostPlayedActivity}
Total stars earned: ${totalStars}
Emotion breakdown: ${JSON.stringify(emotionDistribution)}`;

    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: "claude-opus-4-7",
        max_tokens: 300,
        system: "You write warm, friendly progress summaries for caregivers of children using EmoLor. Keep responses to 3-4 sentences. Be positive and encouraging.",
        messages: [{ role: "user", content: prompt }],
      }),
    });

    if (!response.ok) {
      const err = await response.text();
      return new Response(
        JSON.stringify({ error: "Claude API error", detail: err }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const data = await response.json();
    const insight = data.content?.[0]?.text ?? "Great progress this week!";

    return new Response(
      JSON.stringify({ insight }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
