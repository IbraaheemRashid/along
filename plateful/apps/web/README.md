# Along local web prototype

React + Vite companion to the native iOS prototype. The repository directory keeps its earlier `plateful` name; the product shown here is Along, with the original code-native woodland companion Pip.

Run `pnpm install`, then `pnpm dev`. `pnpm build`, `pnpm check` and `pnpm test` verify the bundle and the check-in rules. Node 22.12+ is supported by the selected Vite release.

- `/` is the responsive validation landing page and interactive preview.
- `/?demo=1` opens the portrait app preview for screen recordings.
- Choose a mood, appetite, optional routines and optional note. Save to see the journey and milestones. Editing today replaces the previous entry. Reset clears the preview.
- Check-ins exist only in React memory. Refresh clears them. There are no cookies, browser storage, external requests, analytics, AI calls or remote health-data submission.
- The visible waitlist is intentionally disabled and never accepts an email. The separately tested `waitlist.mjs` adapter is preparatory code, not connected to the page. Live collection needs reviewed privacy information, consent UI, Turnstile and configured API/D1 before it is enabled.
- `$29.99/year` is explicitly a pricing hypothesis. No checkout or subscription exists.

This is a prototype before market validation. No demand, health outcomes or conversion results are implied. No production deployment is configured or performed.

Reference APIs: [React createRoot](https://react.dev/reference/react-dom/client/createRoot), [Vite guide](https://vite.dev/guide/).
