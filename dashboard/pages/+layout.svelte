<script>
	import { EvidenceDefaultLayout } from "@evidence-dev/core-components";
	import { showQueries } from "@evidence-dev/component-utilities/stores";
	import { page } from "$app/stores";
	import "./theme.css";

	export let data;

	showQueries.set(false);

	const tabs = [
		{ label: "Executive", href: "/", test: (path) => path === "/" },
		{
			label: "Sales",
			href: "/pipeline/",
			test: (path) => path.startsWith("/pipeline") || path.startsWith("/bookings"),
		},
		{ label: "Deal Desk", href: null, test: () => false },
		{ label: "Finance", href: "/arr/", test: (path) => path.startsWith("/arr") },
		{
			label: "Data health",
			href: "/data-quality/",
			test: (path) => path.startsWith("/data-quality"),
		},
	];

	$: path = ($page.url.pathname.replace(/\/$/, "") || "/");
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
			<a class="gtm-wordmark" href="/">GTM Data</a>
			<nav class="gtm-tabs" aria-label="Sections">
				{#each tabs as tab}
					{#if tab.href}
						<a class="gtm-tab" href={tab.href} aria-current={tab.test(path) ? "page" : undefined}>
							{tab.label}
						</a>
					{:else}
						<span class="gtm-tab">{tab.label}</span>
					{/if}
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
