<script>
	import { onMount } from "svelte";

	export let option;
	export let height = 280;

	let el;
	let chart;
	let ready = false;

	onMount(async () => {
		const echarts = await import("echarts");
		chart = echarts.init(el, null, { renderer: "canvas" });
		chart.setOption(option);
		ready = true;
		const observer = new ResizeObserver(() => chart && chart.resize());
		observer.observe(el);
		return () => {
			observer.disconnect();
			chart.dispose();
			chart = null;
		};
	});

	$: if (ready && chart && option) chart.setOption(option, true);
</script>

<div class="canvas" bind:this={el} style="height: {height}px"></div>

<style>
	.canvas {
		width: 100%;
	}
</style>
