<script>
	import { browser } from "$app/environment";
	import { getInputContext } from "@evidence-dev/sdk/utils/svelte";
	import { onMount } from "svelte";

	export let keys = "";
	export let defaults = "";

	const inputs = getInputContext();
	const keyList = keys.split(",").map((key) => key.trim()).filter(Boolean);
	const defaultMap = Object.fromEntries(
		defaults
			.split(",")
			.filter(Boolean)
			.map((pair) => {
				const split = pair.indexOf(":");
				return [pair.slice(0, split), pair.slice(split + 1)];
			}),
	);

	function packed(value) {
		return {
			label: value,
			value,
			rawValues: [{ label: value, value, selected: true }],
		};
	}

	function apply(values) {
		inputs.update((current) => {
			const next = { ...current };
			for (const [key, value] of Object.entries(values)) next[key] = packed(value);
			return next;
		});
	}

	// Set the URL value before Dropdown reads its initial selection.
	const urlValues = {};
	if (browser) {
		const params = new URLSearchParams(window.location.search);
		for (const key of keyList) {
			const value = params.get(key);
			if (value) urlValues[key] = value;
		}
		if (Object.keys(urlValues).length) apply(urlValues);
	}

	function inputValue(current, key) {
		const entry = current?.[key];
		if (entry == null || entry === "") return "";
		if (typeof entry === "string" || typeof entry === "number") return String(entry);
		const value = entry.value;
		if (value == null || value === "null" || value === "") return "";
		return String(value);
	}

	onMount(() => {
		// The first resolved input query keeps the prerendered rows. Move each
		// overridden input off the URL value and back so Evidence runs it in DuckDB.
		const overrides = Object.fromEntries(
			Object.entries(urlValues).filter(([key, value]) => value !== defaultMap[key]),
		);
		if (Object.keys(overrides).length) {
			apply(Object.fromEntries(Object.keys(overrides).map((key) => [key, defaultMap[key]])));
			setTimeout(() => apply(overrides), 50);
		}
		const unsubscribe = inputs.subscribe((current) => {
			const params = new URLSearchParams(window.location.search);
			let changed = false;
			for (const key of keyList) {
				const value = inputValue(current, key);
				const fallback = defaultMap[key];
				if (!value || value === fallback) {
					if (params.has(key)) {
						params.delete(key);
						changed = true;
					}
				} else if (params.get(key) !== value) {
					params.set(key, value);
					changed = true;
				}
			}
			if (!changed) return;
			const query = params.toString();
			history.replaceState(null, "", query ? `${location.pathname}?${query}` : location.pathname);
		});
		return unsubscribe;
	});
</script>
