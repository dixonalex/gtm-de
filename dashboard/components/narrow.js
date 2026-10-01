import { browser } from "$app/environment";

export function mobileNow() {
	return browser && window.matchMedia("(max-width: 640px)").matches;
}

export function trackNarrow(set) {
	const mq = window.matchMedia("(max-width: 640px)");
	const ping = () => set(mq.matches);
	ping();
	mq.addEventListener("change", ping);
	const done = () => set(mq.matches);
	document.fonts?.ready?.then(done);
	document.fonts?.addEventListener?.("loadingdone", done);
	return () => {
		mq.removeEventListener("change", ping);
		document.fonts?.removeEventListener?.("loadingdone", done);
	};
}
