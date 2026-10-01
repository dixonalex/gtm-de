<script>
	import { onMount } from "svelte";
	import { capMobileAxes } from "./chartTheme.js";
	import { mobileNow } from "./narrow.js";

	export let option;
	export let height = 280;

	let el;
	let chart;
	let ready = false;
	let painting = false;

	function shown(next) {
		return mobileNow() ? capMobileAxes(next) : next;
	}

	function fit() {
		if (!chart || !el) return;
		if (!mobileNow()) {
			chart.resize();
			return;
		}
		const width = Math.floor(el.clientWidth);
		const box = Number.parseFloat(el.style.height);
		if (width > 0) chart.resize({ width, height: box || el.clientHeight });
	}

	function paint() {
		if (!chart || !option || painting) return;
		painting = true;
		fit();
		chart.setOption(shown(option), true);
		painting = false;
	}

	onMount(async () => {
		const echarts = await import("echarts");
		const renderer = mobileNow() ? "svg" : "canvas";
		const width = mobileNow() ? Math.floor(el.clientWidth) || undefined : undefined;
		chart = echarts.init(el, null, { renderer, width, height });
		chart.setOption(shown(option));
		ready = true;
		const observer = new ResizeObserver(() => paint());
		observer.observe(el);
		return () => {
			observer.disconnect();
			chart.dispose();
			chart = null;
		};
	});

	$: if (ready && chart && option) paint();
</script>

<div class="canvas" bind:this={el} style="height: {height}px"></div>

<style>
	.canvas {
		width: 100%;
	}
	@media (max-width: 640px) {
		.canvas {
			max-width: 100%;
			min-width: 0;
			overflow: hidden;
		}
	}
</style>
