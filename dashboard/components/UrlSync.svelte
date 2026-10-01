<script>
	import { browser } from "$app/environment";
	import { getInputContext } from "@evidence-dev/sdk/utils/svelte";
	import { onMount } from "svelte";
	import { get } from "svelte/store";

	export let keys = "";
	export let defaults = "";
	/** Dropdown that stays the period control. It is never an active filter. */
	export let primary = "";

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

	// Seed once, before Dropdown copies its initial selection. Evidence 40.1.8
	// does not read URL params itself.
	if (browser) {
		const params = new URLSearchParams(window.location.search);
		const urlValues = {};
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

	function isSet(value) {
		if (!value) return false;
		return !/select\s+null|input has not been set/i.test(String(value));
	}

	function paint(current) {
		const root = document.querySelector(".slice-controls");
		if (!root) return;
		const nodes = [...root.querySelectorAll(".inline-block")];
		nodes.forEach((node, index) => {
			const key = keyList[index];
			if (!key) return;
			const value = inputValue(current, key);
			const fallback = defaultMap[key] || "All";
			const isPrimary = key === primary;
			const active = isSet(value) && !isPrimary && value !== fallback;
			node.classList.toggle("is-period", isPrimary);
			node.classList.toggle("is-active", active);
			let clear = node.querySelector(".slice-clear");
			if (active && !clear) {
				clear = document.createElement("button");
				clear.type = "button";
				clear.className = "slice-clear";
				clear.setAttribute("aria-label", `Clear ${key}`);
				clear.textContent = "×";
				clear.addEventListener("click", (event) => {
					event.preventDefault();
					event.stopPropagation();
					apply({ [key]: fallback });
				});
				node.appendChild(clear);
			} else if (!active && clear) {
				clear.remove();
			}
		});
	}

	onMount(() => {
		// Dropdowns are later siblings, so the first paint runs before they exist.
		const refresh = () => paint(get(inputs));
		const frame = requestAnimationFrame(refresh);
		const timer = setTimeout(refresh, 0);
		const unsubscribe = inputs.subscribe((current) => {
			const values = keyList.map((key) => inputValue(current, key));
			// An input that has not resolved still holds Evidence's SQL sentinel.
			// Leave the URL alone until every key has a real value.
			if (values.every(isSet)) {
				const params = new URLSearchParams(window.location.search);
				let changed = false;
				keyList.forEach((key, index) => {
					const value = values[index];
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
				});
				if (changed) {
					const query = params.toString();
					history.replaceState(null, "", query ? `${location.pathname}?${query}` : location.pathname);
				}
			}
			paint(current);
		});
		return () => {
			cancelAnimationFrame(frame);
			clearTimeout(timer);
			unsubscribe();
		};
	});
</script>
