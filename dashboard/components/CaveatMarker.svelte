<script>
	export let n = 1;
</script>

<a class="marker" href="#fn-{n}" aria-label="Footnote {n}"><sup>{n}</sup></a>

<style>
	.marker {
		color: var(--color-warning);
		text-decoration: none;
		font-family: var(--font-sans);
		font-weight: 600;
		font-size: 12px;
		margin-left: 2px;
	}
	.marker sup {
		line-height: 0;
	}
	@media (max-width: 640px) {
		.marker {
			display: inline-flex;
			align-items: center;
			justify-content: center;
			min-width: 44px;
			min-height: 44px;
			margin: -14px -10px;
			vertical-align: middle;
		}
	}
</style>
