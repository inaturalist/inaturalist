/**
 * Responsive breakpoints, shared across all e2e tests.
 *
 * These mirror the Bootstrap 5 grid tiers:
 *
 *   Breakpoint    Infix    Dimensions
 *   Extra small   (none)   < 576px
 *   Small         sm       >= 576px
 *   Medium        md       >= 768px
 *   Large         lg       >= 992px
 *   Extra large   xl       >= 1200px
 *   XX-large      xxl      >= 1400px
 *
 * `minWidth` is the viewport width (px) at which a tier becomes active.
 * `VIEWPORTS` gives a representative viewport for each tier — the tier's
 * lower bound (with a sensible width for `xs`, which has no minimum) — so a
 * test can do `page.setViewportSize( VIEWPORTS.lg )`.
 */

export type BreakpointName = "xs" | "sm" | "md" | "lg" | "xl" | "xxl";

export interface Breakpoint {
  infix: string | null;
  minWidth: number;
}

export const BREAKPOINTS: Record<BreakpointName, Breakpoint> = {
  xs: { infix: null, minWidth: 0 },
  sm: { infix: "sm", minWidth: 576 },
  md: { infix: "md", minWidth: 768 },
  lg: { infix: "lg", minWidth: 992 },
  xl: { infix: "xl", minWidth: 1200 },
  xxl: { infix: "xxl", minWidth: 1400 }
};

const VIEWPORT_HEIGHT = 900;

export const VIEWPORTS: Record<BreakpointName, { width: number; height: number }> = {
  xs: { width: 375, height: VIEWPORT_HEIGHT },
  sm: { width: BREAKPOINTS.sm.minWidth, height: VIEWPORT_HEIGHT },
  md: { width: BREAKPOINTS.md.minWidth, height: VIEWPORT_HEIGHT },
  lg: { width: BREAKPOINTS.lg.minWidth, height: VIEWPORT_HEIGHT },
  xl: { width: BREAKPOINTS.xl.minWidth, height: VIEWPORT_HEIGHT },
  xxl: { width: BREAKPOINTS.xxl.minWidth, height: VIEWPORT_HEIGHT }
};
