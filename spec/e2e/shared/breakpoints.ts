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
