<script>
	import { browser } from "$app/environment";
	import { afterUpdate, tick } from "svelte";
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

	function revealTab() {
		if (!browser || window.innerWidth > 640) return;
		const current = document.querySelector('nav.gtm-tabs [aria-current="page"]');
		const scroller = current?.parentElement;
		if (!current || !scroller) return;
		const left = current.offsetLeft - (scroller.clientWidth - current.offsetWidth) / 2;
		scroller.scrollTo({ left: Math.max(0, left) });
	}

	function wrapTables() {
		if (!browser || window.innerWidth > 640) return;
		document.querySelectorAll(".gtm-frame table").forEach((table) => {
			if (table.closest(".table-scroll")) return;
			if (table.classList.contains("commentary") || table.classList.contains("spark")) return;
			const wrap = document.createElement("div");
			wrap.className = "table-scroll";
			table.parentNode.insertBefore(wrap, table);
			wrap.appendChild(table);
		});
	}

	$: if (browser && path) tick().then(revealTab);
	afterUpdate(wrapTables);
</script>

<svelte:head>
	<meta name="viewport" content="width=device-width, initial-scale=1" />
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
