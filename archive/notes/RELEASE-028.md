# JioFlow 028 — stable full-screen loading

One shared body-level viewport overlay stays centered through overlapping refresh/page/record requests. The refresh overlay no longer disappears before the page query finishes. Stale disconnected page loaders release ownership automatically. Record placeholders no longer contain a second local rotating logo. The footer stays at the bottom while records load. The 56px ring surrounds the stationary, smaller supplied icon. Theme-aware blur covers the entire viewport. No database migration. Includes 027.
