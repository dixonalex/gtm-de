<script>
	import { onMount } from "svelte";
	import { capMobileAxes } from "./chartTheme.js";
	import { mobileNow } from "./narrow.js";

	export let option;
	export let height = 280;

	let el;
	let chart;
	let ready = false;

	function shown(next) {
		return mobileNow() ? capMobileAxes(next) : next;
	}

	onMount(async () => {
		const echarts = await import("echarts");
		const renderer = mobileNow() ? "svg" : "canvas";
		chart = echarts.init(el, null, { renderer });
		chart.setOption(shown(option));
		ready = true;
		const observer = new ResizeObserver(() => {
			if (!chart) return;
			chart.resize();
			if (option) chart.setOption(shown(option), true);
		});
		observer.observe(el);
		return () => {
			observer.disconnect();
			chart.dispose();
			chart = null;
		};
	});

	$: if (ready && chart && option) chart.setOption(shown(option), true);
</script>

<div class="canvas" bind:this={el} style="height: {height}px"></div>

<style>
	.canvas {
		width: 100%;
	}
</style>
