Update 90 - Courier history diagnosis
Requires Update 88 already installed.
Replace server/native-history88.mjs and courier-overview.mjs in the same locations, then deploy. No SQL.
Shared history cards apply to Owner, Admin and Agent.
Reload New Order, check a phone and expand the availability message. Send the Diagnostic version 90 information for Steadfast and Pathao. No API keys needed.
This update diagnoses missing exact counts; it does not grant courier API access or invent counts. Raw provider error text, credentials and phone values are not exposed. Error categories are heuristic; unknown provider errors remain provider_error.
Validated parser and shared-card tests and build locally; not live deployed or verified.
