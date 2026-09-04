export type BreakpointName = "xxs" | "xs" | "sm" | "md" | "lg" | "xl" | "xxl";

export const BREAKPOINT_WIDTHS: Record<BreakpointName, number> = {
  xxs: 360,
  xs: 430,
  sm: 576,
  md: 768,
  lg: 992,
  xl: 1200,
  xxl: 1400
};

const VIEWPORT_HEIGHT = 900;

export const VIEWPORTS: Record<BreakpointName, { width: number; height: number }> = {
  xxs: { width: BREAKPOINT_WIDTHS.xxs, height: VIEWPORT_HEIGHT },
  xs: { width: BREAKPOINT_WIDTHS.xs, height: VIEWPORT_HEIGHT },
  sm: { width: BREAKPOINT_WIDTHS.sm, height: VIEWPORT_HEIGHT },
  md: { width: BREAKPOINT_WIDTHS.md, height: VIEWPORT_HEIGHT },
  lg: { width: BREAKPOINT_WIDTHS.lg, height: VIEWPORT_HEIGHT },
  xl: { width: BREAKPOINT_WIDTHS.xl, height: VIEWPORT_HEIGHT },
  xxl: { width: BREAKPOINT_WIDTHS.xxl, height: VIEWPORT_HEIGHT }
};
