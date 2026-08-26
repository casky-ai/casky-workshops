// app/api/tickets/[id]/route.js — production code excerpt (synthetic training data)
// Loopline, Next.js App Router API route

export async function GET(request, { params }) {
  const { id } = params;
  const session = await getSession(request);

  if (!session) {
    return new Response("Unauthorized", { status: 401 });
  }

  // FINDING (T1190-adjacent / OWASP API1:2023 BOLA): checks that SOMEONE is logged in, but never
  // checks that the ticket belongs to the requester's own org. Any authenticated user — from any
  // org — can read or edit any other org's ticket by changing the numeric :id in the URL.
  const ticket = await db.query("SELECT * FROM tickets WHERE id = $1", [id]);

  // Missing: `AND org_id = $2`, [id, session.org_id]

  return Response.json(ticket);
}

export async function PATCH(request, { params }) {
  const { id } = params;
  const session = await getSession(request);
  if (!session) return new Response("Unauthorized", { status: 401 });

  const body = await request.json();
  // Same gap here — no org_id check before the UPDATE either.
  await db.query("UPDATE tickets SET status = $1 WHERE id = $2", [body.status, id]);
  return Response.json({ ok: true });
}
