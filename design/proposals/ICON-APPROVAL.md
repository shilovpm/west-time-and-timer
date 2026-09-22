# App icon B — corrected white-background version

Status: **approved and implemented on 21 September 2026**.

![Corrected icon B](icon-b/icon-b-selected-white.png)

This revision keeps the originally selected B artwork: its open offset arc, three time lines, reference meridian, endpoint circles, dotted continuation, proportions, and placement. The requested change is limited to the icon background.

## Background contract

- Target background: R = `0.994`, G = `0.994`, B = `0.994` in sRGB.
- Outside the rounded-square silhouette remains transparent.
- Final asset exports must preserve the selected B artwork and must not use the rejected redrawn SVG geometry.

## Superseded artifact

`icon-b-master.svg` and its preview are retained only for audit history. They are rejected and must not be used for implementation because they redrew and displaced the original arc.

The implementation derives `WEST/Resources/AppIcon.icns` from `icon-b-selected-white.png`. The bundled 1024 px representation remains sRGB and preserves the selected geometry.
