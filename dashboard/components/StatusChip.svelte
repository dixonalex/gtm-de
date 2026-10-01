<script>
	export let status = "pass";
	export let measured = "";
	export let threshold = "";

	const label = { pass: "Pass", warn: "Warn", error: "Error", pending: "Pending" };
	$: kind = String(status || "pass").toLowerCase();
	$: detail = [measured, threshold].filter(Boolean).join(", ");
</script>

<span class="chip {kind}">
	<span class="dot" aria-hidden="true"></span>
	<span>{label[kind] || kind}{detail ? ` · ${detail}` : ""}</span>
</span>

<style>
	.chip {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		font-size: 13px;
		line-height: 1.3;
		background: transparent;
	}
	.dot {
		width: 8px;
		height: 8px;
		border-radius: 50%;
		flex: 0 0 auto;
	}
	.pass {
		color: var(--color-ink-muted);
	}
	.pass .dot {
		background: var(--color-ink-muted);
	}
	.warn {
		color: var(--color-warning);
	}
	.warn .dot {
		background: var(--color-warning);
	}
	.error {
		color: var(--color-unfavorable);
	}
	.error .dot {
		background: var(--color-unfavorable);
	}
	.pending {
		color: var(--color-ink-muted);
	}
	.pending .dot {
		background: transparent;
		border: 1.5px solid var(--color-ink-muted);
	}
</style>
