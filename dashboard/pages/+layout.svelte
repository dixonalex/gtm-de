<script>
	import { browser } from "$app/environment";
	import { base } from "$app/paths";
	import { EvidenceDefaultLayout } from "@evidence-dev/core-components";
	import { showQueries } from "@evidence-dev/component-utilities/stores";
	import { addBasePath } from "@evidence-dev/sdk/utils/svelte";
	import { page } from "$app/stores";
	import "./theme.css";

	export let data;

	const SLICE_KEYS = [
		"period", "segment", "region", "quarter", "team", "rep",
		"day", "owner", "type", "queue", "currency", "source", "model", "severity",
	];
	const SLICE_DEFAULTS = { period: "2026-08-31", quarter: "2026-Q3", day: "today" };

	function packed(value) {
		return { label: value, value, rawValues: [{ label: value, value, selected: true }] };
	}

	// The page query is built with whatever inputs exist at init, and Evidence
	// keeps prerendered rows when they are present. Seed the URL first, and drop
	// those rows when the URL is not the built slice, so the first client query runs.
	if (browser && data?.inputs) {
		const params = new URLSearchParams(window.location.search);
		let seeded = false;
		for (const key of SLICE_KEYS) {
			const value = params.get(key);
			if (!value) continue;
			data.inputs[key] = packed(value);
			if (value !== (SLICE_DEFAULTS[key] || "All")) seeded = true;
		}
		if (seeded && data.data) {
			for (const key of Object.keys(data.data)) delete data.data[key];
		}
	}

	showQueries.set(false);

	const tabs = [
		{ label: "Executive", href: addBasePath("/"), test: (path) => path === "/" },
		{ label: "Sales", href: addBasePath("/sales/"), test: (path) => path.startsWith("/sales") },
		{ label: "Deal Desk", href: addBasePath("/deal-desk/"), test: (path) => path.startsWith("/deal-desk") },
		{ label: "Finance", href: addBasePath("/finance/"), test: (path) => path.startsWith("/finance") },
		{ label: "Data health", href: addBasePath("/data-health/"), test: (path) => path.startsWith("/data-health") },
	];

	function appPath(pathname) {
		if (base && (pathname === base || pathname.startsWith(`${base}/`))) {
			pathname = pathname.slice(base.length);
		}
		return pathname.replace(/\/$/, "") || "/";
	}

	$: path = appPath($page.url.pathname);
</script>

<svelte:head>
	<link rel="preconnect" href="https://fonts.googleapis.com" />
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
	<link
		href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans+Condensed:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&family=Newsreader:opsz,wght@6..72,400;6..72,500&display=swap"
		rel="stylesheet"
	/>
</svelte:head>

<EvidenceDefaultLayout
	{data}
	hideSidebar
	hideHeader
	hideBreadcrumbs
	hideTOC
	builtWithEvidence={false}
	neverShowQueries
	fullWidth
>
	<header class="gtm-nav">
		<div class="gtm-nav-inner">
			<a class="gtm-wordmark" href={addBasePath("/")}>GTM Data</a>
			<nav class="gtm-tabs" aria-label="Sections">
				{#each tabs as tab}
					<a class="gtm-tab" href={tab.href} aria-current={tab.test(path) ? "page" : undefined}>
						{tab.label}
					</a>
				{/each}
			</nav>
		</div>
	</header>
	<div slot="content">
		<div class="gtm-frame">
			<slot />
		</div>
	</div>
</EvidenceDefaultLayout>
