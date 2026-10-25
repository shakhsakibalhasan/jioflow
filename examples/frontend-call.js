// Supply an already-authenticated Supabase access token from your existing CRM login.
// Do not place Steadfast keys here.
export async function courierStatus(accessToken, by, value) {
  const r = await fetch('/api/steadfast', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${accessToken}` },
    body: JSON.stringify({ action:'status', by, value })
  });
  return await r.json();
}
// Booking request uses action:'book' and fields invoice, recipient_name,
// recipient_phone, recipient_address, cod_amount, optional note.
// IMPORTANT: do not automatically retry bookings.
